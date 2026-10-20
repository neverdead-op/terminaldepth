extends Node
## Регрессия полосок на повёрнутых моделях, реакций резака и суммарного отброса дроби.
const Bar := preload("res://scripts/health_bar_3d.gd")
const DB := preload("res://scripts/item_db.gd")

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var center := Vector3(2000, 0, 2000)
	player.global_position = center + Vector3(0, 0, 4)
	var camera := get_viewport().get_camera_3d()
	var rig := camera.get_parent()
	assert(is_equal_approx(rig.distance, 13.8) and is_equal_approx(rig.elevation_degrees, 52))
	rig.set_physics_process(false)
	camera.global_position = center + rig._camera_offset()
	camera.look_at(center + Vector3.UP * 0.7)
	var enemies: Array[Enemy] = []
	for i in 6:
		var enemy: Enemy = load("res://scenes/brute.tscn" if i == 5 else "res://scenes/crawler.tscn").instantiate()
		if i in [2, 3]: enemy.humanoid_model = preload("res://assets/characters/parasite.tscn")
		if i == 5: enemy.humanoid_model = preload("res://assets/characters/mutant.tscn")
		if i in [2, 3, 5]: enemy.humanoid_alt = null
		add_child(enemy)
		enemy.global_position = center + Vector3((i % 3 - 1) * 3.0, 0, (i / 3) * 3.3 - 2)
		enemy.set_physics_process(false)
		enemy.rotation.y = i * PI / 3
		enemies.append(enemy)
		var bar: Node3D = enemy.health_bar
		bar.hide_when_full = false
		bar.set_ratio([0.08, 0.25, 0.5, 0.75, 1.0, 0.6][i])
		print("BAR_HEIGHT ", i, " ", bar.position.y)
		assert(bar.position.y > 1.6)
	await get_tree().process_frame
	for enemy in enemies:
		var bar: Node3D = enemy.health_bar
		for angle in [0.0, 0.7, 1.57, 2.6, 3.14, 4.8]:
			enemy.rotation.y = angle
			bar._process(0)
			var fill: MeshInstance3D = bar._fill
			var left := camera.unproject_position(fill.to_global(Vector3(-bar.width * 0.5, 0, 0)))
			var right := camera.unproject_position(fill.to_global(Vector3(bar.width * 0.5, 0, 0)))
			var backing_left := camera.unproject_position(bar.to_global(Vector3(-bar.width * 0.5, 0, 0)))
			assert(absf(left.y - right.y) < 0.2)
			assert(absf(left.x - backing_left.x) < 0.2)
			assert(right.x > left.x)
			assert(fill.material_override.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED)
		bar.set_ratio(0)
		assert(not bar.visible)
		bar.set_ratio(0.4)
		assert(bar.visible)
	print("HEALTH_BARS_OK: six models, rotations, screen-left alignment, full/empty, model height")
	var victim: Enemy = enemies[0]
	victim.max_hp = 100
	victim.hp = 100
	victim._state = Enemy.State.CHASE
	victim._hit_anim_at = 0
	victim._hit_anim_left = 0
	victim._anim_lock = 0
	victim._model_anim.play(victim.anim_idle)
	var bullet := preload("res://scenes/bullet.tscn").instantiate()
	add_child(bullet)
	var cutter: WeaponData = load("res://data/weapons/plasma_cutter.tres")
	assert(not cutter.allow_hit_stagger)
	bullet.activate(Transform3D(Basis.IDENTITY, victim.global_position), 23, 21, victim.global_position, {"damage": 40.0, "allow_stagger": cutter.allow_hit_stagger, "shooter": player, "look": &"plasma"})
	bullet.set_physics_process(false)
	bullet._damage(victim)
	assert(victim.hp > 0 and victim.hp < 100)
	assert(victim._anim_lock == 0 and victim._hit_anim_left <= victim.hit_stop_duration)
	assert(victim._hit_anim_at == 0)
	victim.max_hp = 1000
	victim.hp = 1000
	victim.velocity = Vector3.ZERO
	for pellet in 24:
		victim.take_damage(10, &"physical", player)
		assert(Vector2(victim.velocity.x, victim.velocity.z).length() <= victim.max_hit_push_speed + 0.001)
	print("HIT_REACTION_OK: cutter does not trigger falling, 24 pellets remain below push cap")
	bullet.deactivate()
	bullet.queue_free()
	var shotgun := GearItem.create(DB.base_by_id(&"shotgun"), 1, 0)
	shotgun.corp = &""
	player.inventory.add_item(shotgun)
	assert(player.inventory.equip_weapon(shotgun, 1) == "")
	player.select_weapon(1)
	player._using_mouse = false
	player.rotation.y = 0
	player._aim_dir = Vector3.FORWARD
	await get_tree().create_timer(0.3).timeout
	player._update_muzzle()
	player._bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
	for projectile in player._bullet_pool._bullets: projectile.deactivate()
	player._shoot(shotgun.weapon_data())
	var speeds := []
	var angles := []
	for projectile in player._bullet_pool._bullets:
		if not projectile.active: continue
		assert(projectile._look == &"pellet" and projectile.get_node("Mesh").visible)
		assert(is_equal_approx(projectile.get_node("Mesh").scale.x, 1.6))
		speeds.append(projectile._speed)
		angles.append(projectile.global_basis.z.signed_angle_to(Vector3.BACK, Vector3.UP))
		projectile.set_physics_process(false)
		projectile._physics_process(0.04)
	assert(speeds.size() == shotgun.weapon_data().pellets)
	assert(speeds.max() - speeds.min() > 0.1)
	assert(angles.max() - angles.min() > 0.0001)
	assert(angles.all(func(a): return absf(a) <= deg_to_rad(5.01)))
	print("SHOTGUN_PELLETS_OK: small visible dots, independent angles and speeds")
	if "--capture" in OS.get_cmdline_user_args():
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(30, 30)
		floor_mesh.mesh = plane
		var floor_material := StandardMaterial3D.new()
		floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		floor_material.albedo_color = Color(0.06, 0.07, 0.08)
		floor_mesh.material_override = floor_material
		add_child(floor_mesh)
		floor_mesh.global_position = center - Vector3.UP * 0.05
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-60, -20, 0)
		light.light_energy = 1.4
		add_child(light)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/health_bars_fixed.png")
	print("HEALTH_COMBAT_OK")
	get_tree().quit()
