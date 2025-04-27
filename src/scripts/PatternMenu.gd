class_name PatternMenu
extends VBoxContainer


signal selected(pattern_resource: Pattern)


func _ready():
	var dir = DirAccess.open("res://src/patterns")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var pattern_resources = _load_patterns_from(dir.get_current_dir() + "/" + file_name)
				_create_pattern_container(file_name, pattern_resources)
			file_name = dir.get_next()


func _create_pattern_container(category_name, pattern_resources):
	const PATTERN_CONTAINER_SCENE = preload("res://src/scenes/PatternContainer.tscn")
	var pattern_container = PATTERN_CONTAINER_SCENE.instantiate()
	add_child(pattern_container)
	pattern_container.add_patterns(category_name.capitalize(), pattern_resources)
	pattern_container.selected.connect(func(pattern_resource): selected.emit(pattern_resource))


func _load_patterns_from(dir_path):
	var dir = DirAccess.open(dir_path)
	var pattern_paths = dir.get_files()
	var pattern_resources = []
	for res_path in pattern_paths:
		if ResourceLoader.exists(dir_path + "/" + res_path, "Pattern"):
			pattern_resources.append(ResourceLoader.load(dir_path + "/" + res_path))
	return pattern_resources


func start_animations():
	for child in get_children():
		child.start_animations()


func stop_animations():
	for child in get_children():
		child.stop_animations()
