"""Подготовка отдельного персонажа MODEL 1 без изменения кампании."""
import bpy, json, math, shutil
from pathlib import Path
from mathutils import Vector, Matrix
R=Path(__file__).resolve().parents[1]
WORK=R/'work/model1'; ART=R/'art_source/model1_v1'; OUT=R/'assets/characters/model1/v1'
for p in [ART,OUT]:p.mkdir(parents=True,exist_ok=True)
(ART/'.gdignore').touch()
bpy.ops.wm.open_mainfile(filepath=str(WORK/'source.blend'))
hero=next(o for o in bpy.context.scene.objects if o.type=='MESH')
axis=Matrix(((0,0,1),( -1,0,0),(0,1,0)))
for v in hero.data.vertices:v.co=axis @ (hero.matrix_world @ v.co)
hero.matrix_world=Matrix.Identity(4)
bpy.context.view_layer.objects.active=hero
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
parts=list(bpy.context.selected_objects)
report=[]
for o in parts:
 ps=[v.co for v in o.data.vertices]
 lo=[min(p[i] for p in ps) for i in range(3)];hi=[max(p[i] for p in ps) for i in range(3)]
 report.append({'name':o.name,'faces':len(o.data.polygons),'lo':lo,'hi':hi})
(WORK/'components.json').write_text(json.dumps(report,indent=2))
print('COMPONENTS',len(parts),json.dumps(sorted(report,key=lambda x:-x['faces'])[:22]),flush=True)
with bpy.data.libraries.load(str(R/'art_source/red_huntress_v1/huntress_rigged.blend'),link=False) as (a,b):
 b.objects=[n for n in a.objects if 'Rig' in n or 'Armature' in n]
for obj in b.objects:
 if obj:
  bpy.context.collection.objects.link(obj)
  if obj.type=='ARMATURE':
   print('BONES',obj.name,json.dumps({bone.name:[list(obj.matrix_world@bone.head_local),list(obj.matrix_world@bone.tail_local)] for bone in obj.data.bones}),flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'parts.blend'))
