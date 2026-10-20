"""Original mid-poly modular set for the Last Human Threshold. Blender 5.x."""
import bpy, math, json, random, struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment/threshold_polish/v1';OUT.mkdir(parents=True,exist_ok=True)
SRC=ROOT/'art_source/threshold_polish_v1';SRC.mkdir(parents=True,exist_ok=True);(SRC/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.samples=1
rng=random.Random(1607);parts=[];assets={};mats=[]
def mat(name,dark,light,metal=0,rough=.85):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
    out=n.new('ShaderNodeOutputMaterial');emit=n.new('ShaderNodeEmission');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=2.5;noise.inputs['Detail'].default_value=1
    coords=n.new('ShaderNodeNewGeometry');ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(*dark,1);ramp.color_ramp.elements[1].color=(*light,1)
    m.node_tree.links.new(coords.outputs['Position'],noise.inputs['Vector']);m.node_tree.links.new(noise.outputs['Fac'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],emit.inputs[0]);m.node_tree.links.new(emit.outputs[0],out.inputs['Surface'])
    m['metal']=metal;m['rough']=rough;mats.append(m);return m
stone=mat('Limestone',(.17,.20,.20),(.39,.39,.33));pale=mat('Cut_stone',(.28,.30,.28),(.53,.48,.37))
dark=mat('Deep_mortar',(.065,.085,.09),(.12,.15,.15));iron=mat('Forged_iron',(.025,.038,.043),(.095,.13,.14),.65,.6)
red=mat('Oxblood_painted_oak',(.10,.012,.014),(.29,.042,.027));wood=mat('Dark_oak',(.09,.048,.027),(.25,.15,.07))
tile=mat('Red_slate',(.13,.022,.018),(.35,.075,.038));bronze=mat('Antique_bronze',(.15,.08,.025),(.35,.22,.08),.65,.5)
plaster=mat('Old_plaster',(.27,.28,.23),(.53,.50,.39));glow=mat('Amber_window',(.5,.16,.02),(1,.52,.12),0,.5)
cloth=mat('Red_canvas',(.13,.012,.019),(.32,.035,.035));leaf=mat('Red_ivy',(.11,.017,.018),(.32,.052,.022))

def finish(o,name,m,bevel=0):
    o.name=name;o.data.materials.append(m);bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Broad_bevel','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    parts.append(o);return o
def box(name,loc,size,m,bevel=.025,angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=(0,0,angle));o=bpy.context.object;o.scale=size;return finish(o,name,m,bevel)
def cyl(name,loc,r,h,m,n=8,r2=None,bevel=.012):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=h,location=loc);return finish(bpy.context.object,name,m,bevel)
def beam(name,a,b,r,m,n=6):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,m,n,bevel=0);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,verts,faces,m,bevel=.01):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update();o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);return finish(o,name,m,bevel)
def arch(name,width,height,thick,depth,m,y=0,z=0):
    # Segmented semicircular voussoirs: genuine opening, not a painted dark rectangle.
    r=width/2;spring=height-r
    box(name+' jamb L',(-r-thick/2,y,z+spring/2),(thick,depth,spring),m)
    box(name+' jamb R',(r+thick/2,y,z+spring/2),(thick,depth,spring),m)
    for i in range(9):
        a=i*math.pi/9+.009;b=(i+1)*math.pi/9-.009
        verts=[]
        for yy in [y-depth/2,y+depth/2]:
            for rr,t in [(r,a),(r,b),(r+thick,b),(r+thick,a)]:verts.append((rr*math.cos(t),yy,z+spring+rr*math.sin(t)))
        mesh(name+' arch stone',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m,.018)
def save_asset(name):
    global parts
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.vertex_groups.new(name=name).add(list(range(len(o.data.vertices))),1,'REPLACE')
    assets[name]=o;parts=[]

# Irregular clipped Voronoi slabs: no aligned four metre grid inside the module.
box('Mortar',(0,0,-.16),(4,4,.26),dark,0)
seeds=[(-2+(x+.5)*.8+rng.uniform(-.22,.22),-2+(y+.5)*.8+rng.uniform(-.22,.22)) for y in range(5) for x in range(5)]
for sx,sy in seeds:
    poly=[(-2,-2),(2,-2),(2,2),(-2,2)]
    for tx,ty in seeds:
        if (tx,ty)==(sx,sy):continue
        nx,ny=tx-sx,ty-sy;d=(tx*tx+ty*ty-sx*sx-sy*sy)/2
        clipped=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            da=a[0]*nx+a[1]*ny-d;db=b[0]*nx+b[1]*ny-d
            if da<=0:clipped.append(a)
            if (da<=0)!=(db<=0):
                t=da/(da-db);clipped.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
        poly=clipped
    cx=sum(v[0] for v in poly)/len(poly);cy=sum(v[1] for v in poly)/len(poly)
    poly=[(cx+(x-cx)*.965,cy+(y-cy)*.965) for x,y in poly]
    n=len(poly);top=.035+rng.uniform(-.008,.008)
    verts=[(x,y,z) for z in [-.13,top] for x,y in poly]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh('Chipped polygon slab',verts,faces,stone if rng.random()<.85 else pale,.035)
save_asset('courtyard_stones')
# Sculptural stepped gothic buttress, a strong silhouette at architectural corners.
for z,w,dep,h in [(.25,1.4,1.5,.5),(2.4,.92,1.1,3.8),(4.5,1.15,1.35,.35),(5.4,.65,.8,1.5),(6.25,.9,1.0,.25)]:
    box('Buttress stone',(0,0,z),(w,dep,h),stone if h>1 else pale,.06)
cyl('Pointed finial',(0,0,7),.43,1.3,pale,4,r2=0)
for z in [1,2,3,4]:box('Broad dressed stone',(0,-.59,z),(.8,.12,.1),pale,.02)
save_asset('gothic_buttress')
# Dense distant balcony: paired arches, balustrade and emissive expedition windows.
for x in [-3,3]:
    start=len(parts);arch('Tall recess',4.2,7.2,.35,.65,stone)
    for o in parts[start:]:o.location.x+=x
box('Balcony deck',(0,0,7.5),(12,.9,.35),pale,.04)
for x in range(-6,7):
    box('Balustrade',(x,-.25,8.2),(.1,.12,1.3),iron,.01)
    cyl('Spear',(x,-.25,8.95),.1,.3,iron,4,r2=0)
box('Top rail',(0,-.25,8.7),(12,.12,.12),iron,.01)
for x in [-5,-2,2,5]:
    box('Amber window',(x,0,7.95),(.16,.12,.45),glow,.02)
save_asset('abyss_arcade')
bpy.ops.object.select_all(action='DESELECT')
for o in assets.values():o.select_set(True)
bpy.context.view_layer.objects.active=next(iter(assets.values()));bpy.ops.object.join();whole=bpy.context.object
whole.name='_AtlasBake'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(angle_limit=math.radians(65),island_margin=.002,area_weight=.35)
bpy.ops.object.mode_set(mode='OBJECT')
whole.data.uv_layers.active.name='UV_Atlas'
atlas=bpy.data.images.new('Threshold_set_albedo_4096',width=4096,height=4096,alpha=False);atlas.filepath_raw=str(OUT/'threshold_albedo_4096.png');atlas.file_format='PNG'
for m in mats:
    n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=atlas;m.node_tree.nodes.active=n
scene.render.bake.margin=6;bpy.ops.object.bake(type='EMIT');atlas.save()
for m in mats:
    n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');s=n.new('ShaderNodeBsdfPrincipled');t=n.new('ShaderNodeTexImage');t.image=atlas;t.location=(-250,0);o.location=(350,0)
    m.node_tree.links.new(t.outputs['Color'],s.inputs['Base Color']);s.inputs['Metallic'].default_value=m['metal'];s.inputs['Roughness'].default_value=m['rough']
    if m==glow:m.node_tree.links.new(t.outputs['Color'],s.inputs['Emission Color']);s.inputs['Emission Strength'].default_value=2
    if m in [cloth,leaf]:m.surface_render_method='DITHERED';m.use_backface_culling=False
    m.node_tree.links.new(s.outputs[0],o.inputs[0]);n.active=t
alluv=whole.data.uv_layers.active.data
stats={};built=[]
for name in assets:
    group=whole.vertex_groups[name].index
    indices={v.index for v in whole.data.vertices if any(g.group==group for g in v.groups)}
    mapping={old:new for new,old in enumerate(sorted(indices))}
    faces=[p for p in whole.data.polygons if p.vertices[0] in indices]
    d=bpy.data.meshes.new(name);d.from_pydata([whole.data.vertices[v].co for v in sorted(indices)],[],[[mapping[v] for v in p.vertices] for p in faces]);d.update()
    for m in whole.data.materials:d.materials.append(m)
    uv=d.uv_layers.new(name='UV_Atlas')
    for dst,src in zip(d.polygons,faces):
        dst.material_index=src.material_index
        for dl,sl in zip(dst.loop_indices,src.loop_indices):uv.data[dl].uv=alluv[sl].uv
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_lights=False,export_cameras=False)
    # Share the atlas on disk instead of embedding the same 7MB PNG in all 21 GLBs.
    path=OUT/(name+'.glb');raw=path.read_bytes();jl=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+jl]);binary=raw[28+jl:]
    image_views={im['bufferView'] for im in doc.get('images',[]) if 'bufferView' in im}
    remap={};views=[];newbin=bytearray()
    for index,view in enumerate(doc['bufferViews']):
        if index in image_views:continue
        remap[index]=len(views)
        while len(newbin)%4:newbin.append(0)
        v=dict(view);old=v.get('byteOffset',0);v['byteOffset']=len(newbin);newbin.extend(binary[old:old+v['byteLength']]);views.append(v)
    for im in doc.get('images',[]):
        im.pop('bufferView',None);im.pop('mimeType',None);im['uri']='threshold_albedo_4096.png'
    def remap_views(value):
        if isinstance(value,dict):
            for k,v in value.items():
                if k=='bufferView':value[k]=remap[v]
                else:remap_views(v)
        elif isinstance(value,list):
            for v in value:remap_views(v)
    remap_views(doc);doc['bufferViews']=views;doc['buffers'][0]['byteLength']=len(newbin)
    while len(newbin)%4:newbin.append(0)
    j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(j)+len(newbin))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(newbin),0x004e4942)+newbin)
    d.calc_loop_triangles();stats[name]={'triangles':len(d.loop_triangles),'dimensions':list(o.dimensions)};built.append(o)
bpy.data.objects.remove(whole,do_unlink=True)
# A single editable Blender gallery, assets separated and named. Export files keep origin zero.
for i,o in enumerate(built):o.location=((i%5)*15,(i//5)*16,0)
atlas.pack()
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':a.spaces.active.region_3d.view_distance=85;a.spaces.active.region_3d.view_location=(28,25,0);a.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT');built[0].select_set(True);bpy.context.view_layer.objects.active=built[0]
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'threshold_models.blend'))
(OUT/'catalog.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('THRESHOLD_SET_OK',len(stats),'models',sum(v['triangles'] for v in stats.values()),'triangles total')
