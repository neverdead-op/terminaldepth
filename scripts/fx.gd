extends Node3D
## Автозагрузка Fx: эффекты «сочности» боя. Всё из заранее созданных пулов, без создания объектов в бою.
##   Fx.hit(позиция, направление, цвет) — брызги из раны;
##   Fx.sparks(позиция, нормаль) — искры от попадания в стену;
##   Fx.number(позиция, урон, цвет) — всплывающая цифра урона;
##   Fx.shake(сила) — тряска камеры.

## Показывать цифры урона над врагами.
@export var damage_numbers := true
## Цифры урона летят дугой (правило Disney «дуги»): вверх и в сторону от выстрела, затем чуть падают.
## Выключить — цифры просто всплывают вверх, как раньше.
@export var number_arcs := true
## Высота дуги цифры (м).
@export_range(0.1, 2.0, 0.05) var number_arc_height := 0.75
## Насколько далеко цифра отлетает вбок (м).
@export_range(0.0, 2.0, 0.05) var number_arc_side := 0.7
## Сколько секунд летит цифра.
@export_range(0.3, 1.5, 0.05) var number_arc_time := 0.7
## Чистая стрельба: выключены все самодельные эффекты попаданий и смертей (кровь, ошмётки, брызги,
## искры, дырки, гильзы, дым, вспышки удара, конус дробовика). Остаются вспышка выстрела, взрывы гранат,
## цифры урона, тряска и колья. Включить обратно — галочку снять (Fx — Autoload, scenes/fx или scripts/fx.gd).
@export var clean_combat := false
@export var hit_pool_size := 36
@export var number_pool_size := 40
## Количество капель и выразительность брызг попадания.
@export_range(0.5, 3.0, 0.1) var blood_impact_scale := 1.6

var _emitters: Array[GPUParticles3D] = []
var _next_emitter := 0
var _labels: Array[Label3D] = []
var _next_label := 0
var _shells: Array[GPUParticles3D] = []
var _next_shell := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var drop := SphereMesh.new()
	drop.radius = 0.03
	drop.height = 0.06
	drop.radial_segments = 6
	drop.rings = 3
	for i in hit_pool_size:
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 10
		p.lifetime = 0.45
		p.explosiveness = 0.95
		p.local_coords = false
		var m := ParticleProcessMaterial.new()
		m.direction = Vector3(0, 0, -1)
		m.spread = 40.0
		m.initial_velocity_min = 3.5
		m.initial_velocity_max = 9.0
		m.gravity = Vector3(0, -12, 0)
		m.scale_min = 0.6
		m.scale_max = 1.4
		p.process_material = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		var mesh := drop.duplicate() as SphereMesh
		mesh.material = mat
		p.draw_pass_1 = mesh
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_emitters.append(p)
	# Гильзы: латунные цилиндрики, вылетают вбок и падают.
	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = 0.018
	shell_mesh.bottom_radius = 0.018
	shell_mesh.height = 0.06
	shell_mesh.radial_segments = 6
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.85, 0.65, 0.25)
	brass.metallic = 0.8
	brass.roughness = 0.35
	shell_mesh.material = brass
	for i in 10:
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 1
		p.lifetime = 0.7
		p.local_coords = false
		var m := ParticleProcessMaterial.new()
		m.direction = Vector3(0, 0, -1)
		m.spread = 18.0
		m.initial_velocity_min = 2.5
		m.initial_velocity_max = 3.5
		m.gravity = Vector3(0, -14, 0)
		m.angular_velocity_min = -720.0
		m.angular_velocity_max = 720.0
		p.process_material = m
		p.draw_pass_1 = shell_mesh
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_shells.append(p)
	for i in number_pool_size:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 40
		l.pixel_size = 0.008
		l.outline_size = 5
		l.outline_modulate = Color(0, 0, 0, 0.9)
		l.visible = false
		add_child(l)
		_labels.append(l)
	_build_muzzles()


## Брызги из раны. dir — куда летят (обычно от стрелка через врага).
## Попадание пулей со стихией (тип патронов): вспышка своего цвета.
func element_hit(at: Vector3, element: StringName) -> void:
	if clean_combat: return
	var c: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	flipbook(&"spark", at, randf_range(0.9, 1.15), 0.2, c)
	_burst(at, Vector3.UP, c, 6, 70.0)


func hit(at: Vector3, dir: Vector3, color: Color, amount := 10) -> void:
	if clean_combat: return
	# Вспышка удара пули в точке попадания (покадровый лист Brackeys) — «импакт» вместо белого тела.
	flipbook(&"spark", at - dir.normalized() * 0.15, randf_range(0.55, 0.75), 0.16, Color(1.0, 0.82, 0.6))
	_burst(at, dir, color, int(amount * 0.5 * blood_impact_scale), 48.0)
	flipbook(&"blood", at, randf_range(0.45, 0.65) * sqrt(blood_impact_scale) * (1.3 if amount > 14 else 1.0), 0.4, Color(color, 0.7), false, true)
	# Брызги: лист рисован на 100 пикселей, сами брызги ~30 — квад больше, чтобы брызги были ~0.8 м.
	flipbook(StringName("blood_px%d" % randi_range(1, 5)), at + dir.normalized() * 0.3, randf_range(2.2, 3.0) * sqrt(blood_impact_scale), 0.5,
			color.lightened(0.15), false, true)


## Гильза вылетает в сторону dir.
# --- Кровь на полу и стенах: пул наклеек (Decal), старые исчезают, когда пятен больше max_blood ---
@export var max_blood := 360
var _blood: Array[Decal] = []
var _next_blood := 0
var _blood_grow: Dictionary = {}


## Пятно крови: at — точка, normal — куда смотрит поверхность (пол — вверх, стена — от стены).
func blood_decal(at: Vector3, normal: Vector3, size: float, color: Color, grow := 0.35) -> void:
	if clean_combat: return
	if _blood.is_empty():
		for i in max_blood:
			var d := Decal.new()
			d.visible = false
			d.cull_mask = 1
			add_child(d)
			_blood.append(d)
	var d := _blood[_next_blood]
	_next_blood = (_next_blood + 1) % _blood.size()
	var previous: Tween = _blood_grow.get(d)
	if previous != null and previous.is_valid(): previous.kill()
	_blood_grow.erase(d)
	d.texture_albedo = Enemy.splat_texture(randi())
	d.modulate = color
	# Наклейка проецируется вдоль своей оси −Y: ставим Y по нормали поверхности.
	var y := normal.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(x, y, x.cross(y)).rotated(y, randf() * TAU)
	d.global_transform = Transform3D(basis, at + y * 0.05)
	var full := Vector3(size, 0.35, size * randf_range(0.7, 1.0))
	d.visible = true
	if grow > 0.0:
		d.size = Vector3(full.x * 0.3, full.y, full.z * 0.3)
		var tween := d.create_tween()
		_blood_grow[d] = tween
		tween.tween_property(d, "size", full, grow).set_ease(Tween.EASE_OUT)
	else:
		d.size = full


## Брызги крови от удара: капли на пол рядом и, если близко стена по направлению удара, — пятна на стене.
func blood_spray(from: Vector3, dir: Vector3, color: Color, amount := 1.0) -> void:
	if clean_combat: return
	var space := get_world_3d().direct_space_state
	var flat := Vector3(dir.x, 0, dir.z).normalized() if dir.length() > 0.01 else Vector3.FORWARD
	# Капли на пол.
	for i in int(ceil(3.0 * amount)):
		var p := from + flat * randf_range(0.3, 1.6) * amount + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP, p + Vector3.DOWN * 3.0, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			blood_decal(hit.position, hit.normal, randf_range(0.3, 0.75) * amount, color, 0.15)
	# Стены по направлению удара (веером).
	for i in int(ceil(2.0 * amount)):
		var d := flat.rotated(Vector3.UP, deg_to_rad(randf_range(-35, 35)))
		var start := from + Vector3.UP * randf_range(-0.2, 0.6)
		var q := PhysicsRayQueryParameters3D.create(start, start + d * 3.5 * amount, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf(hit.normal.y) < 0.5:
			blood_decal(hit.position, hit.normal, randf_range(0.6, 1.3) * amount, color, 0.1)


# --- Обломки: гильзы и куски врагов. Летят, падают на пол, подпрыгивают и остаются лежать ---
## Сколько гильз и кусков лежит одновременно (старые исчезают).
@export var max_shells := 30
@export var max_gibs := 160
var _debris: Array = []  # {node, vel, spin, floor_y, bounce, kind}
var _shell_nodes: Array[MeshInstance3D] = []
var _gib_nodes: Array[MeshInstance3D] = []
var _next_shell_node := 0
var _next_gib_node := 0
var _shell_mesh: Mesh
var _gib_meshes: Array[Mesh] = []
var _gib_mats := {}


func _floor_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 4.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else at.y - 1.0


func _launch(mi: MeshInstance3D, at: Vector3, vel: Vector3, kind: StringName, bounce: float) -> void:
	for d in _debris:
		if d.node == mi:
			_debris.erase(d)
			break
	if mi.get_parent() == null:
		add_child(mi)
	mi.global_position = at
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	mi.visible = true
	_debris.append({"node": mi, "vel": vel, "spin": Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15)),
			"floor_y": _floor_y(at), "bounce": bounce, "kind": kind})


func _physics_process(delta: float) -> void:
	if _debris.is_empty():
		return
	var still := []
	for d in _debris:
		var mi: MeshInstance3D = d.node
		if not is_instance_valid(mi):
			still.append(d)
			continue
		d.vel.y -= 18.0 * delta
		var p: Vector3 = mi.global_position + d.vel * delta
		if p.y <= d.floor_y + 0.02:
			p.y = d.floor_y + 0.02
			if absf(d.vel.y) > 1.2:
				d.vel = Vector3(d.vel.x * 0.55, -d.vel.y * d.bounce, d.vel.z * 0.55)
				d.spin *= 0.6
			else:
				# Лёг: кладём плашмя и больше не двигаем.
				mi.global_position = p
				mi.rotation = Vector3(PI * 0.5 if d.kind == &"shell" else mi.rotation.x * 0.2, mi.rotation.y, 0)
				still.append(d)
				continue
		mi.global_position = p
		mi.rotation += d.spin * delta
	for d in still:
		_debris.erase(d)


## Гильза: вылетает вбок от оружия, звякает о пол и остаётся лежать.
func shell(at: Vector3, dir: Vector3) -> void:
	if clean_combat: return
	if _shell_mesh == null:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.026
		cyl.bottom_radius = 0.026
		cyl.height = 0.09
		cyl.radial_segments = 6
		cyl.rings = 1
		var brass := StandardMaterial3D.new()
		brass.albedo_color = Color(0.85, 0.65, 0.25)
		brass.metallic = 0.6
		brass.roughness = 0.3
		brass.emission_enabled = true
		brass.emission = Color(0.85, 0.6, 0.2)
		brass.emission_energy_multiplier = 0.1
		cyl.material = brass
		_shell_mesh = cyl
		for i in max_shells:
			var mi := MeshInstance3D.new()
			mi.mesh = _shell_mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			add_child(mi)
			_shell_nodes.append(mi)
	var mi := _shell_nodes[_next_shell_node]
	_next_shell_node = (_next_shell_node + 1) % _shell_nodes.size()
	var v := dir.normalized() * randf_range(2.2, 3.4) + Vector3(randf_range(-0.6, 0.6), randf_range(1.0, 2.0), randf_range(-0.6, 0.6))
	_launch(mi, at, v, &"shell", 0.35)


## Куски врага при смерти: разлетаются от удара (dir), цвета крови и «кожи», остаются лежать.
func gibs(at: Vector3, dir: Vector3, blood: Color, skin: Color, count := 7, size := 1.0) -> void:
	if clean_combat: return
	if _gib_meshes.is_empty():
		for k in 4:
			var m: Mesh
			if k == 0:
				var b := BoxMesh.new()
				b.size = Vector3(0.26, 0.16, 0.2)
				m = b
			elif k == 1:
				var sp := SphereMesh.new()
				sp.radius = 0.15
				sp.height = 0.24
				sp.radial_segments = 6
				sp.rings = 3
				m = sp
			elif k == 3:
				# Продолговатый фрагмент конечности среди мелких кусков плоти.
				var limb := CapsuleMesh.new()
				limb.radius = 0.085
				limb.height = 0.52
				limb.radial_segments = 6
				limb.rings = 3
				m = limb
			else:
				var c := CapsuleMesh.new()
				c.radius = 0.08
				c.height = 0.4
				c.radial_segments = 6
				c.rings = 1
				m = c
			_gib_meshes.append(m)
		for i in max_gibs:
			var mi := MeshInstance3D.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			add_child(mi)
			_gib_nodes.append(mi)
	var push := Vector3(dir.x, 0, dir.z).normalized() if dir.length() > 0.01 else Vector3.ZERO
	for i in count:
		var mi := _gib_nodes[_next_gib_node]
		_next_gib_node = (_next_gib_node + 1) % _gib_nodes.size()
		mi.mesh = _gib_meshes[i % _gib_meshes.size()]
		var col := blood if i % 2 == 0 else skin
		var key := col.to_html()
		if not _gib_mats.has(key):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col.darkened(0.25)
			mat.roughness = 0.35
			_gib_mats[key] = mat
		mi.material_override = _gib_mats[key]
		mi.scale = Vector3.ONE * size * randf_range(0.7, 1.3)
		var v := push * randf_range(1.5, 4.0) + Vector3(randf_range(-2.2, 2.2), randf_range(2.5, 5.5), randf_range(-2.2, 2.2))
		_launch(mi, at + Vector3(randf_range(-0.2, 0.2), randf_range(0.2, 0.8), randf_range(-0.2, 0.2)) * size, v, &"gib", 0.25)


func _old_shell(at: Vector3, dir: Vector3) -> void:
	var p := _shells[_next_shell]
	_next_shell = (_next_shell + 1) % _shells.size()
	p.global_position = at
	if dir.length() > 0.01:
		p.look_at(at + dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT)
	p.restart()
	p.emitting = true


## Дырки от пуль на стенах (переиспользуем, старые исчезают).
## Цвета стихий: трассеры, вспышки у дула и попаданий.
const ELEMENT_COLORS := {&"fire": Color(1.0, 0.45, 0.12), &"acid": Color(0.5, 1.0, 0.2), &"electric": Color(0.45, 0.75, 1.0)}

const HOLE_POOL := 70
var _holes: Array[Decal] = []
var _next_hole := 0
var _impact_flashes: Array[MeshInstance3D] = []
var _next_impact := 0


const SCORCH := [preload("res://assets/vfx/scorch_01.png"), preload("res://assets/vfx/scorch_02.png"),
		preload("res://assets/vfx/scorch_03.png")]
const SMOKE := [preload("res://assets/vfx/smoke_01.png"), preload("res://assets/vfx/smoke_02.png"),
		preload("res://assets/vfx/smoke_03.png")]
var _smoke: Array[GPUParticles3D] = []
var _next_smoke := 0


## Дымок из ствола: пара серых клубов, поднимаются и расплываются.
func smoke(at: Vector3, dir: Vector3) -> void:
	if clean_combat: return
	if _smoke.is_empty():
		for i in 10:
			var p := GPUParticles3D.new()
			p.one_shot = true
			p.emitting = false
			p.amount = 3
			p.lifetime = 0.9
			p.explosiveness = 0.9
			p.local_coords = false
			var m := ParticleProcessMaterial.new()
			m.direction = Vector3(0, 0, -1)
			m.spread = 25.0
			m.initial_velocity_min = 0.4
			m.initial_velocity_max = 1.2
			m.gravity = Vector3(0, 0.6, 0)
			m.damping_min = 1.0
			m.damping_max = 2.0
			m.scale_min = 0.6
			m.scale_max = 1.1
			var curve := Curve.new()
			curve.add_point(Vector2(0, 0.4))
			curve.add_point(Vector2(1, 1.6))
			var ct := CurveTexture.new()
			ct.curve = curve
			m.scale_curve = ct
			var grad := Gradient.new()
			grad.set_color(0, Color(0.7, 0.7, 0.72, 0.35))
			grad.set_color(1, Color(0.6, 0.6, 0.62, 0.0))
			var gt := GradientTexture1D.new()
			gt.gradient = grad
			m.color_ramp = gt
			m.angle_min = -180.0
			m.angle_max = 180.0
			p.process_material = m
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			mat.albedo_texture = SMOKE[i % SMOKE.size()]
			var quad := QuadMesh.new()
			quad.size = Vector2(0.35, 0.35)
			quad.material = mat
			p.draw_pass_1 = quad
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(p)
			_smoke.append(p)
	var p := _smoke[_next_smoke]
	_next_smoke = (_next_smoke + 1) % _smoke.size()
	p.global_position = at
	if dir.length() > 0.01:
		p.look_at(at + dir.normalized(), Vector3.UP)
	p.restart()
	p.emitting = true


func _make_hole_texture() -> Texture2D:
	var t := GradientTexture2D.new()
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.02, 1))
	g.set_color(1, Color(0.1, 0.09, 0.08, 0))
	g.add_point(0.35, Color(0.05, 0.05, 0.05, 0.9))
	t.gradient = g
	return t


## След пули на стене: тёмное пятно, обращённое по нормали поверхности.
func bullet_hole(at: Vector3, normal: Vector3) -> void:
	if clean_combat: return
	if _holes.is_empty():
		for i in HOLE_POOL:
			var d := Decal.new()
			d.texture_albedo = SCORCH[i % SCORCH.size()]
			d.modulate = Color(0.06, 0.055, 0.05, 0.9)
			d.size = Vector3(0.3, 0.2, 0.3)
			d.visible = false
			add_child(d)
			_holes.append(d)
	var d := _holes[_next_hole]
	_next_hole = (_next_hole + 1) % HOLE_POOL
	d.visible = true
	d.global_position = at
	var up := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var side := up.cross(Vector3.FORWARD) if absf(up.dot(Vector3.FORWARD)) < 0.9 else up.cross(Vector3.RIGHT)
	d.global_basis = Basis(side.normalized(), up, side.cross(up).normalized()).rotated(up, randf() * TAU)
	var s := randf_range(0.8, 1.3)
	d.size = Vector3(0.3 * s, 0.2, 0.3 * s)
	impact(at + normal * 0.05, -normal, Color(1.0, 0.75, 0.4))
	_burst(at, normal, Color(0.55, 0.52, 0.48), 5, 50.0)




# --- Покадровые эффекты (Brackeys VFX Bundle / Unity Labs, CC0) -------------------------
## вид: [лист, сетка, сложение света (add), размер пула, (кадров, если лист заполнен не весь)]
const FLIPBOOKS := {
	&"explosion": [preload("res://assets/vfx/brackeys/explosion_01_5x5.tga"), Vector2(5, 5), false, 8],
	&"smoke": [preload("res://assets/vfx/brackeys/explosion_smoke_01_5x5.tga"), Vector2(5, 5), false, 8],
	# Кровь — тот же клуб дыма, перекрашенный в цвет крови врага (colorize).
	&"blood": [preload("res://assets/vfx/brackeys/explosion_smoke_01_5x5.tga"), Vector2(5, 5), false, 28],
	&"spark": [preload("res://assets/vfx/brackeys/impact_white_6x5.png"), Vector2(6, 5), true, 20, 14],
	# Пиксельные брызги крови (NEw pack blood, CodeManu, public domain): 5 вариантов, 30 кадров 6×6.
	&"blood_px1": [preload("res://assets/vfx/pixel/blood_1.png"), Vector2(6, 6), false, 10, 30],
	&"blood_px2": [preload("res://assets/vfx/pixel/blood_2.png"), Vector2(6, 6), false, 10, 30],
	&"blood_px3": [preload("res://assets/vfx/pixel/blood_3.png"), Vector2(6, 6), false, 10, 30],
	&"blood_px4": [preload("res://assets/vfx/pixel/blood_4.png"), Vector2(6, 6), false, 10, 30],
	&"blood_px5": [preload("res://assets/vfx/pixel/blood_5.png"), Vector2(6, 6), false, 10, 30],
}
var _flip_pools := {}
var _flip_next := {}


func _flip_pool(kind: StringName, flat: bool) -> Array:
	var key := StringName("%s_%s" % [kind, flat])
	if not _flip_pools.has(key):
		var def: Array = FLIPBOOKS[kind]
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/flipbook_add.gdshader") if def[2] else preload("res://assets/shaders/flipbook_mix.gdshader")
		mat.set_shader_parameter("tex", def[0])
		mat.set_shader_parameter("grid", def[1])
		mat.set_shader_parameter("billboard", not flat)
		var quad := QuadMesh.new()
		quad.material = mat
		var pool := []
		for i in def[3]:
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			add_child(mi)
			pool.append(mi)
		_flip_pools[key] = pool
		_flip_next[key] = 0
	return [_flip_pools[key], key]


## Покадровый эффект: kind из FLIPBOOKS, size — сторона квадрата (м), duration — время всей анимации.
## flat — лежит на полу (кольцо), colorize — перекрасить в tint (кровь любого цвета).
func flipbook(kind: StringName, at: Vector3, size: float, duration: float, tint := Color.WHITE, flat := false,
		colorize := false, delay := 0.0) -> void:
	if clean_combat and (kind == &"spark" or String(kind).begins_with("blood")): return
	var got := _flip_pool(kind, flat)
	var pool: Array = got[0]
	var key: StringName = got[1]
	var mi: MeshInstance3D = pool[_flip_next[key]]
	_flip_next[key] = (_flip_next[key] + 1) % pool.size()
	var grid: Vector2 = FLIPBOOKS[kind][1]
	var frames: float = FLIPBOOKS[kind][4] if FLIPBOOKS[kind].size() > 4 else grid.x * grid.y
	if mi.has_meta("tween"):
		var old: Tween = mi.get_meta("tween")
		if old != null and old.is_valid():
			old.kill()
	mi.visible = false
	mi.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)) if flat else Basis(), at)
	mi.scale = Vector3.ONE * size
	mi.set_instance_shader_parameter("frame", 0.0)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("spin", randf() * TAU if not flat else 0.0)
	mi.set_instance_shader_parameter("colorize", 1.0 if colorize else 0.0)
	var tw := mi.create_tween()
	mi.set_meta("tween", tw)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void: mi.visible = true)
	tw.tween_method(func(f: float) -> void: mi.set_instance_shader_parameter("frame", f), 0.0, frames - 0.01, duration)
	tw.tween_callback(func() -> void: mi.visible = false)


## Взрыв гранаты: огненный шар (покадровый), клубы дыма, искры, подпалина, свет и звук.
func explosion(at: Vector3, radius: float) -> void:
	var root := Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = at
	flipbook(&"explosion", at + Vector3.UP * radius * 0.3, radius * 1.5, 1.3)
	for i in 2:
		var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * radius * 0.35
		flipbook(&"explosion", at + off + Vector3.UP * radius * 0.25, radius * 0.9, 1.1, Color.WHITE, false, false,
				0.06 + 0.06 * i)
	flipbook(&"smoke", at + Vector3.UP * radius * 0.45, radius * 1.4, 1.6, Color(0.5, 0.48, 0.46, 0.65), false, false, 0.2)
	_burst(at + Vector3.UP * 0.3, Vector3.UP, Color(1.0, 0.75, 0.35), 24, 80.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = radius * 2.5
	root.add_child(light)
	light.position.y = 1.0
	light.create_tween().tween_property(light, "light_energy", 0.0, 0.4).from(6.0)
	bullet_hole(at + Vector3.UP * 0.02, Vector3.UP)
	_holes[(_next_hole - 1 + HOLE_POOL) % HOLE_POOL].size = Vector3(radius * 0.8, 0.5, radius * 0.8)
	Sfx.play(&"explosion_big", at)
	shake(0.45)
	get_tree().create_timer(2.6).timeout.connect(root.queue_free)


## Короткая белая вспышка в точке попадания по врагу — «тычок» пули.
func impact(at: Vector3, dir: Vector3, tint := Color(1, 0.92, 0.85)) -> void:
	if clean_combat: return
	if _impact_flashes.is_empty():
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = preload("res://assets/vfx/spark_01.png")
		mat.vertex_color_use_as_albedo = false
		var quad := QuadMesh.new()
		quad.size = Vector2(0.35, 0.35)
		quad.material = mat
		for i in 12:
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = mat.duplicate()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			add_child(mi)
			_impact_flashes.append(mi)
	var mi := _impact_flashes[_next_impact]
	_next_impact = (_next_impact + 1) % _impact_flashes.size()
	mi.global_position = at - dir.normalized() * 0.1
	(mi.material_override as StandardMaterial3D).albedo_color = tint
	mi.visible = true
	mi.scale = Vector3.ONE * randf_range(0.8, 1.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.2, 0.07)
	tw.tween_callback(func() -> void: mi.visible = false)


func _make_flash_texture() -> Texture2D:
	var t := GradientTexture2D.new()
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 0.8, 0.6, 0))
	t.gradient = g
	return t


## Искры от попадания в стену или ящик.
func sparks(at: Vector3, normal: Vector3) -> void:
	if clean_combat: return
	_burst(at, normal, Color(1.0, 0.8, 0.4), 6, 60.0)
	flipbook(&"spark", at + normal * 0.08, randf_range(0.35, 0.5), 0.22, Color(1.0, 0.85, 0.6), false, false)


func _burst(at: Vector3, dir: Vector3, color: Color, amount: int, spread: float) -> void:
	var p := _emitters[_next_emitter]
	_next_emitter = (_next_emitter + 1) % _emitters.size()
	p.global_position = at
	if dir.length() > 0.01:
		p.look_at(at + dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT)
	var m := p.process_material as ParticleProcessMaterial
	m.color = color
	m.spread = spread
	p.amount = amount
	p.restart()
	p.emitting = true


## Всплывающая цифра урона: подлетает вверх и гаснет. dir — откуда летела пуля:
## при дугах цифра отлетает дальше по ходу выстрела, чуть вбок.
func number(at: Vector3, value: float, color := Color(1, 1, 1), big := false, dir := Vector3.ZERO) -> void:
	if not damage_numbers or value < 0.5:
		return
	var l := _labels[_next_label]
	_next_label = (_next_label + 1) % _labels.size()
	l.text = str(roundi(value))
	l.modulate = color
	l.font_size = 30 if big else 20
	l.global_position = at + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.2, 0.2))
	l.visible = true
	l.scale = Vector3.ONE * 1.25
	var tween := l.create_tween().set_parallel()
	if not number_arcs:
		tween.tween_property(l, "scale", Vector3.ONE, 0.12)
		tween.tween_property(l, "global_position", l.global_position + Vector3(0, 0.7, 0), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
		tween.chain().tween_callback(func(): l.visible = false)
		return
	# Вбок: по ходу выстрела с небольшим случайным разбросом; без направления — случайно.
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length_squared() < 0.01:
		flat = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	flat = flat.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	var side := flat * number_arc_side * randf_range(0.7, 1.1)
	var height := number_arc_height * (1.2 if big else 1.0)
	# «Хлопок» при появлении: немного больше нужного и пружинит к обычному размеру.
	l.scale = Vector3.ONE * (1.6 if big else 1.4)
	tween.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_number_arc.bind(l, l.global_position, side, height), 0.0, 1.0, number_arc_time)
	tween.tween_property(l, "modulate:a", 0.0, number_arc_time * 0.4).set_delay(number_arc_time * 0.6)
	tween.chain().tween_callback(func(): l.visible = false)


## Точка дуги цифры: t от 0 до 1. Взлёт быстрый, вершина около середины, к концу цифра опускается.
func _number_arc(t: float, l: Label3D, start: Vector3, side: Vector3, height: float) -> void:
	var e := 1.0 - pow(1.0 - t, 2.0)
	var up := height * (2.4 * e - 1.6 * e * e)
	l.global_position = start + side * e + Vector3.UP * up


## Повышение уровня: золотая волна по полу, столб света и искры вверх вокруг персонажа.
func level_up(target: Node3D) -> void:
	var root := Node3D.new()
	target.add_child(root)
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold.albedo_color = Color(1.0, 0.82, 0.35, 0.9)
	# Кольцо-волна.
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.material = gold
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.position.y = 0.1
	ring.scale = Vector3.ONE * 0.2
	root.add_child(ring)
	# Столб света.
	var beam_mat := gold.duplicate() as StandardMaterial3D
	beam_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.35)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.75
	cyl.height = 5.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.material = beam_mat
	var beam := MeshInstance3D.new()
	beam.mesh = cyl
	beam.position.y = 2.5
	root.add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 6.0
	light.omni_range = 7.0
	light.position.y = 1.5
	root.add_child(light)
	# Золотые искры вверх.
	_burst(target.global_position + Vector3.UP * 0.3, Vector3.UP, Color(1.0, 0.85, 0.35), 24, 35.0)
	var tween := root.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * 4.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(gold, "albedo_color:a", 0.0, 0.7)
	tween.tween_property(beam_mat, "albedo_color:a", 0.0, 1.4).set_delay(0.3)
	tween.tween_property(light, "light_energy", 0.0, 1.4)
	tween.chain().tween_callback(root.queue_free)
	shake(0.25)


## Тряска камеры (0.1 — лёгкая, 0.5 — сильная).
func shake(strength: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent().has_method("add_shake"):
		camera.get_parent().add_shake(strength)


@export var muzzle_pool_size := 20
var _shotgun_blasts: Array[MeshInstance3D] = []
var _next_shotgun_blast := 0

## Одна короткая вспышка дробового выстрела, без летящего веера светящихся дробинок.
func shotgun_blast(at: Vector3, direction: Vector3, tint: Color) -> void:
	if clean_combat: return
	if _shotgun_blasts.is_empty():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points := [Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0.52, 0, -0.95), Vector3(-0.52, 0, -0.95)]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_color(Color(1, 0.8, 0.45, 0.5) if index < 2 else Color(1, 0.5, 0.15, 0.0))
			surface.add_vertex(points[index])
		var mesh := surface.commit()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for i in 4:
			var part := MeshInstance3D.new()
			part.mesh = mesh
			part.material_override = mat.duplicate()
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.visible = false
			add_child(part)
			_shotgun_blasts.append(part)
	var flash := _shotgun_blasts[_next_shotgun_blast]
	_next_shotgun_blast = (_next_shotgun_blast + 1) % _shotgun_blasts.size()
	flash.global_transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), at)
	flash.scale = Vector3.ONE
	flash.visible = true
	(flash.material_override as StandardMaterial3D).albedo_color = tint.lightened(0.3)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3(1.2, 1, 0.6), 0.065)
	tween.tween_callback(func() -> void: flash.visible = false)
var _muzzles: Array[Node3D] = []
var _muzzle_next := 0
const MUZZLE_PICTURES := [preload("res://assets/vfx/muzzle_01.png"), preload("res://assets/vfx/muzzle_02.png"), preload("res://assets/vfx/muzzle_03.png")]

## Вспышка: два пересекающихся лепестка пламени, белое ядро и короткий свет на окружении.
func muzzle(at: Vector3, direction: Vector3, strength := 1.0, tint := Color(1, 0.66, 0.28), energy := 4.0) -> void:
	if direction.length_squared() < 0.001:
		return
	if _muzzles.is_empty():
		_build_muzzles()
	var root := _muzzles[_muzzle_next]
	_muzzle_next = (_muzzle_next + 1) % _muzzles.size()
	if root.has_meta("tween"):
		var old: Tween = root.get_meta("tween")
		if old != null and old.is_valid():
			old.kill()
	root.global_transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), at)
	root.scale = Vector3.ONE * strength
	root.visible = true
	for name in ["Flame", "Cross"]:
		var part := root.get_node(name) as MeshInstance3D
		var mat := part.material_override as StandardMaterial3D
		mat.albedo_color = tint * 2.2
		mat.albedo_texture = MUZZLE_PICTURES.pick_random()
	var light := root.get_node("Light") as OmniLight3D
	light.light_color = tint.lightened(0.2)
	light.light_energy = energy
	var tw := root.create_tween().set_parallel()
	root.set_meta("tween", tw)
	tw.tween_property(root, "scale", Vector3.ONE * strength * 0.35, 0.055)
	tw.tween_property(light, "light_energy", 0.0, 0.07)
	tw.chain().tween_callback(func() -> void: root.visible = false)

func _build_muzzles() -> void:
	for i in muzzle_pool_size:
		var root := Node3D.new()
		add_child(root)
		root.visible = false
		for name in ["Flame", "Cross", "Core"]:
			var mi := MeshInstance3D.new()
			mi.name = name
			var quad := QuadMesh.new()
			quad.size = Vector2(0.20, 0.54) if name != "Core" else Vector2(0.18, 0.18)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = Color(2.0, 1.7, 1.2)
			if name == "Core":
				mat.albedo_texture = preload("res://assets/vfx/star_04.png")
				mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			else:
				mi.position.z = -0.15
				mi.basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP) if name == "Flame" else Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
			mi.mesh = quad
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		var light := OmniLight3D.new()
		light.name = "Light"
		light.omni_range = 4.5
		light.shadow_enabled = false
		root.add_child(light)
		_muzzles.append(root)
