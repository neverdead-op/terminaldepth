extends "res://tools/test_huntress.gd"
## Та же проверка весов и деформаций, применённая к отдельной новой модели.
func _initialize() -> void:
	model_scene = load("res://assets/characters/model1_player.tscn")
	mesh_name = "Model1Hero"
	required_bones = ["pelvis", "Head", "hand_l", "hand_r", "ball_l", "ball_r"]
	if "--shooter" in OS.get_cmdline_user_args():
		library_override = "res://assets/animations/model1_shooter.tres"
	super._initialize()
