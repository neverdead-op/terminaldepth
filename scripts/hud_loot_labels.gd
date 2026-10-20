extends Control
## Подписи добычи на экране, как фильтр лута в PoE 2: тёмная плашка, текст и рамка цвета редкости,
## у ценных фрагментов — яркий фон. Плашки не налезают друг на друга: ближние к герою встают на своё
## место, остальные сдвигаются стопкой вверх/вниз. Плашка под мышью подсвечивается — ПКМ по ней
## поднимает вещь (если далеко — герой сам подходит).

@export var font_size := 16
@export var pad := Vector2(12, 5)
## Подписи видны, когда добыча ближе этого расстояния к герою (м).
@export var label_range := 9.0
## Высота над вещью, откуда «растёт» подпись (м).
@export var lift := 0.55

var player: Node3D
## Добыча под курсором мыши (её поднимет ПКМ).
var hovered: Node3D

var _labels: Array = []  # {node, rect, text, style}
var _preview := {}
const Style := preload("res://scripts/ui_style.gd")
const UiIcons := preload("res://scripts/ui_icons.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	_preview.clear()
	_layout()
	if is_instance_valid(hovered):
		remember(hovered)
	queue_redraw()


func _layout() -> void:
	_labels.clear()
	hovered = null
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var font := Loc.MAIN_FONT
	var items := []
	for node in get_tree().get_nodes_in_group("loot"):
		if node.is_queued_for_deletion():
			continue
		var d: float = player.global_position.distance_to(node.global_position)
		if d > label_range:
			continue
		var at: Vector3 = node.global_position + Vector3.UP * lift
		if camera.is_position_behind(at):
			continue
		items.append([d, node, camera.unproject_position(at)])
	# Ближние первыми — они занимают «своё» место, дальние подстраиваются.
	items.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var placed: Array[Rect2] = []
	for entry in items:
		var node: Node3D = entry[1]
		var text: String = Loc.t(node.call("_title"))
		var size_px := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) + pad * 2.0
		var base := Rect2(entry[2] - Vector2(size_px.x * 0.5, size_px.y), size_px)
		var rect := base
		var step := size_px.y + 2.0
		for k in 16:
			# 0, вверх 1, вниз 1, вверх 2, ...
			var shift := (k + 1) / 2 * (-1 if k % 2 == 1 else 1) * step
			rect = Rect2(base.position + Vector2(0, shift), size_px)
			var free := true
			for other in placed:
				if other.grow(1.0).intersects(rect):
					free = false
					break
			if free:
				break
		placed.append(rect)
		_labels.append({"node": node, "rect": rect, "text": text, "anchor": entry[2],
			"item_anchor": camera.unproject_position(node.global_position)})
	var mouse := get_viewport().get_mouse_position()
	for label in _labels:
		if label.rect.has_point(mouse):
			hovered = label.node
	if hovered == null:
		for label in _labels:
			if label.item_anchor.distance_to(mouse) < 20:
				hovered = label.node
				break


func remember(loot: Node) -> void:
	if loot.kind == &"gold":
		return
	_preview = {"kind": loot.kind, "title": loot._title(), "gear": loot.gear,
		"module": loot.module, "currency": loot.currency_id, "color": _style(loot).text}


func _draw() -> void:
	var font := Loc.MAIN_FONT
	var near = player.get("_highlighted_loot") if player != null and is_instance_valid(player) else null
	for label in _labels:
		var node = label.node
		if not is_instance_valid(node):
			continue
		var style := _style(node)
		var rect: Rect2 = label.rect
		var lit: bool = node == hovered or node == near
		# Тонкая ножка от плашки к вещи, если плашку сдвинули.
		var anchor: Vector2 = label.anchor
		if absf(rect.end.y - anchor.y) > 4.0:
			draw_line(Vector2(anchor.x, rect.end.y if rect.end.y < anchor.y else rect.position.y), anchor,
					Color(style.border, 0.35), 1.0)
		Style.nameplate(self, rect, style.text, lit)
		draw_string(font, rect.position + Vector2(pad.x, pad.y + font.get_ascent(font_size)), label.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, style.text)
	_draw_preview(font)


func _draw_preview(font: Font) -> void:
	if not is_instance_valid(hovered) or hovered.is_queued_for_deletion() or _preview.is_empty() or get_tree().paused:
		return
	var lines: Array = []
	var gear: GearItem = _preview.gear
	if gear != null:
		lines.append("Item Level: %d" % gear.item_level)
		for row in gear.describe():
			lines.append(Loc.t(row[0]))
	elif _preview.module != null:
		lines.append(Loc.t(_preview.module.description))
	else:
		lines.append(Loc.t(preload("res://scripts/item_db.gd").CURRENCY[_preview.currency].text))
	var count := mini(lines.size(), 7)
	var box := Rect2(size.x - 392, size.y - 260 - count * 24, 376, 96 + count * 24)
	Style.panel(self, box)
	draw_rect(Rect2(box.position + Vector2(4, 4), Vector2(box.size.x - 8, 34)), Color(_preview.color, 0.13))
	draw_string(Loc.TITLE_FONT, box.position + Vector2(16, 29), Loc.t(_preview.title), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32, 15, _preview.color)
	var icon := Rect2(box.position + Vector2(16, 51), Vector2(76, 90))
	if gear != null:
		if gear.slot == &"mines":
			UiIcons.draw_mine(self, icon)
		elif not UiIcons.draw_item_picture(self, gear, icon) and gear.is_weapon():
			UiIcons.draw_weapon_picture(self, gear.weapon_data(), icon)
	elif _preview.module != null:
		UiIcons.draw_module(self, _preview.module.id, icon.get_center(), 26, Color.WHITE)
	else:
		UiIcons.draw_currency(self, _preview.currency, icon.get_center(), 26, Color.WHITE)
	for i in count:
		draw_multiline_string(font, box.position + Vector2(106, 63 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 252, 14, 1, Style.TEXT)


## Вид плашки по виду и ценности добычи.
func _style(node: Node) -> Dictionary:
	var dark := Color(0.02, 0.02, 0.025, 0.82)
	match node.kind:
		&"gear":
			var r: int = node.gear.rarity
			var c: Color = [Color(0.86, 0.86, 0.86), Color(0.66, 0.75, 1.0), Color(1.0, 1.0, 0.47),
					Color(0.69, 0.38, 0.18)][r]
			if r == 3:
				return {"bg": Color(0.08, 0.04, 0.02, 0.9), "text": Color(1.0, 0.55, 0.22), "border": Color(1.0, 0.55, 0.22)}
			return {"bg": dark, "text": c, "border": Color(c, 0.55) if r >= 1 else Color(0, 0, 0, 0)}
		&"module":
			return {"bg": Color(0.02, 0.06, 0.07, 0.88), "text": Color(0.4, 0.95, 0.95), "border": Color(0.3, 0.8, 0.85, 0.7)}
		&"gold":
			return {"bg": Color(0, 0, 0, 0.6), "text": Color(0.85, 0.75, 0.45), "border": Color(0, 0, 0, 0)}
		&"currency":
			var price: int = node.ItemDB.CURRENCY_PRICES.get(node.currency_id, 10)
			var cc: Color = node.ItemDB.CURRENCY[node.currency_id].color
			if price >= 360:
				# Ценное — яркий фон, как «Perfect Jeweller's Orb» в PoE 2.
				return {"bg": dark, "text": cc.lightened(0.3), "border": cc}
			if price >= 180:
				return {"bg": Color(0.07, 0.05, 0.03, 0.9), "text": Color(0.93, 0.85, 0.7), "border": cc}
			return {"bg": dark, "text": Color(0.78, 0.73, 0.62), "border": Color(0, 0, 0, 0)}
	return {"bg": dark, "text": Color.WHITE, "border": Color(0, 0, 0, 0)}
