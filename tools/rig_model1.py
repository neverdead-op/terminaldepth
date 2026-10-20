"""Упрощение и первая игровая привязка MODEL 1; выходы только model1/v1."""
import bpy, json, shutil, math, struct
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];WORK=R/'work/model1';ART=R/'art_source/model1_v1';OUT=R/'assets/characters/model1/v1'
bpy.ops.wm.open_mainfile(filepath=str(WORK/'parts.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
removed=[]
for o in list(parts):
 lo=min(v.co.z for v in o.data.vertices);hi=max(v.co.z for v in o.data.vertices)
 cx=sum(v.co.x for v in o.data.vertices)/len(o.data.vertices)
 if hi < -.40 and abs(cx)<.065:
  removed.append(o.name);parts.remove(o);bpy.data.objects.remove(o,do_unlink=True)
lo=min(v.co.z for o in parts for v in o.data.vertices);hi=max(v.co.z for o in parts for v in o.data.vertices)
scale=1.8/(hi-lo)
for o in parts:
 for v in o.data.vertices:v.co=Vector((v.co.x*scale,v.co.y*scale,(v.co.z-lo)*scale))
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for b in rig.data.edit_bones:
 b.use_connect=False
 # Сохраняем имена и иерархию одобренного скелета, подгоняем длины под новую анатомию.
 for attr in ['head','tail']:
  p=getattr(b,attr).copy()
  if 'Hand' in b.name and not b.name.endswith('Hand'):
   p.x*=1.16;p.z+=.095
  elif any(t in b.name for t in ['Shoulder','Arm','Hand']):
   old=abs(p.x);sign=1 if p.x>=0 else -1
   if old<.165:x=old*1.16
   elif old<.45915:x=.1914+(old-.165)/(.45915-.165)*(.45-.1914)
   else:x=.45+(old-.45915)/(.65896-.45915)*(.745-.45)
   p.x=sign*x
   if b.name.endswith('Hand'):p.z=1.405
  elif any(t in b.name for t in ['UpLeg','Leg','Foot','Toe']):
   p.x=(1 if p.x>0 else -1)*(.13+(.98-p.z)/.98*.12)
  setattr(b,attr,p)
bpy.ops.object.mode_set(mode='OBJECT')
for p in rig.pose.bones:p.matrix_basis.identity()
mat=bpy.data.materials.new('Model1 supplied PBR');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.7
for src,dest in [('dc075df8-db08-4959-8fd0-055dbf8b48a3.png','model1_albedo.png'),('ebbdf153-659e-4e36-9e2a-badf10c44d94.png','model1_normal.png'),('dc75f372-a4ed-4d2c-a6ca-6254a0865a63.png','model1_orm.png')]:
 shutil.copy2(R/'MODEL 1'/src,OUT/dest)
 n=nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(OUT/dest))
 if 'albedo' in dest:links.new(n.outputs['Color'],bsdf.inputs['Base Color'])
 else:
  n.image.colorspace_settings.name='Non-Color'
  if 'normal' in dest:
   nm=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
  else:
   sep=nodes.new('ShaderNodeSeparateColor');links.new(n.outputs['Color'],sep.inputs[0]);links.new(sep.outputs['Green'],bsdf.inputs['Roughness']);links.new(sep.outputs['Blue'],bsdf.inputs['Metallic'])
for o in parts:o.data.materials.clear();o.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'model1_high.blend'))
source_triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in parts)
ratio=55000/source_triangles
for o in parts:
 bpy.context.view_layer.objects.active=o
 dec=o.modifiers.new('Game reduction','DECIMATE');dec.ratio=ratio
 bpy.ops.object.modifier_apply(modifier=dec.name)
 for p in o.data.polygons:p.use_smooth=True
 # Мелкие жёсткие элементы следуют одной кости; суставные поверхности получают плавные веса.
 center=sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
 bounds=[max(v.co[i] for v in o.data.vertices)-min(v.co[i] for v in o.data.vertices) for i in range(3)]
 groups={b.name:o.vertex_groups.new(name=b.name) for b in rig.data.bones}
 def candidates(p):
  side='Left' if p.x>=0 else 'Right'
  if p.z>1.53:return ['Head','Neck'] if p.z<1.57 else ['Head']
  if abs(p.x)>.22 and p.z>1.18:
   if abs(p.x)>.83:return [b.name for b in rig.data.bones if b.name.startswith(side+'Hand') and not b.name.endswith('4')]
   return [side+'Arm',side+'ForeArm',side+'Hand']
  if p.z<.88:return [side+'UpLeg',side+'Leg',side+'Foot',side+'ToeBase']
  return ['Hips','Spine','Spine1','Spine2','Neck',side+'Shoulder']
 def distance(p,name):
  b=rig.data.bones[name];a=b.head_local;delta=b.tail_local-a
  t=max(0,min(1,(p-a).dot(delta)/max(delta.length_squared,1e-8)))
  return (p-a-delta*t).length
 rigid=max(bounds)<.085
 fixed=min(candidates(center),key=lambda n:distance(center,n)) if rigid else None
 for v in o.data.vertices:
  if fixed:groups[fixed].add([v.index],1,'REPLACE');continue
  ns=sorted(candidates(v.co),key=lambda n:distance(v.co,n))[:2]
  ds=[distance(v.co,n) for n in ns]
  ws=[math.exp(-(d-min(ds))/.025) for d in ds];total=sum(ws)
  for n,w in zip(ns,ws):groups[n].add([v.index],w/total,'REPLACE')
 o.parent=rig
 mod=o.modifiers.new('Armature','ARMATURE');mod.object=rig
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
hero=bpy.context.object;hero.name='Model1Hero'
rig.name='Model1Rig'
bpy.ops.object.select_all(action='DESELECT');hero.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'model1.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_skins=True,export_apply=False,export_image_format='NONE')
# Атласы остаются внешними PNG рядом с GLB, как у действующего героя.
path=OUT/'model1.glb';blob=path.read_bytes();size=struct.unpack_from('<I',blob,12)[0]
doc=json.loads(blob[20:20+size]);binary=blob[20+size:]
doc['images']=[{'uri':n} for n in ['model1_albedo.png','model1_normal.png','model1_orm.png']]
doc['samplers']=[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]
doc['textures']=[{'source':i,'sampler':0} for i in range(3)]
doc['materials']=[{'name':'Model1 supplied PBR','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':1.0,'roughnessFactor':1.0},'normalTexture':{'index':1},'occlusionTexture':{'index':2,'strength':.6}}]
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*(-len(js)%4)
path.write_bytes(struct.pack('<III',0x46546C67,2,12+8+len(js)+len(binary))+struct.pack('<II',len(js),0x4E4F534A)+js+binary)
report={'source_triangles':source_triangles,'game_triangles':sum(len(p.vertices)-2 for p in hero.data.polygons),'vertices':len(hero.data.vertices),'bones':len(rig.data.bones),'excluded_fragments':removed,'height':1.8}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ART/'model1_rigged.blend'))
print('MODEL1_RIG',json.dumps(report),flush=True)
