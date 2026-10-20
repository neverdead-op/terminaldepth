extends SkeletonModifier3D
## Поправка позы поверх анимации: приподнимает голову и шею (в анимациях с оружием манекен смотрит в пол),
## чуть выпрямляет грудь. Углы — в градусах, вверх — плюс.

@export var head_pitch := 12.0
@export var neck_pitch := 6.0
@export var chest_pitch := 0.0
## Узел персонажа: его ось X — «вправо», вокруг неё и наклоняем.
@export var body: Node3D

var _bones: Array = []


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for pair in [["spine_03", chest_pitch], ["neck_01", neck_pitch], ["head", head_pitch]]:
		var i := skeleton.find_bone(pair[0])
		if i >= 0:
			_bones.append([i, pair[1]])


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or body == null:
		return
	# Ось «вправо» персонажа в координатах скелета.
	var right := (skeleton.global_basis.inverse() * body.global_basis.x).normalized()
	for b in _bones:
		var bone: int = b[0]
		var pose := skeleton.get_bone_global_pose(bone)
		pose.basis = Basis(right, deg_to_rad(b[1])) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
