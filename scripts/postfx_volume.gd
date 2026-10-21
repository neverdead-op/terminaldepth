@tool
extends Node3D
## Аналог области Post Process Volume: коробка, приоритет, радиус и вес смешивания.
@export var enabled := true
@export var unbound := false:
	set(value):
		unbound=value
		update_gizmos()
@export var profile: Resource
@export var size := Vector3(20,40,20):
	set(value):
		size=value.max(Vector3.ONE*.01)
		update_gizmos()
@export_range(0,30,.1) var blend_radius := 5.0
@export_range(0,1,.01) var blend_weight := 1.0
@export var priority := 0
## Пусто — весь профиль. Иначе только указанные поля, например env/tonemap_exposure, vignette.
@export var overrides := PackedStringArray()

func _enter_tree() -> void:
	add_to_group("postfx_volumes")

func influence(point: Vector3) -> float:
	if not enabled or profile==null: return 0.0
	if unbound: return blend_weight
	var p := to_local(point).abs()-size*.5
	var distance := Vector3(maxf(p.x,0),maxf(p.y,0),maxf(p.z,0)).length()
	return blend_weight*(1.0-smoothstep(0,maxf(blend_radius,.001),distance))
