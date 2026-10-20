@tool
extends Node3D
## The supplied atlas is preserved; disable it for a readable playthrough blockout.
@export var use_source_textures := false:
 set(value):
  use_source_textures = value
  if is_inside_tree():_apply.call_deferred()
func _ready() -> void:_apply()
func _apply() -> void:
 var material := ShaderMaterial.new()
 material.shader = preload("res://assets/environment/level1_supplied/stone_preview.gdshader")
 for mesh in find_children("*", "MeshInstance3D", true, false):
  mesh.material_override = null if use_source_textures else material
