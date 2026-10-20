extends Node
## Подсказки «в первый раз» (игра учит сама): когда герой впервые подходит к новому виду объекта —
## обелиску, инкубатору, разлому, роботу-союзнику, сундуку, — в ленте сообщений появляется короткое объяснение.
## Каждая подсказка — один раз за забег. Создаётся из hud.gd.

const HINTS := [
	[&"quest_obelisk", 13.0, "Обелиск культа лечит врагов рядом — разрушьте его, и стая станет уязвимой"],
	[&"quest_nest", 15.0, "Инкубатор выпускает ползунов, пока вы рядом — уничтожьте его"],
	[&"quest_seal", 10.0, "Печать разлома: F / ○ — начать запечатывание. Отбейте все волны врагов"],
	[&"ally_robots", 8.0, "Отключённый робот-союзник: F / ○ — перезапустить, он будет сражаться рядом с вами"],
	[&"chests", 7.0, "Сундук: F / ○ — открыть. Синие и жёлтые сундуки щедрее"],
	[&"quest_escort", 9.0, "Выживший сотрудник: F / ○ — сопроводить. Доведите его до лифта — голубой квадрат на мини-карте"],
]

var player: Node3D
var _shown := {}
var _check := 0.0


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or player == null or not player.is_inside_tree():
		return
	_check = 0.5
	for h in HINTS:
		if _shown.has(h[0]):
			continue
		for node in get_tree().get_nodes_in_group(h[0]):
			if node is Node3D and node.is_inside_tree() and node.global_position.distance_to(player.global_position) < h[1]:
				_shown[h[0]] = true
				player.show_message(h[2], 6.0)
				break
