extends StaticBody3D
## Разрушаемая цель задания этажа. Стоит на слое врагов: в неё стреляют пули, целится автоприцел, бьют гранаты.
##   obelisk — обелиск культа: тёмный столп с красными письменами; пока цел, раз в секунду лечит врагов рядом
##             и окутывает их красным свечением — разрушь его до боя.
##   nest    — инкубатор: стеклянный бак с зелёной жижей; пока цел и герой рядом, выпускает ползунов.

const CRAWLER := preload("res://scenes/crawler.tscn")
const HealthBar := preload("res://scripts/health_bar_3d.gd")
const Highlight := preload("res://scripts/highlight.gd")
const RitualFx := preload("res://scripts/gothic_ritual_fx.gd")

@export_enum("obelisk", "nest") var kind := "obelisk"
@export var max_hp := 300.0
## Прочность растёт с уровнем этажа: ×(1 + hp_per_level · (уровень − 1)).
@export var hp_per_level := 0.5
@export_group("Обелиск")
## Нарисованный обелиск вместо фигур из кода (scripts/flat_sprite.gd). Пусто — прежний вид.
@export var sprite: Texture2D
@export var sprite_width := 1.9
@export var heal_radius := 10.0
## Доля здоровья врага, которую обелиск лечит в секунду.
@export var heal_ratio := 0.04
## Готическое свечение для нарисованного обелиска кампании.
@export var gothic_fx_enabled := true
@export_range(0.0, 3.0) var gothic_fx_intensity := 0.8
@export_group("Инкубатор")
@export var spawn_interval := 7.0
@export var spawn_range := 17.0
@export var max_alive := 4

var hp := 0.0
var destroyed := false
var _bar: Node3D
var _light: OmniLight3D
var _tick := 0.0
var _spawned: Array = []
var _glow_mat: StandardMaterial3D
var _time := 0.0
var _player: Node3D
var _sprite: Sprite3D
var _gothic_fx: RitualFx


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("quest_obelisk" if kind == "obelisk" else "quest_nest")
	collision_layer = 4
	collision_mask = 0
	var level := 1
	var node := get_parent()
	while node != null:
		if "zone_level" in node:
			level = node.zone_level
			break
		node = node.get_parent()
	max_hp *= 1.0 + hp_per_level * (level - 1)
	hp = max_hp
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 3.0, 1.4) if kind == "obelisk" else Vector3(1.8, 2.4, 1.8)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	add_child(shape)
	if kind == "obelisk" and sprite != null:
		_build_obelisk_sprite()
	elif kind == "obelisk":
		_build_obelisk()
	else:
		_build_nest()
	_bar = HealthBar.new()
	_bar.width = 1.4
	_bar.position = Vector3(0, 3.6 if kind == "obelisk" else 2.9, 0)
	_bar.hide_when_full = true
	add_child(_bar)
	_tick = randf() * 1.0
	Highlight.apply(self, Color(1.0, 0.3, 0.25) if kind == "obelisk" else Color(0.5, 1.0, 0.3))
	var sprite_node := get("_sprite") as Sprite3D
	if kind == "obelisk" and sprite_node != null and gothic_fx_enabled:
		# Добавляем после Highlight: контур цели не должен обводить плоскости эффектов.
		_gothic_fx = RitualFx.new()
		_gothic_fx.name = "GothicFx"
		_gothic_fx.radius = sprite_node.pixel_size * sprite_node.texture.get_width() * 1.2
		_gothic_fx.intensity = gothic_fx_intensity
		add_child(_gothic_fx)
		_gothic_fx.bind_crystal(sprite_node)
		_light.light_energy = 0.0


func _mat(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.6
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _add(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _build_obelisk() -> void:
	var stone := _mat(Color(0.09, 0.08, 0.09))
	_glow_mat = _mat(Color(1.0, 0.18, 0.12), 3.0)
	var base := BoxMesh.new()
	base.size = Vector3(1.6, 0.35, 1.6)
	_add(base, Vector3(0, 0.17, 0), stone)
	var step := BoxMesh.new()
	step.size = Vector3(1.2, 0.3, 1.2)
	_add(step, Vector3(0, 0.5, 0), stone)
	var pillar := CylinderMesh.new()
	pillar.radial_segments = 4
	pillar.top_radius = 0.22
	pillar.bottom_radius = 0.5
	pillar.height = 2.6
	_add(pillar, Vector3(0, 1.95, 0), stone, Vector3(0, PI / 4, 0))
	# Письмена — светящиеся полосы на гранях.
	var rune := BoxMesh.new()
	rune.size = Vector3(0.06, 1.6, 0.04)
	for i in 4:
		var a := i * PI / 2
		var mi := _add(rune, Vector3(sin(a) * 0.37, 1.7, cos(a) * 0.37), _glow_mat, Vector3(-0.1 * cos(a), a, 0.1 * sin(a)))
		mi.rotation = Vector3(0, a, 0)
	var crystal := SphereMesh.new()
	crystal.radius = 0.28
	crystal.height = 0.75
	crystal.radial_segments = 4
	crystal.rings = 2
	_add(crystal, Vector3(0, 3.55, 0), _glow_mat)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.2, 0.12)
	_light.omni_range = 7.0
	_light.light_energy = 2.0
	_light.position = Vector3(0, 3.0, 0)
	add_child(_light)


func _build_obelisk_sprite() -> void:
	_glow_mat = _mat(Color(1.0, 0.18, 0.12), 3.0)  # мерцание кристалла считается по этому материалу
	_sprite = preload("res://scripts/flat_sprite.gd").make(sprite, sprite_width)
	_sprite.modulate = Color(0.8, 0.78, 0.8)
	add_child(_sprite)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.2, 0.12)
	_light.omni_range = 7.0
	_light.light_energy = 2.0
	_light.position = Vector3(0, 2.2, 0.6)
	add_child(_light)


func _build_nest() -> void:
	var metal := _mat(Color(0.16, 0.17, 0.18))
	metal.metallic = 0.7
	_glow_mat = _mat(Color(0.4, 1.0, 0.25), 1.6, 0.55)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.95
	ring.bottom_radius = 1.0
	ring.height = 0.35
	_add(ring, Vector3(0, 0.17, 0), metal)
	_add(ring, Vector3(0, 2.25, 0), metal)
	var tank := CylinderMesh.new()
	tank.top_radius = 0.8
	tank.bottom_radius = 0.8
	tank.height = 1.75
	_add(tank, Vector3(0, 1.2, 0), _glow_mat)
	# Тёмный силуэт внутри — то, что там зреет.
	var body := CapsuleMesh.new()
	body.radius = 0.32
	body.height = 1.2
	_add(body, Vector3(0, 1.15, 0), _mat(Color(0.05, 0.08, 0.04)), Vector3(0.3, 0, 0.2))
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.08
	pipe.bottom_radius = 0.08
	pipe.height = 1.6
	for i in 3:
		var a := i * TAU / 3.0
		_add(pipe, Vector3(sin(a) * 0.95, 1.2, cos(a) * 0.95), metal)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 1.0, 0.3)
	_light.omni_range = 6.0
	_light.light_energy = 1.6
	_light.position = Vector3(0, 1.4, 0)
	add_child(_light)


func take_damage(amount: float, _element := &"physical", _source = null) -> float:
	if destroyed:
		return 0.0
	var dealt := minf(amount, hp)
	hp -= dealt
	_bar.set_ratio(hp / max_hp)
	Fx.number(global_position + Vector3.UP * 3.0, dealt)
	_glow_mat.emission_energy_multiplier = 6.0
	if _sprite != null:
		_sprite.modulate = Color(1.4, 0.7, 0.7)
		create_tween().tween_property(_sprite, "modulate", Color(0.8, 0.78, 0.8), 0.2)
	if hp <= 0.0:
		_destroy()
	return dealt


func _destroy() -> void:
	destroyed = true
	Highlight.clear(self)
	remove_from_group("enemies")
	collision_layer = 0
	_bar.visible = false
	Fx.flipbook(&"explosion", global_position + Vector3.UP * 1.5, 3.5, 1.2)
	Fx.shake(0.4)
	Sfx.play(&"explosion_big", global_position)
	_light.light_energy = 0.0
	if _gothic_fx != null:
		_gothic_fx.active = false
		_gothic_fx.pulse()
	# Обломки: модель проседает и темнеет.
	if _sprite != null:
		# Картинка оседает, кренится и темнеет.
		var fall := _sprite.create_tween()
		fall.tween_property(_sprite, "position:y", -0.9, 0.5).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(_sprite, "rotation:z", randf_range(-0.35, 0.35), 0.5)
		fall.parallel().tween_property(_sprite, "modulate", Color(0.3, 0.28, 0.28), 0.5)
	for c in get_children():
		if c is MeshInstance3D:
			var tw := c.create_tween()
			tw.tween_property(c, "position:y", c.position.y * 0.35, 0.5).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(c, "rotation:z", randf_range(-0.6, 0.6), 0.5)
	_glow_mat.emission_energy_multiplier = 0.0
	_glow_mat.albedo_color = Color(0.1, 0.1, 0.1, _glow_mat.albedo_color.a)
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.show_message("Обелиск разрушен" if kind == "obelisk" else "Инкубатор уничтожен", 2.0)


func _physics_process(delta: float) -> void:
	if destroyed:
		return
	_time += delta
	_glow_mat.emission_energy_multiplier = lerpf(_glow_mat.emission_energy_multiplier, 2.5 + sin(_time * 3.0) * 0.8,
			1.0 - exp(-6.0 * delta))
	_tick -= delta
	if _tick > 0.0:
		return
	if kind == "obelisk":
		_tick = 1.0
		_heal_enemies()
	else:
		_tick = spawn_interval
		_spawn()


func _heal_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not e is Node3D or not ("hp" in e) or not ("max_hp" in e) or e.has_method("_heal_enemies"):
			continue
		if e.global_position.distance_to(global_position) > heal_radius or e.hp >= e.max_hp:
			continue
		e.hp = minf(e.hp + e.max_hp * heal_ratio, e.max_hp)
		if e.get("health_bar") != null:
			e.health_bar.set_ratio(e.hp / e.max_hp)
		Fx.impact(e.global_position + Vector3.UP * 1.2, Vector3.UP, Color(1.0, 0.25, 0.2))


func _spawn() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null or _player.global_position.distance_to(global_position) > spawn_range:
		return
	_spawned = _spawned.filter(func(s) -> bool: return is_instance_valid(s) and s.is_in_group("enemies"))
	if _spawned.size() >= max_alive:
		return
	var c: Node3D = CRAWLER.instantiate()
	c.start_awake = true
	c.xp_reward = 1
	c.gear_drop_chance = 0.0
	c.currency_drop_chance = 0.0
	c.module_drop_chance = 0.0
	get_parent().add_child(c)
	var a := randf() * TAU
	c.global_position = global_position + Vector3(cos(a), 0.1, sin(a)) * 1.8
	_spawned.append(c)
	Sfx.play(&"acid_splash", global_position)
	Fx.hit(global_position + Vector3.UP * 1.2, Vector3.UP, Color(0.4, 1.0, 0.25), 14)
