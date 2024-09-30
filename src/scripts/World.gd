class_name World
extends TileMap

enum Mode{DRAWING, ERASING, SIMULATING}

signal cell_count_changed(new_cell_count)
signal tick_completed(current_gen_number)

var mode: Mode
var default_drawing_mode: Mode = Mode.DRAWING
var simulation_speed: int = 10
var gen_number: int = 0
var seed: Array = []
var current_generation: Array = []
var hovered_cell: Vector2i


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
	_draw_cells(next_generation) # draw update
	current_generation = next_generation
	tick_completed.emit(gen_number)


func pause_simulation() -> void:
	$TickTimer.paused = true


func resume_simulation() -> void:
	$TickTimer.paused = false


func reset(reload_seed: bool=true) -> void:
	mode = default_drawing_mode
	gen_number = 0
	if reload_seed:
		current_generation = seed
		_draw_cells(seed)
	else:
		_clear_world()
	# ensure timer is not paused for the next simulation
	if is_paused():
		$TickTimer.paused = false


func get_gen_number() -> int:
	return gen_number


func is_paused() -> bool:
	return $TickTimer.paused


func is_simulating() -> bool:
	return mode == Mode.SIMULATING


func set_to_drawing_mode() -> void:
	mode = Mode.DRAWING


func set_to_erasing_mode() -> void:
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


func _draw_cells(cells) -> void:
	clear_layer(1)
	for cell in cells:
		set_cell(1, cell, 0, Vector2i(0, 0))
	cell_count_changed.emit(cells.size())


func _clear_world() -> void:
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


func detect_world_changes() -> void:
	var current_cell = local_to_map(get_local_mouse_position())
	if !Input.is_action_just_pressed("click"): # hovering not clicking
		if hovered_cell not in current_generation and current_cell != hovered_cell:
			erase_cell(1, hovered_cell)
		if current_cell not in current_generation:
			set_cell(1, current_cell, 0, Vector2(2, 0))
			hovered_cell = current_cell
	elif mode == Mode.DRAWING and current_cell not in current_generation:
		set_cell(1, current_cell, 0, Vector2i(0, 0))
		current_generation.append(current_cell)
		cell_count_changed.emit(current_generation.size())
	elif mode == Mode.ERASING and current_cell in current_generation:
		erase_cell(1, hovered_cell)
		current_generation.erase(current_cell)
		cell_count_changed.emit(current_generation.size())
		
