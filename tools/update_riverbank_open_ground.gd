extends SceneTree
## Меняет только пол, границы и навигацию Riverbank; существующие ориентиры и маркеры сохраняет.
const Layout := preload("res://scripts/riverbank_layout.gd")
const BlendedFloor := preload("res://scripts/blended_floor.gd")
const OUTPUT := "res://scenes/art/riverbank_blockout.tscn"
var map_root: Node3D
func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	get_root().get_node("Game").set("testing", true)
	map_root = load(OUTPUT).instantiate()
	var boundaries: Node3D = map_root.get_node("Geometry/Boundaries")
	for child in boundaries.get_children():
		boundaries.remove_child(child)
		child.free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(build_ground_material())
	# Плавный контур берега: точные вершины, без клетчатого силуэта.
	for row in range(int(Layout.NORTH),int(Layout.SOUTH),2):
		var z := float(row)
		var a := Vector3(Layout.shore_x(z),0,z)
		var b := Vector3(Layout.EAST,0,z)
		var c := Vector3(Layout.EAST,0,z+2)
		var d := Vector3(Layout.shore_x(z+2),0,z+2)
		for v: Vector3 in [a,b,c,a,c,d]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x,v.z)/3)
			st.add_vertex(v)
		barrier(boundaries,(a+d)*0.5,Vector3(0.3,1.4,2.2))
	barrier(boundaries,Vector3(Layout.EAST,0,(Layout.NORTH+Layout.SOUTH)/2),Vector3(.4,2,Layout.SOUTH-Layout.NORTH))
	barrier(boundaries,Vector3(0,0,Layout.NORTH),Vector3(160,2,.4))
	barrier(boundaries,Vector3(0,0,Layout.SOUTH),Vector3(160,2,.4))
	var mesh := st.commit()
	map_root.get_node("Geometry/Ground/Floor/Plane").mesh = mesh
	map_root.get_node("Geometry/Ground/Floor/Shape").shape = mesh.create_trimesh_shape()
	var nav: NavigationRegion3D = map_root.get_node("Navigation")
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = .75
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = .25
	nav_mesh.cell_size = .25
	nav_mesh.cell_height = .25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.filter_baking_aabb = AABB(Vector3(-95,-.8,-178),Vector3(166,2.0,225))
	nav.navigation_mesh = nav_mesh
	get_root().add_child(map_root)
	await process_frame
	await process_frame
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh,source,map_root)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh,source)
	assert(nav_mesh.get_polygon_count()>0,"Open shore navigation is empty")
	var water: MeshInstance3D = map_root.get_node("Backdrop/River/Surface")
	var mat := water.mesh.surface_get_material(0).duplicate() as ShaderMaterial
	var rings := PackedVector3Array()
	for i in range(16):
		var z := -168.0+i*14
		var x := Layout.shore_x(z)-12-(i%3)*4
		rings.append(Vector3(x,z,1.8))
	mat.set_shader_parameter("foam_rocks",rings)
	assert(ResourceSaver.save(mat,"res://assets/environment/riverbank/materials/water_surface.tres")==OK)
	# Dummy-рендер headless не отражает значения по умолчанию шейдера: оставляем их в самом шейдере.
	var material_file := "res://assets/environment/riverbank/materials/water_surface.tres"
	var lines := FileAccess.get_file_as_string(material_file).split("\n")
	var clean := ""
	for line in lines:
		if not line.ends_with(" = null"): clean += line+"\n"
	FileAccess.open(material_file,FileAccess.WRITE).store_string(clean.strip_edges()+"\n")
	water.material_override = mat
	map_root.get_node("OverviewCamera").position = Vector3(0,180,5)
	map_root.get_node("OverviewCamera").size = 245
	# Берём эффективные параметры рига: его _ready переопределяет FOV дочерней камеры.
	var lunar: Node3D = load("res://scenes/lunar_intro.tscn").instantiate()
	var source_rig: Node3D = lunar.get_node("CameraRig")
	var target_rig := map_root.get_node("CameraRig")
	for property in ["distance", "elevation_degrees", "fov_degrees", "use_distance_angle", "offset", "follow_speed"]:
		target_rig.set(property, source_rig.get(property))
	target_rig.get_node("Camera3D").fov = source_rig.fov_degrees
	lunar.free()
	var packed := PackedScene.new()
	assert(packed.pack(map_root)==OK)
	assert(ResourceSaver.save(packed,OUTPUT)==OK)
	print("RIVERBANK_OPEN_GROUND_OK polygons=",nav_mesh.get_polygon_count())
	quit()

func build_ground_material() -> ShaderMaterial:
	var variants := {}
	var noise := FastNoiseLite.new()
	noise.seed = 73119
	noise.frequency = 0.055
	var courts: Array[Vector2] = [Vector2(-20,12), Vector2(-38,-24), Vector2(22,-64), Vector2(-30,-114), Vector2(-10,-144)]
	for z in range(int(Layout.NORTH)-2, int(Layout.SOUTH)+4, 2):
		for x in range(-82, int(Layout.EAST)+4, 2):
			var at := Vector2(x+1,z+1)
			var n := noise.get_noise_2dv(at)
			var variant := 1
			if n < -0.12: variant = 2
			if n > 0.16: variant = 4
			if x < Layout.shore_x(z)+9: variant = 2
			for court in courts:
				if at.distance_to(court) < 11.0+n*8.0: variant = 0
			variants[Vector2i(x,z)] = variant
	var textures: Array[Texture2D] = [load("res://assets/environment/riverbank/materials/flagstones_albedo.png"),
		load("res://assets/environment/riverbank/textures/ground/T_RB_Ground_QuayCobble_A_BaseColor.png"),
		load("res://assets/environment/riverbank/textures/ground/T_RB_Ground_RiverSilt_A_BaseColor.png"),
		load("res://assets/environment/riverbank/textures/ground/T_RB_Ground_QuayCobble_A_BaseColor.png"),
		load("res://assets/environment/riverbank/textures/ground/T_RB_Ground_MossRubble_A_BaseColor.png"),
		load("res://assets/environment/riverbank/textures/ground/T_RB_Ground_RiverSilt_A_BaseColor.png")]
	# Общая система деревни строит только материал и веса; точный береговой меш сохраняем.
	var preview := BlendedFloor.build(variants,textures,PackedFloat32Array([3,5,5.5,5,5,5.5]),
		PackedFloat32Array([.12,.15,.25,.15,.05,.25]),PackedFloat32Array([.12,.1,.05,.1,.08,.05]),2,.7)
	var material := preview.material_override as ShaderMaterial
	material.set_shader_parameter("height_blend",.35)
	material.set_shader_parameter("edge_softness",.12)
	var output := "res://assets/environment/riverbank/materials/ground_open.tres"
	assert(ResourceSaver.save(material,output)==OK)
	var clean := ""
	for line in FileAccess.get_file_as_string(output).split("\n"):
		if not line.ends_with(" = null"): clean += line+"\n"
	FileAccess.open(output,FileAccess.WRITE).store_string(clean.strip_edges()+"\n")
	material.take_over_path(output)
	preview.free()
	return material

func barrier(parent: Node3D,at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CoastBoundary"
	body.position = at + Vector3.UP*.5
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body,true)
	body.owner = map_root
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	shape.owner = map_root
