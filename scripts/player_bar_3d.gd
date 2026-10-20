extends Node3D
## Полоска над головой игрока: здоровье (красная), поверх — слой Energy Shield (голубой, тратится первым).
## Повёрнуты к камере и видны сквозь стены.

@export var width := 0.9
@export var height := 0.07

var player: Node
var _hp_fill: MeshInstance3D
var _hp_chip: MeshInstance3D
var _hp_ratio := 1.0
var _chip_ratio := 1.0
var _chip_wait := 0.0
var _es_fill: MeshInstance3D
var _es_back: MeshInstance3D


func _ready() -> void:
	_quad(Color(0, 0, 0, 0.75), Vector2(width + 0.05, height + 0.04), 0.0, 0)
	_hp_chip = _quad(Color(1.0, 0.86, 0.55), Vector2(width, height), 0.0, 1)
	_hp_fill = _quad(Color(0.85, 0.12, 0.12), Vector2(width, height), 0.0, 2)
	_es_back = _quad(Color(0, 0, 0, 0.0), Vector2(0.01, 0.01), 0.0, 0)
	_es_fill = _quad(Color(0.4, 0.78, 1.0, 0.75), Vector2(width, height), 0.0, 3)
	preload("res://scripts/health_bar_frame.gd").attach(self, Vector2(width, height), 6)


func _process(_delta: float) -> void:
	if player == null:
		return
	preload("res://scripts/health_bar_3d.gd").face_camera(self)
	visible = not player.is_dead()
	# Шлейф урона: потерянное здоровье светлеет и стекает за полоской.
	var ratio := clampf(player.hp / maxf(player.max_hp, 1.0), 0.0, 1.0)
	if ratio < _hp_ratio:
		_chip_ratio = maxf(_chip_ratio, _hp_ratio)
		_chip_wait = 0.35
	elif ratio > _chip_ratio:
		_chip_ratio = ratio
	_hp_ratio = ratio
	if _chip_ratio > ratio:
		_chip_wait -= _delta
		if _chip_wait <= 0.0:
			_chip_ratio = maxf(ratio, _chip_ratio - 0.9 * _delta)
	_set_fill(_hp_chip, _chip_ratio, _chip_ratio > ratio + 0.002)
	_set_fill(_hp_fill, ratio, true)
	var has_es: bool = player.max_es > 0.0
	_es_back.visible = has_es
	_set_fill(_es_fill, player.es / player.max_es if has_es else 0.0, has_es)


func _set_fill(fill: MeshInstance3D, ratio: float, show: bool) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	fill.visible = show and ratio > 0.0
	fill.scale.x = maxf(ratio, 0.001)
	fill.position.x = -(1.0 - ratio) * width * 0.5


func _quad(color: Color, quad_size: Vector2, y: float, priority: int) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.render_priority = priority + 2
	var quad := QuadMesh.new()
	quad.size = quad_size
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = material
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
