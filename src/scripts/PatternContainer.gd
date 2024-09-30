class_name PatternContainer
extends VBoxContainer

@onready var pattern_category_label: Label = $PatternCategory


func add_patterns(category_name, pattern_resources):
	const PATTERN_CHOICE_SCENE = preload("res://PatternChoice.tscn")
	pattern_category_label.text = category_name
	for pattern in pattern_resources:
		var pattern_choice = PATTERN_CHOICE_SCENE.instantiate()
		$Choices.add_child(pattern_choice)
		pattern_choice.add_pattern(pattern)
