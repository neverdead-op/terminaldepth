"""Генератор этажей scenes/zones/zone_N.tscn (N = 1..5) — сектор «Сады Эдема», в духе карт PoE 2:
много небольших залов неровной формы, узкие коридоры (5 м), понятный главный путь от старта к лифту
(тёплый свет и разметка на полу), тупики-ответвления с наградами и заданиями.
Запуск из папки проекта: python -I tools/gen_open_zone.py .        (перезаписывает zone_1..zone_5)

Устройство: залы лежат по сетке GX×GZ (клетка CELL м); зал — главный прямоугольник + выступы.
Связи — дерево (всё достижимо) + немного петель. Стены — по контуру проходимых клеток (1 м).
Виды залов: сад (кадки, деревья, клумбы), лаборатория (мебель), часовня (статуи, алтари), склад (ящики),
арена (перед лифтом — босс или жёлтый вожак). Задания этажа: сундуки + два из (роботы, обелиски, инкубаторы)
+ разлом (волны врагов).
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_facility import Scene, vec, col, fmt, tr  # noqa: E402

WALL_H = 3.0  # = высота стенных модулей MegaKit
GX, GZ = 6, 4
CELL = 22
START = (0, 1)
CORR = 5  # ширина коридора (= ширина двери)
SOLID_HEIGHT = 1.8  # предметы ниже — без столкновений (не застревать в ящиках и кадках)
SEEDS = {1: 11, 2: 23, 3: 37, 4: 41, 5: 58}
# Какие задания на каком этаже (кроме сундуков и разлома — они всегда).
# На втором сюжетном ярусе есть все четыре побочные активности: персонал, робот,
# обелиски и инкубаторы. Дальше задания снова открываются постепенно.
QUESTS = {1: ("allies", "escort", "obelisks", "nests"), 2: ("allies", "escort"), 3: ("obelisks", "nests"), 4: ("escort", "obelisks"),
          5: ("nests", "obelisks")}

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SIZES = json.load(open(os.path.join(HERE, "model_sizes.json"), encoding="utf-8"))


## Доля врагов в стае по этажам (1 — полная стая). Ранние этажи — меньше врагов.
PACK_DENSITY = {1: 0.55, 2: 0.7, 3: 0.85}

# Растения Quaternius Stylized Nature MegaKit (assets/nature): модели огромные — приводим к нужной высоте (м).
NATURE_HEIGHT = {
    "CommonTree": 3.4, "TwistedTree": 3.6, "DeadTree": 3.4, "Bush_Common": 0.95, "Bush_Common_Flowers": 0.95,
    "Fern_1": 0.75, "Plant_1_Big": 1.3, "Plant_1": 0.55, "Plant_7": 0.12, "Plant_7_Big": 0.14,
    "Flower_3": 0.6, "Flower_4": 0.65, "Grass_Common": 0.45, "Grass_Wispy": 0.5, "Clover": 0.3,
    "Mushroom": 0.3, "Rock_Medium": 0.9, "Pebble": 0.08, "Petal": 0.1,
}
NATURE_SCALE = {}
for _n, _v in list(SIZES.items()):
    for _prefix, _h in NATURE_HEIGHT.items():
        if _n.startswith(_prefix) and os.path.exists(os.path.join(ROOT, "assets", "nature", _n + ".gltf")):
            NATURE_SCALE[_n] = round(_h / _v["size"][1], 4) if _prefix not in ("Pebble", "Petal", "Plant_7") else 0.6
            break
N_TREES = [n for n in NATURE_SCALE if n.startswith("CommonTree")]
N_DEAD = [n for n in NATURE_SCALE if n.startswith("DeadTree")]
# Кусты Bush_Common в паке красные, а цветы — пёстрые: в садах «Эдема» только зелень.
N_BUSHES = ["Plant_1_Big", "Fern_1", "Fern_1"]
# Мелочь: в основном трава и зелень, цветов немного (тон мрачный, не мультяшный).
N_SMALL = ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall"] * 3 + [
           "Clover_1", "Clover_2", "Plant_1", "Plant_1", "Mushroom_Common"]
N_GROUND = [n for n in NATURE_SCALE if n.startswith("Pebble")]
## Растения приглушаем (умножение цвета материалов в model_batch.gd).
NATURE_TINT = (0.55, 0.62, 0.55)
## Стенные панели MegaKit — приглушённые (model_batch tint).
WALL_TINT = (0.58, 0.6, 0.64)


def model_path(name):
    if name in NATURE_SCALE:
        return f"res://assets/nature/{name}.gltf"
    for pack in ("essentials", "megakit"):
        if os.path.exists(os.path.join(ROOT, "assets", pack, name + ".gltf")):
            return f"res://assets/{pack}/{name}.gltf"
    if os.path.exists(os.path.join(ROOT, "assets", "plants", name + ".tscn")):
        return f"res://assets/plants/{name}.tscn"
    raise KeyError(name)


class Batches:
    """Копии моделей для model_batch.gd: на каждую модель — список по 12 чисел (базис + точка)."""

    def __init__(self):
        self.items = {}

    def add(self, name, pos, yaw=0.0, scale=(1.0, 1.0, 1.0), shadows=True):
        c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        sx, sy, sz = scale
        self.items.setdefault((name, shadows), []).extend(
            [c * sx, 0.0, -s * sx, 0.0, sy, 0.0, s * sz, 0.0, c * sz, pos[0], pos[1], pos[2]])

    def emit(self, sc, parent, script):
        for i, ((name, shadows), data) in enumerate(sorted(self.items.items())):
            rid = sc.ext_res("PackedScene", model_path(name))
            props = {
                "script": f'ExtResource("{script}")', "model": f'ExtResource("{rid}")',
                "transforms": "PackedFloat32Array(%s)" % ", ".join(fmt(round(float(v), 3)) for v in data),
                "cast_shadows": "true" if shadows else "false"}
            if name in NATURE_SCALE:
                props["tint"] = col(NATURE_TINT)
            elif name.startswith("Wall"):
                # Белые панели MegaKit под яркими лампами пересвечивались — делаем их серее.
                props["tint"] = col(WALL_TINT)
            sc.node(f"{name}_{i + 1}", "Node3D", parent, props)


# Вид зала → (цвет пола, цвет света, яркость)
## Яркость ламп залов относительно KINDS (общий фон стал темнее — свет даёт пятна).
ROOM_LIGHT_MUL = 3.4
KINDS = {
    "start": ((0.17, 0.17, 0.19), (0.85, 0.9, 1.0), 2.0),
    "garden": ((0.11, 0.15, 0.11), (0.75, 1.0, 0.8), 1.9),
    "lab": ((0.17, 0.17, 0.19), (0.8, 0.88, 1.0), 2.0),
    "chapel": ((0.16, 0.13, 0.12), (1.0, 0.72, 0.42), 1.9),
    "storage": ((0.16, 0.16, 0.15), (0.95, 0.85, 0.7), 1.8),
    "arena": ((0.15, 0.12, 0.12), (1.0, 0.45, 0.35), 2.0),
    "exit": ((0.14, 0.14, 0.16), (1.0, 0.55, 0.3), 2.2),
    "key": ((0.15, 0.15, 0.18), (0.6, 0.85, 1.0), 2.0),
}
# Названия залов — «ориентиры» (появляются при входе, как названия мест в PoE 2).
NAMES = {
    "garden": ["Оранжерея лилий", "Висячий сад", "Папоротниковая галерея", "Сад вечной весны", "Теплица «Ковчег»",
               "Аллея кипарисов"],
    "chapel": ["Часовня Садовника", "Ризница", "Придел тишины", "Капелла Древа"],
    "lab": ["Лаборатория гидропоники", "Генный архив", "Пост наблюдения"],
    "storage": ["Склад семян", "Насосная", "Компостная"],
    "arena": ["Атриум"],
    "exit": ["Грузовой лифт"],
    "key": ["Пост охраны"],
}


def rect_intersects(a, b, pad=0):
    return a[0] - pad < b[2] and b[0] - pad < a[2] and a[1] - pad < b[3] and b[1] - pad < a[3]


def center_of(r):
    return ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2)


def build(level, seed):
    rng = random.Random(seed)
    cells = [(x, z) for x in range(GX) for z in range(GZ)]

    # --- Связи: дерево (обход в глубину) + петли ---
    def nbrs(c):
        x, z = c
        return [n for n in ((x + 1, z), (x - 1, z), (x, z + 1), (x, z - 1)) if 0 <= n[0] < GX and 0 <= n[1] < GZ]

    edges, depth, parent, stack = set(), {START: 0}, {START: None}, [START]
    while stack:
        cur = stack[-1]
        opts = [n for n in nbrs(cur) if n not in depth]
        if not opts:
            stack.pop()
            continue
        n = rng.choice(opts)
        depth[n], parent[n] = depth[cur] + 1, cur
        edges.add(frozenset((cur, n)))
        stack.append(n)
    children = {c: [n for n in cells if parent.get(n) == c] for c in cells}
    leaves = sorted((c for c in cells if c != START and not children[c]), key=lambda c: depth[c], reverse=True)
    exit_area = leaves[0]
    arena = parent[exit_area]
    main_path = []
    c = exit_area
    while c is not None:
        main_path.append(c)
        c = parent[c]
    main_path.reverse()
    key_area = next((c for c in leaves[1:] if c not in main_path and abs(c[0] - exit_area[0]) + abs(c[1] - exit_area[1]) > 2),
                    leaves[1])
    for c in cells:
        for n in nbrs(c):
            e = frozenset((c, n))
            if e not in edges and not ({START, exit_area, key_area} & e) and rng.random() < 0.12:
                edges.add(e)
    main_edges = {frozenset((a, b)) for a, b in zip(main_path, main_path[1:])}

    # --- Залы ---
    kinds = {START: "start", exit_area: "exit", arena: "arena", key_area: "key"}
    others = [c for c in cells if c not in kinds]
    rng.shuffle(others)
    pool = ["garden"] * 9 + ["lab"] * 4 + ["chapel"] * 3 + ["storage"] * 4
    for i, c in enumerate(others):
        kinds[c] = pool[i % len(pool)]
    areas = {}
    for c in cells:
        cx, cz = (c[0] - (GX - 1) / 2) * CELL, (c[1] - (GZ - 1) / 2) * CELL
        k = kinds[c]
        if k == "start":
            w, d = 14, 12
        elif k == "arena":
            w, d = 18, 16
        elif k in ("exit", "key"):
            w, d = 10, 10
        else:
            w, d = rng.randrange(10, 18, 2), rng.randrange(10, 16, 2)
        jx, jz = (0, 0) if k in ("start", "arena") else (rng.randint(-2, 2), rng.randint(-2, 2))
        main = (int(cx + jx - w / 2), int(cz + jz - d / 2), int(cx + jx + w / 2), int(cz + jz + d / 2))
        rects = [main]
        lim = (cx - CELL / 2 + 2, cz - CELL / 2 + 2, cx + CELL / 2 - 2, cz + CELL / 2 - 2)
        if k not in ("start", "exit", "key"):
            for _ in range(rng.randint(1, 3)):
                bw, bd = rng.randrange(5, 10), rng.randrange(5, 9)
                side = rng.choice("nsew")
                if side in "ns":
                    x0 = rng.randint(main[0] - 2, main[2] - bw + 2)
                    z0 = main[1] - bd + 3 if side == "n" else main[3] - 3
                else:
                    z0 = rng.randint(main[1] - 2, main[3] - bd + 2)
                    x0 = main[0] - bw + 3 if side == "w" else main[2] - 3
                blob = (max(x0, int(lim[0])), max(z0, int(lim[1])), min(x0 + bw, int(lim[2])), min(z0 + bd, int(lim[3])))
                if blob[2] - blob[0] >= 4 and blob[3] - blob[1] >= 4:
                    rects.append(blob)
        names = NAMES.get(k, [])
        areas[c] = {"main": main, "rects": rects, "center": center_of(main), "kind": k,
                    "name": names[rng.randrange(len(names))] if names else ""}

    # --- Коридоры: прямые, по линии, где оба зала достаточно широкие ---
    passages, corridor_info = [], []
    for e in sorted(edges, key=lambda e: sorted(e)):
        a, b = sorted(e)
        ma, mb = areas[a]["main"], areas[b]["main"]
        if a[1] == b[1]:  # по X
            lo, hi = max(ma[1], mb[1]) + 1, min(ma[3], mb[3]) - 1 - CORR
            z0 = rng.randint(lo, hi) if hi >= lo else round((areas[a]["center"][1] + areas[b]["center"][1]) / 2 - CORR / 2)
            r = (ma[2] - 1, z0, mb[0] + 1, z0 + CORR)
            axis = "x"
        else:  # по Z
            lo, hi = max(ma[0], mb[0]) + 1, min(ma[2], mb[2]) - 1 - CORR
            x0 = rng.randint(lo, hi) if hi >= lo else round((areas[a]["center"][0] + areas[b]["center"][0]) / 2 - CORR / 2)
            r = (x0, ma[3] - 1, x0 + CORR, mb[1] + 1)
            axis = "z"
        passages.append(r)
        corridor_info.append({"rect": r, "axis": axis, "a": a, "b": b, "main": e in main_edges})

    all_rects = [r for a in areas.values() for r in a["rects"]] + passages

    def walkable(x, z):
        px, pz = x + 0.5, z + 0.5
        return any(r[0] <= px < r[2] and r[1] <= pz < r[3] for r in all_rects)

    xs = [r[0] for r in all_rects] + [r[2] for r in all_rects]
    zs = [r[1] for r in all_rects] + [r[3] for r in all_rects]
    bx0, bx1, bz0, bz1 = min(xs) - 1, max(xs) + 1, min(zs) - 1, max(zs) + 1
    walk = {(x, z) for z in range(bz0, bz1) for x in range(bx0, bx1) if walkable(x, z)}
    wall_cells = {(x, z) for z in range(bz0, bz1) for x in range(bx0, bx1)
                  if (x, z) not in walk and any((x + dx, z + dz) in walk for dx in (-1, 0, 1) for dz in (-1, 0, 1))}
    walls, open_by_key = [], {}
    for z in range(bz0, bz1):
        x = bx0
        while x < bx1:
            if (x, z) in wall_cells:
                s = x
                while (x, z) in wall_cells:
                    x += 1
                r = [s, z, x, z + 1]
                m = open_by_key.pop((r[0], r[2], r[1]), None)
                if m is not None:
                    m[3] = r[3]
                    open_by_key[(m[0], m[2], m[3])] = m
                else:
                    walls.append(r)
                    open_by_key[(r[0], r[2], r[3])] = r
            else:
                x += 1

    def area_of(x, z):
        for c, a in areas.items():
            if any(r[0] <= x < r[2] and r[1] <= z < r[3] for r in a["rects"]):
                return c
        return None

    occupied = []  # занятые места (стоят сундуки, задания и т. п.)

    def free_spot(area_c, margin=2, clear=1.6):
        a = areas[area_c]
        for _ in range(120):
            r = rng.choice(a["rects"])
            if r[2] - r[0] <= margin * 2 or r[3] - r[1] <= margin * 2:
                continue
            x = rng.uniform(r[0] + margin, r[2] - margin)
            z = rng.uniform(r[1] + margin, r[3] - margin)
            if (int(x), int(z)) not in walk:
                continue
            if any(abs(x - ox) < clear and abs(z - oz) < clear for ox, oz in occupied):
                continue
            if any(rect_intersects((x - 1.5, z - 1.5, x + 1.5, z + 1.5), p) for p in passages):
                continue
            return x, z
        return a["center"]

    def take(x, z):
        occupied.append((x, z))
        return x, z

    # --- Сцена ---
    sc = Scene()
    R = {k: sc.ext_res("Script" if k.endswith("_s") else "PackedScene", p) for k, p in {
        "zone_s": "res://scripts/zone.gd", "player": "res://scenes/player.tscn", "camera_s": "res://scripts/camera_rig.gd",
        "pool_s": "res://scripts/bullet_pool.gd", "bullet": "res://scenes/bullet.tscn",
        "crawler": "res://scenes/crawler.tscn", "brute": "res://scenes/brute.tscn", "spitter": "res://scenes/spitter.tscn",
        "leaper": "res://scenes/leaper.tscn",
        "door_s": "res://scripts/door.gd", "spawner_s": "res://scripts/enemy_spawner.gd", "key_s": "res://scripts/keycard.gd",
        "exit_s": "res://scripts/level_exit.gd", "safe_s": "res://scripts/safe_zone.gd", "loot_s": "res://scripts/loot_pickup.gd",
        "batch_s": "res://scripts/model_batch.gd", "robot_walker": "res://scenes/robot_walker.tscn",
        "robot_heavy": "res://scenes/robot_heavy.tscn", "robot_drone": "res://scenes/robot_drone.tscn",
        "chest_s": "res://scripts/loot_chest.gd", "flicker_s": "res://scripts/flicker_light.gd",
        "boss_foreman": "res://scenes/boss_foreman.tscn", "boss_doctor": "res://scenes/boss_doctor.tscn",
        "boss_sentinel": "res://scenes/boss_sentinel.tscn",
        "ally_s": "res://scripts/ally_robot.gd", "destr_s": "res://scripts/destructible.gd",
        "sci_s": "res://scripts/scientist.gd",
        "seal_s": "res://scripts/seal_event.gd",
    }.items()}
    batches = Batches()
    floor_shader = sc.ext_res("Shader", "res://assets/shaders/floor.gdshader")

    env = sc.sub_res("Environment", {
        "background_mode": 1, "background_color": col((0.01, 0.012, 0.012)),
        "ambient_light_source": 2, "ambient_light_color": col((0.42, 0.5, 0.55)), "ambient_light_energy": 1.55,
        "tonemap_mode": 3, "tonemap_exposure": 1.15,
        "ssao_enabled": "true", "ssao_radius": 1.5, "ssao_intensity": 2.5,
        "ssil_enabled": "true", "ssil_radius": 4.0, "ssil_intensity": 1.2,
        "glow_enabled": "true", "glow_intensity": 0.6, "glow_bloom": 0.04, "glow_hdr_threshold": 1.2,
        "fog_enabled": "true", "fog_light_color": col((0.04, 0.06, 0.05)), "fog_density": 0.005,
        "adjustment_enabled": "true", "adjustment_contrast": 1.1, "adjustment_saturation": 1.1,
    })
    navmesh = sc.sub_res("NavigationMesh", {
        "geometry_parsed_geometry_type": 1, "geometry_collision_mask": 1,
        "cell_size": 0.25, "cell_height": 0.25, "agent_height": 1.0, "agent_radius": 0.5, "agent_max_climb": 0.25})
    m_floors = {k: sc.sub_res("ShaderMaterial", {"shader": f'ExtResource("{floor_shader}")',
                                                 "shader_parameter/base_color": col(v[0])}) for k, v in KINDS.items()}
    m_passage = sc.sub_res("ShaderMaterial", {"shader": f'ExtResource("{floor_shader}")',
                                              "shader_parameter/base_color": col((0.12, 0.12, 0.13)),
                                              "shader_parameter/panel_size": 2.5})

    def plain(color, metal, rough):
        return sc.sub_res("StandardMaterial3D", {"albedo_color": col(color), "metallic": metal, "roughness": rough})

    m_top = plain((0.24, 0.27, 0.28), 0.1, 0.6)
    m_core = plain((0.06, 0.07, 0.07), 0.4, 0.7)

    landmarks = [(a["main"], a["name"]) for c, a in sorted(areas.items()) if a["name"]]
    sc.node("Zone", "Node3D", None, {
        "script": f'ExtResource("{R["zone_s"]}")', "zone_level": level + 1,
        "enemy_life_scale": 0.66 if level == 1 else 0.85, "extra_enemy_ratio": 0.5,
        "map_rects": "Array[Rect2]([%s])" % ", ".join(f"Rect2({r[0]}, {r[1]}, {r[2] - r[0]}, {r[3] - r[1]})" for r in all_rects),
        "exit_position": "Vector2(%s, %s)" % tuple(fmt(float(v)) for v in areas[exit_area]["center"]),
        "landmark_rects": "Array[Rect2]([%s])" % ", ".join(f"Rect2({r[0]}, {r[1]}, {r[2] - r[0]}, {r[3] - r[1]})"
                                                          for r, _ in landmarks),
        "landmark_names": "PackedStringArray(%s)" % ", ".join(f'"{n}"' for _, n in landmarks),
        "xp_scale": "__XP_SCALE__",
    })
    sc.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})
    sc.node("MoonLight", "DirectionalLight3D", ".", {
        "transform": "Transform3D(0.819, -0.471, 0.328, 0, 0.571, 0.821, -0.574, -0.672, 0.468, 0, 10, 0)",
        "light_color": col((0.6, 0.72, 0.85)), "light_energy": 0.3, "shadow_enabled": "true"})
    sc.node("Navigation", "NavigationRegion3D", ".", {"navigation_mesh": f'SubResource("{navmesh}")'})
    sc.node("Geometry", "Node3D", "Navigation")
    g = "Navigation/Geometry"
    n = 0
    for c, a in sorted(areas.items()):
        for r in a["rects"]:
            n += 1
            sc.static_box(f"Floor{n}", g, ((r[0] + r[2]) / 2, -0.25, (r[1] + r[3]) / 2),
                          (float(r[2] - r[0]), 0.5, float(r[3] - r[1])), m_floors[a["kind"]])
    for i, r in enumerate(passages):
        sc.static_box(f"Passage{i + 1}", g, ((r[0] + r[2]) / 2, -0.26, (r[1] + r[3]) / 2),
                      (float(r[2] - r[0]), 0.5, float(r[3] - r[1])), m_passage)
    for i, (x0, z0, x1, z1) in enumerate(walls):
        size = (float(x1 - x0), WALL_H, float(z1 - z0))
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        name = f"Wall{i + 1}"
        sc.node(name, "StaticBody3D", g, {"transform": tr((mx, WALL_H / 2, mz))})
        sc.node("Shape", "CollisionShape3D", f"{g}/{name}", {"shape": f'SubResource("{sc.box_shape(size)}")'})
        core = (max(size[0] - 0.5, 0.1), WALL_H, max(size[2] - 0.5, 0.1))
        sc.node("Mesh", "MeshInstance3D", f"{g}/{name}", {"mesh": f'SubResource("{sc.box_mesh(core, m_core)}")'})
        sc.node("Top", "MeshInstance3D", f"{g}/{name}", {
            "transform": tr((0, WALL_H / 2 + 0.03, 0)),
            "mesh": f'SubResource("{sc.box_mesh((size[0], 0.06, size[2]), m_top)}")'})

    # Панели MegaKit вдоль стен. В лабораториях и часовнях — «чистые» панели Astra, в остальном — технические.
    wall_edges = {}
    for (x, z) in wall_cells:
        if (x + 1, z) in walk:
            wall_edges.setdefault(("+x", x + 1), []).append(z)
        if (x - 1, z) in walk:
            wall_edges.setdefault(("-x", x), []).append(z)
        if (x, z + 1) in walk:
            wall_edges.setdefault(("+z", z + 1), []).append(x)
        if (x, z - 1) in walk:
            wall_edges.setdefault(("-z", z), []).append(x)
    for (d, line), cells_on_line in sorted(wall_edges.items()):
        cells_on_line.sort()
        runs, start = [], cells_on_line[0]
        for a, b in zip(cells_on_line, cells_on_line[1:] + [None]):
            if b != a + 1:
                runs.append((start, a + 1))
                start = b
        for (r0, r1) in runs:
            length = r1 - r0
            k = max(1, round(length / 4))
            seg = length / k
            for j in range(k):
                t = r0 + seg * (j + 0.5)
                if d in ("+x", "-x"):
                    cell = (line if d == "+x" else line - 1, int(t))
                else:
                    cell = (int(t), line if d == "+z" else line - 1)
                ac = area_of(cell[0] + 0.5, cell[1] + 0.5)
                clean = ac is not None and areas[ac]["kind"] in ("lab", "chapel", "start", "key")
                window = seg >= 3 and rng.random() < 0.2
                if clean:
                    module = "WallAstra_Straight_Flat_Window" if window else "WallAstra_Straight_Flat"
                else:
                    module = "WallWindow_Straight" if window else "WallBand_Straight"
                pos, yaw = {"+x": ((line + 2, 0, t), 0), "-x": ((line - 2, 0, t), 180),
                            "+z": ((t, 0, line + 2), -90), "-z": ((t, 0, line - 2), 90)}[d]
                batches.add(module, pos, yaw, (1.0, WALL_H / 3.0, seg / 4.0))

    # --- Обстановка ---
    pi = 0

    def place_prop(name, cx, cz, yaw=0, scale=(1.0, 1.0, 1.0), collide=True, y=0.0, shadows=True):
        """Ставит модель центром её габаритов в (cx, cz) на пол; поворот — шагами по 90°."""
        nonlocal pi
        if name in NATURE_SCALE and scale == (1.0, 1.0, 1.0):
            k = NATURE_SCALE[name] * rng.uniform(0.85, 1.15)
            scale = (k, k, k)
        p, s = SIZES[name]["pos"], SIZES[name]["size"]
        lx, lz = (p[0] + s[0] / 2) * scale[0], (p[2] + s[2] / 2) * scale[2]
        c, sn = round(math.cos(math.radians(yaw))), round(math.sin(math.radians(yaw)))
        ox, oz = c * lx + sn * lz, -sn * lx + c * lz
        batches.add(name, (cx - ox, y - max(p[1], 0.0) * scale[1], cz - oz), yaw, scale, shadows)
        w, d = s[0] * scale[0], s[2] * scale[2]
        if yaw % 180:
            w, d = d, w
        h = s[1] * scale[1]
        # Мелочь (ниже SOLID_HEIGHT) не мешает: герой проходит сквозь, пули пролетают над ней.
        if collide and h >= SOLID_HEIGHT:
            pi += 1
            sc.node(f"Prop{pi}", "StaticBody3D", g, {"transform": tr((round(cx, 2), round(y + h / 2, 2), round(cz, 2)))})
            sc.node("Shape", "CollisionShape3D", f"{g}/Prop{pi}",
                    {"shape": f'SubResource("{sc.box_shape((round(w * 0.9, 2), round(h, 2), round(d * 0.9, 2)))}")'})
        return (cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2), h

    def fits(name, x, z, yaw, pad=0.3):
        k = NATURE_SCALE.get(name, 1.0)
        s = [v * k for v in SIZES[name]["size"]]
        w, d = (s[0], s[2]) if yaw % 180 == 0 else (s[2], s[0])
        fp = (x - w / 2 - pad, z - d / 2 - pad, x + w / 2 + pad, z + d / 2 + pad)
        if not all((int(px), int(pz)) in walk for px in (fp[0], fp[2], x) for pz in (fp[1], fp[3], z)):
            return False
        if any(rect_intersects(fp, p, 0.5) for p in passages):
            return False
        if any(fp[0] - 1 < ox < fp[2] + 1 and fp[1] - 1 < oz < fp[3] + 1 for ox, oz in occupied):
            return False
        return True

    def put(name, x, z, yaw=0, collide=True, shadows=True):
        if not fits(name, x, z, yaw):
            return False
        place_prop(name, x, z, yaw, collide=collide, shadows=shadows)
        occupied.append((x, z))
        return True

    def scatter(c, names, count, collide=True, margin=2.0):
        for _ in range(count):
            for _t in range(15):
                r = rng.choice(areas[c]["rects"])
                if r[2] - r[0] <= margin * 2 or r[3] - r[1] <= margin * 2:
                    continue
                x, z = rng.uniform(r[0] + margin, r[2] - margin), rng.uniform(r[1] + margin, r[3] - margin)
                if put(rng.choice(names), x, z, rng.choice([0, 90, 180, 270]), collide):
                    break

    def along_wall(c, names, density=0.6):
        """Мебель вдоль северной и южной стен главного прямоугольника (если за стеной — стена, а не проход)."""
        x0, z0, x1, z1 = areas[c]["main"]
        for wall_z, yaw, outside in ((z0, 0, z0 - 1), (z1, 180, z1)):
            x = x0 + 1.0
            while x < x1 - 1.0:
                name = rng.choice(names)
                s = SIZES[name]["size"]
                if x + s[0] > x1 - 1.0:
                    break
                ok = all((int(xx), outside) in wall_cells for xx in (x, x + s[0] / 2, x + s[0] - 0.01))
                if ok and rng.random() < density:
                    depth_ = s[2]
                    cz = wall_z + depth_ / 2 + 0.05 if yaw == 0 else wall_z - depth_ / 2 - 0.05
                    if put(name, x + s[0] / 2, cz, yaw):
                        if name.startswith("Prop_Desk") and rng.random() < 0.6:
                            off = depth_ / 2 + 0.55
                            place_prop("Prop_Chair", x + s[0] / 2, cz + (off if yaw == 0 else -off), (360 - yaw) % 360,
                                       collide=False)
                x += s[0] + 0.3

    crates = ["Prop_Crate", "Prop_Crate", "Prop_Crate3", "Prop_Crate4", "Prop_Crate_Tarp", "Prop_Crate_Large"]
    barrels = ["Prop_Barrel1", "Prop_Barrel2_Closed", "Prop_Barrel_Large"]
    furniture = ["Prop_Locker", "Prop_Shelves_WideTall", "Prop_Shelves_ThinTall", "Prop_Computer", "Prop_Desk_Medium",
                 "Prop_Desk_Small"]
    decor = ["Prop_Vent_Big", "Prop_Vent_Small", "Prop_Vent_Wide", "Prop_Cable_1", "Prop_Cable_3"]
    for c, a in sorted(areas.items()):
        k = a["kind"]
        cx, cz = a["center"]
        m2 = sum((r[2] - r[0]) * (r[3] - r[1]) for r in a["rects"])
        if k == "start":
            continue
        if k == "garden":
            occupied.append((cx, cz))  # центр — для стаи/задания
            # Деревья (ствол — невидимая колонна), кусты, клумбы и много мелкой зелени без столкновений.
            for _ in range(rng.randint(2, 3)):
                for _t in range(15):
                    x, z = free_spot(c, 2.5, 2.5)
                    if (x, z) == tuple(areas[c]["center"]):
                        break
                    tree = rng.choice(N_DEAD if rng.random() < 0.2 else N_TREES)
                    if fits(tree, x, z, 0, pad=0.0):
                        place_prop(tree, x, z, rng.choice([0, 90, 180, 270]), collide=False)
                        occupied.append((x, z))
                        pi += 1
                        sc.node(f"Prop{pi}", "StaticBody3D", g, {"transform": tr((round(x, 2), 1.5, round(z, 2)))})
                        sc.node("Shape", "CollisionShape3D", f"{g}/Prop{pi}",
                                {"shape": f'SubResource("{sc.box_shape((0.6, 3.0, 0.6))}")'})
                        break
            scatter(c, ["Plant_Bed", "Plant_Planter"], int(m2 / 70), margin=1.6)
            scatter(c, N_BUSHES, int(m2 / 30), collide=False, margin=1.2)
            for _ in range(int(m2 / 9)):
                x, z = free_spot(c, 1.0, 0.6)
                if (x, z) != tuple(areas[c]["center"]):
                    place_prop(rng.choice(N_SMALL), x, z, rng.choice([0, 90, 180, 270]), collide=False, shadows=False)
            for _ in range(int(m2 / 14)):
                x, z = free_spot(c, 0.8, 0.0)
                if (x, z) != tuple(areas[c]["center"]):
                    place_prop(rng.choice(N_GROUND), x, z, rng.choice([0, 90, 180, 270]), collide=False, shadows=False)
        elif k == "lab":
            along_wall(c, furniture)
            scatter(c, crates, rng.randint(1, 3))
            scatter(c, ["Plant_Planter"], 1)
        elif k == "chapel":
            x0, z0, x1, z1 = a["main"]
            put("Statue_Saint", cx, z0 + 1.2, 0)
            put("Shrine_Candles", cx, z0 + 3.0, 0)
            for sx in (x0 + 1.5, x1 - 1.5):
                put("Statue_Saint", sx, z0 + 1.2, 0)
                put("Shrine_Candles", sx, (z0 + z1) / 2, 90 if sx < cx else 270)
            scatter(c, ["Plant_Fern"], int(m2 / 60), collide=False)
            for _ in range(int(m2 / 20)):
                x, z = free_spot(c, 1.0, 0.6)
                if (x, z) != tuple(areas[c]["center"]):
                    place_prop(rng.choice(N_SMALL[:6] + ["Mushroom_Common"]), x, z, rng.choice([0, 90, 180, 270]),
                               collide=False, shadows=False)
        elif k == "storage":
            for _ in range(int(m2 / 50)):
                scatter(c, rng.choice([crates, barrels]), rng.randint(2, 4), margin=1.5)
        elif k == "arena":
            x0, z0, x1, z1 = a["main"]
            for (px, pz) in ((x0 + 2.5, z0 + 2.5), (x1 - 2.5, z0 + 2.5), (x0 + 2.5, z1 - 2.5), (x1 - 2.5, z1 - 2.5)):
                put("Column_Round", px, pz, 0)
            scatter(c, ["Plant_Planter"], 2)
        elif k in ("exit", "key"):
            scatter(c, crates, 2, margin=1.5)
        for _ in range(int(m2 / 70)):
            x, z = free_spot(c, 1.5, 0.5)
            place_prop(rng.choice(decor), x, z, rng.choice([0, 90, 180, 270]), collide=False, shadows=False)

    # Разметка главного пути: пунктир на полу коридоров по пути к лифту.
    for ci in corridor_info:
        if not ci["main"]:
            continue
        r = ci["rect"]
        if ci["axis"] == "x":
            zc = (r[1] + r[3]) / 2
            for x in range(r[0] + 1, r[2] - 1, 3):
                place_prop("Decal_Dashes", x + 0.5, zc, 90, collide=False, y=0.01, shadows=False)
        else:
            xc = (r[0] + r[2]) / 2
            for z in range(r[1] + 1, r[3] - 1, 3):
                place_prop("Decal_Dashes", xc, z + 0.5, 0, collide=False, y=0.01, shadows=False)

    # Двери: у стартового зала (враги не открывают) и запертая дверь лифта (нужен ключ).
    sc.node("Doors", "Node3D", ".")
    di = 0
    for ci in corridor_info:
        ends = {ci["a"], ci["b"]}
        for special in (START, exit_area):
            if special not in ends:
                continue
            m = areas[special]["main"]
            r = ci["rect"]
            other = ci["b"] if ci["a"] == special else ci["a"]
            if ci["axis"] == "x":
                x = m[2] + 1.5 if other[0] > special[0] else m[0] - 1.5
                pos, rot = (x, 0, (r[1] + r[3]) / 2), 90
            else:
                z = m[3] + 1.5 if other[1] > special[1] else m[1] - 1.5
                pos, rot = ((r[0] + r[2]) / 2, 0, z), 0
            di += 1
            p = {"transform": tr(pos, rot), "script": f'ExtResource("{R["door_s"]}")', "height": WALL_H, "width": float(CORR)}
            if special == START:
                p["enemies_can_open"] = "false"
            else:
                p.update({"locked": "true", "key_id": '&"exit"', "key_name": '"Лифт"'})
            sc.node(f"Door{di}", "Node3D", "Doors", p)

    # --- Свет ---
    sc.node("Lights", "Node3D", ".")
    li = 0
    for c, a in sorted(areas.items()):
        k = a["kind"]
        lc, le = KINDS[k][1], KINDS[k][2]
        seen = set()
        for r in a["rects"]:
            for gx in range(r[0] + 4, r[2] - 1, 8):
                for gz in range(r[1] + 4, r[3] - 1, 8):
                    if (gx, gz) in seen or (gx, gz) not in walk:
                        continue
                    seen.add((gx, gz))
                    li += 1
                    # Пятна света в залах: ярче, между ними — полутьма (без теней: кроны деревьев давали чёрные пятна).
                    props = {"transform": tr((gx, 2.7, gz)), "light_color": col(lc), "light_energy": le * ROOM_LIGHT_MUL,
                             "omni_range": 11, "omni_attenuation": 1.3,
                             "distance_fade_enabled": "true", "distance_fade_begin": 40.0, "distance_fade_length": 10.0}
                    roll = rng.random()
                    if k not in ("start", "exit") and roll < 0.1:
                        props["script"] = f'ExtResource("{R["flicker_s"]}")'
                    sc.node(f"Light{li}", "OmniLight3D", "Lights", props)
    for ci in corridor_info:
        r = ci["rect"]
        length = max(r[2] - r[0], r[3] - r[1])
        steps = max(1, round(length / 5.5))
        for j in range(steps):
            t = (j + 0.5) / steps
            if ci["axis"] == "x":
                pos = (r[0] + (r[2] - r[0]) * t, 2.4, (r[1] + r[3]) / 2)
            else:
                pos = ((r[0] + r[2]) / 2, 2.4, r[1] + (r[3] - r[1]) * t)
            li += 1
            # Главный путь — тёплый ровный свет, ответвления — холодный и тусклее.
            color, energy = ((1.0, 0.75, 0.45), 3.6) if ci["main"] else ((0.5, 0.8, 0.9), 2.8)
            sc.node(f"Light{li}", "OmniLight3D", "Lights", {
                "transform": tr(pos), "light_color": col(color), "light_energy": energy, "omni_range": 9})

    # --- Враги ---
    sc.node("Enemies", "Node3D", ".")
    ei = 0
    xp_weight = 0.0
    kind_xp = {"leaper": 9, "crawler": 6, "spitter": 10, "brute": 45 + 18, "robot_walker": 14, "robot_drone": 12, "robot_heavy": 50}
    rarity_xp = [1, 2, 5]
    MAX_RARES = 5
    rares = 0

    def spawn(kind, x, z, rarity=0, guard=False):
        nonlocal ei, xp_weight, rares
        if rarity == 2:
            if rares >= MAX_RARES and not guard:
                rarity = 1
            else:
                rares += 1
        ei += 1
        props = {"transform": tr((round(x, 2), 0.1, round(z, 2)), rng.randrange(360))}
        if rarity:
            props["rarity"] = rarity
        if guard:
            props["guards_exit"] = "true"
        sc.node(f"{kind.title().replace('_', '')}{ei}", None, "Enemies", props, instance=R[kind])
        xp_weight += kind_xp[kind] * rarity_xp[rarity]

    def pack(px, pz, robots, strong=False, guard=False):
        if robots:
            # Тяжёлый робот — с 3-го этажа (на 2-м изредка): на первых этажах он слишком крепкий.
            heavy = rng.choice([1, 1, 2]) if level >= 3 else (1 if level == 2 and rng.random() < 0.3 else 0)
            members = ["robot_heavy"] * heavy + ["robot_walker"] * rng.randint(2, 3) \
                + ["robot_drone"] * rng.randint(1, 2)
        else:
            members = ["brute"] + ["crawler"] * rng.randint(3, 5) + ["leaper"] * rng.choice([0, 1, 1, 2]) \
                + ["spitter"] * rng.choice([0, 1, 1, 2])
        # Первые этажи — стаи меньше (и без Носителя у половины): игрок знакомится с врагами.
        dens = PACK_DENSITY.get(level, 1.0)
        if dens < 1.0:
            if members[0] == "brute" and rng.random() < 0.5:
                members = members[1:]
            # Вожак (первый) остаётся, остальных перемешиваем — иначе урезание отрезало бы плевунов в конце.
            rest = members[1:]
            rng.shuffle(rest)
            members = (members[:1] + rest)[:max(2, round(len(members) * dens))]
        roll = rng.random()
        magic = roll < 0.2
        leader = strong or roll > 0.9
        for i, kind in enumerate(members):
            for _try in range(12):
                ex, ez = px + rng.uniform(-2.5, 2.5), pz + rng.uniform(-2.5, 2.5)
                if (int(ex), int(ez)) in walk:
                    break
            else:
                ex, ez = px, pz
            spawn(kind, ex, ez, 2 if (leader and i == 0) else (1 if magic else 0), guard and i == 0)

    has_boss = level in (1, 3, 5)
    for c, a in sorted(areas.items()):
        k = a["kind"]
        if k in ("start", "exit"):
            continue
        m2 = sum((r[2] - r[0]) * (r[3] - r[1]) for r in a["rects"])
        packs = 1 + (1 if m2 > 230 and level >= 3 else 0)
        if k == "arena":
            continue
        for p in range(packs):
            x, z = (a["center"] if p == 0 else free_spot(c, 2.5, 0.5))
            # Сады — заражённые люди; роботы-охранники — в лабораториях и складах (на 1-м этаже реже).
            robots = rng.random() < (0.6 if k in ("lab", "storage") else 0.35) * (0.5 if level == 1 else 1.0)
            pack(x, z, robots, strong=(c == key_area))
    # Мелкие засады в длинных коридорах.
    for ci in corridor_info:
        r = ci["rect"]
        if max(r[2] - r[0], r[3] - r[1]) >= 9 and rng.random() < 0.4 * PACK_DENSITY.get(level, 1.0):
            x, z = center_of(r)
            for _ in range(rng.randint(2, 3)):
                spawn(rng.choice(["crawler", "crawler", "leaper"]), x + rng.uniform(-1, 1), z + rng.uniform(-1, 1))
    # Арена перед лифтом: босс (этажи 1, 3, 5) или жёлтый вожак со стаей.
    ax, az = areas[arena]["center"]
    if has_boss:
        boss_kind, boss_title = {1: ("boss_foreman", ""), 3: ("boss_sentinel", ""),
                                 5: ("boss_doctor", "Садовница Эдема")}[level]
        props = {"transform": tr((round(ax, 2), 0.1, round(az, 2)), 0)}
        if boss_title:
            props["boss_title"] = f'"{boss_title}"'
        sc.node("Boss", None, "Enemies", props, instance=R[boss_kind])
    else:
        pack(ax, az, rng.random() < 0.5, strong=True, guard=True)
    occupied.append((ax, az))

    # --- Сундуки (задание «Откройте сундуки»: на этаже 6–8 сундуков, нужно 4) ---
    sc.node("Chests", "Node3D", ".")
    chi = 0

    def chest(x, z, rarity, face=None):
        nonlocal chi
        chi += 1
        fx, fz = face if face else (x, z + 1)
        yaw = math.degrees(math.atan2(fx - x, fz - z))
        sc.node(f"Chest{chi}", "Node3D", "Chests", {
            "transform": tr((round(x, 2), 0, round(z, 2)), round(yaw, 1)),
            "script": f'ExtResource("{R["chest_s"]}")', "rarity": rarity})

    # В тупиках (кроме лифта и ключа) — сундук получше: награда за то, что свернул с пути.
    dead_ends = [c for c in leaves if c not in (exit_area, key_area)]
    for c in dead_ends:
        x, z = take(*free_spot(c, 2.5))
        chest(x, z, rng.choices([1, 2], [60, 40])[0], face=areas[c]["center"])
    rooms = [c for c in cells if areas[c]["kind"] not in ("start", "exit") and c not in dead_ends]
    rng.shuffle(rooms)
    for c in rooms[:max(0, 7 - chi)]:
        x, z = take(*free_spot(c, 2.5))
        chest(x, z, rng.choices([0, 1, 2], [60, 30, 10])[0], face=areas[c]["center"])

    # --- Задания этажа ---
    sc.node("Quests", "Node3D", ".")
    side = [c for c in cells if c not in main_path and areas[c]["kind"] not in ("start", "exit", "key")]
    rng.shuffle(side)
    picks = side + [c for c in cells if c in main_path and areas[c]["kind"] not in ("start", "exit", "arena")]
    used = set()

    def pick_rooms(count, avoid_used=True):
        out = []
        for c in picks:
            if len(out) >= count:
                break
            if avoid_used and c in used:
                continue
            out.append(c)
            used.add(c)
        return out

    qi = 0
    for quest in QUESTS[level]:
        if quest == "allies":
            # Три робота: один — танк ближнего боя (провоцирует врагов), двое — стрелки.
            for j, c in enumerate(pick_rooms(1 if level <= 2 else 3)):
                x, z = take(*free_spot(c, 2.5, 2.5))
                qi += 1
                props = {"transform": tr((round(x, 2), 0.1, round(z, 2)), rng.randrange(360)),
                         "script": f'ExtResource("{R["ally_s"]}")'}
                if j == 0:
                    props["melee"] = "true"
                sc.node(f"Ally{qi}", "CharacterBody3D", "Quests", props)
        elif quest == "escort":
            # Персонал прячется в разных комнатах — каждого нужно довести до лифта.
            count = 4 if level == 1 else 2
            staff = [
                ("Биолог", "В лаборатории остались данные о растениях. Помогите мне добраться до лифта.",
                 "Я передал вам записи о заражении. Теперь можно уходить.", (0.30, 0.60, 0.66)),
                ("Инженер", "Я знаю аварийный маршрут. Доведите меня до лифта — покажу короткий путь.",
                 "Маршрут отмечен. Спасибо, что не бросили меня.", (0.68, 0.48, 0.28)),
                ("Медик", "Мои пациенты эвакуированы, но я отстал. Пожалуйста, к лифту.",
                 "Аптечка и данные — ваша. Удачи внизу.", (0.58, 0.34, 0.38)),
                ("Архивист", "Я сохранил копию протокола. Отведите меня к лифту, и она ваша.",
                 "Протокол у вас. Не дайте Улью добраться до комплекса.", (0.38, 0.48, 0.62)),
            ]
            for i, c in enumerate(pick_rooms(count)):
                x, z = take(*free_spot(c, 2.0, 2.0))
                qi += 1
                name, dialogue, thanks, color = staff[i % len(staff)]
                sc.node(f"Scientist{qi}", "CharacterBody3D", "Quests", {
                    "transform": tr((round(x, 2), 0.1, round(z, 2)), rng.randrange(360)),
                    "script": f'ExtResource("{R["sci_s"]}")', "staff_name": f'"{name}"',
                    "rescue_dialogue": f'"{dialogue}"', "rescue_thanks": f'"{thanks}"',
                    "coat_color": col(color)})
        else:
            kind = "obelisk" if quest == "obelisks" else "nest"
            for c in pick_rooms(2):
                x, z = take(*free_spot(c, 3.0, 3.0))
                qi += 1
                sc.node(f"{kind.title()}{qi}", "StaticBody3D", "Quests", {
                    "transform": tr((round(x, 2), 0, round(z, 2))), "script": f'ExtResource("{R["destr_s"]}")',
                    "kind": f'"{kind}"'})
                # Обелиск охраняет стая, у инкубатора — пара ползунов.
                if kind == "obelisk":
                    pack(*free_spot(c, 2.5, 0.5), False)
    # Разлом (волны) — в большом зале не на главном пути.
    seal_room = max(pick_rooms(3) or [arena], key=lambda c: (areas[c]["main"][2] - areas[c]["main"][0]) *
                    (areas[c]["main"][3] - areas[c]["main"][1]))
    sx_, sz_ = areas[seal_room]["center"]
    if level > 2:
        sc.node("Seal", "Node3D", "Quests", {"transform": tr((round(sx_ + 0.5, 2), 0, round(sz_ + 0.5, 2))),
                                             "script": f'ExtResource("{R["seal_s"]}")'})

    # Засады (волны из вентиляций) в двух больших залах.
    sc.node("Spawners", "Node3D", ".")
    big = sorted((c for c in cells if areas[c]["kind"] not in ("start", "exit", "key", "arena") and c != seal_room),
                 key=lambda c: -(areas[c]["main"][2] - areas[c]["main"][0]) * (areas[c]["main"][3] - areas[c]["main"][1]))[:2]
    for i, c in enumerate(big):
        m = areas[c]["main"]
        x, z = areas[c]["center"]
        sc.node(f"Spawner{i + 1}", "Node3D", "Spawners", {
            "transform": tr((x, 0, z)), "script": f'ExtResource("{R["spawner_s"]}")',
            "enemy_scene": f'ExtResource("{R["crawler"]}")', "rare_scene": f'ExtResource("{R["spitter"]}")',
            "rare_chance": 0.2, "waves": "Array[int]([5, 7])", "trigger_size": vec((6.0, 2.0, 6.0))})
        for j, (vx, vz) in enumerate([(m[0] + 1.5, m[1] + 1.5), (m[2] - 1.5, m[1] + 1.5), (m[0] + 1.5, m[3] - 1.5),
                                      (m[2] - 1.5, m[3] - 1.5)]):
            if (int(vx), int(vz)) in walk:
                sc.node(f"Vent{j + 1}", "Marker3D", f"Spawners/Spawner{i + 1}", {"transform": tr((vx - x, 0, vz - z))})

    kx, kz = areas[key_area]["center"]
    sc.node("Keycard", "Area3D", ".", {"transform": tr((kx, 0.9, kz)), "script": f'ExtResource("{R["key_s"]}")',
                                        "key_id": '&"exit"', "key_name": '"Лифт"'})
    ex_, ez_ = areas[exit_area]["center"]
    sc.node("Exit", "Area3D", ".", {"transform": tr((ex_, 0, ez_)), "script": f'ExtResource("{R["exit_s"]}")'})
    s = areas[START]["main"]
    sx0, sz0 = areas[START]["center"]
    sc.node("SafeZone", "Area3D", ".", {"transform": tr((sx0, 0, sz0)), "script": f'ExtResource("{R["safe_s"]}")',
                                         "size": vec((float(s[2] - s[0] - 2), 3.0, float(s[3] - s[1] - 2)))})
    if level == 1:
        stash = [("currency", "blank_module")] * 3 + [("currency", "mutagen")] * 3 + [("currency", "unstable")] * 2 \
            + [("currency", "hive_core"), ("currency", "queen_heart"), ("currency", "catalyst"),
               ("gear", "vest"), ("gear", "sensor_helmet"), ("gear", "army_boots"),
               ("gear", "rifle"), ("gear", "shotgun"), ("currency", "socket_cutter")]
        sc.node("StartLoot", "Node3D", ".")
        for i, (kind, what) in enumerate(stash):
            x = s[0] + 2 + (i % 7) * ((s[2] - s[0] - 4) / 6)
            z = s[1] + 2 + (i // 7) * 1.8
            p = {"transform": tr((round(x, 2), 0, round(z, 2))), "script": f'ExtResource("{R["loot_s"]}")', "kind": f'&"{kind}"'}
            if kind == "currency":
                p["currency_id"] = f'&"{what}"'
            else:
                p["gear_base"] = f'&"{what}"'
            sc.node(f"Loot{i + 1}", "Area3D", "StartLoot", p)

    sc.node("Models", "Node3D", ".")
    batches.emit(sc, "Models", R["batch_s"])
    sc.node("Player", None, ".", {"transform": tr((sx0, 0, sz0 + 3))}, instance=R["player"])
    sc.node("CameraRig", "Node3D", ".", {"script": f'ExtResource("{R["camera_s"]}")', "target_path": 'NodePath("../Player")'})
    sc.node("Camera3D", "Camera3D", "CameraRig", {"current": "true", "fov": 50.0})
    sc.node("BulletPool", "Node3D", ".", {"script": f'ExtResource("{R["pool_s"]}")', "bullet_scene": f'ExtResource("{R["bullet"]}")'})
    text = sc.text().replace('[node name="BulletPool" type="Node3D" parent="."]',
                             '[node name="BulletPool" type="Node3D" parent="." groups=["bullet_pool"]]')
    # Опыт: полная зачистка этажа ≈ один уровень персонажа (как в PoE 2).
    xp_to_level = [2860, 4270, 4910, 5630, 5630]
    xp_scale = xp_to_level[min(level, len(xp_to_level) - 1)] * 0.7 / (xp_weight * (1 + 0.35 * level))
    text = text.replace('__XP_SCALE__', fmt(round(xp_scale, 3)))
    return text, {"chests": chi, "xp_scale": round(xp_scale, 3), "rooms": len(areas), "corridors": len(passages),
                  "walls": len(walls), "lights": li, "enemies": ei, "walkable_m2": len(walk), "exit": exit_area,
                  "key": key_area, "main_path": len(main_path), "quests": QUESTS[level]}


def main(root):
    os.makedirs(f"{root}/scenes/zones", exist_ok=True)
    for level, seed in SEEDS.items():
        text, info = build(level, seed)
        with open(f"{root}/scenes/zones/zone_{level}.tscn", "w", encoding="utf-8") as f:
            f.write(text)
        print(f"zone_{level}: {info}")


if __name__ == "__main__":
    main(sys.argv[1])
