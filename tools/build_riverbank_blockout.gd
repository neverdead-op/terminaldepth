extends SceneTree
## Собирает только отдельный макет берега; существующие уровни не затрагивает.
const OUTPUT := "res://scenes/art/riverbank_blockout.tscn"
const STEP := 2.0
const Layout := preload("res://scripts/riverbank_layout.gd")
const MODULE_DIR := "res://assets/environment/riverbank/modules/"
var map_root: Node3D
var cells: Dictionary = {}
var stone: StandardMaterial3D
var wall: StandardMaterial3D
var gold: StandardMaterial3D
var mesh_floor: BoxMesh
var shape_floor: BoxShape3D

func _initialize() -> void:
	map_root = Node3D.new()
	map_root.name = "RiverbankBlockout"
	map_root.set_script(load("res://scripts/riverbank_level.gd"))
	stone = material(Color("747d89"))
	wall = material(Color("434657"))
	gold = material(Color("ce9851"))
	var geometry := group(map_root, "Geometry")
	var ground := group(geometry, "Ground")
	var bounds := group(geometry, "Boundaries")
	var landmarks := group(geometry, "Landmarks")
	var water := group(map_root, "Backdrop")
	var encounters := group(map_root, "Encounters")
	var markers := group(map_root, "Markers")
	var lighting := group(map_root, "Lighting")
	var route: Array[Vector2] = []
	for point: Vector3 in Layout.ROUTE: route.append(Vector2(point.x,point.z))
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		for k in range(int(a.distance_to(b)) + 1):
			paint_disc(a.lerp(b, float(k) / maxf(a.distance_to(b), 1.0)), 5.0 if i == 8 else 6.0)
	for point: Vector3 in Layout.PACKS: paint_disc(Vector2(point.x,point.z),12.0)
	for x in range(20,43): paint_disc(Vector2(x,-64),4.5)
	paint_disc(Vector2(Layout.POCKET.x,Layout.POCKET.z),6.0)
	var floor_surface := SurfaceTool.new()
	floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floor_material: Material = load("res://assets/environment/riverbank/materials/floor.tres")
	floor_surface.set_material(floor_material)
	var vertices := PackedVector3Array()
	var vertex_ids: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	var edge_count := 0
	for cell: Vector2i in cells:
		var center := Vector3(cell.x * STEP + 1, -0.3, cell.y * STEP + 1)
		var base := Vector3(cell.x * STEP,0,cell.y * STEP)
		for offset: Vector2 in [Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,0),Vector2(2,2),Vector2(0,2)]:
			var vertex := base + Vector3(offset.x,0,offset.y)
			floor_surface.set_normal(Vector3.UP)
			floor_surface.set_uv(Vector2(vertex.x,vertex.z) / 4.0)
			floor_surface.add_vertex(vertex)
		var polygon := PackedInt32Array()
		for offset: Vector2i in [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(1,0)]:
			var corner := cell + offset
			if not vertex_ids.has(corner):
				vertex_ids[corner] = vertices.size()
				vertices.append(Vector3(corner.x * STEP, 0.02, corner.y * STEP))
			polygon.append(vertex_ids[corner])
		polygons.append(polygon)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if cells.has(cell + direction): continue
			var pos := center + Vector3(direction.x, 0.7, direction.y)
			var size := Vector3(0.3, 0.8, STEP) if direction.x else Vector3(STEP, 0.8, 0.3)
			# Точная невидимая граница остаётся независимой от формы сменной модели.
			box(bounds, "BankEdge", pos, size, wall, true, false)
			edge_count += 1
			if edge_count % 2 == 0:
				var outside := pos + Vector3(direction.x,0,direction.y) * 1.25
				outside.y = -0.35
				var kind := "rock_small_b" if edge_count % 6 == 0 else "rock_bank_a"
				var prop := module(bounds,kind,outside,float((edge_count * 137) % 360))
				prop.set("solid",false)
				prop.scale *= 0.9 + (edge_count % 4) * 0.06
	var floor_mesh := floor_surface.commit()
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	ground.add_child(floor_body)
	var floor_visual := MeshInstance3D.new()
	floor_visual.name = "Plane"
	floor_visual.mesh = floor_mesh
	floor_body.add_child(floor_visual)
	var floor_collider := CollisionShape3D.new()
	floor_collider.name = "Shape"
	floor_collider.shape = floor_mesh.create_trimesh_shape()
	floor_body.add_child(floor_collider)
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.vertices = vertices
	for polygon in polygons: nav_mesh.add_polygon(polygon)
	nav.navigation_mesh = nav_mesh
	map_root.add_child(nav)
	var river: Node3D = load("res://scenes/art/riverbank_water.tscn").instantiate()
	river.position = Vector3(0,-0.65,-65)
	water.add_child(river)
	# Низкий мост — ориентир. Проход остаётся ровным для честной проверки боя.
	for z in [-94.5,-85.5]:
		for x in [-12.0,-8.0,-4.0]: module(landmarks,"wall_straight_4m",Vector3(x,0,z),0)
		for x in [-14.5,-1.5]: module(landmarks,"pillar_corner",Vector3(x,0,z),0)
	module(landmarks,"arch_gateway",Vector3(-10,0,-142),0)
	# Связные участки стены с угловыми столбами, вместо разрозненных панелей по сетке.
	for run in [[Vector3(-24,0,-30),4], [Vector3(36,0,-78),3], [Vector3(-16,0,-120),4]]:
		var origin: Vector3 = run[0]
		var count: int = run[1]
		for i in range(count):
			module(landmarks,"wall_broken_4m" if i % 3 == 1 else "wall_straight_4m",origin+Vector3(0,0,i*4),90)
		for z in [-2.3,count*4-1.7]: module(landmarks,"pillar_corner",origin+Vector3(0,0,z),0)
	for i in range(3):
		var data := [Layout.PACKS[i],i+1]
		var marker := Marker3D.new()
		marker.name = "Pack%d" % data[1]
		marker.position = data[0]
		encounters.add_child(marker)
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Layout.ROUTE[0] + Vector3.UP * 0.15
	map_root.add_child(spawn)
	for data in [["Finish",Layout.ROUTE[-1]+Vector3.UP*.1], ["OptionalLoot",Layout.POCKET+Vector3.UP*.1]]:
		var marker := Marker3D.new()
		marker.name = data[0]
		marker.position = data[1]
		markers.add_child(marker)
	var environment: Node3D = load("res://scenes/art/riverbank_environment.tscn").instantiate()
	lighting.add_child(environment)
	for point in [Vector3(-14,3,-140),Vector3(-6,3,-140),Vector3(-8,3,-85)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.light_color = Color("ffb75c")
		lamp.light_energy = 4.0
		lamp.omni_range = 9.0
		lighting.add_child(lamp)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(load("res://scripts/camera_rig.gd"))
	rig.set("target_path", NodePath("../Player"))
	rig.set("distance", 16.0)
	rig.set("elevation_degrees", 52.0)
	rig.set("fov_degrees", 60.0)
	map_root.add_child(rig)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	rig.add_child(camera)
	var overview := Camera3D.new()
	overview.name = "OverviewCamera"
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.size = 185
	overview.position = Vector3(0,165,0)
	overview.rotation_degrees = Vector3(-68,0,0)
	map_root.add_child(overview)
	var pool := Node3D.new()
	pool.name = "BulletPool"
	pool.set_script(load("res://scripts/bullet_pool.gd"))
	pool.set("bullet_scene", load("res://scenes/bullet.tscn"))
	pool.add_to_group("bullet_pool", true)
	map_root.add_child(pool)
	assign_owner(map_root)
	var packed := PackedScene.new()
	assert(packed.pack(map_root) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	print("RIVERBANK_BUILD_OK cells=", cells.size(), " output=", OUTPUT)
	map_root.free()
	quit()

func paint_disc(center: Vector2, radius: float) -> void:
	for x in range(floori((center.x-radius)/STEP), ceili((center.x+radius)/STEP)):
		for z in range(floori((center.y-radius)/STEP), ceili((center.y+radius)/STEP)):
			if Vector2(x*STEP+1,z*STEP+1).distance_to(center) <= radius: cells[Vector2i(x,z)] = true

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	return result

func group(parent: Node, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	parent.add_child(node)
	return node

func box(parent: Node, title: String, at: Vector3, size: Vector3, mat: Material, solid: bool, visible_mesh := true) -> void:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = title
	node.position = at
	parent.add_child(node, true)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.visible = visible_mesh
	visual.mesh = mesh
	node.add_child(visual)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.name = "Shape"
		collider.shape = shape
		node.add_child(collider)

func module(parent: Node, kind: String, at: Vector3, yaw: float) -> Node3D:
	var prop: Node3D = load(MODULE_DIR + kind + ".tscn").instantiate()
	prop.position = at
	prop.rotation_degrees.y = yaw
	parent.add_child(prop, true)
	return prop

func label(parent: Node, text: String, at: Vector3, font_size: int, color: Color) -> void:
	var node := Label3D.new()
	node.text = text
	node.position = at
	node.rotation_degrees.x = -90
	node.font_size = font_size
	node.pixel_size = 0.025
	node.modulate = color
	node.outline_size = 0
	parent.add_child(node)

func assign_owner(node: Node) -> void:
	for child in node.get_children():
		if child.name == "_Generated": continue
		child.owner = map_root
		# Внутренние узлы экземпляра принадлежат его исходной сцене.
		if child.scene_file_path.is_empty(): assign_owner(child)
