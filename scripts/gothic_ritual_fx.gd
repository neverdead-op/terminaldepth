extends Node3D
## Самостоятельный визуальный слой. Не наносит урон, не создаёт врагов и не пишет сохранения.

const SIGIL := preload("res://assets/shaders/gothic_sigil.gdshader")
const MIST := preload("res://assets/shaders/gothic_ground_mist.gdshader")
const CRYSTAL := preload("res://assets/shaders/gothic_crystal_sprite.gdshader")

@export var radius := 2.6
@export var effect_color := Color(0.85, 0.08, 0.04)
@export_range(0.0, 4.0) var intensity := 1.0
@export_range(0.0, 3.0) var speed := 1.0
@export var active := true
@export var mist_enabled := true

var _materials: Array[ShaderMaterial] = []
var _mist_mesh: MeshInstance3D
var _light: OmniLight3D
var _clock := 0.0
var _activation := 0.0
var _burst := 1.0
var _flash := 0.0
var _crystal_sprite: Sprite3D


func _ready() -> void:
	_add_plane(SIGIL, radius * 2.0, 0.08)
	_mist_mesh = _add_plane(MIST, radius * 2.4, 0.14)
	_light = OmniLight3D.new()
	_light.position.y = 0.8
	_light.omni_range = radius * 1.7
	_light.shadow_enabled = false
	add_child(_light)


## Накладывает свечение только на красные участки отдельного спрайта.
func bind_crystal(sprite: Sprite3D) -> void:
	_crystal_sprite = sprite
	var material := ShaderMaterial.new()
	material.shader = CRYSTAL
	material.set_shader_parameter("source_texture", sprite.texture)
	sprite.material_override = material
	_materials.append(material)


## Однократная расходящаяся волна; её можно вызвать при активации или разрушении.
func pulse() -> void:
	_burst = 0.0
	_flash = 1.0


func _add_plane(shader: Shader, diameter: float, height: float) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * diameter
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = material
	instance.position.y = height
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_materials.append(material)
	return instance


func _process(delta: float) -> void:
	_clock += delta * speed
	_activation = move_toward(_activation, 1.0 if active else 0.0, delta * 1.4)
	_burst = minf(1.0, _burst + delta * 0.8 * speed)
	_flash = maxf(0.0, _flash - delta * 2.0)
	for material in _materials:
		material.set_shader_parameter("effect_time", _clock)
		material.set_shader_parameter("activation", _activation)
		material.set_shader_parameter("intensity", intensity)
		if material.shader == MIST:
			material.set_shader_parameter("effect_color", Color(0.3, 0.25, 0.31))
		else:
			material.set_shader_parameter("effect_color", effect_color)
		if material.shader == SIGIL:
			material.set_shader_parameter("burst", _burst)
		elif material.shader == CRYSTAL:
			material.set_shader_parameter("flash", _flash)
			if is_instance_valid(_crystal_sprite):
				material.set_shader_parameter("sprite_tint", _crystal_sprite.modulate)
	_mist_mesh.visible = mist_enabled and (_activation > 0.001)
	_light.light_color = effect_color
	_light.light_energy = intensity * (_activation * (0.55 + 0.15 * sin(_clock * 2.1)) + _flash)
