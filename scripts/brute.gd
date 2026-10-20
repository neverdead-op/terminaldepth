extends Enemy
## Носитель — большой, медленный, бронированный. Долгий замах и тяжёлый удар по площади.
## Броня режет физический урон; кислота её снимает. При смерти лопается на ползунов.

## Насколько сильно трясёт камеру при ударе.
@export var slam_camera_dip := 0.25

static var _meshes := {}

var _body: MeshInstance3D
var _arms: Array[Node3D] = []


func _build_visual() -> void:
	if humanoid_model != null:
		super()
		return
	if _meshes.is_empty():
		var skin := _material(Color(0.32, 0.16, 0.14), 0.0, 0.6)
		var sac := _material(Color(0.5, 0.9, 0.25), 1.6)
		var eye := _material(Color(1.0, 0.85, 0.2), 3.0)
		var body := SphereMesh.new()
		body.radius = 0.5
		body.height = 1.0
		body.material = skin
		var limb := CapsuleMesh.new()
		limb.radius = 0.2
		limb.height = 1.2
		limb.material = skin
		var pustule := SphereMesh.new()
		pustule.radius = 0.16
		pustule.height = 0.32
		pustule.material = sac
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.07
		eye_mesh.height = 0.14
		eye_mesh.material = eye
		_meshes = {"body": body, "limb": limb, "pustule": pustule, "eye": eye_mesh}

	_body = _mesh(_meshes.body, Vector3(0, 1.25, 0.15), Vector3(1.7, 1.5, 1.6))
	_mesh(_meshes.body, Vector3(0, 1.1, -0.65), Vector3(0.75, 0.6, 0.7))  # голова, утопленная в плечи
	_mesh(_meshes.eye, Vector3(0.16, 1.2, -0.98), Vector3.ONE, null, false)
	_mesh(_meshes.eye, Vector3(-0.16, 1.2, -0.98), Vector3.ONE, null, false)
	# Светящиеся гнойники на спине — в них сидят ползуны.
	for p in [Vector3(0.4, 1.8, 0.4), Vector3(-0.35, 1.9, 0.2), Vector3(0.05, 1.65, 0.8), Vector3(-0.5, 1.5, 0.65)]:
		_mesh(_meshes.pustule, p, Vector3.ONE * randf_range(0.8, 1.3), null, false)
	# Ноги — короткие тумбы.
	for side in [-1.0, 1.0]:
		_mesh(_meshes.limb, Vector3(side * 0.45, 0.4, 0.2), Vector3(1.3, 0.7, 1.3))
	# Руки свисают почти до пола.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.85, 1.55, -0.2)
		_visual.add_child(shoulder)
		var arm := _mesh(_meshes.limb, Vector3(0, -0.6, 0), Vector3(1.4, 1.1, 1.4), shoulder)
		arm.rotation.z = side * 0.15
		_arms.append(shoulder)


func _animate(delta: float, speed: float) -> void:
	if humanoid_model != null:
		super(delta, speed)
		return
	_anim_time += delta * (2.0 + speed * 1.5)
	var amount := clampf(speed / maxf(move_speed, 0.1), 0.0, 1.0)
	_body.position.y = 1.25 + sin(_anim_time * 2.0) * 0.06 * (0.3 + amount)
	if _state != State.WINDUP:
		for i in _arms.size():
			_arms[i].rotation.x = sin(_anim_time + PI * i) * 0.35 * amount


## Замах: поднимает руки над головой.
func _on_windup() -> void:
	if humanoid_model != null:
		super()
		return
	var tween := create_tween().set_parallel()
	for arm in _arms:
		tween.tween_property(arm, "rotation:x", -2.6, attack_windup * 0.9).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_visual, "scale", Vector3(1.05, 1.1, 1.05), attack_windup * 0.9)


## Удар: руки с размаху в пол.
func _on_attack() -> void:
	if humanoid_model != null:
		super()
		return
	var tween := create_tween().set_parallel()
	for arm in _arms:
		tween.tween_property(arm, "rotation:x", 0.9, 0.08)
	tween.tween_property(_visual, "scale", Vector3(1.1, 0.85, 1.1), 0.08)
	tween.chain().tween_property(_visual, "scale", Vector3.ONE, 0.3)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent().has_method("add_dip"):
		camera.get_parent().add_dip(slam_camera_dip)
