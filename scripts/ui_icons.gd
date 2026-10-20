extends RefCounted
## Значки интерфейса, нарисованные кодом (пока нет картинок): оружие и модули.
## Все функции рисуют на любом CanvasItem (Control или Node2D) внутри его _draw().
## pos — центр значка, r — «радиус» (половина размера), color — цвет.

const WEAPONS := {
	&"pistol": [
		[Vector2(-0.75, -0.4), Vector2(0.8, -0.4), Vector2(0.8, -0.05), Vector2(-0.75, -0.05)],
		[Vector2(-0.65, -0.05), Vector2(-0.2, -0.05), Vector2(-0.35, 0.7), Vector2(-0.8, 0.7)],
		[Vector2(-0.2, -0.05), Vector2(0.15, -0.05), Vector2(0.05, 0.2), Vector2(-0.25, 0.2)],
	],
	&"rifle": [
		[Vector2(-1.0, -0.12), Vector2(-0.55, -0.25), Vector2(-0.55, 0.12), Vector2(-1.0, 0.25)],
		[Vector2(-0.55, -0.25), Vector2(0.45, -0.25), Vector2(0.45, 0.05), Vector2(-0.55, 0.05)],
		[Vector2(0.45, -0.18), Vector2(1.0, -0.18), Vector2(1.0, -0.07), Vector2(0.45, -0.07)],
		[Vector2(-0.05, 0.05), Vector2(0.15, 0.05), Vector2(0.12, 0.55), Vector2(-0.08, 0.5)],
		[Vector2(-0.42, 0.05), Vector2(-0.24, 0.05), Vector2(-0.32, 0.4), Vector2(-0.5, 0.4)],
	],
	&"shotgun": [
		[Vector2(-1.0, -0.05), Vector2(-0.5, -0.2), Vector2(-0.5, 0.12), Vector2(-1.0, 0.32)],
		[Vector2(-0.5, -0.2), Vector2(0.0, -0.2), Vector2(0.0, 0.08), Vector2(-0.5, 0.08)],
		[Vector2(0.0, -0.2), Vector2(1.0, -0.2), Vector2(1.0, -0.03), Vector2(0.0, -0.03)],
		[Vector2(0.22, -0.03), Vector2(0.65, -0.03), Vector2(0.65, 0.15), Vector2(0.22, 0.15)],
		[Vector2(-0.42, 0.08), Vector2(-0.24, 0.08), Vector2(-0.32, 0.38), Vector2(-0.5, 0.38)],
	],
}


static var _textures := {}
static var _item_views := {}
const ITEM_SHADER := preload("res://assets/shaders/item_icon.gdshader")

## Прозрачная подложка старых картинок только при показе. Исходные PNG не изменяются.
static func item_texture(path: String) -> Texture2D:
	var original := texture(path)
	if original == null or not (path.contains("/corp_weapons/") or path.contains("/gear/")): return original
	if not _item_views.has(path):
		var viewport := SubViewport.new()
		viewport.size = original.get_size()
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var sprite := Sprite2D.new()
		sprite.texture = original
		sprite.centered = false
		var material := ShaderMaterial.new()
		material.shader = ITEM_SHADER
		sprite.material = material
		viewport.add_child(sprite)
		Engine.get_main_loop().root.add_child.call_deferred(viewport)
		_item_views[path] = viewport
		return original
	var rendered: SubViewport = _item_views[path]
	return rendered.get_texture() if rendered.is_inside_tree() else original


static func draw_mine(ci: CanvasItem, rect: Rect2, color := Color.WHITE) -> void:
	var icon := texture("res://assets/icons/weapons/mine_pack_v2.png")
	if icon != null:
		draw_texture_fit(ci, icon, rect, color)


## Картинка по пути (кэш); нет файла — null.
static func texture(path: String) -> Texture2D:
	if path == "":
		return null
	# Реалистичный комплект первого акта; прежние исходники остаются доступны.
	if path.begins_with("res://assets/icons/act_one/"):
		var realistic_path := path.replace("/act_one/", "/act_one_realistic/")
		if ResourceLoader.exists(realistic_path):
			path = realistic_path
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## Картинка вписана в rect с сохранением пропорций (под углом angle_deg).
static func draw_texture_fit(ci: CanvasItem, tex: Texture2D, rect: Rect2, modulate := Color.WHITE, angle_deg := 0.0) -> void:
	var angle := deg_to_rad(angle_deg)
	var ts := Vector2(tex.get_size())
	var c := absf(cos(angle))
	var s := absf(sin(angle))
	var bounds := Vector2(ts.x * c + ts.y * s, ts.x * s + ts.y * c)
	var k := minf(rect.size.x / bounds.x, rect.size.y / bounds.y)
	ci.draw_set_transform(rect.get_center(), angle, Vector2(k, k))
	ci.draw_texture_rect(tex, Rect2(-ts * 0.5, ts), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Значок вещи: картинка (GearItem.icon_path) или false, если картинки нет.
static func draw_item_picture(ci: CanvasItem, item: GearItem, rect: Rect2, modulate := Color.WHITE) -> bool:
	var tex := item_texture(item.icon_path())
	if tex == null:
		return false
	# Оружие остаётся горизонтальным даже в высокой клетке сумки.
	var angle := 0.0
	var flip := item.slot == &"gloves" and (item.icon_path().contains("gloves_vortech") or item.icon_path().contains("gloves_kraken"))
	var rad := deg_to_rad(angle)
	var ts := Vector2(tex.get_size())
	var bounds := Vector2(ts.x * absf(cos(rad)) + ts.y * absf(sin(rad)), ts.x * absf(sin(rad)) + ts.y * absf(cos(rad)))
	var k := minf(rect.size.x / bounds.x, rect.size.y / bounds.y)
	ci.draw_set_transform(rect.get_center(), rad, Vector2(-k if flip else k, k))
	ci.draw_texture_rect(tex, Rect2(-ts * 0.5, ts), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not item.is_weapon() and item.slot in [&"helmet", &"body", &"gloves", &"boots"]:
		draw_defense_badge(ci, item.defense_kind(), rect, modulate.a)
	return true


## Пластинчатый щит — броня, шестигранник с молнией — энергощит; гибрид показывает оба.
static func draw_defense_badge(ci: CanvasItem, kind: StringName, rect: Rect2, opacity := 1.0) -> void:
	if kind not in [&"armor", &"es", &"hybrid"]:
		return
	var size := clampf(minf(rect.size.x, rect.size.y) * 0.20, 8.0, 18.0)
	var count := 2 if kind == &"hybrid" else 1
	for i in count:
		var energy := kind == &"es" or (kind == &"hybrid" and i == 1)
		var center := rect.end - Vector2(size * (0.65 + (count - 1 - i) * 1.15), size * 0.65)
		var tint := Color("a9dbed") if energy else Color("d1b78e")
		tint.a = opacity
		ci.draw_circle(center, size * 0.64, Color(0.035, 0.028, 0.025, opacity * 0.94), true, -1, true)
		var points := PackedVector2Array()
		if energy:
			for j in 7:
				points.append(center + Vector2.from_angle(TAU * (j % 6) / 6.0 - PI / 2) * size * 0.47)
		else:
			for point in [Vector2(-0.40, -0.42), Vector2(0.40, -0.42), Vector2(0.34, 0.17), Vector2(0, 0.48), Vector2(-0.34, 0.17), Vector2(-0.40, -0.42)]:
				points.append(center + point * size)
		ci.draw_polyline(points, tint, maxf(1.0, size * 0.07), true)
		if energy:
			ci.draw_polyline(PackedVector2Array([center + Vector2(0.08, -0.30) * size, center + Vector2(-0.12, 0.03) * size, center + Vector2(0.12, -0.03) * size, center + Vector2(-0.08, 0.30) * size]), tint, maxf(1.0, size * 0.07), true)
		else:
			ci.draw_line(center + Vector2(0, -0.25) * size, center + Vector2(0, 0.23) * size, tint, maxf(1.0, size * 0.07), true)


## Силуэт оружия, повёрнут наискосок (angle_deg), как в меню-крестовине.
## Картинки оружия (отрисованные модели, assets/icons/weapons/<файл оружия>.png).
static var _weapon_textures := {}


static func weapon_texture(data: WeaponData) -> Texture2D:
	if data == null:
		return null
	var act_path := "res://assets/icons/act_one/%s.png" % data.resource_path.get_file().get_basename()
	if ResourceLoader.exists(act_path):
		return texture(act_path)
	var path := "res://assets/icons/weapons/%s.png" % data.resource_path.get_file().get_basename()
	if not _weapon_textures.has(path):
		_weapon_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _weapon_textures[path]


## Иконка оружия — картинка модели, вписанная в rect (под углом angle_deg). Нет картинки — рисованный значок.
static func draw_weapon_picture(ci: CanvasItem, data: WeaponData, rect: Rect2, modulate := Color.WHITE,
		angle_deg := 0.0) -> void:
	var tex := weapon_texture(data)
	if tex == null:
		draw_weapon(ci, data.icon if data != null else &"", rect.get_center(), minf(rect.size.x, rect.size.y) * 0.45, modulate)
		return
	var angle := deg_to_rad(angle_deg)
	# Сколько места занимает повёрнутая картинка — подбираем масштаб, чтобы влезла в rect.
	var ts := Vector2(tex.get_size())
	var c := absf(cos(angle))
	var s := absf(sin(angle))
	var bounds := Vector2(ts.x * c + ts.y * s, ts.x * s + ts.y * c)
	var k := minf(rect.size.x / bounds.x, rect.size.y / bounds.y)
	ci.draw_set_transform(rect.get_center(), angle, Vector2(k, k))
	ci.draw_texture_rect(tex, Rect2(-ts * 0.5, ts), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_weapon(ci: CanvasItem, icon: StringName, pos: Vector2, r: float, color: Color, angle_deg := -35.0) -> void:
	if icon == &"bow":
		var rot := Transform2D(deg_to_rad(angle_deg), pos)
		var stave := PackedVector2Array()
		for p in [Vector2(.3, -1), Vector2(-.15, -.65), Vector2(-.45, 0), Vector2(-.15, .65), Vector2(.3, 1)]:
			stave.append(rot * (p * r))
		ci.draw_polyline(stave, color, maxf(2, r * .12), true)
		ci.draw_line(stave[0], stave[-1], color, maxf(1, r * .035), true)
		return
	if not WEAPONS.has(icon):
		draw_plus(ci, pos, r * 0.5, color)
		return
	var rot := Transform2D(deg_to_rad(angle_deg), Vector2.ZERO)
	for part in WEAPONS[icon]:
		var poly := PackedVector2Array()
		for p in part:
			poly.append(pos + rot * (p * r))
		ci.draw_colored_polygon(poly, color)


static func draw_plus(ci: CanvasItem, pos: Vector2, r: float, color: Color) -> void:
	var w := r * 0.36
	ci.draw_rect(Rect2(pos.x - r, pos.y - w, r * 2.0, w * 2.0), color)
	ci.draw_rect(Rect2(pos.x - w, pos.y - r, w * 2.0, r * 2.0), color)


## Значок модуля по его id. Неизвестный id — ромбик.
static func draw_module(ci: CanvasItem, id: StringName, pos: Vector2, r: float, color: Color) -> void:
	var new_icon := texture("res://assets/icons/modules_v2/%s.png" % id)
	if new_icon != null:
		draw_texture_fit(ci, new_icon, Rect2(pos - Vector2.ONE * r, Vector2.ONE * r * 2), Color(1, 1, 1, color.a))
		return
	# Есть картинка модуля (вырезана из референса) — рисуем её.
	var tex := texture("res://assets/icons/modules/%s.png" % id)
	if tex != null:
		draw_texture_fit(ci, tex, Rect2(pos - Vector2(r, r) * 1.45, Vector2(r, r) * 2.9), Color(1, 1, 1, color.a))
		return
	var w := maxf(r * 0.16, 1.5)  # толщина линий
	match id:
		&"fire":
			# Пламя: внешний язык и внутренний светлый.
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(0, -1), Vector2(0.35, -0.45), Vector2(0.65, -0.1), Vector2(0.7, 0.35), Vector2(0.4, 0.85),
				Vector2(0, 1), Vector2(-0.4, 0.85), Vector2(-0.7, 0.35), Vector2(-0.55, -0.15), Vector2(-0.3, 0.1),
				Vector2(-0.2, -0.45)]), color)
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(0.05, -0.2), Vector2(0.35, 0.3), Vector2(0.25, 0.75), Vector2(0, 0.85), Vector2(-0.25, 0.75),
				Vector2(-0.3, 0.35)]), color.lightened(0.6))
		&"electric":
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(0.25, -1), Vector2(-0.55, 0.15), Vector2(-0.05, 0.15), Vector2(-0.3, 1),
				Vector2(0.55, -0.2), Vector2(0.05, -0.2), Vector2(0.35, -1)]), color)
		&"acid":
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(0, -1), Vector2(0.35, -0.35), Vector2(0.6, 0.15), Vector2(0.55, 0.55), Vector2(0.25, 0.85),
				Vector2(-0.25, 0.85), Vector2(-0.55, 0.55), Vector2(-0.6, 0.15), Vector2(-0.35, -0.35)]), color)
			ci.draw_circle(pos + Vector2(-0.2, 0.3) * r, r * 0.16, color.lightened(0.6))
			ci.draw_circle(pos + Vector2(0.6, -0.6) * r, r * 0.15, color)
		&"ricochet":
			var pts := _pts(pos, r, [Vector2(-0.9, 0.7), Vector2(-0.3, -0.5), Vector2(0.2, 0.5), Vector2(0.8, -0.6)])
			ci.draw_polyline(pts, color, w, true)
			_arrow_head(ci, pts[2], pts[3], r * 0.45, color)
		&"pierce":
			ci.draw_arc(pos, r * 0.45, 0, TAU, 24, color, w * 0.8, true)
			ci.draw_line(pos + Vector2(-1, 0) * r, pos + Vector2(0.75, 0) * r, color, w, true)
			_arrow_head(ci, pos, pos + Vector2(1, 0) * r, r * 0.45, color)
		&"fast_reload":
			ci.draw_arc(pos, r * 0.7, deg_to_rad(-60), deg_to_rad(220), 24, color, w, true)
			var tip := pos + Vector2.from_angle(deg_to_rad(-60)) * r * 0.7
			_arrow_head(ci, tip + Vector2(-0.4, -0.5) * r, tip, r * 0.45, color)
		&"ext_mag":
			for i in 3:
				var y := -0.75 + i * 0.55
				ci.draw_rect(Rect2(pos + Vector2(-0.55, y) * r, Vector2(1.1, 0.38) * r), color)
		&"damage":
			# Восьмиконечная звезда-вспышка.
			var star := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0 - PI * 0.5
				star.append(pos + Vector2.from_angle(a) * r * (1.0 if i % 2 == 0 else 0.42))
			ci.draw_colored_polygon(star, color)
		&"fire_rate":
			for dx in [-0.45, 0.25]:
				ci.draw_polyline(_pts(pos, r, [Vector2(dx - 0.25, -0.7), Vector2(dx + 0.35, 0), Vector2(dx - 0.25, 0.7)]), color, w * 1.3, true)
		&"multishot":
			for a in [-30.0, 0.0, 30.0]:
				var dir := Vector2.from_angle(deg_to_rad(a - 90.0))
				var from := pos + Vector2(0, 0.8) * r
				var to := from + dir * r * 1.55
				ci.draw_line(from, to - dir * r * 0.3, color, w, true)
				_arrow_head(ci, from, to, r * 0.38, color)
		&"nova_shot":
			ci.draw_circle(pos, r * 0.23, color.lightened(0.35))
			for i in 5:
				var direction := Vector2.from_angle(TAU * i / 5.0 - PI * 0.5)
				ci.draw_line(pos + direction * r * 0.36, pos + direction * r * 0.78, color, w, true)
				ci.draw_circle(pos + direction * r * 0.86, r * 0.12, color)
		&"leech":
			# Сердце.
			var heart := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				heart.append(pos + Vector2(x, y) / 17.0 * r)
			ci.draw_colored_polygon(heart, color)
		&"explosive":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(pos + Vector2.from_angle(a) * r * 0.35, pos + Vector2.from_angle(a) * r * 0.95, color, w)
			ci.draw_circle(pos, r * 0.35, color.lightened(0.4))
		&"homing":
			ci.draw_arc(pos, r * 0.8, 0, TAU, 24, color, w, true)
			ci.draw_arc(pos, r * 0.42, 0, TAU, 16, color, w, true)
			ci.draw_circle(pos, r * 0.14, color)
		&"overcharge":
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(-0.1, -1), Vector2(-0.65, 0.1), Vector2(-0.25, 0.1), Vector2(-0.45, 1),
				Vector2(0.1, -0.15), Vector2(-0.25, -0.15), Vector2(0.05, -1)]), color)
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(0.45, -1), Vector2(0.05, -0.05), Vector2(0.35, -0.05), Vector2(0.2, 0.75),
				Vector2(0.75, -0.25), Vector2(0.45, -0.25), Vector2(0.65, -1)]), color.lightened(0.3))
		_:
			ci.draw_colored_polygon(_shape(pos, r * 0.7, [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]), color)


## Значок экипировки по слоту (helmet, body, gloves, boots, implant, combat).
## kind — тип защиты вещи: &"armor" (броня — сплошные пластины), &"es" (энергощит — тёмная основа
## и светящееся энергоядро), &"hybrid" (пластины + энергополоса), пусто — просто силуэт.
static func draw_gear(ci: CanvasItem, slot: StringName, pos: Vector2, r: float, color: Color, kind := &"") -> void:
	_draw_gear_shape(ci, slot, pos, r, color.darkened(0.45) if kind == &"es" else color)
	var energy := Color(0.45, 0.85, 1.0, color.a).lerp(Color(color, color.a), 0.25)
	match kind:
		&"armor":
			# Заклёпки — признак тяжёлой брони.
			for p in [Vector2(-0.45, -0.35), Vector2(0.45, -0.35), Vector2(-0.45, 0.45), Vector2(0.45, 0.45)]:
				ci.draw_circle(pos + p * r, r * 0.07, color.darkened(0.6))
		&"es":
			ci.draw_arc(pos, r * 0.36, 0, TAU, 20, energy, maxf(r * 0.08, 1.5), true)
			ci.draw_circle(pos, r * 0.2, energy)
			ci.draw_circle(pos, r * 0.09, Color(1, 1, 1, color.a))
		&"hybrid":
			ci.draw_line(pos + Vector2(-0.65, 0.55) * r, pos + Vector2(0.65, -0.45) * r, energy, maxf(r * 0.13, 2.0), true)
			ci.draw_circle(pos + Vector2(0, 0.05) * r, r * 0.13, energy)


static func _draw_gear_shape(ci: CanvasItem, slot: StringName, pos: Vector2, r: float, color: Color) -> void:
	var dark := color.darkened(0.55)
	match slot:
		&"helmet":
			# Купол шлема со стеклом-визором.
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				dome.append(pos + Vector2(cos(a) * 0.85, sin(a) * 0.8 + 0.15) * r)
			dome.append(pos + Vector2(0.85, 0.55) * r)
			dome.append(pos + Vector2(-0.85, 0.55) * r)
			ci.draw_colored_polygon(dome, color)
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(-0.6, -0.05), Vector2(0.6, -0.05), Vector2(0.5, 0.3), Vector2(-0.5, 0.3)]), dark)
		&"body":
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(-0.35, -0.9), Vector2(-0.15, -0.75), Vector2(0.15, -0.75), Vector2(0.35, -0.9), Vector2(0.85, -0.6),
				Vector2(0.7, -0.15), Vector2(0.55, -0.2), Vector2(0.55, 0.9), Vector2(-0.55, 0.9), Vector2(-0.55, -0.2),
				Vector2(-0.7, -0.15), Vector2(-0.85, -0.6)]), color)
			for y in [-0.25, 0.15, 0.55]:
				ci.draw_rect(Rect2(pos + Vector2(-0.4, y) * r, Vector2(0.8, 0.18) * r), dark)
		&"gloves":
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(-0.55, 0.9), Vector2(-0.55, -0.1), Vector2(-0.45, -0.75), Vector2(-0.25, -0.75), Vector2(-0.22, -0.2),
				Vector2(-0.12, -0.9), Vector2(0.08, -0.9), Vector2(0.1, -0.2), Vector2(0.18, -0.8), Vector2(0.38, -0.8),
				Vector2(0.38, -0.15), Vector2(0.55, -0.55), Vector2(0.75, -0.45), Vector2(0.55, 0.2), Vector2(0.5, 0.9)]), color)
			ci.draw_rect(Rect2(pos + Vector2(-0.6, 0.55) * r, Vector2(1.15, 0.35) * r), dark)
		&"boots":
			ci.draw_colored_polygon(_shape(pos, r, [
				Vector2(-0.45, -0.9), Vector2(0.2, -0.9), Vector2(0.2, 0.25), Vector2(0.85, 0.45), Vector2(0.9, 0.85),
				Vector2(-0.5, 0.85), Vector2(-0.5, 0.2)]), color)
			ci.draw_rect(Rect2(pos + Vector2(-0.5, 0.62) * r, Vector2(1.4, 0.23) * r), dark)
		&"implant":
			# Микросхема с ножками.
			ci.draw_rect(Rect2(pos + Vector2(-0.55, -0.55) * r, Vector2(1.1, 1.1) * r), color)
			ci.draw_rect(Rect2(pos + Vector2(-0.25, -0.25) * r, Vector2(0.5, 0.5) * r), dark)
			for i in 3:
				var o := -0.35 + i * 0.35
				for side in [-1.0, 1.0]:
					ci.draw_line(pos + Vector2(o, side * 0.55) * r, pos + Vector2(o, side * 0.85) * r, color, maxf(r * 0.1, 1.5))
					ci.draw_line(pos + Vector2(side * 0.55, o) * r, pos + Vector2(side * 0.85, o) * r, color, maxf(r * 0.1, 1.5))
		&"combat":
			# Ромб-кулон с ядром на цепочке.
			ci.draw_arc(pos + Vector2(0, -0.55) * r, r * 0.45, PI * 1.1, PI * 1.9, 12, color, maxf(r * 0.08, 1.5), true)
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(0, -0.45), Vector2(0.6, 0.2), Vector2(0, 0.9), Vector2(-0.6, 0.2)]), color)
			ci.draw_circle(pos + Vector2(0, 0.2) * r, r * 0.22, dark)
		_:
			draw_plus(ci, pos, r * 0.6, color)


## Значок ксено-фрагмента / чистого модуля.
static func draw_currency(ci: CanvasItem, id: StringName, pos: Vector2, r: float, color: Color) -> void:
	var new_icon := texture("res://assets/icons/currency_v2/%s.png" % id)
	if new_icon != null:
		draw_texture_fit(ci, new_icon, Rect2(pos - Vector2.ONE * r, Vector2.ONE * r * 2), Color(1, 1, 1, color.a))
		return
	if id == &"blank_module":
		var tex := texture("res://assets/icons/modules/blank_module.png")
		if tex != null:
			draw_texture_fit(ci, tex, Rect2(pos - Vector2(r, r) * 1.2, Vector2(r, r) * 2.4), Color(1, 1, 1, color.a))
			return
	match id:
		&"mutagen", &"unstable":
			# Колба: горлышко и круглое дно с жидкостью.
			ci.draw_rect(Rect2(pos + Vector2(-0.18, -0.9) * r, Vector2(0.36, 0.5) * r), color.darkened(0.3))
			ci.draw_circle(pos + Vector2(0, 0.25) * r, r * 0.62, color.darkened(0.55))
			ci.draw_circle(pos + Vector2(0, 0.35) * r, r * 0.5, color)
			if id == &"unstable":
				ci.draw_arc(pos + Vector2(0, 0.3) * r, r * 0.28, 0, PI * 1.5, 12, color.lightened(0.7), maxf(r * 0.1, 1.5), true)
		&"hive_core":
			var spikes := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				spikes.append(pos + Vector2.from_angle(a) * r * (0.95 if i % 2 == 0 else 0.6))
			ci.draw_colored_polygon(spikes, color.darkened(0.3))
			ci.draw_circle(pos, r * 0.48, color)
			ci.draw_circle(pos, r * 0.2, color.lightened(0.7))
		&"queen_heart":
			# Сфера с короной из трёх зубцов.
			ci.draw_circle(pos + Vector2(0, 0.2) * r, r * 0.68, color.darkened(0.35))
			ci.draw_circle(pos + Vector2(0, 0.2) * r, r * 0.45, color)
			ci.draw_circle(pos + Vector2(-0.15, 0.05) * r, r * 0.14, color.lightened(0.7))
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(-0.6, -0.4), Vector2(-0.45, -1), Vector2(-0.2, -0.6),
				Vector2(0, -1.05), Vector2(0.2, -0.6), Vector2(0.45, -1), Vector2(0.6, -0.4)]), color.lightened(0.3))
		&"catalyst":
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(0, -1), Vector2(0.5, -0.3), Vector2(0.35, 0.9), Vector2(-0.35, 0.9), Vector2(-0.5, -0.3)]), color)
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(0, -1), Vector2(0.15, -0.3), Vector2(0, 0.9), Vector2(-0.35, 0.9), Vector2(-0.5, -0.3)]), color.lightened(0.35))
		&"blank_module":
			var hexagon := PackedVector2Array()
			for i in 7:
				hexagon.append(pos + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r * 0.85)
			ci.draw_polyline(hexagon, color, maxf(r * 0.14, 2.0), true)
			ci.draw_circle(pos, r * 0.18, color)
		&"socket_cutter":
			# Кольцо-гнездо и режущая кромка.
			ci.draw_arc(pos + Vector2(0.15, 0.15) * r, r * 0.55, 0, TAU, 20, color, maxf(r * 0.16, 2.0), true)
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(-0.95, -0.95), Vector2(-0.15, -0.55), Vector2(-0.55, -0.15)]),
					color.lightened(0.4))
		&"cocoon":
			# Кокон: вытянутый овал с прожилками.
			var oval := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				oval.append(pos + Vector2(cos(a) * 0.55, sin(a) * 0.95) * r)
			ci.draw_colored_polygon(oval, color.darkened(0.3))
			for k in 3:
				var y := (-0.5 + k * 0.5) * r
				ci.draw_line(pos + Vector2(-0.45 * r, y), pos + Vector2(0.45 * r, y + 0.2 * r), color.lightened(0.5), maxf(r * 0.08, 1.0))
		&"solvent":
			ci.draw_circle(pos + Vector2(0, 0.25) * r, r * 0.6, color.darkened(0.3))
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(0, -1), Vector2(0.55, 0.05), Vector2(-0.55, 0.05)]), color.darkened(0.3))
			ci.draw_circle(pos + Vector2(-0.15, 0.15) * r, r * 0.18, color.lightened(0.6))
		&"plating_kit", &"calibration_kit":
			# Пластина с болтами / шестерня калибровки.
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(-0.8, -0.55), Vector2(0.8, -0.55), Vector2(0.65, 0.7),
				Vector2(-0.65, 0.7)]), color.darkened(0.3))
			for p in [Vector2(-0.5, -0.3), Vector2(0.5, -0.3), Vector2(-0.4, 0.45), Vector2(0.4, 0.45)]:
				ci.draw_circle(pos + p * r, r * 0.1, color.lightened(0.5))
			if id == &"calibration_kit":
				ci.draw_arc(pos, r * 0.28, 0, TAU, 12, color.lightened(0.6), maxf(r * 0.1, 1.5), true)
		&"aug_life", &"aug_es", &"aug_armour", &"aug_fire", &"aug_lightning", &"aug_acid":
			# Чип-аугмент: шестиугольник с цветным ядром.
			var hexagon := PackedVector2Array()
			for i in 6:
				hexagon.append(pos + Vector2.from_angle(TAU * i / 6.0) * r * 0.85)
			ci.draw_colored_polygon(hexagon, Color(0.12, 0.12, 0.14, color.a))
			hexagon.append(hexagon[0])
			ci.draw_polyline(hexagon, color, maxf(r * 0.1, 1.5), true)
			ci.draw_circle(pos, r * 0.32, color)
		&"stabilizer":
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(0, -1), Vector2(0.7, 0), Vector2(0, 1), Vector2(-0.7, 0)]), color.darkened(0.25))
			ci.draw_colored_polygon(_shape(pos, r, [Vector2(0, -0.55), Vector2(0.38, 0), Vector2(0, 0.55), Vector2(-0.38, 0)]), color)
		_:
			draw_plus(ci, pos, r * 0.6, color)


## Значки характеристик для окна персонажа: life, energy_shield, armor, speed (+ огонь/электр./кислота — draw_module).
static func draw_stat(ci: CanvasItem, id: StringName, pos: Vector2, r: float, color: Color) -> void:
	match id:
		&"life":
			draw_module(ci, &"leech", pos, r, color)
		&"armor":
			ci.draw_colored_polygon(_shield(pos, r), color)
			ci.draw_colored_polygon(_shield(pos, r * 0.62), color.darkened(0.35))
		&"energy_shield":
			ci.draw_colored_polygon(_shield(pos, r), color.darkened(0.45))
			ci.draw_polyline(_closed(_shield(pos, r)), color, maxf(r * 0.1, 1.5), true)
			draw_module(ci, &"electric", pos + Vector2(0, -0.05) * r, r * 0.6, color.lightened(0.4))
		&"helmet":
			draw_gear(ci, &"helmet", pos, r, color)
		&"speed":
			draw_gear(ci, &"boots", pos, r * 0.85, color)
			for i in 3:
				var y := -0.5 + i * 0.4
				ci.draw_line(pos + Vector2(-1.0, y) * r, pos + Vector2(-0.65, y) * r, color, maxf(r * 0.08, 1.5))
		_:
			draw_module(ci, id, pos, r, color)


static func _shield(pos: Vector2, r: float) -> PackedVector2Array:
	return _shape(pos, r, [Vector2(0, -1), Vector2(0.85, -0.7), Vector2(0.8, 0.1), Vector2(0, 1),
		Vector2(-0.8, 0.1), Vector2(-0.85, -0.7)])


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result


static func _shape(pos: Vector2, r: float, points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(pos + p * r)
	return result


static func _pts(pos: Vector2, r: float, points: Array) -> PackedVector2Array:
	return _shape(pos, r, points)


static func _arrow_head(ci: CanvasItem, from: Vector2, tip: Vector2, size: float, color: Color) -> void:
	var dir := (tip - from).normalized()
	var side := dir.orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - dir * size + side * size * 0.6, tip - dir * size - side * size * 0.6]), color)
