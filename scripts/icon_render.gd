extends Node
## Рендер иконок оружия: модель сбоку, стволом вправо, прозрачный фон → assets/icons/weapons/<файл оружия>.png.
## Запуск: <godot> --path . --resolution 640x360 res://scenes/tools/icon_render.tscn — иконки для всех data/weapons.

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.6
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.current = true
	for f in DirAccess.get_files_at("res://data/weapons"):
		if not f.ends_with(".tres"):
			continue
		var w: WeaponData = load("res://data/weapons/" + f)
		if w.model == null:
			continue
		var inst: Node3D = w.model.instantiate()
		vp.add_child(inst)
		inst.rotation.y = 0.0 if w.projectile == &"arrow" else deg_to_rad(w.model_yaw - 90.0)  # ствол — вправо
		if w.projectile == &"arrow":
			inst.rotation.z = PI * 0.5  # лук — горизонтально
		await get_tree().process_frame
		var box := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var c := box.get_center()
		cam.global_position = c + Vector3(0, 0, 5)
		cam.look_at(c)
		cam.size = maxf(box.size.x / 2.0, box.size.y) * 1.08
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("res://assets/icons/weapons/%s.png" % f.get_basename())
		print("icon: ", f)
		inst.queue_free()
		await get_tree().process_frame
	get_tree().quit()
