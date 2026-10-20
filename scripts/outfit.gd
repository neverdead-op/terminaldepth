extends RefCounted
## Одежда из Modular Character Outfits (Quaternius, assets/characters/outfits) на базовую модель.
## Меши одежды сделаны на тот же скелет, что и Universal Base Characters: переносим их в скелет модели —
## и одежда двигается со всеми анимациями. Тело базовой модели при этом прячем (кроме головы — Suit head_only),
## иначе оно торчит сквозь ткань.
## Использование: Outfit.attach(узел_модели, preload(".../Male_Peasant.gltf"), цвет_ткани, цвет_кожи)

## Перекрашенные материалы (на исходный материал и цвет — одна копия).
static var _materials := {}


static func attach(model: Node, outfit: PackedScene, cloth_tint := Color.WHITE, skin_tint := Color.WHITE) -> void:
	var skeleton := model.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skeleton == null or outfit == null:
		return
	var inst := outfit.instantiate()
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var skin := mi.skin
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skeleton.add_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.skin = skin
		mi.skeleton = NodePath("..")
		for i in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if source == null:
				continue
			# Голые руки и шея в одежде — материал «MI_Regular_*», красим как кожу; ткань — своим цветом.
			var tint := skin_tint if String(source.resource_name).begins_with("MI_Regular") else cloth_tint
			if tint == Color.WHITE:
				continue
			var key := "%s|%s" % [source.get_rid(), tint.to_html()]
			if not _materials.has(key):
				var m := source.duplicate() as BaseMaterial3D
				m.albedo_color = source.albedo_color * tint
				_materials[key] = m
			mi.set_surface_override_material(i, _materials[key])
	inst.free()


## Подходит ли одежда к модели (мужская к мужской, женская к женской) — по именам файлов.
static func fits(model_scene: PackedScene, outfit: PackedScene) -> bool:
	var female := model_scene.resource_path.contains("Female")
	return outfit.resource_path.get_file().begins_with("Female") == female
