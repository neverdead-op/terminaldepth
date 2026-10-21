@tool
extends EditorNode3DGizmoPlugin
const Volume := preload("res://scripts/postfx_volume.gd")

func _init() -> void:
	create_material("postfx_bounds",Color(.35,.8,1,.8))

func _get_gizmo_name() -> String:
	return "PostFX Volume"

func _has_gizmo(node: Node3D) -> bool:
	return node.get_script()==Volume

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var volume: Node3D = gizmo.get_node_3d()
	if volume.unbound: return
	var lines := PackedVector3Array()
	var corners: Array[Vector3] = []
	for i in 8: corners.append(Vector3(1 if i&1 else -1,1 if i&2 else -1,1 if i&4 else -1)*volume.size*.5)
	for i in 8:
		for axis in [1,2,4]:
			if not i&axis: lines.append(corners[i]);lines.append(corners[i|axis])
	gizmo.add_lines(lines,get_material("postfx_bounds",gizmo))
