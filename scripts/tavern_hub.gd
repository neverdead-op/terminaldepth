extends Node3D
## Таверна «Последний огонь». Наследует базу (hub.tscn): её стены, пол, прилавки и службы сохраняются,
## здесь только облик и наполнение. Остатки научно-фантастических пультов и шкафчиков убираются,
## вместо них — столы, полки, бочки, камин и знамёна.

const Kit := "res://assets/environment/victorian_kit/v1/"
const Threshold := "res://assets/environment/threshold_set/v1/"

@export_group("Облик")
## Тон досок пола (умножается на текстуру дуба).
@export var floor_tint := Color(0.5, 0.36, 0.26)
@export var wall_tint := Color(0.95, 0.9, 0.84)
@export var fire_energy := 3.2
@export var candle_energy := 0.9

var _arch: Node3D
var _fire_light: OmniLight3D
var _fire_glow: Array[MeshInstance3D] = []
var _candles: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	set_meta("tavern", true)
	_arch = preload("res://scripts/village_architecture.gd").new()
	_arch.name = "TavernFurnishings"
	add_child(_arch)
	for path in ["Models", "Moon", "HubFinishes"]:
		var node := get_node_or_null(path) as Node3D
		if node: node.visible = false
	var geometry := get_node("Geometry")
	# Прячем всё видимое базы, включая стеллажи-мультисетки.
	for mesh in geometry.find_children("*", "GeometryInstance3D", true, false):
		mesh.visible = false
	# Пульты, шкафчики и ящики базы (Prop1–9) в таверне не нужны: убираем вместе с их преградами.
	for prop in ["Prop1", "Prop2", "Prop3", "Prop4", "Prop5", "Prop6", "Prop8", "Prop9"]:
		var body := geometry.get_node_or_null(prop)
		if body: body.queue_free()
	var plaster := _wall_material(preload("res://assets/textures/level1_v3/wall_plaster_ruin_albedo.png"), 2.4, 0.04)
	var hearth_stone := _wall_material(preload("res://assets/textures/level1_v3/wall_dark_blocks_albedo.png"), 1.6, 0.0)
	var oak := _oak(Color(0.42, 0.28, 0.18), 1.6)
	var floor_oak := _oak(floor_tint, 2.2)
	for node in geometry.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if not shape.shape is BoxShape3D: continue
		var body := shape.get_parent() as Node3D
		if str(body.name) in ["Prop1", "Prop2", "Prop3", "Prop4", "Prop5", "Prop6", "Prop8", "Prop9"]: continue
		# Шкафы за торговцами — настоящие полки из набора, преграда базы остаётся.
		if body.name in [&"Prop11", &"Prop13"]:
			var shelf: Node3D = load(Kit + "shelf_dark.glb").instantiate()
			shelf.position = body.global_position + shape.position - Vector3(0, shape.shape.size.y * 0.5, 0)
			shelf.rotation.y = PI * 0.5
			shelf.scale = Vector3(shape.shape.size.z / 1.42, shape.shape.size.y / 1.9, 1.0)
			_arch.add_child(shelf)
			continue
		var mat: Material = oak if str(body.name).begins_with("Prop") else plaster
		if body.name == &"Floor": mat = floor_oak
		var visual_size: Vector3 = shape.shape.size
		var visual_at: Vector3 = shape.position
		# Передняя стена срезана, чтобы видеть зал сверху.
		if body.name == &"Wall2":
			visual_size.y = 0.45
			visual_at.y -= 1.275
		var visual: MeshInstance3D = _arch.block(body, visual_at, visual_size, mat)
		visual.basis = shape.basis
		# Тёмный деревянный карниз сверху стены: светлая штукатурка на гребне не бросается в глаза.
		if str(body.name).begins_with("Wall"):
			_arch.block(body, visual_at + Vector3(0, visual_size.y * 0.5 + 0.04, 0), visual_size * Vector3(1.0, 0.0, 1.0) + Vector3(0.12, 0.08, 0.12), _oak(Color(0.22, 0.14, 0.09), 1.6))
	_build_walls(oak)
	_build_hearth(hearth_stone, oak)
	_furnish(oak)
	# Службы (торговцы, верстак, склад): тот же дуб, NPC не трогаем.
	for service_name in ["Vendor", "VendorBases", "Workbench", "Stash"]:
		var service := get_node(service_name)
		var npc_model: Node3D = service.get("_model") if service_name != "Stash" else null
		for mesh in service.find_children("*", "MeshInstance3D", true, false):
			if npc_model != null and npc_model.is_ancestor_of(mesh): continue
			mesh.material_override = oak
	_light_room()
	# Летающая надпись с названием таверны убрана.


func _process(delta: float) -> void:
	_time += delta
	# Живой огонь: свет и языки пламени дышат неровно.
	var flicker := 1.0 + sin(_time * 7.3) * 0.08 + sin(_time * 13.1) * 0.05 + sin(_time * 2.2) * 0.06
	if _fire_light: _fire_light.light_energy = fire_energy * flicker
	for i in _fire_glow.size():
		_fire_glow[i].scale = Vector3.ONE * (0.9 + sin(_time * (5.0 + i * 1.7) + i) * 0.12)
	for i in _candles.size():
		_candles[i].light_energy = candle_energy * (1.0 + sin(_time * (9.0 + i) + i * 2.0) * 0.07)


func _wall_material(texture: Texture2D, tile: float, moss: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/village_wall.gdshader")
	mat.set_shader_parameter("base_tex", texture)
	mat.set_shader_parameter("moss_tex", preload("res://assets/textures/level1_v3/floor_moss_albedo.png"))
	mat.set_shader_parameter("tint", wall_tint)
	mat.set_shader_parameter("tile_meters", tile)
	mat.set_shader_parameter("moss_amount", moss)
	mat.set_shader_parameter("grime", 0.35)
	return mat


func _oak(tint: Color, tile: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/environment/victorian_kit/v1/textures/oak_light_albedo.png")
	mat.albedo_color = tint
	mat.roughness = 0.78
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / tile
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Деревянная обшивка внизу стен и балки-стойки.
func _build_walls(oak: Material) -> void:
	_arch.block(_arch, Vector3(0, 0.55, -5.96), Vector3(16, 1.1, 0.08), oak)
	_arch.block(_arch, Vector3(0, 1.12, -5.92), Vector3(16, 0.08, 0.16), oak)
	for x in [-7.96, 7.96]:
		_arch.block(_arch, Vector3(x, 0.55, 0), Vector3(0.08, 1.1, 12), oak)
		_arch.block(_arch, Vector3(x * 0.995, 1.12, 0), Vector3(0.16, 0.08, 12), oak)
		for z in [-4.5, 0.0, 4.5]:
			_arch.block(_arch, Vector3(x, 1.5, z), Vector3(0.24, 3, 0.3), oak)
	for x in [-4.5, 4.5]:
		_arch.block(_arch, Vector3(x, 1.5, -5.88), Vector3(0.3, 3, 0.24), oak)


## Камин у задней стены: кладка, топка, полка, поленья, огонь и плита перед ним.
func _build_hearth(stone: Material, oak: Material) -> void:
	var at := Vector3(-2.6, 0, -5.6)
	_arch.block(_arch, at + Vector3(0, 1.15, 0), Vector3(2.8, 2.3, 0.7), stone)
	_arch.block(_arch, at + Vector3(0, 0.6, 0.33), Vector3(1.5, 1.05, 0.06), _flat(Color(0.03, 0.018, 0.012)))
	_arch.block(_arch, at + Vector3(0, 2.36, 0.12), Vector3(3.1, 0.14, 0.95), oak)
	var floor_slab := _wall_material(preload("res://assets/textures/level1_v3/floor_root_flagstones_albedo.png"), 2.0, 0.0)
	_arch.block(_arch, at + Vector3(0, 0.02, 1.15), Vector3(3.2, 0.04, 1.4), floor_slab)
	for i in 3:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.09
		log_mesh.bottom_radius = 0.1
		log_mesh.height = 0.95
		var log_node := MeshInstance3D.new()
		log_node.mesh = log_mesh
		log_node.material_override = _flat(Color(0.16, 0.09, 0.05))
		log_node.position = at + Vector3((i - 1) * 0.12, 0.14 + (i % 2) * 0.1, 0.45)
		log_node.rotation = Vector3(0, 0, PI * 0.5 + (i - 1) * 0.25)
		_arch.add_child(log_node)
	for i in 3:
		var flame := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.75 - i * 0.15, 0.95 - i * 0.2)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		glow.albedo_texture = preload("res://assets/vfx/circle_05.png")
		glow.albedo_color = [Color(1.0, 0.35, 0.08, 0.8), Color(1.0, 0.6, 0.15, 0.85), Color(1.0, 0.9, 0.55, 0.9)][i]
		quad.material = glow
		flame.mesh = quad
		flame.position = at + Vector3(0, 0.45 + i * 0.05, 0.5)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arch.add_child(flame)
		_fire_glow.append(flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.22)
	_fire_light.light_energy = fire_energy
	_fire_light.omni_range = 9.0
	_fire_light.shadow_enabled = true
	_fire_light.position = at + Vector3(0, 0.9, 1.0)
	add_child(_fire_light)


## Расстановка зала. Центральный проход от входа к двери (x от −1 до 1) свободен;
## к торговцам слева, верстаку и складу справа подходы открыты.
func _furnish(oak: Material) -> void:
	# Круглый стол с тремя стульями.
	_model(Kit + "table_round_dark.glb", Vector3(2.7, 0, -0.6), 0.0, Vector3(1.4, 0.9, 1.4))
	for a in [0.4, 2.5, 4.4]:
		var seat := Vector3(2.7, 0, -0.6) + Vector3(cos(a), 0, sin(a)) * 1.05
		_model(Kit + "chair_dark.glb", seat, atan2(2.7 - seat.x, -0.6 - seat.z), Vector3(0.45, 1.0, 0.45))
	_candle(Vector3(2.7, 0.9, -0.6))
	# Длинный стол с табуретами.
	_model(Kit + "table_long.glb", Vector3(3.2, 0, 1.9), 0.0, Vector3(2.6, 0.9, 0.85))
	for x in [2.3, 3.2, 4.1]:
		for z in [1.25, 2.55]:
			_model(Kit + "stool_dark.glb", Vector3(x, 0, z), 0.0, Vector3(0.45, 0.5, 0.45))
	_candle(Vector3(2.8, 0.9, 1.9))
	_candle(Vector3(3.7, 0.9, 1.95))
	# Полки с посудой у задней стены.
	_model(Kit + "shelf_dark.glb", Vector3(2.0, 0, -5.73), 0.0, Vector3(1.4, 1.9, 0.5))
	_model(Kit + "shelf_dark.glb", Vector3(6.6, 0, -5.73), 0.0, Vector3(1.4, 1.9, 0.5))
	# Бочки и ящики в переднем левом углу и справа у входа.
	for at in [Vector3(-7.2, 0, 5.1), Vector3(-6.3, 0, 5.4), Vector3(-7.25, 0, 4.1)]:
		_model(Threshold + "barrel.glb", at, at.x, Vector3(0.85, 1.25, 0.85))
	_model(Threshold + "crate.glb", Vector3(-5.2, 0, 5.4), 0.3, Vector3(1.1, 1.1, 1.0))
	_model(Threshold + "crate.glb", Vector3(3.6, 0, 5.45), -0.2, Vector3(1.1, 1.1, 1.0))
	_model(Threshold + "barrel.glb", Vector3(4.8, 0, 5.5), 0.7, Vector3(0.85, 1.25, 0.85))
	# Лавка вдоль правой стены.
	_model(Threshold + "bench.glb", Vector3(7.45, 0, -0.4), PI * 0.5, Vector3(0.58, 0.82, 2.2))
	# Знамёна на боковых стенах.
	for spot in [[Vector3(-7.9, 2.85, -0.1), PI * 0.5], [Vector3(7.9, 2.85, -3.4), -PI * 0.5], [Vector3(7.9, 2.85, 2.6), -PI * 0.5]]:
		var banner: Node3D = load(Threshold + "red_banner.glb").instantiate()
		banner.position = spot[0]
		banner.rotation.y = spot[1]
		_arch.add_child(banner)


func _model(path: String, at: Vector3, yaw: float, block: Vector3) -> Node3D:
	var model: Node3D = load(path).instantiate()
	model.position = at
	model.rotation.y = yaw
	_arch.add_child(model)
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, block.y * 0.5, 0)
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = block
	shape.shape = box
	body.add_child(shape)
	_arch.add_child(body)
	return model


func _candle(at: Vector3) -> void:
	var wax := CylinderMesh.new()
	wax.top_radius = 0.035
	wax.bottom_radius = 0.04
	wax.height = 0.16
	var candle := MeshInstance3D.new()
	candle.mesh = wax
	candle.material_override = _flat(Color(0.86, 0.8, 0.66))
	candle.position = at + Vector3(0, 0.08, 0)
	_arch.add_child(candle)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.36)
	light.light_energy = candle_energy
	light.omni_range = 3.2
	light.position = at + Vector3(0, 0.3, 0)
	add_child(light)
	_candles.append(light)


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


## Тёплый свет таверны: камин, свечи, бра на стенах; лунный свет почти погашен.
func _light_room() -> void:
	for spot in [Vector3(-7.75, 2.1, -3.8), Vector3(-7.75, 2.1, 3.8), Vector3(7.75, 2.1, -1.8), Vector3(7.75, 2.1, 4.2), Vector3(4.5, 2.2, -5.75)]:
		_arch.block(_arch, spot, Vector3(0.14, 0.3, 0.14), _flat(Color(0.08, 0.07, 0.06)))
		var sconce := OmniLight3D.new()
		sconce.light_color = Color(1.0, 0.66, 0.36)
		sconce.light_energy = 1.3
		sconce.omni_range = 5.5
		sconce.position = spot + Vector3(-signf(spot.x) * 0.3 if absf(spot.x) > 7.0 else 0.0, 0.25, 0.3 if absf(spot.x) <= 7.0 else 0.0)
		add_child(sconce)
	var env := $WorldEnvironment.environment.duplicate() as Environment
	$WorldEnvironment.environment = env
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.42, 0.36)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.92
	env.ssao_enabled = true
	env.ssao_intensity = 1.3
	env.glow_enabled = true
	env.glow_intensity = 0.3
	$Sun.light_energy = 0.15
	for light in $Lights.get_children():
		if light is OmniLight3D:
			light.light_color = Color(1, 0.70, 0.43)
			light.light_energy = 0.7
