extends Node3D
## F6 самой карты тоже запускает игровой тест; раннер уже выставляет Game.testing.
func _ready() -> void:
	if has_node("Spawn"):
		set_meta("spawn", $Spawn.position)
	if not Game.testing:
		get_tree().change_scene_to_file.call_deferred("res://scenes/tools/riverbank_playtest.tscn")
