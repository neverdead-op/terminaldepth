extends Node3D
## Reusable modest modular village pieces; all materials react to real scene lighting.
const BRICK = preload("res://assets/textures/victorian_village/stylized_v2/brick_albedo.png")
const PLASTER = preload("res://assets/textures/victorian_village/stylized_v2/plaster_albedo.png")
const SLATE = preload("res://assets/textures/victorian_village/stylized_v2/slate_albedo.png")
var houses := 0
@export var use_gothic_houses := false
var _lanterns: Array[OmniLight3D] = []
var _time := 0.0

func material(color: Color, texture: Texture2D = null, scale_m := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = texture
	m.roughness = 0.9
	if texture:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / scale_m
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func block(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi

func house(at: Vector3, yaw := 0.0, width := 5.0, depth := 6.0, tavern := false) -> Node3D:
	houses += 1
	# Two sample buildings at the entrance; remaining houses stay for direct comparison.
	if not tavern and (use_gothic_houses or houses <= 2):
		var sample: Node3D = preload("res://assets/buildings/gothic_house/gothic_house.tscn").instantiate()
		sample.name = "GothicHouseSample%d" % houses
		sample.position = at
		sample.rotation.y = yaw
		sample.scale = Vector3(width / 5.4, 0.85, depth / 6.4)
		add_child(sample)
		return sample
	var root := Node3D.new()
	root.name = "TavernExterior" if tavern else "VillageHouse%d" % houses
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var brick := material(Color.WHITE, BRICK, 3)
	var plaster := material(Color(0.8, 0.81, 0.76), PLASTER, 4)
	var timber := material(Color(0.105, 0.075, 0.065))
	var roof := material(Color(0.8, 0.85, 0.9), SLATE, 3)
	var h := 4.2 if tavern else 3.2
	block(root, Vector3(0, 0.55, 0), Vector3(width, 1.1, depth), brick)
	block(root, Vector3(0, (h + 1.1) * 0.5, 0), Vector3(width, h - 1.1, depth), plaster)
	for x in [-width * 0.5, 0.0, width * 0.5]:
		block(root, Vector3(x, h * 0.5, depth * 0.5 + 0.03), Vector3(0.15, h, 0.14), timber)
	block(root, Vector3(0, h, depth * 0.5 + 0.05), Vector3(width + 0.25, 0.18, 0.2), timber)
	var prism := PrismMesh.new()
	prism.size = Vector3(width + 0.7, 2.0, depth + 0.6)
	var top := MeshInstance3D.new()
	top.mesh = prism
	top.material_override = roof
	top.position.y = h + 1
	root.add_child(top)
	block(root, Vector3(width * 0.3, h + 1.5, -depth * 0.22), Vector3(0.6, 2.2, 0.65), brick)
	var glass := material(Color(0.85, 0.48, 0.17))
	glass.emission_enabled = true
	glass.emission = Color(1, 0.48, 0.15)
	glass.emission_energy_multiplier = 0.65
	for x in [-width * 0.3, width * 0.3]:
		block(root, Vector3(x, 2, depth * 0.5 + 0.07), Vector3(1.1, 1.3, 0.12), timber)
		block(root, Vector3(x, 2, depth * 0.5 + 0.14), Vector3(0.9, 1.1, 0.06), glass)
		block(root, Vector3(x, 2, depth * 0.5 + 0.2), Vector3(0.06, 1.2, 0.07), timber)
		block(root, Vector3(x, 2, depth * 0.5 + 0.2), Vector3(1, 0.06, 0.07), timber)
	block(root, Vector3(0, 1.1, depth * 0.5 + 0.12), Vector3(1.1, 2.2, 0.2), timber)
	if tavern:
		var sign_board := block(root, Vector3(0, 3.3, depth * 0.5 + 0.4), Vector3(5.5, 0.8, 0.2), timber)
		var label := Label3D.new()
		label.text = "ПОСЛЕДНИЙ ОГОНЬ"
		label.font = Loc.TITLE_FONT
		label.font_size = 48
		label.pixel_size = 0.0025
		label.position.z = 0.12
		sign_board.add_child(label)
	return root

## show_model = false — только столб-преграда и свет (картинку фонаря ставит уровень).
func lantern(at: Vector3, energy := 2.2, show_model := true) -> void:
	if show_model:
		var model: Node3D = preload("res://assets/buildings/village_nature/gothic_lantern.glb").instantiate()
		model.position = at
		add_child(model)
		preload("res://scripts/village_materials.gd").apply(model)
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, 1.5, 0)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.23
	shape.height = 3
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 3.28, 0)
	light.light_color = Color(1, 0.66, 0.34)
	light.light_energy = energy
	light.omni_range = 9
	light.light_size = 0.22
	light.light_volumetric_fog_energy = 1.4
	light.set_meta("base_energy", energy)
	light.add_to_group("village_lamps")
	add_child(light)
	_lanterns.append(light)

func _process(delta: float) -> void:
	_time += delta
	for i in _lanterns.size():
		var lamp := _lanterns[i]
		var phase := i * 1.73
		lamp.light_energy = float(lamp.get_meta("base_energy")) * (1.0 + sin(_time * 2.1 + phase) * 0.035 + sin(_time * 3.7 + phase) * 0.018)
