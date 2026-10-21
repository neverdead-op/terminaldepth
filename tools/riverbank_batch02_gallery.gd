extends Node3D
## Просмотр второго набора моделей с исходными пропорциями, без запуска кампании.
func _ready() -> void:
	Game.testing = true
	make.call_deferred()
func make() -> void:
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12,0.14,0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-25,0)
	root.add_child(light)
	var reports: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/riverbank/tripo/v2/asset_report.json"))["assets"]
	for i in range(reports.size()):
		var report: Dictionary = reports[i]
		var prop: Node3D = load("res://assets/environment/riverbank/modules/"+report.module+".tscn").instantiate()
		prop.target_size = Vector3(report.prepared_bbox[0],report.prepared_bbox[1],report.prepared_bbox[2])
		prop.target_size *= 4.4 / maxf(prop.target_size.x,maxf(prop.target_size.y,prop.target_size.z))
		prop.position = Vector3((i%6)*6,0,(i/6)*7)
		root.add_child(prop)
		var label := Label3D.new()
		label.text = str(i+1)+" "+report.module
		label.font_size = 22
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = prop.position + Vector3(0,5,0)
		root.add_child(label)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 29
	cam.position = Vector3(18,26,34)
	root.add_child(cam)
	cam.look_at(Vector3(15,1,9))
	cam.current = true
	if not "--capture" in OS.get_cmdline_user_args(): return
	await get_tree().create_timer(3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/kit_batch02.png")
	get_tree().quit()
