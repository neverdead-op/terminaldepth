extends Control
## Просмотр новых значков в реальном размере ячеек интерфейса.
const UiIcons := preload("res://scripts/ui_icons.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const ModuleDB := preload("res://scripts/module_db.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.027, 0.025, 0.023))
	var font := Loc.MAIN_FONT
	draw_string(Loc.TITLE_FONT, Vector2(80, 55), "TERMINAL DEPTH · RELIQUARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.86, 0.71, 0.45))
	var items := []
	for module in ModuleDB.ALL:
		items.append([module.display_name, "res://assets/icons/modules_v2/%s.png" % module.id])
	for id in ItemDB.CURRENCY_ORDER:
		items.append([ItemDB.CURRENCY[id].name, "res://assets/icons/currency_v2/%s.png" % id])
	items.append_array([["Mine Pack", "res://assets/icons/weapons/mine_pack_v2.png"], ["Loot Reward", "res://assets/icons/rewards/loot.png"], ["Experience", "res://assets/icons/rewards/xp.png"]])
	for i in items.size():
		var at := Vector2(80 + (i % 9) * 160, 90 + (i / 9) * 190)
		var tile := Rect2(at, Vector2(148, 178))
		draw_rect(tile, Color(0.015, 0.015, 0.017))
		draw_rect(tile, Color(0.32, 0.27, 0.2), false)
		var icon := UiIcons.texture(items[i][1])
		if icon != null:
			UiIcons.draw_texture_fit(self, icon, Rect2(at + Vector2(23, 10), Vector2(102, 102)))
			UiIcons.draw_texture_fit(self, icon, Rect2(at + Vector2(58, 122), Vector2(32, 32)))
		draw_string(font, at + Vector2(5, 171), Loc.t(items[i][0]), HORIZONTAL_ALIGNMENT_CENTER, 138, 11, Color(0.83, 0.78, 0.67))
