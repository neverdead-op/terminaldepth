@tool
extends Node3D
## Soft textured billows in world space. No screen overlay or black smoke sprites.
@export_range(0.0,2.0) var density := 1.0
@export var enabled := true
@export_range(0.0,1.5) var background_density := 0.28
@export var courtyard_tint := Color(0.43,0.52,0.55)
@export var background_tint := Color(0.32,0.47,0.54)
var cards: Array[MeshInstance3D] = []
var bases: Array[Vector3] = []
var strengths: Array[float] = []
var clock := 0.0
var preview_camera: Camera3D

func _ready() -> void:
	# Runtime children are deliberately not packed into the parent scene.
	if not cards.is_empty(): return
	for entry in [
		[Vector3(-7,0.6,3),Vector2(12,6),0.42,true],
		[Vector3(6,0.7,4),Vector2(12,6),0.40,true],
		[Vector3(-5,0.65,-3),Vector2(11,5),0.36,true],
		[Vector3(6,0.85,-4),Vector2(12,6),0.40,true],
		[Vector3(0,0.6,6),Vector2(12,5),0.32,true],
		[Vector3(-9,1.1,0),Vector2(10,6),0.36,true],
		[Vector3(9,0.6,0),Vector2(11,6),0.38,true],
		[Vector3(0,0.65,-5),Vector2(10,5),0.30,true],
		[Vector3(11,-2,-7),Vector2(20,11),0.60,false],
		[Vector3(7,-4,-17),Vector2(27,15),0.65,false],
		[Vector3(-11,-6,-19),Vector2(26,14),0.56,false],
		[Vector3(14,-9,-29),Vector2(30,17),0.66,false],
		[Vector3(-18,-12,-30),Vector2(30,17),0.58,false],
		[Vector3(11,-20,-32),Vector2(34,20),0.64,false],
		[Vector3(-8,-26,-42),Vector2(38,20),0.62,false],
		[Vector3(17,-34,-42),Vector2(38,22),0.67,false]
	]:
		_add_card(entry[0],entry[1],entry[2],entry[3])
	visible = enabled

func _add_card(at: Vector3, size: Vector2, strength: float, near_player: bool) -> void:
	var card := MeshInstance3D.new()
	card.name = "CourtyardMist"+str(cards.size()) if near_player else "AbyssBillow"+str(cards.size())
	var quad := QuadMesh.new();quad.size = size;card.mesh = quad
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new();material.shader = preload("res://assets/shaders/threshold_fog_cloud.gdshader")
	material.set_shader_parameter("cloud_map",preload("res://assets/environment/threshold_fog/v1/fog_cloud.png"))
	material.set_shader_parameter("fog_tint",courtyard_tint if near_player else background_tint)
	material.set_shader_parameter("opacity",strength*density)
	material.set_shader_parameter("phase",cards.size()*1.73)
	material.set_shader_parameter("clear_around_player",near_player)
	material.set_shader_parameter("softness",1.15 if near_player else 4.0)
	card.material_override = material
	add_child(card);card.position = at
	cards.append(card);bases.append(at);strengths.append(strength)

func _process(delta: float) -> void:
	visible = enabled
	if not enabled: return
	var camera := preview_camera if Engine.is_editor_hint() and is_instance_valid(preview_camera) else get_viewport().get_camera_3d()
	if camera == null: return
	clock += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for i in cards.size():
		var card := cards[i]
		card.position = bases[i]+Vector3(sin(clock*0.055+i*1.4)*0.85,sin(clock*0.07+i)*0.10,cos(clock*0.045+i)*0.55)
		card.look_at(camera.global_position,Vector3.UP,true)
		card.rotate_object_local(Vector3.FORWARD,deg_to_rad(sin(i*2.7)*(4.0 if i<8 else 11.0)))
		(card.material_override as ShaderMaterial).set_shader_parameter("opacity",strengths[i]*(density if i<8 else background_density))
		if is_instance_valid(player):
			(card.material_override as ShaderMaterial).set_shader_parameter("clear_center",player.global_position)
