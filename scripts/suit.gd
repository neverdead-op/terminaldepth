extends RefCounted
## «Одеть» голую базовую модель Quaternius в боевой костюм.
## Считаем по исходной позе модели, где голова, руки, ноги, и записываем это в цвет вершин;
## шейдер assets/shaders/suit.gdshader по этим меткам рисует комбинезон, бронепластины и светящиеся вставки.
## Лицо и голова остаются с родной текстурой. Позже заменим на настоящие модели брони.
## Использование: Suit.apply(узел_модели, цвет_вставок)

const SHADER := preload("res://assets/shaders/suit.gdshader")

## Уже размеченные меши (на один исходный меш — одна копия).
static var _cache := {}
## Готовые материалы: одинаковые цвета — один материал на всех (сотни врагов).
static var _materials := {}


static func apply(model: Node, accent := Color(0.15, 0.85, 1.0), plate := Color(0.42, 0.45, 0.5), skin := Color.WHITE,
		cloth := Color(0.13, 0.14, 0.16), head_only := false) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var source := mi.mesh
		var material := source.surface_get_material(0)
		# Тело — меш с основным материалом «Superhero_*»; глаза и брови не трогаем.
		if material == null or not String(material.resource_name).begins_with("MI_Superhero"):
			continue
		if not _cache.has(source):
			_cache[source] = _marked_mesh(source)
		mi.mesh = _cache[source]
		var texture: Texture2D = material.albedo_texture if material is BaseMaterial3D else null
		var key := "%s|%s|%s|%s|%s|%s" % [texture.get_rid() if texture != null else 0, accent.to_html(), plate.to_html(),
				skin.to_html(), cloth.to_html(), head_only]
		if not _materials.has(key):
			var suit := ShaderMaterial.new()
			suit.shader = SHADER
			suit.set_shader_parameter("skin_texture", texture)
			suit.set_shader_parameter("accent_color", accent)
			suit.set_shader_parameter("plate_color", plate)
			suit.set_shader_parameter("skin_tint", skin)
			suit.set_shader_parameter("suit_color", cloth)
			suit.set_shader_parameter("head_only", head_only)
			_materials[key] = suit
		mi.material_override = _materials[key]


static func _marked_mesh(source: Mesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var height := hi.y - lo.y
	var half_span := maxf(absf(lo.x), absf(hi.x))
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var h := (v.y - lo.y) / height
		var side := absf(v.x) / half_span
		# Голова: выше шеи и у середины тела (поднятые в стороны кисти сюда не попадают).
		var head := smoothstep(0.855, 0.875, h) * (1.0 - smoothstep(0.1, 0.13, side))
		var front := (v.z - lo.z) / (hi.z - lo.z)
		colors[i] = Color(head, h, side, front)
	arrays[Mesh.ARRAY_COLOR] = colors
	# Дополнительные пользовательские данные в вершинах (есть у женской модели) материалу не нужны.
	for custom in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[custom] = null
	var flags: int = source.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(0, source.surface_get_material(0))
	return mesh
