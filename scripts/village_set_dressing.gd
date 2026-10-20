extends Node3D
## Collision shapes match visible props. All placements are inside the existing playable plan.
const Wall = preload("res://assets/buildings/village_props/wall_straight.glb")
const Gate = preload("res://assets/buildings/village_props/gate_round.glb")
const Basket = preload("res://assets/buildings/village_props/basket.glb")
const Crate = preload("res://assets/buildings/village_props/crate.glb")
const Carriage = preload("res://assets/buildings/village_props/carriage.glb")
const BareTree = preload("res://assets/buildings/village_nature/tree_bare.glb")
const RedTree = preload("res://assets/buildings/village_nature/tree_red.glb")
const Barrel = preload("res://assets/buildings/village_nature/barrel.glb")
const Bench = preload("res://assets/buildings/village_nature/bench.glb")
const Planter = preload("res://assets/buildings/village_nature/planter.glb")
const Materials = preload("res://scripts/village_materials.gd")
var faded: Array[MeshInstance3D] = []

func solid(at: Vector3, size: Vector3, parent: Node3D, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body

## body_material — замена кладки (поверхность 0), каменный верх остаётся.
func wall(parent: Node3D, at: Vector3, along_z: bool, body_material: Material = null) -> StaticBody3D:
	var body := solid(at + Vector3(0, 1.4, 0), Vector3(2, 2.8, 0.72), parent, PI * 0.5 if along_z else 0.0)
	var model := Wall.instantiate() as Node3D
	model.position.y = -1.4
	body.add_child(model)
	Materials.apply(model)
	if body_material != null:
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			mesh.set_surface_override_material(0, body_material)
	body.set_meta("village_occluder", model)
	return body

func gate(at: Vector3, yaw := 0.0) -> void:
	var model := Gate.instantiate() as Node3D
	model.name = "RoundPassage"
	model.position = at
	model.rotation.y = yaw
	add_child(model)
	Materials.apply(model)
	for side in [-1, 1]:
		var body := solid(Vector3(side * 4.05, 2, 0), Vector3(3.9, 4, 0.96), model)
		body.set_meta("village_occluder", model)
	var top := solid(Vector3(0, 4.9, 0), Vector3(4.2, 0.4, 0.96), model)
	top.set_meta("village_occluder", model)

func prop(scene: PackedScene, at: Vector3, size: Vector3, yaw := 0.0) -> Node3D:
	var body := solid(at + Vector3(0, size.y * 0.5, 0), size, self, yaw)
	var model := scene.instantiate() as Node3D
	model.position.y = -size.y * 0.5
	body.add_child(model)
	Materials.apply(model)
	body.set_meta("village_occluder", model)
	return body

func populate() -> void:
	gate(Vector3(-12, 0, -34))
	gate(Vector3(8, 0, -68))
	gate(Vector3(-6, 0, -166))
	# A coach by the first houses, outside the clear central combat lane.
	prop(Carriage, Vector3(3.7, 0, -3), Vector3(2.1, 2.45, 5.0))
	for at in [Vector3(-4.4, 0, -5), Vector3(4.4, 0, -21), Vector3(-16.3, 0, -41), Vector3(12.4, 0, -77), Vector3(5.7, 0, -135), Vector3(-10.3, 0, -181), Vector3(5, 0, -229)]:
		prop(Basket, at, Vector3(0.95, 0.75, 0.95))
		prop(Crate, at + Vector3(0, 0, 1.3), Vector3(1.0, 0.9, 1.0), 0.12)
	for at in [Vector3(-4.5, 0, 8), Vector3(4.5, 0, -19), Vector3(-16.5, 0, -48), Vector3(12.5, 0, -82), Vector3(14.5, 0, -142), Vector3(-10.5, 0, -174)]:
		prop(Barrel, at, Vector3(0.95, 1.1, 0.95))
	for at in [Vector3(-4.8, 0, 3), Vector3(12.7, 0, -73), Vector3(-10.7, 0, -154)]:
		prop(Bench, at, Vector3(2.2, 1.2, 0.85), PI * 0.5)
	for at in [Vector3(-4.6, 0, -18), Vector3(-16.5, 0, -52), Vector3(12.5, 0, -86), Vector3(5.5, 0, -139), Vector3(-1.5, 0, -176), Vector3(-7, 0, -228)]:
		prop(Planter, at, Vector3(1.8, 0.75, 1.8))
		var tree: Node3D = RedTree.instantiate()
		tree.position = at + Vector3(0, 0.65, 0)
		tree.scale = Vector3.ONE * 0.72
		add_child(tree)
		Materials.apply(tree)
	# Trees beyond the boundary replace the removed house silhouettes without opening side paths.
	var tree_points := [Vector2(-8, 5), Vector2(8, 2), Vector2(-9, -12), Vector2(8, -19), Vector2(-21, -33), Vector2(-3, -42), Vector2(17, -65), Vector2(17, -80), Vector2(-17, -98), Vector2(20, -123), Vector2(19, -139), Vector2(-16, -151), Vector2(-15, -170), Vector2(19, -194), Vector2(-8, -211)]
	for i in tree_points.size():
		var at: Vector2 = tree_points[i]
		var tree: Node3D = (RedTree if i % 3 == 0 else BareTree).instantiate()
		tree.position = Vector3(at.x, -1.1, at.y)
		tree.rotation.y = i * 2.39
		add_child(tree)
		Materials.apply(tree)

func update_occlusion(player: Node3D, camera: Camera3D) -> void:
	for mesh in faded:
		if is_instance_valid(mesh): mesh.transparency = 0
	faded.clear()
	var exclude: Array[RID] = [player.get_rid()]
	for i in 5:
		var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1, 0), camera.global_position, 1, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty(): break
		exclude.append(hit.rid)
		var collider := hit.collider as Node
		if collider != null and collider.has_meta("village_occluder"):
			var target: Node3D = collider.get_meta("village_occluder")
			var meshes := target.find_children("*", "MeshInstance3D", true, false)
			if target is MeshInstance3D: meshes.append(target)
			for mesh in meshes:
				mesh.transparency = 0.85
				faded.append(mesh)
