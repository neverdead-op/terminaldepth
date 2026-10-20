extends SceneTree
## Save reusable static scenes with geometry-matching collision. Decorative doors remain static.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var folder := "res://assets/environment/victorian_kit/v1/"
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(folder + "catalog.json"))
	DirAccess.make_dir_recursive_absolute(folder + "scenes")
	for entry in entries:
		var scene := load(folder + entry.id + ".glb") as PackedScene
		assert(scene != null)
		var body := StaticBody3D.new()
		body.name = entry.id.to_pascal_case()
		root.add_child(body)
		var model := scene.instantiate() as Node3D
		model.name = "Visual"
		body.add_child(model)
		model.owner = body
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D: meshes.append(model)
		for mesh: MeshInstance3D in meshes:
			assert(mesh.mesh.get_surface_count() > 0)
			var collision := CollisionShape3D.new()
			collision.shape = mesh.mesh.create_trimesh_shape()
			collision.shape.backface_collision = true
			body.add_child(collision)
			collision.transform = body.global_transform.affine_inverse() * mesh.global_transform
			collision.owner = body
		var packed := PackedScene.new()
		assert(packed.pack(body) == OK)
		var path: String = folder + "scenes/" + entry.id + ".tscn"
		assert(ResourceSaver.save(packed, path) == OK)
		var loaded := load(path).instantiate() as StaticBody3D
		assert(loaded != null and loaded.find_children("*", "CollisionShape3D", true, false).size() > 0)
		loaded.free()
		body.free()
	# Check alpha on generated cutouts; preserve original files without pixel editing.
	for name in ["red_leaves", "red_petal"]:
		var texture := load("res://assets/buildings/village_nature/textures/" + name + ".png") as Texture2D
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		assert(image != null and image.detect_alpha() != Image.ALPHA_NONE)
	print("VICTORIAN_KIT_READY: ", entries.size(), " textured modules, matching static collision scenes, leaf/petal alpha verified")
	quit()
