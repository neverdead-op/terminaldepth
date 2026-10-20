extends "res://scripts/interactable.gd"
## Торговец на базе: покупает вещи игрока за золото и продаёт товары на нескольких страницах.
## Обычный режим — готовые случайные вещи со свойствами и фрагменты (Angie).
## Режим gamble — витрина баз: каждая покупка даёт НОВЫЙ случайный предмет этой базы
## (редкость и свойства выпадают при покупке, как у Gwennen в PoE 2).
## Товары обновляются каждый раз, когда игрок возвращается на базу.
## Вид — женская базовая модель Quaternius в костюме, с анимацией разговора.

const ItemDB := preload("res://scripts/item_db.gd")
const Suit := preload("res://scripts/suit.gd")
const Animator := preload("res://scripts/player_animator.gd")
const MODEL := preload("res://assets/characters/base/Superhero_Female_FullBody.gltf")
const Dialog := preload("res://scripts/npc_dialog.gd")
const Outfit := preload("res://scripts/outfit.gd")
const Hair := preload("res://scripts/hair.gd")
const DialogBox := preload("res://scripts/dialog_box.gd")

## Имя торговки (подпись над ней и в окне торговли).
@export var vendor_name := "Angie"
## Сколько вещей экипировки на каждой странице.
@export var gear_count := 8
## Сколько страниц товаров.
@export var pages := 3
## Витрина баз: покупка выдаёт случайный предмет этой базы.
@export var gamble := false
## Цена покупки «вслепую» (оружие дороже).
@export var gamble_price := 110
@export var gamble_weapon_price := 170
## Уровень продаваемых вещей.
@export var item_level := 1
@export var idle_animation := &"Idle_FoldArms"
@export var suit_accent := Color(1.0, 0.55, 0.15)

## Товары по страницам: каждая — такая же сетка, как сумка игрока.
var stocks: Array[PlayerInventory] = []
## Первая страница (для совместимости).
var stock: PlayerInventory:
	get:
		return stocks[0] if not stocks.is_empty() else null


func _ready() -> void:
	super()
	interact_range = 3.3  # торговка за стойкой
	prompt = ("Купить вслепую у %s" if gamble else "Торговать с %s") % vendor_name
	var label := Label3D.new()
	label.text = vendor_name
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.85, 0.55)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.15
	label.transparency = 1.0  # рисует плашкой hud_world_labels.gd
	label.add_to_group("boxed_label")
	add_child(label)
	_label = label
	for i in pages:
		var page := PlayerInventory.new()
		add_child(page)
		stocks.append(page)
	_build_model()
	restock()
	tree_entered.connect(restock)  # игрок вернулся на базу — новые товары


var _label: Label3D
var _model: Node3D
var _new_shown := false


func _process(_delta: float) -> void:
	# Новый разговор отмечается значком реплики в плашке имени.
	var has_new := Dialog.has_new(vendor_name)
	if has_new != _new_shown and _model != null:
		_new_shown = has_new
		_label.set_meta("new_dialog", has_new)
		prompt = "Поговорить с %s" % vendor_name if has_new else (("Купить вслепую у %s" if gamble else "Торговать с %s") % vendor_name)


func interact(player: Node) -> void:
	preload("res://scripts/npc_conversation.gd").show_for(player, self, vendor_name)


func restock() -> void:
	if stocks.is_empty():
		return
	item_level = Game.floor_number
	for page in stocks:
		page.entries.clear()
	if gamble:
		_restock_bases()
		return
	for page in stocks:
		for i in gear_count:
			var rarity := 0
			var r := randf()
			# Готовые вещи — в основном простые: жёлтые редкость, лучшее добывают на этажах.
			if r < 0.04:
				rarity = 2
			elif r < 0.28:
				rarity = 1
			page.add_item(GearItem.create(ItemDB.random_base(&"", item_level), item_level, rarity))
	var first := stocks[0]
	first.add_currency(&"mutagen", 2)
	first.add_currency(&"unstable", 1)
	if item_level >= 2:
		first.add_currency(&"hive_core", 1)


## Витрина: по одной белой вещи каждой доступной базы; не влезло на страницу — на следующую.
func _restock_bases() -> void:
	var page := 0
	var bases := ItemDB.available_bases(item_level)
	bases.sort_custom(func(a, b): return ItemDB.SLOT_SIZES[a.slot].y > ItemDB.SLOT_SIZES[b.slot].y)
	for base in bases:
		var item := GearItem.create(base, item_level, 0)
		while page < stocks.size() and not stocks[page].add_item(item):
			page += 1
		if page >= stocks.size():
			break


## Цена покупки вслепую.
func gamble_cost(item: GearItem) -> int:
	return (gamble_weapon_price if item.is_weapon() else gamble_price) + (item_level - 1) * 10


## Новый случайный предмет той же базы: редкость, свойства (иногда — уникальный этой базы).
func roll_from(item: GearItem) -> GearItem:
	if randf() < 0.03:
		var uniques := ItemDB.UNIQUES.filter(func(u): return u.base == item.base.id)
		if not uniques.is_empty():
			return GearItem.create_unique(uniques.pick_random(), item_level)
	return GearItem.create(item.base, item_level, ItemDB.roll_rarity(0.25))


func _build_model() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	_model = model
	Suit.apply(model, suit_accent, Color(0.5, 0.42, 0.34), Color.WHITE, Color(0.13, 0.14, 0.16), true)
	Outfit.attach(model, preload("res://assets/characters/outfits/Female_Ranger.gltf"), Color(0.3, 0.38, 0.42) if gamble else Color(0.46, 0.34, 0.27))
	Hair.attach(model, preload("res://assets/characters/hair/Hair_Buns.gltf") if gamble else preload("res://assets/characters/hair/Hair_Long.gltf"), Color(0.17, 0.12, 0.09) if gamble else Color(0.35, 0.18, 0.1))
	var skeleton: Skeleton3D = model.get_node("Armature/Skeleton3D")
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(&"", Animator.fit_library(skeleton, [idle_animation], []))
	player.play(idle_animation)
