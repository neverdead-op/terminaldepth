@tool
extends MultiMeshInstance3D
## Rebuild transforms in editor/runtime; headless renderer cannot serialize GPU buffers.
@export var link_basis := Basis.IDENTITY
@export var link_offset := Vector3.ZERO

func _ready() -> void:
	if multimesh == null: return
	for i in multimesh.instance_count:
		multimesh.set_instance_transform(i,Transform3D(link_basis,link_offset+Vector3(0,-i,0)))
