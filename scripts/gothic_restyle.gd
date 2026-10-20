extends RefCounted
## Переодевает сгенерированную зону (zone_N.tscn из tools/gen_open_zone.py) в стиль первого уровня,
## не меняя её расстановку: пол со смешиванием покрытий, кладка стен с мхом, готические замены
## научно-фантастических моделей (на их месте остаются те же преграды), ночной свет и туман,
## нарисованные сундуки, обелиски, деревья, надгробия и скамьи. Включается в zone.gd: gothic_style.

const FlatSprite := preload("res://scripts/flat_sprite.gd")
const BlendedFloor := preload("res://scripts/blended_floor.gd")
const Materials := preload("res://scripts/village_materials.gd")
const Kit := "res://assets/environment/victorian_kit/v1/"
const Threshold := "res://assets/environment/threshold_set/v1/"
const G2D := "res://assets/environment/graveyard_2d/"
## Модели из этих наборов — станция; их прячем.
const SCI_FI_SETS := ["/megakit/", "/essentials/"]

var zone: Node3D
var cells := {}
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _wall_mats: Array[ShaderMaterial] = []
var _dark_wood: StandardMaterial3D
var _cobweb_mat: ShaderMaterial
var _placed: Array[Vector2] = []


## До _ready детей: сундукам и обелискам — картинки (они строят облик в своём _ready).
static func prepare(target: Node3D) -> void:
	for chest in target.find_children("*", "", true, false):
		if chest.get_script() == preload("res://scripts/loot_chest.gd"):
			chest.sprite = load(G2D + "chest.png")
			chest.sprite_flip = chest.position.x > 0.0
		elif chest.get_script() == preload("res://scripts/destructible.gd") and chest.kind == "obelisk":
			chest.sprite = load(G2D + "obelisk.png")


func apply(target: Node3D) -> void:
	zone = target
	_noise.seed = 4242
	_noise.frequency = 0.05
	_rng.seed = 909
	var geometry := zone.get_node("Navigation/Geometry")
	_build_floor(geometry)
	_dress_walls(geometry)
	_replace_station_models(geometry)
	_restyle_doors()
	_light()
	_paint_props()


## Пол: клетки 2×2 м из коробок Floor/Passage; залы — сады (мох, листва), проходы — булыжник,
## малые комнаты — плитка с корнями, края залов — грязь.
func _build_floor(geometry: Node) -> void:
	var variants := {}
	for body in geometry.get_children():
		var kind := str(body.name).rstrip("0123456789")
		if kind != "Floor" and kind != "Passage": continue
		var shape := body.get_node_or_null("Shape") as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D: continue
		for child in body.get_children():
			if child is MeshInstance3D: child.visible = false
		var size: Vector3 = shape.shape.size
		var center: Vector3 = (body as Node3D).global_position + shape.position
		var area := size.x * size.z
		for x in range(int(floor((center.x - size.x * 0.5) / 2.0)) * 2, int(ceil(center.x + size.x * 0.5)), 2):
			for z in range(int(floor((center.z - size.z * 0.5) / 2.0)) * 2, int(ceil(center.z + size.z * 0.5)), 2):
				var c := Vector2(x + 1, z + 1)
				if absf(c.x - center.x) > size.x * 0.5 or absf(c.y - center.z) > size.z * 0.5: continue
				var cell := Vector2i(x, z)
				var variant := 1
				if kind == "Floor":
					var n := _noise.get_noise_2d(c.x, c.y)
					if area > 140.0: variant = 4 if n < 0.15 else 5
					elif area > 40.0: variant = 3 if n < 0.25 else 4
					else: variant = 3
				# Проход внутри зала не перекрашивает зал.
				if variants.has(cell) and kind == "Passage": continue
				variants[cell] = variant
	cells = variants.duplicate()
	# Края залов (рядом со стеной) — грязь с лужами.
	for cell: Vector2i in variants:
		if variants[cell] >= 4:
			for dir in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				if not cells.has(cell + dir):
					variants[cell] = 2
					break
	var tiles := PackedFloat32Array([6.0, 5.0, 7.0, 6.0, 5.0, 4.0])
	var wets := PackedFloat32Array([0.85, 0.85, 0.85, 0.85, 0.15, 0.15])
	var reliefs := PackedFloat32Array([0.35, 0.35, 0.35, 0.35, 0.08, 0.08])
	zone.add_child(BlendedFloor.build(variants, BlendedFloor.default_textures(), tiles, wets, reliefs, 2, 0.7, 0.015))


func _wall_material(at: Vector3) -> ShaderMaterial:
	if _wall_mats.is_empty():
		for path in ["res://assets/textures/level1_v3/wall_ivy_stone_albedo.png", "res://assets/textures/level1_v3/wall_plaster_ruin_albedo.png", "res://assets/textures/level1_v3/wall_dark_blocks_albedo.png"]:
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://assets/shaders/village_wall.gdshader")
			mat.set_shader_parameter("base_tex", load(path))
			mat.set_shader_parameter("moss_tex", preload("res://assets/textures/level1_v3/floor_moss_albedo.png"))
			mat.set_shader_parameter("tint", Color(0.85, 0.85, 0.88))
			mat.set_shader_parameter("tile_meters", 3.0)
			mat.set_shader_parameter("moss_amount", 0.6)
			_wall_mats.append(mat)
		_dark_wood = StandardMaterial3D.new()
		_dark_wood.albedo_texture = preload("res://assets/environment/victorian_kit/v1/textures/oak_light_albedo.png")
		_dark_wood.albedo_color = Color(0.25, 0.17, 0.11)
		_dark_wood.uv1_triplanar = true
		_dark_wood.uv1_world_triplanar = true
		_dark_wood.roughness = 0.8
	var n := _noise.get_noise_2d(at.x * 1.3 + 100.0, at.z * 1.3)
	return _wall_mats[0] if n < -0.1 else (_wall_mats[1] if n < 0.25 else _wall_mats[2])


## Стены: кладка вместо панелей станции, тёмный камень сверху, местами обломки и навершия, паутина в углах.
func _dress_walls(geometry: Node) -> void:
	for body in geometry.get_children():
		if not str(body.name).begins_with("Wall"): continue
		var shape := body.get_node_or_null("Shape") as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D: continue
		var at: Vector3 = (body as Node3D).global_position
		var mat := _wall_material(at)
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh: mesh.material_override = mat
		var top := body.get_node_or_null("Top") as MeshInstance3D
		if top: top.material_override = _wall_mats[2]
		# Вдоль длинной стены — редкие навершия и обломки на гребне.
		var size: Vector3 = shape.shape.size
		var along := Vector3(1, 0, 0) if size.x >= size.z else Vector3(0, 0, 1)
		var length := maxf(size.x, size.z)
		var steps := int(length / 4.0)
		for i in steps:
			var point := at + along * ((i + 0.5) * length / maxi(steps, 1) - length * 0.5)
			var roll := fposmod(sin(point.x * 12.9898 + point.z * 78.233) * 43758.5453, 1.0)
			var crest := point + Vector3(0, size.y * 0.5 + (body as Node3D).global_position.y * 0.0, 0)
			if roll < 0.12:
				_on_wall(load(Threshold + "column_cap.glb"), crest, Vector3(0.9, 0.32, 0.9), mat)
			elif roll < 0.26:
				_on_wall(load("res://assets/environment/town_ruins/rubble.glb"), crest - Vector3(0, 0.1, 0), Vector3(0.6, 0.7, 0.45), mat)
	# Паутина во внутренних углах пола.
	for cell: Vector2i in cells:
		for corner in [Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(-2, -2)]:
			if cells.has(cell + Vector2i(corner.x, 0)) or cells.has(cell + Vector2i(0, corner.y)): continue
			var spot := Vector3(cell.x + 1 + corner.x * 0.5, 0, cell.y + 1 + corner.y * 0.5)
			if fposmod(sin(spot.x * 7.1 + spot.z * 3.7) * 9631.7, 1.0) > 0.3: continue
			_cobweb(spot, Vector2(-corner.x, -corner.y).normalized())


func _on_wall(scene: PackedScene, at: Vector3, scale: Vector3, mat: Material) -> void:
	var node: Node3D = scene.instantiate()
	node.position = at
	node.scale = scale
	zone.add_child(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = mat


func _cobweb(corner: Vector3, inward: Vector2) -> void:
	if _cobweb_mat == null:
		_cobweb_mat = ShaderMaterial.new()
		_cobweb_mat.shader = preload("res://assets/shaders/cobweb.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var web := MeshInstance3D.new()
	web.mesh = quad
	web.material_override = _cobweb_mat
	web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	web.position = corner + Vector3(inward.x, 0, inward.y) * 1.0 + Vector3.UP * 2.2
	web.rotation.y = atan2(inward.x, inward.y)
	web.set_instance_shader_parameter("seed", corner.x + corner.z)
	zone.add_child(web)


## Модели станции прячем. Их преграды (Prop) остаются — на каждую ставим готическую замену по размеру:
## высокая узкая — колонна, высокая широкая — полка, низкая — бочка или ящик.
func _replace_station_models(geometry: Node) -> void:
	var models := zone.get_node_or_null("Models")
	if models:
		for batch in models.get_children():
			var model = batch.get("model")
			if model is PackedScene and SCI_FI_SETS.any(func(s): return (model as PackedScene).resource_path.contains(s)):
				batch.visible = false
	for body in geometry.get_children():
		if not str(body.name).begins_with("Prop"): continue
		var shape := body.get_node_or_null("Shape") as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D: continue
		var size: Vector3 = shape.shape.size
		var base: Vector3 = (body as Node3D).global_position + shape.position - Vector3(0, size.y * 0.5, 0)
		base.y = 0.0
		var stand_in: Node3D
		if size.y > 2.2 and maxf(size.x, size.z) < 1.4:
			stand_in = load(Kit + "pillar_square.glb").instantiate()
			stand_in.scale = Vector3(size.x / 0.85, size.y / 3.2, size.z / 0.85)
		elif size.y > 1.5:
			stand_in = load(Kit + "shelf_dark.glb").instantiate()
			stand_in.rotation.y = 0.0 if size.x >= size.z else PI * 0.5
			stand_in.scale = Vector3(maxf(size.x, size.z) / 1.42, size.y / 1.9, 1.0)
		elif _rng.randf() < 0.5:
			stand_in = load(Threshold + "barrel.glb").instantiate()
			stand_in.scale = Vector3.ONE * clampf(minf(size.x, size.z) / 0.88, 0.6, 1.4)
		else:
			stand_in = load(Threshold + "crate.glb").instantiate()
			stand_in.scale = Vector3(size.x / 1.11, size.y / 1.1, size.z / 1.02)
		stand_in.position = base
		zone.add_child(stand_in)
		_placed.append(Vector2(base.x, base.z))


## Двери-шлюзы: металл — тёмный дуб; светящиеся полосы (замок) остаются яркими.
func _restyle_doors() -> void:
	var doors := zone.get_node_or_null("Doors")
	if doors == null: return
	for mesh: MeshInstance3D in doors.find_children("*", "MeshInstance3D", true, false):
		var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D if mesh.mesh and mesh.mesh.get_surface_count() > 0 else null
		if mat != null and mat.emission_enabled: continue
		mesh.material_override = _dark_wood


## Свет как в деревне: холодная лунная ночь, тёплые фонари, туман и мягкие тени.
func _light() -> void:
	var lights := zone.get_node_or_null("Lights")
	if lights:
		var i := 0
		for light in lights.get_children():
			if light is OmniLight3D:
				var cold := i % 4 == 3
				light.light_color = Color(0.55, 0.65, 0.85) if cold else Color(1.0, 0.66, 0.36)
				light.light_energy = minf(light.light_energy, 1.6) * (0.7 if cold else 1.0)
				light.light_volumetric_fog_energy = 1.2
				i += 1
	var env_node := zone.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment.duplicate() as Environment
		env_node.environment = env
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.004, 0.006, 0.014)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.48, 0.61, 0.69)
		env.ambient_light_energy = 0.24
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.ssao_enabled = true
		env.ssao_intensity = 1.1
		env.glow_enabled = true
		env.glow_intensity = 0.23
		env.glow_hdr_threshold = 1.6
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.12
		env.adjustment_saturation = 0.88
		env.fog_enabled = true
		env.fog_density = 0.006
		env.fog_light_color = Color(0.17, 0.23, 0.25)
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.025
		env.volumetric_fog_albedo = Color(0.36, 0.43, 0.46)
		env.volumetric_fog_length = 48.0
	var moon := zone.get_node_or_null("MoonLight") as DirectionalLight3D
	if moon:
		moon.light_energy = 0.16
		moon.light_color = Color(0.65, 0.75, 0.85)


## Нарисованные предметы: мёртвые деревья за стенами, надгробия и скамьи в залах-садах.
func _paint_props() -> void:
	var tree := load(G2D + "dead_tree.png") as Texture2D
	var graves := [load(G2D + "tombstone_arch.png"), load(G2D + "stone_cross.png"), load(G2D + "tombstone_candles.png")]
	var bench := load(G2D + "stone_bench.png") as Texture2D
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for cell: Vector2i in cells:
		low = low.min(cell)
		high = high.max(cell)
	for x in range(low.x - 10, high.x + 12, 6):
		for z in range(low.y - 10, high.y + 12, 6):
			var at := Vector2(x, z) + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2))
			if _has_floor(at, 3.0) or not _has_floor(at, 9.0) or _rng.randf() < 0.55: continue
			var sprite := FlatSprite.make(tree, _rng.randf_range(3.5, 5.0), _rng.randf() < 0.5)
			sprite.modulate = Color(0.5, 0.5, 0.56)
			sprite.position = Vector3(at.x, 0, at.y)
			zone.add_child(sprite)
	var keep_clear: Array[Vector2] = _placed.duplicate()
	for node in zone.find_children("*", "Node3D", true, false):
		if node.get_script() == preload("res://scripts/loot_chest.gd") or node.is_in_group("interactables") or node is Enemy or node.get_script() == preload("res://scripts/destructible.gd"):
			keep_clear.append(Vector2(node.global_position.x, node.global_position.z))
	var count := 0
	for cell: Vector2i in cells:
		if count > 40 or _rng.randf() > 0.06: continue
		var at := Vector2(cell.x + 1, cell.y + 1)
		if not _has_floor(at, 2.5, true) or keep_clear.any(func(p): return p.distance_to(at) < 4.0): continue
		keep_clear.append(at)
		count += 1
		var is_bench := _rng.randf() < 0.3
		var texture: Texture2D = bench if is_bench else graves[_rng.randi() % graves.size()]
		var width := 2.2 if is_bench else 1.5 * float(texture.get_width()) / texture.get_height()
		var sprite := FlatSprite.make(texture, width, _rng.randf() < 0.5 and is_bench)
		sprite.modulate = Color(0.5, 0.5, 0.56)
		sprite.position = Vector3(at.x, 0, at.y)
		zone.add_child(sprite)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 0.8, 0.7) if is_bench else Vector3(1.0, 1.2, 0.6)
		shape.shape = box
		body.add_child(shape)
		body.position = Vector3(at.x, box.size.y * 0.5, at.y)
		zone.get_node("Navigation").add_child(body)


## Есть ли пол в радиусе; full — весь круг на полу (место в глубине зала, не у прохода).
func _has_floor(at: Vector2, radius: float, full := false) -> bool:
	var found := false
	for dx in range(-int(radius), int(radius) + 1, 2):
		for dz in range(-int(radius), int(radius) + 1, 2):
			if Vector2(dx, dz).length() > radius: continue
			var cell := Vector2i(int(floor((at.x + dx) / 2.0)) * 2, int(floor((at.y + dz) / 2.0)) * 2)
			var hit: bool = cells.has(cell) and cells[cell] >= 3
			if full and not hit: return false
			found = found or cells.has(cell)
	return found
