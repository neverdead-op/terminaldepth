"""Build the independent, editable architectural trim scene. Never move hub props."""
from pathlib import Path
from gen_facility import Scene, mat, tr, col

ROOT = Path(__file__).resolve().parents[1]
sc = Scene()
bronze = mat(sc, (0.38, 0.26, 0.13), 0.65, 0.4)
dark = mat(sc, (0.12, 0.16, 0.19), 0.45, 0.55)
warm = mat(sc, (0.95, 0.75, 0.43), 0.15, 0.4, ((1.0, 0.67, 0.32), 2.2))
cool = mat(sc, (0.4, 0.8, 0.86), 0.15, 0.4, ((0.3, 0.8, 1.0), 1.8))
sc.node('HubFinishes', 'Node3D', None)

def box(name, pos, size, material):
    mesh = sc.box_mesh(size, material)
    sc.node(name, 'MeshInstance3D', '.', {'transform': tr(pos), 'mesh': f'SubResource("{mesh}")', 'cast_shadow': 0})

# Inlaid brass edges and small cross ties give the walkway a manufactured finish.
for x in (-1.44, 1.44):
    box(f'RunnerEdge{x}', (x, .041, 0), (.035, .014, 9.8), bronze)
for z in (-3.8, -1.8, .2, 2.2, 4.2):
    for x in (-1.3, 1.3):
        box(f'Inlay{x}_{z}', (x, .047, z), (.28, .012, .065), bronze)

# Recessed luminous reliquary panels on the back wall; no new collisions.
for i, x in enumerate((-6.6, -3.5, 3.5, 6.6)):
    box(f'Panel{i}', (x, 1.65, -6.19), (.58, 1.85, .12), dark)
    for dx in (-.3, .3):
        box(f'Frame{i}_{dx}', (x+dx, 1.65, -6.10), (.045, 1.98, .07), bronze)
    for y in (.66, 2.64):
        box(f'Cap{i}_{y}', (x, y, -6.10), (.65, .055, .08), bronze)
    box(f'Lamp{i}', (x, 1.65, -6.09), (.14, 1.48, .055), warm if x < 0 else cool)
    for y in (1.02, 1.65, 2.28):
        box(f'Guard{i}_{y}', (x, y, -6.04), (.35, .055, .07), bronze)
    sc.node(f'WallWash{i}', 'OmniLight3D', '.', {
        'transform': tr((x, 2.1, -5.65)), 'light_color': col((1,.76,.48) if x < 0 else (.48,.8,1)),
        'light_energy': 1.1, 'omni_range': 3.8})

for x in (-8.19, 8.19):
    box(f'WallSkirting{x}', (x,.18,0), (.08,.16,11.8), bronze)
    for z in (-3.6, 0, 3.6):
        box(f'SideHousing{x}_{z}', (x,2.55,z), (.12,.28,1.6), dark)
        box(f'SideLamp{x}_{z}', (x + (.07 if x < 0 else -.07),2.55,z), (.035,.1,1.38), warm if x < 0 else cool)

box('BackCornice', (0,2.92,-6.15), (16.4,.09,.12), bronze)
box('LiftHeader', (0,3.15,-5.92), (2.9,.38,.13), dark)
sc.node('StationName', 'Label3D', '.', {
    'transform': tr((0,3.15,-5.82)), 'text': '"КЕРБЕР–7  /  УБЕЖИЩЕ"',
    'font_size': 42, 'pixel_size': .0017, 'modulate': col((.7,.86,.9)),
    'outline_size': 3, 'no_depth_test': 'false'})
(ROOT / 'scenes/hub_finishes.tscn').write_text(sc.text(), encoding='utf-8')
