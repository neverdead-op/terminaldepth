extends "res://tools/bake_walking1.gd"
## Тот же перенос нижней части тела для нового бега и спринта вперёд.
func _initialize() -> void:
	source_path = "res://animation/Fast Run (1).fbx"
	target_clips = ["SP_run_forward", "SP_sprint_forward"]
	super._initialize()
