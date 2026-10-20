extends Node3D
## Волны врагов. Срабатывает один раз, когда игрок входит в зону-триггер.
## Враги вылезают из «вентиляций» — дочерних узлов Marker3D — и сразу бегут к игроку.
## Следующая волна приходит по таймеру или раньше, если от прошлой почти никого не осталось.

@export var enemy_scene: PackedScene
## Иногда вместо обычного врага — другой (например, Плевун среди ползунов).
@export var rare_scene: PackedScene
@export_range(0.0, 1.0) var rare_chance := 0.15
## Сколько врагов в каждой волне, по порядку.
@export var waves: Array[int] = [4, 6, 8]
## Пауза между волнами (сек).
@export var wave_interval := 8.0
## Если живых из этого спаунера осталось не больше — следующая волна сразу.
@export var early_wave_alive := 2
## Пауза между появлениями отдельных врагов внутри волны (сек).
@export var spawn_interval := 0.3
## Зона-триггер: размер и смещение относительно этого узла.
@export var trigger_size := Vector3(6, 2, 4)
@export var trigger_offset := Vector3.ZERO

static var _vent_mesh: Mesh

var _started := false
var _alive := 0
var _points: Array[Node3D] = []


func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			_points.append(child)
			_add_vent(child)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = trigger_size
	shape.shape = box
	shape.position = trigger_offset + Vector3(0, trigger_size.y * 0.5, 0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_trigger)


func _on_trigger(body: Node) -> void:
	if _started or not body.is_in_group("player") or _points.is_empty() or enemy_scene == null:
		return
	_started = true
	_run_waves()


func _run_waves() -> void:
	for count in waves:
		for i in count:
			_spawn_one()
			await get_tree().create_timer(spawn_interval).timeout
		var wait := wave_interval
		while wait > 0.0 and _alive > early_wave_alive:
			await get_tree().create_timer(0.25).timeout
			wait -= 0.25


func _spawn_one() -> void:
	if not is_inside_tree():
		await tree_entered  # игрок ушёл на базу — волна подождёт его возвращения
	var point: Node3D = _points.pick_random()
	var scene := rare_scene if rare_scene != null and randf() < rare_chance else enemy_scene
	var enemy: Node3D = scene.instantiate()
	if "start_awake" in enemy:
		enemy.start_awake = true
	get_parent().add_child(enemy)
	enemy.global_position = point.global_position + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5))
	_alive += 1
	if enemy.has_signal("died"):
		enemy.died.connect(func(): _alive -= 1)
	Sfx.play(&"vent", point.global_position)


## Решётка вентиляции на полу — видно, откуда полезут.
func _add_vent(point: Node3D) -> void:
	if _vent_mesh == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.05, 0.05, 0.05)
		material.emission_enabled = true
		material.emission = Color(0.6, 0.1, 0.05)
		material.emission_energy_multiplier = 0.6
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 0.04, 1.4)
		box.material = material
		_vent_mesh = box
	var vent := MeshInstance3D.new()
	vent.mesh = _vent_mesh
	vent.position = Vector3(0, 0.02, 0)
	point.add_child(vent)
