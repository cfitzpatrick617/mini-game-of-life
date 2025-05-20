class_name ToggleableButton
extends Button

var is_on := false
@export var image_when_on: Texture
@export var image_when_off: Texture


func _ready() -> void:
	pressed.connect(switch_states)


func switch_states():
	if is_on:
		icon = image_when_off
	else:
		icon = image_when_on
	is_on = !is_on


func set_state(enable: bool):
	if enable:
		icon = image_when_on
	else:
		icon = image_when_off
	is_on = enable
