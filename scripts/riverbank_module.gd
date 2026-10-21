@tool
extends Node3D
## Модуль конструктора: сменная модель и отдельная игровая коллизия.
## Служебное содержимое _Generated пересоздаётся; остальные дочерние узлы не трогаются.
@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		_queue_rebuild()
## Временная готовая модель проекта. Когда задан Model Scene, она больше не используется.
@export var reference_model: PackedScene:
	set(value):
		reference_model = value
		_queue_rebuild()
@export var target_size := Vector3(4, 2, 3):
	set(value):
		target_size = value
		_queue_rebuild()
@export var solid := true:
	set(value):
		solid = value
		_queue_rebuild()
@export var collider_size := Vector3(3.6, 1.8, 2.6):
	set(value):
		collider_size = value
		_queue_rebuild()
@export var collider_center := Vector3(0, 0.9, 0):
	set(value):
		collider_center = value
		_queue_rebuild()
@export var surface_material: Material:
	set(value):
		surface_material = value
		_queue_rebuild()
var _rebuild_queued := false
## Копии материалов для фильтрации Riverbank без изменения импортированных оригиналов.
static var _filtered_materials: Dictionary = {}

func _ready() -> void:
	rebuild()

func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued: return
	_rebuild_queued = true
	rebuild.call_deferred()

func rebuild() -> void:
	_rebuild_queued = false
	var previous := get_node_or_null("_Generated")
	if previous != null:
		remove_child(previous)
		previous.free()
	var active_model := model_scene if model_scene != null else reference_model
	if active_model == null: return
	var generated := Node3D.new()
	generated.name = "_Generated"
	add_child(generated)
	var pivot := Node3D.new()
	pivot.name = "Visual"
	generated.add_child(pivot)
	var source := active_model.instantiate() as Node3D
	if source == null: return
	pivot.add_child(source)
	var bounds := _bounds(source, Transform3D.IDENTITY)
	var size := bounds.size.max(Vector3(0.001,0.001,0.001))
	pivot.scale = target_size / size
	pivot.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * pivot.scale
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		# Новая Tripo-модель сохраняет собственные материалы и рисованную текстуру.
		if model_scene == null and surface_material != null: mesh.material_override = surface_material
		if model_scene != null and mesh.mesh != null:
			for surface in range(mesh.mesh.get_surface_count()):
				var original := mesh.get_active_material(surface)
				if not original is BaseMaterial3D: continue
				var key := original.get_instance_id()
				if not _filtered_materials.has(key):
					var filtered := original.duplicate() as BaseMaterial3D
					filtered.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					_filtered_materials[key] = filtered
				mesh.set_surface_override_material(surface, _filtered_materials[key])
	if solid:
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		generated.add_child(body)
		var collider := CollisionShape3D.new()
		collider.name = "Shape"
		var shape := BoxShape3D.new()
		shape.size = collider_size
		collider.shape = shape
		collider.position = collider_center
		body.add_child(collider)

func _bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform_here := parent_transform * node.transform
	var result := AABB()
	var found := false
	if node is MeshInstance3D:
		result = transform_here * node.get_aabb()
		found = true
	for child in node.get_children():
		if not child is Node3D: continue
		var child_bounds := _bounds(child, transform_here)
		if child_bounds.size.length_squared() < 0.000001: continue
		result = result.merge(child_bounds) if found else child_bounds
		found = true
	return result
