"""Игровой револьвер из pistol/RIP0.obj; исходник и баланс сохранены."""
import bpy,json,shutil,struct
from pathlib import Path
from mathutils import Vector,Matrix
r=Path(__file__).resolve().parents[1];out=r/'assets/weapons/supplied_pistol';art=r/'art_source/supplied_pistol'
out.mkdir(parents=True,exist_ok=True);art.mkdir(parents=True,exist_ok=True);(art/'.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=str(r/'pistol/RIP0.obj'),forward_axis='Y',up_axis='Z')
parts=list(bpy.context.selected_objects)
origin=Vector((0,-.15,.32));axis=Matrix(((1,0,0),(0,0,-1),(0,1,0)));scale=.38
for o in parts:
 for v in o.data.vertices:v.co=(axis@(o.matrix_world@v.co-origin))*scale
 o.matrix_world=Matrix.Identity(4)
shutil.copy2(r/'pistol/f48f63b3-57d2-45e6-b0f7-2f85dc794fb1.png',out/'pistol_albedo.png')
mat=bpy.data.materials.new('Supplied revolver');mat.use_nodes=True
bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Roughness'].default_value=.65
n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(out/'pistol_albedo.png'));mat.node_tree.links.new(n.outputs['Color'],bsdf.inputs['Base Color'])
for o in parts:o.data.materials.clear();o.data.materials.append(mat)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();gun=bpy.context.object;gun.name='SuppliedPistol'
bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(art/'pistol_game.blend'))
path=out/'pistol.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_image_format='NONE')
blob=path.read_bytes();size=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+size]);binary=blob[20+size:]
doc['images']=[{'uri':'pistol_albedo.png'}];doc['samplers']=[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}];doc['textures']=[{'source':0,'sampler':0}]
doc['materials']=[{'name':'Supplied revolver','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'roughnessFactor':.65,'metallicFactor':0.0}}]
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*(-len(js)%4)
path.write_bytes(struct.pack('<III',0x46546C67,2,20+len(js)+len(binary))+struct.pack('<II',len(js),0x4E4F534A)+js+binary)
muzzle=Vector((-.00195,.18677,-.499756));p=axis@(muzzle-origin)*scale;muzzle_local=[p.x,p.z,-p.y]
report={'triangles':sum(len(p.vertices)-2 for p in gun.data.polygons),'length_m':.38,'grip_source':list(origin),'muzzle_local':muzzle_local}
(out/'asset_report.json').write_text(json.dumps(report,indent=2))
(out/'pistol_visual.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="res://assets/weapons/supplied_pistol/pistol.glb" id="1"]\n[node name="SuppliedPistol" type="Node3D"]\n[node name="Model" parent="." instance=ExtResource("1")]\n[node name="MuzzleTip" type="Marker3D" parent="."]\nposition = Vector3(%s, %s, %s)\n'%tuple(muzzle_local))
print('SUPPLIED_PISTOL_READY',json.dumps(report),flush=True)
