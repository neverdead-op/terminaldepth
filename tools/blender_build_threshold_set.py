"""Original mid-poly modular set for the Last Human Threshold. Blender 5.x."""
import bpy, math, json, random, struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment/threshold_set/v1';OUT.mkdir(parents=True,exist_ok=True)
SRC=ROOT/'art_source/threshold_set_v1';SRC.mkdir(parents=True,exist_ok=True);(SRC/'.gdignore').touch()
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

# 1: tileable 4x4 stone floor, actual bevelled large stones.
box('Mortar',(0,0,-.15),(4,4,.25),dark,0)
grid={}
for y in range(5):
    for x in range(5):grid[x,y]=Vector((-2+x+(rng.uniform(-.22,.22) if x not in [0,4] else 0),-2+y+(rng.uniform(-.22,.22) if y not in [0,4] else 0),0))
for y in range(4):
    for x in range(4):
        quad=[grid[x,y],grid[x+1,y],grid[x+1,y+1],grid[x,y+1]]
        polys=[quad] if (x+y)%3 else [[quad[0],quad[1],quad[2]],[quad[0],quad[2],quad[3]]]
        for points in polys:
            center=sum(points,Vector())/len(points)
            points=[center+(p-center)*.94 for p in points]
            verts=[(p.x,p.y,z) for z in [-.14,.04+rng.uniform(-.006,.006)] for p in points]
            n=len(points)
            faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
            mesh('Irregular flagstone',verts,faces,stone if rng.random()<.82 else pale,.025)
save_asset('floor_flagstones_4m')
# 2: cliff platform edge and 3: tall modular wall.
for name,h in [('platform_edge_4m',3),('wall_4m',4)]:
    box('Mortar',(0,0,-h/2 if name.startswith('platform') else h/2),(4,.62,h),dark,0)
    for row in range(int(h/.5)):
        for col in range(4):box('Large block',(-1.5+col,0,(-h if name.startswith('platform') else 0)+.25+row*.5),(.96,.72,.47),stone,.045)
    box('Coping',(0,0,.08 if name.startswith('platform') else h+.08),(4.12,.92,.20),pale,.035)
    save_asset(name)
# 4: freestanding gothic arch, 5: square pier.
arch('Gateway',3.6,4.8,.48,.9,pale)
for side in [-1,1]:
    box('Buttress',(side*2.24,0,1.7),(.55,1.2,3.4),stone,.045)
    cyl('Spear',(side*2.24,0,5.8),.22,.75,iron,4,r2=0)
save_asset('arch_gateway')
for z,w,h in [(.14,.9,.28),(1.0,.61,1.44),(1.78,.86,.17),(1.99,.49,.26)]:box('Pier',(0,0,z),(w,w,h),pale if z!=1 else stone,.035)
cyl('Pinnacle',(0,0,2.22),.25,.25,iron,8,r2=.03);save_asset('column_cap')
# 6: rail module with readable large gothic points.
for z in [.28,1.12]:box('Rail',(0,0,z),(4,.10,.1),iron,.01)
for i in range(13):
    x=-1.9+i*3.8/12
    box('Picket',(x,0,.75),(.045,.055,1.35),iron,.006)
    cyl('Spear',(x,0,1.5),.065,.22,iron,4,r2=0,bevel=0)
save_asset('iron_railing_4m')
# 7: steps rise from -1.6 to zero towards local -Y (Godot +Z).
for i in range(8):box('Stair tread',(0,-1.75+i*.5,-1.6+.1*(i+1)),(4,.52,.2*(i+1)),stone,.025)
save_asset('stair_4m')
# 8: main facade, broad stone base and structural red timber upper storey.
box('Stone facade',(0,0,2.1),(10,.65,4.2),stone,.045)
box('Plaster upper',(0,0,5.8),(10,.45,3.2),plaster,.035)
for x in [-4.8,-2.45,0,2.45,4.8]:box('Red timber upright',(x,-.32,5.8),(.20,.24,3.4),red,.025)
for z in [4.2,5.7,7.4]:box('Red timber rail',(0,-.34,z),(10.2,.26,.24),red,.02)
for x in [-3.6,-1.25,1.25,3.6]:beam('Diagonal brace',(x-.85,-.44,4.4),(x+.85,-.44,5.6),.11,red,4)
for x in [-4.85,4.85]:
    for row in range(8):box('Corner quoin',(x,-.22,.26+row*.52),(.7,.72,.48),pale,.035)
# Facade faces Blender -Y -> Godot +Z. Two emission windows, lattice rods.
for x in [-3.15,3.15]:
    box('Recess',(x,-.38,5.75),(1.42,.1,2.05),wood,.025)
    box('Amber window',(x,-.45,5.75),(1.12,.035,1.78),glow,.01)
    for xx in [-.56,0,.56]:box('Window mullion',(x+xx,-.49,5.75),(.055,.07,1.9),iron,.005)
    for z in [5.3,5.85,6.4]:box('Window rail',(x,-.5,z),(1.15,.065,.045),iron,.005)
    box('Window cornice',(x,-.45,6.83),(1.65,.35,.18),pale)
# Portal ornament and a dark warm interior, separately installed open door.
arch('Entry',2.5,3.5,.32,.32,pale,y=-.55)
box('Doorway shadow',(0,-.74,1.5),(2.35,.04,3),wood,.01)
box('Warm lower doorway',(0,-.77,1.15),(1.7,.03,2.3),glow,.01)
# Large shingled roof silhouette; individual thick tiles, no photographic roof texture.
for side in [-1,1]:
    for row in range(5):
        yy=side*(.30+row*.44);zz=9.35-row*.37
        for col in range(11):
            o=box('Red roof tile',(-5.05+col*1.01,yy,zz),(1.02,.65,.11),tile,.035)
            o.rotation_euler.x=-side*.66
for x in [-5.3,5.3]:beam('Roof verge',(x,-2.5,7.55),(x,0,9.6),.14,red,4);beam('Roof verge',(x,0,9.6),(x,2.5,7.55),.14,red,4)
beam('Ridge',(-5.4,0,9.6),(5.4,0,9.6),.16,red,6)
box('Chimney',(3.8,.75,9.2),(.85,.85,2),stone,.05);box('Chimney cap',(3.8,.75,10.2),(1.1,1.1,.22),pale)
save_asset('tavern_facade')
# 9: doors, freestanding panel can be placed opened without animation.
for x in [-.48,.48]:
    box('Oak door',(x,0,1.35),(.94,.15,2.7),wood,.025)
    for z in [.55,1.9]:box('Strap',(x,-.1,z),(.91,.06,.10),iron,.01)
    cyl('Handle',(x+(.25 if x<0 else -.25),-.14,1.3),.05,.1,bronze,8)
save_asset('oak_double_door')
# 10: hand-cranked wooden hoist frame, gear wheels, rope drum.
for x in [-1.8,1.8]:
    box('Hoist leg',(x,0,2.5),(.3,.35,5),red)
    beam('Hoist brace',(x,0,.4),(x,-1.5,2.1),.12,wood,4)
box('Hoist top',(0,0,5),(4.5,.4,.35),wood)
for x in [-1.25,1.25]:
    wheel=cyl('Pulley',(x,0,5.15),.55,.18,iron,16)
    wheel.rotation_euler.y=math.pi/2
    for i in range(8):
        a=i*math.tau/8
        beam('Pulley spoke',(x-.12,0,5.15),(x-.12,.43*math.sin(a),5.15+.43*math.cos(a)),.035,bronze,4)
box('Drum stand',(0,-.8,.9),(1.5,.8,.25),iron)
drum=cyl('Winch drum',(0,-.8,1.2),.32,1.8,wood,12);drum.rotation_euler.y=math.pi/2
beam('Crank',(1.0,-.8,1.2),(1,-.8,1.85),.06,iron);beam('Crank grip',(1,-.8,1.85),(1.35,-.8,1.85),.06,wood)
save_asset('chain_hoist')
# 11: wooden lowering cage/platform.
for i in range(8):box('Deck plank',(-1.75+i*.5,0,0),(.47,3,.20),wood,.02)
for x in [-1.8,1.8]:
    for y in [-1.35,1.35]:box('Cage upright',(x,y,.7),(.12,.12,1.6),iron,.01)
    box('Cage rail',(x,0,1.3),(.1,2.9,.1),iron,.01)
save_asset('lift_platform')
# 12: one metre of alternating elongated chain links, inexpensive repeated module.
for i in range(4):
    bpy.ops.mesh.primitive_torus_add(major_segments=8,minor_segments=4,major_radius=.13,minor_radius=.029,location=(0,0,-i*.26))
    o=bpy.context.object;o.scale=(1,1.65,1);o.rotation_euler.x=math.pi/2
    if i%2:o.rotation_euler.z=math.pi/2
    finish(o,'Forged chain link',iron,0)
save_asset('chain_1m')
# 13: distant ten metre support: simple planes and bands, not full near-detail masonry.
box('Distant pier',(0,0,-5),(2.8,2.8,10),dark,.12)
for z in [-1,-5,-9]:box('Red band',(0,0,z),(3.1,3.1,.3),red,.03)
for x in [-1.25,1.25]:box('Pier rib',(x,-1.5,-5),(.3,.4,10),stone,.03)
save_asset('abyss_pier_10m')
# 14: modular distant aqueduct arch 8m opening.
arch('Aqueduct',8,8,.6,1.8,stone)
box('Bridge deck',(0,0,8.55),(10,2.8,.45),pale,.05)
save_asset('abyss_bridge_10m')
# 15-18 furniture.
box('Crate body',(0,0,.55),(1.1,.9,1.1),wood,.035)
for x in [-.49,.49]:box('Crate strap',(x,-.47,.55),(.13,.06,1.1),red,.01)
beam('Diagonal crate brace',(-.4,-.51,.1),(.4,-.51,1),.06,wood,4);save_asset('crate')
for z,r,h in [(.2,.38,.4),(.6,.44,.4),(1,.38,.4)]:cyl('Barrel stave',(0,0,z),r,h,wood,12,r2=r+.025 if z<.6 else r-.025)
for z in [.13,.4,.83,1.1]:cyl('Barrel hoop',(0,0,z),.42 if z in [.4,.83] else .39,.07,iron,12)
cyl('Barrel lid',(0,0,1.22),.37,.06,wood,12);save_asset('barrel')
for x in [-.85,.85]:box('Bench leg',(x,0,.35),(.16,.45,.7),iron,.02)
for y in [-.2,0,.2]:box('Bench plank',(0,y,.75),(2.2,.18,.14),wood,.02)
save_asset('bench')
# Banner with a jagged swallow tail, painted ornament deliberately broad.
mesh('Banner',[(-.65,0,0),(.65,0,0),(.65,0,-2.25),(.25,0,-2.05),(0,0,-2.5),(-.25,0,-2.05),(-.65,0,-2.25)],[tuple(range(7))],cloth,0)
beam('Banner rod',(-.8,0,.08),(.8,0,.08),.04,iron)
box('Banner sigil',(0,-.015,-.9),(.065,.02,1.0),bronze,.002)
for side in [-1,1]:beam('Sigil branch',(0,-.02,-1.0),(side*.3,-.02,-.6),.025,bronze,4)
save_asset('red_banner')
# 19 rubble; 20 ivy with actual thick broad leaves, no alpha texture.
for i in range(9):box('Broken stone',(rng.uniform(-.8,.8),rng.uniform(-.5,.5),rng.uniform(.08,.3)),(rng.uniform(.2,.5),rng.uniform(.2,.4),rng.uniform(.15,.4)),stone,.035,rng.uniform(-1,1))
save_asset('rubble_cluster')
for i in range(16):
    x=rng.uniform(-.7,.7);z=rng.uniform(-1.2,1.2)
    beam('Ivy stem',(0,0,-1.4),(x,.02,z),.015,wood,4)
    mesh('Broad ivy leaf',[(x,0,z+.22),(x+.17,-.035,z+.05),(x+.1,-.07,z-.16),(x,-.09,z-.23),(x-.17,-.04,z)],[(0,1,2),(0,2,3),(0,3,4)],leaf,0)
save_asset('red_ivy_cluster')
# 21: drain inset, not a black decal.
box('Drain rim',(0,0,-.02),(1.2,.9,.08),iron,.015)
for i in range(7):box('Drain slot',(-.48+i*.16,0,.025),(.055,.76,.04),dark,.005)
save_asset('drain_grate')

# Shared, non-overlapping atlas; merge for one bake, then restore each asset via groups.
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
bpy.ops.object.select_all(action='DESELECT');built[6].select_set(True);bpy.context.view_layer.objects.active=built[6]
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'threshold_models.blend'))
(OUT/'catalog.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('THRESHOLD_SET_OK',len(stats),'models',sum(v['triangles'] for v in stats.values()),'triangles total')
