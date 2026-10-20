extends SceneTree
## Validate actual skin bindings and sampled deformations for all gameplay clips.
const Model := preload("res://assets/characters/huntress_player.tscn")
const Transfer := preload("res://tools/animation_transfer.gd")
var model_scene: PackedScene = Model
var mesh_name := "RedHuntress"
var library_override := ""
var required_bones := ["pelvis", "Head", "hand_l", "hand_r", "ball_l", "ball_r", "coat_l", "coat_r", "scarf"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var model := model_scene.instantiate()
	if not library_override.is_empty():
		model.animation_library_path = library_override
	root.add_child(model)
	var sk := model.get_node("Armature/Skeleton3D") as Skeleton3D
	assert(sk.get_bone_parent(sk.find_bone("pelvis")) < 0)
	for name in required_bones:
		assert(sk.find_bone(name) >= 0)
	var mesh := sk.find_child(mesh_name, true, false) as MeshInstance3D
	assert(mesh != null and mesh.skin != null)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := weights.size() / vertices.size()
	assert(stride == 4 or stride == 8)
	var material := mesh.get_active_material(0) as StandardMaterial3D
	assert(material.albedo_texture != null and material.normal_texture != null)
	assert(material.roughness_texture != null)
	assert(vertices.size() < 70000)
	var bind_bones: Array[int] = []
	for i in mesh.skin.get_bind_count():
		var name := mesh.skin.get_bind_name(i)
		var index := sk.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(i)
		assert(index >= 0)
		bind_bones.append(index)
	var max_bind_error := 0.0
	for v in vertices.size():
		var total := 0.0
		var rest := Vector3.ZERO
		for j in stride:
			var w := weights[v * stride + j]
			assert(is_finite(w) and w >= 0)
			if w <= 0: continue
			total += w
			var bind := bones[v * stride + j]
			rest += (sk.get_bone_global_rest(bind_bones[bind]) * mesh.skin.get_bind_pose(bind) * vertices[v]) * w
		assert(absf(total - 1.0) < 0.002)
		max_bind_error = maxf(max_bind_error, rest.distance_to(vertices[v]))
	assert(max_bind_error < 0.002, "Bind pose must reproduce the original mesh")
	var library: AnimationLibrary = load(model.animation_library_path)
	assert(library.get_animation_list().size() >= 36)
	var samples := 0
	var idle_min_y := INF
	for name in library.get_animation_list():
		var clip := library.get_animation(name)
		for f in 9:
			var poses := Transfer.poses(sk, clip, clip.length * f / 8.0)
			for v in range(0, vertices.size(), 53):
				var point := Vector3.ZERO
				for j in stride:
					var w := weights[v * stride + j]
					if w <= 0: continue
					var bind := bones[v * stride + j]
					point += (poses[bind_bones[bind]] * mesh.skin.get_bind_pose(bind) * vertices[v]) * w
				assert(point.is_finite() and point.length() < 3.5, "Invalid deformed mesh in " + name)
				if name == "SP_idle": idle_min_y = minf(idle_min_y, point.y)
				samples += 1
	print("HUNTRESS_SKIN_OK: vertices=", vertices.size(), " bones=", sk.get_bone_count(), " bind_error=", max_bind_error, " sampled_vertices=", samples, " clips=", library.get_animation_list().size(), " idle_sole_y=", idle_min_y)
	model.free()
	quit()
