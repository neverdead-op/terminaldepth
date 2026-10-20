extends Node3D
## Снаряд врага (кислотный плевок). Летит прямо, попадание проверяется лучом.
## Бьёт игрока, разбивается о стены и закрытые двери. Плевков мало, поэтому без пула.

const HIT_MASK := 1 | 2 | 16  # стены, игрок, двери

static var _mesh: Mesh

var _velocity := Vector3.ZERO
var _damage := 0.0
var _life := 3.0


static var _meshes := {}

var _element := &"acid"
var _color := Color(0.45, 1.0, 0.15)
## Пуля робота: вытянутый светящийся трассер вместо шара.
var _bullet := false


static func spawn(parent: Node, from: Vector3, to: Vector3, speed: float, damage: float,
		element := &"acid", color := Color(0.45, 1.0, 0.15), bullet := false) -> void:
	var p := new()
	p._element = element
	p._color = color
	p._bullet = bullet
	parent.add_child(p)
	p.global_position = from
	var dir := to - from
	dir.y = 0.0
	p._velocity = dir.normalized() * speed
	p._damage = damage
	if p._velocity.length() > 0.1:
		p.look_at(p.global_position + p._velocity, Vector3.UP)


func _ready() -> void:
	var key := [_color, _bullet]
	if not _meshes.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = _color
		material.emission_enabled = true
		material.emission = _color
		material.emission_energy_multiplier = 4.0
		if _bullet:
			_meshes[key] = _tracer(_color, 0.035, 1.1)
		else:
			# Сгусток (кислота, разряд): яркое ядро + светящийся хвост — читается так же, как пули.
			_meshes[key] = _tracer(_color, 0.09, 0.9)
	var visual := MeshInstance3D.new()
	visual.mesh = _meshes[key]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity, Vector3.UP)
	# Ядро сгустка — светящаяся точка (billboard).
	var core := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (0.12 if _bullet else 0.34)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = preload("res://assets/vfx/circle_05.png")
	m.albedo_color = _color.lightened(0.3)
	q.material = m
	core.mesh = q
	add_child(core)


## След-трассер: две скрещённые полосы, голова яркая, хвост гаснет (как у пуль игрока).
static func _tracer(color: Color, w: float, length: float) -> Mesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head := Color(color.lightened(0.6), 1.0)
	var tail := Color(color, 0.0)
	for axis in [Vector3(w, 0, 0), Vector3(0, w, 0)]:
		# Голова — впереди (−Z), хвост тянется назад (+Z).
		var p := [-axis + Vector3(0, 0, -0.05), axis + Vector3(0, 0, -0.05), axis + Vector3(0, 0, length),
				-axis + Vector3(0, 0, length)]
		var c := [head, head, tail, tail]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(c[i])
			st.add_vertex(p[i])
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	return mesh


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("take_damage") and hit.collider.is_in_group("player"):
			hit.collider.take_damage(_damage, _element)
		Fx.impact(hit.position, _velocity, _color)
		if _bullet and not hit.collider.is_in_group("player"):
			Fx.sparks(hit.position, hit.normal)
			Fx.bullet_hole(hit.position, hit.normal)
		if not _bullet:
			Sfx.play(&"acid_splash" if _element == &"acid" else &"zap", hit.position)
			Fx.flipbook(&"spark", hit.position, 0.9, 0.25, _color)
		queue_free()
		return
	global_position = to
	_life -= delta
	if _life <= 0.0:
		queue_free()
