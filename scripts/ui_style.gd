extends RefCounted
## Художественные PNG-рамки: девять областей сохраняют углы при любом размере окна.
const BRONZE := Color(0.34, 0.33, 0.30)
const GOLD := Color(0.76, 0.68, 0.47)
const INK := Color(0.014, 0.016, 0.020, 0.97)
const TEXT := Color(0.89, 0.89, 0.86)
const BLUE := Color(0.34, 0.65, 0.84)
static var _textures := {}
const REGIONS := {
	"hud_plate": Rect2(31, 179, 2109, 332),
	"window": Rect2(34, 48, 957, 1436),
	"tooltip": Rect2(15, 13, 1419, 1059),
	"socket": Rect2(46, 53, 1162, 1140),
}

static func _texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load("res://assets/ui/" + ("gothic_v1/" if key == "hud_plate" else "gothic_v2/") + key + ".png")
	return _textures[key]

static func _nine(ci: CanvasItem, r: Rect2, key: String, edge: float, margins: Vector4) -> void:
	var tex := _texture(key)
	var source: Rect2 = REGIONS[key] if key == "hud_plate" else Rect2(Vector2.ZERO, tex.get_size())
	var border := minf(edge, minf(r.size.x, r.size.y) * 0.35)
	var sx := [source.position.x, source.position.x + margins.x, source.end.x - margins.z, source.end.x]
	var sy := [source.position.y, source.position.y + margins.y, source.end.y - margins.w, source.end.y]
	var dx := [r.position.x, r.position.x + border, r.end.x - border, r.end.x]
	var dy := [r.position.y, r.position.y + border, r.end.y - border, r.end.y]
	for y in 3:
		for x in 3:
			ci.draw_texture_rect_region(tex, Rect2(dx[x], dy[y], dx[x+1]-dx[x], dy[y+1]-dy[y]),
				Rect2(sx[x], sy[y], sx[x+1]-sx[x], sy[y+1]-sy[y]), Color(0.76, 0.79, 0.82))

static func plate(ci: CanvasItem, r: Rect2, scale := 1.0) -> void:
	_nine(ci, r, "hud_plate", 7 * scale, Vector4(120, 55, 120, 55))

static func panel(ci: CanvasItem, r: Rect2, scale := 1.0) -> void:
	_nine(ci, r, "merchant_frame", 22 * scale, Vector4(165, 190, 165, 190))

static func tooltip(ci: CanvasItem, r: Rect2, scale := 1.0) -> void:
	_nine(ci, r, "item_slot", 12 * scale, Vector4(195, 195, 195, 195))

static func slot(ci: CanvasItem, r: Rect2, scale := 1.0, active := false) -> void:
	ci.draw_rect(r, Color(0.012, 0.016, 0.020, 0.98))
	ci.draw_rect(r.grow(-scale), Color(0.19, 0.21, 0.23), false, 2 * scale)
	ci.draw_line(r.position + Vector2(3, 3) * scale, Vector2(r.end.x - 3 * scale, r.position.y + 3 * scale), Color(0.33, 0.32, 0.28), scale)
	if active:
		ci.draw_rect(r.grow(-2 * scale), GOLD, false, 1.5 * scale)

static func socket(ci: CanvasItem, r: Rect2, active := false, color := Color.WHITE) -> void:
	var radius := r.size.x * 0.43
	ci.draw_circle(r.get_center(), radius, INK)
	ci.draw_arc(r.get_center(), radius, 0, TAU, 48, Color(0.28, 0.30, 0.31, color.a), 3.0, true)
	ci.draw_arc(r.get_center(), radius - 2, 0, TAU, 48, Color(0.48, 0.43, 0.32, color.a), 1.2, true)
	if active:
		ci.draw_arc(r.get_center(), r.size.x * 0.43, 0, TAU, 40, BLUE, 1.2, true)

static func nameplate(ci: CanvasItem, r: Rect2, tint := TEXT, selected := false) -> void:
	ci.draw_rect(r, Color(0.012, 0.017, 0.021, 0.97))
	ci.draw_rect(r.grow(-1), Color(tint, 0.75 if selected else 0.32), false, 1.0)
	ci.draw_line(r.position + Vector2(5, 2), Vector2(r.end.x - 5, r.position.y + 2), Color(0.42, 0.39, 0.32, 0.65), 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(3, r.size.y - 6)), tint)

static func panel_box() -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, 22)
	return box

static func button(ci: CanvasItem, r: Rect2, scale := 1.0, active := false) -> void:
	# Лишнее прозрачное поле исходной кнопки исключаем областью атласа.
	var tex := _texture("button")
	var ts := tex.get_size()
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, ts.y * 0.15, ts.x, ts.y * 0.62)
	ci.draw_texture_rect(atlas, r, false, Color.WHITE if active else Color(0.65, 0.68, 0.71))
	if active: ci.draw_rect(r.grow(-4 * scale), Color(GOLD, 0.6), false, scale)

static func cell(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_texture_rect(_texture("inventory_cell"), r, false, Color(0.65, 0.69, 0.72))

static func gold(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_texture_rect(_texture("gold"), r, false)

static func art(ci: CanvasItem, key: String, r: Rect2, color := Color.WHITE) -> void:
	ci.draw_texture_rect(_texture(key), r, false, color)

static func bar(ci: CanvasItem, r: Rect2, ratio: float, color: Color) -> void:
	ci.draw_rect(r.grow(1), Color(0.08, 0.08, 0.08))
	ci.draw_rect(r, color.darkened(0.85))
	var fill := Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0, 1), r.size.y))
	if fill.size.x > 0:
		ci.draw_rect(fill, color.darkened(0.2))
		ci.draw_rect(Rect2(fill.position, Vector2(fill.size.x, maxf(1, fill.size.y * 0.2))), color.lightened(0.06))
