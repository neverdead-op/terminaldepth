@tool
extends Node
## Переходная геометрия по настоящему сечению меша. Вертикальные стены не перекрашиваются.
@export var enabled := true:
	set(value):
		enabled=value
		_queue_refresh()
## Старый параметр сохранён: ограничивает высоту поиска контакта.
@export_range(.05,1,.01) var blend_height := .2:
	set(value):
		blend_height=value
		_queue_refresh()
@export_range(0,.4,.01) var edge_breakup := .24:
	set(value):
		edge_breakup=value
		_queue_refresh()
@export_range(.08,.6,.01) var blend_width := .28:
	set(value):
		blend_width=value
		_queue_refresh()
@export_range(.02,.12,.005) var contact_lift := .055:
	set(value):
		contact_lift=value
		_queue_refresh()
var material: ShaderMaterial
var applied_count := 0
var triangle_count := 0
var _materials := {}
var _queued := false
static var _cuts := {}

func _ready() -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if not is_inside_tree() or _queued: return
	_queued=true
	refresh.call_deferred()

func owns_overlay(value: Material) -> bool:
	return value is ShaderMaterial and value.shader!=null and value.shader.resource_path=="res://assets/shaders/riverbank_ground_contact.gdshader"

func apply_to_module(_module: Node3D) -> void:
	_queue_refresh()

func _material_for(original: Material) -> ShaderMaterial:
	if not original is BaseMaterial3D: return material
	var id := original.get_instance_id()
	if not _materials.has(id):
		var copy := material.duplicate() as ShaderMaterial
		copy.set_shader_parameter("source_has_texture",original.albedo_texture!=null)
		copy.set_shader_parameter("source_tex",original.albedo_texture)
		copy.set_shader_parameter("source_tint",original.albedo_color)
		copy.set_shader_parameter("source_uv_scale",original.uv1_scale)
		copy.set_shader_parameter("source_uv_offset",original.uv1_offset)
		copy.set_shader_parameter("source_roughness",original.roughness)
		copy.set_shader_parameter("source_metallic",original.metallic)
		_materials[id]=copy
	return _materials[id]

func refresh() -> void:
	_queued=false
	var previous := get_node_or_null("_GroundSkirts")
	if previous!=null:
		remove_child(previous)
		previous.free()
	applied_count=0
	triangle_count=0
	var floor := get_parent().get_node_or_null("Geometry/Ground/Floor/Plane") as MeshInstance3D
	if floor==null: return
	var ground := floor.get_active_material(0) as ShaderMaterial
	if ground==null: return
	if material==null or material.shader!=preload("res://assets/shaders/riverbank_contact_skirt.gdshader"):
		_materials.clear()
		material=ShaderMaterial.new()
		material.shader=preload("res://assets/shaders/riverbank_contact_skirt.gdshader")
	for target in [material]+_materials.values():
		for uniform in ground.shader.get_shader_uniform_list():
			target.set_shader_parameter(uniform.name,ground.get_shader_parameter(uniform.name))
		target.set_shader_parameter("contact_limits",Vector3(floor.get_aabb().position.z,floor.get_aabb().end.z,floor.get_aabb().end.x))
	var generated := Node3D.new()
	generated.name="_GroundSkirts"
	add_child(generated)
	generated.top_level=true
	generated.global_transform=Transform3D.IDENTITY
	var batches := {}
	var ground_y := floor.global_position.y
	for module in get_parent().find_children("*","Node3D",true,false):
		if module.get_script()!=preload("res://scripts/riverbank_module.gd"): continue
		var source: PackedScene=module.get("model_scene")
		if source==null: continue
		var path := source.resource_path.to_lower()
		var eligible := false
		for kind in ["wall","rock","cliff","bank_edge","pillar","buttress","roots_ground","dead_tree"]:
			if kind in path: eligible=true
		if "wall_lantern" in path: eligible=false
		for mesh: MeshInstance3D in module.find_children("*","MeshInstance3D",true,false):
			if owns_overlay(mesh.material_overlay): mesh.material_overlay=null
			if not enabled or not eligible or not mesh.is_visible_in_tree() or mesh.mesh==null: continue
			var bounds := mesh.global_transform*mesh.get_aabb()
			if bounds.position.y>ground_y+blend_height or bounds.end.y<ground_y+contact_lift: continue
			var local_plane: Plane=mesh.global_transform.affine_inverse()*Plane(Vector3.UP,ground_y+contact_lift)
			var normal_matrix := mesh.global_basis.inverse().transposed()
			var found := false
			for surface in mesh.mesh.get_surface_count():
				var segments := _section(mesh.mesh,surface,local_plane)
				if segments.is_empty(): continue
				found=true
				var original := mesh.get_active_material(surface)
				var key := str(original.get_instance_id() if original!=null else 0)+":"+str(Vector2i(floori(bounds.get_center().x/24),floori(bounds.get_center().z/24)))
				if not batches.has(key):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tool.set_material(_material_for(original))
					batches[key]=tool
				var tool: SurfaceTool=batches[key]
				var joints := {}
				for segment: Array in segments:
					for endpoint in 2:
						var joint := Vector3i((segment[endpoint*3]*10000.0).round())
						var normal: Vector3=normal_matrix*segment[endpoint*3+1]
						var direction := Vector3(normal.x,0,normal.z).normalized()
						joints[joint]=joints.get(joint,Vector3.ZERO)+direction
				for segment: Array in segments:
					var points: Array[Vector3]=[]
					var normals: Array[Vector3]=[]
					for endpoint in 2:
						var point: Vector3=mesh.global_transform*segment[endpoint*3]
						var normal: Vector3=(normal_matrix*segment[endpoint*3+1]).normalized()
						var out := Vector3(normal.x,0,normal.z)
						if out.length_squared()<.01: out=Vector3(1,0,0)
						out=out.normalized()
						var joint := Vector3i((segment[endpoint*3]*10000.0).round())
						var joined: Vector3=joints[joint].normalized()
						if joined.length_squared()>.01: out=joined/maxf(.5,joined.dot(out))
						var width := blend_width*(1.0+sin(point.x*2.7+point.z*1.8)*edge_breakup)
						width=minf(width,minf(module.target_size.x,module.target_size.z)*.14)
						for row in 2:
							var fraction := float(row)
							var vertex := point+out*(.001+fraction*width)
							vertex.y=lerpf(ground_y+contact_lift,ground_y+.002,fraction)
							points.append(vertex)
							normals.append(normal.lerp(Vector3.UP,smoothstep(0,1,fraction)).normalized())
					var indices: Array[int]=[0,1,2,2,1,3]
					if (points[1]-points[0]).cross(points[2]-points[0]).y>0: indices=[0,2,1,2,3,1]
					for index in indices:
						tool.set_normal(normals[index])
						tool.set_uv(segment[2 if index<2 else 5])
						tool.set_uv2(Vector2(float(index%2),0))
						tool.add_vertex(points[index])
					triangle_count+=2
			if found: applied_count+=1
	for key in batches:
		var instance := MeshInstance3D.new()
		instance.mesh=batches[key].commit()
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		generated.add_child(instance)

## Сечение кэшируется в координатах исходного меша: одинаковые модули не разбираются повторно.
static func _section(mesh: Mesh,surface: int,plane: Plane) -> Array:
	var key := str(mesh.get_instance_id())+":"+str(surface)+":"+str(plane.normal.snapped(Vector3.ONE*.00001))+":"+str(snappedf(plane.d,.00001))
	if _cuts.has(key): return _cuts[key]
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var result := []
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for triangle in range(0,count,3):
		var hits := []
		for edge in 3:
			var a: int=indices[triangle+edge] if not indices.is_empty() else triangle+edge
			var b: int=indices[triangle+(edge+1)%3] if not indices.is_empty() else triangle+(edge+1)%3
			var da := plane.distance_to(vertices[a])
			var db := plane.distance_to(vertices[b])
			if (da>0)==(db>0) or absf(da-db)<.000001: continue
			var t := da/(da-db)
			var normal := normals[a].lerp(normals[b],t).normalized() if normals.size()==vertices.size() else (vertices[b]-vertices[a]).cross(plane.normal).normalized()
			var uv := uvs[a].lerp(uvs[b],t) if uvs.size()==vertices.size() else Vector2.ZERO
			hits.append_array([vertices[a].lerp(vertices[b],t),normal,uv])
		if hits.size()==6: result.append(hits)
	_cuts[key]=result
	return result
