import bpy,json,math,collections
from pathlib import Path
from mathutils import Vector
R=Path(r'C:/Users/user/Documents/terminal-depth');S=Path(r'C:/Users/user/Desktop/MAIN HERO ASSET/1 LEVEl');W=R/'work/level1_source';W.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=str(S/'RIP0.obj'),forward_axis='Y',up_axis='Z')
o=bpy.context.selected_objects[0];o.name='Level1Supplied'
for v in o.data.vertices:
 p=v.co.copy();v.co=(p.x*120,-p.z*120,p.y*120)
o.data.materials.clear();m=bpy.data.materials.new('Supplied Level Atlas');m.use_nodes=True
b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Roughness'].default_value=.9
t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(S/'8ead50b3-6e8e-4b12-a472-503ddd83c5c4.png'));m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color']);o.data.materials.append(m)
bpy.ops.wm.save_as_mainfile(filepath=str(W/'source.blend'))
hist=collections.defaultdict(float)
for p in o.data.polygons:
 if p.normal.z>.85:hist[round(p.center.z*2)/2]+=p.area
print('FLOOR_HEIGHTS',sorted(hist.items(),key=lambda p:-p[1])[:18],flush=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.world.color=(.5,.5,.5);scene.view_settings.view_transform='Standard'
for pos,power,size in [((0,-20,100),50000,100),((-80,20,60),35000,80)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.size=size;l.rotation_euler=(-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(95,-125,125));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=150;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
scene.render.resolution_x=1400;scene.render.resolution_y=1200;scene.render.resolution_percentage=100;scene.render.filepath=str(W/'iso.png');bpy.ops.render.render(write_still=True)
cam.location=(0,0,180);cam.rotation_euler=(0,0,0);cam.data.ortho_scale=135;scene.render.resolution_x=1200;scene.render.resolution_y=1400;scene.render.filepath=str(W/'top.png');bpy.ops.render.render(write_still=True)
print('LEVEL1_INSPECT_OK',flush=True)
