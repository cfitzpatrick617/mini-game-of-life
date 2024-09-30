class_name PatternChoice
extends Control

var pattern_resource: Pattern
var animating := false
@export var pattern_icon: TextureRect
@export var pattern_name: Label


func _ready():
	print(pattern_icon.size / 2)
	pattern_icon.pivot_offset = (pattern_icon.size / 2)


func add_pattern(pattern_resource):
	self.pattern_resource = pattern_resource
	pattern_icon.texture.region = Rect2(0, pattern_resource.icon_column * 217, 217, 217)
	pattern_name.text = pattern_resource.name
	_setup_hover_animation(0.2, pattern_resource.total_animation_frames)


func _setup_hover_animation(frame_interval, total_frames):
	var hover_animation = Animation.new()
	var track_index = hover_animation.add_track(Animation.TYPE_VALUE)
	hover_animation.track_set_path(track_index, "PatternChoice/PatternIcon:texture:region")
	hover_animation.length = frame_interval * total_frames
	for frame_count in range(total_frames):
		hover_animation.track_insert_key(track_index, frame_count * frame_interval, Rect2(0 + (frame_count * 217), pattern_resource.icon_column * 217, 217, 217), 0)
	hover_animation.setup_local_to_scene()
	var anim_lib = $AnimationPlayer.get_animation_library("")
	anim_lib.add_animation(pattern_resource.name, hover_animation)
	

func _on_mouse_entered():
	if !animating:
		start_hover_animation()


func _on_mouse_exited():
	if animating:
		stop_hover_animation()


func start_hover_animation():
	animating = true
	_hover()


func _hover():
	if animating:
		$AnimationPlayer.play(pattern_resource.name)
		await $AnimationPlayer.animation_finished
		_hover()


func stop_hover_animation():
	animating = false
	$AnimationPlayer.stop()
	$AnimationPlayer.animation_finished.emit()
	pattern_icon.texture.region = Rect2(0, pattern_resource.icon_column * 217, 217, 217)

