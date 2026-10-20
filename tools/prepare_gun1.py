"""Подготовка предоставленного GUN 1; исходники и баланс оружия не меняются."""
import bpy, json, math, shutil, struct, sys
from pathlib import Path
from mathutils import Vector, Matrix
R=Path(__file__).resolve().parents[1];WORK=R/'work/gun1';OUT=R/'assets/weapons/gun1';ART=R/'art_source/gun1'
for p in [WORK,OUT,ART]:p.mkdir(parents=True,exist_ok=True)
for p in [WORK,ART]:(p/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=str(R/'GUN 1/RIP0.obj'),forward_axis='Y',up_axis='Z')
hero=bpy.context.selected_objects[0]
mat=bpy.data.materials.new('Gun1 supplied atlas');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF')
n=nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(R/'GUN 1/667e84a3-f271-4038-b1f6-9fe584ecde7a.png'));links.new(n.outputs['Color'],bsdf.inputs['Base Color'])
bsdf.inputs['Roughness'].default_value=.7
hero.data.materials.clear();hero.data.materials.append(mat)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
parts=list(bpy.context.selected_objects)
report=[]
for o in parts:
 ps=[o.matrix_world@v.co for v in o.data.vertices]
 report.append({'name':o.name,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'lo':[min(p[i] for p in ps) for i in range(3)],'hi':[max(p[i] for p in ps) for i in range(3)]})
(WORK/'components.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'source.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.color=(.4,.4,.4);scene.view_settings.view_transform='Standard'
ps=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
lo=Vector(tuple(min(p[i] for p in ps) for i in range(3)));hi=Vector(tuple(max(p[i] for p in ps) for i in range(3)))
center=(lo+hi)/2;size=max(hi-lo)
print('GUN1_SOURCE',sum(p['triangles'] for p in report),'parts',len(parts),'bounds',list(lo),list(hi),flush=True)
for d in [(1,-2,3),(-2,-1,1),(0,2,2)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(d)*size);o=bpy.context.object;o.data.energy=180*size*size;o.data.size=size*2;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.3
for name,d in [('front',(0,-3,0)),('side',(3,0,0)),('top',(0,0,3))]:
 cam.location=center+Vector(d)*size;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(WORK/(name+'.png'));bpy.ops.render.render(write_still=True)

# Рукоять становится началом координат; в Godot ствол направлен вдоль -Z.
origin=Vector((0,-.04,.22));axis=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
for o in parts:
 for v in o.data.vertices:v.co=(axis@(o.matrix_world@v.co-origin))*.95
 o.matrix_world=Matrix.Identity(4)
for src,dest in [('667e84a3-f271-4038-b1f6-9fe584ecde7a.png','gun1_albedo.png'),('3991fca6-7599-4078-8044-8a7edafaa8e7.png','gun1_normal.png'),('3bfc6e0a-6996-4c1f-bd1f-426bbe84be30.png','gun1_orm.png')]:
 shutil.copy2(R/'GUN 1'/src,OUT/dest)
 if 'albedo' in dest:n.image=bpy.data.images.load(str(OUT/dest));continue
 tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/dest));tex.image.colorspace_settings.name='Non-Color'
 if 'normal' in dest:
  nm=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
 else:
  sep=nodes.new('ShaderNodeSeparateColor');links.new(tex.outputs['Color'],sep.inputs[0]);links.new(sep.outputs['Green'],bsdf.inputs['Roughness']);links.new(sep.outputs['Blue'],bsdf.inputs['Metallic'])
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();gun=bpy.context.object;gun.name='Gun1'
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'gun1_high.blend'))
dec=gun.modifiers.new('Game reduction','DECIMATE');dec.ratio=20000/243308
bpy.ops.object.modifier_apply(modifier=dec.name)
for p in gun.data.polygons:p.use_smooth=True
bpy.ops.export_scene.gltf(filepath=str(OUT/'gun1.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_image_format='NONE')
path=OUT/'gun1.glb';blob=path.read_bytes();size=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+size]);binary=blob[20+size:]
doc['images']=[{'uri':n} for n in ['gun1_albedo.png','gun1_normal.png','gun1_orm.png']]
doc['samplers']=[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}];doc['textures']=[{'source':i,'sampler':0} for i in range(3)]
doc['materials']=[{'name':'Gun1 supplied PBR','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':1.0,'roughnessFactor':1.0},'normalTexture':{'index':1},'occlusionTexture':{'index':2,'strength':.6}}]
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*(-len(js)%4);path.write_bytes(struct.pack('<III',0x46546C67,2,12+8+len(js)+len(binary))+struct.pack('<II',len(js),0x4E4F534A)+js+binary)
bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ART/'gun1_game.blend'))
report={'source_triangles':243308,'game_triangles':sum(len(p.vertices)-2 for p in gun.data.polygons),'length_m':.95,'grip_source':list(origin),'muzzle_local':[0,.095,-.684]}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2));print('GUN1_READY',json.dumps(report),flush=True)
