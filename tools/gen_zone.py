"""Генератор большой зоны scenes/zone.tscn (этаж 1).
Запуск из папки проекта: python -I tools/gen_zone.py . [seed]

Комнаты раскладываются по сетке GX×GZ (часть клеток пустая), соединяются коридорами:
сначала дерево (все комнаты достижимы), потом лишние связи — петли. Старт — внизу, выход — в самом
дальнем тупике за запертой дверью, ключ-карта — в другом дальнем тупике (бэктрекинг).
Стены строятся по контуру всех проходимых прямоугольников. ВНИМАНИЕ: перезаписывает zone.tscn.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_facility import Scene, vec, col, fmt, tr, mat  # noqa: E402

WALL_H = 2.4
GX, GZ = 7, 6
CELL = 34
START = (3, 5)
ZONE_LEVEL = 1

THEMES = [  # (цвет пола, цвет света)
    ((0.15, 0.16, 0.19), (0.75, 0.82, 1.0)),
    ((0.14, 0.17, 0.16), (0.55, 1.0, 0.8)),
    ((0.17, 0.15, 0.13), (1.0, 0.65, 0.35)),
    ((0.16, 0.14, 0.17), (0.85, 0.55, 1.0)),
    ((0.13, 0.13, 0.14), (1.0, 0.35, 0.25)),
]


def cell_center(gx, gz):
    return ((gx - (GX - 1) / 2) * CELL, (gz - (GZ - 1)) * CELL)


def build_layout(rng):
    while True:
        cells = {(x, z) for x in range(GX) for z in range(GZ)}
        removable = [c for c in cells if c != START and c != (START[0], START[1] - 1)]
        for c in rng.sample(removable, 6):
            cells.discard(c)
        # Связность оставшихся клеток.
        seen, stack = {START}, [START]
        while stack:
            x, z = stack.pop()
            for n in ((x + 1, z), (x - 1, z), (x, z + 1), (x, z - 1)):
                if n in cells and n not in seen:
                    seen.add(n)
                    stack.append(n)
        if seen == cells:
            return cells


def neighbors(c, cells):
    x, z = c
    return [n for n in ((x + 1, z), (x - 1, z), (x, z + 1), (x, z - 1)) if n in cells]


def main(root, seed):
    rng = random.Random(seed)
    cells = build_layout(rng)

    # --- Комнаты ---
    rooms = {}
    for c in cells:
        cx, cz = cell_center(*c)
        if c == START:
            w, d = 14, 12
            jx = jz = 0
        else:
            w, d = rng.randrange(12, 25, 2), rng.randrange(12, 25, 2)
            jx, jz = rng.randint(-3, 3), rng.randint(-3, 3)
        x0 = int(round(cx + jx - w / 2))
        z0 = int(round(cz + jz - d / 2))
        rooms[c] = [x0, z0, x0 + w, z0 + d]

    # --- Дерево связей (случайный обход в глубину) + глубина от старта ---
    edges = set()
    depth = {START: 0}
    parent = {START: None}
    stack = [START]
    while stack:
        cur = stack[-1]
        options = [n for n in neighbors(cur, cells) if n not in depth]
        if not options:
            stack.pop()
            continue
        n = rng.choice(options)
        depth[n] = depth[cur] + 1
        parent[n] = cur
        edges.add(frozenset((cur, n)))
        stack.append(n)

    children = {c: [n for n in cells if parent.get(n) == c] for c in cells}
    leaves = [c for c in cells if not children[c] and c != START]
    leaves.sort(key=lambda c: depth[c], reverse=True)
    exit_cell = leaves[0]
    key_cell = next((c for c in leaves[1:] if abs(c[0] - exit_cell[0]) + abs(c[1] - exit_cell[1]) > 1), leaves[1])

    # Петли: лишние связи, но не в старт и не в выход (у выхода один вход — через красную дверь).
    for c in cells:
        for n in neighbors(c, cells):
            e = frozenset((c, n))
            if e in edges or START in e or exit_cell in e:
                continue
            if rng.random() < 0.3:
                edges.add(e)

    # --- Коридоры ---
    rects = []  # все проходимые прямоугольники
    room_rects = {c: tuple(r) for c, r in rooms.items()}
    corridors = []  # (rect, центр двери, поворот, ребро)
    for e in edges:
        a, b = sorted(e)
        ra, rb = rooms[a], rooms[b]
        if a[1] == b[1]:  # соседи по горизонтали: a левее
            lo = max(ra[1], rb[1]) + 2
            hi = min(ra[3], rb[3]) - 2
            zc = (lo + hi) // 2
            rect = (ra[2], zc - 2, rb[0], zc + 2)
            door = ((rect[0] + rect[2]) / 2, zc, 90)
        else:  # по вертикали: a выше (меньше z)
            lo = max(ra[0], rb[0]) + 2
            hi = min(ra[2], rb[2]) - 2
            xc = (lo + hi) // 2
            rect = (xc - 2, ra[3], xc + 2, rb[1])
            door = (xc, (rect[1] + rect[3]) / 2, 0)
        corridors.append((rect, door, e))

    for c, r in room_rects.items():
        rects.append(r)
    for rect, _, _ in corridors:
        rects.append(rect)

    # --- Стены по контуру ---
    def walkable(cx, cz):
        x, z = cx + 0.5, cz + 0.5
        return any(r[0] <= x < r[2] and r[1] <= z < r[3] for r in rects)

    xs = [r[0] for r in rects] + [r[2] for r in rects]
    zs = [r[1] for r in rects] + [r[3] for r in rects]
    bx0, bx1, bz0, bz1 = min(xs) - 1, max(xs) + 1, min(zs) - 1, max(zs) + 1
    walk = {(cx, cz) for cz in range(bz0, bz1) for cx in range(bx0, bx1) if walkable(cx, cz)}
    wall_cells = set()
    for cz in range(bz0, bz1):
        for cx in range(bx0, bx1):
            if (cx, cz) in walk:
                continue
            if any((cx + dx, cz + dz) in walk for dx in (-1, 0, 1) for dz in (-1, 0, 1)):
                wall_cells.add((cx, cz))
    runs = []
    for cz in range(bz0, bz1):
        cx = bx0
        while cx < bx1:
            if (cx, cz) in wall_cells:
                s = cx
                while (cx, cz) in wall_cells:
                    cx += 1
                runs.append([s, cz, cx, cz + 1])
            else:
                cx += 1
    walls = []
    open_by_key = {}
    for r in runs:
        key = (r[0], r[2], r[1])
        m = open_by_key.pop(key, None)
        if m is not None:
            m[3] = r[3]
            open_by_key[(m[0], m[2], m[3])] = m
        else:
            walls.append(r)
            open_by_key[(r[0], r[2], r[3])] = r

    # --- Сцена ---
    sc = Scene()
    r_script = sc.ext_res("Script", "res://scripts/zone.gd")
    r_player = sc.ext_res("PackedScene", "res://scenes/player.tscn")
    r_camera = sc.ext_res("Script", "res://scripts/camera_rig.gd")
    r_pool = sc.ext_res("Script", "res://scripts/bullet_pool.gd")
    r_bullet = sc.ext_res("PackedScene", "res://scenes/bullet.tscn")
    r_crawler = sc.ext_res("PackedScene", "res://scenes/crawler.tscn")
    r_brute = sc.ext_res("PackedScene", "res://scenes/brute.tscn")
    r_spitter = sc.ext_res("PackedScene", "res://scenes/spitter.tscn")
    r_door = sc.ext_res("Script", "res://scripts/door.gd")
    r_spawner = sc.ext_res("Script", "res://scripts/enemy_spawner.gd")
    r_key = sc.ext_res("Script", "res://scripts/keycard.gd")
    r_exit = sc.ext_res("Script", "res://scripts/level_exit.gd")
    r_safe = sc.ext_res("Script", "res://scripts/safe_zone.gd")
    r_loot = sc.ext_res("Script", "res://scripts/loot_pickup.gd")

    env = sc.sub_res("Environment", {
        "background_mode": 1, "background_color": col((0.01, 0.01, 0.015)),
        "ambient_light_source": 2, "ambient_light_color": col((0.4, 0.45, 0.55)), "ambient_light_energy": 0.25,
        "tonemap_mode": 2, "glow_enabled": "true",
        "fog_enabled": "true", "fog_light_color": col((0.05, 0.06, 0.08)), "fog_density": 0.01,
    })
    navmesh = sc.sub_res("NavigationMesh", {
        "geometry_parsed_geometry_type": 1, "geometry_collision_mask": 1,
        "cell_size": 0.25, "cell_height": 0.25, "agent_height": 1.0, "agent_radius": 0.5, "agent_max_climb": 0.25,
    })
    m_wall = mat(sc, (0.22, 0.23, 0.26), 0.3, 0.8)
    m_wall_top = mat(sc, (0.45, 0.47, 0.5), 0.6, 0.5)
    m_crate = mat(sc, (0.38, 0.27, 0.12), 0.4, 0.6)
    m_pillar = mat(sc, (0.3, 0.31, 0.34), 0.5, 0.6)
    m_corridor = mat(sc, (0.11, 0.11, 0.12), 0.5, 0.75)
    m_floors = [mat(sc, t[0], 0.5, 0.75) for t in THEMES]

    map_rects = [f"Rect2({r[0]}, {r[1]}, {r[2] - r[0]}, {r[3] - r[1]})" for r in rects]
    ex = room_center(rooms[exit_cell])
    sc.node("Zone", "Node3D", None, {
        "script": f'ExtResource("{r_script}")',
        "map_rects": "Array[Rect2]([%s])" % ", ".join(map_rects),
        "exit_position": "Vector2(%s, %s)" % (fmt(float(ex[0])), fmt(float(ex[1]))),
    })
    sc.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})
    sc.node("MoonLight", "DirectionalLight3D", ".", {
        "transform": "Transform3D(0.819, -0.471, 0.328, 0, 0.571, 0.821, -0.574, -0.672, 0.468, 0, 10, 0)",
        "light_color": col((0.6, 0.7, 0.9)), "light_energy": 0.3, "shadow_enabled": "true"})

    sc.node("Navigation", "NavigationRegion3D", ".", {"navigation_mesh": f'SubResource("{navmesh}")'})
    sc.node("Geometry", "Node3D", "Navigation")
    g = "Navigation/Geometry"
    room_theme = {c: rng.randrange(len(THEMES)) for c in cells}
    room_theme[START] = 0
    for i, (c, r) in enumerate(sorted(room_rects.items())):
        size = (float(r[2] - r[0]), 0.5, float(r[3] - r[1]))
        sc.static_box(f"Floor{i + 1}", g, ((r[0] + r[2]) / 2, -0.25, (r[1] + r[3]) / 2), size, m_floors[room_theme[c]])
    for i, (rect, _, _) in enumerate(corridors):
        size = (float(rect[2] - rect[0]), 0.5, float(rect[3] - rect[1]))
        sc.static_box(f"CorridorFloor{i + 1}", g, ((rect[0] + rect[2]) / 2, -0.24, (rect[1] + rect[3]) / 2), size, m_corridor)
    for i, (x0, z0, x1, z1) in enumerate(walls):
        size = (float(x1 - x0), WALL_H, float(z1 - z0))
        sc.static_box(f"Wall{i + 1}", g, ((x0 + x1) / 2, WALL_H / 2, (z0 + z1) / 2), size, m_wall)
        sc.node("Top", "MeshInstance3D", f"{g}/Wall{i + 1}", {
            "transform": tr((0, WALL_H / 2 + 0.02, 0)),
            "mesh": f'SubResource("{sc.box_mesh((size[0], 0.04, size[2]), m_wall_top)}")'})

    # Ящики и колонны внутри комнат (не ближе 3 м к стенам — проходы не перекрываются).
    prop_i = 0
    for c, r in sorted(room_rects.items()):
        if c == START:
            continue
        area = (r[2] - r[0]) * (r[3] - r[1])
        placed = []
        for _ in range(int(area / 70)):
            for _try in range(12):
                big = rng.random() < 0.25 and area > 300
                sx = 2.0 if big else rng.choice([1.2, 1.4, 1.8, 2.4])
                sz = 2.0 if big else rng.choice([1.2, 1.4, 1.8])
                h = 2.4 if big else rng.choice([1.0, 1.2, 1.4])
                x = rng.uniform(r[0] + 3 + sx / 2, r[2] - 3 - sx / 2)
                z = rng.uniform(r[1] + 3 + sz / 2, r[3] - 3 - sz / 2)
                if all(abs(x - px) > 3 or abs(z - pz) > 3 for px, pz in placed):
                    placed.append((x, z))
                    prop_i += 1
                    sc.static_box(f"Prop{prop_i}", g, (round(x, 2), h / 2, round(z, 2)), (sx, h, sz),
                                  m_pillar if big else m_crate)
                    break

    # --- Двери ---
    sc.node("Doors", "Node3D", ".")
    for i, (rect, (dx, dz, rot), e) in enumerate(corridors):
        props = None
        if START in e:
            props = {"enemies_can_open": "false"}
        elif exit_cell in e:
            props = {"locked": "true", "key_id": '&"exit"', "key_name": '"Лифт"'}
        elif rng.random() < 0.4:
            props = {}
        if props is None:
            continue
        p = {"transform": tr((dx, 0, dz), rot), "script": f'ExtResource("{r_door}")', "height": WALL_H}
        p.update(props)
        sc.node(f"Door{i + 1}", "Node3D", "Doors", p)

    # --- Свет ---
    sc.node("Lights", "Node3D", ".")
    li = 0
    for c, r in sorted(room_rects.items()):
        w, d = r[2] - r[0], r[3] - r[1]
        nx, nz = max(1, round(w / 13)), max(1, round(d / 13))
        for ix in range(nx):
            for iz in range(nz):
                li += 1
                x = r[0] + w * (ix + 0.5) / nx
                z = r[1] + d * (iz + 0.5) / nz
                sc.node(f"Light{li}", "OmniLight3D", "Lights", {
                    "transform": tr((x, 2.2, z)), "light_color": col(THEMES[room_theme[c]][1]),
                    "light_energy": 1.8, "omni_range": 10})
    for rect, _, _ in corridors:
        length = max(rect[2] - rect[0], rect[3] - rect[1])
        if length < 6:
            continue
        li += 1
        sc.node(f"Light{li}", "OmniLight3D", "Lights", {
            "transform": tr(((rect[0] + rect[2]) / 2, 2.2, (rect[1] + rect[3]) / 2)),
            "light_color": col((1.0, 0.22, 0.15)), "light_energy": 1.6, "omni_range": 7})

    # --- Враги ---
    sc.node("Enemies", "Node3D", ".")
    ei = 0
    room_list = sorted(room_rects.items())
    big_rooms = sorted((c for c in cells if c not in (START, exit_cell, key_cell)),
                       key=lambda c: -(rooms[c][2] - rooms[c][0]) * (rooms[c][3] - rooms[c][1]))[:5]
    for c, r in room_list:
        if c == START:
            continue
        area = (r[2] - r[0]) * (r[3] - r[1])
        count = int(area * 0.038) + rng.randint(0, 3)
        if depth[c] == 1:
            count = count // 2
        kinds = []
        if area > 280 and rng.random() < 0.5 or c in (exit_cell, key_cell):
            kinds.append(r_brute)
        for _ in range(count):
            kinds.append(r_spitter if rng.random() < 0.18 else r_crawler)
        for res in kinds:
            ei += 1
            x = rng.uniform(r[0] + 2, r[2] - 2)
            z = rng.uniform(r[1] + 2, r[3] - 2)
            name = {r_brute: "Brute", r_spitter: "Spitter", r_crawler: "Crawler"}[res]
            sc.node(f"{name}{ei}", None, "Enemies", {"transform": tr((round(x, 2), 0.1, round(z, 2)), rng.randrange(360)),
                                                      "level": ZONE_LEVEL}, instance=res)

    # --- Засады-волны в больших комнатах ---
    sc.node("Spawners", "Node3D", ".")
    for i, c in enumerate(big_rooms):
        r = rooms[c]
        x, z = room_center(r)
        name = f"Spawner{i + 1}"
        sc.node(name, "Node3D", "Spawners", {
            "transform": tr((x, 0, z)), "script": f'ExtResource("{r_spawner}")',
            "enemy_scene": f'ExtResource("{r_crawler}")', "rare_scene": f'ExtResource("{r_spitter}")',
            "rare_chance": 0.2, "waves": "Array[int]([4, 6])",
            "trigger_size": vec((6.0, 2.0, 6.0))})
        corners = [(r[0] + 1.5, r[1] + 1.5), (r[2] - 1.5, r[1] + 1.5), (r[0] + 1.5, r[3] - 1.5), (r[2] - 1.5, r[3] - 1.5)]
        for j, (vx, vz) in enumerate(corners):
            sc.node(f"Vent{j + 1}", "Marker3D", f"Spawners/{name}", {"transform": tr((vx - x, 0, vz - z))})

    # --- Ключ, выход, старт ---
    kx, kz = room_center(rooms[key_cell])
    sc.node("Keycard", "Area3D", ".", {"transform": tr((kx, 0.9, kz)), "script": f'ExtResource("{r_key}")',
                                        "key_id": '&"exit"', "key_name": '"Лифт"'})
    sc.node("Exit", "Area3D", ".", {"transform": tr((ex[0], 0, ex[1])), "script": f'ExtResource("{r_exit}")'})
    s = rooms[START]
    sx, sz = room_center(s)
    sc.node("SafeZone", "Area3D", ".", {"transform": tr((sx, 0, sz)), "script": f'ExtResource("{r_safe}")',
                                         "size": vec((float(s[2] - s[0]), 3.0, float(s[3] - s[1])))})
    # Стартовый запас для проверки крафта.
    stash = [("currency", "blank_module")] * 3 + [("currency", "mutagen")] * 3 + [("currency", "unstable")] * 2 \
        + [("currency", "hive_core"), ("currency", "hive_core"), ("currency", "queen_heart"), ("currency", "queen_heart"),
           ("currency", "catalyst"),
           ("gear", "vest"), ("gear", "sensor_helmet"), ("gear", "army_boots")]
    sc.node("StartLoot", "Node3D", ".")
    for i, (kind, what) in enumerate(stash):
        x = s[0] + 2 + (i % 7) * ((s[2] - s[0] - 4) / 6)
        z = s[1] + 2.5 + (i // 7) * 2.2
        p = {"transform": tr((round(x, 2), 0, z)), "script": f'ExtResource("{r_loot}")', "kind": f'&"{kind}"'}
        if kind == "currency":
            p["currency_id"] = f'&"{what}"'
        else:
            p["gear_base"] = f'&"{what}"'
            p["gear_level"] = ZONE_LEVEL
        sc.node(f"Loot{i + 1}", "Area3D", "StartLoot", p)

    sc.node("Player", None, ".", {"transform": tr((sx, 0, sz + 2))}, instance=r_player)
    sc.node("CameraRig", "Node3D", ".", {"script": f'ExtResource("{r_camera}")', "target_path": 'NodePath("../Player")'})
    sc.node("Camera3D", "Camera3D", "CameraRig", {"current": "true", "fov": 50.0})
    sc.node("BulletPool", "Node3D", ".", {"script": f'ExtResource("{r_pool}")', "bullet_scene": f'ExtResource("{r_bullet}")'})
    text = sc.text().replace('[node name="BulletPool" type="Node3D" parent="."]',
                             '[node name="BulletPool" type="Node3D" parent="." groups=["bullet_pool"]]')
    with open(f"{root}/scenes/zone.tscn", "w", encoding="utf-8") as f:
        f.write(text)
    walk_area = len(walk)
    print(f"seed={seed} rooms={len(rooms)} corridors={len(corridors)} walls={len(walls)} lights={li} "
          f"enemies={ei} walkable_m2={walk_area} exit={exit_cell} key={key_cell}")


def room_center(r):
    return ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2)


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 7)
