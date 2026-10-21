extends SceneTree
## Пересобирает пол, границы, навигацию, траву и маркеры по утверждённой петле Riverbank.
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
	var ground_material := build_ground_material()
	st.set_material(ground_material)
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
	# Земля заполняет кадр, коллизия и проходы следуют петле MapTsukuri.
	var walk_surface := SurfaceTool.new()
	walk_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-75,6,3):
		for x in range(-60,54,3):
			var at := Vector2(x+1.5,z+1.5)
			if not Layout.on_land(at): continue
			for v: Vector3 in [Vector3(x,0,z),Vector3(x+3,0,z),Vector3(x+3,0,z+3),Vector3(x,0,z),Vector3(x+3,0,z+3),Vector3(x,0,z+3)]:
				walk_surface.add_vertex(v)
			for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				if Layout.on_land(at+direction*3): continue
				var edge: Vector2 = at+direction*1.5
				barrier(boundaries,Vector3(edge.x,0,edge.y),Vector3(3.1,2,.25) if direction.x==0 else Vector3(.25,2,3.1))
	var mesh := st.commit()
	map_root.get_node("Geometry/Ground/Floor/Plane").mesh = mesh
	map_root.get_node("Geometry/Ground/Floor/Shape").shape = walk_surface.commit().create_trimesh_shape()
	map_root.get_node("Spawn").position = Layout.START+Vector3.UP*.15
	map_root.get_node("Markers/Finish").position = Layout.FINISH+Vector3.UP*.1
	map_root.get_node("Markers/OptionalLoot").position = Layout.POCKET+Vector3.UP*.1
	for i in 3: map_root.get_node("Encounters/Pack%d" % (i+1)).position = Layout.PACKS[i]
	var loot_marker := map_root.get_node("Markers/OptionalLoot")
	var chest := loot_marker.get_node_or_null("OptionalReward")
	if chest == null:
		chest = Node3D.new()
		chest.name = "OptionalReward"
		loot_marker.add_child(chest)
		chest.owner = map_root
	chest.set_script(load("res://scripts/loot_chest.gd"))
	chest.set("rarity",1)
	chest.set("sprite",load("res://assets/environment/graveyard_2d/chest.png"))
	chest.position = Vector3(0,0,-3)
	# Предыдущая ручная основа сохранена вне игровой области; новые ориентиры в Dressing.
	var previous: Node3D = map_root.get_node("Geometry/Landmarks")
	previous.visible = false
	previous.position.y = -500
	var cover := map_root.get_node_or_null("Geometry/GroundCover")
	if cover != null:
		cover.get_parent().remove_child(cover)
		cover.free()
	cover = Node3D.new()
	cover.name = "GroundCover"
	map_root.get_node("Geometry").add_child(cover)
	cover.owner = map_root
	preload("res://tools/build_riverbank_ground_cover.gd").populate(cover,map_root,ground_material)
	var nav: NavigationRegion3D = map_root.get_node("Navigation")
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = .75
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = .25
	nav_mesh.cell_size = .25
	nav_mesh.cell_height = .25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.filter_baking_aabb = AABB(Vector3(-75,-.8,-85),Vector3(140,2.0,110))
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
	map_root.get_node("OverviewCamera").position = Vector3(0,140,30)
	map_root.get_node("OverviewCamera").size = 135
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
	var courts: Array[Vector2] = [Vector2(-36,-16),Vector2(33,-20),Vector2(0,-63),Vector2(-6,-4)]
	for z in range(int(Layout.NORTH)-2, int(Layout.SOUTH)+4, 2):
		for x in range(-82, int(Layout.EAST)+4, 2):
			var at := Vector2(x+1,z+1)
			var n := noise.get_noise_2dv(at)
			var variant := 2
			if n>.05 or (x>20 and z < -30): variant = 4
			if z < -42 and x < -15: variant = 0
			for court in courts:
				if at.distance_to(court) < 10.0+n*5.0: variant = 0
			# Вне игровых дворов — единое зелёное поле, внутри — травяные полосы у оград.
			if not Layout.on_land(at) or not Layout.on_land(at,2.5): variant = 1
			variants[Vector2i(x,z)] = variant
	var prefix := "res://assets/environment/riverbank/textures/ground/stylized_v2/T_RB_Ground_"
	var textures: Array[Texture2D] = []
	for kind in ["Flagstone","Meadow","Soil","Flagstone","Moss","Soil"]:
		textures.append(load(prefix+kind+("_A_Bright_BaseColor.png" if kind=="Moss" else "_A_BaseColor.png")))
	# Общая система деревни строит только материал и веса; точный береговой меш сохраняем.
	var preview := BlendedFloor.build(variants,textures,PackedFloat32Array([4,6,6,4,6,6]),
		PackedFloat32Array([.05,.05,.08,.05,.02,.08]),PackedFloat32Array([.02,.02,.01,.02,.01,.01]),4,.12)
	var material := preview.material_override as ShaderMaterial
	material.set_shader_parameter("height_blend",.06)
	material.set_shader_parameter("edge_softness",.28)
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
