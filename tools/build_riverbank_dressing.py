"""Собирает только авторскую отделку riverbank_dressing.tscn. Ручную базу уровня не пересоздаёт."""
from pathlib import Path
import math
import re
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'scenes/art/riverbank_dressing.tscn'
MODULE = 'res://assets/environment/riverbank/modules/'
resources = {}
nodes = []
counts = defaultdict(int)
import json
SIZES = {a['module']:a['target_size'] for a in json.loads((ROOT/'assets/environment/riverbank/tripo/v2/asset_report.json').read_text(encoding='utf-8'))['assets']}
SIZES.update(rock_bank_a=[4,3,3],rock_small_b=[2,1.5,2],wall_straight_4m=[4,1.4,0.65],wall_broken_4m=[4,1.4,0.65],pillar_corner=[1,2.2,1],barrel=[.9,1.25,.9])


def group(name):
    nodes.append(f'[node name="{name}" type="Node3D" parent="."]\n')


def prop(kind, position, yaw=0, size=None, parent='Architecture', solid=False):
    if kind not in resources:
        resources[kind] = 'P_' + kind
    counts[kind] += 1
    name = kind.title().replace('_', '') + f'_{counts[kind]:03}'
    x, y, z = position
    text = f'[node name="{name}" parent="{parent}" instance=ExtResource("{resources[kind]}")]\n'
    text += f'position = Vector3({x:.3f}, {y:.3f}, {z:.3f})\nrotation = Vector3(0, {math.radians(yaw):.6f}, 0)\n'
    text += 'solid = ' + str(solid).lower() + '\n'
    if solid:
        actual = size or SIZES[kind]
        collider = (actual[0]*0.78, max(1.6,actual[1]*0.8), actual[2]*0.78)
        text += 'collider_size = Vector3(%s)\n' % ', '.join(str(v) for v in collider)
        text += 'collider_center = Vector3(0, %s, 0)\n' % (collider[1]/2)
    if size:
        text += 'target_size = Vector3(%s)\n' % ', '.join(str(v) for v in size)
    nodes.append(text)


def lamp(x, y, z, yaw=0):
    prop('wall_lantern', (x,y,z), yaw, parent='Lanterns')
    nodes.append(f'''[node name="Glow_{counts['wall_lantern']:03}" type="OmniLight3D" parent="Lanterns"]
position = Vector3({x}, {y+0.6}, {z+0.4})
light_color = Color(1, 0.59, 0.23, 1)
light_energy = 2.2
omni_range = 5.5
omni_attenuation = 1.6
''')


def coast(z):
    return -66+math.sin(z*0.047)*8+math.sin(z*0.11)*2.5


def building(x,z,variant=False,ruined=False):
    # Компактный готовый ансамбль; вход в декоративный корпус не предусмотрен.
    for depth in [-3.6,3.6]:
        prop('window_wall_4m',(x,0,z+depth),0,(5,4,0.8),solid=True)
        if not ruined: prop('gable_end_4m',(x,4,z+depth),0,(5,2.4,0.8))
    for sx in [x-2.5,x+2.5]:
        for depth in [-1.8,1.8]: prop('window_wall_4m',(sx,0,z+depth),90,(3.8,4,0.8),solid=True)
    if not ruined:
        prop('roof_segment_4m_variant_b' if variant else 'roof_segment_4m',(x,4,z),0,(5.4,2.6,8.2))
    for sx in [x-2.5,x+2.5]: prop('buttress_4m',(sx,0,z+4),0,(1.2,4.5,1.8),solid=True)
    lamp(x,2,z+4.1)


def court(x,z,variant):
    # Разные дворы: стены с разрывами, ориентир и небольшие группы грузов.
    for i in [-2,-1,1,2]:
        prop('wall_broken_4m' if (i+variant)%2 else 'wall_straight_4m',(x+i*4,0,z-5),0,solid=True)
    for dx in [-10,10]:
        prop('pillar_corner',(x+dx,0,z-5),solid=True)
    if variant%2:
        prop('hooded_statue',(x-7,0,z),solid=True)
        prop('cargo_wagon',(x+7,0,z+1),30,solid=True)
    else:
        prop('dead_tree_hero',(x+7,0,z),variant*37,solid=True)
        prop('roots_ground',(x+6,-0.04,z+1),variant*37)
        prop('fallen_log',(x-7,0,z+1),20,solid=True)
    lamp(x-10,1.4,z-4.8)


def main():
    for name in ['Shoreline','Cliffs','SeaStacks','Architecture','Dock','Nature','Landmarks','Lanterns']:
        group(name)
    # Один непрерывный естественный берег вместо двух сторон узкой дорожки.
    for i,z in enumerate(range(-176,45,4)):
        x=coast(z)
        slope=(coast(z+0.5)-coast(z-0.5))
        yaw=90+math.degrees(math.atan(slope))
        prop('bank_edge_4m',(x-0.6,-1.1,z),yaw,(4.5,1.2,3.0),parent='Shoreline')
        if i%3==0: prop('rock_bank_a',(x-1.7,-1.1,z),i*53,(5,2.2,4.0),parent='Shoreline')
    for i,z in enumerate(range(-168,41,14)):
        x=coast(z)-12-(i%3)*4
        prop('sea_stack',(x,-1.0,z),i*47,(3.2,5+(i%3),3.2),parent='SeaStacks')
    # Непрерывная глубина по краю карты, а не одиночные островки декора.
    for i,z in enumerate(range(-168,41,13)):
        for x in [58,69]:
            prop('cliff_face_8m',(x,-0.25,z+(i%2)*4),i*29,(9,7+i%3,6),parent='Cliffs',solid=True)
            if x==58:
                prop('dead_tree_hero',(x-4,0,z+4),i*71,(4,6,4),parent='Nature',solid=True)
    # Финальный ансамбль сохраняет одобренную композицию.
    building(-18,-144.5)
    building(-2,-144.5,True)
    for x in [-15.2,-4.8]: prop('hooded_statue',(x,0,-137),parent='Landmarks',solid=True)
    prop('gate_leaf',(-13.4,0,-143.6),-70,(3,5.5,0.25))
    prop('gate_leaf_variant_b',(-6.6,0,-143.6),70,(3,5.5,0.25))
    # Четыре различимых части уровня: гавань, дворы, руины и роща.
    for i,(x,z,ruin) in enumerate([(-5,23,False),(27,15,False),(43,-13,True),
                (-20,-21,True),(43,-48,False),(-8,-62,True),(-51,-72,False),
                (33,-94,True),(-9,-106,False),(-48,-129,True),(35,-145,False)]):
        building(x,z,i%2==1,ruin)
    for i,(x,z) in enumerate([(-17,3),(23,-19),(-43,-47),(19,-43),(-24,-76),
                              (31,-104),(-45,-99),(14,-123),(29,-164),(-41,-158)]):
        court(x,z,i)
    # Причал соединён с широкой набережной; сами помосты остаются за береговой границей.
    for z in [12,-62]:
        x=coast(z)
        for dx in [-2,-6,-10]: prop('pier_section_4m',(x+dx,-1.98,z),0,(4.2,2,5),parent='Dock')
        for dx in [-1,-11]:
            for dz in [-2,2]: prop('mooring_post',(x+dx,-0.05,z+dz),parent='Dock')
        prop('boat',(x-9,-0.8,z+6),80,parent='Dock')
        prop('cargo_wagon',(x+7,0,z+6),15,parent='Dock',solid=True)
        lamp(x+1,1.3,z)
    # Крупные группы камней и растительности разбивают длинные пустые виды.
    for i,(x,z) in enumerate([(-45,30),(12,33),(46,31),(-53,4),(11,1),
             (-43,-7),(6,-25),(45,-34),(-55,-40),(-13,-47),(5,-82),
             (-42,-86),(48,-79),(-15,-94),(15,-107),(-53,-113),
             (42,-120),(14,-145),(-30,-154),(48,-164)]):
        prop('cliff_face_8m',(x,0,z),i*39,(6,4.5+(i%3),4),parent='Cliffs',solid=True)
        prop('rock_small_b',(x-2,0,z+2),i*67,parent='Nature',solid=True)
        prop('dead_tree_hero',(x+3,0,z-1),i*71,(4.2,6.2,3.8),parent='Nature',solid=True)
        prop('roots_ground',(x+2,-0.04,z),i*71,parent='Nature')
        if i%2==0: prop('fallen_log',(x-4,0,z+3),i*13,parent='Nature',solid=True)
    # В каждом боевом районе — своя рамка из ориентиров и небольшого реквизита.
    for i,(x,z) in enumerate([(-20,12),(-38,-24),(22,-64),(-30,-114)]):
        prop('dead_tree_hero',(x+10,0,z-3),i*49,(4,6,4),parent='Nature',solid=True)
        prop('roots_ground',(x+9,-.04,z-2),i*49,parent='Nature')
        prop('cargo_wagon',(x-10,0,z+2),30+i*40,parent='Landmarks',solid=True)
        prop('wall_broken_4m',(x+1,0,z-12),0,parent='Landmarks',solid=True)
        prop('hooded_statue',(x-9,0,z-8),i*20,(1.1,2.6,1.1),parent='Landmarks',solid=True)
        prop('wall_broken_4m',(x+8,0,z+7),20,(3,1.1,.8),parent='Landmarks',solid=True)
        for j,(dx,dz) in enumerate([(-8,4),(-9,5.4),(-7,5.8),(8,-7),(9,-8)]):
            prop('barrel' if j%2 else 'rock_small_b',(x+dx,0,z+dz),i*60+j*17,(.9,1.2,.9) if j%2 else (1.2,.7,1.0),parent='Landmarks',solid=True)
        prop('fallen_log',(x-9,0,z+8),20,(3,.7,1),parent='Landmarks',solid=True)
        lamp(x-9,1.3,z-8)
    for i,(x,z) in enumerate([(-7,5),(-24,-32),(36,-72),(-45,-108)]):
        building(x,z,i%2==0,i==1)
    # Мелкие камни соединяют большие группы; все боевые центры остаются свободными.
    packs=[(-38,-24),(22,-64),(-30,-114),(-20,12),(-10,-138)]
    for row,z in enumerate(range(-165,40,11)):
        for col,x in enumerate(range(-53,54,13)):
            px=x+math.sin(row*3.1+col)*2
            pz=z+math.cos(col*1.7+row)*2
            if px<coast(pz)+6 or any(math.hypot(px-cx,pz-cz)<8 for cx,cz in packs): continue
            if (row+col)%3==0:
                prop('rock_small_b',(px,0,pz),(row*113+col*71)%360,(1.5,0.7,1.3),parent='Nature',solid=True)
                prop('roots_ground',(px+1,-0.03,pz+0.5),row*57,(1.7,0.25,1.1),parent='Nature')
    # Сам пролёт уходит в воду как остаток старого моста; открытый берег не пережимается.
    prop('bridge_span',(coast(-94)-6,-2.98,-94),0,(12,3,7),parent='Landmarks')
    header='[gd_scene format=3]\n\n'
    for kind,key in resources.items(): header+=f'[ext_resource type="PackedScene" path="{MODULE+kind}.tscn" id="{key}"]\n'
    header+='\n[node name="RiverbankDressing" type="Node3D"]\n\n'
    OUT.write_text(header+'\n'.join(nodes),encoding='utf-8')
    print('OPEN_DRESSING_OK',sum(counts.values()),dict(counts))


if __name__=='__main__': main()
