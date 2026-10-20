extends Node3D
## Dynamic bowstring and nocked arrow, aligned by BowPose after arm animation.
var draw := 0.0
var nocked := true
var _string: MeshInstance3D
var _arrow: MeshInstance3D
var _material: StandardMaterial3D
var _limbs: Array[MeshInstance3D] = []

func _ready() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if mesh.get_blend_shape_count() > 0: _limbs.append(mesh)
	_string = MeshInstance3D.new()
	_string.name = "Bowstring"
	add_child(_string)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.50, 0.40, 0.25)
	_material.roughness = 1.0
	_string.material_override = _material
	_arrow = MeshInstance3D.new()
	_arrow.name = "NockedArrow"
	_arrow.mesh = preload("res://scripts/wood_arrow_mesh.gd").make_arrow()
	add_child(_arrow)
	update_draw(0.0, false)

func update_draw(amount: float, show_arrow: bool) -> void:
	draw = clampf(amount, 0, 1)
	nocked = show_arrow
	if _string == null: return
	var middle := Vector3(draw * 0.13, draw * 0.08, 0.196 + draw * 0.274)
	update_pose(middle, show_arrow, draw)

func update_pose(middle: Vector3, show_arrow: bool, amount: float) -> void:
	if _string == null: return
	draw = amount
	nocked = show_arrow
	for limb in _limbs: limb.set_blend_shape_value(0, draw)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var tip_y := .64 * (1.0 - .035 * draw)
	var tip_z := .196 + .035 * draw
	for p in [Vector3(0, tip_y, tip_z), middle, middle, Vector3(0, -tip_y, tip_z)]: mesh.surface_add_vertex(p)
	mesh.surface_end()
	_string.mesh = mesh
	_arrow.visible = show_arrow
	var direction := (-middle).normalized()
	_arrow.basis = Basis.looking_at(direction, Vector3.UP)
	_arrow.position = middle + direction * 0.30
