extends Node
func _ready() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"):
			var script := load("res://scripts/" + file) as GDScript
			assert(script != null and script.can_instantiate(), file)
			count += 1
	print("SCRIPT_CHECK_OK: ", count, " scripts")
	get_tree().quit()
