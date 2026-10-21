@tool
extends Node3D
## Матрицы сохраняются в сцене на CPU; MultiMesh создаётся в действующем рендерере.
@export var placements: Array[Transform3D] = []

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 12:
		var angle := blade*2.399
		var side := Vector3(cos(angle),0,sin(angle))*.035
		var root := Vector3(sin(angle)*.28,0,cos(angle)*.28)
		var height := .4+float(blade%4)*.06
		var mid := root+Vector3(cos(angle)*.08,height*.55,sin(angle)*.08)
		var tip := mid+Vector3(cos(angle)*.15,height*.45,sin(angle)*.15)
		for v: Vector3 in [root-side,mid-side*.6,root+side,root+side,mid-side*.6,mid+side*.6,mid-side*.6,tip,mid+side*.6]:
			surface.set_uv(Vector2(0,clampf(v.y/height,0,1)))
			surface.set_color(Color.WHITE*(.85+float(blade%3)*.08))
			surface.add_vertex(v)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/environment/riverbank/materials/grass.gdshader")
	material.set_shader_parameter("ground_tex",preload("res://assets/environment/riverbank/textures/ground/stylized_v2/T_RB_Ground_Meadow_A_BaseColor.png"))
	mesh.surface_set_material(0,material)
	var container := Node3D.new()
	container.name = "_GrassTufts"
	add_child(container)
	# Небольшие участки отсекаются камерой отдельно: дальняя трава не рисуется целиком.
	var chunks := {}
	for transform in placements:
		var key := Vector2i(floori(transform.origin.x/24),floori(transform.origin.z/24))
		if not chunks.has(key): chunks[key] = []
		chunks[key].append(transform)
	for key: Vector2i in chunks:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = chunks[key].size()
		for i in chunks[key].size(): multi.set_instance_transform(i,chunks[key][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Patch_%s_%s" % [key.x,key.y]
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(instance)
