@tool
extends Node
## Только дополнительный проход у оснований модулей Riverbank; импортированные материалы не меняются.
@export var enabled := true:
	set(value):
		enabled=value
		if is_inside_tree(): refresh.call_deferred()
@export_range(.05,1,.01) var blend_height := .2:
	set(value):
		blend_height=value
		if is_inside_tree(): refresh.call_deferred()
@export_range(0,.4,.01) var edge_breakup := .24:
	set(value):
		edge_breakup=value
		if is_inside_tree(): refresh.call_deferred()
var material: ShaderMaterial
var applied_count := 0
var _materials := {}

func owns_overlay(value: Material) -> bool:
	return value!=null and (value==material or value in _materials.values())

func _material_for(original: Material) -> ShaderMaterial:
	if not original is BaseMaterial3D: return material
	var id := original.get_instance_id()
	if not _materials.has(id):
		var copy := material.duplicate() as ShaderMaterial
		copy.set_shader_parameter("contact_has_texture",original.albedo_texture!=null)
		copy.set_shader_parameter("contact_source_tex",original.albedo_texture)
		copy.set_shader_parameter("contact_uv_scale",original.uv1_scale)
		copy.set_shader_parameter("contact_uv_offset",original.uv1_offset)
		_materials[id]=copy
	return _materials[id]

func _ready() -> void:
	refresh.call_deferred()

func refresh() -> void:
	var floor := get_parent().get_node_or_null("Geometry/Ground/Floor/Plane") as MeshInstance3D
	if floor==null: return
	var ground := floor.get_active_material(0) as ShaderMaterial
	if ground==null: return
	if material==null:
		material=ShaderMaterial.new()
		material.shader=preload("res://assets/shaders/riverbank_ground_contact.gdshader")
	for target in [material]+_materials.values():
		for uniform in ground.shader.get_shader_uniform_list():
			target.set_shader_parameter(uniform.name,ground.get_shader_parameter(uniform.name))
		target.set_shader_parameter("contact_ground_y",floor.global_position.y)
		target.set_shader_parameter("contact_height",blend_height)
		target.set_shader_parameter("contact_breakup",edge_breakup)
		target.set_shader_parameter("contact_limits",Vector3(floor.get_aabb().position.z,floor.get_aabb().end.z,floor.get_aabb().end.x))
	applied_count=0
	for node in get_parent().find_children("*","Node3D",true,false):
		if node.get_script()==preload("res://scripts/riverbank_module.gd"): apply_to_module(node)

func apply_to_module(module: Node3D) -> void:
	if material==null or not is_instance_valid(module): return
	var source: PackedScene=module.get("model_scene")
	if source==null: return
	var path := source.resource_path.to_lower()
	if "wall_lantern" in path: return
	var eligible := false
	for kind in ["wall","rock","cliff","bank_edge","pillar","buttress","roots_ground","dead_tree"]:
		if kind in path: eligible=true
	if not eligible: return
	for mesh: MeshInstance3D in module.find_children("*","MeshInstance3D",true,false):
		if mesh.material_overlay!=null and not owns_overlay(mesh.material_overlay): continue
		var bounds := mesh.global_transform*mesh.get_aabb()
		var ground_y: float=material.get_shader_parameter("contact_ground_y")
		var touches := bounds.position.y<ground_y+blend_height and bounds.end.y>ground_y
		mesh.material_overlay=_material_for(mesh.get_active_material(0)) if enabled and touches else null
		if owns_overlay(mesh.material_overlay): applied_count+=1
