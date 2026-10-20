"""Static adult corpse silhouettes and rubble for the ruined town; no AI, XP or loot."""
from mesh_asset_builder import *
OUT=Path('assets/environment/town_ruins'); OUT.mkdir(parents=True,exist_ok=True)
textures=['../../textures/victorian_village/stylized_v2/plaster_albedo.png','../../buildings/gothic_house/textures/ashlar_albedo.png','../../buildings/gothic_house/textures/oak_albedo.png']
def mat(name,color,tex=None):
    p={'baseColorFactor':color+[1],'roughnessFactor':.94,'metallicFactor':0}
    if tex is not None:p['baseColorTexture']={'index':tex}
    return {'name':name,'pbrMetallicRoughness':p}
mats=[mat('Tattered burgundy coat',[.18,.055,.043],0),mat('Cold pale skin',[.25,.22,.18]),mat('Black trousers',[.035,.04,.043]),mat('Rope',[.18,.13,.075]),mat('Rubble stone',[.55,.55,.51],1),mat('Broken timber',[.45,.42,.36],2)]
def limb(mat,a,b,r=.08,n=7):
    axis=sub(b,a); l=math.sqrt(sum(v*v for v in axis)); d=tuple(v/l for v in axis)
    u=cross(d,(1,0,0) if abs(d[0])<.8 else (0,0,1)); ul=math.sqrt(sum(v*v for v in u));u=tuple(v/ul for v in u);v=cross(d,u)
    for i in range(n):
        def p(c,t):return tuple(c[k]+r*(u[k]*math.cos(t)+v[k]*math.sin(t)) for k in range(3))
        t=i*math.tau/n;q=(i+1)*math.tau/n
        quad(mat,[p(a,t),p(a,q),p(b,q),p(b,t)])
        tri(mat,b,p(b,t),p(b,q))
def adult():
    # Adult proportions, coat, hands, boots and a slumped faceless head.
    box(0,(0,1.03,0),(.42,.55,.22))
    box(0,(0,.77,.02),(.46,.28,.26))
    limb(1,(0,1.3,0),(.045,1.43,.06),.07)
    box(1,(.045,1.55,.07),(.20,.24,.21))
    for side in [-1,1]:
        limb(0,(side*.22,1.22,0),(side*.33,.95,.06),.085)
        limb(0,(side*.33,.95,.06),(side*.30,.72,.10),.07)
        box(1,(side*.30,.68,.1),(.10,.14,.09))
        limb(2,(side*.12,.75,0),(side*.14,.37,.02),.09)
        limb(2,(side*.14,.37,.02),(side*.18,.08,.07),.07)
        box(2,(side*.18,.055,.13),(.14,.11,.27))
adult()
export_glb(OUT/'adult_body.glb',mats,textures);surfaces.clear()
adult();limb(3,(0,1.35,-.02),(0,2.65,-.02),.022,6)
export_glb(OUT/'hanging_body.glb',mats,textures);surfaces.clear()
for i in range(11):
    box(4,((i%4-1.5)*.4,.12+(i//4)*.18,(i%3-1)*.35),(.35+(i%2)*.2,.25,.4),i*1.7)
box(5,(0,.3,0),(2.1,.15,.16),.6)
box(5,(0,.45,0),(1.7,.12,.12),-.5)
export_glb(OUT/'rubble.glb',mats,textures)
