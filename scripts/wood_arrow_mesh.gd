extends RefCounted
## Shared matte arrow mesh for the nocked arrow and pooled flying arrows.
static var cached: ArrayMesh
static func make_arrow() -> ArrayMesh:
	if cached != null: return cached
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.30, 0.18, 0.075)
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := TAU * i / 6.0
		var b := TAU * (i + 1) / 6.0
		var p := Vector3(cos(a) * 0.009, sin(a) * 0.009, 0.31)
		var q := Vector3(cos(b) * 0.009, sin(b) * 0.009, 0.31)
		var r := Vector3(q.x, q.y, -0.27)
		var s := Vector3(p.x, p.y, -0.27)
		for v in [p,q,r,p,r,s]: st.add_vertex(v)
		for v in [s,r,Vector3(0,0,-0.36)]: st.add_vertex(v)
	for axis in [Vector3.RIGHT, Vector3.UP]:
		for v in [axis * 0.035 + Vector3(0,0,.25), -axis * 0.035 + Vector3(0,0,.25), Vector3(0,0,.13)]:st.add_vertex(v)
	st.generate_normals()
	st.set_material(material)
	cached = st.commit()
	return cached
