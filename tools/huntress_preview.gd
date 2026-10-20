extends Node3D
## F6: playable supplied hero. F2 changes camera. Campaign saves are disabled.
const Player := preload("res://scenes/player.tscn")
const DB := preload("res://scripts/item_db.gd")
var player: Node3D
var camera: Camera3D
var close_camera := true
var capturing := false
## Отдельная модель для проверки без замены героя кампании.
@export var preview_model: PackedScene
@export var capture_prefix := "huntress"
@export var fixed_bow_loadout := true
@export var preview_library := ""
@export var preview_weapon := &"rifle"

func _ready() -> void:
	set_meta("test_runner", true)
	Game.testing = true
	Game.mode = &"normal"
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.08, 0.09, 0.11)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.85, 1)
	world.environment.ambient_light_energy = 0.7
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(40, 0.2, 40)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.17, 0.19)
	material.roughness = 0.85
	mesh.material = material
	floor_mesh.mesh = mesh
	floor_mesh.position.y = -0.1
	floor_body.add_child(floor_mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position.y = -0.1
	floor_body.add_child(collision)
	camera = Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.3
	add_child(camera)
	player = Player.instantiate()
	if preview_model != null:
		var previous := player.get_node("Model")
		var model_transform: Transform3D = previous.transform
		player.remove_child(previous)
		previous.free()
		var replacement := preview_model.instantiate()
		replacement.name = "Model"
		replacement.transform = model_transform
		player.add_child(replacement)
	player.flashlight_energy = 0.0
	player.fixed_bow_loadout = fixed_bow_loadout
	if not fixed_bow_loadout:
		player.start_weapon = preview_weapon
		player.start_weapon_corp = &""
	if not preview_library.is_empty():
		player.get_node("Model").animation_library_path = preview_library
	Game.player = player
	add_child(player)
	var pool := preload("res://scripts/bullet_pool.gd").new()
	pool.name = "Arrows"
	pool.add_to_group("bullet_pool")
	pool.bullet_scene = preload("res://scenes/bullet.tscn")
	pool.pool_size = 32
	add_child(pool)
	for at in [Vector3(0, 0, -7), Vector3(-3, 0, -8), Vector3(3, 0, -8)]:
		var target := preload("res://scenes/dummy.tscn").instantiate()
		target.position = at
		add_child(target)
	var canvas := CanvasLayer.new()
	canvas.name = "PreviewHelp"
	add_child(canvas)
	var label := Label.new()
	label.text = "WASD — движение · удерживать ЛКМ — натянуть лук и стрелять · Space — перекат\nF2 — камера · лук закреплён · сохранения отключены"
	if not fixed_bow_loadout:
		label.text = "WASD — движение · ЛКМ — стрельба · R — перезарядка · Space — перекат\nF2 — камера · сохранения отключены"
	label.position = Vector2(20, 16)
	canvas.add_child(label)
	_update_camera()
	if "--capture" in OS.get_cmdline_user_args():
		capturing = true
		_capture.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		close_camera = not close_camera
		_update_camera()

func _process(_delta: float) -> void:
	if is_instance_valid(player) and not capturing:
		_update_camera()

func _update_camera() -> void:
	var target: Vector3 = player.global_position + Vector3.UP * 0.85
	camera.size = 3.3 if close_camera else 11.0
	camera.position = target + (Vector3(2.5, 1.1, -4.5) if close_camera else Vector3(0, 10.8, 8.5))
	camera.look_at(target)

func _capture() -> void:
	player._bow_equip_left = 0.0
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.get_node("HUD").hide()
	$PreviewHelp.hide()
	for child in player.get_children():
		if child.get_script() == preload("res://scripts/player_bar_3d.gd"):
			child.set_process(false)
			child.hide()
	await get_tree().create_timer(0.5).timeout
	var animator: AnimationTree = player.get_node("Animator")
	var sk := player.get_node("Model/Armature/Skeleton3D") as Skeleton3D
	assert(sk.find_bone("hand_l") >= 0 and sk.find_bone("hand_r") >= 0)
	if not fixed_bow_loadout:
		player._using_mouse = false
		player._aim_dir = Vector3.FORWARD
	var states := ["idle", "run", "draw", "release", "roll"] if fixed_bow_loadout else ["idle", "walk", "walk_fire", "run", "sprint", "fire", "reload", "roll"]
	for name in states:
		player._sprinting = name == "sprint"
		player.velocity = Vector3.FORWARD * maxf(player.move_speed, animator.walk_switch_speed + .4) if name == "run" else Vector3.ZERO
		if name == "sprint": player.velocity = Vector3.FORWARD * player.sprint_speed
		if name in ["walk", "walk_fire"]:
			player.velocity = Vector3.FORWARD * player.shoot_move_speed
		player.rotation = Vector3.ZERO
		player._firing = name in ["draw", "release", "fire", "walk_fire"]
		player._bow_draw_elapsed = player.bow_draw_time * 0.95 if name == "draw" else 0.0
		player._bow_release_left = player.bow_release_time * .76 if name == "release" else 0.0
		if name == "release": player._shoot(player.current_weapon())
		if name in ["fire", "walk_fire"]:
			player._using_mouse = false
			player._aim_dir = Vector3.FORWARD
			player._shoot(player.current_weapon())
		if name == "reload": animator._on_reload_started(2.0)
		if name == "roll":
			animator._on_reload_cancelled()
			player._start_dodge(Vector3.FORWARD)
			player._dodge_left = player.dodge_duration * 0.55
			player._roll_elapsed = player.dodge_duration * 0.45
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		if name in ["walk", "walk_fire"]:
			assert(animator._state == &"Walk", "Expected forward walk, got " + animator._state)
			print("WALKING1_MIX_OK speed=", player.velocity.length(), " upper=", animator.get("parameters/upper/blend_amount"), " rate=", animator.get("parameters/legs_speed/scale"))
		if not fixed_bow_loadout and name in ["run", "sprint"]:
			assert(animator._state == (&"Sprint" if name == "sprint" else &"Run"))
			var clip_name := &"SP_sprint_forward" if name == "sprint" else &"SP_run_forward"
			var expected := "res://animation/Fast Run (1).fbx"
			if preview_library == "res://assets/animations/model1_shooter.tres":
				expected = "res://animation/Pro Rifle Pack/" + ("sprint forward.fbx" if name == "sprint" else "run forward.fbx")
			assert(animator.get_animation(clip_name).get_meta("source_file", "") == expected)
			print("FAST_RUN1_MIX_OK state=", animator._state, " speed=", player.velocity.length())
		get_viewport().get_texture().get_image().save_png("res://docs/screens/" + capture_prefix + "_" + name + ".png")
		print("HUNTRESS_CAPTURE ", name, " state=", animator._state, " hand=", sk.get_bone_global_pose(sk.find_bone("hand_r")).origin)
		if not fixed_bow_loadout:
			if sk.has_node("StanceWidth") and name != "roll":
				var stance := sk.get_node("StanceWidth")
				assert(stance.last_width_after < stance.max_width + .01)
				assert(stance.last_foot_error < .015)
				print("STANCE_OK ", name, " before=", stance.last_width_before, " after=", stance.last_width_after, " foot_error=", stance.last_foot_error)
			for modifier in sk.get_children():
				if modifier.get_script() == preload("res://scripts/weapon_support_modifier.gd"):
					print("GRIP_SAMPLE weapon=", player.current_weapon().display_name, " state=", name, " weight=", modifier._weight, " error=", modifier.last_error)
					if modifier._weight > .99: assert(modifier.last_error < .015, "Support hand does not reach the weapon")
					if name in ["sprint", "reload", "roll"]: assert(modifier._weight < .01)
			assert(player.get_node("RightHand").bone_idx == sk.find_bone("hand_r"))
			if name == "idle": assert(player.get_node("RightHand").global_position.y > 0.8)
			for model in player.gun.get_children():
				if model.is_queued_for_deletion(): continue
				var tip := model.get_node_or_null("MuzzleTip") as Marker3D
				if tip != null:
					assert(player._muzzle_local.distance_to(player.gun.to_local(tip.global_position)) < 0.001)
	print("HUNTRESS_PREVIEW_OK")
	get_tree().quit()

