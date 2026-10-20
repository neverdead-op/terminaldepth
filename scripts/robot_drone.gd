extends "res://scripts/spitter.gd"
## Охранный дрон-глаз (Sci-Fi Essentials): парит над полом, держит дистанцию и стреляет
## электрическими разрядами. Поведение — как у Плевуна, вид — готовая модель с анимациями.

## Насколько сильно покачивается в воздухе.
@export var hover_bob := 0.12


func _build_visual() -> void:
	_build_model()


func _animate(delta: float, _speed: float) -> void:
	_anim_time += delta
	_visual.position.y = sin(_anim_time * 2.2) * hover_bob
	if _model_anim != null:
		_animate_model(delta, 0.0)  # у дрона нет ходьбы — всегда «парит»


func _on_windup() -> void:
	_play_once(&"Charging", attack_windup)


func _on_attack() -> void:
	_play_once(anim_attack, 0.5)
