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


def group(name):
    nodes.append(f'[node name="{name}" type="Node3D" parent="."]\n')


def prop(kind, position, yaw=0, size=None, parent='Architecture'):
    if kind not in resources:
        resources[kind] = 'P_' + kind
    counts[kind] += 1
    name = kind.title().replace('_', '') + f'_{counts[kind]:03}'
    x, y, z = position
    text = f'[node name="{name}" parent="{parent}" instance=ExtResource("{resources[kind]}")]\n'
    text += f'position = Vector3({x:.3f}, {y:.3f}, {z:.3f})\nrotation = Vector3(0, {math.radians(yaw):.6f}, 0)\n'
    text += 'solid = false\n'
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


def main():
    for name in ['Shoreline','Cliffs','SeaStacks','Architecture','Dock','Nature','Landmarks','Lanterns']:
        group(name)
    # Получаем точные края уже существующего пола; навигация и коллизия не меняются.
    scene = (ROOT/'scenes/art/riverbank_blockout.tscn').read_text(encoding='utf-8')
    shapes = {m[0]: tuple(map(float,m[1].split(','))) for m in re.findall(
        r'\[sub_resource type="BoxShape3D" id="([^"]+)"\]\nsize = Vector3\(([^)]+)\)',scene)}
    blocks = re.split(r'(?=^\[node )',scene,flags=re.M)
    outline = defaultdict(list)
    for i,block in enumerate(blocks):
        if not block.startswith('[node name="BankEdge') or 'type="StaticBody3D"' not in block:
            continue
        xyz = tuple(map(float,re.search(r'transform = Transform3D\(([^)]+)',block)[1].split(',')))[-3:]
        shape = re.search(r'shape = SubResource\("([^"]+)"\)', ''.join(blocks[i+1:i+3]))
        if not shape:
            continue
        size = shapes[shape[1]]
        if size[0] < 1:
            outline[('z',round(xyz[0]))].append(xyz[2])
        else:
            outline[('x',round(xyz[2]))].append(xyz[0])
    for (axis, fixed), values in sorted(outline.items()):
        values = sorted(set(values))
        runs = []
        for value in values:
            if not runs or value-runs[-1][-1] > 2.1: runs.append([])
            runs[-1].append(value)
        for run in runs:
            for i in range(0,len(run),2):
                part = run[i:i+2]
                center = sum(part)/len(part)
                # Низкая кладка маскирует край, не загромождая силуэтами маршрут.
                at = (center,-1.13,fixed) if axis=='x' else (fixed,-1.13,center)
                prop('bank_edge_4m',at,0 if axis=='x' else 90,
                     (len(part)*2+0.25,1.18,2.3),parent='Shoreline')
    # Крупные скалы располагаются группами за игровым контуром.
    for x,z,yaw in [(-10,10,10),(-9,1,25),(-16,-17,15),(-22,-25,40),(-20,-32,0),
                    (2,-33,20),(10,-35,-10),(34,-43,25),(40,-50,-15),(42,-60,20),
                    (48,-74,10),(34,-79,35),(15,-103,5),(-8,-104,15),(-10,-112,30),
                    (-12,-125,5),(4,-133,-15),(8,-142,15),(2,-151,0),(-30,-150,25)]:
        prop('rock_bank_a',(x,-1.5,z),yaw,(12,2.1,10),parent='Cliffs')
        prop('cliff_face_8m',(x,-0.4,z),yaw,(8,9,5),parent='Cliffs')
    for i,(x,z) in enumerate([(-40,17),(-48,3),(-54,-14),(-59,-34),(-52,-52),(-45,-64),
                              (-28,-61),(-10,-66),(3,-72),(8,-100),(-49,-96),(-53,-116),
                              (-47,-138),(-41,-157),(-18,-164),(-2,-164),(18,-151),(53,-96)]):
        scale = 0.65+(i%4)*0.2
        prop('sea_stack',(x,-1.1,z),i*43,(3*scale,6*scale,3*scale),parent='SeaStacks')
    # Причал у входа и оставленная лодка; глубина ног причала уходит под воду.
    for x in [-25,-29,-34]: prop('pier_section_4m',(x,-1.98,8),0,(5.1,2,5),parent='Dock')
    for x,z in [(-27,6),(-27,10),(-36,6),(-36,10)]:
        prop('mooring_post',(x,-0.1,z),parent='Dock')
    prop('boat',(-34,-0.8,13),85,parent='Dock')
    prop('boat',(-50,-0.78,-53),-15,parent='Dock')
    # Мост поверх прежнего ровного пути. Коллизия пола остаётся общей.
    prop('bridge_span',(-8,-2.98,-90),0,(16,3,8.8),parent='Landmarks')
    for x in [-14.5,-1.5]:
        for z in [-94.5,-85.5]:
            prop('hooded_statue',(x,2.2,z),0,(0.9,2.3,0.9),parent='Landmarks')
    # Два небольших корпуса обрамляют существующую арку. Центральный проход открыт.
    for x in [-18,-2]:
        for z in [-140.8,-148.5]:
            prop('window_wall_4m',(x,0,z),0,(5,4,0.8))
            prop('gable_end_4m',(x,4,z),0,(5,2.4,0.8))
        for sx in [x-2.5,x+2.5]:
            for z in [-142.8,-146.6]:
                prop('window_wall_4m',(sx,0,z),90,(4,4,0.8))
        prop('roof_segment_4m' if x < -10 else 'roof_segment_4m_variant_b',
             (x,4,-144.65),0,(5.5,2.6,8.6))
        for sx in [x-2.5,x+2.5]:
            prop('buttress_4m',(sx,0,-140.2),0,(1.2,4.5,1.8))
        prop('bank_edge_4m',(x,-1.1,-144.5),0,(6.5,1.2,10))
        lamp(x,2.1,-140.1)
    prop('gate_leaf',(-13.4,0,-143.6),-70,(3.0,5.5,0.25))
    prop('gate_leaf_variant_b',(-6.6,0,-143.6),70,(3.0,5.5,0.25))
    for x in [-15.2,-4.8]:
        prop('hooded_statue',(x,0,-137),0,parent='Landmarks')
        lamp(x,2.2,-140.3)
    # Повторяемые ориентиры и небольшие группы декора за границами боевых площадок.
    for x,z,yaw in [(-14,1,15),(-24,-40,-20),(35,-68,90),(-16,-116,25)]:
        prop('cargo_wagon',(x,0,z),yaw,parent='Landmarks')
    for i,(x,z) in enumerate([(-12,10),(-23,-14),(-47,-32),(-14,-34),(10,-34),(34,-46),
                              (39,-72),(11,-79),(-20,-77),(-44,-106),(-16,-123),(-27,-135),
                              (-1,-132),(1,-145)]):
        prop('rock_bank_a',(x,-1.1,z),i*67,(6.5,1.2,5.5),parent='Nature')
        prop('dead_tree_hero',(x,0,z),i*67,parent='Nature')
        prop('roots_ground',(x-0.7,-0.03,z+0.5),i*67,parent='Nature')
    for i,(x,z) in enumerate([(-28,17),(-47,-12),(-22,-35),(10,-51),(39,-52),(-40,-130)]):
        prop('rock_bank_a',(x,-1.1,z),i*43,(6,1.15,4),parent='Nature')
        prop('fallen_log',(x,-0.05,z),i*43,parent='Nature')
    for x,z in [(-23,-29),(36,-77),(-16,-121)]: lamp(x,1.6,z,90)
    header = '[gd_scene format=3]\n\n'
    for kind,key in resources.items():
        header += f'[ext_resource type="PackedScene" path="{MODULE+kind}.tscn" id="{key}"]\n'
    header += '\n[node name="RiverbankDressing" type="Node3D"]\n\n'
    OUT.write_text(header+'\n'.join(nodes),encoding='utf-8')
    print('Dressing instances:',sum(counts.values()),dict(counts))


if __name__ == '__main__': main()
