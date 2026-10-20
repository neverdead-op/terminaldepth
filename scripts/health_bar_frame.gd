extends RefCounted
## Исходные PNG не обрезаются: атлас исключает прозрачные поля, заливка совпадает с окном.
const OVERHEAD := preload("res://assets/ui/gothic_v4/health_frames/overhead_frame_v1.png")
const TARGET := preload("res://assets/ui/gothic_v4/health_frames/target_panel_v1.png")
const OVERHEAD_REGION := Rect2(2, 251, 2075, 249)
const OVERHEAD_OPENING := Rect2(210, 336, 1660, 74)
const TARGET_REGION := Rect2(37, 145, 1910, 501)
const TARGET_OPENING := Rect2(278, 484, 1426, 63)
static var _meshes := {}
static var _materials := {}
static var _overhead_atlas: AtlasTexture
const MOB := preload("res://assets/ui/gothic_v4/health_frames/mob_frame_v2.png")
const BOSS := preload("res://assets/ui/gothic_v4/health_frames/boss_frame_v2.png")
const MOB_REGION := Rect2(25, 303, 2122, 118)
const MOB_OPENING := Rect2(145, 344, 1882, 36)
const BOSS_REGION := Rect2(12, 183, 2148, 277)
const BOSS_OPENING := Rect2(190, 290, 1790, 56)
static var _target_atlases := {}

static func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = region
	return result

static func attach(parent: Node3D, fill_size: Vector2, priority: int) -> MeshInstance3D:
	if _overhead_atlas == null:
		_overhead_atlas = _atlas(OVERHEAD, OVERHEAD_REGION)
	var factor := fill_size / OVERHEAD_OPENING.size
	if not _meshes.has(fill_size):
		var quad := QuadMesh.new()
		quad.size = OVERHEAD_REGION.size * factor
		_meshes[fill_size] = quad
	if not _materials.has(priority):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = _overhead_atlas
		material.no_depth_test = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.render_priority = priority
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_materials[priority] = material
	var frame := MeshInstance3D.new()
	frame.name = "GothicFrame"
	frame.mesh = _meshes[fill_size]
	frame.material_override = _materials[priority]
	var offset := (OVERHEAD_REGION.get_center() - OVERHEAD_OPENING.get_center()) * factor
	frame.position = Vector3(offset.x, -offset.y, 0)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(frame)
	return frame

## Имя находится над рамкой, а уровень — справа, без наложения друг на друга.
static func target_layout(center_x: float, fill_width: float, boss := false, fill_height := 5.0) -> Dictionary:
	var region := BOSS_REGION if boss else MOB_REGION
	var opening := BOSS_OPENING if boss else MOB_OPENING
	var factor := Vector2(fill_width, fill_height) / opening.size
	var title_height := 22.0 if boss else 18.0
	var title_rect := Rect2(center_x - fill_width * 0.5 + 30, 0, fill_width - 60, title_height)
	var level_rect := Rect2(center_x + fill_width * 0.5 - 27, 0, 27, title_height)
	# Выравниваем отверстие по середине экрана, независимо от украшений исходного рисунка.
	var panel_pos := Vector2(center_x - fill_width * 0.5, title_height + (15 if boss else 5)) - (opening.position - region.position) * factor
	var panel := Rect2(panel_pos, region.size * factor)
	var bar := Rect2(panel.position + (opening.position - region.position) * factor, Vector2(fill_width, fill_height))
	return {"panel": panel, "bar": bar, "title_rect": title_rect, "level_rect": level_rect}

static func draw_target(ci: CanvasItem, panel: Rect2, boss := false) -> void:
	if not _target_atlases.has(boss):
		_target_atlases[boss] = _atlas(BOSS if boss else MOB, BOSS_REGION if boss else MOB_REGION)
	ci.draw_texture_rect(_target_atlases[boss], panel, false)
