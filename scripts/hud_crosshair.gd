extends Control
## Боевые отметки поверх игры. Постоянную стрелку мыши задаёт GameCursor.
## При наведении на врага остаются уголки цели и короткая отметка попадания.

@export var ring_radius := 12.0
@export var color := Color(1.0, 1.0, 1.0, 1.0)
@export var lock_color := Color(1.0, 0.35, 0.25, 1.0)
@export var thickness := 2.5
@export var outline_width := 2.0
@export var arm_length := 9.0
@export var center_radius := 2.0

var player: Node
var _pulse := 0.0


func _ready() -> void:
	# Работает и на паузе: иначе при открытом инвентаре мышь так и осталась бы скрытой.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


func _process(delta: float) -> void:
	_pulse += delta
	var active: bool = player != null and player._using_mouse and not get_tree().paused and not player.is_dead()
	visible = active
	if active:
		queue_redraw()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _draw() -> void:
	var at := get_local_mouse_position()
	var target = player.mouse_target
	var locked: bool = target != null and is_instance_valid(target)
	# Отметка попадания: четыре косых штриха (красные — враг убит).
	var since: int = Time.get_ticks_msec() - player.hit_marker_msec
	if since < 140:
		var k := 1.0 - since / 140.0
		var hm := Color(1.0, 0.25, 0.2, k) if player.hit_marker_kill else Color(1, 1, 1, k)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn: Vector2 = d.normalized()
			draw_line(at + dn * 5.0, at + dn * 9.0, Color(0, 0, 0, k * 0.6), 3.0)
			draw_line(at + dn * 5.0, at + dn * 9.0, hm, 1.4)
	if locked:
		# Уголки вокруг врага.
		var camera := get_viewport().get_camera_3d()
		if camera != null and not camera.is_position_behind(target.global_position):
			var p := camera.unproject_position(target.global_position + Vector3.UP * 0.9)
			var s := 18.0 + sin(_pulse * 10.0) * 1.5
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := p + Vector2(sx, sy) * s
					draw_line(corner, corner - Vector2(sx * 5.0, 0), Color(lock_color, 0.8), 1.4)
					draw_line(corner, corner - Vector2(0, sy * 5.0), Color(lock_color, 0.8), 1.4)
