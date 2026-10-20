extends CanvasLayer
## Боевой интерфейс: портрет и показатели слева внизу, действия по центру, оружие справа.
## Данные берёт у игрока (родительский узел); прежняя компоновка сохранена как запасная.

const QuickMenu := preload("res://scripts/hud_quick_menu.gd")
const LifeBar := preload("res://scripts/hud_life_bar.gd")
const XpBar := preload("res://scripts/hud_xp_bar.gd")
const CharacterScreen := preload("res://scripts/character_screen.gd")
const PassiveTree := preload("res://scripts/passive_tree_screen.gd")
const DamageOverlay := preload("res://scripts/hud_damage_overlay.gd")
const Notifications := preload("res://scripts/hud_notifications.gd")
const RefHud := preload("res://scripts/hud_ref.gd")
const LootLabels := preload("res://scripts/hud_loot_labels.gd")
const WorldLabels := preload("res://scripts/hud_world_labels.gd")
const WorldPrompt := preload("res://scripts/hud_world_prompt.gd")
const Quest := preload("res://scripts/hud_quest.gd")
const FirstTimeHints := preload("res://scripts/first_time_hints.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const SkillsScreen := preload("res://scripts/skills_screen.gd")
const InventoryScreen := preload("res://scripts/inventory_screen.gd")
const Minimap := preload("res://scripts/hud_minimap.gd")
const TargetBar := preload("res://scripts/hud_target_bar.gd")
const Crosshair := preload("res://scripts/hud_crosshair.gd")

@export var margin := Vector2(28, 24)
@export var health_bar_width := 380.0
@export var font_size := 19
## HUD с готическим портретом, полосами, шестью ячейками и рамкой оружия. false — старый HUD.
@export var reference_hud := true
@export var low_ammo_color := Color(1.0, 0.35, 0.25)
@export var normal_color := Color(0.85, 0.92, 1.0)

var _player: Node
var _weapon_label: Label
var _ammo_label: Label
var _reload_bar: ProgressBar
## Лента сообщений слева сверху (задания, подсказки, новый уровень).
var notifications: Control
var _prompt: Label
const HINT := "X поднять · E/↑ аптечка · 1/2 оружие · R/X перезарядка · Tab/Back инвентарь · C персонаж · P/R3 пассивки · H/L3 портал · Esc/Start меню"
var _hint: Label
## Экран инвентаря (его открывают и торговец с верстаком).
var inventory_screen: Control
var skills_screen: Control


func _ready() -> void:
	_player = get_parent()

	# Красная вспышка и кровь по краям экрана при уроне (под остальным интерфейсом).
	var overlay := DamageOverlay.new()
	overlay.player = _player
	add_child(overlay)

	# Подписи добычи — плашками, как в PoE 2 (под остальным интерфейсом).
	var loot_labels := LootLabels.new()
	loot_labels.player = _player
	add_child(loot_labels)
	_player.loot_labels = loot_labels
	var world_labels := WorldLabels.new()
	world_labels.player = _player
	add_child(world_labels)
	var world_prompt := WorldPrompt.new()
	world_prompt.player = _player
	add_child(world_prompt)

	if reference_hud:
		var ref := RefHud.new()
		ref.player = _player
		add_child(ref)
	else:
		# --- Справа внизу: полоска здоровья (сверху — энергощит) ---
		var life := LifeBar.new()
		life.player = _player
		_place(life, true, margin.x - 6, margin.y, Vector2(280, 22))
		life.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(life)

		# --- Слева внизу: меню-крестовина ---
		var menu := QuickMenu.new()
		menu.player = _player
		_place(menu, false, margin.x - 8, margin.y - 6, Vector2(116, 116))
		menu.clip_contents = false
		menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(menu)

	# Патроны — справа от крестовины, на уровне правого ромба.
	var ammo_box := VBoxContainer.new()
	_place(ammo_box, false, margin.x + 106, margin.y + 26, Vector2(200, 52))
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_box.visible = not reference_hud  # в HUD из референса патроны — в рамке оружия
	add_child(ammo_box)
	_weapon_label = _make_label(int(font_size * 0.62))
	_weapon_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_box(_weapon_label, Color(0, 0, 0, 0))
	ammo_box.add_child(_weapon_label)
	_ammo_label = _make_label(font_size)
	_ammo_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_box(_ammo_label, Color(0, 0, 0, 0))
	ammo_box.add_child(_ammo_label)
	_reload_bar = ProgressBar.new()
	_reload_bar.custom_minimum_size = Vector2(110, 4)
	_reload_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	ammo_box.add_child(_reload_bar)

	# --- Внизу по центру: опыт и уровень ---
	var xp := XpBar.new()
	xp.player = _player
	xp.anchor_left = 0.5
	xp.anchor_right = 0.5
	xp.anchor_top = 1.0
	xp.anchor_bottom = 1.0
	xp.offset_left = -260
	xp.offset_right = 260
	xp.offset_top = -30
	xp.offset_bottom = -4
	xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# В HUD из референса опыт — полоса внутри нижней панели.
	xp.visible = not reference_hud
	add_child(xp)

	var hint := _make_label(10)
	hint.text = Loc.t(HINT)
	_hint = hint
	Loc.language_changed.connect(func() -> void: _hint.text = Loc.t(HINT))
	Loc.device_changed.connect(func() -> void: _hint.text = Loc.t(HINT))
	hint.modulate.a = 0.75
	if reference_hud:
		# Слева сверху — портрет; строка управления — по центру сверху.
		# Слева сверху — портрет: строку управления не показываем (кнопки — в меню паузы и подсказках).
		hint.visible = false
	else:
		hint.position = Vector2(margin.x - 8, 6)
	_box(hint, Color(0, 0, 0, 0))
	add_child(hint)

	# Сверху по центру: враг, по которому стреляем (имя, здоровье, свойства).
	var target_bar := TargetBar.new()
	target_bar.anchor_left = 0.5
	target_bar.anchor_right = 0.5
	target_bar.offset_left = -300
	target_bar.offset_right = 300
	target_bar.offset_top = 30
	target_bar.offset_bottom = 200
	add_child(target_bar)

	# Подсказка взаимодействия («F / ○ — Торговать»).
	_prompt = _make_label(20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# По центру внизу, ширина — по тексту (чтобы плашка была под надписью, а не на весь экран).
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -112
	_prompt.offset_bottom = -82
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box(_prompt, Color(0.88, 0.47, 0.16))
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	add_child(_prompt)

	# --- Сообщения: лента плашек слева сверху, под строкой управления ---
	notifications = Notifications.new()
	notifications.position = Vector2(margin.x - 8, 14 if reference_hud else 34)
	notifications.size = Vector2(360, 400)
	add_child(notifications)
	_player.message.connect(show_message)
	_player.leveled_up.connect(func(new_level: int) -> void:
		notifications.push(Loc.t("НОВЫЙ УРОВЕНЬ %d") % new_level, Color(1.0, 0.82, 0.35),
				Loc.t("+%d к Life · +1 очко пассивок — P / R3") % int(_player.hp_per_level), 5.0))

	# --- Справа сверху: мини-карта ---
	var minimap := Minimap.new()
	minimap.player = _player
	_place_top_right(minimap, Vector2(margin.x - 8, 12), Vector2(190, 190))
	add_child(minimap)
	# Под мини-картой — задание этажа.
	var quest := Quest.new()
	_place_top_right(quest, Vector2(margin.x - 8, 210), Vector2(340, 220))
	add_child(quest)
	var hints := FirstTimeHints.new()
	hints.player = _player
	add_child(hints)

	# Курсор-прицел (мышь).
	var crosshair := Crosshair.new()
	crosshair.player = _player
	add_child(crosshair)

	# Инвентарь — на отдельном слое поверх всего.
	var inventory_layer := CanvasLayer.new()
	inventory_layer.layer = 10
	inventory_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inventory_layer)
	var inventory := SkillsScreen.new()
	inventory.with_inventory = true
	inventory.player = _player
	inventory_layer.add_child(inventory)
	inventory_screen = inventory
	var skill_panel := SkillsScreen.new()
	skill_panel.player = _player
	inventory_layer.add_child(skill_panel)
	skills_screen = skill_panel
	var character := CharacterScreen.new()
	character.player = _player
	inventory_layer.add_child(character)
	var tree_screen := PassiveTree.new()
	tree_screen.player = _player
	inventory_layer.add_child(tree_screen)
	# Меню паузы — последним: Esc сначала закрывает открытые окна, а меню открывает, только если ничего не открыто.
	inventory_layer.add_child(preload("res://scripts/dialog_box.gd").new())
	var tabs := preload("res://scripts/menu_tabs.gd").new()
	tabs.screens = [inventory, skill_panel, character, tree_screen]
	for screen in tabs.screens:
		screen.visibility_changed.connect(func() -> void:
			if screen.visible:
				for other in tabs.screens:
					if other != screen and other.visible:
						if other.has_method("_cancel_held"): other._cancel_held()
						if other.has_method("_toggle"): other._toggle()
						else: other.visible = false
				get_tree().paused = true)
	inventory_layer.add_child(tabs)
	var pause := PauseMenu.new()
	pause.player = _player
	inventory_layer.add_child(pause)


func show_message(text: String, duration := 2.5) -> void:
	notifications.push(text, Color(0, 0, 0, 0), "", duration + 1.5)


func _process(_delta: float) -> void:
	var target: Node3D = _player.nearest_interactable() if not _player.is_dead() else null
	_prompt.text = "F / ○ — %s" % Loc.t(target.prompt) if target != null else ""
	var loot = _player.get("_highlighted_loot")  # без типа: вещь могли только что поднять и удалить
	if target == null and is_instance_valid(loot) and not loot.is_queued_for_deletion():
		_prompt.text = Loc.t("X / ПКМ / X / □ — поднять: %s" % loot.call("_title"))
	# Подсказка действия теперь над самим объектом (hud_world_prompt.gd).
	_prompt.visible = false
	var weapon: WeaponData = _player.current_weapon()
	if weapon == null:
		return
	var ammo: int = _player.current_ammo()
	_weapon_label.text = Loc.t(weapon.display_name).to_upper()
	if _player.fixed_bow_loadout:
		_ammo_label.text = "НАТЯЖЕНИЕ" if _player.bow_draw_fraction() > 0 else "ЛУК"
		_ammo_label.modulate = normal_color
		_reload_bar.modulate.a = 1.0 if _player.bow_draw_fraction() > 0 else 0.0
		_reload_bar.value = _player.bow_draw_fraction()
		return
	if _player.is_reloading():
		_ammo_label.text = Loc.t("ПЕРЕЗАРЯДКА")
		_ammo_label.modulate = normal_color
	else:
		var magazine: int = _player.current_magazine_size()
		_ammo_label.text = "%d / %d" % [ammo, magazine]
		_ammo_label.modulate = low_ammo_color if ammo <= magazine * 0.25 else normal_color
	_reload_bar.modulate.a = 1.0 if _player.is_reloading() else 0.0
	_reload_bar.value = _player.reload_progress()


## Ставит элемент в нижний левый (right = false) или нижний правый угол с отступами от краёв.
func _place(control: Control, right: bool, from_side: float, from_bottom: float, box: Vector2) -> void:
	var side := 1.0 if right else 0.0
	control.anchor_left = side
	control.anchor_right = side
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	if right:
		control.offset_left = -from_side - box.x
		control.offset_right = -from_side
	else:
		control.offset_left = from_side
		control.offset_right = from_side + box.x
	control.offset_top = -from_bottom - box.y
	control.offset_bottom = -from_bottom


func _place_top_right(control: Control, offset: Vector2, box: Vector2) -> void:
	control.anchor_left = 1.0
	control.anchor_right = 1.0
	control.offset_left = -offset.x - box.x
	control.offset_right = -offset.x
	control.offset_top = offset.y
	control.offset_bottom = offset.y + box.y


## Тёмная плашка под текстом (читаемость на любом фоне), border — цвет тонкой рамки (прозрачный — без рамки).
func _box(label: Label, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.025, 0.8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	if border.a > 0.0:
		style.border_color = Color(border, 0.7)
		style.set_border_width_all(1)
	label.add_theme_stylebox_override("normal", style)


func _make_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
