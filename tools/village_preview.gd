extends Node
## F6: playable preview without campaign writes; choose the tavern in Inspector if desired.
@export var start_in_tavern := false

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	Game.start_test(2 if start_in_tavern else 1, &"normal", Game.HUB_SCENE if start_in_tavern else Game.INTRO_SCENE)
