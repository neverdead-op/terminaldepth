extends "res://scripts/interactable.gd"
## Портал. Раскрывается из точки (анимация + звук), срабатывает, когда игрок в него входит
## (или по F / ○ рядом). destination: &"hub" — на базу, &"zone" — обратно в зону.
## На базе стоит постоянно; в зоне его открывает кнопка H / L3 (Game.open_town_portal).
## Если игрок появился прямо у портала — тот не сработает, пока игрок не отойдёт.

@export var destination := &"zone"
## Сколько секунд портал раскрывается.
@export var open_time := 0.8

var wait_for_exit := false
var _ring: MeshInstance3D
var _visual: Node3D
var _time := 0.0
var _ready_to_use := false


func _ready() -> void:
	super()
	prompt = "Портал в зону" if destination == &"zone" else "Портал на базу"
	_build()
	_visual.scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _ready_to_use = true)
	Sfx.play(&"portal_open", global_position)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.9
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time += delta
	_ring.rotation.z = _time * 0.8


func interact(player: Node) -> void:
	_use(player)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not wait_for_exit:
		_use(body)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		wait_for_exit = false


func _use(player: Node) -> void:
	if not _ready_to_use or Game.is_transitioning():
		return
	Sfx.play(&"portal_enter", global_position)
	if destination == &"hub":
		Game.go_to_hub(player)
	else:
		Game.return_to_zone()


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.8, 1.0)
	glow.emission_energy_multiplier = 3.0
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.2
	torus.material = glow
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.position.y = 1.4
	_ring.rotation.x = PI * 0.5
	_visual.add_child(_ring)
	var core := StandardMaterial3D.new()
	core.albedo_color = Color(0.2, 0.5, 1.0, 0.35)
	core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.emission_enabled = true
	core.emission = Color(0.2, 0.55, 1.0)
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.material = core
	var inner := MeshInstance3D.new()
	inner.mesh = disc
	inner.position.y = 1.4
	inner.rotation.x = PI * 0.5
	_visual.add_child(inner)
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.8, 1.0)
	light.position = Vector3(0, 1.4, 0.8)
	light.omni_range = 6.0
	light.light_energy = 2.0
	_visual.add_child(light)
