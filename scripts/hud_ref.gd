extends Control
## Компактный боевой HUD: живые данные поверх художественных PNG, центр свободен.
const Style := preload("res://scripts/ui_style.gd")
const UiIcons := preload("res://scripts/ui_icons.gd")
const FLASK := preload("res://assets/ui/ref/ico_canister.png")
const GRENADE := preload("res://assets/ui/ref/ico_grenade.png")
const HUD_ATLAS := preload("res://assets/ui/gothic_v2/hud_corner_atlas.png")
@export var margin := Vector2.ZERO
## Общий размер нижних панелей; привязки к краям и центру сохраняются.
@export_range(0.7, 1.1, 0.05) var hud_scale := 0.9
@export var left_panel_width := 440.0
@export var right_panel_width := 280.0
@export var life_color := Color(0.63, 0.045, 0.065)
@export var es_color := Color(0.17, 0.74, 0.94)
var player: Node
var _scale := 1.0
var _origin := Vector2.ZERO
var _layout_size := Vector2(1280, 720)
var weapon_rects: Array[Rect2] = []
var vitals_rect := Rect2()
var _portrait: AtlasTexture
var _skills_frame: AtlasTexture
var _weapon_frame: AtlasTexture
## Шлейф урона на полосках Life и Shield: потерянное светлеет и стекает.
@export var chip_color := Color(1.0, 0.86, 0.55)
var _chips := {}  # ключ полоски → [показанная доля, доля шлейфа, ожидание]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait = _atlas(Rect2(24, 155, 958, 356))
	_skills_frame = _atlas(Rect2(24, 648, 1007, 235))
	_weapon_frame = _atlas(Rect2(1000, 83, 516, 433))

func _atlas(region: Rect2) -> AtlasTexture:
	var part := AtlasTexture.new()
	part.atlas = HUD_ATLAS
	part.region = region
	part.filter_clip = true
	return part

func _process(_delta: float) -> void:
	queue_redraw()

func _r(r: Rect2) -> Rect2:
	return Rect2(_origin + r.position * _scale, r.size * _scale)

func _label(text: String, at: Vector2, fs := 14, color := Style.TEXT, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(Loc.MAIN_FONT, _origin + at * _scale, Loc.t(text), align, width * _scale if width > 0 else -1, maxi(9, roundi(fs * _scale)), color)

func _draw() -> void:
	if not is_instance_valid(player): return
	_scale = minf(size.x / 1280.0, size.y / 720.0) * hud_scale
	_layout_size = size / _scale
	_origin = Vector2.ZERO
	_draw_life()
	_draw_weapon()
	_draw_skills()

## Панели используют отдельные области исходного атласа без изменения рисунка.
func _draw_life() -> void:
	var k := left_panel_width / 958.0
	var p := Vector2(margin.x, _layout_size.y - margin.y - 356 * k)
	draw_texture_rect(_portrait, _r(Rect2(p, Vector2(958, 356) * k)), false)
	# Полоски внутри ячеек рамки, с отступом от скруглённых концов (в пикселях атласа).
	var hp := Rect2(p + Vector2(316, 104) * k, Vector2(552, 42) * k)
	var shield := Rect2(p + Vector2(316, 187) * k, Vector2(552, 42) * k)
	var xp := Rect2(p + Vector2(316, 272) * k, Vector2(552, 42) * k)
	vitals_rect = _r(hp)
	_chip(&"life", hp, player.hp / maxf(player.max_hp, 1))
	_fill(hp, player.hp / maxf(player.max_hp, 1), life_color)
	var heal: float = clampf(player.pending_heal() / maxf(player.max_hp, 1), 0, 1 - clampf(player.hp / maxf(player.max_hp, 1), 0, 1))
	if heal > 0:
		var start: float = clampf(player.hp / maxf(player.max_hp, 1), 0, 1)
		draw_rect(_r(Rect2(hp.position + Vector2(hp.size.x * start, 0), Vector2(hp.size.x * heal, hp.size.y))), Color(1, 0.5, 0.5, 0.5))
	_chip(&"shield", shield, player.es / maxf(player.max_es, 1))
	_fill(shield, player.es / maxf(player.max_es, 1), es_color)
	var need: int = player.xp_for_next_level()
	_fill(xp, 1.0 if need <= 0 else float(player.xp) / need, Style.GOLD)
	# Как в PoE: название слева, цифры справа.
	_bar_text(hp, "Life", "%d / %d" % [ceili(player.hp), int(player.max_hp)])
	_bar_text(shield, "Shield", "%d / %d" % [ceili(player.es), int(player.max_es)])
	_bar_text(xp, "EXP  ·  Lv %d" % player.level, "%d / %d" % [player.xp, need])


func _bar_text(bar: Rect2, title: String, value: String) -> void:
	var baseline := bar.position + Vector2(8, bar.size.y * 0.5 + 5)
	# Тёмная обводка: текст читается и на тёмной ячейке, и на золотой полосе опыта.
	var fs := maxi(9, roundi(12 * _scale))
	var outline := maxi(2, roundi(3 * _scale))
	draw_string_outline(Loc.MAIN_FONT, _origin + baseline * _scale, Loc.t(title), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0, 0, 0, 0.85))
	draw_string_outline(Loc.MAIN_FONT, _origin + baseline * _scale, value, HORIZONTAL_ALIGNMENT_RIGHT, (bar.size.x - 16) * _scale, fs, outline, Color(0, 0, 0, 0.85))
	_label(title, baseline, 12)
	_label(value, baseline, 12, Style.TEXT, bar.size.x - 16, HORIZONTAL_ALIGNMENT_RIGHT)

func _chip(key: StringName, rect: Rect2, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var state: Array = _chips.get(key, [ratio, ratio, 0.0])
	var delta := get_process_delta_time()
	if ratio < state[0]:
		state[1] = maxf(state[1], state[0])
		state[2] = 0.35
	elif ratio > state[1]:
		state[1] = ratio
	state[0] = ratio
	if state[1] > ratio:
		state[2] -= delta
		if state[2] <= 0.0:
			state[1] = maxf(ratio, state[1] - 0.9 * delta)
		_fill(rect, state[1], chip_color)
	_chips[key] = state


func _fill(rect: Rect2, ratio: float, color: Color) -> void:
	var fill := Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y))
	if fill.size.x <= 0.5:
		return
	# Скруглённые концы повторяют форму ячейки рамки — полоска не залезает на её края.
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(roundi(minf(fill.size.y * 0.5, fill.size.x * 0.5) * _scale))
	if rect.size.y > 8: box.border_width_top = maxi(1, roundi(2 * _scale))  # блик сверху только у крупных полос
	box.border_color = color.lightened(0.25)
	box.anti_aliasing = true
	draw_style_box(box, _r(fill))

func _draw_weapon() -> void:
	var k := right_panel_width / 516.0
	var height := 433 * k
	var p := Vector2(_layout_size.x - margin.x - right_panel_width, _layout_size.y - margin.y - height)
	draw_texture_rect(_weapon_frame, _r(Rect2(p, Vector2(right_panel_width, height))), false)
	var current: int = player.current_weapon_index()
	weapon_rects.clear()
	var item: GearItem = player.weapon_item(current)
	var data: WeaponData = player.current_weapon()
	# Номера слотов располагаются внутри верхнего окна, а не поверх внешнего декора.
	for i in PlayerInventory.WEAPON_COUNT:
		var box := Rect2(p + Vector2(50 + i * 120, 84) * k, Vector2(105, 40) * k)
		weapon_rects.append(_r(box))
		var other: GearItem = player.weapon_item(i)
		if other != null:
			Style.slot(self, _r(box), _scale, i == current)
			UiIcons.draw_item_picture(self, other, _r(box.grow(-3)))
			_label(str(i + 1), box.position + Vector2(2, 10), 9)
	if item != null:
		UiIcons.draw_item_picture(self, item, _r(Rect2(p + Vector2(50, 145) * k, Vector2(380, 135) * k)))
	if data != null:
		_label(data.display_name, p + Vector2(50, 310) * k, 12, Style.TEXT, 400 * k)
	var ammo := p + Vector2(90, 391) * k
	var progress := Rect2(ammo + Vector2(0, 9), Vector2(95, 3))
	if player.fixed_bow_loadout:
		_label("ЛУК", ammo, 17)
		_fill(progress, player.bow_draw_fraction(), Style.GOLD)
	elif data != null and data.projectile == &"mine" and player.get_node_or_null("Skills") != null:
		var skills: Node = player.get_node("Skills")
		_label("%d / %d" % [skills.mines, skills.max_mines()], ammo, 19)
	else:
		_label("%d / %d" % [player.current_ammo(), player.current_magazine_size()], ammo, 19)
		if player.is_reloading(): _fill(progress, player.reload_progress(), Style.GOLD)

func _draw_skills() -> void:
	var p := Vector2((_layout_size.x - 360) * 0.5, _layout_size.y - margin.y - 84.01)
	draw_texture_rect(_skills_frame, _r(Rect2(p, Vector2(360, 84.01))), false)
	var skills: Node = player.get_node_or_null("Skills")
	for i in 6:
		var cell := Rect2(p + Vector2(14 + i * 57.2, 17.5), Vector2(45, 43))
		var center := _r(cell).get_center()
		var key := ""
		var count := ""
		var cooldown := 0.0
		var enabled := true
		match i:
			0:
				key = Loc.action_key("shoot")
				var item: GearItem = player.weapon_item(player.current_weapon_index())
				if item != null: UiIcons.draw_item_picture(self, item, _r(cell.grow(-3)))
			1:
				if skills == null: continue
				key = Loc.action_key("skill_grenade")
				if skills.has_pulse():
					UiIcons.draw_module(self, &"electric", center, 15 * _scale, Style.BLUE)
					cooldown = skills.pulse_cooldown
					if skills.is_charging_pulse():
						var data: WeaponData = player.current_weapon()
						_fill(Rect2(cell.position + Vector2(3, 32), Vector2(33, 4)), 1.0 - skills._pulse_charge_left / maxf(data.secondary_charge, 0.001), Style.BLUE)
				elif skills.has_grenade():
					UiIcons.draw_texture_fit(self, GRENADE, _r(cell.grow(-5)))
					count = str(skills.grenades)
					if skills.grenades == 0: cooldown = skills.grenade_timer
				else: enabled = false
			2:
				key = Loc.action_key("heal")
				UiIcons.draw_texture_fit(self, FLASK, _r(cell.grow(-4)))
				count = str(int(player.flask_charges))
				enabled = player.flask_charges >= 1
			3:
				key = Loc.action_key("dodge")
				UiIcons.draw_stat(self, &"speed", center, 15 * _scale, Style.GOLD)
			4:
				if skills == null or Game.mode != &"demo": continue
				key = Loc.action_key("skill_nova")
				UiIcons.draw_module(self, &"electric", center, 15 * _scale, Style.BLUE)
				cooldown = skills.nova_timer
			5:
				if skills == null: continue
				key = Loc.action_key("skill_fireball")
				UiIcons.draw_module(self, &"fire", center, 17 * _scale, Color(1.0, 0.45, 0.12))
				cooldown = skills.fireball_timer
		if not enabled or cooldown > 0:
			draw_rect(_r(cell), Color(0, 0, 0, 0.65))
		if cooldown > 0: _label("%.1f" % cooldown, cell.position + Vector2(10, 28), 15)
		if count != "": _label(count, cell.position + Vector2(27, 34), 12)
		# Показываем привязку выбранного устройства, включая переназначенные кнопки.
		if enabled or i == 2:
			_label(key.split(" / ")[0], p + Vector2(23 + i * 57.2, 77), 9, Style.GOLD, 32)
