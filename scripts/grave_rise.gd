extends RefCounted
## Подъём мертвецов: на земле загорается фиолетовый круг, идёт дым, и враг выползает из-под земли.
## Используют некромант, привратник и засады после сундуков/обелисков.

const COLOR := Color(0.62, 0.3, 1.0)


## setup(enemy) вызывается до добавления врага в сцену — там задают здоровье, урон и т. п.
static func raise(parent: Node3D, scene: PackedScene, at: Vector3, setup := Callable(), delay := 0.75) -> void:
	var map := parent.get_world_3d().navigation_map
	var snapped := NavigationServer3D.map_get_closest_point(map, at)
	if snapped.distance_to(at) < 6.0:  # точка в стене — ближайший пол рядом
		at = snapped
	var mark := _mark(parent, at)
	Fx.flipbook(&"smoke", at + Vector3.UP * 0.4, 2.4, 1.1, Color(0.32, 0.2, 0.45))
	Sfx.play(&"zombie_growl", at)
	# Задержка привязана к уровню: ушли с уровня — подъём не случится.
	var wait := parent.create_tween()
	wait.tween_interval(delay)
	wait.tween_callback(func() -> void:
		var enemy: Enemy = scene.instantiate()
		enemy.position = at + Vector3.UP * 0.1
		enemy.start_awake = true
		enemy.xp_reward = 0
		enemy.drops_enabled = false
		enemy.add_to_group("raised_dead")
		if setup.is_valid():
			setup.call(enemy)
		parent.add_child(enemy)
		# Выползает: модель поднимается из-под пола, пока враг уже идёт к цели.
		var visual := enemy.get("_visual") as Node3D
		if visual != null:
			visual.position.y = -1.6
			enemy.create_tween().tween_property(visual, "position:y", 0.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		Fx.flipbook(&"spark", at + Vector3.UP * 0.3, 2.0, 0.35, COLOR, true, true)
		Fx.hit(at + Vector3.UP * 0.2, Vector3.UP, Color(0.25, 0.18, 0.12), 10)
		if is_instance_valid(mark):
			var fade := mark.create_tween()
			fade.tween_property(mark, "scale", Vector3(1.6, 1, 1.6), 0.5)
			fade.tween_callback(mark.queue_free))


static func _mark(parent: Node3D, at: Vector3) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 2.6)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = preload("res://assets/vfx/circle_05.png")
	material.albedo_color = Color(COLOR, 0.0)
	quad.material = material
	mark.mesh = quad
	mark.rotation.x = -PI / 2
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.global_position = at + Vector3.UP * 0.05
	mark.create_tween().tween_property(material, "albedo_color:a", 0.85, 0.5)
	return mark
