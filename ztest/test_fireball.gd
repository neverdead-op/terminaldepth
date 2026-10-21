extends Node
## Изолированная проверка навыка, попаданий в цель и дверь, кадр реального рендера.
class Target extends StaticBody3D:
	var hits := 0
	var element: StringName
	var source: Node
	func take_damage(_amount: float, kind: StringName, who: Node) -> void:
		hits += 1
		element = kind
		source = who

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal", "res://ztest/fireball_arena.tscn")
	await get_tree().process_frame
	player.set_physics_process(false)
	player._aim_dir = Vector3.RIGHT
	var skills: Node = player.get_node("Skills")
	var target := Target.new()
	target.collision_layer = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 2.0, 2.0)
	shape.shape = box
	target.add_child(shape)
	player.get_parent().add_child(target)
	target.position = Vector3(4, 1, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(skills.cast_fireball())
	assert(not skills.cast_fireball())
	await get_tree().create_timer(0.4).timeout
	assert(target.hits == 1 and target.element == &"fire" and target.source == player)
	# Дверь непосредственно перед героем перекрывает первый отрезок полёта.
	var door := StaticBody3D.new()
	door.collision_layer = 16
	var door_shape := CollisionShape3D.new()
	door_shape.shape = box
	door.add_child(door_shape)
	player.get_parent().add_child(door)
	door.position = Vector3(0.4, 1, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	skills.fireball_timer = 0.0
	assert(skills.cast_fireball())
	await get_tree().create_timer(0.4).timeout
	assert(target.hits == 1)
	door.queue_free()
	skills.fireball_timer = 0.0
	assert(skills.cast_fireball())
	await get_tree().create_timer(0.1).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://ztest/fireball_capture.png")
	print("FIREBALL_OK: fire damage, source, cooldown, door blocks first segment")
	get_tree().quit()
