"""Генератор тестового уровня scenes/facility.tscn. Запуск: python -I gen_facility.py <путь к проекту>"""
import sys

WALL_H = 2.4

# Проходимые прямоугольники: (x0, z0, x1, z1, цвет пола). Ось Z: «вверх» на экране = −Z.
ROOMS = [
    (-6, 0, 6, 10, (0.15, 0.16, 0.19)),        # A. Старт
    (-2, -12, 2, 0, (0.12, 0.12, 0.13)),       # C1. Коридор
    (-14, -36, 14, -12, (0.16, 0.16, 0.18)),   # B. Зал
    (-26, -30, -15, -18, (0.13, 0.15, 0.19)),  # E. Оружейная (за красной дверью)
    (-15, -26, -14, -22, (0.12, 0.12, 0.13)),  # проём в стене между залом и Оружейной
    (14, -26, 30, -22, (0.12, 0.12, 0.13)),    # C2. Восточный коридор
    (30, -32, 44, -16, (0.17, 0.15, 0.13)),    # F. Склад
]

# Двери: (x, z, поворот°, заперта, key_id, название ключа)
DOORS = [
    (0, -0.5, 0, False, "", "", False),  # дверь безопасной комнаты: враги её не открывают
    (0, -11.5, 0, False, "", ""),
    (-14.5, -24, 90, True, "armory", "Оружейная"),
    (14.5, -24, 90, False, "", ""),
    (29.5, -24, 90, False, "", ""),
]

# Ящики и колонны: (x, z, sx, sz, высота, тип)
PROPS = [
    (-4, 6, 1.4, 1.4, 1.2, "crate"), (4.5, 2, 1.2, 2.4, 1.0, "crate"),
    (-8, -20, 2, 2, 2.4, "pillar"), (8, -20, 2, 2, 2.4, "pillar"),
    (-8, -30, 2, 2, 2.4, "pillar"), (8, -30, 2, 2, 2.4, "pillar"),
    (-2, -25, 1.4, 1.4, 1.1, "crate"), (0.2, -26, 1.2, 1.2, 1.1, "crate"),
    (11, -14.5, 2.5, 1.2, 1.2, "crate"), (-11.5, -34, 2, 2, 1.3, "crate"),
    (33, -19, 2.5, 1.5, 1.4, "crate"), (36, -29, 1.5, 3, 1.4, "crate"),
    (39, -20, 1.4, 1.4, 1.2, "crate"), (34, -24.5, 1.2, 1.2, 1.1, "crate"),
    (-24, -20, 1.6, 1.6, 1.3, "crate"), (-24, -28, 1.6, 1.6, 1.3, "crate"),
]

# Спящие враги. Тип по умолчанию — ползун; (x, z, "brute") / (x, z, "spitter") — другие.
CRAWLERS = [
    (0, -30, "brute"), (-10, -34, "spitter"), (10, -34, "spitter"),
    (37, -24, "brute"), (42, -30, "spitter"), (-24, -24, "spitter"),
    (-1, -6), (1, -9),
    (-10, -26), (10, -27), (-4, -33), (5, -16),
    (20, -24), (25, -23), (27, -25),
    (35, -21), (40, -27), (38, -17), (32, -30), (42, -22), (37, -24),
    (-18, -22), (-20, -27), (-17, -25),
]

# Волны: (x, z, триггер (sx, sz), смещение триггера (dx, dz), волны, точки вентиляций)
SPAWNERS = [
    (0, -14, (8, 3), (0, 0), [4, 6, 8], [(-12, -34), (12, -34), (0, -35), (-13, -16), (13, -30)]),
    (41, -24, (4, 4), (0, 0), [6, 8], [(43, -31), (43, -17), (31, -31), (31, -17)]),
]

KEYCARD = (41, -24, "armory", "Оружейная")
# Безопасная комната (центр x, z, размер x, z) и модули, лежащие в ней.
SAFE_ZONE = (0, 5, 12, 10)
START_MODULES = [(-4.5, 2.5, "pierce"), (-1.5, 2.5, "fire"), (1.5, 2.5, "fast_reload"), (4.5, 2.5, "leech")]
EXIT = (-22, -24)
PLAYER = (0, 6)

# Свет: (x, z, цвет, энергия, радиус)
LIGHTS = [
    (0, 5, (0.6, 0.75, 1.0), 2.0, 9),
    (0, -6, (1.0, 0.2, 0.15), 2.5, 7),
    (-8, -16, (0.9, 0.85, 0.7), 2.0, 10), (8, -16, (0.9, 0.85, 0.7), 2.0, 10),
    (-8, -33, (0.9, 0.85, 0.7), 2.0, 10), (8, -33, (0.9, 0.85, 0.7), 2.0, 10),
    (0, -25, (1.0, 0.3, 0.2), 1.5, 8),
    (22, -24, (1.0, 0.2, 0.15), 2.5, 7),
    (34, -20, (1.0, 0.6, 0.3), 2.2, 10), (40, -28, (1.0, 0.6, 0.3), 2.2, 10),
    (-20, -24, (0.4, 0.6, 1.0), 2.0, 10),
]


def walkable(cx, cz):
    x, z = cx + 0.5, cz + 0.5
    return any(r[0] <= x < r[2] and r[1] <= z < r[3] for r in ROOMS)


def wall_rects():
    xs = [r[0] for r in ROOMS] + [r[2] for r in ROOMS]
    zs = [r[1] for r in ROOMS] + [r[3] for r in ROOMS]
    x0, x1, z0, z1 = min(xs) - 1, max(xs) + 1, min(zs) - 1, max(zs) + 1
    cells = set()
    for cz in range(z0, z1):
        for cx in range(x0, x1):
            if walkable(cx, cz):
                continue
            if any(walkable(cx + dx, cz + dz) for dx in (-1, 0, 1) for dz in (-1, 0, 1)):
                cells.add((cx, cz))
    # Склеиваем клетки в полосы по строкам, потом одинаковые полосы — по столбцам.
    runs = []
    for cz in range(z0, z1):
        cx = x0
        while cx < x1:
            if (cx, cz) in cells:
                start = cx
                while (cx, cz) in cells:
                    cx += 1
                runs.append([start, cz, cx, cz + 1])
            else:
                cx += 1
    merged = []
    for r in runs:
        for m in merged:
            if m[0] == r[0] and m[2] == r[2] and m[3] == r[1]:
                m[3] = r[3]
                break
        else:
            merged.append(r)
    return merged


class Scene:
    def __init__(self):
        self.ext = []
        self.sub = []
        self.nodes = []
        self._shapes = {}
        self._meshes = {}

    def ext_res(self, kind, path):
        rid = f"{len(self.ext) + 1}_r"
        self.ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
        return rid

    def sub_res(self, kind, props):
        rid = f"{kind}_{len(self.sub) + 1}"
        body = "\n".join(f"{k} = {v}" for k, v in props.items())
        self.sub.append(f'[sub_resource type="{kind}" id="{rid}"]\n{body}')
        return rid

    def box_shape(self, size):
        if size not in self._shapes:
            self._shapes[size] = self.sub_res("BoxShape3D", {"size": vec(size)})
        return self._shapes[size]

    def box_mesh(self, size, mat):
        key = (size, mat)
        if key not in self._meshes:
            self._meshes[key] = self.sub_res("BoxMesh", {"material": f'SubResource("{mat}")', "size": vec(size)})
        return self._meshes[key]

    def node(self, name, kind, parent, props=None, instance=None):
        head = f'[node name="{name}"'
        if kind:
            head += f' type="{kind}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance:
            head += f' instance=ExtResource("{instance}")'
        head += "]"
        body = "\n".join(f"{k} = {v}" for k, v in (props or {}).items())
        self.nodes.append(head + ("\n" + body if body else ""))

    def static_box(self, name, parent, pos, size, mat):
        self.node(name, "StaticBody3D", parent, {"transform": tr(pos)})
        self.node("Shape", "CollisionShape3D", f"{parent}/{name}", {"shape": f'SubResource("{self.box_shape(size)}")'})
        self.node("Mesh", "MeshInstance3D", f"{parent}/{name}", {"mesh": f'SubResource("{self.box_mesh(size, mat)}")'})

    def text(self):
        return (f"[gd_scene format=3]\n\n" + "\n".join(self.ext) + "\n\n" + "\n\n".join(self.sub) + "\n\n"
                + "\n\n".join(self.nodes) + "\n")


def vec(v):
    return "Vector3(%s)" % ", ".join(fmt(x) for x in v)


def col(c, a=1.0):
    return "Color(%s)" % ", ".join(fmt(x) for x in (*c, a))


def fmt(x):
    return ("%.3f" % x).rstrip("0").rstrip(".") if isinstance(x, float) else str(x)


def tr(pos, rot_y=0):
    import math
    c, s = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    c, s = round(c, 6), round(s, 6)
    return "Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s)" % (fmt(c), fmt(s), fmt(-s), fmt(c), ", ".join(fmt(float(p)) for p in pos))


def mat(scene, color, metallic, roughness, emission=None):
    props = {"albedo_color": col(color), "metallic": metallic, "roughness": roughness}
    if emission:
        props.update({"emission_enabled": "true", "emission": col(emission[0]), "emission_energy_multiplier": emission[1]})
    return scene.sub_res("StandardMaterial3D", props)


def main(root):
    sc = Scene()
    r_script = sc.ext_res("Script", "res://scripts/facility.gd")
    r_player = sc.ext_res("PackedScene", "res://scenes/player.tscn")
    r_camera = sc.ext_res("Script", "res://scripts/camera_rig.gd")
    r_pool = sc.ext_res("Script", "res://scripts/bullet_pool.gd")
    r_bullet = sc.ext_res("PackedScene", "res://scenes/bullet.tscn")
    r_crawler = sc.ext_res("PackedScene", "res://scenes/crawler.tscn")
    r_brute = sc.ext_res("PackedScene", "res://scenes/brute.tscn")
    r_spitter = sc.ext_res("PackedScene", "res://scenes/spitter.tscn")
    r_safe = sc.ext_res("Script", "res://scripts/safe_zone.gd")
    r_pickup = sc.ext_res("Script", "res://scripts/loot_pickup.gd")
    r_mods = {m: sc.ext_res("Resource", f"res://data/modules/{m}.tres") for _, _, m in START_MODULES}
    r_door = sc.ext_res("Script", "res://scripts/door.gd")
    r_spawner = sc.ext_res("Script", "res://scripts/enemy_spawner.gd")
    r_key = sc.ext_res("Script", "res://scripts/keycard.gd")
    r_exit = sc.ext_res("Script", "res://scripts/level_exit.gd")

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
    m_crate = mat(sc, (0.38, 0.27, 0.12), 0.4, 0.6)
    m_pillar = mat(sc, (0.3, 0.31, 0.34), 0.5, 0.6)
    m_wall_top = mat(sc, (0.45, 0.47, 0.5), 0.6, 0.5)

    sc.node("Facility", "Node3D", None, {"script": f'ExtResource("{r_script}")'})
    sc.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})
    sc.node("MoonLight", "DirectionalLight3D", ".", {
        "transform": "Transform3D(0.819, -0.471, 0.328, 0, 0.571, 0.821, -0.574, -0.672, 0.468, 0, 10, 0)",
        "light_color": col((0.6, 0.7, 0.9)), "light_energy": 0.3, "shadow_enabled": "true"})

    sc.node("Navigation", "NavigationRegion3D", ".", {"navigation_mesh": f'SubResource("{navmesh}")'})
    sc.node("Geometry", "Node3D", "Navigation")
    g = "Navigation/Geometry"
    for i, (x0, z0, x1, z1, color) in enumerate(ROOMS):
        m_floor = mat(sc, color, 0.5, 0.75)
        size = (float(x1 - x0), 0.5, float(z1 - z0))
        sc.static_box(f"Floor{i + 1}", g, ((x0 + x1) / 2, -0.25, (z0 + z1) / 2), size, m_floor)
    for i, (x0, z0, x1, z1) in enumerate(wall_rects()):
        size = (float(x1 - x0), WALL_H, float(z1 - z0))
        sc.static_box(f"Wall{i + 1}", g, ((x0 + x1) / 2, WALL_H / 2, (z0 + z1) / 2), size, m_wall)
        # Светлая кромка сверху — стены лучше читаются камерой сверху.
        sc.node("Top", "MeshInstance3D", f"{g}/Wall{i + 1}", {
            "transform": tr((0, WALL_H / 2 + 0.02, 0)),
            "mesh": f'SubResource("{sc.box_mesh((size[0], 0.04, size[2]), m_wall_top)}")'})
    for i, (x, z, sx, sz, h, kind) in enumerate(PROPS):
        sc.static_box(f"{kind.title()}{i + 1}", g, (x, h / 2, z), (float(sx), float(h), float(sz)),
                      m_crate if kind == "crate" else m_pillar)

    sc.node("Doors", "Node3D", ".")
    for i, door in enumerate(DOORS):
        x, z, rot, locked, key, key_name = door[:6]
        props = {"transform": tr((x, 0, z), rot), "script": f'ExtResource("{r_door}")', "height": WALL_H}
        if len(door) > 6 and not door[6]:
            props["enemies_can_open"] = "false"
        if locked:
            props.update({"locked": "true", "key_id": f'&"{key}"', "key_name": f'"{key_name}"'})
        sc.node(f"Door{i + 1}", "Node3D", "Doors", props)

    sc.node("Lights", "Node3D", ".")
    for i, (x, z, c, e, rng) in enumerate(LIGHTS):
        sc.node(f"Light{i + 1}", "OmniLight3D", "Lights", {
            "transform": tr((x, 2.2, z)), "light_color": col(c), "light_energy": e, "omni_range": rng})

    sc.node("Enemies", "Node3D", ".")
    kinds = {"crawler": ("Crawler", r_crawler), "brute": ("Brute", r_brute), "spitter": ("Spitter", r_spitter)}
    for i, e in enumerate(CRAWLERS):
        name, res = kinds[e[2] if len(e) > 2 else "crawler"]
        sc.node(f"{name}{i + 1}", None, "Enemies", {"transform": tr((e[0], 0.1, e[1]), (i * 67) % 360)}, instance=res)

    sc.node("Spawners", "Node3D", ".")
    for i, (x, z, tsize, toff, waves, vents) in enumerate(SPAWNERS):
        name = f"Spawner{i + 1}"
        sc.node(name, "Node3D", "Spawners", {
            "transform": tr((x, 0, z)), "script": f'ExtResource("{r_spawner}")',
            "enemy_scene": f'ExtResource("{r_crawler}")', "rare_scene": f'ExtResource("{r_spitter}")',
            "waves": "Array[int]([%s])" % ", ".join(map(str, waves)),
            "trigger_size": vec((float(tsize[0]), 2.0, float(tsize[1]))),
            "trigger_offset": vec((float(toff[0]), 0.0, float(toff[1])))})
        for j, (vx, vz) in enumerate(vents):
            sc.node(f"Vent{j + 1}", "Marker3D", f"Spawners/{name}", {"transform": tr((vx - x, 0, vz - z))})

    kx, kz, kid, kname = KEYCARD
    sc.node("Keycard", "Area3D", ".", {"transform": tr((kx, 0.9, kz)), "script": f'ExtResource("{r_key}")',
                                        "key_id": f'&"{kid}"', "key_name": f'"{kname}"'})
    sx, sz, ssx, ssz = SAFE_ZONE
    sc.node("SafeZone", "Area3D", ".", {"transform": tr((sx, 0, sz)), "script": f'ExtResource("{r_safe}")',
                                         "size": vec((float(ssx), 3.0, float(ssz)))})
    sc.node("Modules", "Node3D", ".")
    for i, (mx, mz, mid) in enumerate(START_MODULES):
        sc.node(f"Module{i + 1}", "Area3D", "Modules", {"transform": tr((mx, 0.6, mz)), "script": f'ExtResource("{r_pickup}")', "kind": '&"module"',
                                                       "module": f'ExtResource("{r_mods[mid]}")'})
    sc.node("Exit", "Area3D", ".", {"transform": tr((EXIT[0], 0, EXIT[1])), "script": f'ExtResource("{r_exit}")'})

    sc.node("Player", None, ".", {"transform": tr((PLAYER[0], 0, PLAYER[1]))}, instance=r_player)
    sc.node("CameraRig", "Node3D", ".", {"script": f'ExtResource("{r_camera}")', "target_path": 'NodePath("../Player")'})
    sc.node("Camera3D", "Camera3D", "CameraRig", {"current": "true", "fov": 50.0})
    sc.node("BulletPool", "Node3D", ".", {"script": f'ExtResource("{r_pool}")', "bullet_scene": f'ExtResource("{r_bullet}")'})
    # группа задаётся в заголовке узла — допишем вручную
    text = sc.text().replace('[node name="BulletPool" type="Node3D" parent="."]',
                             '[node name="BulletPool" type="Node3D" parent="." groups=["bullet_pool"]]')
    with open(f"{root}/scenes/facility.tscn", "w", encoding="utf-8") as f:
        f.write(text)
    print("walls:", len(wall_rects()), "sub_resources:", len(sc.sub))


if __name__ == "__main__":
    main(sys.argv[1])
