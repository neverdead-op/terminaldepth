extends Node
func _ready() -> void:
 set_meta("test_runner", true)
 _run.call_deferred()
func _run() -> void:
 var p := Game.start_test(1, &"normal")
 await get_tree().create_timer(1.0).timeout
 assert(p.fixed_bow_loadout and p.current_weapon().projectile == &"wood_arrow")
 var zone := p.get_parent()
 assert(not is_instance_valid(zone._training_gate))
 assert(not zone._hints.has("equip_gate") and not zone._hints.has("rifle"))
 assert(Game.testing)
 print("ARCHERY_CAMPAIGN_OK fixed_bow, tutorial_gate, no_saved_game_writes")
 get_tree().quit()
