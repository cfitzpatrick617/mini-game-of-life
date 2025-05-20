class_name SettingsButton
extends MenuButton

signal setting_change_requested(setting_id: Option, enabled: bool)

enum Option{GRID_ENABLED, DRAW_DURING_SIMULATION, CELLS_FIZZLE, LIGHT_MODE}

const SETTINGS = {
	Option.GRID_ENABLED: ["Grid enabled", true],
	Option.DRAW_DURING_SIMULATION: ["Draw during sim", false],
	#Option.CELLS_FIZZLE: ["Cells fizzle", false],
	#Option.LIGHT_MODE: ["Light mode", true],
}


# Called when the node enters the scene tree for the first time.
func _ready():
	for key in SETTINGS.keys():
		var setting = SETTINGS[key]
		get_popup().add_check_item(setting[0], key)
		get_popup().set_item_checked(key, setting[1])
	get_popup().hide_on_checkable_item_selection = false
	get_popup().id_pressed.connect(_on_option_checked)


func _on_option_checked(id: int):
	var checked = get_popup().is_item_checked(id)
	get_popup().set_item_checked(id, !checked)
	setting_change_requested.emit(id, !checked)
	
