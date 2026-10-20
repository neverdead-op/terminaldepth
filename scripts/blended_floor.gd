extends RefCounted
## Пол одним куском из клеток 2×2 м: до шести покрытий смешиваются по карте смешивания
## (assets/shaders/village_floor_blend.gdshader) — без квадратных ступенек на стыках.
## Используют деревня (lunar_intro.gd) и переодетые зоны (gothic_restyle.gd).

## Покрытия по номерам: 0 — плитка с лепестками, 1 — булыжник, 2 — грязь с лужами,
## 3 — плитка с корнями, 4 — мох, 5 — палая листва.
static func default_textures() -> Array[Texture2D]:
	return [preload("res://assets/textures/victorian_garden/stylized_v2/flagstones_red_petals_albedo.png"),
		preload("res://assets/environment/town_ruins/textures/cobbles_albedo.png"),
		preload("res://assets/textures/level1_v3/floor_mud_puddles_albedo.png"),
		preload("res://assets/textures/level1_v3/floor_root_flagstones_albedo.png"),
		preload("res://assets/textures/level1_v3/floor_moss_albedo.png"),
		preload("res://assets/textures/level1_v3/floor_leaves_albedo.png")]


## variants: Vector2i(клетка, чётные x/z) → номер покрытия. tiles/wets/reliefs — по шесть значений.
## blend_cells — ширина перехода в клетках, height — высота пола (y).
static func build(variants: Dictionary, textures: Array[Texture2D], tiles: PackedFloat32Array, wets: PackedFloat32Array,
		reliefs: PackedFloat32Array, blend_cells := 2, edge_noise := 0.7, height := 0.012) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for cell: Vector2i in variants:
		low = low.min(cell)
		high = high.max(cell)
		var corners := [Vector3(cell.x, height, cell.y + 2), Vector3(cell.x + 2, height, cell.y + 2), Vector3(cell.x + 2, height, cell.y), Vector3(cell.x, height, cell.y)]
		for index in [0, 2, 1, 0, 3, 2]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(corners[index].x, corners[index].z) / 6.0)
			surface.add_vertex(corners[index])
	# Карта смешивания: пиксель на клетку, веса размыты на blend_cells клеток в каждую сторону.
	var origin := Vector2(low.x - 2, low.y - 2)
	var size := Vector2i((high.x - low.x) / 2 + 3, (high.y - low.y) / 2 + 3)
	var weights := []
	for i in 6:
		var layer := PackedFloat32Array()
		layer.resize(size.x * size.y)
		weights.append(layer)
	for cell: Vector2i in variants:
		var px := (cell.x - int(origin.x)) / 2
		var pz := (cell.y - int(origin.y)) / 2
		weights[variants[cell]][pz * size.x + px] = 1.0
	for pass_index in blend_cells:
		for i in 6:
			var src: PackedFloat32Array = weights[i]
			var dst := PackedFloat32Array()
			dst.resize(src.size())
			for z in size.y:
				for x in size.x:
					var sum := 0.0
					for dz in range(-1, 2):
						for dx in range(-1, 2):
							sum += src[clampi(z + dz, 0, size.y - 1) * size.x + clampi(x + dx, 0, size.x - 1)]
					dst[z * size.x + x] = sum / 9.0
			weights[i] = dst
	var splat_a := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var splat_b := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for z in size.y:
		for x in size.x:
			var k := z * size.x + x
			var total := 0.0
			for i in 6: total += weights[i][k]
			total = maxf(total, 0.0001)
			splat_a.set_pixel(x, z, Color(weights[0][k] / total, weights[1][k] / total, weights[2][k] / total, weights[3][k] / total))
			splat_b.set_pixel(x, z, Color(weights[4][k] / total, weights[5][k] / total, 0, 1))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/village_floor_blend.gdshader")
	for i in 6:
		mat.set_shader_parameter("layer%d" % i, textures[i])
	mat.set_shader_parameter("tiles", tiles)
	mat.set_shader_parameter("wet", wets)
	mat.set_shader_parameter("relief", reliefs)
	mat.set_shader_parameter("splat_a", ImageTexture.create_from_image(splat_a))
	mat.set_shader_parameter("splat_b", ImageTexture.create_from_image(splat_b))
	mat.set_shader_parameter("splat_rect", Vector4(origin.x, origin.y, size.x * 2.0, size.y * 2.0))
	mat.set_shader_parameter("edge_noise", edge_noise)
	var visual := MeshInstance3D.new()
	visual.name = "TownFloor"
	visual.mesh = surface.commit()
	visual.material_override = mat
	return visual
