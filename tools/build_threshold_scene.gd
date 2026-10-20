extends SceneTree
## Build an editable standalone scene from the original Blender assets.
const KIT := "res://assets/environment/threshold_set/v1/"
var stage: Node3D
var playable: Node3D
var distant: Node3D
var cache := {}
var lamp_number := 0
var model_count := 0

func _skyline(id: String, at: Vector3, angle: float, size: float, fade: float) -> void:
	var model := (load("res://assets/environment/threshold_skyline/v1/"+id+".glb") as PackedScene).instantiate() as Node3D
	distant.add_child(model)
	model.position = at;model.rotation.y = deg_to_rad(angle);model.scale = Vector3.ONE*size
	model.add_to_group("threshold_skyline",true)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as StandardMaterial3D
			var key := "skyline"+source.resource_name+str(fade)
			if not cache.has(key):
				var material := ShaderMaterial.new();material.shader = load("res://assets/shaders/threshold_skyline.gdshader")
				material.set_shader_parameter("atlas",load("res://assets/environment/threshold_skyline/v1/skyline_albedo_1024.png"))
				material.set_shader_parameter("layer_fade",fade)
				material.set_shader_parameter("window_glow",source.resource_name.contains("Warm_window"))
				cache[key] = material
			mesh.set_surface_override_material(i,cache[key])

func _initialize() -> void: _run.call_deferred()

func _own(node: Node) -> void:
	for child in node.get_children():
		# Fully localise the constructed tree; mixing imported instances and owned
		# replacement children leaves orphan meshes when the packed scene reloads.
		child.scene_file_path = ""
		child.owner = stage
		_own(child)

func _box(parent: Node3D, at: Vector3, size: Vector3, angle := 0.0) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = at
	body.rotation.y = deg_to_rad(angle)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _materials(model: Node3D, lantern := false, polish := false) -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source == null: continue
			var key := ("lamp" if lantern else "polish" if polish else "kit") + source.resource_name
			if not cache.has(key):
				var mat := ShaderMaterial.new()
				mat.shader = load("res://assets/shaders/threshold_surface.gdshader")
				mat.set_shader_parameter("atlas",load("res://assets/environment/threshold_lantern/v1/lantern_albedo_2048.png" if lantern else "res://assets/environment/threshold_polish/v1/threshold_albedo_4096.png" if polish else KIT+"threshold_albedo_4096.png"))
				mat.set_shader_parameter("tint",source.albedo_color)
				mat.set_shader_parameter("stone_detail",load("res://assets/environment/threshold_polish/v1/stone_painted.png"))
				mat.set_shader_parameter("stone_amount",.65 if source.resource_name in ["Limestone","Cut_stone"] else 0.0)
				mat.set_shader_parameter("metalness",source.metallic)
				mat.set_shader_parameter("surface_roughness",source.roughness)
				if source.resource_name.contains("Amber"):
					mat.set_shader_parameter("glow_color",Vector3(1,0.72,0.40))
					mat.set_shader_parameter("glow_strength",2.1)
				cache[key] = mat
			mesh.set_surface_override_material(i,cache[key])

func _model(id: String, at: Vector3, parent: Node3D, angle := 0.0, scale_value := Vector3.ONE) -> Node3D:
	var polish := id in ["courtyard_stones","gothic_buttress","abyss_arcade"]
	var directory := "res://assets/environment/threshold_polish/v1/" if polish else KIT
	var model := (load(directory+id+".glb") as PackedScene).instantiate() as Node3D
	model.name = id.to_pascal_case()+str(model_count)
	model_count += 1
	parent.add_child(model)
	model.position = at
	model.rotation.y = deg_to_rad(angle)
	model.scale = scale_value
	_materials(model,false,polish)
	return model

func _light(at: Vector3, energy := 3.0, range_value := 8.0, shadows := false) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "AmberLight"+str(lamp_number)
	lamp_number += 1
	stage.add_child(lamp)
	lamp.position = at
	lamp.light_color = Color(1,0.55,0.23)
	lamp.light_energy = energy
	lamp.omni_range = range_value
	lamp.omni_attenuation = 1.4
	lamp.shadow_enabled = shadows
	lamp.shadow_blur = 1.5
	lamp.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	lamp.light_size = 0.0
	lamp.light_volumetric_fog_energy = 0.6

func _lantern(at: Vector3, scale_value := 0.8, shadows := false) -> void:
	var model := (load("res://assets/environment/threshold_lantern/v1/gothic_lantern.glb") as PackedScene).instantiate() as Node3D
	playable.add_child(model)
	model.position = at
	model.scale = Vector3.ONE*scale_value
	_materials(model,true)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.add_to_group("threshold_lantern_visuals",true)
	# Pole-only shadow proxy: the bulb never sits inside shadow-casting glass/cage.
	var proxy := MeshInstance3D.new();proxy.name = "LanternPoleShadow"
	var pole := CylinderMesh.new();pole.top_radius = .065;pole.bottom_radius = .13;pole.height = 2.4;pole.radial_segments = 8
	proxy.mesh = pole;proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	playable.add_child(proxy);proxy.position = at+Vector3(0,1.4*scale_value,0);proxy.scale = Vector3.ONE*scale_value
	_light(at+Vector3(0,3.19*scale_value,0),3.1,8,shadows)

func _chain(at: Vector3, length: int, parent: Node3D) -> void:
	# One mesh draw per surface for each chain, rather than one node per link.
	var original := _model("chain_1m",Vector3.ZERO,parent)
	var source: MeshInstance3D = original.find_children("*","MeshInstance3D",true,false)[0]
	var mesh := source.mesh.duplicate() as ArrayMesh
	for i in mesh.get_surface_count(): mesh.surface_set_material(i,source.get_active_material(i))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = length
	var mesh_transform := parent.global_transform.affine_inverse()*source.global_transform
	for i in length: multi.set_instance_transform(i,Transform3D(mesh_transform.basis,mesh_transform.origin+Vector3(0,-i,0)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "VerticalChain"
	instance.multimesh = multi
	instance.set_script(load("res://scripts/threshold_chain.gd"))
	instance.set("link_basis",mesh_transform.basis)
	instance.set("link_offset",mesh_transform.origin)
	parent.add_child(instance)
	instance.position = at
	original.free()

func _run() -> void:
	stage = Node3D.new()
	stage.name = "LastHumanThreshold"
	root.add_child(stage)
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_mesh = NavigationMesh.new()
	nav.navigation_mesh.agent_radius = 0.45
	nav.navigation_mesh.agent_max_climb = 0.35
	nav.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.navigation_mesh.geometry_collision_mask = 1
	stage.add_child(nav)
	playable = Node3D.new();playable.name = "Courtyard";nav.add_child(playable)
	distant = Node3D.new();distant.name = "AbyssScenery_NoCollision";stage.add_child(distant)
	# 20 x 16m platform, floor drawn with individual bevelled flagstones.
	for x in [-8,-4,0,4,8]:
		for z in [-6,-2,2,6]: _model("courtyard_stones",Vector3(x,0,z),playable)
	_box(playable,Vector3(0,-0.1,0),Vector3(20,0.3,16))
	for x in [-8,-4,0,4,8]:
		_model("platform_edge_4m",Vector3(x,-0.25,8),playable)
		_model("platform_edge_4m",Vector3(x,-0.25,-8),playable)
	for z in [-6,-2,2,6]:
		_model("platform_edge_4m",Vector3(10,-0.25,z),playable,90)
		_model("platform_edge_4m",Vector3(-10,-0.25,z),playable,90)
	_model("tavern_facade",Vector3(-4,0,-7.8),playable)
	_box(playable,Vector3(-4,3,-8),Vector3(10.6,6,1))
	_model("oak_double_door",Vector3(-4,0,-6.65),playable,20,Vector3(1,1,1))
	_light(Vector3(-4,1.8,-6.0),4.2,6,true)
	_light(Vector3(-7,5.6,-7.0),1.3,5)
	_light(Vector3(-1,5.6,-7.0),1.3,5)
	# Railings and piers: only the near entry opening remains walkable.
	for z in [-6,-2,2,6]:
		_model("iron_railing_4m",Vector3(9.7,0,z),playable,90)
		_model("column_cap",Vector3(9.7,0,z-2),playable)
	_box(playable,Vector3(9.8,.8,0),Vector3(.5,1.6,16))
	for x in [-8,-4,4,8]:
		_model("iron_railing_4m",Vector3(x,0,7.7),playable)
		_model("column_cap",Vector3(x-2,0,7.7),playable)
		_box(playable,Vector3(x,.8,7.8),Vector3(4,1.6,.4))
	_box(playable,Vector3(-9.8,.8,0),Vector3(.5,1.6,16))
	_box(playable,Vector3(3.8,.8,-7.8),Vector3(7.8,1.6,.5))
	for z in [-4,0,4]: _model("wall_4m",Vector3(-10,0,z),playable,90)
	# Entry stair, actual mesh collision for its eight treads.
	var stairs := _model("stair_4m",Vector3(0,0,10),playable)
	var stair_mesh: MeshInstance3D = stairs.find_children("*","MeshInstance3D",true,false)[0]
	var body := StaticBody3D.new();playable.add_child(body)
	var shape := CollisionShape3D.new();shape.shape = stair_mesh.mesh.create_trimesh_shape();body.add_child(shape)
	shape.transform = stair_mesh.global_transform
	_box(playable,Vector3(0,-1.7,13),Vector3(4,.2,2))
	_model("courtyard_stones",Vector3(0,-1.6,14),playable)
	_box(playable,Vector3(0,-1,15.8),Vector3(4,1,.4))
	_box(playable,Vector3(-2.1,-.8,12.5),Vector3(.3,1.5,7))
	_box(playable,Vector3(2.1,-.8,12.5),Vector3(.3,1.5,7))
	_model("arch_gateway",Vector3(-9.6,0,8),distant,25,Vector3(.9,.9,.9))
	# Hoist at the right edge, separate visible lowering cage.
	_model("chain_hoist",Vector3(6,0,-5),playable,0)
	_model("lift_platform",Vector3(6,-2.7,-6.3),distant)
	_box(playable,Vector3(6,1,-5),Vector3(4.3,2,.6))
	for x in [4.75,7.25]: _chain(Vector3(x,5.0,-5.2),16,distant)
	# Furniture deliberately confined to the facade and borders.
	for at in [Vector3(-8.1,0,-6.4),Vector3(-1.1,0,-6.3),Vector3(7.8,0,-6.5)]: _model("barrel",at,playable)
	_model("crate",Vector3(-.5,0,-5.2),playable,15)
	_model("bench",Vector3(-7,0,-6.2),playable)
	for at in [Vector3(-8.6,.05,3),Vector3(7.8,.05,5),Vector3(-2.5,.05,-6.2)]: _model("rubble_cluster",at,playable)
	_model("drain_grate",Vector3(1,.04,4),playable)
	for at in [Vector3(-8,4,-7.36),Vector3(0,6,-7.36),Vector3(-9.5,2,2)]: _model("red_ivy_cluster",at,distant,0,Vector3(1.8,1.8,1.8))
	for at in [Vector3(1,6,-7.3),Vector3(9.6,1.5,1),Vector3(-9.5,5,7.8)]: _model("red_banner",at,distant)
	_lantern(Vector3(-7,0,-4.5),.8,true)
	_lantern(Vector3(3,0,5),.8,true)
	_lantern(Vector3(8,0,-1),.75,false)
	_lantern(Vector3(-5,0,5.5),.65,false)
	# Depth: tiered aqueducts, giant descending chains, tiny expedition lights.
	for tier in 4:
		var y := 5.0-tier*15
		for i in 3:
			var at := Vector3(7-tier*5+i*10,y,-28-tier*5)
			_model("abyss_pier_10m",at,distant,0,Vector3(1,2.3,1))
			_model("abyss_bridge_10m",at+Vector3(5,-8,0),distant,0,Vector3(1.2,1,1))
			if (i+tier)%2 == 0:
				_model("red_banner",at+Vector3(0,-1,1.6),distant,0,Vector3(1.5,1.5,1.5))
				_light(at+Vector3(2,1,0),.6,4)
	for at in [Vector3(12,16,-13),Vector3(20,20,-22),Vector3(27,20,-40)]: _chain(at,95,distant)
	# Separate skyline layers; only broad roof shapes and a few emissive windows.
	var skyline_ids := ["gabled_house","turret_house","gabled_house","needle_belfry","turret_house"]
	for i in 5:
		_skyline(skyline_ids[i],Vector3(-23+i*8,-16,-23-i*2),-12+i*9,1.0,.40)
	for i in 7:
		_skyline("needle_belfry" if i%3==0 else "turret_house",Vector3(-32+i*9,-30,-43-i*2),12+i*7,1.15,.75)
	for i in 4:
		_skyline("gabled_house" if i%2==0 else "needle_belfry",Vector3(3+i*7,-29,-28-i*4),-18,.85,.60)
	for i in 16:
		_model("red_ivy_cluster",Vector3(-8+(i*7%17),.09,-5+(i*5%12)),distant,0,Vector3(.22,.22,.22)).rotation.x = -PI/2
	# Retaining architecture continues beneath the courtyard rather than floating.
	for depth in 3:
		for z in [-5,-1,3,7]:
			_model("wall_4m",Vector3(-11.7,-4.0-depth*4,z),distant,90)
	# Foreground wings frame the playable stage and hide the empty platform underside.
	_model("arch_gateway",Vector3(10,-1,10),distant,-15,Vector3(1.35,1.35,1.35))
	_model("wall_4m",Vector3(-11.5,-1,7),distant,90,Vector3(1.3,1.8,1.2))
	for i in 7:
		_model("red_ivy_cluster",Vector3(8.4+i*.32,1+i*.45,9.7),distant,0,Vector3(1.2,1.2,1.2))
	for x in [-7.6,-.5]:
		_model("wall_4m",Vector3(x,0,-7.16),distant,0,Vector3(.65,.85,.4))
	# Carved architectural framing; all new foreground props remain outside movement.
	for at in [Vector3(-10,0,-7),Vector3(-10,0,0),Vector3(-10,0,7),Vector3(1.7,0,-8.1)]:
		_model("gothic_buttress",at,distant)
	for i in 10:
		_model("red_ivy_cluster",Vector3(-9.6,1.0+i*.47,6.8-i*.18),distant,0,Vector3(1.3,1.3,1.3))
	for i in 9:
		_model("red_ivy_cluster",Vector3(-8.8+i*.9,.09,-6.5),distant,0,Vector3(.42,.42,.42)).rotation.x=-PI/2
	# Repeated gothic galleries and visible warm windows give scale to the drop.
	for tier in 4:
		for col in 3:
			_model("abyss_arcade",Vector3(3+col*12-tier*2,-13-tier*14,-24-tier*7),distant)
			_light(Vector3(3+col*12-tier*2,-5.2-tier*14,-23-tier*7),1.0,4.5)
		for col in 2:
			_model("gothic_buttress",Vector3(8+col*18,-5-tier*14,-23-tier*7),distant,0,Vector3(1.6,1.6,1.6))
	# Cold key with readable near-plane shadows, warm light stays local.
	var env_node := WorldEnvironment.new();env_node.name = "WorldEnvironment"
	var env := Environment.new();env_node.environment = env;stage.add_child(env_node)
	env.background_mode = Environment.BG_COLOR;env.background_color = Color(.009,.025,.037)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color = Color(.32,.47,.56);env.ambient_light_energy = .16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true;env.ssao_intensity = 1.1;env.ssao_radius = 1.2
	env.ssil_enabled = true;env.ssil_intensity = .35
	env.glow_enabled = true;env.glow_intensity = .55;env.glow_hdr_threshold = 1.15
	env.fog_enabled = true;env.fog_light_color = Color(.14,.31,.39);env.fog_light_energy = .65;env.fog_density = .0035
	env.volumetric_fog_enabled = true;env.volumetric_fog_density = .0045
	env.volumetric_fog_albedo = Color(.24,.39,.47);env.volumetric_fog_emission = Color(.002,.006,.010);env.volumetric_fog_length = 180
	for depth in 2:
		var fog := FogVolume.new();fog.name = "AbyssDepthFog"+str(depth)
		fog.size = Vector3(40,32,28);fog.position = Vector3(12,-22-depth*28,-27-depth*8)
		var fog_material := FogMaterial.new();fog_material.density = .028
		fog_material.albedo = Color(.15,.30,.35);fog_material.emission = Color(.005,.025,.035)
		fog.material = fog_material;stage.add_child(fog)
	for i in 2:
		var mist := FogVolume.new();mist.name = "SkylineMist"+str(i)
		mist.size = Vector3(82,22,25);mist.position = Vector3(-4,-8-i*16,-26-i*19)
		var material := FogMaterial.new();material.density = .018+i*.009
		material.albedo = Color(.22,.37,.45);material.emission = Color(.018,.055,.078)
		mist.material = material;stage.add_child(mist)
	var edge_mist := FogVolume.new();edge_mist.name = "CliffEdgeMist"
	edge_mist.size = Vector3(28,6,20);edge_mist.position = Vector3(13,-3,-14)
	var edge_fog := FogMaterial.new();edge_fog.density = .055
	edge_fog.albedo = Color(.2,.34,.43);edge_fog.emission = Color(.008,.028,.04)
	edge_fog.edge_fade = 0.35
	edge_mist.material = edge_fog;stage.add_child(edge_mist)
	# Real three-dimensional animated billows behind the playable deck.
	for entry in [[Vector3(-1,-5,-24),Vector3(38,20,25)],[Vector3(15,-19,-30),Vector3(42,25,29)],[Vector3(-8,-33,-44),Vector3(50,28,32)]]:
		var volume := FogVolume.new();volume.name = "VolumeBillow"+str(stage.get_child_count())
		volume.position = entry[0];volume.size = entry[1]
		var material := ShaderMaterial.new();material.shader = load("res://assets/shaders/threshold_billow_volume.gdshader")
		volume.material = material;stage.add_child(volume)
	# Script is assigned after adding the node so headless packing does not own
	# temporary fog cards. They are built once when the saved scene opens.
	var fluffy := Node3D.new();fluffy.name = "FluffyFog";stage.add_child(fluffy)
	fluffy.set_script(load("res://scripts/threshold_fluffy_fog.gd"))
	var petals := GPUParticles3D.new();petals.name = "DriftingPetals"
	petals.set_script(load("res://scripts/village_petal_rain.gd"));petals.set("petal_count",55)
	stage.add_child(petals);petals.position = Vector3(0,5,0)
	var sun := DirectionalLight3D.new();sun.name = "ColdMoon";stage.add_child(sun)
	sun.rotation_degrees = Vector3(-48,-30,0);sun.light_color = Color(.62,.73,.84);sun.light_energy = .34
	sun.shadow_enabled = true;sun.directional_shadow_max_distance = 55
	var spawn := Marker3D.new();spawn.name = "Spawn";spawn.position = Vector3(0,.2,2);stage.add_child(spawn)
	var rig := Node3D.new();rig.name = "CameraRig";rig.set_script(load("res://scripts/camera_rig.gd"));rig.set("target_path",NodePath("../Player"));rig.set("distance",17.5)
	var cam := Camera3D.new();cam.name = "Camera3D";cam.fov = 50;cam.far = 300;rig.add_child(cam)
	stage.add_child(rig)
	var overview := Camera3D.new();overview.name = "OverviewCamera";stage.add_child(overview)
	overview.position = Vector3(17,20,23);overview.look_at(Vector3(3,-1.8,-3));overview.projection = Camera3D.PROJECTION_PERSPECTIVE;overview.fov = 42;overview.far = 400;overview.current = true
	var lens := CameraAttributesPractical.new();lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 55; lens.dof_blur_far_transition = 35; lens.dof_blur_amount = .045
	overview.attributes = lens
	var pool := Node3D.new();pool.name = "BulletPool";pool.set_script(load("res://scripts/bullet_pool.gd"));pool.set("bullet_scene",load("res://scenes/bullet.tscn"));pool.set("pool_size",100);pool.add_to_group("bullet_pool",true);stage.add_child(pool)
	# This canvas is below HUD layers, so grading does not recolour interface text.
	var grade := CanvasLayer.new();grade.name = "WorldGrade";grade.layer = -10;stage.add_child(grade)
	var screen := ColorRect.new();screen.name = "ColorGrade";screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade_material := ShaderMaterial.new();grade_material.shader = load("res://assets/shaders/threshold_grade.gdshader");screen.material = grade_material;grade.add_child(screen)
	var look_controller := Node.new();look_controller.name = "LookController"
	look_controller.set_script(load("res://scripts/threshold_look_controller.gd"));stage.add_child(look_controller)
	# Navmesh and all placement are saved, visible and editable in Godot.
	_own(stage)
	nav.bake_navigation_mesh(true)
	await nav.bake_finished
	stage.set_script(load("res://scripts/threshold_composition.gd"))
	DirAccess.make_dir_recursive_absolute("res://scenes/art")
	var packed := PackedScene.new();assert(packed.pack(stage)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/art/threshold_composition.tscn")==OK)
	print("THRESHOLD_SCENE_OK: ",model_count," model instances, ",lamp_number," local lights, saved navmesh and editable scene")
	quit()
