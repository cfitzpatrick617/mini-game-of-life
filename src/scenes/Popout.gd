class_name Popout
extends Container

signal popout_just_hidden
signal popout_just_revealed

@export var animation_length: float = 0.5
var start_pos: Vector2
var end_pos: Vector2
var tween: Tween


func _ready():
	start_pos = position
	end_pos = Vector2(start_pos.x + size.x, start_pos.y)


func reveal_popout():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "global_position", start_pos, animation_length)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): _on_popout_finished_moving(false))
	tween.play()


func hide_popout():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "global_position", end_pos, animation_length)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): _on_popout_finished_moving(true))
	tween.play()


func _on_popout_finished_moving(hidden: bool):
	if tween:
		tween.kill()
	if hidden:
		popout_just_hidden.emit()
	else:
		popout_just_revealed.emit()
