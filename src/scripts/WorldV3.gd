class_name World
extends Node2D
## Class representing the world in which cells can be drawn and where simulations take place

enum CreativeMode{DRAWING, ERASING}

signal cell_count_changed(new_cell_count) ## Emitted when the cell count changes
signal gen_number_changed(new_gen_number) ## Emiitted when the gen number changes
signal world_state_transitioned() ## Emitted after an undo or redo command

const FIZZLE_MATERIAL = preload("res://src/shaders/fizzle_material.tres")
@export var bg_layer: TileMap
@export var cell_layer: TileMap
var width: int
var height: int
var grid_enabled := true
var rd: RenderingDevice
var shader: RID
var current_pattern: Pattern ## Current build pattern
var creative_mode := CreativeMode.DRAWING
var simulating := false
var can_draw_during_sim := false
var cells_fizzle := false
var time_between_gens := 0.1
var cooldown_timer: float = 0
var current_generation := PackedFloat32Array()
var cells_alive: int = 0
var gen_number: int = 0
var seed := [] ## Starting set of cells for a simulation
var hovered_cells := [] ## Cells currently being hovered over by the mouse
var undo_stack := []
var redo_stack := []
var unstored_changes := []
var last_mouse_pos := Vector2i(-1, -1)


func _ready():
	width = bg_layer.get_used_rect().size.x
	height = bg_layer.get_used_rect().size.y
	# create compute shader for faster generation
	rd = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://src/shaders/generator.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	# initialise empty grid
	for n in range(width * height):
		current_generation.append(0)
	set_process(false) # ensure simulation is off


func set_grid(enable: bool) -> void:
	bg_layer.visible = enable
	grid_enabled = enable
	for cell in cell_layer.get_used_cells(0):
		cell_layer.set_cell(0, cell, int(enable), cell_layer.get_cell_atlas_coords(0, cell))


func set_drawing_during_sim(enable: bool) -> void:
	can_draw_during_sim = enable


func set_cells_fizzle(enable: bool) -> void:
	cell_layer.material = FIZZLE_MATERIAL


func start_simulation() -> void: ## Starts a simulation
	simulating = true
	seed = current_generation # make the current canvas the seed
	if can_draw_during_sim:
		creative_mode = CreativeMode.DRAWING
	await get_tree().process_frame # ensure that all editing has been completed before simulation
	set_process(true)


func is_paused() -> bool:
	return is_simulating() and !is_processing()


func pause_simulation() -> void:
	set_process(false)


func resume_simulation() -> void:
	set_process(true)


func stop_simulation() -> void:
	set_process(false)
	simulating = false
	reset()


func is_simulating() -> bool:
	return simulating


func change_time_between_gens(new_time_between_gens: float) -> void:
	time_between_gens = new_time_between_gens


func _process(delta):
	cooldown_timer += delta
	if cooldown_timer > time_between_gens:
		_complete_tick()
		cooldown_timer = 0
		
	
func _complete_tick() -> void: ## Enforce rules and move to the next generation
	var next_generation = _calculate_next_gen()
	_refresh_cells(next_generation) # draw update
	gen_number += 1
	gen_number_changed.emit(gen_number)


func _calculate_next_gen() -> Array:
	var byte_map := current_generation.to_byte_array()
	# double buffer solution where current gen is read from and next gen is written to
	var current_buffer = rd.storage_buffer_create(byte_map.size(), byte_map)
	var next_buffer = rd.storage_buffer_create(byte_map.size(), byte_map)
	var current_uniform := RDUniform.new()
	current_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	current_uniform.binding = 0
	current_uniform.add_id(current_buffer)
	var current_uniform_set = rd.uniform_set_create([current_uniform], shader, 0) 
	var next_uniform := RDUniform.new()
	next_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	next_uniform.binding = 0 
	next_uniform.add_id(next_buffer)
	var next_uniform_set = rd.uniform_set_create([next_uniform], shader, 1) 
	# push width and height constants
	var parameters := PackedByteArray()
	parameters.resize(16)
	parameters.encode_s32(0, width)
	parameters.encode_s32(4, height)
	parameters.encode_s32(8, int(cells_fizzle))
	# create new compute pipeline
	var pipeline = rd.compute_pipeline_create(shader)
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, current_uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, next_uniform_set, 1)
	rd.compute_list_set_push_constant(compute_list, parameters, parameters.size())
	rd.compute_list_dispatch(compute_list, current_generation.size(), 1, 1)
	rd.compute_list_end()
	# submit and await results
	rd.submit()
	rd.sync()
	var output_bytes = rd.buffer_get_data(next_buffer)
	# manually free memory to prevent leaks
	rd.free_rid(pipeline)
	rd.free_rid(current_buffer)
	rd.free_rid(next_buffer)
	return output_bytes.to_float32_array()


func _refresh_cells(cells) -> void:
	cell_layer.clear_layer(0)
	current_generation = cells
	cells_alive = 0
	for n in range(cells.size()): # for every cell
		if is_zero_approx(current_generation[n]):
			continue
		var tile := Vector2i()
		if is_equal_approx(current_generation[n], 1):
			cells_alive += 1
			tile = Vector2i(0, 0)
		elif is_equal_approx(current_generation[n], 0.8):
			tile = Vector2i(3, 0)
			print(tile)
		elif is_equal_approx(current_generation[n], 0.6):
			tile = Vector2i(4, 0)
		elif is_equal_approx(current_generation[n], 0.4):
			tile = Vector2i(5, 0)
		elif is_equal_approx(current_generation[n], 0.2):
			tile = Vector2i(6, 0)
		cell_layer.set_cell(0, Vector2i(n % width, n / width), grid_enabled, tile)
	cell_count_changed.emit(cells_alive)


func set_to_drawing_mode() -> void:
	current_pattern = null
	creative_mode = CreativeMode.DRAWING


func set_to_erasing_mode() -> void:
	current_pattern = null
	creative_mode = CreativeMode.ERASING


func set_current_pattern(pattern: Pattern):
	current_pattern = pattern


func _input(event) -> void:
	# detect mouse activity during creative phase
	if !is_paused() and (can_draw_during_sim or !is_simulating()):
		detect_world_changes()
		if event.is_action_released("click"): # finished an action
			last_mouse_pos = Vector2(-1, -1)
			if !is_simulating() and !unstored_changes.is_empty(): # store action in action history
				redo_stack = []
				undo_stack.append([creative_mode, unstored_changes])
				unstored_changes = []
				world_state_transitioned.emit()


func detect_world_changes() -> void:
	var hovered_cell = cell_layer.local_to_map(get_local_mouse_position())
	var active_cells = []
	if !current_pattern:
		active_cells.append(hovered_cell)
	else:
		for pos in current_pattern.cells:
			active_cells.append(hovered_cell + pos)
	# hovering not clicking
	if !Input.is_action_pressed("click"):
		if !is_simulating():
			_hover_cells(active_cells)
	# drawing a pattern
	elif creative_mode == CreativeMode.DRAWING and Input.is_action_just_pressed("click") and current_pattern:
		unstored_changes.append_array(_draw_cells(active_cells))
	else:
		active_cells = _get_smoothed_mouse_path(last_mouse_pos, hovered_cell)
		if creative_mode == CreativeMode.DRAWING: # draw freehand with mouse
			unstored_changes.append_array(_draw_cells(active_cells))
		else: # erases cell that is already drawn
			unstored_changes.append_array(_erase_cells(active_cells))
			_hover_cells(active_cells)
		last_mouse_pos = hovered_cell


func _get_smoothed_mouse_path(last_mouse_pos: Vector2i, current_mouse_pos: Vector2i):
	# if mouse has not moved i.e. there's no path
	if last_mouse_pos == Vector2i(-1, -1):
		return [current_mouse_pos]
	var x1 = last_mouse_pos.x
	var y1 = last_mouse_pos.y
	var x2 = current_mouse_pos.x
	var y2 = current_mouse_pos.y
	# Bresenham's line algorithm
	var dx = abs(x2 - x1)
	var sx
	if x1 < x2:
		sx = 1
	else:
		sx = -1
	var dy = abs(y2 - y1)
	var sy
	if y1 < y2:
		sy = 1
	else:
		sy = -1
	var err = dx - dy
	
	var path = []
	while (true):
		path.append(Vector2i(x1, y1))
		if (x1 == x2) and (y1 == y2): break
		var e2 = err << 1
		if (e2 > -dy):
			if (x1 == x2): break
			err -= dy
			x1 += sx
		if (e2 <= dx):
			if (y1 == y2): break
			err += dx
			y1 += sy
	return path


func _draw_cells(cells) -> Array:
	var cells_drawn = []
	for cell in cells:
		if !check_is_alive(cell):
			cells_drawn.append(cell)
			cell_layer.set_cell(0, cell, int(grid_enabled), Vector2i(0, 0))
			current_generation[cell.y * width + cell.x] = 1
	if cells_drawn:
		cells_alive += cells_drawn.size()
		cell_count_changed.emit(cells_alive)
	return cells_drawn


func _erase_cells(cells) -> Array:
	var cells_erased = []
	for cell in cells:
		if check_is_alive(cell):
			cells_erased.append(cell)
			cell_layer.erase_cell(0, cell)
			current_generation[cell.y * width + cell.x] = 0
	if cells_erased:
		cells_alive -= cells_erased.size()
		cell_count_changed.emit(cells_alive)
	return cells_erased


func _hover_cells(cells_to_hover):
	for cell in hovered_cells:
		if !check_is_alive(cell):
			if cell not in cells_to_hover:
				cell_layer.erase_cell(0, cell)
	var new_hovered_cells = []
	for cell in cells_to_hover:
		if !check_is_alive(cell):
			new_hovered_cells.append(cell)
			if cell not in hovered_cells:
				cell_layer.set_cell(0, cell, int(grid_enabled), Vector2(2, 0))
	hovered_cells = new_hovered_cells


func check_is_alive(cell):
	return cell_layer.get_cell_atlas_coords(0, cell) == Vector2i(0, 0)


func force_unhover():
	_hover_cells([])


func can_undo() -> bool:
	return !undo_stack.is_empty() and !is_simulating()


func undo() -> void:
	if !undo_stack.is_empty():
		var operation = undo_stack.pop_back()
		if operation[0] == CreativeMode.DRAWING:
			_erase_cells(operation[1])
		else:
			_draw_cells(operation[1])
		redo_stack.append(operation)
		world_state_transitioned.emit()


func can_redo() -> bool:
	return !redo_stack.is_empty() and !is_simulating()


func redo() -> void:
	if !redo_stack.is_empty():
		var operation = redo_stack.pop_back()
		if operation[0] == CreativeMode.DRAWING:
			_draw_cells(operation[1])
		else:
			_erase_cells(operation[1])
		undo_stack.append(operation)
		world_state_transitioned.emit()


func reset(reload_seed: bool=true) -> void:
	if reload_seed:
		_refresh_cells(seed)
	else:
		_clear_world()
	creative_mode = CreativeMode.DRAWING
	gen_number = 0
	gen_number_changed.emit(0)


func _clear_world() -> void:
	redo_stack = []
	undo_stack.append([CreativeMode.ERASING, cell_layer.get_used_cells(0)])
	world_state_transitioned.emit()
	cell_layer.clear_layer(0)
	seed = []
	current_generation = []
	for n in range(width * height):
		current_generation.append(0)
	cells_alive = 0
	cell_count_changed.emit(0)
