extends Control
## Реакция экрана на урон по игроку, как в большинстве экшенов:
## красная вспышка по краям экрана (сильнее при большом уроне), капли крови по краям, которые тают,
## пульсирующая красная рамка, когда здоровья мало. Удар по энергощиту — короткая голубая вспышка.

@export var flash_color := Color(0.8, 0.0, 0.0)
@export var shield_color := Color(0.3, 0.6, 1.0)
## Ниже какой доли здоровья экран начинает пульсировать.
@export_range(0.0, 1.0) var low_hp_threshold := 0.3
## Сколько секунд тают капли крови.
@export var splat_life := 2.5

var player: Node
var _flash := 0.0
var _shield_flash := 0.0
var _time := 0.0
var _splats: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.damaged.connect(_on_damaged)


func _on_damaged(hp_lost: float, shield_lost: float) -> void:
	var share := hp_lost / maxf(player.max_hp, 1.0)
	if hp_lost > 0.0:
		_flash = minf(_flash + 0.25 + share * 1.5, 0.9)
		for i in clampi(int(share * 12.0) + 1, 1, 3):
			_add_splat()
	if shield_lost > 0.0:
		_shield_flash = minf(_shield_flash + 0.5, 0.8)


## Капля крови у случайного края экрана: несколько кругов разного размера.
func _add_splat() -> void:
	var p := Vector2(randf(), randf())
	match randi() % 4:
		0: p.x = randf_range(0.0, 0.15)
		1: p.x = randf_range(0.85, 1.0)
		2: p.y = randf_range(0.0, 0.15)
		_: p.y = randf_range(0.85, 1.0)
	var blobs := []
	var base := randf_range(9.0, 24.0)
	for i in randi_range(4, 8):
		blobs.append([Vector2(randf_range(-1, 1), randf_range(-1, 1)) * base * 1.2, base * randf_range(0.25, 0.7)])
	_splats.append({"pos": p, "blobs": blobs, "life": splat_life})


func _process(delta: float) -> void:
	_time += delta
	_flash = move_toward(_flash, 0.0, delta * 2.2)
	_shield_flash = move_toward(_shield_flash, 0.0, delta * 3.0)
	for s in _splats:
		s.life -= delta
	_splats = _splats.filter(func(s): return s.life > 0.0)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var ratio: float = player.hp / maxf(player.max_hp, 1.0)
	var low := 0.0
	if ratio < low_hp_threshold and not player.is_dead():
		low = (1.0 - ratio / low_hp_threshold) * (0.35 + 0.25 * sin(_time * 5.0))
	_vignette(flash_color, maxf(_flash * 0.8, low))
	if _shield_flash > 0.0:
		_vignette(shield_color, _shield_flash * 0.5)
	for s in _splats:
		var alpha: float = clampf(s.life / splat_life, 0.0, 1.0) * 0.7
		var at: Vector2 = s.pos * size
		for b in s.blobs:
			draw_circle(at + b[0], b[1], Color(0.35, 0.0, 0.0, alpha))


## Рамка по краям экрана, плотнее у краёв.
func _vignette(color: Color, strength: float) -> void:
	if strength <= 0.01:
		return
	# Много тонких полупрозрачных слоёв — переход к центру получается плавным, без видимых полос.
	var steps := 24
	var depth := minf(size.x, size.y) * 0.2
	for i in steps:
		var k := float(i) / steps
		var w := depth * (1.0 - k)
		var c := Color(color, strength * 0.07 * (1.0 - k))
		draw_rect(Rect2(0, 0, size.x, w), c)
		draw_rect(Rect2(0, size.y - w, size.x, w), c)
		draw_rect(Rect2(0, 0, w, size.y), c)
		draw_rect(Rect2(size.x - w, 0, w, size.y), c)
