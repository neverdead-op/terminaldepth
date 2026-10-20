extends SceneTree
## Просмотр исходных картинок: без преобразования и изменения файлов.
class Gallery extends Control:
	var files: Array[String] = []
	var textures: Array[Texture2D] = []
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1600, 1000), Color(0.045, 0.05, 0.06))
		for i in files.size():
			var p := Vector2((i % 12) * 132, floori(i / 12.0) * 125)
			if textures.size() <= i: textures.append(load(files[i]))
			var texture: Texture2D = textures[i]
			var ts := texture.get_size()
			var scale := minf(116.0 / ts.x, 95.0 / ts.y)
			draw_texture_rect(texture, Rect2(p + Vector2(8, 5), ts * scale), false)
			draw_string(ThemeDB.fallback_font, p + Vector2(4, 115), files[i].get_file().trim_suffix(".png"), HORIZONTAL_ALIGNMENT_LEFT, 130, 10)
func _initialize() -> void:
	root.size = Vector2i(1600, 1000)
	var gallery := Gallery.new()
	for dir in ["res://assets/icons/corp_weapons", "res://assets/icons/gear"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png") and (dir.ends_with("corp_weapons") or f.begins_with("gloves") or f.begins_with("boots") or f.begins_with("body")):
				gallery.files.append(dir + "/" + f)
	root.add_child.call_deferred(gallery)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://ztest/icon_orientation.png")
	quit()
