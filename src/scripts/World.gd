class_name World
extends TileMap

enum Mode{DRAWING, ERASING, SIMULATING}

signal cell_count_changed(new_cell_count)
signal tick_completed(current_gen_number)
signal world_state_transitioned()

var current_pattern: Pattern
var mode: Mode
var default_drawing_mode: Mode = Mode.DRAWING
var simulation_speed: int = 10
var gen_number: int = 0
var seed: Array = []
var current_generation: Array = []
var hovered_cells: Array = []
var undo_stack: Array = []
var redo_stack: Array = []
var unstored_changes: Array = []


func start_simulation() -> void:
	mode = Mode.SIMULATING
	seed = current_generation # save the original generation as the seed
	await get_tree().process_frame # ensure that all editing has been completed before simulation
	_simulate(Time.get_unix_time_from_system())


func _simulate(last_time) -> void:
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
	

func _complete_tick() -> void:
	gen_number += 1
	var next_generation = _calculate_next_gen() # update game
	_refresh_cells(next_generation) # draw update
	current_generation = next_generation
	tick_completed.emit(gen_number)


func pause_simulation() -> void:
	$TickTimer.paused = true


func resume_simulation() -> void:
	$TickTimer.paused = false


func can_undo() -> bool:
	return !undo_stack.is_empty()

func undo() -> void:
	if !undo_stack.is_empty():
		var operation = undo_stack.pop_back()
		if operation[0] == Mode.DRAWING:
			_erase_cells(operation[1])
		else:
			_draw_cells(operation[1])
		redo_stack.append(operation)
		world_state_transitioned.emit()


func can_redo() -> bool:
	return !redo_stack.is_empty()


func redo() -> void:
	if !redo_stack.is_empty():
		var operation = redo_stack.pop_back()
		if operation[0] == Mode.DRAWING:
			_draw_cells(operation[1])
		else:
			_erase_cells(operation[1])
		undo_stack.append(operation)
		world_state_transitioned.emit()


func reset(reload_seed: bool=true) -> void:
	mode = default_drawing_mode
	gen_number = 0
	if reload_seed:
		current_generation = seed
		_refresh_cells(seed)
	else:
		_clear_world()
	$TickTimer.paused = false # ensure timer is not paused for the next simulation


func get_gen_number() -> int:
	return gen_number


func is_paused() -> bool:
	return $TickTimer.paused


func is_simulating() -> bool:
	return mode == Mode.SIMULATING


func set_to_drawing_mode() -> void:
	current_pattern = null
	mode = Mode.DRAWING


func set_to_erasing_mode() -> void:
	current_pattern = null
	mode = Mode.ERASING


func _calculate_next_gen() -> Array:
	var next_generation = []
	# calculate active cell statuses
	const DIRECTIONS = [
		Vector2i(-1, 1), Vector2i.UP, Vector2i(1, 1),
		Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(-1, -1), Vector2i.DOWN, Vector2i(1, -1),
	]
	var potential_births = {}
	var alive_neighbour_count
	# deal with live cells
	for cell in current_generation:
		alive_neighbour_count = 0
		for direction in DIRECTIONS:
			if cell + direction in current_generation:
				alive_neighbour_count += 1
			else:
				potential_births[cell + direction] = null
		if alive_neighbour_count == 2 or alive_neighbour_count == 3:
			next_generation.append(cell)
	# deal with potential births
	for cell in potential_births.keys():
		alive_neighbour_count = 0
		for direction in DIRECTIONS:
			if cell + direction in current_generation:
				alive_neighbour_count += 1
		if alive_neighbour_count == 3:
			next_generation.append(cell)
	return next_generation


func _refresh_cells(cells) -> void:
	clear_layer(1)
	for cell in cells:
		set_cell(1, cell, 0, Vector2i(0, 0))
	cell_count_changed.emit(cells.size())


func _clear_world() -> void:
	if !current_generation.is_empty():
		redo_stack = []
		undo_stack.append([Mode.ERASING, current_generation])
		world_state_transitioned.emit()
		clear_layer(1)
		seed = []
		current_generation = []
		cell_count_changed.emit(0)


func change_simulation_speed(new_simulation_speed) -> void:
	# prevent invalid speed
	if typeof(new_simulation_speed) == TYPE_INT and new_simulation_speed >= 1:
		if !$TickTimer.is_stopped():
			$TickTimer.time_left = 0.06 # lowest reliable time possible
		simulation_speed = new_simulation_speed


func _input(event) -> void:
	# detect mouse activity during creative phase
	if mode != Mode.SIMULATING:
		detect_world_changes()
		if event.is_action_released("click") and !unstored_changes.is_empty():
			redo_stack = []
			undo_stack.append([mode, unstored_changes])
			unstored_changes = []
			world_state_transitioned.emit()


func set_current_pattern(pattern: Pattern):
	current_pattern = pattern


func detect_world_changes() -> void:
	var current_cell = local_to_map(get_local_mouse_position())
	var cells_to_draw = []
	if !current_pattern:
		cells_to_draw.append(current_cell)
	else:
		for pos in current_pattern.cells:
			cells_to_draw.append(current_cell + pos)
	# hovering not clicking
	if !Input.is_action_pressed("click"):
		_hover_cells(cells_to_draw)
	# if we have detected a click
	# draws a new cell that is not already drawn
	elif mode == Mode.DRAWING:
		unstored_changes.append_array(_draw_cells(cells_to_draw))
	# erases cell that is already drawn
	elif mode == Mode.ERASING:
		unstored_changes.append_array(_erase_cells([current_cell]))
		_hover_cells([current_cell])


func _draw_cells(cells) -> Array:
	var cells_drawn = []
	for cell in cells:
		if cell not in current_generation:
			set_cell(1, cell, 0, Vector2i(0, 0))
			cells_drawn.append(cell)
			current_generation.append(cell)
	cell_count_changed.emit(current_generation.size())
	return cells_drawn


func _erase_cells(cells) -> Array:
	var cells_erased = []
	for cell in cells:
		if cell in current_generation:
			erase_cell(1, cell)
			current_generation.erase(cell)
			cells_erased.append(cell)
	cell_count_changed.emit(current_generation.size())
	return cells_erased


func _hover_cells(cells_to_hover):
	for cell in hovered_cells:
		if cell not in current_generation:
			if cell not in cells_to_hover:
				erase_cell(1, cell)
	var new_hovered_cells = []
	for cell in cells_to_hover:
		if cell not in current_generation:
			new_hovered_cells.append(cell)
			if cell not in hovered_cells:
				set_cell(1, cell, 0, Vector2(2, 0))
	hovered_cells = new_hovered_cells


func force_unhover():
	_hover_cells([])
