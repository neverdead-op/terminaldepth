extends Node3D
## Событие «Запечатать разлом» (как Ритуал в PoE 2). Над полом висит светящийся разлом.
## F / ○ рядом — начинается запечатывание: на полу вспыхивает круг, из разлома идут волны врагов
## (короткие, но плотные). Каждая следующая начинается, когда перебита предыдущая (или через wave_timeout).
## Все волны отбиты — разлом закрывается, задание этажа выполнено (zone_quests.gd), рядом падает награда.

const LOOT := preload("res://scripts/loot_pickup.gd")
const PLATFORM := preload("res://assets/megakit/Platform_Round1.gltf")
const COLUMN := preload("res://assets/megakit/Column_Astra.gltf")
const CREATURE := preload("res://assets/megakit/Alien_Scolitex.gltf")
const Highlight := preload("res://scripts/highlight.gd")
const RitualFx := preload("res://scripts/gothic_ritual_fx.gd")
const SCENES := {
	&"crawler": preload("res://scenes/crawler.tscn"), &"leaper": preload("res://scenes/leaper.tscn"),
	&"spitter": preload("res://scenes/spitter.tscn"), &"brute": preload("res://scenes/brute.tscn"),
}

## Волны: список врагов в каждой.
@export var waves: Array[PackedStringArray] = [
	PackedStringArray(["crawler", "crawler", "crawler", "crawler", "crawler", "crawler", "crawler", "crawler", "leaper",
		"leaper"]),
	PackedStringArray(["brute", "crawler", "crawler", "crawler", "crawler", "crawler", "leaper", "leaper", "spitter",
		"spitter", "spitter"]),
	PackedStringArray(["brute", "brute", "crawler", "crawler", "crawler", "crawler", "crawler", "crawler", "leaper",
		"leaper", "leaper", "spitter", "spitter"]),
]
## Доля синих врагов в волне; последняя волна — с жёлтым вожаком.
@export var magic_chance := 0.25
## Пауза между волнами (сек) — короткая передышка.
@export var wave_pause := 1.5
@export var radius := 6.5
@export var wave_timeout := 30.0
@export var rift_color := Color(0.85, 0.25, 1.0)
## Новый визуальный слой только для готического алтаря; остальные разломы прежние.
@export var gothic_fx_enabled := true
@export_range(0.0, 3.0) var gothic_fx_intensity := 0.5
## Каменный алтарь для деревни; остальные разломы сохраняют прежние модели.
@export var gothic_altar := false
## Нарисованный алтарь, лежит на земле (scripts/flat_sprite.gd). Пусто — каменная плита и шпили.
@export var altar_sprite: Texture2D
@export var altar_sprite_width := 5.2
@export var final_rare_leader := true
## Ноль сохраняет параметры сцен врагов.
@export var enemy_life := 0.0
@export var enemy_damage := 0.0

## Для подсказки «F / ○ — …» (как у interactable.gd).
var prompt := "Запечатать разлом"
var interact_range := 3.0
var running := false
var destroyed := false  # = завершено (для подсчёта задания)

var _wave := -1
var _alive: Array = []
var _wave_left := 0.0
var _pause_left := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _rift: Node3D
var _rift_mat: StandardMaterial3D
var _light: OmniLight3D
var _time := 0.0
var _player: Node3D
var _level := 1
var _base: Node3D
var _gothic_fx: RitualFx


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("quest_seal")
	var node := get_parent()
	while node != null:
		if "zone_level" in node:
			_level = node.zone_level
			break
		node = node.get_parent()
	# Разлом: круглая платформа MegaKit, четыре колонны, в центре парит тварь из разлома (Alien_Scolitex)
	# в фиолетовом свечении. Модели — Quaternius MegaKit (CC0).
	var base_mi: Node3D = Node3D.new() if gothic_altar else PLATFORM.instantiate()
	if gothic_altar and altar_sprite != null:
		base_mi.add_child(preload("res://scripts/flat_sprite.gd").make(altar_sprite, altar_sprite_width / 1.3, false, true))
		var candles := OmniLight3D.new()
		candles.light_color = Color(1.0, 0.68, 0.35)
		candles.light_energy = 1.6
		candles.omni_range = 6.0
		candles.position.y = 1.2
		base_mi.add_child(candles)
	elif gothic_altar:
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.18, 0.16, 0.19)
		stone.roughness = 0.95
		var slab := CylinderMesh.new()
		slab.top_radius = 1.7
		slab.bottom_radius = 1.9
		slab.height = 0.25
		slab.material = stone
		var mesh := MeshInstance3D.new()
		mesh.mesh = slab
		mesh.position.y = 0.125
		base_mi.add_child(mesh)
	base_mi.scale = Vector3.ONE * 1.3
	add_child(base_mi)
	for i in (0 if altar_sprite != null else 4):
		var a := i * PI * 0.5 + PI * 0.25
		var col: Node3D = Node3D.new() if gothic_altar else COLUMN.instantiate()
		if gothic_altar:
			var pillar := MeshInstance3D.new()
			var shape := CylinderMesh.new()
			shape.radial_segments = 4
			shape.top_radius = 0.05
			shape.bottom_radius = 0.45
			shape.height = 2.6
			shape.material = base_mi.get_child(0).mesh.material
			pillar.mesh = shape
			pillar.position.y = 1.3
			col.add_child(pillar)
		col.position = Vector3(cos(a), 0, sin(a)) * 2.4
		col.scale = Vector3(0.9, 0.55, 0.9)
		add_child(col)
	_rift = Node3D.new()
	_rift.position.y = 1.0
	add_child(_rift)
	var creature: Node3D = Node3D.new() if gothic_altar else CREATURE.instantiate()
	creature.scale = Vector3.ONE * 0.75
	_rift.add_child(creature)
	var anim := creature.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation(&"Alien_Idle"):
		anim.get_animation(&"Alien_Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play(&"Alien_Idle")
	_rift_mat = StandardMaterial3D.new()
	_rift_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rift_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rift_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_rift_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_rift_mat.albedo_texture = preload("res://assets/vfx/circle_05.png")
	_rift_mat.albedo_color = Color(rift_color, 0.5)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	q.material = _rift_mat
	halo.mesh = q
	halo.position.y = 0.6
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rift.add_child(halo)
	_light = OmniLight3D.new()
	_light.light_color = rift_color
	_light.omni_range = 7.0
	_light.light_energy = 1.8
	_light.position.y = 1.6
	add_child(_light)
	# Круг на полу (виден во время события).
	var disc := TorusMesh.new()
	disc.inner_radius = radius - 0.12
	disc.outer_radius = radius
	disc.rings = 48
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(rift_color, 0.0)
	disc.material = _ring_mat
	_ring = MeshInstance3D.new()
	_ring.mesh = disc
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_base = base_mi
	if get("gothic_altar") == true and gothic_fx_enabled:
		_gothic_fx = RitualFx.new()
		_gothic_fx.name = "GothicFx"
		# Внешняя линия шейдера находится на 0.73 радиуса плоскости.
		_gothic_fx.radius = radius / 0.73
		_gothic_fx.effect_color = rift_color
		_gothic_fx.intensity = gothic_fx_intensity
		_gothic_fx.active = false
		add_child(_gothic_fx)
		_ring.visible = false
		_rift.visible = false
		_light.light_energy = 0.0


func interact(player: Node) -> void:
	if running or destroyed:
		return
	running = true
	if _gothic_fx != null:
		_gothic_fx.active = true
	_player = player
	remove_from_group("interactables")
	Sfx.play(&"boss_roar", global_position, -6.0)
	Fx.shake(0.3)
	player.show_message("Разлом открывается — выстойте %d волны!" % waves.size(), 3.0)
	_ring.create_tween().tween_property(_ring_mat, "albedo_color:a", 0.75, 0.6)
	_next_wave()


func _next_wave() -> void:
	_wave += 1
	if _wave >= waves.size():
		_complete()
		return
	_wave_left = wave_timeout
	if _gothic_fx != null:
		_gothic_fx.pulse()
	_alive.clear()
	var list: PackedStringArray = waves[_wave]
	for i in list.size():
		var scene: PackedScene = SCENES.get(StringName(list[i]), SCENES[&"crawler"])
		var e: Node3D = scene.instantiate()
		e.start_awake = true
		if enemy_life > 0:
			e.max_hp = enemy_life * (2.0 if list[i] == "brute" else 1.0)
		if enemy_damage > 0:
			e.damage = enemy_damage
			if list[i] == "spitter": e.projectile_damage = enemy_damage * 1.4
		e.gear_drop_chance = e.gear_drop_chance * 0.3
		if final_rare_leader and _wave == waves.size() - 1 and i == 0:
			e.rarity = 2
		elif randf() < magic_chance:
			e.rarity = 1
		get_parent().add_child(e)
		# По кругу, с небольшим разбросом — враги лезут со всех сторон.
		var a := TAU * i / list.size() + randf_range(-0.2, 0.2)
		var at := global_position + Vector3(cos(a), 0, sin(a)) * radius * randf_range(0.8, 1.0)
		# Не в стену: ближайшая точка карты проходимости.
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			at = NavigationServer3D.map_get_closest_point(map, at)
		e.global_position = at + Vector3.UP * 0.1
		_alive.append(e)
		Fx.flipbook(&"smoke", e.global_position + Vector3.UP * 0.8, 1.6, 0.8, Color(rift_color, 0.7), false, true)
	Sfx.play(&"zap", global_position, 2.0)
	if _player != null and _wave > 0:
		_player.show_message("Волна %d / %d" % [_wave + 1, waves.size()], 2.0)


func _complete() -> void:
	running = false
	destroyed = true
	if _gothic_fx != null:
		_gothic_fx.active = false
		_gothic_fx.pulse()
	_ring.create_tween().tween_property(_ring_mat, "albedo_color:a", 0.0, 0.8)
	var tw := _rift.create_tween()
	tw.tween_property(_rift, "scale", Vector3(0.01, 0.01, 0.01), 0.6).set_ease(Tween.EASE_IN)
	_light.create_tween().tween_property(_light, "light_energy", 0.0, 0.8)
	Fx.flipbook(&"explosion", global_position + Vector3.UP * 1.6, 3.0, 1.0, rift_color)
	Sfx.play(&"explosion_big", global_position)
	var parent := get_parent()
	LOOT.drop(parent, global_position, &"gear", GearItem.random_drop(_level, 1.0))
	LOOT.drop(parent, global_position, &"gear", GearItem.random_drop(_level, 0.5))
	LOOT.drop(parent, global_position, &"currency", LOOT.ItemDB.random_currency(_level + 1))
	if _player != null and is_instance_valid(_player):
		_player.show_message("Разлом запечатан!", 3.0)


func _process(delta: float) -> void:
	_time += delta
	if not destroyed:
		_rift.rotation.y = _time * 0.4
		_rift.position.y = 1.0 + sin(_time * 1.5) * 0.12
		_rift_mat.albedo_color.a = 0.35 + sin(_time * 4.0) * 0.15
	if not running:
		return
	_ring_mat.albedo_color = Color(rift_color, 0.55 + sin(_time * 5.0) * 0.2)
	_wave_left -= delta
	_alive = _alive.filter(func(e) -> bool: return is_instance_valid(e) and e.is_in_group("enemies"))
	if _alive.is_empty() or (wave_timeout > 0.0 and _wave_left <= 0.0):
		_pause_left -= delta
		if _pause_left <= 0.0:
			_pause_left = wave_pause
			_next_wave()
