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


func turn_on():
	icon = image_when_on
	is_on = true


func turn_off():
	icon = image_when_off
	is_on = false
