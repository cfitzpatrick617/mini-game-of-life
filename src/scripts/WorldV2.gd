class_name WorldV2
extends TileMap
## Class representing the world in which cells can be drawn and where simulations take place

enum Mode{DRAWING, ERASING, SIMULATING} ## Current mode of world

signal cell_count_changed(new_cell_count) ## Emitted when the cell count changes
signal tick_completed(current_gen_number) ## Emitted when a generation tick completes
signal world_state_transitioned() ## Emitted after an undo or redo command

var current_pattern: Pattern ## Current build pattern
var mode: Mode
var default_drawing_mode: Mode = Mode.DRAWING
var simulation_speed: int = 10
var gen_number: int = 0
var seed = {} ## Starting set of cells for a simulation
var cell_count = 0
var hovered_cells: Array = [] ## Cells currently being hovered over by the mouse
var undo_stack: Array = []
var redo_stack: Array = []
var unstored_changes: Array = []
var last_mouse_pos: Vector2i = Vector2i(-1, -1)
var map = {}


func start_simulation() -> void: ## Starts a simulation
	mode = Mode.SIMULATING
	seed = map
	await get_tree().process_frame # ensure that all editing has been completed before simulation
	_simulate(Time.get_unix_time_from_system())


func is_paused() -> bool:
	return $TickTimer.paused


func pause_simulation() -> void:
	$TickTimer.paused = true


func resume_simulation() -> void:
	$TickTimer.paused = false


func is_simulating() -> bool:
	return mode == Mode.SIMULATING


func change_simulation_speed(new_simulation_speed) -> void:
	# prevent invalid speed
	if typeof(new_simulation_speed) == TYPE_INT and new_simulation_speed >= 1:
		if !$TickTimer.is_stopped():
			$TickTimer.time_left = 0.06 # lowest reliable time possible
		simulation_speed = new_simulation_speed


func _simulate(last_time) -> void: ## Recursive algorithm to simulate
	var this_time = Time.get_unix_time_from_system()
	if mode == Mode.SIMULATING: # base case that ends recursive algorithm when the simulation is stopped
		var time_before_tick = Time.get_unix_time_from_system()
		_complete_tick()
		var time_taken = Time.get_unix_time_from_system() - time_before_tick
		# account for processing time for consistent spacing
		$TickTimer.wait_time = ((1.0 - time_taken) / simulation_speed)
		$TickTimer.start()
		await $TickTimer.timeout # wait depending on the simulation speed
		_simulate(this_time) # repeat simulation until the user stops it
	

func _complete_tick() -> void: ## Enforce rules and move to the next generation
	gen_number += 1
	_calculate_next_gen()
	_refresh_cells() # draw update
	tick_completed.emit(gen_number)


func _calculate_next_gen() -> void:
	var this_time = Time.get_unix_time_from_system()
	var new_map = {}
	# deal with live cells
	for cell in map.keys():
		var val = map[cell]
		if val != 0:
			if val & 1 == 1 and ((val >> 1) & 15 != 2 and (val >> 1) & 15 != 3):
				_update_cell_in_map(new_map, cell, 0)
			elif val & 1 == 0 and (val >> 1) & 15 == 3:
				_update_cell_in_map(new_map, cell, 1)
	map = new_map
	var next_time = Time.get_unix_time_from_system()


func _update_cell_in_map(new_map, cell, new_state):
	const DIRECTIONS = [
		Vector2i(-1, 1), Vector2i.UP, Vector2i(1, 1),
		Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(-1, -1), Vector2i.DOWN, Vector2i(1, -1),
	]
	if !map.has(cell):
		new_map[cell] = 0
	if map[cell] == new_state:
		return
	if new_state == 0:
		new_map[cell] = 0
		for direction in DIRECTIONS:
			if !map.has(cell + direction):
				new_map[cell + direction] = 0
			else:
				var val = map[cell + direction]
				var middle = (val >> 1) & 15
				middle -= 1
				var cleared = val & ~(15 << 1)    
				new_map[cell + direction] = max(cleared | (middle << 1), 0)
	else:
		new_map[cell] = map[cell] | 1
		for direction in DIRECTIONS:
			if !map.has(cell + direction):
				new_map[cell + direction] = 2
			else:
				var val = map[cell + direction]
				var middle = (val >> 1) & 15
				middle += 1  
				var cleared = val & ~(15 << 1) 
				new_map[cell + direction] = min(cleared | (middle << 1), 8) 


func get_gen_number() -> int:
	return gen_number


func _refresh_cells() -> void:
	clear_layer(1)
	var alive_count = 0
	for cell in map.keys():
		if map[cell] != 0:
			set_cell(1, cell, 0, Vector2i(0, 0))
			alive_count += 1
	cell_count_changed.emit(alive_count)


func set_to_drawing_mode() -> void:
	current_pattern = null
	mode = Mode.DRAWING


func set_to_erasing_mode() -> void:
	current_pattern = null
	mode = Mode.ERASING


func set_current_pattern(pattern: Pattern):
	current_pattern = pattern


func _input(event) -> void:
	# detect mouse activity during creative phase
	if mode != Mode.SIMULATING:
		detect_world_changes()
		if event.is_action_released("click"):
			last_mouse_pos = Vector2(-1, -1)
			if !unstored_changes.is_empty():
				redo_stack = []
				undo_stack.append(map.duplicate(true))
				unstored_changes = []
				world_state_transitioned.emit()


func detect_world_changes() -> void:
	var hovered_cell = local_to_map(get_local_mouse_position())
	var active_cells = []
	if !current_pattern:
		active_cells.append(hovered_cell)
	else:
		for pos in current_pattern.cells:
			active_cells.append(hovered_cell + pos)
	# hovering not clicking
	if !Input.is_action_pressed("click"):
		_hover_cells(active_cells)
	# drawing a pattern
	elif mode == Mode.DRAWING and Input.is_action_just_pressed("click") and current_pattern:
		unstored_changes.append_array(_draw_cells(active_cells))
	else:
		active_cells = _get_smoothed_mouse_path(last_mouse_pos, hovered_cell)
		if mode == Mode.DRAWING: # draw freehand with mouse
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
		if !map.has(cell) or map[cell] & 1 != 1:
			set_cell(1, cell, 0, Vector2i(0, 0))
			_update_cell_in_map(map, cell, 1)
			cells_drawn.append(cell)
	change_cell_count(cells_drawn.size())
	return cells_drawn


func change_cell_count(by: int):
	cell_count += by
	cell_count_changed.emit(cell_count)


func _erase_cells(cells) -> Array:
	var cells_erased = []
	for cell in cells:
		if map.has(cell) and map[cell] & 1 == 1:
			erase_cell(1, cell)
			_update_cell_in_map(map, cell, 0)
			cells_erased.append(cell)
	change_cell_count(-cells_erased.size())
	return cells_erased


func _hover_cells(cells_to_hover):
	for cell in hovered_cells:
		if !map.has(cell) or map[cell] == 0:
			if cell not in cells_to_hover:
				erase_cell(1, cell)
	var new_hovered_cells = []
	for cell in cells_to_hover:
		if !map.has(cell) or map[cell] == 0:
			new_hovered_cells.append(cell)
			if cell not in hovered_cells:
				set_cell(1, cell, 0, Vector2(2, 0))
	hovered_cells = new_hovered_cells


func force_unhover():
	_hover_cells([])


func can_undo() -> bool:
	return !undo_stack.is_empty()


func undo() -> void:
	if !undo_stack.is_empty():
		var undo_map = undo_stack.pop_back()
		redo_stack.append(map.duplicate(true))
		map = undo_map
		_refresh_cells()
		world_state_transitioned.emit()


func can_redo() -> bool:
	return !redo_stack.is_empty()


func redo() -> void:
	if !redo_stack.is_empty():
		var redo_map = redo_stack.pop_back()
		undo_stack.append(map.duplicate(true))
		map = redo_map
		_refresh_cells()
		world_state_transitioned.emit()


func reset(reload_seed: bool=true) -> void:
	mode = default_drawing_mode
	gen_number = 0
	if reload_seed:
		map = seed
		_refresh_cells()
	else:
		_clear_world()
	$TickTimer.paused = false # ensure timer is not paused for the next simulation


func _clear_world() -> void:
	redo_stack = []
	undo_stack.append(map)
	map = {}
	world_state_transitioned.emit()
	clear_layer(1)
	seed = []
	change_cell_count(-cell_count)
