extends Node3D
## Световой столб над ценной добычей и предметами заданий (как в PoE 2): тонкий светящийся луч вверх,
## мягкое пятно на полу, лёгкая пульсация. Видно издалека, сквозь сумрак.

@export var color := Color(1.0, 0.85, 0.35)
@export var height := 7.0
@export var width := 0.12

static var _meshes := {}
var _mat: StandardMaterial3D
var _time := randf() * 10.0


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_color = color
	var beam := MeshInstance3D.new()
	beam.mesh = _beam_mesh()
	beam.material_override = _mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.scale = Vector3(width / 0.1, height, width / 0.1)
	add_child(beam)
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	glow.mesh = quad
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_texture = preload("res://assets/vfx/circle_05.png")
	gm.albedo_color = Color(color, 0.6)
	glow.material_override = gm
	glow.rotation.x = -PI / 2
	glow.position.y = 0.03
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)


## Столб: две скрещённые полосы, яркие у пола, к верху гаснут (цвет вершин).
static func _beam_mesh() -> Mesh:
	if _meshes.has("beam"):
		return _meshes.beam
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3(0.05, 0, 0), Vector3(0, 0, 0.05)]:
		var bottom := Color(1, 1, 1, 0.9)
		var top := Color(1, 1, 1, 0.0)
		var p := [-axis, axis, axis + Vector3.UP, -axis + Vector3.UP]
		var c := [bottom, bottom, top, top]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(c[i])
			st.add_vertex(p[i])
	_meshes.beam = st.commit()
	return _meshes.beam


func _process(delta: float) -> void:
	_time += delta
	_mat.albedo_color = Color(color, 0.75 + 0.25 * sin(_time * 2.5))
