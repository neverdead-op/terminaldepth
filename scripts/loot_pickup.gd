extends Area3D
## Добыча на полу: ксено-фрагмент, предмет экипировки, модуль оружия или золото.
## Подписи рисует интерфейс (hud_loot_labels.gd) — плашками, как фильтр лута в PoE 2.
## Вещи и фрагменты подбираются кнопкой «поднять» (X), золото — само, когда проходишь рядом.
## Ближайшая к игроку вещь подсвечивается (подпись крупнее и ярче).

const ItemDB := preload("res://scripts/item_db.gd")
const Beam := preload("res://scripts/loot_beam.gd")

## Что лежит: currency, gear, module или gold.
@export var kind := &"currency"
## Для фрагмента: его id (mutagen, unstable, hive_core, queen_heart, catalyst, blank_module).
@export var currency_id := &"mutagen"
## Количество (стопка фрагментов, золото).
@export var amount := 1
## Для модуля, положенного в сцене вручную.
@export var module: ModuleData
## Для предмета, положенного в сцене вручную: id базы и редкость (0 — белый, 1 — синий, 2 — жёлтый).
@export var gear_base := &""
@export var gear_rarity := 0
@export var gear_level := 1

## Сам предмет экипировки (при выпадении с врага задаётся в коде).
var gear: GearItem
## Не подбирать, пока игрок не отойдёт (для выброшенного из сумки).
var wait_for_exit := false

static var _meshes := {}
static var _all: Array[Node3D] = []

var _visual: Node3D
## Откуда вылетела (относительно места падения); ZERO — лежит сразу (положена в сцене).
var _fly_from := Vector3.ZERO
var _rest_y := 0.06
var _time := 0.0
var _retry := 0.0
var _highlighted := false


static func drop(parent: Node, at: Vector3, kind_value: StringName, payload, count := 1, from_player := false) -> void:
	var p := new()
	p.kind = kind_value
	p.amount = count
	p.wait_for_exit = from_player
	match kind_value:
		&"currency":
			p.currency_id = payload
		&"gear":
			p.gear = payload
		&"module":
			p.module = payload
		&"gold":
			p.amount = payload
	parent.call_deferred("add_child", p)
	# Вылетает из врага дугой и ложится рядом (разброс, чтобы добыча не легла стопкой).
	var a := randf() * TAU
	var offset := Vector3(cos(a), 0, sin(a)) * randf_range(0.6, 1.8)
	p.set_deferred("global_position", Vector3(at.x, 0.0, at.z) + offset)
	p._fly_from = Vector3(-offset.x, 1.0, -offset.z)


func _ready() -> void:
	if kind == &"gear" and gear == null:
		var base := ItemDB.base_by_id(gear_base) if gear_base != &"" else ItemDB.random_base()
		gear = GearItem.create(base, gear_level, gear_rarity)
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	shape.shape = sphere
	add_child(shape)

	var color := _color()
	_visual = _build_visual(color)
	_visual.rotation.y = randf() * TAU
	_visual.position.y = _rest_y
	add_child(_visual)
	# Ценное — светлый столб, как в PoE 2 (видно издалека).
	var beam_color := _beam_color()
	if beam_color.a > 0.0:
		var beam := Beam.new()
		beam.color = beam_color
		add_child(beam)
	if _fly_from != Vector3.ZERO:
		_fly()

	_all.append(self)
	add_to_group("loot")

	if kind == &"gear" and gear != null and gear.rarity == 3:
		Sfx.play(&"unique_drop", global_position)
	body_entered.connect(_try_pick)
	body_exited.connect(_on_body_exited)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		wait_for_exit = false


func _exit_tree() -> void:
	_all.erase(self)


## Полёт дугой из врага с двумя отскоками от пола.
func _fly() -> void:
	var start := _fly_from
	_visual.position = start
	var spin := Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9))
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start.lerp(Vector3(0, _rest_y, 0), t)
		p.y = lerpf(start.y, _rest_y, t) + sin(t * PI) * 1.3
		_visual.position = p
		_visual.rotation = spin * t, 0.0, 1.0, 0.45)
	tw.tween_callback(func() -> void: _visual.rotation = Vector3(0, _visual.rotation.y, 0))
	for h in [0.28, 0.1]:
		tw.tween_property(_visual, "position:y", _rest_y + h, 0.11 + h * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_visual, "position:y", _rest_y, 0.11 + h * 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _process(delta: float) -> void:
	_time += delta
	# Золото подбирается само (повторяем, пока игрок рядом).
	if kind == &"gold":
		_retry -= delta
		if _retry <= 0.0:
			_retry = 0.3
			for body in get_overlapping_bodies():
				_try_pick(body)


## Подсветка ближайшей к игроку вещи (её поднимет кнопка X).
func set_highlight(value: bool) -> void:
	if value == _highlighted:
		return
	_highlighted = value


## Поднять (вызывает игрок по кнопке X). true — поднято.
func pick(body: Node) -> bool:
	if is_queued_for_deletion() or not body.pick_up_loot(self):
		return false
	Sfx.play(&"key_pickup", global_position, -4.0)
	queue_free()
	return true


func _try_pick(body: Node) -> void:
	if kind != &"gold" or wait_for_exit or not body.has_method("pick_up_loot"):
		return
	pick(body)


func _title() -> String:
	match kind:
		&"currency":
			var n: String = ItemDB.CURRENCY[currency_id].name
			return n if amount <= 1 else "%s ×%d" % [n, amount]
		&"gear":
			return gear.display_name()
		&"module":
			return module.display_name
		&"gold":
			return "%d золота" % amount
	return "?"


## Цвет столба: жёлтые и уникальные вещи, модули, ценные фрагменты. Прозрачный — без столба.
func _beam_color() -> Color:
	match kind:
		&"gear":
			if gear.rarity == 3:
				return Color(1.0, 0.5, 0.15)
			if gear.rarity == 2:
				return Color(1.0, 0.9, 0.35)
		&"module":
			return Color(0.35, 0.95, 1.0)
		&"currency":
			if currency_id == &"blank_module":
				return Color(0.35, 0.95, 1.0)
			if ItemDB.CURRENCY_PRICES.get(currency_id, 10) >= 180:
				return ItemDB.CURRENCY[currency_id].color.lightened(0.3)
	return Color(0, 0, 0, 0)


## Маленький предмет на полу: оружие — его модель, броня — плоский свёрток, фрагмент — кристалл, золото — монеты.
func _build_visual(color: Color) -> Node3D:
	if kind == &"gear" and gear != null and gear.is_weapon():
		var w := gear.weapon_data()
		if w != null and w.model != null:
			var holder := Node3D.new()
			var m: Node3D = w.model.instantiate()
			m.scale = Vector3.ONE * w.model_scale * 0.9
			m.rotation_degrees = Vector3(0, w.model_yaw, 90)  # лежит на боку
			holder.add_child(m)
			_rest_y = 0.08
			return holder
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_for(kind)
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.2) if kind == &"gear" else color
	material.metallic = 0.4
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35 if kind == &"gear" else 1.0
	mi.material_override = material
	_rest_y = 0.05
	return mi


func _color() -> Color:
	match kind:
		&"currency":
			return ItemDB.CURRENCY[currency_id].color
		&"gear":
			return gear.color()
		&"module":
			return module.color
		&"gold":
			return Color(1.0, 0.82, 0.3)
	return Color.WHITE


static func _mesh_for(k: StringName) -> Mesh:
	if not _meshes.has(k):
		var mesh: Mesh
		match k:
			&"gear":
				var box := BoxMesh.new()
				box.size = Vector3(0.3, 0.08, 0.22)
				mesh = box
			&"module":
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.13
				cyl.bottom_radius = 0.13
				cyl.height = 0.05
				cyl.radial_segments = 6
				mesh = cyl
			&"gold":
				var coin := CylinderMesh.new()
				coin.top_radius = 0.1
				coin.bottom_radius = 0.1
				coin.height = 0.03
				mesh = coin
			_:
				# Кристалл-фрагмент: вытянутый восьмигранник.
				var crystal := SphereMesh.new()
				crystal.radius = 0.08
				crystal.height = 0.24
				crystal.radial_segments = 4
				crystal.rings = 2
				mesh = crystal
		_meshes[k] = mesh
	return _meshes[k]
