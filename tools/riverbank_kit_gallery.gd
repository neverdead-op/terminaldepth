extends Node3D
## Снимок реального набора моделей, без игрока и без записи профиля.
func _ready() -> void:
	Game.testing = true
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/kit_models.png")
		get_tree().quit()
