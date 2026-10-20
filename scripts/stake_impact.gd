extends RefCounted
## Кол коломёта: как выглядит, как торчит из врага и из стены.
## Во враге кол крепится к ближайшей кости — качается вместе с телом и остаётся в трупе.
## В стене висит stuck_lifetime секунд и исчезает.

const MAX_PER_ENEMY := 5
const MAX_IN_WALLS := 40
const WALL_LIFETIME := 12.0
## На сколько метров кол входит в цель (остальное торчит наружу).
const DEPTH := 0.12

static var _mesh: Mesh
static var _in_walls: Array[Node3D] = []


## Кол вдоль оси −Z: наконечник впереди (z = −0.335), хвост сзади (z = +0.225).
static func mesh() -> Mesh:
	if _mesh != null:
		return _mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.18)
	# Светлое дерево чуть светится — кол читается и в ночной сцене.
	wood.emission_enabled = true
	wood.emission = Color(0.35, 0.24, 0.12)
	wood.emission_energy_multiplier = 0.12
	wood.roughness = 0.85
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.19, 0.18)
	iron.metallic = 0.75
	iron.roughness = 0.4
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.008
	shaft.bottom_radius = 0.011
	shaft.height = 0.42
	shaft.radial_segments = 6
	shaft.rings = 1
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.015
	tip.height = 0.07
	tip.radial_segments = 6
	tip.rings = 1
	var ring := CylinderMesh.new()
	ring.top_radius = 0.014
	ring.bottom_radius = 0.014
	ring.height = 0.02
	ring.radial_segments = 6
	ring.rings = 1
	var along := Basis(Vector3.RIGHT, -PI * 0.5)  # ось цилиндра Y → −Z
	var result := ArrayMesh.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(shaft, 0, Transform3D(along, Vector3(0, 0, 0.0)))
	tool.set_material(wood)
	tool.commit(result)
	tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(tip, 0, Transform3D(along, Vector3(0, 0, -0.245)))
	tool.append_from(ring, 0, Transform3D(along, Vector3(0, 0, 0.2)))
	tool.set_material(iron)
	tool.commit(result)
	_mesh = result
	return _mesh


## Кол торчит из врага: at — точка попадания, dir — направление полёта.
static func stick_in_enemy(enemy: Node, at: Vector3, dir: Vector3) -> void:
	var visual := enemy.get("_visual") as Node3D
	if visual == null or not visual.is_inside_tree():
		return
	var count: int = enemy.get_meta("stakes", 0)
	if count >= MAX_PER_ENEMY:
		return
	enemy.set_meta("stakes", count + 1)
	var stake := _make(at + dir * DEPTH, dir)
	var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null and skeleton.get_bone_count() > 0:
		# Ближайшая к попаданию кость: кол двигается вместе с ней (и в анимации смерти).
		var best := 0
		var best_distance := INF
		for i in skeleton.get_bone_count():
			var bone_at := skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
			var d := bone_at.distance_squared_to(at)
			if d < best_distance:
				best_distance = d
				best = i
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_idx = best
		var bone_global := skeleton.global_transform * skeleton.get_bone_global_pose(best)
		var world := stake.transform
		stake.transform = bone_global.affine_inverse() * world
		attachment.add_child(stake)
	else:
		var world := stake.transform
		visual.add_child(stake)
		stake.global_transform = world


## Кол в стене: висит и через время исчезает; старые убираются, когда кольев слишком много.
static func stick_in_wall(level: Node, at: Vector3, dir: Vector3) -> void:
	if level == null or not level.is_inside_tree():
		return
	var stake := _make(at + dir * DEPTH * 0.6, dir)
	var world := stake.transform
	level.add_child(stake)
	stake.global_transform = world
	_in_walls.append(stake)
	_in_walls.assign(_in_walls.filter(func(s): return is_instance_valid(s)))
	while _in_walls.size() > MAX_IN_WALLS:
		var old: Node3D = _in_walls.pop_front()
		if is_instance_valid(old): old.queue_free()
	var fade := stake.create_tween()
	fade.tween_interval(WALL_LIFETIME)
	fade.tween_property(stake, "scale", Vector3.ONE * 0.01, 0.4)
	fade.tween_callback(stake.queue_free)


static func _make(tip_at: Vector3, dir: Vector3) -> MeshInstance3D:
	var stake := MeshInstance3D.new()
	stake.mesh = mesh()
	stake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var forward := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var up := Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT
	# Наконечник (−Z меша) в точке tip_at, хвост торчит назад к стрелку.
	stake.transform = Transform3D(Basis.looking_at(forward, up), tip_at - forward * 0.28)
	return stake
