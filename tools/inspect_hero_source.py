"""Inspect the supplied OBJ without modifying it. Run in Blender background."""
import bpy, json
from pathlib import Path
from mathutils import Vector
R = Path(__file__).resolve().parents[1]
SRC = Path(r'C:\Users\user\Desktop\MAIN HERO ASSET')
OUT = R/'work/hero_source'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=str(SRC/'RIP0.obj'), forward_axis='Y', up_axis='Z')
mesh = bpy.context.selected_objects[0]
print('IMPORT', mesh.name, len(mesh.data.vertices), len(mesh.data.polygons), flush=True)
bpy.context.view_layer.objects.active=mesh
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='LOOSE')
bpy.ops.object.mode_set(mode='OBJECT')
report=[]
for o in bpy.context.selected_objects:
    ps=[o.matrix_world@Vector(c) for c in o.bound_box]
    report.append({'name':o.name,'vertices':len(o.data.vertices),'faces':len(o.data.polygons),'min':[min(p[i] for p in ps) for i in range(3)],'max':[max(p[i] for p in ps) for i in range(3)]})
report.sort(key=lambda x:-x['faces'])
(OUT/'components.json').write_text(json.dumps(report,indent=2))
print('COMPONENTS',len(report),json.dumps(report[:30]),flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source.blend'))
# Raw axes render from -Y: original geometry, texture and materials.
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.color=(.3,.3,.3)
center=Vector((0,0,0))
for pos in [(1,-2,3),(-2,-1,1),(0,2,2)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    bpy.context.object.data.energy=100;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=3
    bpy.context.object.rotation_euler=(center-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-3,0))
cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.2
cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='Standard'
scene.render.filepath=str(OUT/'raw_front.png');bpy.ops.render.render(write_still=True)
cam.location=(0,0,3);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'raw_top.png');bpy.ops.render.render(write_still=True)
