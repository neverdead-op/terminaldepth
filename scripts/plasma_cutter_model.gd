extends Node3D
## Компактный резак: рукоять в ладони, широкая режущая головка и три эмиттера.
@export var upgraded := false
func _ready() -> void:
	_part(Vector3(0.115, 0.13, 0.25), Vector3(0, 0.02, -0.07), Color(0.12, 0.14, 0.16))
	_part(Vector3(0.08, 0.16, 0.09), Vector3(0, -0.10, 0.01), Color(0.045, 0.045, 0.05))
	_part(Vector3(0.24 if upgraded else 0.20, 0.11, 0.095), Vector3(0, 0.02, -0.23), Color(0.64, 0.63, 0.53) if upgraded else Color(0.24, 0.22, 0.17))
	for x in [-0.064, 0.0, 0.064]:
		_part(Vector3(0.043, 0.022, 0.018), Vector3(x, 0.025, -0.284), Color(0.13, 0.8, 1.0), true)
func _part(dimensions: Vector3, at: Vector3, tint: Color, glow := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.7
	mat.roughness = 0.5
	if glow:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	add_child(part)
