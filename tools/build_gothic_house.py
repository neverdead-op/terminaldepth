"""Original game-ready gothic house. Metric UVs, merged materials, embedded GLB textures.
No external Python packages or Blender required. Front faces +Z; footprint 5.4 x 6.4 m.
"""
from pathlib import Path
import math, struct, json

OUT = Path('assets/buildings/gothic_house')
surfaces = {}
materials = [
    {'name': 'Painted ashlar', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'baseColorFactor': [.78,.79,.76,1], 'metallicFactor':0,'roughnessFactor':.9}},
    {'name': 'Weathered carved limestone', 'pbrMetallicRoughness': {'baseColorFactor':[.24,.225,.19,1], 'metallicFactor':0,'roughnessFactor':.86}},
    {'name': 'Painted slate', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 2}, 'baseColorFactor':[.75,.80,.84,1], 'metallicFactor':0,'roughnessFactor':.86}},
    {'name': 'Painted oak', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 1}, 'metallicFactor':0,'roughnessFactor':.9}},
    {'name': 'Blackened iron', 'pbrMetallicRoughness': {'baseColorFactor':[.055,.065,.07,1], 'metallicFactor':.45,'roughnessFactor':.6}},
    {'name': 'Recess shadow', 'pbrMetallicRoughness': {'baseColorFactor':[.035,.043,.047,1], 'metallicFactor':0,'roughnessFactor':1}},
    {'name': 'Dim amber glass', 'pbrMetallicRoughness': {'baseColorFactor':[.13,.09,.045,1], 'metallicFactor':0,'roughnessFactor':.5}, 'emissiveFactor':[.065,.022,.004]},
]

def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def tri(mat,a,b,c,uv=None):
    data=surfaces.setdefault(mat, {'p':[], 'n':[], 'u':[], 'i':[]})
    n=cross(sub(b,a),sub(c,a)); l=math.sqrt(sum(x*x for x in n))
    if l<1e-8: return
    n=tuple(x/l for x in n)
    start=len(data['p'])//3
    for j,v in enumerate((a,b,c)):
        data['p'].extend(v); data['n'].extend(n)
        data['u'].extend(uv[j] if uv else (v[0]/3, -v[1]/3))
    data['i'].extend((start,start+1,start+2))

def quad(mat,pts,scale=3):
    # Real-world UV scale on each face (no world triplanar dependency in the exported mesh).
    u=math.dist(pts[0],pts[1])/scale; v=math.dist(pts[1],pts[2])/scale
    tri(mat,*pts[:3],((0,v),(u,v),(u,0)))
    tri(mat,pts[0],pts[2],pts[3],((0,v),(u,0),(0,0)))

def transform(p, origin=(0,0,0), yaw=0):
    x,y,z=p; co=math.cos(yaw); si=math.sin(yaw)
    return (origin[0]+co*x+si*z, origin[1]+y, origin[2]-si*x+co*z)

def box(mat,center,size,yaw=0):
    x,y,z=(v/2 for v in size)
    pts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    pts=[transform(v,center,yaw) for v in pts]
    for face in [(4,5,6,7),(1,0,3,2),(0,4,7,3),(5,1,2,6),(7,6,2,3),(0,1,5,4)]:
        quad(mat,[pts[i] for i in face])

def cylinder(mat,x,y,z,r,h,sides=12):
    for i in range(sides):
        a=i*math.tau/sides; b=(i+1)*math.tau/sides
        p=(x+r*math.cos(a),y-h/2,z+r*math.sin(a))
        q=(x+r*math.cos(b),y-h/2,z+r*math.sin(b))
        u=(q[0],y+h/2,q[2]); v=(p[0],y+h/2,p[2])
        quad(mat,[q,p,v,u])
        tri(mat,(x,y+h/2,z),u,v)

def arch_points(w,h):
    spring=h-w*.8660254
    left=[(-w/2,0),(-w/2,spring)]
    for j in range(1,9):
        a=math.pi-j*(math.pi/3)/8
        left.append((w/2+w*math.cos(a),spring+w*math.sin(a)))
    return left+[(-x,y) for x,y in reversed(left[:-1])]

def polygon(mat,points,origin,yaw=0):
    # Outline runs clockwise when seen from +Z; reverse to face front.
    pts=[transform((x,y,0),origin,yaw) for x,y in reversed(points)]
    center=tuple(sum(p[k] for p in pts)/len(pts) for k in range(3))
    for i in range(len(pts)): tri(mat,center,pts[i],pts[(i+1)%len(pts)])

def window(x,base,z,w,h,yaw=0,door=False):
    origin=(x,base,z)
    outer=arch_points(w+.36,h+.27); inner=arch_points(w,h)
    # Equal vertex counts form a proper raised ring, not a texture-painted arch.
    for i in range(len(outer)-1):
        o1,o2=outer[i],outer[i+1]; i1,i2=inner[i],inner[i+1]
        pts=[(o1[0],o1[1]-.10,.12),(i1[0],i1[1],.12),(i2[0],i2[1],.12),(o2[0],o2[1]-.10,.12)]
        quad(1,[transform(v,origin,yaw) for v in pts])
        side=[(o1[0],o1[1]-.10,0),(o1[0],o1[1]-.10,.12),(o2[0],o2[1]-.10,.12),(o2[0],o2[1]-.10,0)]
        quad(1,[transform(v,origin,yaw) for v in side])
    polygon(5,arch_points(w+.05,h+.04),transform((0,0,.01),origin,yaw),yaw)
    polygon(3 if door else 6,arch_points(w*.84,h*.93),transform((0,.025,.025),origin,yaw),yaw)
    def piece(mat,at,size): box(mat,transform(at,origin,yaw),size,yaw)
    if door:
        for yy in [.45,1.15]: piece(4,(0,yy,.065),(w*.80,.065,.04))
        piece(4,(.28,1,.085),(.09,.12,.08))
    else:
        piece(4,(0,h*.40,.075),(.055,h*.8,.055))
        piece(4,(0,h*.43,.075),(w*.85,.05,.055))
        piece(1,(0,-.06,.16),(w+.55,.14,.38))

# Main mass, foundation and layered cornices.
box(0,(0,2.65,0),(5.4,5.3,6.4))
for yy,ww,dd,hh in [(.16,5.85,6.85,.32),(.42,5.65,6.65,.16),(2.65,5.65,6.65,.16),(2.79,5.8,6.8,.10),(5.15,5.65,6.65,.16),(5.32,5.9,6.9,.14)]:
    box(1,(0,yy,0),(ww,hh,dd))
# Buttresses and stepped capitals around the facade and rear.
for xx in [-2.65,2.65]:
    for zz in [-3.14,3.14]:
        box(1,(xx,2.6,zz),(.38,5.15,.44))
        for yy in [.38,2.72,5.24]: box(1,(xx,yy,zz),(.56,.20,.6))
        box(1,(xx,5.58,zz),(.34,.55,.4))
        # Small pyramidal coping, readable silhouette without micro ornaments.
        y=5.87; r=.26
        v=[(xx-r,y,zz-r),(xx+r,y,zz-r),(xx+r,y,zz+r),(xx-r,y,zz+r)]
        for i in range(4): tri(1,v[i],(xx,y+.43,zz),v[(i+1)%4])
# Front and rear triangular masonry gables.
for zz,yaw in [(3.22,0),(-3.22,math.pi)]:
    polygon(0,[(-2.7,5.3),(0,7.65),(2.7,5.3)],(0,0,zz),yaw)
# Two proper roof slopes with explicit UVs, ridge and roof edging.
quad(2,[(-3.02,5.4,3.55),(0,7.9,3.55),(0,7.9,-3.55),(-3.02,5.4,-3.55)],2.5)
quad(2,[(0,7.9,3.55),(3.02,5.4,3.55),(3.02,5.4,-3.55),(0,7.9,-3.55)],2.5)
box(4,(0,7.92,0),(.12,.13,7.3))
for zz in [-3.56,3.56]:
    for side in [-1,1]:
        # Narrow sloped gable bar assembled as a rotated box around Z.
        a=(side*3.03,5.4,zz); b=(0,7.92,zz)
        direction=sub(b,a); length=math.sqrt(sum(v*v for v in direction))
        midpoint=tuple((a[i]+b[i])/2 for i in range(3))
        # A prism defined by four corners on each side of the slope.
        nx=-direction[1]/length*.07; ny=direction[0]/length*.07
        pts=[(a[0]+nx,a[1]+ny,zz+.08),(b[0]+nx,b[1]+ny,zz+.08),(b[0]-nx,b[1]-ny,zz+.08),(a[0]-nx,a[1]-ny,zz+.08)]
        quad(1,pts)
# Chimney, pot caps, projecting bay and balcony ironwork.
box(0,(1.7,6.4,-1.5),(.68,3.0,.8))
box(1,(1.7,7.92,-1.5),(.88,.16,1))
for zz in [-1.72,-1.28]: cylinder(4,1.7,8.14,zz,.16,.35)
window(0,.35,3.24,1.2,2.15,door=True)
for xx in [-1.65,1.65]:
    window(xx,.95,3.24,.80,1.35)
    window(xx,3.18,3.24,.95,1.65)
window(0,5.55,3.25,.6,1.12)
for xx in [-1.5,1.5]:
    window(xx,3.2,-3.24,.8,1.5,math.pi)
    window(xx,.95,-3.24,.7,1.3,math.pi)
# Side windows, including faces likely to be seen from above.
for side in [-1,1]:
    yaw=side*math.pi/2
    for zz in [-1.8,1.5]:
        window(side*2.73,3.2,zz,.9,1.6,yaw)
        window(side*2.73,.95,zz,.8,1.3,yaw)
box(1,(0,.12,3.55),(1.8,.24,.7))
box(1,(0,.065,3.95),(2.1,.13,.45))
# Two front pillars, shallow porch and simple balcony at the string course.
for xx in [-.82,.82]:
    cylinder(1,xx,1.32,3.6,.10,2.35)
    box(1,(xx,2.48,3.6),(.3,.12,.3))
box(1,(0,2.58,3.55),(2.1,.16,.95))
for xx in [-.95,-.63,-.31,0,.31,.63,.95]: box(4,(xx,2.98,4.0),(.045,.7,.045))
box(4,(0,3.34,4.0),(2.05,.055,.065))

# Write a standalone GLB with seven merged surfaces and embedded PNG textures.
blob=bytearray(); views=[]; accessors=[]
def view(data,target=None):
    while len(blob)%4: blob.append(0)
    start=len(blob); blob.extend(data)
    v={'buffer':0,'byteOffset':start,'byteLength':len(data)}
    if target: v['target']=target
    views.append(v); return len(views)-1
def accessor(values,kind,components):
    is_index=kind=='SCALAR'; fmt='I' if is_index else 'f'
    v=view(struct.pack('<'+fmt*len(values),*values),34963 if is_index else 34962)
    a={'bufferView':v,'componentType':5125 if is_index else 5126,'count':len(values)//components,'type':kind}
    if kind=='VEC3':
        a['min']=[min(values[j::3]) for j in range(3)]; a['max']=[max(values[j::3]) for j in range(3)]
    accessors.append(a); return len(accessors)-1
primitives=[]
for mat,data in sorted(surfaces.items()):
    primitives.append({'attributes':{'POSITION':accessor(data['p'],'VEC3',3),'NORMAL':accessor(data['n'],'VEC3',3),'TEXCOORD_0':accessor(data['u'],'VEC2',2)},'indices':accessor(data['i'],'SCALAR',1),'material':mat})
images=[]
for name in ['ashlar','oak','slate']:
    images.append({'bufferView':view((OUT/'textures'/f'{name}_albedo.png').read_bytes()),'mimeType':'image/png','name':name})
doc={'asset':{'version':'2.0','generator':'Terminal Depth original gothic-house builder'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':'GothicHouse','mesh':0}],'meshes':[{'name':'GothicHouseMerged','primitives':primitives}],'materials':materials,'images':images,'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],'textures':[{'source':i,'sampler':0} for i in range(3)],'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':accessors}
js=json.dumps(doc,separators=(',',':')).encode(); js+=b' ' * (-len(js)%4); blob+=b'\0'*(-len(blob)%4)
total=12+8+len(js)+8+len(blob)
(OUT/'gothic_house.glb').write_bytes(struct.pack('<III',0x46546C67,2,total)+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(blob),0x004E4942)+blob)
tris=sum(len(v['i'])//3 for v in surfaces.values())
(OUT/'mesh_stats.json').write_text(json.dumps({'triangles':tris,'surfaces':len(primitives),'size_m':[6.04,8.32,7.55],'footprint_collision_m':[5.6,5.3,6.6],'textures':['ashlar','oak','slate'],'front':'+Z'},indent=2))
print(f'GOTHIC_HOUSE_BUILT: {tris} triangles, {len(primitives)} surfaces, {total} bytes embedded GLB')
