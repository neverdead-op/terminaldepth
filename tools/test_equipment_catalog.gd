extends Control
## Галерея нового первого акта, без запуска кампании и записи сохранения.
const DB := preload("res://scripts/item_db.gd")
const Icons := preload("res://scripts/ui_icons.gd")
const ROWS := [
	[&"plasma_cutter", &"plasma_cutter_mk2", &"shotgun", &"pump_shotgun", &"rifle", &"carbine"],
	[&"patrol_helmet", &"bastion_helmet", &"assault_helmet", &"command_helmet", &"sensor_helmet", &"emitter_crown"],
	[&"vest", &"exoskeleton", &"spacesuit", &"drop_suit", &"hazmat", &"hive_suit"],
	[&"tactical_gloves", &"power_gloves", &"combat_mitts", &"relay_gloves", &"conductor_gloves", &"neuro_gloves"],
	[&"army_boots", &"servo_boots", &"scout_boots", &"relay_boots", &"mag_boots", &"grav_boots"],
]

func _ready() -> void:
	set_meta("test_runner", true)
	for row in ROWS:
		for column in row.size():
			var base := DB.base_by_id(row[column])
			var level := 1 if column % 2 == 0 else 4
			assert(base.level == level)
			assert(DB.available_bases(level).has(base))
			assert(level == 1 or not DB.available_bases(3).has(base))
			var item := GearItem.create(base, level, 0)
			assert(item.corp == (&"helix" if item.is_weapon() else &"vortech"))
			assert(Icons.texture(item.icon_path()) != null)
			if item.is_weapon(): assert(Icons.weapon_texture(item.weapon_data()) == Icons.texture(item.icon_path()))
	print("EQUIPMENT CATALOG OK: 30 icons, levels 1/4, fixed manufacturers, HUD textures")
	queue_redraw()
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
	elif "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/equipment_catalog.png")
		get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), Color("14171b"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(25, 30), "АКТ I — ОРУЖИЕ HELIX / БРОНЯ VORTECH — 1-й и 4-й уровни", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("d6bb8c"))
	for r in ROWS.size():
		for c in 6:
			var item := GearItem.create(DB.base_by_id(ROWS[r][c]), 4, 0)
			var cell := Rect2(20 + c * 260, 45 + r * 169, 250, 160)
			draw_rect(cell, Color("20262c"))
			Icons.draw_item_picture(self, item, Rect2(cell.position + Vector2(12, 5), Vector2(226, 117)))
			draw_string(font, cell.position + Vector2(8, 139), item.base.name, HORIZONTAL_ALIGNMENT_LEFT, 236, 15, Color("e2ded4"))
			var text := "Уровень %d" % item.base.level
			if not item.is_weapon(): text += "   Броня %d / ЭЩ %d" % [item.base.armor, item.base.es]
			draw_string(font, cell.position + Vector2(8, 156), text, HORIZONTAL_ALIGNMENT_LEFT, 236, 13, Color("83b4bb"))
