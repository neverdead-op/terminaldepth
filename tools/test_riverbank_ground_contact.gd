extends Node
const Module := preload("res://scripts/riverbank_module.gd")

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_meta("test_runner",true)
	get_tree().create_timer(60,true).timeout.connect(func(): get_tree().quit(1))
	run.call_deferred()

func shot(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/"+path+".png")==OK)

func frame_object(camera: Camera3D, object: Node3D, zone: Node, distance := 8.0, height := 6.0) -> void:
	var target := object.global_position+Vector3(0,.35,0)
	var best := 100000.0
	var chosen := Vector3.ZERO
	var light: DirectionalLight3D=zone.get_node("Lighting/RiverbankEnvironment/Moon")
	var towards_light := Vector3(light.global_basis.z.x,0,light.global_basis.z.z).normalized()
	for angle in 12:
		var direction := Vector3(sin(angle*TAU/12),0,cos(angle*TAU/12))
		var position := target+direction*distance+Vector3.UP*height
		var blocked := 0
		for mesh: MeshInstance3D in zone.find_children("*","MeshInstance3D",true,false):
			if object.is_ancestor_of(mesh) or not mesh.is_visible_in_tree(): continue
			var bounds := mesh.global_transform*mesh.get_aabb()
			if bounds.intersects_segment(position,target)!=null: blocked+=1
		var score := float(blocked)*100.0-direction.dot(towards_light)
		if score<best:
			best=score;chosen=position
	camera.global_position=chosen
	camera.look_at(target)
	print("CONTACT_CAMERA blockers=",best," at=",chosen)

func run() -> void:
	var player := Game.start_test(1,&"normal","res://scenes/art/riverbank_blockout.tscn",{"fixed_bow_loadout":false,"start_weapon":&"rifle"})
	var zone := player.get_parent()
	await get_tree().create_timer(1).timeout
	player.set_physics_process(false)
	player.get_node("HUD").hide()
	var contact: Node=zone.get_node("GroundContact")
	var floor: MeshInstance3D=zone.get_node("Geometry/Ground/Floor/Plane")
	var ground: ShaderMaterial=floor.get_active_material(0)
	assert(contact.applied_count>30)
	assert(contact.material.get_shader_parameter("layer1")==ground.get_shader_parameter("layer1"))
	assert(contact.material.get_shader_parameter("splat_a")==ground.get_shader_parameter("splat_a"))
	var wall: Node3D
	var rock: Node3D
	var expected := {}
	var map_rect: Vector4=ground.get_shader_parameter("splat_rect")
	var weights: Image=ground.get_shader_parameter("splat_a").get_image()
	for node in zone.find_children("*","MeshInstance3D",true,false):
		if node.is_visible_in_tree() and not contact.is_ancestor_of(node): expected[node]=node.get_active_material(0)
	for node in zone.find_children("*","Node3D",true,false):
		if node.get_script()!=Module: continue
		var model: PackedScene=node.get("model_scene")
		if model==null: continue
		var path := model.resource_path.to_lower()
		var at := Vector2(node.global_position.x,node.global_position.z)
		var uv := (at-Vector2(map_rect.x,map_rect.y))/Vector2(map_rect.z,map_rect.w)
		var pixel := Vector2i(clampi(int(uv.x*weights.get_width()),0,weights.get_width()-1),clampi(int(uv.y*weights.get_height()),0,weights.get_height()-1))
		if weights.get_pixelv(pixel).g<.45 or node.global_position.y<-.4: continue
		if "wall_straight" in path or "wall_broken" in path:
			if wall==null or at.distance_to(Vector2(-30,-54))<Vector2(wall.global_position.x,wall.global_position.z).distance_to(Vector2(-30,-54)): wall=node
		if rock==null and "rock_small" in path and node.target_size.x>5: rock=node
	print("CONTACT_TARGETS wall=",wall," rock=",rock)
	assert(wall!=null and rock!=null)
	var stale := ShaderMaterial.new()
	stale.shader=preload("res://assets/shaders/riverbank_ground_contact.gdshader")
	wall.find_children("*","MeshInstance3D",true,false)[0].material_overlay=stale
	contact.material=stale
	contact.refresh()
	assert(contact.material.shader.resource_path=="res://assets/shaders/riverbank_contact_skirt.gdshader")
	for mesh in wall.find_children("*","MeshInstance3D",true,false): assert(not contact.owns_overlay(mesh.material_overlay))
	get_tree().paused=true
	var camera := Camera3D.new();zone.add_child(camera);camera.fov=42
	frame_object(camera,wall,zone,4,3);camera.make_current()
	contact.enabled=false;contact.refresh()
	assert(contact.triangle_count==0)
	for mesh in expected: assert(not contact.owns_overlay(mesh.material_overlay) and mesh.get_active_material(0)==expected[mesh])
	await shot("ground_contact_wall_before")
	contact.enabled=true;contact.refresh()
	assert(contact.triangle_count>100)
	for mesh in expected: assert(not contact.owns_overlay(mesh.material_overlay) and mesh.get_active_material(0)==expected[mesh])
	await shot("ground_contact_wall_after")
	wall.rebuild()
	await get_tree().process_frame
	assert(contact.triangle_count>100 and contact.get_node("_GroundSkirts").get_child_count()>0,"Module rebuild lost contact skirts")
	frame_object(camera,rock,zone)
	await shot("ground_contact_rock_after")
	camera.queue_free()
	zone.get_node("CameraRig").position=Vector3(-30,.1,-54)
	zone.get_node("CameraRig/Camera3D").make_current()
	await shot("ground_contact_gameplay")
	var backup: Resource=load("res://data/visual/riverbank_before_ground_contact_20261021.tres")
	assert(is_equal_approx(backup.environment.tonemap_exposure,.92))
	var studio: Node=zone.get_node("PostFXStudio")
	var panel: Control=studio.make_panel();add_child(panel);panel.hide()
	studio.profile.environment.tonemap_exposure=1.7
	var restored := false
	for button: Button in panel.find_children("*","Button",true,false):
		if button.text=="Вернуть свет до переходов":
			button.pressed.emit();restored=true
	assert(restored and is_equal_approx(studio.profile.environment.tonemap_exposure,.92))
	print("GROUND_CONTACT_OK: ",contact.applied_count," meshes, ",contact.triangle_count," skirt triangles; no wall overlay; original materials; disable/rebuild; exposure backup .92")
	get_tree().quit()
