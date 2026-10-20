extends Node
## Навыки героя (узел Skills внутри игрока):
##   Граната (G / RB) — бросок дугой туда, куда целишься, взрыв по площади. Заряды восстанавливаются со временем.
##   Ударная волна (V / LB) — электрический импульс вокруг героя: урон и отброс, спасает в окружении.
##   Мина (B / LT) — ставится под ноги, взрывается, когда рядом враг. Цифры и модули — минный ранец
##   (player.MINE_SLOT): урон, радиус, заряды (магазин), восстановление (перезарядка), стихия — первое гнездо.
## Урон растёт с уровнем персонажа. Все цифры — в Inspector.

const EXPLOSION := preload("res://scenes/explosion.tscn")

@export_group("Граната")
@export var grenade_charges := 3
@export var grenade_recharge := 9.0
@export var grenade_damage := 150.0
@export var grenade_radius := 5.5
@export var grenade_range := 13.0
@export var grenade_flight := 0.7

@export_group("Ударная волна")
@export var nova_cooldown := 12.0
@export var nova_damage := 80.0
@export var nova_radius := 5.0
@export var nova_knockback := 14.0

@export_group("Мины")
## Сколько мин может стоять одновременно (старая взрывается, если поставить лишнюю).
@export var mine_max_active := 5
## Через сколько секунд после установки мина «взводится».
@export var mine_arm_time := 0.18
## Радиус срабатывания (враг ближе — взрыв).
@export var mine_trigger_radius := 2.2
## Дальность броска мины (м) и время полёта (сек).
@export var mine_throw_range := 6.0
@export var mine_flight := 0.28
## Расстояние между минами при броске нескольких (модуль «Доп. снаряды»).
@export var mine_spread := 1.8
## Кислотная лужа: сколько секунд, раз в сколько секунд урон, доля урона мины за тик.
@export var puddle_time := 4.0
@export var puddle_tick := 0.5
@export var puddle_ratio := 0.12
## Электрический взрыв: сколько врагов бьёт молниями и какой долей урона.
@export var arc_targets := 4
@export var arc_ratio := 0.5

## Сколько гранат сейчас и сколько осталось до следующей (сек).
var grenades := 3
var grenade_timer := 0.0
var nova_timer := 0.0
var mines := 3
var mine_timer := 0.0
var _mine_throw_left := 0.0
var _active_mines: Array[Node3D] = []
var pulse_cooldown := 0.0
var _pulse_charge_left := 0.0
var _pulse_item: GearItem

func is_charging_pulse() -> bool:
	return _pulse_charge_left > 0.0

func has_pulse() -> bool:
	var item: GearItem = player.weapon_item(player.current_weapon_index()) if player != null else null
	return item != null and item.secondary_skill() == &"plasma_pulse"

func start_pulse() -> bool:
	if not has_pulse() or is_charging_pulse() or pulse_cooldown > 0 or player.is_dead() or player.is_dodging() or player.is_reloading() or player._recovery_left > 0: return false
	var w: WeaponData = player.current_weapon()
	if player.current_ammo() < w.secondary_ammo_cost:
		Sfx.play(&"empty", player.global_position)
		return false
	_pulse_item = player.weapon_item(player.current_weapon_index())
	_pulse_charge_left = w.secondary_charge
	Sfx.play(&"zap", player.global_position, -10.0)
	return true

var player: Node3D
const GRENADE_MODEL := preload("res://assets/essentials/Prop_Grenade.gltf")
## Пятно кислотной лужи (Kenney Particle Pack, CC0), красится в зелёный.
const PUDDLE_TEXTURE := preload("res://assets/vfx/scorch_02.png")


func _ready() -> void:
	player = get_parent()
	grenades = grenade_charges


## Бонусы гранат из дерева пассивок и вещей (player._gear).
func _bonus(key: StringName) -> float:
	var gear = player.get("_gear")
	return float(gear.get(key, 0)) if gear is Dictionary else 0.0


func max_grenades() -> int:
	return grenade_charges + int(_bonus(&"grenade_charges"))


func recharge_time() -> float:
	var reload_bonus := 0.0
	for m in _grenade_modules():
		if m != null:
			reload_bonus += m.reload_speed_bonus
	return grenade_recharge / maxf(0.1, 1.0 + _bonus(&"grenade_recharge") / 100.0 + reload_bonus)


func _grenade_modules() -> Array:
	var item: GearItem = player.weapon_item(player.current_weapon_index())
	return item.secondary_modules if item != null and item.secondary_skill() == &"grenade" else []


func _process(delta: float) -> void:
	pulse_cooldown = maxf(0, pulse_cooldown - delta)
	if _pulse_charge_left > 0:
		if player.is_dead() or player.is_dodging() or player.weapon_item(player.current_weapon_index()) != _pulse_item:
			_pulse_charge_left = 0
		else:
			player.muzzle_flash.light_color = Color(1.0, 0.7, 0.35) if _pulse_item.weapon_data().projectile != &"plasma" else Color(0.15, 0.8, 1.0)
			player.muzzle_flash.light_energy = 1.5 * (1.0 - _pulse_charge_left / _pulse_item.weapon_data().secondary_charge)
			_pulse_charge_left = maxf(0, _pulse_charge_left - delta)
			if _pulse_charge_left <= 0:
				var stats: Dictionary = player.pulse_stats(player.current_weapon_index())
				if player.fire_plasma_pulse(): pulse_cooldown = stats.cooldown
	_mine_throw_left = maxf(0, _mine_throw_left - delta)
	if grenades < max_grenades():
		grenade_timer -= delta
		if grenade_timer <= 0.0:
			grenades += 1
			grenade_timer = recharge_time() if grenades < max_grenades() else 0.0
	nova_timer = maxf(nova_timer - delta, 0.0)
	var st := _mine_stats()
	if not st.is_empty() and mines < st.magazine:
		mine_timer -= delta
		if mine_timer <= 0.0:
			mines += 1
			mine_timer = st.reload_time if mines < st.magazine else 0.0
	_update_mines(delta)


func _unhandled_input(event: InputEvent) -> void:
	if player.is_dead() or get_tree().paused or Game.in_hub():
		return
	if event.is_action_pressed("skill_grenade"):
		if has_pulse(): start_pulse()
		else: throw_grenade()
	elif event.is_action_pressed("skill_nova"):
		nova()
	# Мины сохранены в коде для поздних актов; получение и ввод в первом акте отключены.


func _level_mult() -> float:
	return 1.0 + 0.25 * (player.level - 1)


func has_grenade() -> bool:
	var item: GearItem = player.weapon_item(player.current_weapon_index())
	return item != null and item.secondary_skill() == &"grenade"

func grenade_stats() -> Dictionary:
	var damage := grenade_damage * _level_mult() * (1.0 + _bonus(&"grenade_damage") / 100.0)
	var radius := grenade_radius * (1.0 + _bonus(&"grenade_radius") / 100.0)
	var elements := {}
	for module in _grenade_modules():
		if module == null: continue
		damage *= (1.0 + module.damage_bonus) * module.damage_multiplier
		radius *= module.area_mult
		if module.element != &"": elements[module.element] = elements.get(module.element, 0.0) + module.element_ratio
	return {"damage": damage, "radius": radius, "elements": elements, "cooldown": recharge_time()}


func throw_grenade() -> void:
	if not has_grenade() or player.is_dodging() or player._recovery_left > 0:
		return
	if grenades <= 0:
		Sfx.play(&"empty", player.global_position)
		return
	if grenades >= max_grenades():
		grenade_timer = recharge_time()
	grenades -= 1
	var from: Vector3 = player.global_position + Vector3.UP * 1.4
	var target: Vector3 = _aim_point()
	var g: Node3D = GRENADE_MODEL.instantiate()
	g.scale = Vector3.ONE * 1.3
	# Мигающий огонёк — видно, куда летит.
	var blink := OmniLight3D.new()
	blink.light_color = Color(1.0, 0.3, 0.15)
	blink.omni_range = 2.0
	blink.light_energy = 1.5
	g.add_child(blink)
	var level := player.get_parent()
	level.add_child(g)
	g.global_position = from
	Sfx.play(&"dodge", from, -6.0)
	var stats := grenade_stats()
	var damage: float = stats.damage
	var radius: float = stats.radius
	var elements: Dictionary = stats.elements
	var tween := g.create_tween()
	tween.tween_method(func(t: float) -> void:
		var p := from.lerp(target, t)
		p.y = lerpf(from.y, target.y + 0.15, t) + sin(t * PI) * 2.2
		g.global_position = p
		g.rotation = Vector3(t * 12.0, t * 7.0, 0), 0.0, 1.0, grenade_flight)
	tween.tween_callback(func() -> void:
		var at := g.global_position
		g.queue_free()
		_explode(at, radius, damage, &"physical", 0.0)
		for element in elements:
			_explode(at, radius, damage * elements[element], element, 0.0))


## Куда бросать: во врага, в которого целимся (с небольшим упреждением); если цели нет —
## в ближайшего врага по направлению прицела; иначе в курсор мыши или вперёд.
func _aim_point(max_range := -1.0) -> Vector3:
	var throw_range := grenade_range if max_range <= 0.0 else max_range
	var pos: Vector3 = player.global_position
	var aim: Vector3 = player._aim_dir if player._aim_dir.length() > 0.1 else -player.global_basis.z
	var target := pos + aim.normalized() * throw_range * 0.75
	var enemy: Node3D = player.aim_target
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_in_group("enemies"):
		enemy = null
		# На геймпаде без цели — ближайший враг по прицелу; мышью — туда, где курсор.
		if not player._using_mouse:
			enemy = player._find_target(aim.normalized(), 35.0, throw_range * 1.2)
	if enemy != null and is_instance_valid(enemy):
		target = enemy.global_position
		if "velocity" in enemy:
			var v: Vector3 = enemy.velocity
			target += Vector3(v.x, 0, v.z) * grenade_flight * 0.6
	elif player._using_mouse:
		var camera := player.get_viewport().get_camera_3d()
		if camera != null:
			var mouse := player.get_viewport().get_mouse_position()
			var hit = Plane(Vector3.UP, pos.y).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
			if hit != null:
				target = hit
	var flat := target - pos
	flat.y = 0.0
	if flat.length() > throw_range:
		target = pos + flat.normalized() * throw_range
	# Не за стену: если по пути стена — падает у стены.
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP, target + Vector3.UP, 1 | 16)
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		target = h.position - flat.normalized() * 0.4
	target.y = pos.y
	return target


func nova() -> void:
	if Game.mode != &"demo":
		return
	if nova_timer > 0.0:
		Sfx.play(&"empty", player.global_position)
		return
	nova_timer = nova_cooldown
	var at: Vector3 = player.global_position
	_explode(at, nova_radius, nova_damage * _level_mult(), &"electric", nova_knockback)
	Sfx.play(&"zap", at, 4.0)
	# Расходящееся кольцо.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.45, 0.75, 1.0, 0.9)
	torus.material = m
	ring.mesh = torus
	player.get_parent().add_child(ring)
	ring.global_position = at + Vector3.UP * 0.3
	ring.scale = Vector3(0.3, 0.2, 0.3)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(nova_radius, 0.2, nova_radius), 0.3)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)


func _explode(at: Vector3, radius: float, damage: float, element: StringName, knock: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue
		var flat: Vector3 = enemy.global_position - at
		flat.y = 0.0
		var d := flat.length()
		if d > radius:
			continue
		enemy.take_damage(damage * (1.0 - 0.4 * d / radius), element, player)
		if knock > 0.0 and is_instance_valid(enemy) and "velocity" in enemy:
			var dir := flat.normalized() if d > 0.05 else Vector3.FORWARD
			var resist: float = enemy.get("knockback_resist") if enemy.get("knockback_resist") != null else 0.0
			enemy.velocity += dir * knock * (1.0 - resist)
	if element == &"physical":
		Fx.explosion(at, radius)
	else:
		Fx.shake(0.35)
	if player.has_method("vibrate"):
		player.vibrate(0.6, 0.8, 0.2)


# --- Мины ----------------------------------------------------------------------------------

func _mine_stats() -> Dictionary:
	if player.get("_stats") == null:
		return {}
	for i in [player.current_weapon_index(), 1, 2, 3]:
		var item: GearItem = player.weapon_item(i)
		if item != null and item.slot == &"mines" and i < player._stats.size():
			return player._stats[i]
	return {}


func max_mines() -> int:
	return int(_mine_stats().get("magazine", 0))


## Бросок мины туда, куда целишься (как граната, но ближе). «Доп. снаряды» — несколько мин веером.
func place_mine() -> bool:
	if player.is_dodging() or player._recovery_left > 0 or _mine_throw_left > 0:
		return false
	var st := _mine_stats()
	if st.is_empty() or mines <= 0:
		Sfx.play(&"empty", player.global_position)
		return false
	if mines >= st.magazine:
		mine_timer = st.reload_time
	mines -= 1
	_mine_throw_left = 1.0 / maxf(st.fire_rate, 0.1)
	player.get_node("Animator").play_throw()
	var ammo: StringName = st.get("ammo", &"")
	var color: Color = Fx.ELEMENT_COLORS.get(ammo, Color(1.0, 0.35, 0.2))
	var target := _aim_point(mine_throw_range)
	var from: Vector3 = player.global_position + Vector3.UP * 1.3
	var flat := target - player.global_position
	flat.y = 0.0
	var side := Vector3(-flat.z, 0, flat.x).normalized() if flat.length() > 0.1 else Vector3.RIGHT
	var count: int = maxi(1, st.get("pellets", 1))
	for k in count:
		var spot := target + side * (k - (count - 1) * 0.5) * mine_spread
		_throw_mine(from, spot, color)
	Sfx.play(&"dodge", from, -6.0)
	return true


func _throw_mine(from: Vector3, to: Vector3, color: Color) -> void:
	while _active_mines.size() >= mine_max_active:
		_detonate(_active_mines[0])
	var mine := _make_mine(color)
	player.get_parent().add_child(mine)
	mine.global_position = from
	mine.set_meta("arm", 9999.0)
	var snapshot := _mine_stats().duplicate(true)
	mine.set_meta("stats", snapshot)
	mine.set_meta("t", 0.0)
	_active_mines.append(mine)
	var tw := mine.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(mine):
			return
		var p := from.lerp(to, t)
		p.y = lerpf(from.y, to.y + 0.02, t) + sin(t * PI) * 1.4
		mine.global_position = p, 0.0, 1.0, mine_flight)
	tw.tween_callback(func() -> void:
		if is_instance_valid(mine):
			mine.set_meta("t", 0.0)
			mine.set_meta("arm", mine_arm_time)
			Sfx.play(&"key_pickup", to, -6.0))


func _make_mine(color: Color) -> Node3D:
	var mine := Node3D.new()
	var body := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.28
	disc.height = 0.08
	disc.radial_segments = 12
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.17, 0.18)
	metal.metallic = 0.7
	metal.roughness = 0.4
	disc.material = metal
	body.mesh = disc
	body.position.y = 0.04
	mine.add_child(body)
	var lamp := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 4.0
	dot.material = glow
	lamp.mesh = dot
	lamp.position.y = 0.1
	mine.add_child(lamp)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 1.6
	light.light_energy = 0.8
	light.position.y = 0.3
	mine.add_child(light)
	mine.set_meta("lamp", lamp)
	mine.set_meta("light", light)
	return mine


func _update_mines(delta: float) -> void:
	for mine in _active_mines.duplicate():
		if not is_instance_valid(mine) or not mine.is_inside_tree():
			_active_mines.erase(mine)
			continue
		var t: float = mine.get_meta("t") + delta
		mine.set_meta("t", t)
		var arm: float = mine.get_meta("arm")
		# Мигает: до взвода медленно, потом часто.
		var blink := 0.5 + 0.5 * sin(t * (6.0 if t < arm else 14.0))
		(mine.get_meta("light") as OmniLight3D).light_energy = 0.3 + blink * 1.2
		(mine.get_meta("lamp") as Node3D).visible = blink > 0.3
		if t < arm:
			continue
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node3D:
				var flat: Vector3 = enemy.global_position - mine.global_position
				flat.y = 0.0
				if flat.length() < mine_trigger_radius:
					_detonate(mine)
					break


## Взрыв: урон ранца с модулями по площади. Стихия патронов меняет взрыв:
## огонь — огненный шар и поджог, кислота — лужа, которая жжёт и разъедает броню, электричество — молнии к соседям.
func _detonate(mine: Node3D) -> void:
	_active_mines.erase(mine)
	if not is_instance_valid(mine):
		return
	var at := mine.global_position
	at.y = player.global_position.y
	mine.queue_free()
	var st: Dictionary = mine.get_meta("stats", {})
	if st.is_empty():
		return
	var damage: float = st.damage
	var radius: float = st.explode_radius
	var ammo: StringName = st.get("ammo", &"")
	_area_hit(at, radius, damage, st.elements)
	match ammo:
		&"fire":
			Fx.explosion(at, radius * 1.15)
			Fx.flipbook(&"explosion", at + Vector3.UP * 0.8, radius * 1.6, 0.55, Color(1.0, 0.55, 0.2))
			Fx.flipbook(&"spark", at + Vector3.UP * 0.4, radius * 1.2, 0.3, Fx.ELEMENT_COLORS[&"fire"])
		&"acid":
			Fx.flipbook(&"smoke", at + Vector3.UP * 0.5, radius * 1.4, 0.6, Color(0.45, 1.0, 0.25, 0.8), false, true)
			_acid_puddle(at, radius, damage)
		&"electric":
			Fx.flipbook(&"spark", at + Vector3.UP * 0.6, radius * 1.8, 0.3, Fx.ELEMENT_COLORS[&"electric"])
			Sfx.play(&"zap", at, 2.0)
			_arcs(at, radius, damage)
		_:
			Fx.explosion(at, radius)
	if player.has_method("vibrate"):
		player.vibrate(0.5, 0.7, 0.18)


func _area_hit(at: Vector3, radius: float, damage: float, elements: Dictionary) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue
		var flat: Vector3 = enemy.global_position - at
		flat.y = 0.0
		var d := flat.length()
		if d > radius:
			continue
		var k := 1.0 - 0.4 * d / radius
		enemy.take_damage(damage * k, &"physical", player)
		for element in elements:
			if is_instance_valid(enemy):
				enemy.take_damage(damage * k * elements[element], element, player)


## Кислотная лужа: зелёное пятно, раз в puddle_tick — кислотный урон всем внутри (и разъедание брони).
func _acid_puddle(at: Vector3, radius: float, damage: float) -> void:
	# Пятно на полу — наклейка (Decal): ложится только на пол, не залезает на стены, мягкие края.
	var puddle := Decal.new()
	puddle.texture_albedo = PUDDLE_TEXTURE
	puddle.size = Vector3(radius * 2.2, 2.0, radius * 2.2)
	puddle.modulate = Color(0.45, 1.0, 0.2, 0.0)
	puddle.albedo_mix = 1.0
	puddle.emission_energy = 1.5
	puddle.texture_emission = PUDDLE_TEXTURE
	puddle.upper_fade = 0.2
	puddle.lower_fade = 0.2
	player.get_parent().add_child(puddle)
	puddle.global_position = at
	puddle.rotation.y = randf() * TAU
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.2)
	light.omni_range = radius * 1.3
	light.light_energy = 1.0
	light.position.y = 0.6
	puddle.add_child(light)
	var appear := puddle.create_tween()
	appear.tween_property(puddle, "modulate:a", 0.85, 0.25)
	var ticks := int(puddle_time / puddle_tick)
	var tw := puddle.create_tween()
	for i in ticks:
		tw.tween_interval(puddle_tick)
		tw.tween_callback(func() -> void:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy is Node3D:
					var flat: Vector3 = enemy.global_position - at
					flat.y = 0.0
					if flat.length() <= radius:
						enemy.take_damage(damage * puddle_ratio, &"acid", player)
			if randf() < 0.5:
				var off := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * radius * 0.6
				Fx.flipbook(&"smoke", at + off + Vector3.UP * 0.3, 1.2, 0.5, Color(0.45, 1.0, 0.25, 0.6), false, true))
	tw.tween_property(puddle, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.6)
	tw.tween_callback(puddle.queue_free)


## Электрический взрыв: молнии от центра к ближайшим врагам (до двух радиусов) — урон и шок.
func _arcs(at: Vector3, radius: float, damage: float) -> void:
	var targets := []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D:
			var d: float = (enemy.global_position - at).length()
			if d <= radius * 2.2:
				targets.append([d, enemy])
	targets.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	if targets.is_empty():
		return
	var mesh := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.6, 0.85, 1.0)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, m)
	var start := at + Vector3.UP * 1.0
	var hit := []
	for i in mini(arc_targets, targets.size()):
		var enemy: Node3D = targets[i][1]
		hit.append(enemy)
		var end := enemy.global_position + Vector3.UP * 1.0
		var prev := start
		for s in range(1, 7):
			var p := start.lerp(end, s / 6.0)
			if s < 6:
				p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3))
			mesh.surface_add_vertex(prev)
			mesh.surface_add_vertex(p)
			prev = p
	mesh.surface_end()
	for enemy in hit:
		if is_instance_valid(enemy):
			enemy.take_damage(damage * arc_ratio, &"electric", player)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(mi.queue_free)
