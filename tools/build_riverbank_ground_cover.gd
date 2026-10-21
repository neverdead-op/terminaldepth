extends RefCounted
## Размещение по той же размытой карте весов, что использует материал пола.
const Layout := preload("res://scripts/riverbank_layout.gd")
static func populate(parent: Node3D, scene_owner: Node, ground: ShaderMaterial) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 82611
	var points: Array[Transform3D] = []
	var weights: Image = ground.get_shader_parameter("splat_a").get_image()
	var rect: Vector4 = ground.get_shader_parameter("splat_rect")
	for attempt in 41000:
		var at := Vector2(rng.randf_range(-65,59),rng.randf_range(-84,17))
		if at.x < Layout.shore_x(at.y)+1: continue
		var uv := (at-Vector2(rect.x,rect.y))/Vector2(rect.z,rect.w)
		var pixel := Vector2i(clampi(int(uv.x*weights.get_width()),0,weights.get_width()-1),clampi(int(uv.y*weights.get_height()),0,weights.get_height()-1))
		if weights.get_pixelv(pixel).g < .7: continue
		if Layout.on_land(at) and not Layout.on_land(at,.8): continue
		var center := false
		for p: Vector3 in Layout.PACKS+[Layout.START,Layout.FINISH]:
			if at.distance_to(Vector2(p.x,p.z))<5.5: center = true
		if center: continue
		var scale := rng.randf_range(.7,1.25)
		points.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale),Vector3(at.x,.025,at.y)))
	var instance := Node3D.new()
	instance.set_script(preload("res://scripts/riverbank_ground_cover.gd"))
	instance.set("placements",points)
	instance.name = "GrassTufts"
	parent.add_child(instance)
	instance.owner = scene_owner
	print("RIVERBANK_GRASS_OK tufts=",points.size())
