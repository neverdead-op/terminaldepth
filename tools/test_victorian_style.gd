extends Node

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(2, &"normal", "res://scenes/tools/victorian_courtyard.tscn")
	player.show_message("Проба стиля: викторианский двор. Сохранение отключено.", 5.0)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(24, 100)
	label.text = "ПРОБА СТИЛЯ · Викторианский двор\nWASD — движение · мышь — прицел · пробел — перекат"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	canvas.add_child(label)
	await get_tree().create_timer(6).timeout
	assert(Game.testing)
	assert(player.global_position.y > -1)
	print("VICTORIAN_STYLE_OK: real 3D courtyard loaded, player grounded, campaign saving disabled")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/victorian_courtyard.png")
		get_tree().quit()
