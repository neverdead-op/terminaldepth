extends "res://scripts/interactable.gd"
## Склад на базе (F / ○): вкладка «Валюта» с ячейкой под каждый фрагмент и вкладки под вещи.
## Сами вещи хранятся в автозагрузке Game (stash_tabs, stash_currency) — склад общий и не пропадает
## при переходах между базой и этажами.

@export var model: PackedScene = preload("res://assets/essentials/Prop_Chest.gltf")
@export var model_scale := 1.4
@export var stash_name := "Склад"


func _ready() -> void:
	super()
	prompt = "Открыть склад"
	interact_range = 2.6
	var inst: Node3D = model.instantiate()
	inst.scale = Vector3.ONE * model_scale
	add_child(inst)
	var anim := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation(&"Idle_Open"):
		anim.play(&"Idle_Open")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.9, 1.0) * model_scale
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	add_child(body)
	var label := Label3D.new()
	label.text = Loc.t(stash_name)
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.85, 0.55)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.8
	label.transparency = 1.0  # рисует плашкой hud_world_labels.gd
	label.add_to_group("boxed_label")
	add_child(label)
	Loc.language_changed.connect(func() -> void: label.text = Loc.t(stash_name))


func interact(player: Node) -> void:
	player.get_node("HUD").inventory_screen.open_context(&"stash", self)
