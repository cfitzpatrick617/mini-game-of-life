class_name PatternContainer
extends VBoxContainer


signal selected(pattern_resource: Pattern)

@onready var pattern_category_label: Label = $PatternCategory


func add_patterns(category_name, pattern_resources):
	const PATTERN_CHOICE_SCENE = preload("res://src/scenes/PatternChoice.tscn")
	pattern_category_label.text = category_name
	for pattern in pattern_resources:
		var pattern_choice = PATTERN_CHOICE_SCENE.instantiate()
		$Choices.add_child(pattern_choice)
		pattern_choice.add_pattern(pattern)
		pattern_choice.gui_input.connect(_select.bind(pattern_choice))


func start_animations():
	for child in $Choices.get_children():
		child.start_hover_animation()


func stop_animations():
	for child in $Choices.get_children():
		child.stop_hover_animation()


func _select(event, pattern_choice):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(pattern_choice.pattern_resource)
