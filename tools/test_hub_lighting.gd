extends Node
## F6 on this test scene: safe graphics comparison, never writes campaign saves.
@export var high_quality := true
@export var baked_enabled := true
var hub: Node3D
var gi: LightmapGI
var light_data: LightmapGIData
var label: Label
var reflection: ReflectionProbe

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal", "res://scenes/tools/hub_lightmap_preview.tscn")
	hub = player.get_parent()
	gi = hub.get_node("BakedLighting")
	light_data = gi.light_data
	if light_data == null:
		push_error("Bake BakedLighting in hub_lightmap_preview.tscn and save the scene first.")
		get_tree().quit(1)
		return
	reflection = ReflectionProbe.new()
	reflection.name = "InteriorReflection"
	reflection.position = Vector3(0, 1.6, 0)
	reflection.size = Vector3(16, 6, 12)
	reflection.box_projection = true
	reflection.interior = true
	reflection.intensity = 0.55
	hub.add_child(reflection)
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(310, 15)
	label.add_theme_color_override("font_color", Color(0.85, 0.95, 1))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(label)
	_apply()
	if "--capture" in OS.get_cmdline_user_args():
		player.set_physics_process(false)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for mode in [0, 1, 2]:
			baked_enabled = mode != 0
			high_quality = mode == 2
			_apply()
			await get_tree().create_timer(3.0).timeout
			var start := Time.get_ticks_usec()
			for frame in 120: await get_tree().process_frame
			var ms := (Time.get_ticks_usec() - start) / 120000.0
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/screens/hub_lighting_%s.png" % mode)
			print("HUB_LIGHTING mode=", mode, " mean_frame_ms=", snappedf(ms, 0.01), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("HUB_LIGHTING_OK: baked data loaded, three graphics modes rendered, campaign saves disabled")
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F2:
		baked_enabled = not baked_enabled
		_apply()
	elif event.keycode == KEY_F3:
		high_quality = not high_quality
		_apply()

func _apply() -> void:
	gi.light_data = light_data if baked_enabled else null
	var env: Environment = hub.get_node("WorldEnvironment").environment
	env.ambient_light_energy = 0.35 if baked_enabled else 0.95
	env.ssr_enabled = high_quality
	get_viewport().msaa_3d = Viewport.MSAA_4X if high_quality else Viewport.MSAA_DISABLED
	reflection.visible = high_quality
	label.text = "F2: запечённый свет %s  |  F3: отражения и сглаживание %s" % ["ВКЛ" if baked_enabled else "ВЫКЛ", "ВКЛ" if high_quality else "ВЫКЛ"]
