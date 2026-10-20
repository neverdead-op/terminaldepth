@tool
extends Node
const Look = preload("res://scripts/threshold_look.gd")
const PROFILE_PATH := "res://data/visual/threshold_saved.tres"
@export var profile: Resource = preload("res://data/visual/threshold_default.tres")
var materials: Array[ShaderMaterial] = []
var scene_root: Node

func _ready() -> void:
	scene_root = get_parent()
	profile = load(PROFILE_PATH).duplicate(true) if FileAccess.file_exists(PROFILE_PATH) else profile.duplicate(true)
	_gather()
	apply.call_deferred()

func _gather() -> void:
	materials.clear()
	var copies := {}
	for node in scene_root.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
		if mesh == null: continue
		for i in mesh.get_surface_count():
			var material: Material = node.get_active_material(i) if node is MeshInstance3D else mesh.surface_get_material(i)
			if material is not ShaderMaterial or material.shader == null: continue
			if not material.shader.resource_path.get_file() in ["threshold_surface.gdshader","threshold_cel.gdshader"]: continue
			var id: int = material.get_instance_id()
			if not copies.has(id):
				copies[id] = material.duplicate()
				materials.append(copies[id])
			if node is MeshInstance3D: node.set_surface_override_material(i,copies[id])
			else: mesh.surface_set_material(i,copies[id])

func apply() -> void:
	if not is_instance_valid(scene_root) or profile == null: return
	for material in materials:
		material.shader = load("res://assets/shaders/threshold_cel.gdshader" if profile.cel_enabled else "res://assets/shaders/threshold_surface.gdshader")
		for id in ["weathering","flat_normals","cel_amount","cel_steps","cel_softness"]: material.set_shader_parameter(id,profile.get(id))
		material.set_shader_parameter("rim_strength",profile.rim)
	var env: Environment = scene_root.get_node("WorldEnvironment").environment
	env.tonemap_exposure = profile.exposure;env.ambient_light_energy = profile.ambient
	env.glow_enabled = profile.bloom > 0;env.glow_intensity = profile.bloom;env.glow_hdr_threshold = profile.bloom_threshold
	env.ssao_enabled = profile.ssao;env.ssil_enabled = profile.ssil
	scene_root.get_node("ColdMoon").light_energy = profile.moon
	for light in scene_root.find_children("AmberLight*","OmniLight3D",true,false):
		if not light.has_meta("base_energy"): light.set_meta("base_energy",light.light_energy)
		light.light_energy = float(light.get_meta("base_energy"))*profile.warm_lights
		light.light_color = profile.warm_color
	var grade := scene_root.get_node("WorldGrade/ColorGrade").material as ShaderMaterial
	for pair in [["contrast_amount","contrast"],["saturation_amount","saturation"],["temperature","temperature"],["split_amount","split_tone"],["vignette_strength","vignette"],["softness","softness"],["posterize_amount","posterize"],["color_steps","color_steps"]]: grade.set_shader_parameter(pair[0],profile.get(pair[1]))
	var fluffy := scene_root.get_node("FluffyFog")
	fluffy.density = profile.courtyard_fog;fluffy.background_density = profile.background_cards
	for volume in scene_root.find_children("VolumeBillow*","FogVolume",true,false):
		var material := volume.material as ShaderMaterial
		material.set_shader_parameter("density",profile.volume_density)
		material.set_shader_parameter("cloud_scale",profile.cloud_scale)
		material.set_shader_parameter("wind",profile.wind)
		material.set_shader_parameter("cloud_color",profile.cloud_color)
	var camera := scene_root.get_node("OverviewCamera") as Camera3D
	if camera.attributes is CameraAttributesPractical:
		camera.attributes.dof_blur_far_enabled = profile.dof > 0
		camera.attributes.dof_blur_amount = profile.dof;camera.attributes.dof_blur_far_distance = profile.focus_distance
	profile.emit_changed()

func save_profile(path := PROFILE_PATH) -> Error:
	return ResourceSaver.save(profile,path)

func reload_profile(path := PROFILE_PATH) -> void:
	profile = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE).duplicate(true) if FileAccess.file_exists(path) else Look.new()
	apply()

func preset(graphic := false) -> void:
	profile = Look.new()
	if graphic:
		profile.cel_enabled = true;profile.cel_amount = .75;profile.cel_steps = 3;profile.cel_softness = .14
		profile.flat_normals = .65;profile.rim = .16;profile.contrast = 1.12;profile.saturation = .92
		profile.posterize = .18;profile.color_steps = 20
	apply()
