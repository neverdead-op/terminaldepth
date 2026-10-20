extends RefCounted
## Shared materials preserve UV textures; no per-frame texture or shader creation.
static var cache := {}

static func apply(model: Node3D) -> void:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D: meshes.append(model)
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			var key := source.get_instance_id()
			if not cache.has(key):
				var mat := ShaderMaterial.new()
				if source.resource_name.contains("Red foliage"):
					mat.shader = preload("res://assets/shaders/village_foliage.gdshader")
					mat.set_shader_parameter("leaf_map", source.albedo_texture)
				elif source.resource_name.contains("Lantern glass"):
					mat.shader = preload("res://assets/shaders/village_lantern.gdshader")
				else:
					mat.shader = preload("res://assets/shaders/village_weathered.gdshader")
					mat.set_shader_parameter("base_map", source.albedo_texture)
					mat.set_shader_parameter("has_texture", source.albedo_texture != null)
					mat.set_shader_parameter("tint", source.albedo_color)
					mat.set_shader_parameter("metalness", source.metallic)
				cache[key] = mat
			mesh.set_surface_override_material(surface, cache[key])
