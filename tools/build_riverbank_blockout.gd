extends SceneTree
## Собирает только отдельный макет берега; существующие уровни не затрагивает.
const OUTPUT := "res://scenes/art/riverbank_blockout.tscn"
const STEP := 2.0
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
	var route := [Vector2(0, 6), Vector2(0, -16), Vector2(-6, -34), Vector2(-4, -50), Vector2(-4, -70), Vector2(6, -86), Vector2(6, -106)]
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		for k in range(int(a.distance_to(b)) + 1):
			paint_disc(a.lerp(b, float(k) / maxf(a.distance_to(b), 1.0)), 5.0 if i == 3 else 6.0)
	paint_disc(Vector2(0, -17), 12.0)
	paint_disc(Vector2(-4, -50), 14.0)
	paint_disc(Vector2(6, -86), 15.0)
	for x in range(3, 11):
		for z in range(-29, -22): cells[Vector2i(x, z)] = true
	mesh_floor = BoxMesh.new()
	mesh_floor.size = Vector3(STEP, 0.6, STEP)
	mesh_floor.material = stone
	shape_floor = BoxShape3D.new()
	shape_floor.size = mesh_floor.size
	var vertices := PackedVector3Array()
	var vertex_ids: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	for cell: Vector2i in cells:
		var center := Vector3(cell.x * STEP + 1, -0.3, cell.y * STEP + 1)
		var tile := StaticBody3D.new()
		tile.name = "Tile_%d_%d" % [cell.x + 40, cell.y + 80]
		tile.position = center
		ground.add_child(tile)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh_floor
		visual.name = "Mesh"
		tile.add_child(visual)
		var collider := CollisionShape3D.new()
		collider.shape = shape_floor
		collider.name = "Shape"
		tile.add_child(collider)
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
			box(bounds, "BankEdge", pos, size, wall, true)
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.vertices = vertices
	for polygon in polygons: nav_mesh.add_polygon(polygon)
	nav.navigation_mesh = nav_mesh
	map_root.add_child(nav)
	box(water, "River", Vector3(-30, -0.75, -50), Vector3(30, 0.15, 132), material(Color("243e4b")), false)
	box(water, "FarBank", Vector3(-48, -0.3, -50), Vector3(8, 1.5, 132), wall, false)
	for i in range(26):
		var z := 10.0 - i * 4.8
		var x := -23.0 + sin(i * 0.72) * 3.0
		box(water, "RiverRock", Vector3(x, -0.1, z), Vector3(3.5, 1.8, 2.8), wall, false)
	for i in range(20):
		var z := 5.0 - i * 5.5
		box(water, "Cliff", Vector3(25 + sin(i * 0.8) * 3, 2, z), Vector3(5, 4 + i % 3, 4), wall, false)
	# Низкий мост — ориентир. Проход остаётся ровным для честной проверки боя.
	for x in [-8.6, 0.6]:
		box(landmarks, "BridgeParapet", Vector3(x, 0.8, -69), Vector3(0.8, 1.6, 10), wall, true)
		for z in [-74.0, -64.0]: box(landmarks, "BridgePier", Vector3(x, 1.3, z), Vector3(1.4, 2.6, 1.4), stone, true)
	box(landmarks, "Tollhouse", Vector3(19, 3.5, -99), Vector3(7, 7, 9), wall, true)
	for x in [1.0, 11.0]:
		box(landmarks, "GatePillar", Vector3(x, 3.5, -105), Vector3(2, 7, 2), stone, true)
	box(landmarks, "GateLintel", Vector3(6, 7, -105), Vector3(12, 1.2, 2.2), gold, false)
	for data in [[Vector3(0,0,-17), 1], [Vector3(-4,0,-50), 2], [Vector3(6,0,-86), 3]]:
		var marker := Marker3D.new()
		marker.name = "Pack%d" % data[1]
		marker.position = data[0]
		encounters.add_child(marker)
		label(landmarks, "%02d" % data[1], data[0] + Vector3(0,0.045,0), 100, Color("b5bdca"))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0,0.15,6)
	map_root.add_child(spawn)
	for data in [["Finish",Vector3(6,0.1,-106)], ["OptionalLoot",Vector3(18,0.1,-50)]]:
		var marker := Marker3D.new()
		marker.name = data[0]
		marker.position = data[1]
		markers.add_child(marker)
	label(landmarks, "START", Vector3(0,0.045,7), 56, Color("acc6bd"))
	label(landmarks, "REFUGE", Vector3(6,0.045,-102), 56, Color("e5bc77"))
	label(landmarks, "SIDE POCKET", Vector3(18,0.045,-50), 36, Color("bda7d3"))
	for i in range(0, 24):
		var z := 3.0 - i * 4.4
		var closest: Vector2 = route[0]
		var dist := INF
		for j in range(route.size()-1):
			var point := Geometry2D.get_closest_point_to_segment(Vector2(0,z), route[j], route[j+1])
			if absf(point.y-z) < dist:
				dist = absf(point.y-z)
				closest = point
		box(landmarks, "RouteDash", Vector3(closest.x,0.025,z), Vector3(0.18,0.03,1.2), gold, false)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("222536")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9cacc9")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	lighting.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "Moon"
	sun.rotation_degrees = Vector3(-58,-25,0)
	sun.light_color = Color("c9d5ef")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	lighting.add_child(sun)
	for point in [Vector3(1,3,-103),Vector3(11,3,-103),Vector3(-8,3,-65)]:
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
	overview.size = 135
	overview.position = Vector3(0,115,5)
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

func box(parent: Node, title: String, at: Vector3, size: Vector3, mat: Material, solid: bool) -> void:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = title
	node.position = at
	parent.add_child(node, true)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	node.add_child(visual)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.name = "Shape"
		collider.shape = shape
		node.add_child(collider)

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
		child.owner = map_root
		assign_owner(child)
