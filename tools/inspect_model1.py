"""Осмотр нового OBJ; исходные файлы не изменяются."""
import bpy, json
from pathlib import Path
from mathutils import Vector
R = Path(__file__).resolve().parents[1]
OUT = R/'work/model1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=str(R/'MODEL 1/RIP0 (1).obj'), forward_axis='Y', up_axis='Z')
o = bpy.context.selected_objects[0]
coords = [o.matrix_world @ v.co for v in o.data.vertices]
lo = Vector(tuple(min(p[i] for p in coords) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in coords) for i in range(3)))
print('BOUNDS', list(lo), list(hi), flush=True)
mat = bpy.data.materials.new('Model1 atlas'); mat.use_nodes=True
n = mat.node_tree.nodes.new('ShaderNodeTexImage')
n.image = bpy.data.images.load(str(R/'MODEL 1/dc075df8-db08-4959-8fd0-055dbf8b48a3.png'))
mat.node_tree.links.new(n.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
o.data.materials.clear(); o.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source.blend'))
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=8
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.color=(.35,.35,.35);scene.view_settings.view_transform='Standard'
center=(lo+hi)/2; size=max(hi-lo)
for delta in [(1,-2,3),(-2,-1,1),(0,2,2)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(delta)*size)
 lamp=bpy.context.object;lamp.data.energy=200*size*size;lamp.data.size=size*2
 lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(); cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.2
for name,d in [('front',(0,-3,0)),('side',(3,0,0)),('top',(0,0,3))]:
 cam.location=center+Vector(d)*size;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
