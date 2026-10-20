extends Node3D
## Отдельный тест прохождения предоставленной карты.
@export var zone_level := 1
@export var enemy_speed_scale := .85
@export var enemy_life_scale := .85
@export var xp_scale := 1.0
@export var map_rects: Array[Rect2] = [Rect2(-47,-60,94,120)]
@export var exit_position := Vector2(11,-44)
@export var enemy_count := 64
@export var candidate_spawns: PackedVector3Array
@export var finish_position := Vector3(11,1,-44)
@export var route_points: PackedVector3Array
var completed := false
var overview := false
var mob_count := 0
func _ready() -> void:
 if Engine.is_editor_hint():return
 if has_node("Spawn"):set_meta("spawn",$Spawn.position)
 _spawn_mobs.call_deferred()
func _spawn_mobs() -> void:
 for i in mini(enemy_count,candidate_spawns.size()):
  var heavy := i%17==16
  var scene:PackedScene=preload("res://scenes/crawler.tscn")
  if heavy:scene=preload("res://scenes/brute.tscn")
  elif i%5==2 and i>2:scene=preload("res://scenes/spitter.tscn")
  elif i%5==4:scene=preload("res://scenes/leaper.tscn")
  var enemy:Enemy=scene.instantiate()
  enemy.name="TestMob%03d"%i
  enemy.position=candidate_spawns[i]+Vector3.UP*.10
  enemy.max_hp=200 if heavy else 88
  enemy.damage=9 if heavy else 5
  if enemy.get_script()==preload("res://scripts/spitter.gd"):
   enemy.projectile_damage=7.0
  enemy.xp_reward=2
  enemy.drops_enabled=false
  enemy.aggro_range=11
  enemy.wake_radius=6
  enemy.wander_radius=.7
  add_child(enemy)
  enemy.floor_max_angle = deg_to_rad(55)
  var steps := preload("res://scripts/level1_step_assist.gd").new()
  steps.body=enemy
  enemy.add_child(steps)
  mob_count+=1
func _process(_delta:float) -> void:
 if not is_instance_valid(Game.player) or not is_ancestor_of(Game.player):return
 if Game.player.global_position.y < -12:
  Game.player.global_position=$Spawn.position
  Game.player.velocity=Vector3.ZERO
 if not completed and Game.player.global_position.distance_to(finish_position)<2.5:
  completed=true
  Game.player.show_message("Уровень пройден. Вы дошли до таверны «Последний огонь».",6)
  Game.complete_zone(Game.player)
func _unhandled_key_input(event:InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F2:
  overview=not overview
  $OverviewCamera.current=overview
  $CameraRig/Camera3D.current=not overview
  if is_instance_valid(Game.player):Game.player.get_node("HUD").visible=not overview
