extends Node3D
## Взрыв при смерти врага: искры, ошмётки и вспышка света. Удаляет себя сам.

## Какой звук играть (у разных врагов — разный).
@export var sound := &"explosion"

@onready var sparks: GPUParticles3D = $Sparks
@onready var chunks: GPUParticles3D = $Chunks
@onready var flash: OmniLight3D = $Flash


func _ready() -> void:
	# Чистый бой: без самодельных искр, обломков и вспышки — только звук.
	sparks.emitting = not Fx.clean_combat
	chunks.emitting = not Fx.clean_combat
	if Fx.clean_combat: flash.visible = false
	Sfx.play(sound, global_position)
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.35).from(8.0)
	await get_tree().create_timer(1.5).timeout
	queue_free()
