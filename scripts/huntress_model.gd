extends "res://scripts/shooter_model.gd"
## Approved rig: ordinary animation, without the deferred cloth experiment.
@export_range(0.0, 1.0) var coat_follow := 0.72
@export_range(1.0, 30.0) var cloth_response := 12.0

func _enter_tree() -> void:
	super._enter_tree()
	var skeleton := get_node("Armature/Skeleton3D") as Skeleton3D
	if not skeleton.has_node("CoatMotion"):
		var coat := preload("res://scripts/huntress_cloth_modifier.gd").new()
		coat.name = "CoatMotion"
		coat.follow = coat_follow
		coat.response = cloth_response
		skeleton.add_child(coat)
