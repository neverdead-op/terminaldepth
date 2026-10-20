extends RefCounted
## Подготовка клипов под выбранный скелет. Для родного пака поза костей остаётся неизменной.
const Names := preload("res://scripts/shooter_model.gd")

static func poses(sk: Skeleton3D, clip: Animation, time: float) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var bone_indices := {}
	for i in sk.get_bone_count():
		result.append(sk.get_bone_rest(i))
		bone_indices[Names.bone_alias(sk.get_bone_name(i))] = i
	for t in clip.get_track_count():
		var track_bone := String(clip.track_get_path(t).get_concatenated_subnames())
		var i := sk.find_bone(track_bone)
		if i < 0:
			i = int(bone_indices.get(Names.bone_alias(track_bone), -1))
		if i < 0:
			continue
		if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			result[i].basis = Basis(clip.rotation_track_interpolate(t, time))
		elif clip.track_get_type(t) == Animation.TYPE_POSITION_3D:
			result[i].origin = clip.position_track_interpolate(t, time)
	for i in sk.get_bone_count():
		var parent := sk.get_bone_parent(i)
		if parent >= 0:
			result[i] = result[parent] * result[i]
	return result

static func bake(source: Skeleton3D, target: Skeleton3D, clip: Animation, looped: bool, aligned_bones: PackedStringArray = []) -> Animation:
	var names := {}
	for i in source.get_bone_count():
		names[Names.bone_alias(source.get_bone_name(i))] = i
	var mapping := {}
	var tracks := {}
	var result := Animation.new()
	result.length = clip.length
	result.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	for i in target.get_bone_count():
		var name := target.get_bone_name(i)
		if names.has(name):
			mapping[i] = names[name]
			var t := result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(t, NodePath("Armature/Skeleton3D:" + name))
			tracks[i] = t
	# Некоторые скачанные модели — существа или используют другие имена костей.
	# Перенос вращений для совпавших костей всё ещё полезен, но доступ к
	# mapping[-1] при отсутствии таза приводит к ошибке Dictionary.
	var pelvis := target.find_bone("pelvis")
	var hip := int(mapping.get(pelvis, -1)) if pelvis >= 0 else -1
	if mapping.is_empty():
		push_warning("Для клипа '%s' не нашлось костей, совместимых с целевой моделью." % clip.resource_name)
	var position_track := -1
	var ratio := 1.0
	var first := Vector3.ZERO
	var last := Vector3.ZERO
	if pelvis >= 0 and hip >= 0:
		position_track = result.add_track(Animation.TYPE_POSITION_3D)
		result.track_set_path(position_track, NodePath("Armature/Skeleton3D:pelvis"))
		ratio = target.get_bone_global_rest(pelvis).origin.y / maxf(source.get_bone_global_rest(hip).origin.y, 0.001)
		first = poses(source, clip, 0)[hip].origin
		last = poses(source, clip, clip.length)[hip].origin
	else:
		push_warning("Анимация '%s' перенесена без движения таза: целевой скелет не содержит совместимую кость pelvis." % clip.resource_name)
	var steps := maxi(1, ceili(clip.length * 30))
	for frame in range(steps + 1):
		var time := clip.length * frame / steps
		var from := poses(source, clip, time)
		var globals: Array[Basis] = []
		for i in target.get_bone_count():
			var parent := target.get_bone_parent(i)
			var parent_basis := globals[parent] if parent >= 0 else Basis.IDENTITY
			var global_basis := parent_basis * target.get_bone_rest(i).basis
			if mapping.has(i):
				var n: int = mapping[i]
				var source_rest := source.get_bone_global_rest(n).basis
				var target_rest := target.get_bone_global_rest(i).basis
				# У выбранных конечностей переносим направление длинной оси исходника,
				# сохраняя поворот вокруг оси целевой кости и её длину.
				if target.get_bone_name(i) in aligned_bones:
					var alignment := Quaternion(target_rest.y.normalized(), source_rest.y.normalized())
					target_rest = Basis(alignment) * target_rest
				global_basis = from[n].basis * source_rest.inverse() * target_rest
				result.rotation_track_insert_key(tracks[i], time, (parent_basis.inverse() * global_basis).orthonormalized().get_rotation_quaternion().normalized())
			globals.append(global_basis)
		if position_track >= 0:
			var position := from[hip].origin * ratio
			var drift := first.lerp(last, time / maxf(clip.length, 0.001)) * ratio
			position.x -= drift.x
			position.z -= drift.z
			var parent := target.get_bone_parent(pelvis)
			if parent >= 0:
				position = target.get_bone_global_rest(parent).affine_inverse() * position
			result.position_track_insert_key(position_track, time, position)
	return result
