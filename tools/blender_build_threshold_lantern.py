"""Blender 5.x: original gothic lamp, unique UV atlas, editable source and game GLB.
Run with Blender --background --factory-startup --python this_file.
"""
import bpy, math, json, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/environment/threshold_lantern/v1'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'art_source/threshold_lantern_v1'
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.device = 'CPU'
model_collection = bpy.data.collections.new('01_LANTERN_MODEL')
scene.collection.children.link(model_collection)
studio = bpy.data.collections.new('02_PREVIEW_STUDIO_not_exported')
scene.collection.children.link(studio)
parts = []
materials = []

def material(name, dark, light, metal, rough):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    n = mat.node_tree.nodes
    n.clear()
    out = n.new('ShaderNodeOutputMaterial')
    emission = n.new('ShaderNodeEmission')
    tex = n.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 3.4
    tex.inputs['Detail'].default_value = 1.0
    tex.inputs['Roughness'].default_value = .35
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .2
    ramp.color_ramp.elements[0].color = (*dark,1)
    ramp.color_ramp.elements[1].position = .8
    ramp.color_ramp.elements[1].color = (*light,1)
    mat.node_tree.links.new(tex.outputs['Fac'], ramp.inputs[0])
    mat.node_tree.links.new(ramp.outputs['Color'], emission.inputs['Color'])
    mat.node_tree.links.new(emission.outputs[0], out.inputs['Surface'])
    mat['metallic'] = metal
    mat['roughness'] = rough
    materials.append(mat)
    return mat

iron = material('01_Charcoal_cast_iron',(.032,.043,.047),(.09,.115,.12),.65,.55)
red = material('02_Oxblood_enamel',(.12,.015,.012),(.33,.055,.028),.18,.62)
bronze = material('03_Worn_bronze',(.19,.10,.037),(.39,.25,.10),.68,.46)
stone = material('04_Blue_limestone',(.18,.235,.25),(.36,.40,.38),0,.9)
glass = material('05_Amber_diffusing_glass',(.43,.115,.018),(.9,.43,.075),0,.48)
edge = material('06_Enamel_edge_highlights',(.27,.044,.025),(.44,.105,.048),.18,.62)

def finish(obj, name, mat, bevel=0):
    obj.name = name
    for col in list(obj.users_collection): col.objects.unlink(obj)
    model_collection.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        m = obj.modifiers.new('Broad readable bevels','BEVEL')
        m.width = bevel
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier=m.name)
    parts.append(obj)
    return obj

def cylinder(name,z,r,depth,mat,vertices=8,r2=None,xy=(0,0),bevel=.012):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=depth,location=(*xy,z))
    return finish(bpy.context.object,name,mat,bevel)

def box(name,loc,size,mat,bevel=.015,angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=(0,0,angle))
    obj=bpy.context.object
    obj.scale=size
    return finish(obj,name,mat,bevel)

def beam(name,a,b,r,mat,vertices=6):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r*.85,depth=(b-a).length,location=(a+b)*.5)
    obj=bpy.context.object
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish(obj,name,mat,.004)

def ribbon(name,points,width,thickness,mat):
    # Flat forged bracket: silhouette is mesh geometry, not a normal-map trick.
    verts=[]
    for i,p in enumerate(points):
        before=Vector(points[max(0,i-1)])
        after=Vector(points[min(len(points)-1,i+1)])
        tangent=(after-before).normalized()
        side=Vector((-tangent.z,0,tangent.x))*width*.5
        for y in [-thickness*.5,thickness*.5]:
            for sign in [-1,1]: verts.append(Vector(p)+side*sign+Vector((0,y,0)))
    faces=[(0,2,3,1)]
    for i in range(len(points)-1):
        a=i*4;b=a+4
        faces.extend([(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)])
    a=(len(points)-1)*4
    faces.append((a,a+1,a+3,a+2))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    model_collection.objects.link(obj)
    finish(obj,name,mat,.007)

# Four-metre asset: generous forms remain readable at the game's camera distance.
cylinder('Stone plinth lower',.09,.38,.18,stone,8,bevel=.025)
cylinder('Stone plinth shoulder',.23,.32,.14,stone,8,r2=.26,bevel=.018)
cylinder('Iron foot',.37,.23,.14,iron,8)
cylinder('Red pedestal',.64,.19,.40,red,8,r2=.145)
cylinder('Pedestal crown',.88,.22,.10,iron,8)
cylinder('Tapered fluted shaft',1.75,.095,1.68,iron,12,r2=.065,bevel=.006)
for z,r in [(1.03,.12),(1.1,.11),(2.34,.105),(2.49,.145)]:
    cylinder('Forged shaft collar',z,r,.065,bronze if z==1.1 else iron,12,bevel=.007)
for i in range(6):
    a=i*math.tau/6
    beam('Red shaft fluting',(.082*math.cos(a),.082*math.sin(a),1.13),(.061*math.cos(a),.061*math.sin(a),2.30),.012,red)

# Two S-shaped braces support the lantern in silhouette.
for sign in [-1,1]:
    ribbon('Forged shoulder scroll',[(0,0,2.18),(sign*.17,0,2.30),(sign*.36,0,2.52),(sign*.38,0,2.68),(sign*.28,0,2.77),(sign*.19,0,2.72)],.065,.045,iron)

cylinder('Lantern lower bowl',2.69,.16,.23,iron,6,r2=.36,bevel=.012)
cylinder('Lantern base rim',2.835,.39,.07,bronze,6)
# Six glass faces as a solid, opaque diffusing glow; no transparent overdraw.
cylinder('Six amber glass panels',3.19,.29,.64,glass,6,r2=.33,bevel=0)
cylinder('Top cage rim',3.54,.395,.085,iron,6)
for i in range(6):
    a=i*math.tau/6
    ca,sa=math.cos(a),math.sin(a)
    beam('Cage upright',(.31*ca,.31*sa,2.86),(.36*ca,.36*sa,3.52),.028,iron)
    # Gothic lancet ribs over glass, broad enough to read in gameplay.
    b=(i+1)*math.tau/6
    p=Vector((.31*ca,.31*sa,3.02))
    q=Vector((.31*math.cos(b),.31*math.sin(b),3.02))
    tip=(p+q)*.5;tip.z=3.43;tip.x*=1.10;tip.y*=1.10
    beam('Lancet arch left',p,tip,.012,iron)
    beam('Lancet arch right',q,tip,.012,iron)

# Red pagoda-like Gothic roof made from a three-ring hexagonal profile.
def roof():
    verts=[]
    for radius,z in [(.47,3.59),(.32,3.72),(.11,4.03)]:
        for i in range(6):
            a=i*math.tau/6
            verts.append((radius*math.cos(a),radius*math.sin(a),z))
    faces=[]
    for level in range(2):
        for i in range(6):faces.append((level*6+i,level*6+(i+1)%6,(level+1)*6+(i+1)%6,(level+1)*6+i))
    faces.extend([tuple(reversed(range(6))),tuple(range(12,18))])
    mesh=bpy.data.meshes.new('Roof shaped facets')
    mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Oxblood six sided roof',mesh)
    model_collection.objects.link(obj)
    finish(obj,obj.name,red,.008)
roof()
for i in range(6):
    a=i*math.tau/6
    beam('Roof raised seams lower',(.47*math.cos(a),.47*math.sin(a),3.602),(.32*math.cos(a),.32*math.sin(a),3.732),.013,edge)
    beam('Roof raised seams upper',(.32*math.cos(a),.32*math.sin(a),3.732),(.11*math.cos(a),.11*math.sin(a),4.042),.013,edge)
cylinder('Roof finial collar',4.045,.09,.065,iron,8)
cylinder('Roof spear finial',4.19,.067,.24,iron,6,r2=0,bevel=0)
for i in range(4):
    a=math.pi/4+i*math.pi/2
    cylinder('Plinth bolt',.193,.025,.014,bronze,6,xy=(.27*math.cos(a),.27*math.sin(a)),bevel=.002)

# Recalculate mesh orientation, then generate a unique non-overlapping UV layout.
bpy.ops.object.select_all(action='DESELECT')
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
model=bpy.context.object
model.name='Gothic_Lantern_Threshold_v1'
scene.cursor.location=(0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012,area_weight=.4)
bpy.ops.object.mode_set(mode='OBJECT')
model.data.uv_layers.active.name='UV_Atlas'
atlas=bpy.data.images.new('Lantern_albedo_2048',width=2048,height=2048,alpha=False)
atlas.filepath_raw=str(OUT/'lantern_albedo_2048.png')
atlas.file_format='PNG'
for mat in materials:
    n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=atlas
    mat.node_tree.nodes.active=n
scene.render.bake.margin=12
bpy.ops.object.bake(type='EMIT')
atlas.save()

# Final exported PBR materials: shared baked color atlas, material-specific roughness.
for mat in materials:
    nodes=mat.node_tree.nodes;nodes.clear()
    out=nodes.new('ShaderNodeOutputMaterial');out.location=(400,0)
    bsdf=nodes.new('ShaderNodeBsdfPrincipled');bsdf.location=(80,0)
    tex=nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.location=(-240,0)
    tex.label='Unique UV atlas · 2048 px'
    mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    bsdf.inputs['Metallic'].default_value=mat['metallic']
    bsdf.inputs['Roughness'].default_value=mat['roughness']
    if mat==glass:
        mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value=2.5
    mat.node_tree.links.new(bsdf.outputs[0],out.inputs['Surface'])
    nodes.active=tex

model.data.calc_loop_triangles()
triangles=len(model.data.loop_triangles)
model['asset_notes']='Original stylized mid-poly model. Z-up Blender, metres. Foot origin. No collision/lights in game GLB.'
model['triangle_count']=triangles
bpy.ops.uv.export_layout(filepath=str(SOURCE/'lantern_uv_layout.svg'),mode='SVG',size=(2048,2048),opacity=.3,export_all=True)
# Raster UV template needs no GPU context in background Blender.
import numpy as np
size=2048
pixels=np.zeros((size,size,4),dtype=np.float32)
pixels[:,:,:3]=.018;pixels[:,:,3]=1
uv=model.data.uv_layers.active.data
for poly in model.data.polygons:
    loops=list(poly.loop_indices)
    for i,j in zip(loops,loops[1:]+loops[:1]):
        a=np.array(uv[i].uv)*(size-1);b=np.array(uv[j].uv)*(size-1)
        count=max(2,int(np.max(np.abs(b-a)))+1)
        line=np.linspace(a,b,count).astype(int)
        pixels[line[:,1],line[:,0],:3]=(.9,.68,.35)
layout=bpy.data.images.new('UV layout reference',width=size,height=size)
layout.pixels.foreach_set(pixels.ravel())
layout.filepath_raw=str(SOURCE/'lantern_uv_layout.png');layout.file_format='PNG';layout.save()
bpy.data.images.remove(layout)
bpy.ops.export_scene.gltf(filepath=str(OUT/'gothic_lantern.glb'),export_format='GLB',use_selection=True,export_yup=True,export_lights=False,export_cameras=False)

# A separate preview studio, never included in the selected-object game export.
def to_studio(obj):
    for col in list(obj.users_collection):col.objects.unlink(obj)
    studio.objects.link(obj)

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015))
floor=bpy.context.object;floor.name='Studio_ground';to_studio(floor)
fm=bpy.data.materials.new('Studio_ground_only');fm.diffuse_color=(.035,.055,.065,1);floor.data.materials.append(fm)
def area(name,loc,power,color,size,target=(0,0,2)):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);studio.objects.link(obj);obj.location=loc
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
area('Large warm key',(3,-4,6),650,(1,.78,.55),4)
area('Cool rim',(-3,2,5),950,(.34,.63,1),3)
area('Soft front fill',(-4,-4,2),320,(.65,.8,1),4)
light=bpy.data.lights.new('Lantern_preview_light','POINT');light.energy=18;light.color=(1,.38,.08);light.shadow_soft_size=.28
obj=bpy.data.objects.new('Lantern_preview_light',light);studio.objects.link(obj);obj.location=(0,0,3.2)
world=bpy.data.worlds.new('Cold studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.085,.12,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35;scene.world=world
bpy.ops.object.camera_add(location=(5,-8,4.5))
camera=bpy.context.object;camera.name='Preview_camera';to_studio(camera)
camera.rotation_euler=(Vector((0,0,2.15))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=5.1;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'lantern_preview.png')

# Save an immediately useful modelling view with model selected, studio hidden in viewport.
bpy.ops.object.select_all(action='DESELECT');model.select_set(True);bpy.context.view_layer.objects.active=model
studio.hide_viewport=True
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_distance=6
            a.spaces.active.region_3d.view_location=(0,0,2.1)
            a.spaces.active.shading.type='MATERIAL'
atlas.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'gothic_lantern.blend'))
studio.hide_viewport=False
bpy.ops.render.render(write_still=True)
camera.location=(-5,7,4.1)
camera.rotation_euler=(Vector((0,0,2.15))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'lantern_preview_back.png')
bpy.ops.render.render(write_still=True)
report={'triangles':triangles,'vertices':len(model.data.vertices),'materials':len(model.data.materials),'uv_layers':[u.name for u in model.data.uv_layers],'height_metres':round(model.dimensions.z,3),'texture':'lantern_albedo_2048.png','addons_required':False}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('LANTERN_BUILD_OK',json.dumps(report))
