"""Combinable 4m floors, 2m walls/fences, static door modules and metric furniture."""
from mesh_asset_builder import *
OUT=Path('assets/environment/victorian_kit/v1')
textures=[
    '../../../buildings/gothic_house/textures/oak_albedo.png',
    'textures/oak_light_albedo.png','textures/painted_blue_albedo.png',
    '../../../textures/victorian_village/stylized_v2/brick_albedo.png',
    'textures/fieldstone_albedo.png','textures/parquet_albedo.png',
    '../../../textures/victorian_garden/stylized_v2/flagstones_red_petals_albedo.png',
    '../../../textures/victorian_village/stylized_v2/plaster_albedo.png',
    '../../../buildings/village_nature/textures/iron_albedo.png',
]
def mat(name,tex=None,color=(.8,.8,.76),metal=0):
    p={'baseColorFactor':list(color)+[1],'metallicFactor':metal,'roughnessFactor':.88-metal*.3}
    if tex is not None:p['baseColorTexture']={'index':tex}
    return {'name':name,'pbrMetallicRoughness':p}
mats=[mat('Dark oak',0),mat('Pale oak',1),mat('Blue painted oak',2),mat('Painted brick',3),mat('Painted fieldstone',4),mat('Parquet',5),mat('Petal flagstones',6),mat('Calm plaster',7),mat('Aged iron',8,(.7,.73,.76),.5),mat('Stone trim',None,(.26,.25,.22)),mat('Muted burgundy cloth',None,(.16,.045,.035))]
for index in [0,1,2,9]: mats[index]['doubleSided']=True
catalog=[]
def save(name,group,label,size):
    stats=export_glb(OUT/f'{name}.glb',mats,textures)
    catalog.append(dict(id=name,group=group,label=label,size=size,**stats))
    surfaces.clear()

def table(wood=0,round_top=False,long=False):
    if round_top:
        cylinder(wood,0,.84,0,.8,.12,20)
        cylinder(wood,0,.43,0,.12,.75,10)
        for a in range(4): box(wood,(0,.08,0),(1.3,.16,.15),a*math.pi/2)
    else:
        w=2.7 if long else 1.8; d=.9 if long else 1.1
        for i in range(5): box(wood,(-w/2+(i+.5)*w/5,.84,0),(w/5-.012,.12,d))
        for x in [-w*.4,w*.4]:
            for z in [-d*.35,d*.35]: box(wood,(x,.42,z),(.12,.78,.12))
        box(wood,(0,.69,0),(w-.1,.15,d-.15))
        if long: box(8,(0,.28,0),(w-.3,.07,.07))
for name,wood,round_top,long,label in [
    ('table_rect_dark',0,False,False,'Стол · тёмный'),('table_rect_light',1,False,False,'Стол · светлый'),
    ('table_round_dark',0,True,False,'Стол · круглый'),('table_round_blue',2,True,False,'Стол · синий'),
    ('table_long',0,False,True,'Стол · длинный')]:
    table(wood,round_top,long); save(name,'furniture',label,[2.7 if long else 1.8,.9,1.6 if round_top else 1.1])

for wood,name in [(0,'dark'),(1,'light'),(2,'blue')]:
    box(wood,(0,.47,0),(.52,.10,.52))
    for x in [-.2,.2]:
        for z in [-.2,.2]:box(wood,(x,.24,z),(.065,.48,.065))
        box(wood,(x,.85,-.22),(.06,.85,.06))
    for y in [.83,1.08]:box(wood,(0,y,-.22),(.5,.12,.055))
    save('chair_'+name,'furniture','Стул · '+name,[.55,1.16,.55])
for wood,name in [(0,'dark'),(1,'light')]:
    cylinder(wood,0,.49,0,.27,.10,12)
    for i in range(3):
        a=i*math.tau/3; box(wood,(math.cos(a)*.17,.24,math.sin(a)*.17),(.07,.48,.07))
    save('stool_'+name,'furniture','Табурет · '+name,[.55,.55,.55])
for wood,name in [(0,'dark'),(2,'blue')]:
    for x in [-.65,.65]:box(wood,(x,.95,0),(.12,1.9,.5))
    for y in [.1,.65,1.2,1.85]:box(wood,(0,y,0),(1.4,.09,.5))
    box(wood,(0,.95,-.24),(1.4,1.8,.05))
    save('shelf_'+name,'furniture','Стеллаж · '+name,[1.45,1.95,.55])

# Door modules are decorative static meshes; hinges/interaction are added by the consuming scene.
def door(wood,arched=False,double=False):
    w=2.2 if double else 1.2; h=2.55
    if arched:
        window(0,0,0,w,h,door=True)  # borrowed geometry uses oak material index 3; remap below
        old=surfaces.pop(3,None)
        if old: surfaces[wood]=old
        iron=surfaces.pop(4,None)
        if iron: surfaces[8]=iron
        stone=surfaces.pop(1,None)
        if stone: surfaces[9]=stone
        surfaces.pop(5,None)  # hidden recess not needed for a standalone module
    else:
        box(wood,(0,h*.5,0),(w,h,.12))
        for x in [-w*.5-.10,w*.5+.10]:box(9,(x,h*.5,0),(.18,h+.2,.30))
        box(9,(0,h+.05,0),(w+.4,.18,.30))
        for y in [.5,1.9]:box(8,(0,y,.09),(w*.9,.065,.05))
        box(8,(w*.3,1.2,.13),(.09,.12,.10))
    if double:box(8,(0,1.0,.13),(.035,2,.035))
for wood,name in [(0,'oak'),(2,'blue')]:
    for arched,shape in [(False,'rect'),(True,'arch')]:
        door(wood,arched); save(f'door_{shape}_{name}','architecture','Дверь · '+shape+' '+name,[1.6,2.8,.4])
door(0,False,True);save('door_double_oak','architecture','Дверь · двойная',[2.6,2.8,.4])
for wood,name in [(0,'oak'),(2,'blue')]:
    for x in [-.35,.35]:
        box(wood,(x,.7,0),(.65,1.4,.10))
        for y in [.2,1.15]:box(8,(x,y,.07),(.55,.05,.04))
    save('shutters_'+name,'architecture','Ставни · '+name,[1.4,1.4,.15])

def wall(material=3,height=2.8,broken=False):
    if broken:
        for i,h in enumerate([2.5,2.2,1.7,1.9]):box(material,(-.75+i*.5,h*.5,0),(.5,h,.5))
    else:
        box(material,(0,height*.5,0),(2,height,.5))
        box(9,(0,height+.05,0),(2.1,.15,.7))
    box(9,(0,.1,0),(2,.2,.65))
for material,name in [(3,'brick'),(4,'stone'),(7,'plaster')]:
    wall(material);save('wall_'+name,'structure','Стена · '+name,[2.1,2.95,.7])
wall(3,broken=True);save('wall_broken','structure','Стена · повреждённая',[2,2.5,.65])
wall(4,1.0);save('wall_low_stone','structure','Стена · низкая',[2.1,1.15,.7])
box(3,(-.75,1.4,0),(.5,2.8,2));box(3,(0,1.4,-.75),(2,2.8,.5))
box(9,(-.75,2.85,0),(.7,.15,2));box(9,(0,2.85,-.75),(2,.15,.7))
save('wall_corner','structure','Стена · угол',[2,2.95,2])
box(4,(0,1.5,0),(.55,3,.55));box(9,(0,3.1,0),(.85,.2,.85));box(9,(0,.1,0),(.8,.2,.8))
save('pillar_square','structure','Столб · квадратный',[.85,3.2,.85])

def fence(wood=0,iron=False,broken=False):
    h=1.8 if iron else 1.4
    for x in [-.95,.95]:box(8 if iron else wood,(x,h*.5,0),(.10,h+.15,.12))
    for y in [.35,1.15]:box(8 if iron else wood,(0,y,0),(2,.08,.10))
    for i in range(9):
        if broken and i in [3,4]:continue
        x=-.8+i*.2
        box(8 if iron else wood,(x,h*.5,0),(.035 if iron else .12,h,.06))
        if iron:
            tri(8,(x-.07,h-.1,.04),(x+.07,h-.1,.04),(x,h+.14,.04))
            tri(8,(x+.07,h-.1,-.04),(x-.07,h-.1,-.04),(x,h+.14,-.04))
for wood,name,iron,broken in [(0,'wood',False,False),(1,'pale',False,False),(2,'blue',False,False),(0,'broken',False,True),(0,'iron',True,False)]:
    fence(wood,iron,broken);save('fence_'+name,'structure','Забор · '+name,[2,2 if iron else 1.55,.15])
# low masonry plus iron railing combination
wall(3,.7)
for i in range(9):box(8,(-.8+i*.2,1.3,0),(.04,1.15,.05))
box(8,(0,1.85,0),(2,.06,.07))
save('fence_brick_iron','structure','Ограда · кирпич/железо',[2.1,1.9,.7])

for index,name,label in [(0,'oak_dark','Пол · тёмные доски'),(1,'oak_light','Пол · светлые доски'),(5,'parquet','Пол · паркет'),(6,'flagstones','Пол · камень с лепестками'),(4,'fieldstone','Пол · грубый камень')]:
    quad(index,[(-2,0,2),(2,0,2),(2,0,-2),(-2,0,-2)],4)
    save('floor_'+name,'floors',label,[4,.05,4])

# Open-front stall with actual supported canopy, no texture-painted furniture.
box(0,(0,.8,0),(2.4,.12,1.2))
for x in [-1.05,1.05]:
    for z in [-.48,.48]:box(0,(x,1.1,z),(.10,2.2,.10))
box(10,(0,2.25,0),(2.65,.12,1.55)); box(0,(0,.4,.5),(2.4,.8,.1))
save('market_stall','furniture','Торговый прилавок',[2.65,2.35,1.55])
(OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
print('KIT_TOTAL',len(catalog),'models')
