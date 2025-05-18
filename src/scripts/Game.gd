extends VBoxContainer

@export var pattern_menu: PatternMenu
@export var gen_number_label: Label
@export var cell_count_label: Label
@export var pen_button: ToggleableButton
@export var rubber_button: ToggleableButton
@export var build_button: ToggleableButton
@export var undo_button: Button
@export var redo_button: Button
@export var clear_button: Button
@export var simulate_button: Button
@export var kill_button: Button
@export var world_container: SubViewportContainer
@export var world: World
var undo_stack: Array 
var inactive_during_sim: Array[Button]


func _ready() -> void:
	simulate_button.disabled = true
	inactive_during_sim = [
		pen_button,
		rubber_button,
		build_button,
		redo_button,
		undo_button,
		clear_button,
	]
	# connect signals
	pen_button.pressed.connect(_enable_drawing)
	rubber_button.pressed.connect(_enable_erasing)
	build_button.pressed.connect(_show_builder)
	undo_button.pressed.connect(func(): world.undo())
	redo_button.pressed.connect(func(): world.redo())
	simulate_button.pressed.connect(_switch_simulation_state)
	kill_button.pressed.connect(_stop_simulation)
	clear_button.pressed.connect(_clear_screen)
	world_container.mouse_exited.connect(func(): world.force_unhover())
	world.world_state_transitioned.connect(_update_undo_redo)
	world.cell_count_changed.connect(_update_cell_count)
	world.tick_completed.connect(_update_gen_number)
	pattern_menu.selected.connect(_select_pattern)
	_enable_drawing()


func _clear_screen() -> void:
	world.reset(false)
	_enable_drawing()


func _stop_simulation() -> void:
	kill_button.disabled = true
	await world.reset()
	_update_gen_number(0)
	_enable_drawing()
	simulate_button.turn_off()


func _enable_drawing() -> void:
	rubber_button.turn_off()
	build_button.turn_off()
	pen_button.turn_on()
	world.set_to_drawing_mode()
	for button in inactive_during_sim:
		button.disabled = false
	_update_undo_redo()


func _enable_erasing() -> void:
	build_button.turn_off()
	pen_button.turn_off()
	rubber_button.turn_on()
	world.set_to_erasing_mode()
	

func _switch_simulation_state() -> void:
	# if simulation has not been started
	if !world.is_simulating():
		# disable all creative buttons (drawing, erasing, clearing)
		for button in inactive_during_sim:
			if button is ToggleableButton:
				button.turn_off()
			button.release_focus()
			button.disabled = true
		world.start_simulation()
		kill_button.disabled = false
	else:
		if world.is_paused():
			world.resume_simulation()
		else:
			world.pause_simulation()


func _show_builder() -> void:
	pen_button.turn_off()
	rubber_button.turn_off()
	build_button.turn_on()
	pattern_menu.start_animations()
	$Overlay.visible = true


func _close_builder() -> void:
	$Overlay.visible = false
	pattern_menu.stop_animations()


func _select_pattern(pattern_resource: Pattern) -> void:
	world.set_current_pattern(pattern_resource)
	_close_builder()


func _update_undo_redo() -> void:
	undo_button.disabled = !world.can_undo()
	redo_button.disabled = !world.can_redo()


func _update_gen_number(gen_number) -> void:
	gen_number_label.text = "Generation: %s" % gen_number


func _update_cell_count(cell_count) -> void:
	cell_count_label.text = "Cells Alive: %s" % cell_count
	# if atleast one cell exists, allow a simulation to be started
	if simulate_button.disabled and cell_count > 0:
		simulate_button.disabled = false
	# disable starting simulation if there are no cells
	elif simulate_button.disabled and cell_count <= 0:
		simulate_button.disabled = true


func _process(_delta) -> void:
	if Input.is_action_just_pressed("switch_simulation_state"):
		simulate_button.pressed.emit()
