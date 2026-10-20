extends Node
const ROOT := "res://assets/environment/level1_supplied/"
var stage:Node3D
var region:NavigationRegion3D
func _ready() -> void:_run.call_deferred()
func _own(parent:Node) -> void:
 for child in parent.get_children():
  child.owner=stage
  if child.scene_file_path.is_empty():_own(child)
func _run() -> void:
 Game.testing=true
 stage=Node3D.new();stage.name="Level1Supplied";stage.set_script(load("res://scripts/level1_supplied.gd"))
 # Avoid running gameplay while constructing the editable scene.
 get_tree().root.add_child(stage);stage.set_process(false);stage.set_process_unhandled_key_input(false)
 region=NavigationRegion3D.new();region.name="Navigation";stage.add_child(region)
 var nav:=NavigationMesh.new();nav.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
 nav.agent_height=2.0;nav.agent_radius=.5;nav.agent_max_climb=.75;nav.agent_max_slope=48;nav.cell_size=.25;nav.cell_height=.25;nav.region_min_size=3.0
 region.navigation_mesh=nav
 var model:Node3D=load(ROOT+"level1_visual.glb").instantiate();model.name="SuppliedMap";model.set_script(load("res://scripts/level1_material_preview.gd"));region.add_child(model)
 var collider:Node3D=load(ROOT+"level1_collision.glb").instantiate()
 var mesh:MeshInstance3D=collider.find_child("*",true,false) as MeshInstance3D
 if mesh==null:
  for node in collider.find_children("*","MeshInstance3D",true,false):mesh=node;break
 assert(mesh!=null)
 var body:=StaticBody3D.new();body.name="MapCollision";body.collision_layer=1;body.collision_mask=0;region.add_child(body)
 var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();shape.transform=mesh.transform;body.add_child(shape)
 var doors := [AABB(Vector3(-3,-1,-10.6),Vector3(6,4.4,5.0)), AABB(Vector3(19.4,-1,8.4),Vector3(6.2,4.4,6.0))]
 var faces := (shape.shape as ConcavePolygonShape3D).get_faces()
 var filtered := PackedVector3Array()
 for i in range(0,faces.size(),3):
  var center := (faces[i]+faces[i+1]+faces[i+2])/3.0
  var remove := false
  for door in doors:
   if door.has_point(center): remove=true;break
  if not remove: filtered.append_array(faces.slice(i,i+3))
 (shape.shape as ConcavePolygonShape3D).set_faces(filtered)
 for door in doors:
  var patch := StaticBody3D.new();patch.name="DoorwayRepair";patch.position=Vector3(door.get_center().x,.435,door.get_center().z);patch.collision_layer=1;region.add_child(patch)
  var box := BoxShape3D.new();box.size=Vector3(door.size.x,.25,door.size.z)
  var collision := CollisionShape3D.new();collision.shape=box;patch.add_child(collision)
  var floor_mesh := MeshInstance3D.new();var floor_box := BoxMesh.new();floor_box.size=box.size
  var mat := ShaderMaterial.new();mat.shader=load(ROOT+"stone_preview.gdshader");floor_box.material=mat;floor_mesh.mesh=floor_box;patch.add_child(floor_mesh)
 assert(ResourceSaver.save(shape.shape,ROOT+"level1_collision.res",ResourceSaver.FLAG_CHANGE_PATH)==OK);shape.shape.take_over_path(ROOT+"level1_collision.res");collider.free()
 var env:=WorldEnvironment.new();env.name="WorldEnvironment";env.environment=Environment.new()
 var e:=env.environment;e.background_mode=Environment.BG_COLOR;e.background_color=Color(.004,.009,.014);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.48,.57,.68);e.ambient_light_energy=.65;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;e.ssao_enabled=true;e.ssao_intensity=1.2
 e.fog_enabled=true;e.fog_density=.0018;e.fog_light_color=Color(.008,.02,.028)
 stage.add_child(env)
 var moon:=DirectionalLight3D.new();moon.name="Moonlight";moon.rotation_degrees=Vector3(-50,-35,0);moon.light_color=Color(.62,.75,.9);moon.light_energy=.65;moon.shadow_enabled=true;stage.add_child(moon)
 for p in [Vector3(3,2,47),Vector3(3,2,35),Vector3(-8,2,24),Vector3(-28,2,20),Vector3(-34,2,3),Vector3(-9,2,-2),Vector3(-14,2,-24),Vector3(3,3,-10),Vector3(25,3,-8),Vector3(40,3,-10),Vector3(11,3,14),Vector3(37,3,12),Vector3(22,3,-22),Vector3(4,3,-31),Vector3(11,3,-43)]:
  var lamp:=OmniLight3D.new();lamp.position=p;lamp.light_color=Color(1,.49,.19);lamp.light_energy=4.0;lamp.omni_range=10;lamp.omni_attenuation=1.3;lamp.shadow_enabled=false;stage.add_child(lamp)
 var spawn:=Marker3D.new();spawn.name="Spawn";spawn.position=Vector3(3.5,.4,51);stage.add_child(spawn)
 var rig:=Node3D.new();rig.name="CameraRig";rig.set_script(load("res://scripts/camera_rig.gd"));rig.distance=12.5
 var camera:=Camera3D.new();camera.name="Camera3D";camera.fov=60;camera.current=true;rig.add_child(camera);stage.add_child(rig)
 var overview:=Camera3D.new();overview.name="OverviewCamera";stage.add_child(overview);overview.position=Vector3(95,112,125);overview.look_at(Vector3(0,0,0));overview.projection=Camera3D.PROJECTION_ORTHOGONAL;overview.size=90
 var pool:=Node3D.new();pool.name="BulletPool";pool.set_script(load("res://scripts/bullet_pool.gd"));pool.bullet_scene=load("res://scenes/bullet.tscn");pool.pool_size=0;pool.add_to_group("bullet_pool",true);stage.add_child(pool);pool.pool_size=240
 await get_tree().process_frame
 region.bake_navigation_mesh(false)
 assert(nav.get_polygon_count()>0)
 await get_tree().physics_frame;await get_tree().physics_frame
 await get_tree().create_timer(.4).timeout
 var map:=stage.get_world_3d().navigation_map
 for attempt in 120:
  if NavigationServer3D.region_get_iteration_id(region.get_rid())>0:break
  await get_tree().physics_frame
 NavigationServer3D.map_force_update(map)
 print("REGION_DEBUG iteration=",NavigationServer3D.region_get_iteration_id(region.get_rid())," mesh_vertices=",nav.get_vertices().size()," sample=",nav.get_vertices()[0]," enabled=",region.enabled," layers=",region.navigation_layers)
 print("MAP_DEBUG active=",NavigationServer3D.map_is_active(map)," iteration=",NavigationServer3D.map_get_iteration_id(map)," regions=",NavigationServer3D.map_get_regions(map).size())
 var start:=NavigationServer3D.map_get_closest_point(map,spawn.position)
 spawn.position=start+Vector3.UP*.15
 var end:=NavigationServer3D.map_get_closest_point(map,Vector3(11,1,-44))
 var path:=NavigationServer3D.map_get_path(map,start,end,true)
 print("LEVEL1_NAV initial start=",start," finish=",end," path=",path.size()," nav_polygons=",nav.get_polygon_count())
 stage.finish_position=end
 stage.exit_position=Vector2(end.x,end.z)
 stage.route_points=path
 var points:Array[Vector3]=[]
 for z in range(-47,52,3):
  for x in range(-40,44,3):
   var candidate:=Vector3(x,0,z)
   var at:=NavigationServer3D.map_get_closest_point(map,candidate)
   if Vector2(at.x-x,at.z-z).length()>.65 or at.y>2.5 or at.y<-.8 or at.distance_to(start)<7 or at.distance_to(end)<3:continue
   var p:=NavigationServer3D.map_get_path(map,start,at,true)
   if p.size()<2 or p[-1].distance_to(at)>.5:continue
   var valid:=true
   for other in points:
    if other.distance_to(at)<2.4:valid=false;break
   if valid:points.append(at)
 # Deterministic interleaving distributes packs over the whole connected route.
 var ordered:=PackedVector3Array()
 points.sort_custom(func(a:Vector3,b:Vector3):return hash(a)<hash(b))
 for point in points:ordered.append(point)
 stage.candidate_spawns=ordered
 stage.map_rects.clear()
 stage.map_rects.append(Rect2(start.x-3,start.z-5,6,10))
 stage.map_rects.append(Rect2(end.x-5,end.z-5,10,10))
 for p in points:stage.map_rects.append(Rect2(p.x-1.5,p.z-1.5,3,3))
 for data in [["НАЧАЛО",start],["ТАВЕРНА «ПОСЛЕДНИЙ ОГОНЬ»",end]]:
  var label:=Label3D.new();label.text=data[0];label.position=data[1]+Vector3.UP*4;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=36;label.pixel_size=.006;label.modulate=Color(1,.78,.43);stage.add_child(label)
 print("LEVEL1_NAV candidates=",points.size()," route_end=",path[-1] if path.size()>0 else Vector3.ZERO)
 assert(ResourceSaver.save(nav,ROOT+"level1_navigation.res",ResourceSaver.FLAG_CHANGE_PATH)==OK)
 nav.take_over_path(ROOT+"level1_navigation.res")
 _own(stage)
 var packed:=PackedScene.new();assert(packed.pack(stage)==OK);assert(ResourceSaver.save(packed,"res://scenes/art/level1_supplied.tscn")==OK)
 var report:={"start":[start.x,start.y,start.z],"finish":[end.x,end.y,end.z],"nav_polygons":nav.get_polygon_count(),"route_points":path.size(),"candidates":points.size()}
 var file:=FileAccess.open("res://work/level1_nav_report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("LEVEL1_SCENE_BUILT")
 stage.free();get_tree().quit()
