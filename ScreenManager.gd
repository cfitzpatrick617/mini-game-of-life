extends Node

const SCREENS: Dictionary = {
	"game": "res://src/scenes/Game.tscn",
	"pattern_builder": "res://src/scenes/PatternMenu.tscn",
}
var current_scene: Node


# Called when the node enters the scene tree for the first time.
func _ready():
	current_scene = SCREENS["game"]


func load_screen(screen_name):
	if SCREENS[screen_name]:
		if current_scene:
	
