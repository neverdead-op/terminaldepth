extends "res://tools/level1_playtest.gd"
## Тот же безопасный тест уровня с предоставленным револьвером.
func _start() -> void:
	super._start()
	player.select_weapon(1)
	player.show_message("Револьвер: ЛКМ — выстрел, R — перезарядка, F7 — заново.",6)
	var help:Label=level.get_node("TestControls").get_child(0)
	help.text="1 УРОВЕНЬ • РЕВОЛЬВЕР • ЛКМ — выстрел • R — перезарядка • F7 — заново"

func _check() -> void:
	await get_tree().create_timer(.8).timeout
	for enemy in get_tree().get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	assert(Game.testing and player.current_weapon().icon==&"pistol")
	assert(player.current_weapon().model.resource_path=="res://assets/weapons/supplied_pistol/pistol_visual.tscn")
	var marker:Marker3D=player.gun.get_child(0).get_node("MuzzleTip")
	assert(player._muzzle_local.distance_to(player.gun.to_local(marker.global_position))<.001)
	var ammo:int=player.current_ammo()
	Input.action_press("shoot")
	await get_tree().create_timer(.1).timeout
	Input.action_release("shoot")
	await get_tree().create_timer(.15).timeout
	assert(player.current_ammo()==ammo-1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screens/supplied_pistol_level.png")
	print("SUPPLIED_PISTOL_LEVEL_OK model, muzzle marker, real shot, ammo=",player.current_ammo())
	get_tree().quit()
