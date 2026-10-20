extends "res://scripts/interactable.gd"
## Сундук с добычей (F / ○ — открыть). Как враги, бывает обычным, синим и жёлтым:
## чем реже сундук, тем больше вещей и тем чаще они синие и жёлтые.

const LOOT := preload("res://scripts/loot_pickup.gd")
const Highlight := preload("res://scripts/highlight.gd")
const Mods := preload("res://scripts/monster_mods.gd")

@export_enum("Обычный", "Синий", "Жёлтый") var rarity := 0
@export var model: PackedScene = preload("res://assets/essentials/Prop_Chest.gltf")
@export var model_scale := 0.9
## Модификаторы (камни поддержки), которые выпадают точно — вместе с остальной добычей.
@export var guaranteed_modules: Array[ModuleData] = []
## Нарисованный сундук вместо модели (scripts/flat_sprite.gd). Пусто — модель.
@export var sprite: Texture2D
## Ширина нарисованного сундука в метрах.
@export var sprite_width := 1.8
@export var sprite_flip := false
## Учебный сундук: ровно один заданный предмет, без случайных наград.
@export var guaranteed_base := &""
## Сколько вещей выпадает (по редкости: обычный, синий, жёлтый).
@export var item_counts := Vector3i(2, 4, 7)
## Насколько чаще вещи синие/жёлтые (по редкости сундука).
@export var rarity_bonuses := Vector3(0.0, 0.35, 0.8)

## Подпись над сундуком видна ближе этого расстояния (м).
@export var label_range := 14.0

var _opened := false
var _chest_model: Node3D
var _label: Label3D
var _check := 0.0
var _anim: AnimationPlayer
var _light: OmniLight3D


func _ready() -> void:
	super()
	add_to_group("chests")  # для задания «Откройте сундуки»
	prompt = ["Открыть сундук", "Открыть синий сундук", "Открыть жёлтый сундук"][rarity]
	interact_range = 2.4
	var inst: Node3D = model.instantiate() if sprite == null else preload("res://scripts/flat_sprite.gd").make(sprite, sprite_width, sprite_flip)
	if sprite == null:
		inst.scale = Vector3.ONE * model_scale
	else:
		# Неоткрытый — чуть светится цветом редкости (контур на картинку не ложится).
		(inst as Sprite3D).modulate = Color(0.95, 0.92, 0.9).lerp(Mods.RARITY_COLORS[rarity], 0.2)
	add_child(inst)
	# Неоткрытый сундук подсвечен цветом редкости — видно издалека, что его можно открыть.
	Highlight.apply(inst, Color(Mods.RARITY_COLORS[rarity], 0.9))
	_chest_model = inst
	_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null and _anim.has_animation(&"Idle_Closed"):
		_anim.play(&"Idle_Closed")
	# Твёрдый: игрок и враги обходят.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.9, 0.9) * model_scale
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	add_child(body)
	_label = Label3D.new()
	_label.text = Loc.t("Сундук")
	_label.modulate = Mods.RARITY_COLORS[rarity]
	_label.outline_modulate = Color(0, 0, 0, 0.95)
	_label.outline_size = 8
	_label.font_size = 34
	_label.pixel_size = 0.0075
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 1.5
	_label.visible = false
	_label.transparency = 1.0  # рисует плашкой hud_world_labels.gd
	_label.add_to_group("boxed_label")
	add_child(_label)
	if rarity > 0:
		_light = OmniLight3D.new()
		_light.light_color = Mods.RARITY_COLORS[rarity]
		_light.light_energy = 1.6
		_light.omni_range = 3.5
		_light.position.y = 1.2
		add_child(_light)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _opened:
		return
	_check = 0.25
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_label.visible = player != null and player.global_position.distance_squared_to(global_position) < label_range * label_range


func interact(_player: Node) -> void:
	if _opened:
		return
	_opened = true
	Highlight.clear(_chest_model)
	_label.visible = false
	remove_from_group("interactables")
	if _anim != null and _anim.has_animation(&"Open"):
		_anim.play(&"Open")
	if _chest_model is Sprite3D:
		# Картинка: подпрыгивает и темнеет — сундук пуст.
		var pop := create_tween()
		pop.tween_property(_chest_model, "position:y", 0.18, 0.08)
		pop.tween_property(_chest_model, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)
		pop.parallel().tween_property(_chest_model, "modulate", Color(0.38, 0.36, 0.36), 0.6)
		Fx.flipbook(&"spark", global_position + Vector3.UP * 0.7, 1.4, 0.3, Color(1.0, 0.8, 0.4))
	Sfx.play(&"chest_open", global_position)
	if _light != null:
		create_tween().tween_property(_light, "light_energy", 0.0, 1.5)
	var level := _zone_level()
	var parent := get_parent()
	var at := global_position + global_basis.z * 0.8
	for module in guaranteed_modules:
		LOOT.drop(parent, at + Vector3(randf_range(-0.6, 0.6), 0, randf_range(0.2, 0.7)), &"module", module.duplicate())
	if guaranteed_base != &"":
		LOOT.drop(parent, at, &"gear", GearItem.create(LOOT.ItemDB.base_by_id(guaranteed_base), level, 0))
		return
	var count: int = maxi(1, roundi(item_counts[rarity] * Game.loot_mult()))
	var bonus: float = rarity_bonuses[rarity]
	LOOT.drop(parent, at, &"gold", randi_range(2, 6) * (rarity + 1) * level)
	# Первый этаж учит: если у героя только пистолет — в сундуке гарантированно второе оружие.
	var hero := get_tree().get_first_node_in_group("player")
	if level == 1 and hero != null and hero.weapon_item(1) == null:
		LOOT.drop(parent, at, &"gear", GearItem.create(LOOT.ItemDB.random_base(&"weapon", 1), 1, 1))
	for i in count:
		var roll := randf()
		if roll < 0.55:
			LOOT.drop(parent, at, &"gear", GearItem.random_drop(level, bonus))
		elif rarity == 2 and roll > 0.9:
			LOOT.drop(parent, at, &"currency", &"blank_module")  # модуль — только в жёлтом сундуке, редко
		else:
			LOOT.drop(parent, at, &"currency", LOOT.ItemDB.random_currency(level))


func _zone_level() -> int:
	var node := get_parent()
	while node != null:
		if "zone_level" in node:
			return node.zone_level
		node = node.get_parent()
	return 1
