class_name PatternMenu
extends VBoxContainer


func _ready():
	var dir = DirAccess.open("res://patterns")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var pattern_resources = _load_patterns_from(dir.get_current_dir() + "/" + file_name)
				_create_pattern_container(file_name, pattern_resources)
			file_name = dir.get_next()


func _create_pattern_container(category_name, pattern_resources):
	const PATTERN_CONTAINER_SCENE = preload("res://PatternContainer.tscn")
	var pattern_container = PATTERN_CONTAINER_SCENE.instantiate()
	add_child(pattern_container)
	pattern_container.add_patterns(category_name.capitalize(), pattern_resources)


func _load_patterns_from(dir_path):
	var dir = DirAccess.open(dir_path)
	var pattern_paths = dir.get_files()
	var pattern_resources = []
	for res_path in pattern_paths:
		if ResourceLoader.exists(dir_path + "/" + res_path, "Pattern"):
			pattern_resources.append(ResourceLoader.load(dir_path + "/" + res_path))
	return pattern_resources
