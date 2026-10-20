"""Three original mid-poly background gothic buildings, UV atlas and packed Blender source."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment/threshold_skyline/v1';OUT.mkdir(parents=True,exist_ok=True)
SRC=ROOT/'art_source/threshold_skyline_v1';SRC.mkdir(parents=True,exist_ok=True);(SRC/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
parts=[];buildings=[];materials=[]
def material(name,color,rough=.9):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
    out=n.new('ShaderNodeOutputMaterial');emit=n.new('ShaderNodeEmission');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1.4;noise.inputs['Detail'].default_value=0
    geom=n.new('ShaderNodeNewGeometry');ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=tuple(v*.7 for v in color)+(1,);ramp.color_ramp.elements[1].color=tuple(v*1.18 for v in color)+(1,)
    m.node_tree.links.new(geom.outputs['Position'],noise.inputs['Vector']);m.node_tree.links.new(noise.outputs['Fac'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],emit.inputs[0]);m.node_tree.links.new(emit.outputs[0],out.inputs[0]);m['rough']=rough;materials.append(m);return m
stone=material('Blue_grey_stone',(.17,.20,.19));roof=material('Oxblood_roof',(.19,.025,.025));iron=material('Dark_red_timber',(.065,.028,.027));window=material('Warm_window',(.7,.27,.045));dark=material('Window_recess',(.018,.025,.03))
def finish(o,name,m,bevel=0):
    o.name=name;o.data.materials.append(m);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Silhouette_bevel','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    parts.append(o);return o
def box(name,at,size,m,bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.scale=size;return finish(o,name,m,bevel)
def cone(name,at,r,h,m,n=4):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=0,depth=h,location=at);return finish(bpy.context.object,name,m)
def gable(width,depth,base,height):
    w=width/2;d=depth/2
    v=[(-w,-d,base),(w,-d,base),(w,d,base),(-w,d,base),(0,-d,base+height),(0,d,base+height)]
    mesh=bpy.data.meshes.new('Sharp gable');mesh.from_pydata(v,[],[(0,4,1),(3,2,5),(0,3,5,4),(4,5,2,1),(0,1,2,3)]);mesh.update();o=bpy.data.objects.new('Tall sharp roof',mesh);scene.collection.objects.link(o);finish(o,o.name,roof,.035)
def lights(width,base,rows,depth):
    for row in range(rows):
        for col in [-1,1]:
            x=col*width*.25;z=base+row*1.65
            box('Window recess',(x,-depth/2-.03,z),(.58,.08,.98),dark,.015)
            if (row+(col+1)//2)%3!=0:
                box('Amber pane',(x,-depth/2-.08,z),(.36,.035,.72),window,.008)
                box('Mullion',(x,-depth/2-.11,z),(.055,.035,.72),iron,.006)
def save(name):
    global parts
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.vertex_groups.new(name=name).add(list(range(len(o.data.vertices))),1,'REPLACE');buildings.append(o);parts=[]

# Asymmetrical steep roof, chimney and large spire: silhouettes rather than facade microdetail.
box('Narrow stone house',(0,0,3.5),(4.3,4,7),stone);gable(4.9,4.7,7,5)
for x in [-2.1,2.1]:box('Vertical beam',(x,-2.1,4.5),(.18,.17,5.2),iron)
for z in [2.5,4.6,6.8]:box('Red rail',(0,-2.12,z),(4.4,.18,.16),iron)
box('Tall chimney',(1.3,.7,10),(.6,.7,4.4),stone);box('Chimney cap',(1.3,.7,12.25),(.85,.9,.22),iron)
lights(4.3,1.4,3,4);save('gabled_house')
box('Tower house',(0,0,4.5),(3.5,3.6,9),stone);gable(4.1,4.1,9,5.5)
box('Side turret',(1.8,.1,6.3),(1.6,1.8,9.2),stone);cone('Turret spire',(1.8,.1,13.4),1.5,5,roof,6)
for z in [3,6,8.8]:box('Red storey rail',(0,-1.88,z),(3.7,.2,.2),iron)
lights(3.5,1.6,4,3.6);save('turret_house')
box('Belfry body',(0,0,6),(4.4,4.4,12),stone)
for x in [-2.15,2.15]:
    for y in [-2.15,2.15]:box('Tower buttress',(x,y,6),(.4,.4,12.3),iron)
box('Crown cornice',(0,0,12),(5,5,.45),stone)
for x in [-1.7,1.7]:
    for y in [-1.7,1.7]:
        box('Belfry corner',(x,y,13.5),(.45,.45,2.8),stone)
        cone('Small pinnacle',(x,y,15.5),.55,1.4,roof)
box('Belfry dark opening',(0,0,13.4),(3.3,3.3,2.4),dark)
cone('Belfry needle roof',(0,0,18),3.25,7,roof)
cone('Finial',(0,0,22),.20,1.2,iron,6)
lights(4.4,2,3,4.4);save('needle_belfry')

bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=buildings[0];bpy.ops.object.join();whole=bpy.context.object;whole.name='_AtlasBake'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(angle_limit=math.radians(65),island_margin=.007);bpy.ops.object.mode_set(mode='OBJECT');whole.data.uv_layers.active.name='UV_Atlas'
atlas=bpy.data.images.new('Skyline_albedo_1024',width=1024,height=1024,alpha=False);atlas.filepath_raw=str(OUT/'skyline_albedo_1024.png');atlas.file_format='PNG'
for m in materials:n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=atlas;m.node_tree.nodes.active=n
scene.render.bake.margin=4;bpy.ops.object.bake(type='EMIT');atlas.save()
for m in materials:
    n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');s=n.new('ShaderNodeBsdfPrincipled');t=n.new('ShaderNodeTexImage');t.image=atlas;m.node_tree.links.new(t.outputs[0],s.inputs['Base Color']);s.inputs['Roughness'].default_value=m['rough']
    if m==window:m.node_tree.links.new(t.outputs[0],s.inputs['Emission Color']);s.inputs['Emission Strength'].default_value=1
    m.node_tree.links.new(s.outputs[0],out.inputs[0]);n.active=t
result={};saved=[]
for name in ['gabled_house','turret_house','needle_belfry']:
    group=whole.vertex_groups[name].index;ids=sorted(v.index for v in whole.data.vertices if any(g.group==group for g in v.groups));index={old:new for new,old in enumerate(ids)};faces=[p for p in whole.data.polygons if p.vertices[0] in index]
    d=bpy.data.meshes.new(name);d.from_pydata([whole.data.vertices[i].co for i in ids],[],[[index[v] for v in p.vertices] for p in faces]);d.update()
    for m in whole.data.materials:d.materials.append(m)
    uv=d.uv_layers.new(name='UV_Atlas')
    for a,b in zip(d.polygons,faces):
        a.material_index=b.material_index
        for al,bl in zip(a.loop_indices,b.loop_indices):uv.data[al].uv=whole.data.uv_layers.active.data[bl].uv
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_lights=False,export_cameras=False)
    d.calc_loop_triangles();result[name]=len(d.loop_triangles);saved.append(o)
bpy.data.objects.remove(whole,do_unlink=True)
for i,o in enumerate(saved):o.location.x=i*9
atlas.pack();bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'gothic_skyline.blend'))
(OUT/'catalog.json').write_text(json.dumps(result,indent=2));print('SKYLINE_OK',result)
