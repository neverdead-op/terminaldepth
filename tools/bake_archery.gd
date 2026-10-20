extends SceneTree
const Transfer := preload("res://tools/animation_transfer.gd")
const Model := preload("res://scripts/shooter_model.gd")
var target: Skeleton3D
var library: AnimationLibrary
func _initialize() -> void:
	_run.call_deferred()
func add_clip(path: String, name: StringName, looped := true) -> void:
	var node: Node = load(path).instantiate()
	root.add_child(node)
	var sk := node.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source_name := ap.get_animation_list()[0]
	if ap.has_animation("mixamo_com"): source_name = "mixamo_com"
	var source: Animation = ap.get_animation(source_name).duplicate(true)
	# The supplied Ch33 pack has numbered namespaces (mixamorig7_, etc.).
	var prefix := RegEx.new()
	prefix.compile("^mixamorig[0-9]*[_:]")
	var aliases := {}
	for i in sk.get_bone_count():
		var original := sk.get_bone_name(i)
		aliases[original] = Model.bone_alias(prefix.sub(original, ""))
		sk.set_bone_name(i, aliases[original])
	for track in source.get_track_count():
		var original := String(source.track_get_path(track).get_concatenated_subnames())
		if aliases.has(original): source.track_set_path(track, NodePath("Skeleton3D:" + aliases[original]))
	var clip := Transfer.bake(sk, target, source, looped)
	assert(clip.get_track_count() > 40, "Unmapped animation bones in " + path)
	var hip := sk.find_bone("pelvis")
	if hip >= 0:
		var first := Transfer.poses(sk, source, 0)[hip].origin
		var last := Transfer.poses(sk, source, source.length)[hip].origin
		var speed := Vector2(last.x-first.x, last.z-first.z).length() / source.length
		if speed > 0.1: clip.set_meta("locomotion_speed", speed * target.get_bone_global_rest(target.find_bone("pelvis")).origin.y / sk.get_bone_global_rest(hip).origin.y)
	library.add_animation(name, clip)
	print("ARCHERY_CLIP ", name, " ", clip.length)
	node.free()
func _run() -> void:
	var model := Model.new()
	model.source_path = "res://assets/characters/red_huntress/v1/huntress.glb"
	root.add_child(model)
	target = model.get_node("Armature/Skeleton3D")
	library = load("res://assets/animations/huntress_shooter.tres").duplicate(true)
	for name in ["idle", "idle (2)", "idle (3)", "idle (4)", "idle (5)", "running", "walking"]:
		add_clip("res://animation/pack 12/action/" + name + ".fbx", StringName("ADV_" + name.replace(" ", "_")), true)
	add_clip("res://animation/longbow_ch33/standing idle 01.fbx", &"Bow_Idle")
	for mode in ["walk", "run"]:
		for direction in ["forward", "back", "left", "right"]:
			add_clip("res://animation/longbow_ch33/standing %s %s.fbx" % [mode, direction], StringName("LB_" + mode + "_" + direction))
	for mode in ["walk", "run", "sprint"]:
		for direction in ["forward", "forward_right", "right", "backward_right", "backward", "backward_left", "left", "forward_left"]:
			var source_dir: String = {"backward":"back", "forward_right":"forward", "forward_left":"forward", "backward_right":"back", "backward_left":"back"}.get(direction, direction)
			var clip: Animation = library.get_animation("ADV_running" if mode == "sprint" else "LB_" + mode + "_" + source_dir).duplicate(true)
			var yaw: float = {"forward_right":-45.0,"forward_left":45.0,"backward_right":45.0,"backward_left":-45.0}.get(direction, 0.0)
			if mode == "sprint": yaw = {"forward":0.0,"forward_right":-45.0,"right":-90.0,"backward_right":-135.0,"backward":180.0,"backward_left":135.0,"left":90.0,"forward_left":45.0}[direction]
			if yaw != 0:
				for track in clip.get_track_count():
					if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and String(clip.track_get_path(track).get_concatenated_subnames()) == "pelvis":
						for key in clip.track_get_key_count(track): clip.track_set_key_value(track,key,Quaternion(Vector3.UP,deg_to_rad(yaw)) * clip.track_get_key_value(track,key))
			var name := StringName("SP_" + mode + "_" + direction)
			library.remove_animation(name)
			library.add_animation(name, clip)
	assert(ResourceSaver.save(library, "res://assets/animations/huntress_archery.tres") == OK)
	model.free()
	print("ARCHERY_BAKE_OK")
	quit()
