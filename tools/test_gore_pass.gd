extends Node
## Реальные смерти, следы на полу и ограниченные пулы эффектов, без сохранения кампании.
func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	player.set_physics_process(false)
	var intro := player.get_parent()
	assert(intro.pack_size == 5)
	var population := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		population += 1
		assert(is_equal_approx(enemy.health_scale, 0.72))
	assert(population == intro.pack_positions.size() * 5 + 1)
	var center := Vector3(2400, 0, 2400)
	player.global_position = center + Vector3(0, 0.1, 4)
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.5, 30)
	collider.shape = box
	ground.add_child(collider)
	var surface := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.26, 0.23)
	material.roughness = 0.8
	mesh.material = material
	surface.mesh = mesh
	ground.add_child(surface)
	add_child(ground)
	ground.global_position = center - Vector3.UP * 0.25
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -35, 0)
	light.light_energy = 0.8
	add_child(light)
	var camera := get_viewport().get_camera_3d()
	camera.get_parent().set_physics_process(false)
	camera.global_position = center + Vector3(0, 10, 8)
	camera.look_at(center)
	await get_tree().physics_frame
	# Переполнение не создаёт неограниченных новых узлов и повторных движений одного куска.
	for i in 20: Fx.gibs(center + Vector3(25, 0.4, 0), Vector3.FORWARD, Color.DARK_RED, Color(0.4, 0.15, 0.1), 11)
	assert(Fx._gib_nodes.size() == Fx.max_gibs and Fx.max_gibs == 160)
	assert(Fx._debris.size() <= Fx.max_gibs)
	for i in 400: Fx.blood_decal(center + Vector3(25, 0, 0), Vector3.UP, 0.4, Color.DARK_RED, 0.15)
	assert(Fx._blood.size() == Fx.max_blood and Fx.max_blood == 360)
	assert(Fx._blood_grow.size() <= Fx.max_blood)
	for i in 6:
		var enemy: Enemy = preload("res://scenes/crawler.tscn").instantiate()
		enemy.max_corpses = 3
		add_child(enemy)
		enemy.set_physics_process(false)
		enemy.global_position = center + Vector3((i % 3 - 1) * 2.3, 0, floorf(i / 3.0) * 2.2 - 2)
		assert(enemy.gib_count == 11 and enemy.blood_on_hit == 0.8)
		assert(is_equal_approx(enemy.max_hp, 96.0 * 0.72))
		enemy.take_damage(enemy.max_hp + 1, &"physical", player)
		await get_tree().create_timer(0.12).timeout
	assert(Enemy._corpses.size() <= 3)
	assert(Fx._blood.any(func(d): return d.visible and d.global_position.distance_to(center) < 10))
	await get_tree().create_timer(0.2).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/gore_pass.png")
	print("GORE_OK: 41 intro enemies, health scale 0.72, stronger hit/death blood, 11 death chunks, bounded 160 chunks/360 decals/corpses")
	get_tree().quit()
