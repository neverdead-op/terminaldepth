extends Node

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var intro := player.get_parent()
	assert(intro.garden_floor_texture != null)
	assert(is_equal_approx(intro.garden_floor_tile_meters, 6.0))
	assert(Game.testing)
	await get_tree().create_timer(6).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/garden_floor_stylized.png")
		print("GARDEN_FLOOR_OK: original stylized texture, 6m world repeat, campaign saves disabled")
		get_tree().quit()
