extends Node3D
## Полоска здоровья над врагом. Всегда повёрнута к камере и видна сквозь стены.
## Использование: health_bar.set_ratio(hp / max_hp)

@export var width := 1.0
@export var height := 0.08
@export var fill_color := Color(0.85, 0.12, 0.1)
@export var back_color := Color(0.0, 0.0, 0.0, 0.75)
## Прятать полоску, пока здоровье полное (удобно для толп мелких врагов).
@export var hide_when_full := false
## «Шлейф» урона: после удара потерянный кусок остаётся светлым chip_hold секунд и стекает со скоростью chip_speed (доля полоски в секунду).
@export var chip_color := Color(1.0, 0.86, 0.55)
@export var chip_hold := 0.35
@export var chip_speed := 0.9

## Общие материалы и меши для всех полосок — сотня врагов не создаёт сотни копий.
static var _materials := {}
static var _quads := {}

var _fill: MeshInstance3D
var _chip: MeshInstance3D
var _ratio := 1.0
var _chip_ratio := 1.0
var _chip_wait := 0.0


func _ready() -> void:
	_make_quad(back_color, Vector2(width + 0.06, height + 0.06), 0)
	_chip = _make_quad(chip_color, Vector2(width, height), 1)
	_chip.visible = false
	_fill = _make_quad(fill_color, Vector2(width, height), 2)
	preload("res://scripts/health_bar_frame.gd").attach(self, Vector2(width, height), 3)
	visible = not hide_when_full


func _process(delta: float) -> void:
	if not visible:
		return
	face_camera(self)
	if _chip_ratio > _ratio:
		_chip_wait -= delta
		if _chip_wait <= 0.0:
			_chip_ratio = maxf(_ratio, _chip_ratio - chip_speed * delta)
		_place(_chip, _chip_ratio)
	_chip.visible = _chip_ratio > _ratio + 0.002


## Вся полоска поворачивается целиком: сдвиг заполнения идёт по экрану, не по оси врага.
static func face_camera(bar: Node3D) -> void:
	var camera := bar.get_viewport().get_camera_3d()
	if camera != null:
		bar.global_basis = camera.global_basis.orthonormalized()


## Учитываем высоту актуальной модели, включая заменённые модели и крупных врагов.
func fit_above_visual(visual: Node3D, clearance := 0.2) -> void:
	var top := position.y - clearance
	var inv := get_parent_node_3d().global_transform.affine_inverse()
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible: continue
		var bounds: AABB = (inv * mesh.global_transform) * mesh.get_aabb()
		top = maxf(top, bounds.end.y)
	position.y = maxf(position.y, top + clearance)


func set_ratio(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	visible = ratio > 0.0 and (not hide_when_full or ratio < 1.0)
	_fill.visible = ratio > 0.0
	if ratio < _ratio:
		# Новый удар: шлейф начинается от прежнего значения (если не стёк — копится дальше).
		_chip_ratio = maxf(_chip_ratio, _ratio)
		_chip_wait = chip_hold
	else:
		_chip_ratio = ratio
	_ratio = ratio
	_place(_fill, ratio)
	_place(_chip, _chip_ratio)
	_chip.visible = _chip_ratio > _ratio + 0.002
	# Убитого врага прячем только после того, как шлейф стечёт — видно последний удар.
	if ratio <= 0.0 and _chip_ratio > 0.0:
		visible = true


## Сдвигаем полоску, чтобы она «убывала» справа налево.
func _place(bar: MeshInstance3D, ratio: float) -> void:
	bar.scale.x = maxf(ratio, 0.001)
	bar.position.x = -(1.0 - ratio) * width * 0.5


func _make_quad(color: Color, size: Vector2, priority: int) -> MeshInstance3D:
	var material_key := "%s|%d" % [color, priority]
	if not _materials.has(material_key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		material.no_depth_test = true
		material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		material.render_priority = priority
		_materials[material_key] = material
	if not _quads.has(size):
		var quad := QuadMesh.new()
		quad.size = size
		_quads[size] = quad

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _quads[size]
	mesh_instance.material_override = _materials[material_key]
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance
