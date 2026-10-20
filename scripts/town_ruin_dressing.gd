extends Node3D
## Static adult silhouettes, rubble and derelict stalls. No enemy, XP, death sound or loot code.
const Body = preload("res://assets/environment/town_ruins/adult_body.glb")
const Hanging = preload("res://assets/environment/town_ruins/hanging_body.glb")
const Rubble = preload("res://assets/environment/town_ruins/rubble.glb")
var corpse_count := 0
var hanging_count := 0

func populate(dressing: Node3D) -> void:
	populate_at(dressing, [Vector3(-10, 0, -17), Vector3(-32, 0, -52), Vector3(29, 0, -82), Vector3(-20, 0, -156), Vector3(-13, 0, -221)],
		[Vector3(-15.5, 0.25, -12), Vector3(5.35, 0.4, -17), Vector3(-31.4, 0.4, -45), Vector3(28.6, 0.4, -69), Vector3(-23.6, 0.25, -153), Vector3(13.6, 0.4, -219)],
		[Vector3(-13, 0, -3), Vector3(13, 0, -22), Vector3(-34, 0, -30), Vector3(-35, 0, -58), Vector3(30, 0, -72), Vector3(-20, 0, -140), Vector3(27, 0, -179), Vector3(-30, 0, -217), Vector3(14, 0, -233)],
		[Vector3(-34, 0, -43), Vector3(-22, 0, -57), Vector3(29, 0, -67)])

## Те же завалы по заданным точкам: курганы тел, повешенные, обломки и брошенные лотки.
func populate_at(dressing: Node3D, mounds: Array, hanging: Array, rubble: Array, stalls: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1626
	for at in mounds:
		var mound := Node3D.new()
		mound.position = at
		add_child(mound)
		for i in 10:
			var body := Body.instantiate() as Node3D
			body.position = Vector3(rng.randf_range(-1.4, 1.4), 0.2 + floorf(i / 4.0) * 0.28, rng.randf_range(-0.8, 0.8))
			body.rotation = Vector3(PI * 0.5 + rng.randf_range(-0.18, 0.18), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
			body.scale = Vector3.ONE * rng.randf_range(0.95, 1.1)
			mound.add_child(body)
			corpse_count += 1
		dressing.solid(at + Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 2.4), self)
	for at in hanging:
		var body := Hanging.instantiate() as Node3D
		body.position = at
		body.rotation.y = rng.randf_range(-0.3, 0.3)
		add_child(body)
		var hook := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.7, 0.06, 0.07)
		hook.mesh = bar
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.055, 0.05, 0.045)
		hook.material_override = iron
		hook.position = at + Vector3(-0.3, 2.65, 0)
		add_child(hook)
		hanging_count += 1
	for at in rubble:
		dressing.prop(Rubble, at, Vector3(2.2, 0.7, 1.5), rng.randf() * TAU)
	var stall := preload("res://assets/environment/victorian_kit/v1/market_stall.glb")
	for at in stalls:
		var body: Node3D = dressing.prop(stall, at, Vector3(2.7, 2.35, 1.6), rng.randf_range(-0.2, 0.2))
		var visual := body.get_child(1) as Node3D
		visual.rotation.z = rng.randf_range(-0.15, 0.15)
