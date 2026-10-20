extends Enemy
## Ползун — мелкий быстрый враг, берёт числом. Шесть лап семенят при беге.
## Поведение — общее (enemy.gd): спит, просыпается, бежит, замах, укус.

static var _meshes := {}

var _body_mesh: MeshInstance3D
var _legs: Array[Node3D] = []


func _build_visual() -> void:
	if humanoid_model != null:
		super()
		return
	if _meshes.is_empty():
		var skin := _material(Color(0.22, 0.24, 0.12), 0.0, 0.45)
		var eye := _material(Color(1.0, 0.4, 0.05), 3.0)
		var body := SphereMesh.new()
		body.radius = 0.5
		body.height = 1.0
		body.material = skin
		var head := SphereMesh.new()
		head.radius = 0.25
		head.height = 0.4
		head.material = skin
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.06
		eye_mesh.height = 0.12
		eye_mesh.material = eye
		var leg := BoxMesh.new()
		leg.size = Vector3(0.07, 0.07, 0.55)
		leg.material = skin
		_meshes = {"body": body, "head": head, "eye": eye_mesh, "leg": leg}

	_body_mesh = _mesh(_meshes.body, Vector3(0, 0.38, 0.05), Vector3(0.75, 0.5, 1.0))
	_mesh(_meshes.head, Vector3(0, 0.38, -0.5))
	_mesh(_meshes.eye, Vector3(0.1, 0.45, -0.68), Vector3.ONE, null, false)
	_mesh(_meshes.eye, Vector3(-0.1, 0.45, -0.68), Vector3.ONE, null, false)
	for i in 6:
		var side := 1.0 if i % 2 == 0 else -1.0
		var row := floorf(i / 2.0) - 1.0
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.25, 0.32, row * 0.28)
		_visual.add_child(pivot)
		var leg := _mesh(_meshes.leg, Vector3(side * 0.22, -0.12, 0), Vector3.ONE, pivot, false)
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leg.rotation = Vector3(0, deg_to_rad(90.0 + row * 25.0 * side), deg_to_rad(-30.0 * side))
		_legs.append(pivot)


## Лапы семенят тем быстрее, чем быстрее бежит ползун; туловище слегка подпрыгивает.
func _animate(delta: float, speed: float) -> void:
	if humanoid_model != null:
		super(delta, speed)
		return
	_anim_time += delta * (4.0 + speed * 3.0)
	var amount := clampf(speed / move_speed, 0.0, 1.0)
	for i in _legs.size():
		var phase := _anim_time + (PI if i % 2 == 0 else 0.0) + floorf(i / 2.0) * 0.8
		_legs[i].rotation = Vector3(sin(phase) * 0.6 * amount, 0, 0)
	_body_mesh.position.y = 0.38 + absf(sin(_anim_time)) * 0.05 * amount
