extends Node
func _ready() -> void:
	set_meta("test_runner",true)
	_run.call_deferred()
func _run() -> void:
	Game.start_test(1,&"normal","res://scenes/art/threshold_composition.tscn")
