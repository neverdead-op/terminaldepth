extends Node3D

static var _sources: Dictionary = {}
## Родная модель Mixamo. Имена костей приведены к игровым креплениям, поза скелета сохранена.
const SOURCE := "res://animation/Ch15_nonPBR.fbx"
@export var source_path := SOURCE
@export var creature := false
@export var animation_library_path := ""
## Профиль переноса анимаций из скачанных паков, собирается при первом появлении врага.
@export var animation_profile := ""
@export var target_height := 0.0
## Ограничение ширины постановки ног для моделей с широкой исходной позой; 0 — без поправки.
@export_range(0.0, 0.6, 0.01) var max_stance_width := 0.0
const BONE_NAMES := {
	"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head", "HeadTop_End": "head_leaf",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l", "LeftToe_End": "ball_leaf_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r", "RightToe_End": "ball_leaf_r",
}

static func bone_alias(original: String) -> String:
	var name := original.trim_prefix("mixamorig_").trim_prefix("mixamorig:")
	if BONE_NAMES.has(name):
		return BONE_NAMES[name]
	for side in ["Left", "Right"]:
		for finger in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
			var prefix: String = side + "Hand" + finger
			if name.begins_with(prefix):
				var joint := int(name.trim_prefix(prefix))
				return "%s_%02d%s_%s" % [finger.to_lower(), joint, "_leaf" if joint == 4 else "", "l" if side == "Left" else "r"]
	return name

func _enter_tree() -> void:
	if has_node("Armature"):
		return
	set_meta("native_shooter", true)
	if creature:
		set_meta("native_creature", true)
	if animation_library_path != "":
		set_meta("animation_library_path", animation_library_path)
	if animation_profile != "":
		set_meta("animation_profile", animation_profile)
	var native: Node3D = _source_scene().instantiate()
	add_child(native)
	var skeleton := native.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null)
	var original := {}
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		original[name] = bone_alias(name)
	for mesh in native.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			mesh.skin = mesh.skin.duplicate()
			for bind in mesh.skin.get_bind_count():
				var name: String = mesh.skin.get_bind_name(bind)
				if original.has(name):
					mesh.skin.set_bind_name(bind, original[name])
	for i in skeleton.get_bone_count():
		skeleton.set_bone_name(i, original[skeleton.get_bone_name(i)])
	for ap in native.find_children("*", "AnimationPlayer", true, false):
		ap.free()
	var armature := Node3D.new()
	armature.name = "Armature"
	add_child(armature)
	skeleton.reparent(armature, true)
	# Меши обычно находятся внутри Skeleton3D; внешние меши тоже сохраняют привязку.
	for mesh in native.find_children("*", "MeshInstance3D", true, false):
		# Статические части вроде винтовки остаются под исходным родителем (часто это кость кисти).
		# Перепривязываем только меши, которые действительно деформируются скелетом.
		if mesh.skin != null:
			mesh.reparent(skeleton, true)
			mesh.skeleton = NodePath("..")
	if native.get_child_count() == 0:
		native.free()

	if target_height > 0:
		var bounds := AABB()
		var found := false
		for mesh in skeleton.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			bounds = box if not found else bounds.merge(box)
			found = true
		if found and bounds.size.y > 0.1:
			armature.scale = Vector3.ONE * target_height / bounds.size.y


func _source_scene() -> PackedScene:
	if not _sources.has(source_path):
		_sources[source_path] = load(source_path)
	return _sources[source_path]
