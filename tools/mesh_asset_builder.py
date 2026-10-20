from pathlib import Path
import math, struct, json
surfaces = {}

def export_glb(path, materials, textures):
    blob=bytearray(); views=[]; accessors=[]
    def view(data,target=None):
        while len(blob)%4: blob.append(0)
        offset=len(blob); blob.extend(data)
        v={'buffer':0,'byteOffset':offset,'byteLength':len(data)}
        if target: v['target']=target
        views.append(v); return len(views)-1
    def acc(values,kind,n):
        ind=kind=='SCALAR'; fmt='I' if ind else 'f'
        v=view(struct.pack('<'+fmt*len(values),*values),34963 if ind else 34962)
        a={'bufferView':v,'componentType':5125 if ind else 5126,'count':len(values)//n,'type':kind}
        if kind=='VEC3':
            a['min']=[min(values[j::3]) for j in range(3)]; a['max']=[max(values[j::3]) for j in range(3)]
        accessors.append(a); return len(accessors)-1
    primitives=[]
    for mat,d in sorted(surfaces.items()):
        primitives.append({'attributes':{'POSITION':acc(d['p'],'VEC3',3),'NORMAL':acc(d['n'],'VEC3',3),'TEXCOORD_0':acc(d['u'],'VEC2',2)},'indices':acc(d['i'],'SCALAR',1),'material':mat})
    doc={'asset':{'version':'2.0','generator':'Terminal Depth mesh builder'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':path.stem,'mesh':0}],'meshes':[{'primitives':primitives}],'materials':materials,'images':[{'uri':t} for t in textures],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],'textures':[{'source':i,'sampler':0} for i in range(len(textures))],'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':accessors}
    js=json.dumps(doc,separators=(',',':')).encode(); js+=b' '*(-len(js)%4); blob+=b'\0'*(-len(blob)%4)
    total=12+8+len(js)+8+len(blob)
    path.write_bytes(struct.pack('<III',0x46546c67,2,total)+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob)
    stats={'triangles':sum(len(s['i'])//3 for s in surfaces.values()),'surfaces':len(primitives)}
    print(path.name, stats)
    return stats

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

