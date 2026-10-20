extends "res://scripts/interactable.gd"
## Верстак разбора на базе: превращает ненужные вещи в ксено-фрагменты.


const DESK := preload("res://assets/essentials/Prop_Desk_Medium.gltf")
const TERMINAL := preload("res://assets/megakit/Prop_Computer.gltf")
const PARTS := preload("res://assets/essentials/Prop_Ammo_Small.gltf")
const MAN := preload("res://assets/characters/base/Superhero_Male_FullBody.gltf")
const Suit := preload("res://scripts/suit.gd")
const Animator := preload("res://scripts/player_animator.gd")
const Dialog := preload("res://scripts/npc_dialog.gd")
const Outfit := preload("res://scripts/outfit.gd")
const Hair := preload("res://scripts/hair.gd")
const DialogBox := preload("res://scripts/dialog_box.gd")
## Техник за верстаком: рассказывает про фрагменты (по этажам).
const NPC_NAME := "Техник Рой"

var _model: Node3D
var _label: Label3D
var _new_shown := false


func _ready() -> void:
	super()
	prompt = "Разобрать вещи"
	# Стол с терминалом и ящиком деталей — модели из Sci-Fi Essentials / MegaKit.
	var desk: Node3D = DESK.instantiate()
	add_child(desk)
	desk.rotation.y = PI  # передом к залу, техник — за столом
	var terminal: Node3D = TERMINAL.instantiate()
	terminal.position = Vector3(1.9, 0, -0.1)
	add_child(terminal)
	var parts: Node3D = PARTS.instantiate()
	parts.position = Vector3(-0.7, 0.94, 0.0)
	parts.scale = Vector3.ONE * 0.8
	add_child(parts)
	var light := OmniLight3D.new()
	light.light_color = Color(0.65, 0.82, 1.0)
	light.position = Vector3(0, 1.8, 0.3)
	light.omni_range = 4.0
	light.light_energy = 0.7
	add_child(light)
	# Твёрдый стол, чтобы сквозь него не ходили.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.9, 1.0, 1.1)
	shape.shape = box
	shape.position.y = 0.5
	body.add_child(shape)
	add_child(body)
	var label := Label3D.new()
	label.text = "Техник Рой · Верстак"
	label.modulate = Color(0.55, 1.0, 0.7)
	label.position = Vector3(0, 2.2, -0.9)
	label.transparency = 1.0  # рисует плашкой hud_world_labels.gd
	label.add_to_group("boxed_label")
	add_child(label)
	_label = label
	# Техник Рой стоит за столом и говорит по рации.
	var man: Node3D = MAN.instantiate()
	man.position = Vector3(0.2, 0, -0.95)
	add_child(man)
	_model = man
	Suit.apply(man, Color(0.3, 1.0, 0.6), Color(0.35, 0.37, 0.4), Color.WHITE, Color(0.13, 0.14, 0.16), true)
	Outfit.attach(man, preload("res://assets/characters/outfits/Male_Ranger.gltf"), Color(0.38, 0.4, 0.43))
	Hair.attach(man, preload("res://assets/characters/hair/Hair_SimpleParted.gltf"), Color(0.36, 0.33, 0.29))
	Hair.attach(man, preload("res://assets/characters/hair/Hair_Beard.gltf"), Color(0.36, 0.33, 0.29))
	var skeleton: Skeleton3D = man.get_node("Armature/Skeleton3D")
	var anim := AnimationPlayer.new()
	man.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library(&"", Animator.fit_library(skeleton, [&"Idle_TalkingPhone"], []))
	anim.play(&"Idle_TalkingPhone")


func _process(_delta: float) -> void:
	var has_new := Dialog.has_new(NPC_NAME)
	if has_new == _new_shown:
		return
	_new_shown = has_new
	_label.set_meta("new_dialog", has_new)
	prompt = "Поговорить с техником" if has_new else "Разобрать вещи"


func interact(player: Node) -> void:
	preload("res://scripts/npc_conversation.gd").show_for(player, self, NPC_NAME)
