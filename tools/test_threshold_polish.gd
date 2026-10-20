extends Node
func _ready() -> void:
	set_meta("test_runner",true)
	_run.call_deferred()
func shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://docs/screens/"+name+".png")
	return image
func _run() -> void:
	var player := Game.start_test(1,&"normal","res://scenes/art/threshold_composition.tscn")
	var zone := player.get_parent()
	await get_tree().create_timer(4).timeout
	var look: Node = zone.get_node("LookController")
	await shot("threshold_concept_pass")
	player.get_node("HUD").hide();zone.get_node("PreviewControls").hide()
	await get_tree().process_frame
	await shot("threshold_concept_clean")
	player.get_node("HUD").show();zone.get_node("PreviewControls").show()
	var original: Resource = look.profile.duplicate(true)
	zone.get_node("FluffyFog").set_process(false)
	look.profile.cel_enabled=false;look.apply()
	await get_tree().process_frame
	var soft: Image = await shot("threshold_cel_comparison_off")
	look.profile.cel_enabled=true;look.profile.cel_amount=1;look.profile.cel_steps=3;look.profile.cel_softness=.06;look.apply()
	await get_tree().process_frame
	var toon: Image = await shot("threshold_cel_comparison_on")
	var error := 0.0;var samples := 0
	for y in range(150,550,4):
		for x in range(200,900,4):
			var a := soft.get_pixel(x,y);var b := toon.get_pixel(x,y)
			error+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);samples+=3
	assert(error/samples>.008,"Cel must visibly change received light on the courtyard")
	look.profile=original;look.apply()
	print("POLISH_VISUAL_OK cel_rgb_difference=",error/samples)
	get_tree().quit()
