class_name Pattern
extends Resource

enum Type{OSCILLATOR, GUN}

@export var name: String
@export var icon_column: int
@export var total_animation_frames: int 
@export var type: Type
@export var width: int
@export var height: int
@export var cells: Array[Vector2i]
