extends "res://scripts/spitter.gd"
## Некромант — держит дистанцию, бросает сгусток тьмы и поднимает зомби из-под земли.
## Перед подъёмом замирает с воплем, над головой разгорается сфера — это окно, чтобы его убить.
## Убит некромант — поднятые им мертвецы рассыпаются.

const GraveRise := preload("res://scripts/grave_rise.gd")

@export_group("Подъём мертвецов")
## Секунд между подъёмами.
@export var raise_interval := 8.0
## Сколько зомби за раз.
@export var raise_count := 2
## Больше этого числа живых поднятых не бывает.
@export var raise_limit := 4
## Сколько стоит на месте, творя подъём.
@export var raise_cast_time := 1.1
@export var minion_scene: PackedScene = preload("res://scenes/crawler.tscn")
## Доля здоровья поднятого зомби от обычного.
@export_range(0.1, 1.0) var minion_life_ratio := 0.55
@export var minion_damage := 7.0
@export var orb_color := Color(0.62, 0.3, 1.0)

var _raise_left := 3.0
var _casting := 0.0
var _minions: Array[Enemy] = []
var _orb: MeshInstance3D
var _orb_light: OmniLight3D


func _ready() -> void:
	super()
	_raise_left = randf_range(2.0, 4.0)
	_orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = orb_color.lightened(0.3)
	sphere.material = glow
	_orb.mesh = sphere
	_orb.position = Vector3(0, 2.15, 0)
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)
	_orb_light = OmniLight3D.new()
	_orb_light.light_color = orb_color
	_orb_light.light_energy = 1.2
	_orb_light.omni_range = 4.0
	_orb.add_child(_orb_light)
	var bob := _orb.create_tween().set_loops()
	bob.tween_property(_orb, "position:y", 2.3, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_orb, "position:y", 2.1, 0.9).set_trans(Tween.TRANS_SINE)


func _think(delta: float, to_player: Vector3, distance: float) -> Array:
	if _casting > 0.0:
		_casting -= delta
		if _casting <= 0.0:
			_raise(to_player)
		return [Vector3.ZERO, to_player]
	_raise_left -= delta
	if _raise_left <= 0.0 and _state == State.CHASE and _sees_player and distance < 16.0:
		_minions.assign(_minions.filter(func(m) -> bool: return is_instance_valid(m) and m.has_method("is_dead") and not m.is_dead()))
		_raise_left = raise_interval
		if _minions.size() < raise_limit:
			_casting = raise_cast_time
			_play_once(anim_attack, raise_cast_time)
			Sfx.play(&"boss_roar", global_position)
			var flare := create_tween()
			flare.tween_property(_orb, "scale", Vector3.ONE * 2.4, raise_cast_time * 0.8)
			flare.parallel().tween_property(_orb_light, "light_energy", 5.0, raise_cast_time * 0.8)
			flare.tween_property(_orb, "scale", Vector3.ONE, 0.3)
			flare.parallel().tween_property(_orb_light, "light_energy", 1.2, 0.3)
			return [Vector3.ZERO, to_player]
	return super(delta, to_player, distance)


## Зомби встают между некромантом и героем — прикрывают хозяина.
func _raise(to_player: Vector3) -> void:
	var toward := to_player.normalized() if to_player.length() > 0.1 else -global_basis.z
	for i in mini(raise_count, raise_limit - _minions.size()):
		var side := toward.cross(Vector3.UP) * (i - (raise_count - 1) * 0.5) * 2.2
		var at := global_position + toward * minf(4.0, to_player.length() * 0.5) + side
		GraveRise.raise(get_parent(), minion_scene, at, func(m: Enemy) -> void:
			m.max_hp *= minion_life_ratio
			m.damage = minion_damage
			m.aggro_range = 20
			_minions.append(m))


func _die() -> void:
	var was_alive := _state != State.DEAD
	super()
	if not was_alive:
		return
	if is_instance_valid(_orb):
		_orb.create_tween().tween_property(_orb, "scale", Vector3.ZERO, 0.4)
	for m in _minions:
		if is_instance_valid(m) and m.has_method("is_dead") and not m.is_dead():
			m.take_damage(m.hp + 1000.0, &"physical", null, false)
