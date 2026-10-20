extends Node

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.5).timeout
	await Game.complete_zone(player)
	await get_tree().create_timer(0.5).timeout
	var hub := player.get_parent()
	var props := 0
	for node in hub.get_node("Geometry").get_children():
		if not node is StaticBody3D or not String(node.name).begins_with("Prop"): continue
		var visual: Node3D
		for child in node.get_children():
			if child.get_script() == preload("res://scripts/model_batch.gd"): visual = child
		assert(visual != null)
		assert(visual.get_script().is_tool())
		assert(not visual.get_children().is_empty())
		props += 1
	assert(props == 13)
	var table: Node3D = hub.get_node("Geometry/Prop12")
	var initial := table.transform
	var shape: CollisionShape3D = table.get_node("Shape")
	var visual: Node3D = table.get_child(1)
	var mesh: MultiMeshInstance3D = visual.get_child(0)
	var model_at := mesh.global_transform * mesh.multimesh.get_instance_transform(0)
	var collision_at := shape.global_transform
	table.position += Vector3(1.3, 0, -0.5)
	var model_moved := mesh.global_transform * mesh.multimesh.get_instance_transform(0)
	assert(model_moved.origin.is_equal_approx(model_at.origin + Vector3(1.3, 0, -0.5)))
	assert(shape.global_position.is_equal_approx(collision_at.origin + Vector3(1.3, 0, -0.5)))
	table.rotation.y += 0.6
	var saved_transform := table.transform
	var packed := PackedScene.new()
	assert(packed.pack(hub) == OK)
	assert(ResourceSaver.save(packed, "res://work/hub_movement_probe.tscn") == OK)
	var restored: Node3D = (load("res://work/hub_movement_probe.tscn") as PackedScene).instantiate()
	assert(restored.get_node("Geometry/Prop12").transform.is_equal_approx(saved_transform))
	assert(restored.get_node("Geometry/Prop12").get_child_count() == 2)
	restored.free()
	table.transform = initial
	print("EDITABLE_HUB_OK: 13 props visible in editor, table/model/collision move and rotate together, saved placement reloads")
	get_tree().quit()
