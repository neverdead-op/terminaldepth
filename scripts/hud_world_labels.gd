extends Control
const Style := preload("res://scripts/ui_style.gd")
## Надписи над объектами мира (имена торговок, склад, верстак, сундуки, дверь) — плашками, как подписи добычи:
## тёмный фон, текст и тонкая рамка цвета надписи. Объект кладёт в себя Label3D, добавляет его в группу
## boxed_label и делает невидимым (transparency = 1) — здесь рисуется плашка на его месте.

@export var font_size := 16
@export var pad := Vector2(12, 5)
@export var max_distance := 30.0

var player: Node3D
var _badge: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var font := Loc.TITLE_FONT
	for label in get_tree().get_nodes_in_group("boxed_label"):
		if not label is Label3D or not label.is_visible_in_tree() or label.text == "":
			continue
		var at: Vector3 = label.global_position
		if camera.is_position_behind(at):
			continue
		if player != null and is_instance_valid(player) and player.global_position.distance_to(at) > max_distance:
			continue
		var text := Loc.npc_name(label.text).trim_prefix("! ")
		var color := Style.TEXT
		var size_px := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) + pad * 2.0
		var rect := Rect2(camera.unproject_position(at) - size_px * 0.5, size_px)
		Style.nameplate(self, rect, Style.GOLD)
		draw_string(font, rect.position + Vector2(pad.x, pad.y + font.get_ascent(font_size)), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		if label.get_meta("new_dialog", false):
			# Отдельный контрастный значок реплики, без контура на теле NPC.
			var bubble := Rect2(Vector2(rect.end.x + 5, rect.position.y - 3), Vector2(25, 20))
			draw_style_box(_dialog_badge(), bubble)
			draw_colored_polygon(PackedVector2Array([bubble.position + Vector2(5, 18), bubble.position + Vector2(5, 25), bubble.position + Vector2(12, 18)]), Color(0.68, 0.92, 1.0))
			for i in 3:
				draw_circle(bubble.position + Vector2(6.5 + i * 6, 10), 1.6, Color(0.04, 0.08, 0.1))


func _dialog_badge() -> StyleBoxFlat:
	if _badge != null:
		return _badge
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.68, 0.92, 1.0)
	badge.border_color = Color(0.02, 0.04, 0.05)
	badge.set_border_width_all(2)
	badge.set_corner_radius_all(5)
	_badge = badge
	return badge
