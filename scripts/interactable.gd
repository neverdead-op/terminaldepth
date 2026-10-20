extends Node3D
## Основа для всего, с чем игрок взаимодействует кнопкой F / ○ (торговец, верстак, портал).
## Подсказку «F / ○ — …» показывает HUD, когда игрок рядом.

## Что написать в подсказке.
@export var prompt := "Взаимодействовать"
## С какого расстояния можно взаимодействовать (м).
@export var interact_range := 2.6


func _ready() -> void:
	add_to_group("interactables")


func interact(_player: Node) -> void:
	pass
