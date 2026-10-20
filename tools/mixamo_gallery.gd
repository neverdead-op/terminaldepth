extends Node3D
## Просмотр перенесённых анимаций. --capture сохраняет кадры, реальное сохранение не используется.
const Model := preload("res://assets/characters/shooter_model.tscn")
const Animator := preload("res://scripts/player_animator.gd")
const Suit := preload("res://scripts/suit.gd")
var _players: Array[AnimationPlayer] = []

func _ready() -> void:
	set_meta("test_runner", true)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.07, 0.08, 0.10)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.8, 1)
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.8
	add_child(sun)
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(24, 14)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.16, 0.19)
	mesh.material = mat
	floor.mesh = mesh
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(7, 7.5, 15)
	add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14
	camera.current = true
	var clips: Array = [&"SP_run_forward", &"SP_run_backward", &"SP_run_left", &"SP_run_right", &"SC_rifle_aiming_idle", &"SC_firing_rifle", &"MX_Reloading", &"SP_dive_roll"]
	if "--roll" in OS.get_cmdline_user_args():
		clips.fill(&"DR_Dive_Roll" if "--alternate-roll" in OS.get_cmdline_user_args() else &"SP_dive_roll")
	var creatures := "--monsters" in OS.get_cmdline_user_args()
	if creatures:
		clips = [&"Zombie_Idle", &"Zombie_Idle"]
		camera.position = Vector3(4, 3.5, 8)
		camera.look_at(Vector3(0, 1, 0))
		camera.size = 8
	for i in clips.size():
		var model: Node3D = load("res://assets/characters/" + ("parasite" if i == 0 else "mutant") + ".tscn").instantiate() if creatures else Model.instantiate()
		model.position = Vector3((i % 4 - 1.5) * 3.1, 0, (i / 4 - 0.5) * 4.0)
		if creatures:
			model.position = Vector3((i - 0.5) * 3.4, 0, 0)
			model.scale = Vector3.ONE * (0.95 if i == 0 else 1.45)
		add_child(model)
		Suit.apply(model, Color(0.15, 0.65, 0.8), Color(0.20, 0.24, 0.29), Color(0.7, 0.56, 0.4), Color(0.1, 0.12, 0.16))
		var skeleton := model.get_node("Armature/Skeleton3D") as Skeleton3D
		var anim := AnimationPlayer.new()
		model.add_child(anim)
		anim.root_node = NodePath("..")
		anim.add_animation_library(&"", load(model.get_meta("animation_library_path")) if creatures else Animator.fit_library(skeleton, [clips[i]], [clips[i]]))
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		anim.play(clips[i])
		anim.advance(0)
		_players.append(anim)
		var label := Label3D.new()
		label.text = ("Parasite" if i == 0 else "Mutant") if creatures else String(clips[i]).trim_prefix("MX_").replace("_", " ")
		label.font_size = 42
		label.pixel_size = 0.006
		label.position = model.position + Vector3(0, 2.05 if creatures and i == 0 else 3.0 if creatures else 2.35, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	if "--roll" in OS.get_cmdline_user_args():
		set_process(false)
		_roll_capture.call_deferred()
	else:
		_capture.call_deferred()

func _process(delta: float) -> void:
	for ap in _players:
		ap.advance(delta)
		if not ap.is_playing():
			ap.play(ap.assigned_animation)

func _capture() -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	for frame in 4:
		for ap in _players:
			ap.seek(ap.get_animation(ap.assigned_animation).length * (frame + 0.5) / 4, true)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(("res://docs/screens/monsters_%d.png" if "--monsters" in OS.get_cmdline_user_args() else "res://docs/screens/mixamo_%d.png") % frame)
	print("MIXAMO_VISUAL_OK")
	get_tree().quit()

func _roll_capture() -> void:
	if "--roll" not in OS.get_cmdline_user_args():
		return
	for i in _players.size():
		var ap := _players[i]
		var length := ap.get_animation(ap.assigned_animation).length
		print("ROLL_SAMPLE ", i, " time=", length * (i + 0.5) / 8)
		ap.seek(length * (i + 0.5) / 8, true)
		ap.advance(0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screens/alternate_roll.png" if "--alternate-roll" in OS.get_cmdline_user_args() else "res://docs/screens/shooter_roll.png")
	get_tree().quit()
