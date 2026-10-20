extends SceneTree
const Transfer := preload("res://tools/animation_transfer.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var model := preload("res://assets/characters/huntress_player.tscn").instantiate()
	root.add_child(model)
	var sk := model.get_node("Armature/Skeleton3D") as Skeleton3D
	var lib: AnimationLibrary = load("res://assets/animations/huntress_shooter.tres")
	for name in lib.get_animation_list():
		if not name.begins_with("SP_walk") and name != "SP_idle":continue
		var clip := lib.get_animation(name)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for f in 61:
			var p := Transfer.poses(sk, clip, clip.length * f / 60.0)
			for side in 2:
				var height := p[sk.find_bone("ball_l" if side == 0 else "ball_r")].origin.y
				lo[side] = minf(lo[side], height)
				hi[side] = maxf(hi[side], height)
		print(name, " min=", lo, " max=", hi)
	model.free()
	quit()
