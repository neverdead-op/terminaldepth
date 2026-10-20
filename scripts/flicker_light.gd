extends OmniLight3D
## Неисправная лампа: время от времени мигает и гаснет на мгновение. Аварийная — медленно «дышит».

@export_enum("Мигает", "Аварийная") var mode := 0
@export var speed := 1.0

var _base := 1.0
var _time := 0.0
var _next := 0.0


func _ready() -> void:
	_base = light_energy
	_time = randf() * 10.0
	_next = randf_range(0.5, 3.0)


func _process(delta: float) -> void:
	_time += delta * speed
	if mode == 1:
		light_energy = _base * (0.35 + 0.65 * pow(0.5 + 0.5 * sin(_time * 2.4), 2.0))
		return
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(0.04, 0.12) if randf() < 0.6 else randf_range(1.0, 4.0)
		light_energy = _base * (randf_range(0.0, 0.3) if randf() < 0.5 else 1.0)
