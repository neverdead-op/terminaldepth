extends Node3D
## Пуля. Не создаётся и не удаляется каждый раз: её берут из пула и возвращают.
## Попадание проверяется лучом от прошлой позиции к новой — быстрые пули не пролетают сквозь стены.
## Что делает пуля при попадании, задаёт «груз» (payload) от оружия с модулями:
##   damage — физический урон, elements — {стихия: доля} добавленного урона,
##   pierce — сколько врагов прошить насквозь, chain — сколько раз перескочить на другого врага,
##   leech — доля урона, которая лечит стрелка, shooter — кто стрелял.

const StakeImpact := preload("res://scripts/stake_impact.gd")
const HIT_MASK := 1 | 4 | 16  # слой 1 — стены и пол, 3 (значение 4) — враги, 5 (значение 16) — двери
const CHAIN_RANGE := 10.0
## Рикошет срабатывает не всегда, и перескочившая пуля бьёт слабее.
const CHAIN_CHANCE := 0.6
const CHAIN_DAMAGE := 0.7
const EXPLOSION := preload("res://scenes/explosion.tscn")
## Самонаведение: на каком расстоянии и в каком конусе пуля ищет цель.
const HOMING_RANGE := 14.0
const HOMING_CONE := 0.35  # косинус: ~70° от курса

var active := false
var _speed := 0.0
var _life := 0.0
var _max_life := 1.0
var _from := Vector3.ZERO  # откуда проверять следующий отрезок полёта
var _payload: Dictionary
var _pierce_left := 0
var _chain_left := 0
var _exclude: Array[RID] = []  # уже поражённые враги — второй раз в них не попадаем
var _hit_enemies: Array[Node] = []
var _homing_target: Node3D
var _look := &"bullet"
var _travel := 0.0
## Длина светящегося хвоста трассера (м).
const TRACER_LEN := 0.8
## Меши и материалы для видов снарядов (общие на все пули).
static var _looks := {}
var _homing_retarget := 0.0
var _ammo := &""
var _damage_mult := 1.0
## Насколько ствол выше линии огня: след пули начинается у ствола и за первые метры опускается к линии.
var _lift := 0.0
var _bar_width := 0.0
const LIFT_DISTANCE := 2.5
## След кола: рассечённый воздух за летящим колом (м). Растёт с полётом до этой длины.
const STAKE_TRAIL_LEN := 1.4
static var _trail_meshes: Array[Mesh] = []
var _trail: Array[MeshInstance3D] = []
## На каком расстоянии изображение пули сходится с линией огня: точка первого попадания или конец полёта.
## Сходимость линейная — трассер выглядит одной прямой от ствола, без излома.
var _lift_distance := LIFT_DISTANCE


## shooter_point — точка внутри стрелка (грудь). Первый отрезок проверяется от неё до ствола,
## чтобы враг вплотную, оказавшийся «за» стволом, тоже получал попадание.
func activate(start: Transform3D, speed: float, max_range: float, shooter_point: Vector3, payload: Dictionary) -> void:
	global_transform = start
	_from = shooter_point
	_speed = speed
	_life = 0.0
	_max_life = max_range / maxf(speed, 0.01)
	_payload = payload
	_pierce_left = payload.get("pierce", 0)
	_chain_left = payload.get("chain", 0)
	_damage_mult = 1.0
	_lift = float(payload.get("lift", 0.0)) if payload.get("look", &"bullet") in [&"bullet", &"pellet", &"wood_arrow", &"stake"] else 0.0
	_exclude.assign(payload.get("exclude_rids", []))
	_lift_distance = max_range
	if _lift != 0.0:
		var probe := PhysicsRayQueryParameters3D.create(start.origin, start.origin - start.basis.z * max_range, HIT_MASK, _exclude)
		var first := get_world_3d().direct_space_state.intersect_ray(probe)
		if not first.is_empty():
			_lift_distance = maxf(start.origin.distance_to(first.position), 0.5)
	_hit_enemies.clear()
	_homing_target = null
	_homing_retarget = 0.0
	_set_look(payload.get("look", &"bullet"))
	_bar_width = maxf(0.08, float(payload.get("width", 0.75))) if _look == &"plasma" else 0.0
	_ammo = payload.get("ammo", &"")
	if _look == &"bullet" and _ammo != &"":
		# Стихийные патроны — трассер своего цвета.
		var key := StringName("bullet_" + _ammo)
		if not _looks.has(key):
			var c: Color = Fx.ELEMENT_COLORS[_ammo]
			_looks[key] = _tracer(c.lightened(0.5), Color(c, 0.0), 0.022)
		$Mesh.mesh = _looks[key]
	_travel = 0.0
	$Mesh.scale = Vector3.ONE
	if _look == &"plasma":
		$Mesh.scale.x = _bar_width
	if _look == &"pellet":
		$Mesh.scale = Vector3.ONE * float(payload.get("pellet_visual_scale", 1.0))
	$Mesh.visible = not payload.get("hide_tracer", false)
	$Mesh.rotation = Vector3.ZERO
	$Mesh.position = Vector3(0, _lift, TRACER_LEN * 0.025 if _look == &"bullet" else 0.0)
	if _look == &"plasma": $Mesh.position.z = 0.09
	if _look == &"bullet":
		$Mesh.scale.z = 0.05
	_show_trail(_look == &"stake")
	reset_physics_interpolation()
	active = true
	visible = true
	set_physics_process(true)


func deactivate() -> void:
	_show_trail(false)
	active = false
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var homing: float = _payload.get("homing", 0.0)
	if homing > 0.0:
		_steer(homing, delta)
	var from := _from
	var to := global_position - global_basis.z * _speed * delta
	if _look == &"plasma":
		_step_plasma(from, to, delta)
		return
	_from = to

	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, _exclude)
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var target: Object = hit.collider
		if target != null and target.has_method("take_damage"):
			# Полоску цели сверху переключает только первое попадание пули, не рикошет и не прострел.
			Enemy.mark_target = _hit_enemies.is_empty()
			var flight := -global_basis.z
			# Кол: если добьёт — тело отлетит вперёд (Enemy.impale_push), и кол останется торчать.
			if _look == &"stake" and "impale_push" in target:
				target.set("impale_push", Vector3(flight.x, 0, flight.z).normalized() * float(_payload.get("impale_push", 2.6)))
			_damage(target)
			if _look == &"stake":
				if is_instance_valid(target) and target is Enemy and not target.is_dead():
					target.set("impale_push", Vector3.ZERO)
				if is_instance_valid(target) and target is Enemy:
					StakeImpact.stick_in_enemy(target, hit.position, flight)
			Enemy.mark_target = false
			if _payload.get("explode_radius", 0.0) > 0.0:
				_explode(hit.position, target)
			Enemy.mark_target = true
			Sfx.play(&"hit_flesh", hit.position)
			if _ammo != &"":
				Fx.element_hit(hit.position, _ammo)
			if is_instance_valid(target):
				_exclude.append(target.get_rid())
			_hit_enemies.append(target)
			if _pierce_left > 0:
				_pierce_left -= 1
				global_position = hit.position
				_from = hit.position
				return
			if _chain_left > 0 and _ricochet(hit.position):
				return
		else:
			if _look == &"grenade":
				_explode(hit.position, null)
			elif _look == &"wood_arrow":
				Sfx.play(&"bow_impact", hit.position, -8.0)
			elif _look == &"stake":
				Sfx.play(&"bow_impact", hit.position)
				Fx.sparks(hit.position, hit.normal)
				StakeImpact.stick_in_wall(get_tree().current_scene, hit.position, -global_basis.z)
			elif _look != &"flame":
				Sfx.play(&"hit_wall", hit.position)
				Fx.sparks(hit.position, hit.normal)
				Fx.bullet_hole(hit.position, hit.normal)
				if _ammo != &"":
					Fx.element_hit(hit.position, _ammo)
		deactivate()
		return

	global_position = to
	_life += delta
	if _look != &"bullet":
		_travel += _speed * delta
		if _look == &"pellet" or _look == &"stake":
			$Mesh.position.y = _lift * (1.0 - clampf(_travel / _lift_distance, 0.0, 1.0))
		elif _look == &"wood_arrow":
			$Mesh.position.y = _lift * (1.0 - smoothstep(0.0, 4.0, _travel))
	if _look == &"stake":
		_update_trail()
	if _look == &"bullet":
		_travel += _speed * delta
		_update_tracer(_speed * delta)
	if _look == &"flame":
		# Струя огня расширяется и тускнеет к концу полёта.
		var t := _life / _max_life
		$Mesh.scale = Vector3.ONE * (0.6 + t * 2.2)
	if _life > _max_life:
		if _look == &"grenade" and _payload.get("explode_radius", 0.0) > 0.0:
			_explode(global_position, null)
		deactivate()


## Первый видимый отрезок соединён с настоящим дулом даже при низкой частоте кадров.
## Проверка попаданий остаётся на линии огня; высота изображения плавно сходится к ней.
func _update_tracer(step_distance: float) -> void:
	var length := minf(_travel, maxf(TRACER_LEN, step_distance))
	var tail_distance := maxf(0.0, _travel - length)
	var head_lift := _lift * (1.0 - clampf(_travel / _lift_distance, 0.0, 1.0))
	var tail_lift := _lift * (1.0 - clampf(tail_distance / _lift_distance, 0.0, 1.0))
	var head := global_position + Vector3.UP * head_lift
	var tail := global_position + global_basis.z * length + Vector3.UP * tail_lift
	var segment := head - tail
	if segment.length_squared() < 0.000001: return
	$Mesh.global_transform = Transform3D(Basis.looking_at(segment.normalized(), Vector3.UP), (head + tail) * 0.5)
	$Mesh.scale = Vector3(1, 1, segment.length() / TRACER_LEN)


## Одна цельная полоса: боковые проверки одной плоскости, пробивание расходуется по глубине.
func _step_plasma(from: Vector3, to: Vector3, delta: float) -> void:
	var direction := -global_basis.z
	var right := global_basis.x
	var nearest := INF
	var hits: Dictionary = {}
	var world := get_world_3d().direct_space_state
	var samples := maxi(3, ceili(_bar_width / 0.10) + 1)
	for i in samples:
		var offset := right * (float(i) / (samples - 1) - 0.5) * _bar_width
		var query := PhysicsRayQueryParameters3D.create(from + offset, to + offset, HIT_MASK, _exclude)
		query.hit_from_inside = true
		var hit := world.intersect_ray(query)
		if hit.is_empty(): continue
		var depth: float = (hit.position - from).dot(direction)
		hit.depth = depth
		nearest = minf(nearest, depth)
		var key: RID = hit.rid
		if not hits.has(key) or depth < hits[key].depth: hits[key] = hit
	if not hits.is_empty():
		var stop := from + direction * nearest
		var wall := false
		var damaged := false
		for hit in hits.values():
			# Цели сбоку поражаются, задние ждут явно заданного пробивания.
			if hit.depth > nearest + 0.18: continue
			var target = hit.collider
			if not is_instance_valid(target): continue
			if not target.has_method("take_damage"):
				wall = true
				Fx.sparks(hit.position, hit.normal)
				continue
			global_position = hit.position
			Enemy.mark_target = _hit_enemies.is_empty()
			_damage(target)
			Enemy.mark_target = true
			Fx.element_hit(hit.position, &"electric")
			if _payload.get("explode_radius", 0.0) > 0: _explode(hit.position, target)
			_exclude.append(hit.rid)
			_hit_enemies.append(target)
			damaged = true
		global_position = stop
		_from = stop
		Sfx.play(&"zap", stop, -8.0)
		if wall or not damaged or _pierce_left <= 0:
			deactivate()
			return
		_pierce_left -= 1
		# Рикошет — отдельный явный модификатор, сам по себе сквозной полёт не разрешает.
	elif _life + delta >= _max_life:
		deactivate()
		return
	else:
		global_position = to
		_from = to
	_life += delta
	_travel += _speed * delta


func _damage(target: Object) -> void:
	var base: float = _payload.get("damage", 0.0) * _damage_mult
	var shooter = _payload.get("shooter")
	var nova_target: bool = target is Enemy or (target is Node and target.is_in_group("enemies"))
	var dealt := _deal(target, base, &"physical", shooter)
	var elements: Dictionary = _payload.get("elements", {})
	for element in elements:
		dealt += _deal(target, base * elements[element], element, shooter)
	if shooter != null and is_instance_valid(shooter) and shooter.has_method("on_hit_confirmed"):
		shooter.on_hit_confirmed(is_instance_valid(target) and target.has_method("is_dead") and target.is_dead())
	if is_instance_valid(target) and target is Node3D:
		Fx.impact(global_position, -global_basis.z)
	if nova_target and is_instance_valid(target):
		_spawn_nova(target)
	var leech: float = _payload.get("leech", 0.0)
	if leech > 0.0 and shooter != null and is_instance_valid(shooter):
		shooter.on_damage_dealt(dealt, leech)


## Общее состояние выстрела разделяется всеми дробинками и прострелами.
## Отложенный запуск не даёт полному пулу переиспользовать текущую пулю внутри её попадания.
func _spawn_nova(target: Node3D) -> void:
	var count := int(_payload.get("nova_projectiles", 0))
	if count <= 0: return
	var state: Dictionary = _payload.get("nova_state", {})
	if state.get("triggered", false): return
	state.triggered = true
	_payload.nova_state = state
	var pool := get_tree().get_first_node_in_group("bullet_pool")
	if pool == null: return
	var at := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	var child := _payload.duplicate()
	child.damage = float(_payload.get("damage", 0.0)) * _damage_mult * float(_payload.get("nova_damage_ratio", 0.5))
	child.nova_projectiles = 0
	child.nova_secondary = true
	child.lift = 0.0
	var excluded: Array[RID] = []
	if target is CollisionObject3D: excluded.append(target.get_rid())
	child.exclude_rids = excluded
	var distance := maxf(0.1, _speed * (_max_life - _life))
	var incoming := -global_basis.z
	for i in count:
		var direction := incoming.rotated(Vector3.UP, TAU * i / count)
		var start := Transform3D(Basis.looking_at(direction, Vector3.UP), at)
		pool.fire.call_deferred(start, _speed, distance, at, child)


func _deal(target: Object, amount: float, element: StringName, shooter) -> float:
	if not is_instance_valid(target):
		return 0.0
	var result = target.take_damage(amount, element, shooter, bool(_payload.get("allow_stagger", true))) if target is Enemy else target.take_damage(amount, element, shooter)
	return result if result is float else amount


func _set_look(look: StringName) -> void:
	# Сравниваем с тем, что реально стоит на этой пуле: у каждой пули пула свой меш
	# (раньше проверялось только имя вида — и все пули, кроме первой, оставались старыми толстыми брусками).
	if look == _look and _looks.has(look) and $Mesh.mesh == _looks[look]:
		return
	_look = look
	if look == &"wood_arrow":
		$Mesh.mesh = preload("res://scripts/wood_arrow_mesh.gd").make_arrow()
		return
	if look == &"stake":
		$Mesh.mesh = StakeImpact.mesh()
		$Mesh.scale = Vector3.ONE
		$Mesh.position = Vector3.ZERO
		return
	if not _looks.has(&"bullet"):
		_looks[&"bullet"] = _tracer()
		_looks[&"pellet"] = _ball(0.035, Color(0.035, 0.03, 0.025), Color.BLACK, 0.0)
		_looks[&"arrow"] = _box(Vector3(0.05, 0.05, 1.3), Color(0.4, 0.95, 1.0), 6.0)
		_looks[&"grenade"] = _ball(0.16, Color(0.25, 0.3, 0.2), Color(1.0, 0.6, 0.2), 2.0)
		_looks[&"flame"] = _ball(0.32, Color(1.0, 0.45, 0.08, 0.65), Color(1.0, 0.45, 0.05), 5.0)
		_looks[&"plasma"] = _box(Vector3(1.0, 0.075, 0.18), Color(0.24, 0.86, 1.0), 4.5)
	$Mesh.mesh = _looks.get(look, _looks[&"bullet"])
	$Mesh.scale = Vector3.ONE
	$Mesh.position = Vector3.ZERO


## Трассер: тонкая светящаяся черта, к хвосту гаснет.
## След кола: широкая бледная «волна» воздуха и тонкая светлая сердцевина, обе гаснут к хвосту.
func _show_trail(on: bool) -> void:
	if on and _trail.is_empty():
		if _trail_meshes.is_empty():
			_trail_meshes.append(_tracer(Color(0.75, 0.82, 0.9, 0.16), Color(0.6, 0.7, 0.85, 0.0), 0.025))
			_trail_meshes.append(_tracer(Color(1.0, 0.93, 0.8, 0.45), Color(0.9, 0.75, 0.55, 0.0), 0.005))
		for mesh in _trail_meshes:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_trail.append(mi)
	for mi in _trail:
		mi.visible = on
		mi.scale = Vector3(1, 1, 0.01)


func _update_trail() -> void:
	var length := minf(_travel, STAKE_TRAIL_LEN)
	if length <= 0.01: return
	for mi in _trail:
		# Начинается у хвоста кола (+Z — назад) и тянется к стрелку.
		mi.position = Vector3(0, $Mesh.position.y, 0.25 + length * 0.5)
		mi.scale = Vector3(1, 1, length / TRACER_LEN)


static func _tracer(head := Color(1.0, 0.95, 0.85, 0.95), tail := Color(0.9, 0.55, 0.3, 0.0), w := 0.014) -> Mesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 1.0, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := TRACER_LEN * 0.5
	# Две перекрещенные полоски (видно с любого угла), голова яркая, хвост прозрачный.
	for axis in [Vector3(w, 0, 0), Vector3(0, w, 0)]:
		var p := [-axis + Vector3(0, 0, -h), axis + Vector3(0, 0, -h), axis + Vector3(0, 0, h), -axis + Vector3(0, 0, h)]
		var c := [head, head, tail, tail]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(c[idx])
			st.add_vertex(p[idx])
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	return mesh


static func _box(size: Vector3, color: Color, energy: float) -> Mesh:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	var b := BoxMesh.new()
	b.size = size
	b.material = m
	return b


static func _ball(radius: float, color: Color, glow: Color, energy: float) -> Mesh:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = energy
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 8
	s.rings = 4
	s.material = m
	return s


## Взрывные патроны: урон всем врагам в радиусе (кроме того, в кого попали), огненная вспышка.
func _explode(at: Vector3, direct: Object) -> void:
	var radius: float = _payload.get("explode_radius", 0.0)
	var amount: float = _payload.get("damage", 0.0) * _payload.get("explode_ratio", 0.0)
	var shooter = _payload.get("shooter")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == direct or not enemy is Node3D:
			continue
		var flat: Vector3 = enemy.global_position - at
		flat.y = 0.0
		if flat.length() <= radius:
			_deal(enemy, amount, &"physical", shooter)
	var boom := EXPLOSION.instantiate()
	boom.sound = &"explosion"
	boom.scale = Vector3.ONE * 0.45
	get_tree().current_scene.add_child(boom)
	boom.global_position = at


## Самонаведение: раз в 0.15 с выбираем ближайшего врага впереди и плавно доворачиваем к нему.
func _steer(rate: float, delta: float) -> void:
	_homing_retarget -= delta
	if _homing_retarget <= 0.0:
		_homing_retarget = 0.15
		_homing_target = null
		var forward := -global_basis.z
		var best := HOMING_RANGE
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy in _hit_enemies or not enemy is Node3D:
				continue
			var to: Vector3 = enemy.global_position - global_position
			to.y = 0.0
			var d := to.length()
			if d < best and d > 0.1 and forward.dot(to / d) > HOMING_CONE:
				best = d
				_homing_target = enemy
	if _homing_target == null or not is_instance_valid(_homing_target):
		return
	var aim := _homing_target.global_position
	aim.y = global_position.y
	var want := (aim - global_position).normalized()
	var now := -global_basis.z
	var turned := now.slerp(want, clampf(rate * delta, 0.0, 1.0)).normalized()
	if turned.length() > 0.1:
		look_at(global_position + turned, Vector3.UP)


## Рикошет: ищем ближайшего живого врага, в которого ещё не попадали и до которого нет стены.
func _ricochet(at: Vector3) -> bool:
	if randf() > CHAIN_CHANCE:
		return false
	var best: Node3D = null
	var best_distance := CHAIN_RANGE
	var space := get_world_3d().direct_space_state
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_enemies or not enemy is Node3D:
			continue
		var distance := at.distance_to(enemy.global_position)
		if distance >= best_distance:
			continue
		var target: Vector3 = enemy.global_position
		target.y = at.y
		var query := PhysicsRayQueryParameters3D.create(at, target, 1 | 16)
		if not space.intersect_ray(query).is_empty():
			continue
		best = enemy
		best_distance = distance
	if best == null:
		return false
	_chain_left -= 1
	_damage_mult *= CHAIN_DAMAGE
	_lift = 0.0
	$Mesh.position.y = 0.0
	var aim := best.global_position
	aim.y = at.y
	global_position = at
	_from = at
	look_at(aim, Vector3.UP)
	_life = 0.0
	return true
