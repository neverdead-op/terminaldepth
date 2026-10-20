@tool
extends Node3D
## Много копий одной модели (стенные панели, ящики, колонны) — одним махом через MultiMesh:
## видеокарта рисует их все за раз, поэтому сотни панелей не тормозят игру.
## Генератор этажей кладёт сюда модель и список положений (по 12 чисел на копию:
## три оси базиса — x, y, z — и точка начала координат).

@export var model: PackedScene
@export var transforms := PackedFloat32Array()
@export var cast_shadows := true
## Умножить цвет всех материалов модели (приглушить яркие растения). Белый — без изменений.
@export var tint := Color.WHITE

## Перекрашенные копии материалов: один на исходный материал и цвет (сотни копий — пара материалов).
static var _tinted := {}


func _ready() -> void:
	if model == null or transforms.is_empty():
		return
	var count := transforms.size() / 12
	var source := model.instantiate()
	# В модели может быть несколько мешей — на каждый свой MultiMesh со своим смещением внутри модели.
	for mi in source.find_children("*", "MeshInstance3D", true, false):
		var local := Transform3D.IDENTITY
		var n: Node = mi
		while n != source and n != null:
			if n is Node3D:
				local = n.transform * local
			n = n.get_parent()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh if tint == Color.WHITE else _tinted_mesh(mi.mesh)
		mm.instance_count = count
		for i in count:
			var o := i * 12
			var t := Transform3D(
				Basis(Vector3(transforms[o], transforms[o + 1], transforms[o + 2]),
					Vector3(transforms[o + 3], transforms[o + 4], transforms[o + 5]),
					Vector3(transforms[o + 6], transforms[o + 7], transforms[o + 8])),
				Vector3(transforms[o + 9], transforms[o + 10], transforms[o + 11]))
			mm.set_instance_transform(i, t * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	source.free()


func _tinted_mesh(mesh: Mesh) -> Mesh:
	var key := "%s|%s" % [mesh.get_rid(), tint.to_html()]
	if _tinted.has(key):
		return _tinted[key]
	var copy := mesh.duplicate() as Mesh
	for i in copy.get_surface_count():
		var mat := copy.surface_get_material(i) as BaseMaterial3D
		if mat != null:
			mat = mat.duplicate() as BaseMaterial3D
			mat.albedo_color *= tint
			copy.surface_set_material(i, mat)
	_tinted[key] = copy
	return copy
