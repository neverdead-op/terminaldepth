extends Node
## Быстрый тест этажа без меню и базы: F6 на scenes/tools/test_zone.tscn — сразу на нужный этаж.
## Сохранения в тесте отключены (настоящий забег не затрётся).
## Из командной строки (для Claude): godot --path . res://scenes/tools/test_zone.tscn -- floor=2 shots=user://shots
##   floor=N — этаж, mode=god/normal, freeze=1 — враги стоят, shots=папка — снимки старта и залов-ориентиров, затем выход,
##   at=x,z — поставить игрока в точку, zoom=0.4 — камера ближе (доля обычного расстояния).

## Этаж 1…5.
@export_range(1, 5) var floor := 1
## Режим: god — бессмертие и много золота, normal — как в игре.
@export_enum("god", "normal", "hardcore") var mode := "god"
## Враги замирают (удобно смотреть локацию).
@export var freeze_enemies := false
## Уровень персонажа на старте.
@export_range(1, 5) var player_level := 1

var _shots := ""
var _at := Vector2.INF
var _zoom := 1.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"floor": floor = int(kv[1])
			"mode": mode = kv[1]
			"freeze": freeze_enemies = kv[1] == "1"
			"level": player_level = int(kv[1])
			"shots": _shots = kv[1]
			"zoom": _zoom = float(kv[1])
			"at":
				var xz := kv[1].split(",")
				_at = Vector2(float(xz[0]), float(xz[1]))
	_start.call_deferred()


func _start() -> void:
	set_meta(&"test_runner", true)
	var p: Node3D = Game.start_test(floor, StringName(mode))
	var zone := get_tree().current_scene
	while p.level < player_level and not p.is_max_level():
		p.add_xp(p.xp_for_next_level() - p.xp)
	await get_tree().create_timer(0.3).timeout
	if freeze_enemies:
		for e in get_tree().get_nodes_in_group("enemies"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	if _zoom != 1.0:
		var cam := get_viewport().get_camera_3d()
		if cam != null and cam.get_parent().get("offset") != null:
			cam.get_parent().offset *= _zoom
	if _at != Vector2.INF:
		p.global_position = Vector3(_at.x, 0.1, _at.y)
	if _shots == "":
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	var spots: Array = [p.global_position]
	var rects: Array = zone.get("landmark_rects") if zone.get("landmark_rects") != null else []
	for r: Rect2 in rects:
		spots.append(Vector3(r.get_center().x, 0.1, r.get_center().y))
	await get_tree().create_timer(2.0).timeout
	for i in spots.size():
		p.global_position = spots[i]
		p.velocity = Vector3.ZERO
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(_shots.path_join("floor%d_%02d.png" % [floor, i]))
		print("shot %d: %d FPS" % [i, Engine.get_frames_per_second()])
	get_tree().quit()
