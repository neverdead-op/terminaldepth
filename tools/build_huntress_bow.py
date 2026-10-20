"""Prepare the user-supplied bow OBJ, preserving its texture and UVs."""
import bpy,json,struct,shutil,bmesh,statistics
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];SRC=Path(r'C:\Users\user\Desktop\MAIN HERO ASSET')
OUT=R/'assets/weapons/huntress_bow';ART=R/'art_source/huntress_bow'
OUT.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True);(ART/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=str(SRC/'bow.obj'),forward_axis='Y',up_axis='Z')
obj=bpy.context.selected_objects[0];obj.name='HuntressBow'
raw=[v.co.copy() for v in obj.data.vertices]
print('RAW_BOUNDS',[(min(p[i] for p in raw),max(p[i] for p in raw)) for i in range(3)],'MATRIX',obj.matrix_world)
lo=Vector(tuple(min(p[i] for p in raw) for i in range(3)));hi=Vector(tuple(max(p[i] for p in raw) for i in range(3)))
center=(lo+hi)*.5;scale=1.38/(hi.y-lo.y)
grip=[p for p in raw if abs(p.y-center.y)<200]
center.x=statistics.median(p.x for p in grip);center.z=statistics.median(p.z for p in grip)
for v,p in zip(obj.data.vertices,raw):
    q=(p-center)*scale
    v.co=Vector((q.z,-q.x,q.y))
# Quantized UVs address the populated lower-left quarter of the supplied atlas.
for uv in obj.data.uv_layers.active.data: uv.uv /= 8190.0
bm=bmesh.new();bm.from_mesh(obj.data)
bm.verts.ensure_lookup_table();bm.verts.index_update()
# Remove only the straight captured string. Runtime supplies a drawable string.
to_delete=[v for v in bm.verts if raw[v.index].x>2700 and .04*(hi.y-lo.y)<raw[v.index].y<.96*(hi.y-lo.y)]
print('DELETE_STRING',len(to_delete),'CENTER',center)
bmesh.ops.delete(bm,geom=to_delete,context='VERTS');bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
obj.data.materials.clear();mat=bpy.data.materials.new('Supplied bow wood and binding');mat.use_nodes=True
p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.82;p.inputs['Metallic'].default_value=.08
shutil.copy2(SRC/'bow.png',OUT/'bow_albedo.png')
t=mat.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(OUT/'bow_albedo.png'));mat.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color']);obj.data.materials.append(mat)
before=len(obj.data.polygons);dec=obj.modifiers.new('Game bow','DECIMATE');dec.ratio=.12;bpy.ops.object.modifier_apply(modifier=dec.name)
for face in obj.data.polygons:face.use_smooth=True
obj.shape_key_add(name='Basis')
draw_key=obj.shape_key_add(name='Draw')
for v in draw_key.data:
    tip=min(1.0,abs(v.co.z)/.69)**1.7
    v.co.y-=.035*tip
    v.co.z*=1.0-.035*tip
bpy.ops.export_scene.gltf(filepath=str(OUT/'bow.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_image_format='NONE')
path=OUT/'bow.glb';b=path.read_bytes();size=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+size]);binary=b[20+size:]
d['images']=[{'uri':'bow_albedo.png'}];d['textures']=[{'source':0}]
d['materials']=[{'name':'Supplied bow','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'roughnessFactor':.82,'metallicFactor':.08}}]
js=json.dumps(d,separators=(',',':')).encode();js+=b' '*(-len(js)%4)
path.write_bytes(struct.pack('<III',0x46546C67,2,20+len(js)+len(binary))+struct.pack('<II',len(js),0x4E4F534A)+js+binary)
bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ART/'bow.blend'))
(OUT/'report.json').write_text(json.dumps({'source_triangles':before,'game_triangles':len(obj.data.polygons),'height':1.38,'source':'User supplied bow.obj / bow.png'},indent=2))
# Inspect from the side of the stave, with a neutral studio.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.world.color=(.5,.5,.5)
for loc in [(2,-3,3),(-2,-2,0)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=130;o.data.size=3;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3,-1,.1));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.65;scene.camera=cam
scene.render.resolution_x=600;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.filepath=str(R/'work/bow_asset.png');bpy.ops.render.render(write_still=True)
print('HUNTRESS_BOW_ASSET_OK',len(obj.data.polygons))
