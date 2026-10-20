"""Gothic lantern, two trees, barrel, bench and planter; original low-poly UV meshes."""
from mesh_asset_builder import *
import random
OUT=Path('assets/buildings/village_nature'); OUT.mkdir(parents=True,exist_ok=True)
textures=['textures/bark_albedo.png','textures/iron_albedo.png','../gothic_house/textures/oak_albedo.png','../gothic_house/textures/ashlar_albedo.png','textures/red_leaves.png']
def mat(name,color,tex=None,metal=0):
    p={'baseColorFactor':color+[1],'roughnessFactor':.85,'metallicFactor':metal}
    if tex is not None: p['baseColorTexture']={'index':tex}
    return {'name':name,'pbrMetallicRoughness':p}
mats=[mat('Painted bark',[.8,.82,.77],0),mat('Aged cast iron',[.65,.69,.72],1,.55),mat('Painted oak',[.7,.7,.65],2),mat('Carved stone',[.58,.60,.58],3),mat('Lantern glass',[.28,.14,.045]),mat('Red foliage',[.8,.72,.64],4)]
mats[4]['emissiveFactor']=[.8,.3,.055]
mats[5].update({'doubleSided':True,'alphaMode':'MASK','alphaCutoff':.5})
stats={}
def save(name):
    stats[name]=export_glb(OUT/f'{name}.glb',mats,textures); surfaces.clear()
def segment(mat,a,b,r1,r2,n=8):
    axis=sub(b,a); length=math.sqrt(sum(x*x for x in axis)); axis=tuple(x/length for x in axis)
    helper=(1,0,0) if abs(axis[0])<.8 else (0,0,1)
    u=cross(axis,helper); ul=math.sqrt(sum(x*x for x in u)); u=tuple(x/ul for x in u)
    v=cross(axis,u)
    def point(at,r,t): return tuple(at[k]+r*(u[k]*math.cos(t)+v[k]*math.sin(t)) for k in range(3))
    for i in range(n):
        t=i*math.tau/n; q=(i+1)*math.tau/n
        p0=point(a,r1,t); p1=point(a,r1,q); p2=point(b,r2,q); p3=point(b,r2,t)
        uv=[(i/n,0),((i+1)/n,0),((i+1)/n,length/2),(i/n,length/2)]
        tri(mat,p0,p1,p2,[uv[0],uv[1],uv[2]])
        tri(mat,p0,p2,p3,[uv[0],uv[2],uv[3]])
        tri(mat,b,p3,p2)

# Broad Gothic silhouette: stepped octagonal base, fluted pole, framed six-sided lantern.
cylinder(3,0,.10,0,.34,.20,8)
cylinder(1,0,.30,0,.23,.30,8)
segment(1,(0,.45,0),(0,2.86,0),.11,.065,12)
for y,r in [(.55,.16),(1.1,.125),(2.55,.14),(2.86,.19)]: cylinder(1,0,y,0,r,.10,12)
cylinder(1,0,2.98,0,.28,.12,6)
cylinder(4,0,3.29,0,.225,.55,6)
for i in range(6):
    a=i*math.tau/6
    segment(1,(.245*math.cos(a),3.0,.245*math.sin(a)),(.245*math.cos(a),3.59,.245*math.sin(a)),.025,.025,6)
cylinder(1,0,3.59,0,.30,.12,6)
for i in range(6):
    a=i*math.tau/6; b=(i+1)*math.tau/6
    tri(1,(.39*math.cos(b),3.65,.39*math.sin(b)),(.39*math.cos(a),3.65,.39*math.sin(a)),(0,3.98,0))
segment(1,(0,3.94,0),(0,4.17,0),.07,0,8)
for side in [-1,1]:
    pts=[(0,2.5,0),(side*.24,2.62,0),(side*.33,2.82,0),(side*.26,2.95,0)]
    for a,b in zip(pts,pts[1:]): segment(1,a,b,.035,.03,6)
save('gothic_lantern')

def tree(seed,leaves=False):
    rng=random.Random(seed)
    trunk=[(0,0,0),(.12,1.2,-.08),(-.08,2.35,.05),(.16,3.5,.12),(.45,4.5,.05)]
    for j,(a,b) in enumerate(zip(trunk,trunk[1:])): segment(0,a,b,.30-j*.06,.24-j*.06,9)
    for i in range(5):
        a=i*math.tau/5
        segment(0,(math.cos(a)*.8,.03,math.sin(a)*.7),(0,.6,0),.12,.20,7)
    tips=[]
    for i in range(9):
        a=i*2.39; y=1.5+i*.27; reach=rng.uniform(1.1,1.9)
        start=(0,y,0); mid=(math.cos(a)*reach*.65,y+.55,math.sin(a)*reach*.65)
        end=(math.cos(a)*reach,y+1.45,math.sin(a)*reach)
        segment(0,start,mid,.13,.075,7); segment(0,mid,end,.075,.018,6)
        fork=(end[0]+math.cos(a+1)*.6,end[1]+.35,end[2]+math.sin(a+1)*.6)
        segment(0,mid,fork,.045,.005,5)
        tips.extend((end,fork))
    if leaves:
        for i,t in enumerate(tips):
            # Crossed textured cards: explicit alpha cutout, coherent scale, no spherical blobs.
            for yaw in [i*.8,i*.8+math.pi/2]:
                local=[(-.65,-.3,0),(.65,-.3,0),(.65,.7,0),(-.65,.7,0)]
                pts=[transform(v,t,yaw) for v in local]
                tri(5,pts[0],pts[1],pts[2],[(0,1),(1,1),(1,0)])
                tri(5,pts[0],pts[2],pts[3],[(0,1),(1,0),(0,0)])
tree(18); save('tree_bare')
tree(31,True); save('tree_red')

# Bulging faceted oak barrel, real iron hoops and top lid.
ys=[0,.15,.55,.95,1.1]; rs=[.36,.41,.46,.41,.36]
for j in range(4):
    for i in range(16):
        a=i*math.tau/16; b=(i+1)*math.tau/16
        quad(2,[(rs[j]*math.cos(b),ys[j],rs[j]*math.sin(b)),(rs[j]*math.cos(a),ys[j],rs[j]*math.sin(a)),(rs[j+1]*math.cos(a),ys[j+1],rs[j+1]*math.sin(a)),(rs[j+1]*math.cos(b),ys[j+1],rs[j+1]*math.sin(b))],1.5)
for y,r in [(.15,.425),(.55,.475),(.95,.425)]: cylinder(1,0,y,0,r,.065,16)
cylinder(2,0,1.08,0,.36,.04,16)
save('barrel')

for z in [-.25,0,.25]: box(2,(0,.55,z),(2.2,.10,.20))
for y in [.9,1.14]: box(2,(0,y,-.36),(2.2,.18,.10))
for x in [-.85,.85]:
    box(1,(x,.28,0),(.10,.55,.65)); box(1,(x,.9,-.35),(.08,.85,.09))
    segment(1,(x,.6,.3),(x,.9,.22),.035,.035,6)
save('bench')

box(3,(0,.10,0),(1.8,.2,1.8))
for x in [-.79,.79]: box(3,(x,.42,0),(.22,.65,1.8))
for z in [-.79,.79]: box(3,(0,.42,z),(1.8,.65,.22))
box(0,(0,.56,0),(1.4,.10,1.4))
save('planter')
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2))
