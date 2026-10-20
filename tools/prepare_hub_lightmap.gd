extends SceneTree
## Separate snapshot for LightmapGI experiments. Source hub is never overwritten.
const OUTPUT := "res://scenes/tools/hub_lightmap_preview.tscn"
var converted := 0
var mesh_cache := {}

func _initialize() -> void:
	call_deferred("_prepare")

func _prepare() -> void:
	if FileAccess.file_exists(OUTPUT) and "--overwrite-preview" not in OS.get_cmdline_user_args():
		push_error("Preview already exists. Use --overwrite-preview only when preparing a fresh bake; hub.tscn remains untouched.")
		quit(1)
		return
	var hub := load("res://scenes/hub.tscn").instantiate() as Node3D
	_expand(hub)
	_own(hub, hub)
	var gi := LightmapGI.new()
	gi.name = "BakedLighting"
	gi.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	gi.bounces = 3
	gi.texel_scale = 1.0
	gi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_8
	gi.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	gi.environment_custom_color = Color(0.62, 0.69, 0.8)
	gi.environment_custom_energy = 0.35
	hub.add_child(gi)
	gi.owner = hub
	hub.move_child(gi, 0)
	for node in hub.find_children("*", "MeshInstance3D", true, false):
		if hub.get_node("Moon").is_ancestor_of(node):
			node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			continue
		var source: Mesh = node.mesh
		if source == null: continue
		var key := source.get_instance_id()
		if not mesh_cache.has(key):
			var mesh := ArrayMesh.new()
			for surface in source.get_surface_count():
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
				mesh.surface_set_material(surface, source.surface_get_material(surface))
			var result := mesh.lightmap_unwrap(Transform3D.IDENTITY, 0.14)
			if result != OK:
				push_error("UV2 unwrap failed: " + str(node.name) + " / " + str(result))
				quit(1)
				return
			mesh_cache[key] = mesh
			node.mesh = mesh
		else:
			node.mesh = mesh_cache[key]
		node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		converted += 1
	var env: Environment = hub.get_node("WorldEnvironment").environment.duplicate()
	env.ambient_light_energy = 0.35
	hub.get_node("WorldEnvironment").environment = env
	var scene := PackedScene.new()
	assert(scene.pack(hub) == OK)
	assert(ResourceSaver.save(scene, OUTPUT) == OK)
	print("HUB_LIGHTMAP_PREPARED: ", converted, " static meshes, original layout preserved: ", OUTPUT)
	hub.free()
	quit()

func _expand(node: Node) -> void:
	if node.get_script() == load("res://scripts/model_batch.gd"):
		var model: PackedScene = node.model
		var transforms: PackedFloat32Array = node.transforms
		var tint: Color = node.tint
		var shadows: bool = node.cast_shadows
		if model != null:
			var source := model.instantiate()
			for mi in source.find_children("*", "MeshInstance3D", true, false):
				var local := Transform3D.IDENTITY
				var n: Node = mi
				while n != source and n != null:
					if n is Node3D: local = n.transform * local
					n = n.get_parent()
				for i in transforms.size() / 12:
					var o: int = i * 12
					var t := Transform3D(Basis(Vector3(transforms[o], transforms[o+1], transforms[o+2]), Vector3(transforms[o+3], transforms[o+4], transforms[o+5]), Vector3(transforms[o+6], transforms[o+7], transforms[o+8])), Vector3(transforms[o+9], transforms[o+10], transforms[o+11]))
					var visual := MeshInstance3D.new()
					visual.name = "Static_%s_%s" % [mi.name, i]
					visual.mesh = mi.mesh if tint == Color.WHITE else node._tinted_mesh(mi.mesh)
					visual.transform = t * local
					visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					node.add_child(visual)
			source.free()
		node.set_script(null)
	for child in node.get_children():
		_expand(child)

func _own(node: Node, root_node: Node) -> void:
	if node != root_node:
		node.owner = root_node
		node.scene_file_path = ""
	for child in node.get_children(): _own(child, root_node)
