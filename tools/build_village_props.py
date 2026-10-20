"""Original reusable wall, round gate, wicker basket, crate and carriage meshes."""
from mesh_asset_builder import *
OUT=Path('assets/buildings/village_props')
OUT.mkdir(parents=True,exist_ok=True)
textures=['../../textures/victorian_village/stylized_v2/brick_albedo.png','../gothic_house/textures/ashlar_albedo.png','../gothic_house/textures/oak_albedo.png','textures/wicker_albedo.png']
def mat(name,color,texture=None,metal=0):
    p={'baseColorFactor':color+[1],'roughnessFactor':.85,'metallicFactor':metal}
    if texture is not None: p['baseColorTexture']={'index':texture}
    return {'name':name,'pbrMetallicRoughness':p}
mats=[mat('Painted brick',[.78,.8,.8],0),mat('Stone coping',[.65,.66,.64],1),mat('Painted oak',[.65,.65,.62],2),mat('Woven wicker',[.8,.75,.64],3),mat('Black iron',[.035,.045,.05],metal=.55),mat('Dark interior',[.035,.027,.02]),mat('Burgundy coach panels',[.13,.035,.028]),mat('Dusty dark glass',[.045,.075,.085],metal=.15)]
mats[2]['doubleSided']=True  # thin wheel spokes remain visible from either side
mats[3]['doubleSided']=True  # basket weave has a visible inside
stats={}
def save(name):
    stats[name]=export_glb(OUT/f'{name}.glb',mats,textures)
    surfaces.clear()

# 2m long, 2.8m high wall panel; the end pilaster joins seamlessly with its neighbor.
box(0,(0,1.25,0),(2,2.5,.5))
box(1,(0,.12,0),(2,.24,.7))
box(1,(0,2.55,0),(2,.16,.7))
box(0,(-.85,1.4,0),(.3,2.8,.72))
box(1,(-.85,2.85,0),(.48,.14,.88))
save('wall_straight')

# Rounded true open arch: 4.2m clear opening, 12m overall width.
radius=2.1; spring=2.6; outer=2.65
for side in [-1,1]:
    box(0,(side*4.325,2.0,0),(3.35,4.0,.75))
    box(1,(side*2.42,1.3,0),(.64,2.6,1))
    box(1,(side*4.4,4.08,0),(3.2,.16,1))
for i in range(20):
    a=i*math.pi/20+.006; b=(i+1)*math.pi/20-.006
    poly=[(radius*math.cos(a),spring+radius*math.sin(a)),(outer*math.cos(a),spring+outer*math.sin(a)),(outer*math.cos(b),spring+outer*math.sin(b)),(radius*math.cos(b),spring+radius*math.sin(b))]
    for z in [-.48,.48]:
        points=[(x,y,z) for x,y in poly]
        if z<0: points.reverse()
        quad(1,points)
    for j in range(4):
        p,q=poly[j],poly[(j+1)%4]
        quad(1,[(p[0],p[1],-.48),(q[0],q[1],-.48),(q[0],q[1],.48),(p[0],p[1],.48)])
box(1,(0,5.3,0),(.45,.45,1.1))
save('gate_round')

# Hollow tapered basket: inner wall, base and thick rim, not a solid cylinder.
def ring_y(mat,y,outer,inner,n=16):
    for i in range(n):
        a=i*math.tau/n; b=(i+1)*math.tau/n
        quad(mat,[(outer*math.cos(a),y,outer*math.sin(a)),(inner*math.cos(a),y,inner*math.sin(a)),(inner*math.cos(b),y,inner*math.sin(b)),(outer*math.cos(b),y,outer*math.sin(b))],.8)
for i in range(16):
    a=i*math.tau/16; b=(i+1)*math.tau/16
    quad(3,[(.32*math.cos(b),0,.32*math.sin(b)),(.32*math.cos(a),0,.32*math.sin(a)),(.48*math.cos(a),.72,.48*math.sin(a)),(.48*math.cos(b),.72,.48*math.sin(b))],.8)
    quad(3,[(.43*math.cos(a),.72,.43*math.sin(a)),(.30*math.cos(a),.08,.30*math.sin(a)),(.30*math.cos(b),.08,.30*math.sin(b)),(.43*math.cos(b),.72,.43*math.sin(b))],.8)
    tri(5,(0,.08,0),(.30*math.cos(b),.08,.30*math.sin(b)),(.30*math.cos(a),.08,.30*math.sin(a)))
ring_y(3,.74,.49,.42)
save('basket')

box(2,(0,.45,0),(.9,.9,.85))
for y in [.1,.8]:
    for z in [-.46,.46]: box(2,(0,y,z),(1,.12,.09))
for x in [-.42,.42]:
    for z in [-.46,.46]: box(2,(x,.45,z),(.11,.9,.1))
save('crate')

# Victorian enclosed coach, real spoked wheels, panels, bench and front shafts.
box(4,(0,.78,0),(1.65,.18,3.25))
box(6,(0,1.55,.15),(1.5,1.35,1.95))
box(2,(0,2.28,.15),(1.7,.18,2.17))
box(4,(0,2.41,.15),(1.5,.10,1.95))
for side in [-1,1]:
    box(7,(side*.76,1.86,.3),(.035,.65,.8))
    for z in [-.15,.75]: box(2,(side*.8,1.85,z),(.08,.75,.07))
    for yy in [1.48,2.22]: box(2,(side*.8,yy,.3),(.08,.07,1.0))
    box(2,(side*.8,1.2,.3),(.06,.08,1.7))
    box(4,(side*.91,.65,.3),(.25,.10,1.0))
box(2,(0,1.25,-1.15),(1.5,.15,.55))
box(6,(0,1.53,-1.45),(1.45,.5,.12))
for side in [-1,1]: box(2,(side*.5,.78,-2.2),(.10,.12,2.6))
def wheel(cx,cy,cz,r):
    n=20
    for i in range(n):
        a=i*math.tau/n; b=(i+1)*math.tau/n
        # Ring in YZ plane, axle along X.
        for xx in [cx-.07,cx+.07]:
            pts=[(xx,cy+r*math.cos(a),cz+r*math.sin(a)),(xx,cy+(r-.11)*math.cos(a),cz+(r-.11)*math.sin(a)),(xx,cy+(r-.11)*math.cos(b),cz+(r-.11)*math.sin(b)),(xx,cy+r*math.cos(b),cz+r*math.sin(b))]
            if xx<cx: pts.reverse()
            quad(2,pts)
        quad(4,[(cx-.08,cy+r*math.cos(a),cz+r*math.sin(a)),(cx+.08,cy+r*math.cos(a),cz+r*math.sin(a)),(cx+.08,cy+r*math.cos(b),cz+r*math.sin(b)),(cx-.08,cy+r*math.cos(b),cz+r*math.sin(b))])
    for i in range(10):
        a=i*math.tau/10
        # Actual spoke prisms.
        uy,uz=math.cos(a),math.sin(a); vy,vz=-uz*.035,uy*.035
        p=(cy,cz); q=(cy+(r-.1)*uy,cz+(r-.1)*uz)
        quad(2,[(cx+.04,p[0]+vy,p[1]+vz),(cx+.04,q[0]+vy,q[1]+vz),(cx+.04,q[0]-vy,q[1]-vz),(cx+.04,p[0]-vy,p[1]-vz)])
    box(4,(cx,cy,cz),(.24,.19,.19))
for side in [-1,1]:
    wheel(side*.99,.62,-1.15,.6)
    wheel(side*.99,.72,1.22,.7)
save('carriage')
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2))
