extends RefCounted
## Причёски из Universal Base Characters (assets/characters/hair, вариант «Origin at 0»).
## Меш причёски сделан в позе модели по умолчанию — крепим его к кости головы (BoneAttachment3D)
## со сдвигом «обратно от позы покоя головы», и причёска двигается вместе с головой при любой анимации.
## Использование: Hair.attach(узел_модели, preload(".../Hair_SimpleParted.gltf"), оттенок)

## Оттенённые материалы (на один исходный материал и цвет — одна копия).
static var _materials := {}


static func attach(model: Node, hair: PackedScene, tint := Color.WHITE) -> Node3D:
	var skeleton := model.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skeleton == null or hair == null:
		return null
	var head := skeleton.find_bone("Head")
	if head < 0:
		head = skeleton.find_bone("head")
	if head < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = skeleton.get_bone_name(head)
	skeleton.add_child(attachment)
	var inst: Node3D = hair.instantiate()
	attachment.add_child(inst)
	inst.transform = skeleton.get_bone_global_rest(head).affine_inverse()
	if tint != Color.WHITE:
		for node in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var source := mi.mesh.surface_get_material(0) as BaseMaterial3D
			if source == null:
				continue
			var key := "%s|%s" % [source.get_rid(), tint.to_html()]
			if not _materials.has(key):
				var m := source.duplicate() as BaseMaterial3D
				m.albedo_color = source.albedo_color * tint
				_materials[key] = m
			mi.material_override = _materials[key]
	return inst
