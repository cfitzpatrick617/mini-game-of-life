class_name CreativeToolbar
extends BoxContainer

var active_button: ToggleableButton
var default_button: ToggleableButton
@export var pen_button: ToggleableButton
@export var rubber_button: ToggleableButton
@export var build_button: Button
@export var clear_button: Button


func _ready() -> void:
	default_button = pen_button
	for button in [pen_button, rubber_button]:
		button.pressed.connect(activate_button.bind(button))
	
# deactives all creative tools
func deactivate() -> void:
	if active_button:
		active_button.turn_off()


# sets to default creative mode
func set_to_default() -> void:
	if default_button != active_button:
		activate_button(default_button)
	

# activate a creative mode
func activate_button(button: Button) -> void:
	if active_button:
		active_button.turn_off()
	button.turn_on()
	active_button = button
