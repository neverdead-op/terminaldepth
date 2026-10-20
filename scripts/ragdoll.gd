extends RefCounted
## Регдолл врага при смерти: на основные кости скелета ставятся физические капсулы с суставами,
## анимация останавливается, тело падает физикой. Скелет у всех врагов одинаковый
## (pelvis, spine_01…, thigh_l…); если нужных костей нет — false, и враг играет анимацию смерти.
## Физические кости лежат на слое RAGDOLL_LAYER и сталкиваются только с миром (слой 1):
## героиню, врагов и пули не задевают.

const RAGDOLL_LAYER := 1 << 6
## [кость, кость-конец (куда тянется капсула), радиус в долях длины тела, тип сустава]
const PARTS := [
	["pelvis", "spine_01", 0.085, PhysicalBone3D.JOINT_TYPE_NONE],
	["spine_01", "spine_03", 0.09, PhysicalBone3D.JOINT_TYPE_CONE],
	["spine_03", "neck_01", 0.095, PhysicalBone3D.JOINT_TYPE_CONE],
	["Head", "head_leaf", 0.065, PhysicalBone3D.JOINT_TYPE_CONE],
	["upperarm_l", "lowerarm_l", 0.035, PhysicalBone3D.JOINT_TYPE_CONE],
	["lowerarm_l", "hand_l", 0.03, PhysicalBone3D.JOINT_TYPE_HINGE],
	["upperarm_r", "lowerarm_r", 0.035, PhysicalBone3D.JOINT_TYPE_CONE],
	["lowerarm_r", "hand_r", 0.03, PhysicalBone3D.JOINT_TYPE_HINGE],
	["thigh_l", "calf_l", 0.05, PhysicalBone3D.JOINT_TYPE_CONE],
	["calf_l", "foot_l", 0.04, PhysicalBone3D.JOINT_TYPE_HINGE],
	["thigh_r", "calf_r", 0.05, PhysicalBone3D.JOINT_TYPE_CONE],
	["calf_r", "foot_r", 0.04, PhysicalBone3D.JOINT_TYPE_HINGE],
]
## Масса частей (кг): таз и грудь тяжелее, конечности легче.
const MASS := {"pelvis": 12.0, "spine_01": 10.0, "spine_03": 10.0, "Head": 5.0}


## impulse — толчок телу (направление выстрела × сила), м/с у таза.
static func start(skeleton: Skeleton3D, impulse: Vector3, anim: AnimationPlayer = null) -> bool:
	if skeleton == null:
		return false
	# Jolt не умеет неравномерно растянутые тела (громила 1.6×1.45×1.6) — у таких остаётся анимация смерти.
	var sc := skeleton.global_transform.basis.get_scale()
	if maxf(sc.x, maxf(sc.y, sc.z)) / maxf(minf(sc.x, minf(sc.y, sc.z)), 0.001) > 1.02:
		return false
	for part in PARTS:
		if skeleton.find_bone(part[0]) < 0 or skeleton.find_bone(part[1]) < 0:
			return false
	# Длина тела (таз → голова) — от неё зависят толщины капсул при любом масштабе модели.
	var body_height := _bone_world(skeleton, "pelvis").distance_to(_bone_world(skeleton, "head_leaf")) * 2.0
	if anim != null:
		anim.pause()
		anim.active = false
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	skeleton.add_child(simulator)
	var bones: Array[PhysicalBone3D] = []
	for part in PARTS:
		var bone := PhysicalBone3D.new()
		bone.name = "Phys_" + part[0]
		bone.bone_name = part[0]
		bone.joint_type = part[3]
		bone.mass = MASS.get(part[0], 3.0)
		bone.friction = 0.8
		bone.linear_damp = 0.4
		bone.angular_damp = 2.5
		bone.collision_layer = RAGDOLL_LAYER
		bone.collision_mask = 1
		# Капсула от кости к её «концу»: тело в середине отрезка, ось капсулы вдоль кости.
		var from := _bone_world(skeleton, part[0])
		var to := _bone_world(skeleton, part[1])
		var length := maxf(from.distance_to(to), 0.05)
		var radius := clampf(part[2] * body_height, 0.03, length * 0.45 + 0.04)
		var bone_global := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(part[0]))
		var axis_local := (bone_global.affine_inverse() * to).normalized()
		var mid_local := bone_global.affine_inverse() * ((from + to) * 0.5)
		var up := Vector3.UP if absf(axis_local.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var basis := Basis(axis_local.cross(up).normalized(), axis_local, axis_local.cross(axis_local.cross(up)).normalized() * -1.0).orthonormalized()
		bone.body_offset = Transform3D(basis, mid_local)  # тело = кость × body_offset
		bone.joint_offset = Transform3D(Basis(), basis.inverse() * -mid_local)
		match part[3]:
			PhysicalBone3D.JOINT_TYPE_CONE:
				bone.set("joint_constraints/swing_span", 40.0)
				bone.set("joint_constraints/twist_span", 25.0)
			PhysicalBone3D.JOINT_TYPE_HINGE:
				bone.set("joint_constraints/angular_limit_enabled", true)
				bone.set("joint_constraints/angular_limit_upper", 95.0)
				bone.set("joint_constraints/angular_limit_lower", -5.0)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		var scale := skeleton.global_transform.basis.get_scale()
		var unit := (scale.x + scale.y + scale.z) / 3.0
		capsule.radius = radius / unit
		capsule.height = maxf(length / unit, capsule.radius * 2.0 + 0.01)
		shape.shape = capsule
		bone.add_child(shape)
		simulator.add_child(bone)
		bones.append(bone)
	simulator.physical_bones_start_simulation()
	_move_stakes_to_bodies(skeleton, bones)
	for bone in bones:
		var share := 1.0 if bone.bone_name in ["pelvis", "spine_01", "spine_03"] else 0.6
		bone.apply_central_impulse(impulse * bone.mass * share)
	return true


static func _bone_world(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin


## Колья висели на BoneAttachment3D — при регдолле они отставали и зависали в воздухе.
## Переносим каждый кол на ближайшую физическую кость: дальше он летит и лежит вместе с ней.
static func _move_stakes_to_bodies(skeleton: Skeleton3D, bones: Array[PhysicalBone3D]) -> void:
	for attachment in skeleton.get_children():
		if not attachment is BoneAttachment3D:
			continue
		for stake in attachment.get_children():
			if not stake is MeshInstance3D:
				continue
			var world: Transform3D = stake.global_transform
			var best: PhysicalBone3D = null
			var best_distance := INF
			for bone in bones:
				var d := bone.global_position.distance_squared_to(world.origin)
				if d < best_distance:
					best_distance = d
					best = bone
			if best == null:
				continue
			stake.reparent(best, false)
			stake.global_transform = world
		attachment.queue_free()
