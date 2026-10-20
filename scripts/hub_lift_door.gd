extends "res://scripts/interactable.gd"
## Большая дверь грузового лифта на базе — путь вниз, в сектор. F / ○ рядом: створки разъезжаются,
## за ними тёплый свет шахты — и переход на текущий этаж (Game.return_to_zone).
## Над дверью — табло «ЛИФТ · ЯРУС N» (плашкой, hud_world_labels.gd).

@export var width := 4.4
@export var tavern_exit := false
@export var height := 3.0
@export var glow := Color(1.0, 0.6, 0.25)

var _left: MeshInstance3D
var _right: MeshInstance3D
var _label: Label3D
var _busy := false


func _ready() -> void:
	super()
	interact_range = 3.2
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.17, 0.19)
	metal.metallic = 0.7
	metal.roughness = 0.4
	if tavern_exit:
		metal.albedo_color = Color(0.20, 0.11, 0.065)
		metal.metallic = 0.0
		metal.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.07, 0.08)
	dark.metallic = 0.5
	if tavern_exit:
		dark.albedo_color = Color(0.13, 0.07, 0.045)
		dark.metallic = 0.0
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = glow
	light_mat.emission_enabled = true
	light_mat.emission = glow
	light_mat.emission_energy_multiplier = 2.5
	if tavern_exit:
		light_mat.emission_enabled = false
		light_mat.albedo_color = Color(0.30, 0.19, 0.09)
	# Рама: два столба и перемычка.
	for x in [-width * 0.5 - 0.3, width * 0.5 + 0.3]:
		_box(Vector3(0.6, height, 0.7), Vector3(x, height * 0.5, 0), metal)
		_box(Vector3(0.08, height - 0.4, 0.05), Vector3(x + (0.25 if x < 0 else -0.25), height * 0.5, 0.36), light_mat)
	_box(Vector3(width + 1.2, 0.5, 0.7), Vector3(0, height - 0.25, 0), metal)
	_box(Vector3(width * 0.6, 0.08, 0.05), Vector3(0, height - 0.25, 0.36), light_mat)
	# Шахта за дверью — тёплое свечение (видно, когда створки открыты).
	_box(Vector3(width, height - 0.5, 0.1), Vector3(0, (height - 0.5) * 0.5, -0.3), light_mat)
	# Створки.
	_left = _box(Vector3(width * 0.5, height - 0.5, 0.2), Vector3(-width * 0.25, (height - 0.5) * 0.5, 0.05), dark)
	_right = _box(Vector3(width * 0.5, height - 0.5, 0.2), Vector3(width * 0.25, (height - 0.5) * 0.5, 0.05), dark)
	for panel in [_left, _right]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.1, height - 0.9, 0.02)
		stripe.mesh = stripe_mesh
		stripe.material_override = light_mat
		stripe.position = Vector3(0, 0, 0.11)
		panel.add_child(stripe)
	var lamp := OmniLight3D.new()
	lamp.light_color = glow
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.position = Vector3(0, height - 0.6, 1.2)
	add_child(lamp)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 1.8, height, 0.8)
	shape.shape = box
	shape.position.y = height * 0.5
	body.add_child(shape)
	add_child(body)
	_label = Label3D.new()
	_label.modulate = glow
	_label.position = Vector3(0, height - 0.2, 1.0)
	_label.transparency = 1.0  # рисует плашкой hud_world_labels.gd
	_label.add_to_group("boxed_label")
	add_child(_label)


func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	return mi


func _process(_delta: float) -> void:
	# Над дверью — просто куда ведёт: название следующей локации.
	_label.text = Loc.t(Game.FLOOR_NAMES[Game.floor_number - 1]) if Game.floor_number <= Game.FLOOR_NAMES.size() else ""
	prompt = "Выйти из таверны" if tavern_exit else "Спуститься на лифте"


func interact(_player: Node) -> void:
	if _busy or Game.is_transitioning():
		return
	_busy = true
	Sfx.play(&"door_open", global_position)
	var tw := create_tween().set_parallel()
	tw.tween_property(_left, "position:x", -width * 0.75, 0.6)
	tw.tween_property(_right, "position:x", width * 0.75, 0.6)
	await tw.finished
	Game.return_to_zone()
	# Пока экран затемнён — закрываем створки обратно.
	await get_tree().create_timer(1.0).timeout
	_left.position.x = -width * 0.25
	_right.position.x = width * 0.25
	_busy = false
