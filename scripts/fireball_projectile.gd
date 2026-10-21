extends Node3D
## Огненный шар: авторский атлас 6×4, движение и непрерывная проверка попадания.

const TEXTURE := preload("res://assets/vfx/fireball/annomotion_fireball.png")
var direction := Vector3.FORWARD
var speed := 18.0
var damage := 70.0
var remaining := 24.0
var source: Node3D
var _sprite: Sprite3D
var _age := 0.0
var _material: ShaderMaterial

func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = TEXTURE
	_sprite.hframes = 6
	_sprite.vframes = 4
	_sprite.pixel_size = 0.008
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = false
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/vfx/fireball/fireball.gdshader")
	_material.set_shader_parameter("fire_texture", TEXTURE)
	_sprite.material_override = _material
	add_child(_sprite)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.28, 0.04)
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)

func _process(delta: float) -> void:
	_age += delta
	_sprite.frame = int(_age * 24.0) % 24
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var screen_direction := camera.unproject_position(global_position + direction) - camera.unproject_position(global_position)
		_material.set_shader_parameter("screen_rotation", -screen_direction.angle())

func _physics_process(delta: float) -> void:
	var distance := minf(speed * delta, remaining)
	var next := global_position + direction * distance
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | 4 | 16)
	if is_instance_valid(source) and source is CollisionObject3D:
		query.exclude = [source.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var target: Object = hit.collider
		if target.has_method("take_damage"):
			target.take_damage(damage, &"fire", source)
		Fx.explosion(global_position, 0.65)
		queue_free()
		return
	global_position = next
	remaining -= distance
	if remaining <= 0.0:
		queue_free()
