"""Растения и святыни для «Садов Эдема» из простых форм (своих моделей растений в паках нет).
Запуск из папки проекта: python -I tools/gen_plants.py .
Пишет assets/plants/<имя>.tscn (сцены с мешами — их умеет размножать model_batch.gd) и габариты
в tools/model_sizes.json (для генератора этажей). Модель стоит на полу, центр основания — в (0, 0, 0).
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def fmt(x):
    return ("%.4f" % x).rstrip("0").rstrip(".") if isinstance(x, float) else str(x)


def col(c, a=1.0):
    return "Color(%s)" % ", ".join(fmt(float(v)) for v in (*c, a))


def rot_matrix(rx, ry, rz):
    """Поворот (градусы): сначала X, потом Z, потом Y. Матрица 3×3 по строкам."""
    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    x, y, z = (math.radians(v) for v in (rx, ry, rz))
    mx = [[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]]
    my = [[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]]
    mz = [[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]]
    return mul(my, mul(mz, mx))


class Model:
    def __init__(self, name):
        self.name = name
        self.subs = []  # (type, id, props)
        self.nodes = []
        self.mats = {}
        self.lo = [1e9, 1e9, 1e9]
        self.hi = [-1e9, -1e9, -1e9]

    def mat(self, color, emission=0.0, rough=0.7, metal=0.0, alpha=1.0):
        key = (color, emission, rough, metal, alpha)
        if key not in self.mats:
            mid = f"mat{len(self.mats) + 1}"
            p = {"albedo_color": col(color, alpha), "roughness": rough, "metallic": metal}
            if alpha < 1.0:
                p["transparency"] = 1
            if emission:
                p.update({"emission_enabled": "true", "emission": col(color), "emission_energy_multiplier": emission})
            self.subs.append(("StandardMaterial3D", mid, p))
            self.mats[key] = mid
        return self.mats[key]

    def part(self, kind, props, mat, pos, scale=(1, 1, 1), rot=(0, 0, 0), extent=(0.5, 0.5, 0.5)):
        sid = f"mesh{len(self.subs) + 1}"
        props = dict(props)
        props["material"] = f'SubResource("{mat}")'
        self.subs.append((kind, sid, props))
        r = rot_matrix(*rot)
        m = [[r[i][j] * scale[j] for j in range(3)] for i in range(3)]
        t = "Transform3D(%s)" % ", ".join(fmt(float(v)) for v in [m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2],
                                                               m[2][0], m[2][1], m[2][2], *pos])
        self.nodes.append((f"P{len(self.nodes) + 1}", t, sid))
        # Габариты — грубо, по наибольшему размаху части.
        reach = max(extent[i] * scale[i] for i in range(3))
        for i in range(3):
            e = reach if any(rot) else extent[i] * scale[i]
            self.lo[i] = min(self.lo[i], pos[i] - e)
            self.hi[i] = max(self.hi[i], pos[i] + e)

    def box(self, size, mat, pos, rot=(0, 0, 0)):
        self.part("BoxMesh", {"size": "Vector3(%s)" % ", ".join(fmt(float(v)) for v in size)}, mat, pos, rot=rot,
                  extent=tuple(v / 2 for v in size))

    def sphere(self, r, mat, pos, scale=(1, 1, 1), seg=10, rings=6, rot=(0, 0, 0)):
        self.part("SphereMesh", {"radius": r, "height": r * 2, "radial_segments": seg, "rings": rings}, mat, pos, scale,
                  rot, extent=(r, r, r))

    def cyl(self, r_top, r_bot, h, mat, pos, rot=(0, 0, 0), seg=10, scale=(1, 1, 1)):
        self.part("CylinderMesh", {"top_radius": r_top, "bottom_radius": r_bot, "height": h, "radial_segments": seg},
                  mat, pos, scale, rot, extent=(max(r_top, r_bot), h / 2, max(r_top, r_bot)))

    def torus(self, r_in, r_out, mat, pos, rot=(0, 0, 0)):
        self.part("TorusMesh", {"inner_radius": r_in, "outer_radius": r_out}, mat, pos, rot=rot,
                  extent=(r_out, r_out - r_in, r_out))

    def write(self, root):
        lines = [f'[gd_scene load_steps={len(self.subs) + 1} format=3]', ""]
        for kind, sid, props in self.subs:
            lines.append(f'[sub_resource type="{kind}" id="{sid}"]')
            for k, v in props.items():
                lines.append(f"{k} = {fmt(v) if isinstance(v, float) else v}")
            lines.append("")
        lines.append(f'[node name="{self.name}" type="Node3D"]')
        lines.append("")
        for name, t, sid in self.nodes:
            lines += [f'[node name="{name}" type="MeshInstance3D" parent="."]', f"transform = {t}",
                      f'mesh = SubResource("{sid}")', ""]
        path = os.path.join(root, "assets", "plants", self.name + ".tscn")
        open(path, "w", encoding="utf-8").write("\n".join(lines))
        return {"pos": [round(v, 3) for v in self.lo], "size": [round(self.hi[i] - self.lo[i], 3) for i in range(3)]}


# Приглушённая, «больная» зелень мёртвого сада (не яркая): тёмные оливковые и серо-зелёные тона.
GREENS = [(0.06, 0.09, 0.05), (0.08, 0.11, 0.06), (0.07, 0.08, 0.06), (0.1, 0.1, 0.06)]
GLOWS = [(0.35, 0.7, 0.75), (0.75, 0.35, 0.55), (0.85, 0.6, 0.3)]


def planter(rng):
    m = Model("Plant_Planter")
    metal = m.mat((0.14, 0.16, 0.17), rough=0.45, metal=0.6)
    m.box((1.8, 0.5, 0.8), metal, (0, 0.25, 0))
    m.box((1.9, 0.08, 0.9), m.mat((0.3, 0.32, 0.33), rough=0.4, metal=0.7), (0, 0.52, 0))
    m.box((1.7, 0.06, 0.7), m.mat((0.08, 0.06, 0.04)), (0, 0.55, 0))
    for i in range(6):
        x = -0.7 + i * 0.28 + rng.uniform(-0.05, 0.05)
        m.sphere(0.32, m.mat(rng.choice(GREENS)), (x, 0.72 + rng.uniform(0, 0.12), rng.uniform(-0.12, 0.12)),
                 (1.0, rng.uniform(0.6, 0.9), 0.9))
    for i in range(3):
        x = rng.uniform(-0.6, 0.6)
        h = rng.uniform(0.5, 0.9)
        m.cyl(0.015, 0.02, h, m.mat((0.08, 0.12, 0.06)), (x, 0.6 + h / 2, rng.uniform(-0.15, 0.15)), seg=5)
        m.sphere(0.07, m.mat(rng.choice(GLOWS), emission=1.2, rough=0.3), (x, 0.6 + h + 0.05, 0), seg=8, rings=4)
    return m


def tree(rng):
    m = Model("Plant_Tree")
    stone = m.mat((0.2, 0.2, 0.21), rough=0.8)
    m.cyl(0.8, 0.7, 0.6, stone, (0, 0.3, 0), seg=12)
    m.cyl(0.72, 0.72, 0.05, m.mat((0.08, 0.06, 0.04)), (0, 0.6, 0), seg=12)
    bark = m.mat((0.18, 0.12, 0.08), rough=0.9)
    m.cyl(0.12, 0.2, 2.4, bark, (0, 1.8, 0), seg=7)
    m.cyl(0.05, 0.09, 1.0, bark, (0.35, 2.4, 0), rot=(0, 0, -35), seg=6)
    m.cyl(0.05, 0.09, 0.9, bark, (-0.3, 2.3, 0.1), rot=(10, 0, 40), seg=6)
    for (x, y, z, r) in [(0, 3.2, 0, 0.85), (0.6, 2.9, 0.2, 0.65), (-0.55, 2.85, -0.1, 0.7), (0.1, 2.8, -0.55, 0.6),
                         (-0.1, 2.75, 0.55, 0.6)]:
        m.sphere(r, m.mat(rng.choice(GREENS)), (x, y, z), (1.0, 0.75, 1.0))
    glow = m.mat((1.0, 0.75, 0.3), emission=3.0, rough=0.3)
    for _ in range(5):
        a = rng.uniform(0, math.tau)
        m.sphere(0.07, glow, (math.cos(a) * 0.7, 2.45, math.sin(a) * 0.7), seg=8, rings=4)
    return m


def fern(rng):
    m = Model("Plant_Fern")
    for i in range(9):
        a = i * 40 + rng.uniform(-10, 10)
        tilt = rng.uniform(40, 65)
        length = rng.uniform(0.7, 1.1)
        rad = math.radians(a)
        dx, dz = math.sin(rad), math.cos(rad)
        cx = dx * math.sin(math.radians(tilt)) * length / 2
        cz = dz * math.sin(math.radians(tilt)) * length / 2
        cy = math.cos(math.radians(tilt)) * length / 2
        # Лист: сплюснутый конус, наклонён наружу.
        m.cyl(0.0, 0.13, length, m.mat(rng.choice(GREENS), rough=0.8), (cx, cy, cz), rot=(tilt, a, 0), seg=4,
              scale=(1.0, 1.0, 0.25))
    m.sphere(0.06, m.mat(rng.choice(GLOWS), emission=1.2), (0, 0.25, 0), seg=8, rings=4)
    return m


def flowerbed(rng):
    m = Model("Plant_Bed")
    stone = m.mat((0.22, 0.21, 0.2), rough=0.85)
    m.box((3.6, 0.4, 1.2), stone, (0, 0.2, 0))
    m.box((3.4, 0.05, 1.0), m.mat((0.08, 0.06, 0.04)), (0, 0.42, 0))
    for _ in range(14):
        x, z = rng.uniform(-1.6, 1.6), rng.uniform(-0.4, 0.4)
        m.sphere(0.2, m.mat(rng.choice(GREENS)), (x, 0.5, z), (1.0, rng.uniform(0.5, 0.9), 1.0), seg=8, rings=4)
    for _ in range(10):
        x, z = rng.uniform(-1.6, 1.6), rng.uniform(-0.4, 0.4)
        h = rng.uniform(0.25, 0.6)
        m.cyl(0.012, 0.015, h, m.mat((0.08, 0.12, 0.06)), (x, 0.45 + h / 2, z), seg=4)
        m.sphere(0.06, m.mat(rng.choice(GLOWS), emission=1.0, rough=0.3), (x, 0.45 + h + 0.04, z), seg=8, rings=4)
    return m


def shrine(rng):
    """Святыня: каменный алтарь со свечами и золотым нимбом над ним (религиозные мотивы Эдема)."""
    m = Model("Shrine_Candles")
    stone = m.mat((0.25, 0.24, 0.22), rough=0.85)
    m.box((1.4, 0.9, 0.7), stone, (0, 0.45, 0))
    m.box((1.6, 0.1, 0.85), m.mat((0.32, 0.3, 0.27), rough=0.85), (0, 0.95, 0))
    m.box((0.12, 0.9, 0.06), m.mat((0.85, 0.65, 0.3), emission=1.2, rough=0.3, metal=0.8), (0, 1.5, -0.25))
    m.box((0.55, 0.1, 0.06), m.mat((0.85, 0.65, 0.3), emission=1.2, rough=0.3, metal=0.8), (0, 1.7, -0.25))
    wax = m.mat((0.9, 0.85, 0.72), rough=0.6)
    flame = m.mat((1.0, 0.7, 0.3), emission=4.0)
    for i in range(7):
        x = -0.6 + i * 0.2 + rng.uniform(-0.03, 0.03)
        z = rng.uniform(0.0, 0.25)
        h = rng.uniform(0.12, 0.3)
        m.cyl(0.035, 0.035, h, wax, (x, 1.0 + h / 2, z), seg=6)
        m.sphere(0.03, flame, (x, 1.0 + h + 0.04, z), (1, 1.6, 1), seg=6, rings=3)
    m.torus(0.42, 0.46, m.mat((1.0, 0.8, 0.4), emission=1.2, rough=0.3), (0, 2.25, -0.25), rot=(90, 0, 0))
    return m


def statue(rng):
    """Статуя святого в капюшоне на постаменте."""
    m = Model("Statue_Saint")
    stone = m.mat((0.3, 0.3, 0.31), rough=0.9)
    m.box((1.1, 0.6, 1.1), stone, (0, 0.3, 0))
    m.cyl(0.25, 0.45, 1.7, stone, (0, 1.45, 0), seg=10)
    m.sphere(0.27, stone, (0, 2.42, 0.02), (1, 1.15, 1), seg=10)
    m.sphere(0.2, m.mat((0.04, 0.04, 0.05)), (0, 2.38, -0.12), (1, 1.1, 0.6), seg=8)
    m.cyl(0.07, 0.09, 0.8, stone, (0.22, 1.85, -0.18), rot=(-60, 0, 20), seg=6)
    m.cyl(0.07, 0.09, 0.8, stone, (-0.22, 1.85, -0.18), rot=(-60, 0, -20), seg=6)
    m.torus(0.3, 0.33, m.mat((1.0, 0.82, 0.45), emission=2.0, rough=0.3), (0, 2.8, 0.1), rot=(80, 0, 0))
    return m


def main(root):
    os.makedirs(os.path.join(root, "assets", "plants"), exist_ok=True)
    sizes_path = os.path.join(HERE, "model_sizes.json")
    sizes = json.load(open(sizes_path, encoding="utf-8"))
    for i, make in enumerate([planter, tree, fern, flowerbed, shrine, statue]):
        m = make(random.Random(100 + i))
        sizes[m.name] = m.write(root)
        print(m.name, sizes[m.name])
    json.dump(sizes, open(sizes_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1])
