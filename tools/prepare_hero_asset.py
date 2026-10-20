"""Extract one supplied turnaround mesh, preserve UVs and prepare a game rig.

Run with Blender, from the project root. Source files remain read-only.
"""
import bpy, math, json, sys, shutil
from pathlib import Path
from mathutils import Vector, Matrix
R=Path(__file__).resolve().parents[1]
WORK=R/'work/hero_source'
OUT=R/'assets/characters/red_huntress/v1'
ART=R/'art_source/red_huntress_v1'
OUT.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True)
(ART/'.gdignore').touch()
bpy.ops.wm.open_mainfile(filepath=str(WORK/'source.blend'))
axis=Matrix(((0,0,1,0),(1,0,0,0),(0,1,0,0),(0,0,0,1)))
groups={i:[] for i in range(6)}
for o in list(bpy.context.scene.objects):
    if o.type!='MESH':continue
    p=o.matrix_world@sum((Vector(c) for c in o.bound_box),Vector())/8
    col=0 if p.z<-.21 else (1 if p.z<.21 else 2)
    row=0 if p.y>0 else 1
    groups[row*3+col].append(o)
    o.matrix_world=axis@o.matrix_world
print('GROUPS',[(i,len(os),sum(len(o.data.polygons) for o in os)) for i,os in groups.items()],flush=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.color=(.5,.5,.5)
scene.view_settings.view_transform='Standard'
for pos,power in [((-1,-2,3),120),((2,-1,1),70),((0,2,2),80)]:
    bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.size=3
    o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-3,0));cam=bpy.context.object;scene.camera=cam
cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=1.2
if '--grid-only' in sys.argv:
    scene.render.filepath=str(WORK/'grid.png');bpy.ops.render.render(write_still=True)
    sys.exit(0)

# The upper-left figure is the most frontal complete copy. Keep every part of it.
parts=groups[0]
for i,os in groups.items():
    if i!=0:
        for o in os:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
hero=bpy.context.object;hero.name='RedHuntress'
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
coords=[hero.matrix_world@v.co for v in hero.data.vertices]
lo=Vector(tuple(min(p[i] for p in coords) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in coords) for i in range(3)))
origin=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));scale=1.8/(hi.z-lo.z)
for v,p in zip(hero.data.vertices,coords):v.co=(p-origin)*scale
hero.matrix_world=Matrix.Identity(4)
source_triangles=len(hero.data.polygons)
mat=bpy.data.materials.new('Red huntress | supplied PBR atlas');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF')
src=Path(r'C:\Users\user\Desktop\MAIN HERO ASSET')
for filename,dest in [('8084db01-8033-4633-87fd-3deb45624fb4.png','huntress_albedo.png'),('26268041-0d7f-4dd0-8613-171c1c21f479.png','huntress_normal.png'),('217944a9-c7ba-422f-9966-0f8d676d38c8.png','huntress_orm.png')]:
    shutil.copy2(src/filename,OUT/dest)
    n=nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(OUT/dest),check_existing=True)
    if 'albedo' in dest:links.new(n.outputs['Color'],bsdf.inputs['Base Color'])
    else:
        n.image.colorspace_settings.name='Non-Color'
        if 'normal' in dest:
            normal=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
        else:
            split=nodes.new('ShaderNodeSeparateColor');links.new(n.outputs['Color'],split.inputs[0]);links.new(split.outputs['Green'],bsdf.inputs['Roughness']);links.new(split.outputs['Blue'],bsdf.inputs['Metallic'])
hero.data.materials.clear();hero.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'huntress_extracted_high.blend'))
dec=hero.modifiers.new('Game mesh | preserve silhouette and UV','DECIMATE');dec.ratio=.16
bpy.ops.object.modifier_apply(modifier=dec.name)
for p in hero.data.polygons:p.use_smooth=True
print('EXTRACTED',source_triangles,'GAME',len(hero.data.polygons),'bounds',list(lo),list(hi),'scale',scale,flush=True)
cam.data.ortho_scale=2.05
scene.render.resolution_x=800;scene.render.resolution_y=1000
for name,pos in [('front',(0,-5,.92)),('back',(0,5,.92)),('side',(5,0,.92))]:
    cam.location=pos;cam.rotation_euler=(Vector((0,0,.92))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(WORK/('single_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'extracted.blend'))
if '--extract-only' in sys.argv:sys.exit(0)
