extends RefCounted
## Подсветка объекта: светящийся край по силуэту всех его мешей (как обводка в PoE 2).
## Highlight.apply(узел, цвет) / Highlight.clear(узел). Материалы общие на цвет.

const SHADER := preload("res://assets/shaders/highlight.gdshader")
static var _mats := {}


static func material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("color", color)
		_mats[key] = m
	return _mats[key]


static func apply(node: Node, color: Color) -> void:
	var m := material(color)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = m
	if node is MeshInstance3D:
		node.material_overlay = m


static func clear(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = null
