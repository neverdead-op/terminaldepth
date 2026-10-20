"""Генератор базы scenes/hub.tscn: маленькая лаборатория на Луне — зал с торговками (Angie — готовые вещи,
Mira — вещи «вслепую» по базе), верстаком разбора, складом и большой дверью грузового лифта (путь в сектор). Снаружи — лунная поверхность с кратерами,
камнями и антенной (видна вокруг зала и через окна). Модели — Quaternius MegaKit + Sci-Fi Essentials.
Первичная сборка: python -I tools/gen_hub.py .
Существующую базу с ручной расстановкой заменяет только явный --overwrite."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_facility import Scene, vec, col, tr, mat  # noqa: E402
from gen_open_zone import Batches, SIZES  # noqa: E402

W, D, H = 16, 12, 3.0  # зал x[-8, 8], z[-6, 6]; стены — модули MegaKit высотой 3 м


def main(root):
    target = os.path.join(root, "scenes", "hub.tscn")
    if os.path.exists(target) and "--overwrite" not in sys.argv:
        raise SystemExit("База уже существует. Ручная расстановка сохранена. Для явной перегенерации добавьте --overwrite.")
    rng = random.Random(7)
    sc = Scene()
    r_camera = sc.ext_res("Script", "res://scripts/camera_rig.gd")
    r_pool = sc.ext_res("Script", "res://scripts/bullet_pool.gd")
    r_bullet = sc.ext_res("PackedScene", "res://scenes/bullet.tscn")
    r_safe = sc.ext_res("Script", "res://scripts/safe_zone.gd")
    r_vendor = sc.ext_res("Script", "res://scripts/vendor.gd")
    r_bench = sc.ext_res("Script", "res://scripts/workbench.gd")
    r_lift = sc.ext_res("Script", "res://scripts/hub_lift_door.gd")
    r_batch = sc.ext_res("Script", "res://scripts/model_batch.gd")
    r_stash = sc.ext_res("Script", "res://scripts/stash.gd")
    r_finishes = sc.ext_res("PackedScene", "res://scenes/hub_finishes.tscn")
    batches = Batches()

    env = sc.sub_res("Environment", {
        "background_mode": 1, "background_color": col((0.0, 0.0, 0.005)),
        "ambient_light_source": 2, "ambient_light_color": col((0.62, 0.69, 0.8)), "ambient_light_energy": 0.95,
        "tonemap_mode": 3, "tonemap_exposure": 1.1, "ssao_enabled": "true", "ssao_radius": 1.0, "ssao_intensity": 0.75,
        "glow_enabled": "true", "glow_intensity": 0.35, "glow_bloom": 0.0, "glow_hdr_threshold": 2.0,
        "adjustment_enabled": "true", "adjustment_contrast": 1.03, "adjustment_saturation": 1.0,
    })
    m_core = mat(sc, (0.07, 0.075, 0.09), 0.4, 0.7)
    m_top = mat(sc, (0.34, 0.35, 0.39), 0.6, 0.5)
    m_stripe = mat(sc, (0.25, 0.43, 0.48), 0.3, 0.5, ((0.35, 0.7, 0.8), 0.5))
    m_bronze = mat(sc, (0.23, 0.16, 0.09), 0.65, 0.5)
    m_runner = mat(sc, (0.075, 0.12, 0.14), 0.2, 0.85)
    m_regolith = mat(sc, (0.22, 0.22, 0.23), 0.0, 0.95)
    m_crater = mat(sc, (0.14, 0.14, 0.15), 0.0, 1.0)
    m_rock = mat(sc, (0.2, 0.2, 0.2), 0.0, 0.9)
    m_earth = mat(sc, (0.25, 0.45, 0.85), 0.0, 0.6, ((0.2, 0.45, 1.0), 1.4))

    sc.node("Hub", "Node3D", None)
    sc.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})
    # Солнце на Луне — резкое, холодное, длинные тени.
    sc.node("Sun", "DirectionalLight3D", ".", {
        "transform": "Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, -0.5, -0.612, 0.612, 0, 10, 0)",
        "light_color": col((0.95, 0.95, 1.0)), "light_energy": 0.65, "shadow_enabled": "true"})
    sc.node("Geometry", "Node3D", ".")
    g = "Geometry"

    # --- Снаружи: лунный грунт, кратеры, камни, антенны, Земля над горизонтом ---
    sc.node("Moon", "Node3D", ".")
    sc.node("Regolith", "MeshInstance3D", "Moon", {
        "transform": tr((0, -0.08, 0)), "mesh": f'SubResource("{sc.box_mesh((140.0, 0.1, 110.0), m_regolith)}")'})
    torus = sc.sub_res("TorusMesh", {"inner_radius": 0.82, "outer_radius": 1.0, "rings": 32, "ring_segments": 8,
                                     "material": f'SubResource("{m_crater}")'})
    disc = sc.sub_res("CylinderMesh", {"top_radius": 0.85, "bottom_radius": 0.85, "height": 0.02, "radial_segments": 32,
                                       "material": f'SubResource("{m_crater}")'})
    rock = sc.sub_res("SphereMesh", {"radius": 0.5, "height": 0.7, "radial_segments": 7, "rings": 4,
                                     "material": f'SubResource("{m_rock}")'})
    ci = 0
    for _ in range(26):
        x, z = rng.uniform(-55, 55), rng.uniform(-45, 40)
        if abs(x) < W / 2 + 4 and abs(z) < D / 2 + 4:
            continue
        r = rng.uniform(1.5, 6.0)
        ci += 1
        sc.node(f"Crater{ci}", "MeshInstance3D", "Moon", {
            "transform": "Transform3D(%s, 0, 0, 0, %s, 0, 0, 0, %s, %s, 0, %s)" % (
                round(r, 2), round(r * 0.25, 2), round(r, 2), round(x, 2), round(z, 2)),
            "mesh": f'SubResource("{torus}")'})
        sc.node(f"CraterFloor{ci}", "MeshInstance3D", "Moon", {
            "transform": "Transform3D(%s, 0, 0, 0, 1, 0, 0, 0, %s, %s, -0.02, %s)" % (
                round(r, 2), round(r, 2), round(x, 2), round(z, 2)),
            "mesh": f'SubResource("{disc}")'})
    for i in range(40):
        x, z = rng.uniform(-50, 50), rng.uniform(-40, 35)
        if abs(x) < W / 2 + 2 and abs(z) < D / 2 + 2:
            continue
        s = rng.uniform(0.4, 2.0)
        sc.node(f"Rock{i + 1}", "MeshInstance3D", "Moon", {
            "transform": "Transform3D(%s, 0, 0, 0, %s, 0, 0, 0, %s, %s, %s, %s)" % (
                round(s * 1.3, 2), round(s * 0.7, 2), round(s, 2), round(x, 2), round(s * 0.15, 2), round(z, 2)),
            "mesh": f'SubResource("{rock}")'})
    earth = sc.sub_res("SphereMesh", {"radius": 6.0, "height": 12.0, "material": f'SubResource("{m_earth}")'})
    sc.node("Earth", "MeshInstance3D", "Moon", {"transform": tr((26, 2, -60)), "mesh": f'SubResource("{earth}")'})
    batches.add("Prop_SatelliteDish", (-17, 0, -12), 30)
    batches.add("Prop_SatelliteDish", (19, 0, 9), -120)

    # --- Зал: пол из плиток MegaKit, вокруг портала — узорная площадка ---
    sc.node("Floor", "StaticBody3D", g, {"transform": tr((0, -0.25, 0))})
    sc.node("Shape", "CollisionShape3D", f"{g}/Floor", {"shape": f'SubResource("{sc.box_shape((float(W), 0.5, float(D)))}")'})
    for ix in range(W // 4):
        for iz in range(D // 4):
            x, z = -W / 2 + 2 + ix * 4, -D / 2 + 2 + iz * 4
            centre = abs(x) < 3 and z < 0
            tile = "Platform_CenterPlate" if centre else ("Platform_Simple" if (ix * 3 + iz) % 4 else "Platform_Simple2")
            batches.add(tile, (x, 0.01, z), 0, shadows=False)

    # Стены: коробки столкновений снаружи + панели внутрь. Северная — окна на лунную равнину.
    for i, ((x, z), (sx, sz)) in enumerate([((0, -D / 2 - 0.5), (W + 2.0, 1.0)), ((0, D / 2 + 0.5), (W + 2.0, 1.0)),
                                           ((-W / 2 - 0.5, 0), (1.0, float(D))), ((W / 2 + 0.5, 0), (1.0, float(D)))]):
        name = f"Wall{i + 1}"
        sc.node(name, "StaticBody3D", g, {"transform": tr((x, H / 2, z))})
        sc.node("Shape", "CollisionShape3D", f"{g}/{name}", {"shape": f'SubResource("{sc.box_shape((sx, H, sz))}")'})
        # Срез передней стены открывает комнату верхней камере; столкновения прежние.
        visible_h = 0.45 if z > D / 2 else H
        core = (sx - 0.5 if sx < 2 else sx, visible_h, sz - 0.5 if sz < 2 else sz)
        sc.node("Mesh", "MeshInstance3D", f"{g}/{name}", {"transform": tr((0, (visible_h - H) / 2, 0)), "mesh": f'SubResource("{sc.box_mesh(core, m_core)}")'})
        sc.node("Top", "MeshInstance3D", f"{g}/{name}", {
            "transform": tr((0, visible_h - H / 2 + 0.03, 0)), "mesh": f'SubResource("{sc.box_mesh((sx, 0.06, sz), m_top)}")'})
    for k in range(W // 4):
        t = -W / 2 + 2 + k * 4
        if abs(t) > 3:
            batches.add("WallWindow_Straight", (t, 0, -D / 2 + 2), -90)
        # Передние высокие панели убраны: они закрывали людей и рабочие места.
    for k in range(D // 4):
        t = -D / 2 + 2 + k * 4
        batches.add("WallAstra_Straight_Flat_Window" if k == 1 else "WallAstra_Straight_Flat", (-W / 2 + 2, 0, t), 0)
        batches.add("WallAstra_Straight_Flat_Window" if k == 2 else "WallAstra_Straight_Flat", (W / 2 - 2, 0, t), 180)
    for x in (-W / 2 + 0.5, W / 2 - 0.5):
        for z in (-D / 2 + 0.5, D / 2 - 0.5):
            batches.add("Column_Pipes", (x, 0, z), 0, (1.0, H / 5.0, 1.0))
    # Ритм металлических рёбер и бронзовых накладок на дальней стене.
    for k, x in enumerate((-7.3, -3.3, 3.3, 7.3)):
        for suffix, size, material, y in [("Rib", (0.2, 2.8, 0.24), m_core, 1.4), ("Cap", (0.42, 0.12, 0.42), m_bronze, 2.75)]:
            sc.node(f"Alcove{k}{suffix}", "MeshInstance3D", g, {"transform": tr((x, y, -5.7)), "mesh": f'SubResource("{sc.box_mesh(size, material)}")'})
    sc.node("CentralRunner", "MeshInstance3D", g, {"transform": tr((0, 0.025, 0)), "mesh": f'SubResource("{sc.box_mesh((2.8, 0.02, 10.0), m_runner)}")'})

    pi = 0
    di = 0

    def prop(name, cx, cz, yaw=0, scale=1.0, collide=True, y=0.0):
        nonlocal pi, di
        p, s = SIZES[name]["pos"], SIZES[name]["size"]
        lx, lz = (p[0] + s[0] / 2) * scale, (p[2] + s[2] / 2) * scale
        c, sn = round(math.cos(math.radians(yaw))), round(math.sin(math.radians(yaw)))
        model_position = (cx - (c * lx + sn * lz), y - p[1] * scale, cz - (-sn * lx + c * lz))
        w, d = s[0] * scale, s[2] * scale
        if yaw % 180:
            w, d = d, w
        h = s[1] * scale
        if collide:
            pi += 1
            sc.node(f"Prop{pi}", "StaticBody3D", g, {"transform": tr((cx, y + h / 2, cz)), "metadata/_edit_group_": "true"})
            sc.node("Shape", "CollisionShape3D", f"{g}/Prop{pi}",
                    {"shape": f'SubResource("{sc.box_shape((round(w, 2), round(h, 2), round(d, 2)))}")'})
            # Модель принадлежит тому же узлу, что и преграда: перемещение Prop двигает всё.
            visual = Batches()
            visual.add(name, (model_position[0] - cx, model_position[1] - y - h / 2, model_position[2] - cz), yaw, (scale,) * 3)
            visual.emit(sc, f"{g}/Prop{pi}", r_batch)
        else:
            # Небольшой декор тоже можно расставлять отдельными узлами в редакторе.
            di += 1
            visual = Batches()
            visual.add(name, (0, 0, 0), yaw, (scale,) * 3)
            sc.node(f"Decor{di}_{name}", "Node3D", g, {"transform": tr(model_position), "metadata/_edit_group_": "true"})
            visual.emit(sc, f"{g}/Decor{di}_{name}", r_batch)
        return h

    # Лаборатория: терминалы у окон, стол, стеллаж, шкафчики персонала, ящики.
    for i in range(2):
        prop("Prop_Computer", -6.8 + i * 0.95, -D / 2 + 0.45, 0)
        prop("Prop_Computer", 4.9 + i * 0.95, -D / 2 + 0.45, 0)
    for i in range(2):
        prop("Prop_Locker", 1.5 + i * 1.05, D / 2 - 0.35, 180)
    prop("Prop_Desk_Medium", -2.0, D / 2 - 0.8, 180)
    prop("Prop_Chair", -2.6, D / 2 - 2.0, 180, collide=False)
    prop("Prop_Mug", -1.5, D / 2 - 0.8, 0, collide=False, y=0.94)
    h = prop("Prop_Crate", -7.0, 4.8, 0)
    prop("Prop_Crate3", -7.0, 4.8, 90, collide=False, y=h)
    prop("Prop_Ammo_Closed", 7.2, 0.0, 90)
    for (name, x, z, yaw) in [("Prop_Light_Floor", -2.4, -4.8, 0), ("Prop_Light_Floor", 2.4, -4.8, 0)]:
        prop(name, x, z, yaw, collide=False)
    # Лавки торговок: стойка перед торговкой, стеллаж и ящики за ней.
    for vz in (-2.6, 2.4):
        prop("Prop_Desk_Medium", -4.0, vz, 270)  # передом к залу, торговка — за столом
        prop("Prop_Shelves_WideTall", -W / 2 + 0.4, vz, 90)
    for i, x in enumerate([-1.6, 1.6]):
        sc.node(f"Stripe{i + 1}", "MeshInstance3D", g, {
            "transform": tr((x, 0.03, -1.5)), "mesh": f'SubResource("{sc.box_mesh((0.12, 0.02, 6.0), m_stripe)}")'})

    sc.node("Lights", "Node3D", ".")
    for i, (x, z, c) in enumerate([(-5, -2.5, (1.0, 0.83, 0.66)), (5, -2.5, (0.7, 0.85, 1.0)), (0, 2.5, (0.9, 0.92, 1.0)),
                                   (-5, 3.5, (0.85, 0.9, 1.0)), (5, 3.5, (0.85, 0.9, 1.0))]):
        sc.node(f"Light{i + 1}", "OmniLight3D", "Lights", {
            "transform": tr((x, 2.7, z)), "light_color": col(c), "light_energy": 2.2, "omni_range": 8.5})

    sc.node("Models", "Node3D", ".")
    batches.emit(sc, "Models", r_batch)
    # Общая палитра базы: матовый графит вместо ослепительно белого пола и стоек.
    for i, node_text in enumerate(sc.nodes):
        if node_text.startswith('[node name="Platform_'):
            sc.nodes[i] += "\ntint = " + col((0.48, 0.53, 0.58))
        elif node_text.startswith('[node name="Prop_Desk_'):
            sc.nodes[i] += "\ntint = " + col((0.6, 0.52, 0.41))

    sc.node("SafeZone", "Area3D", ".", {"script": f'ExtResource("{r_safe}")', "size": vec((float(W), 3.0, float(D)))})
    # Торговки за стойками, лицом к залу (+X).
    sc.node("Vendor", "Node3D", ".", {"transform": tr((-5.4, 0, -2.6), 90), "script": f'ExtResource("{r_vendor}")'})
    sc.node("VendorBases", "Node3D", ".", {"transform": tr((-5.4, 0, 2.4), 90), "script": f'ExtResource("{r_vendor}")',
                                           "vendor_name": '"Mira"', "gamble": "true", "pages": 2,
                                           "suit_accent": col((0.45, 0.8, 1.0))})
    sc.node("Workbench", "Node3D", ".", {"transform": tr((4.6, 0, -3.0)), "script": f'ExtResource("{r_bench}")'})
    sc.node("Stash", "Node3D", ".", {"transform": tr((5.6, 0, 3.6), 180), "script": f'ExtResource("{r_stash}")'})
    sc.node("LiftDoor", "Node3D", ".", {"transform": tr((0, 0, -D / 2 + 0.35)), "script": f'ExtResource("{r_lift}")'})
    sc.node("Spawn", "Marker3D", ".", {"transform": tr((0, 0, 3.0))})

    sc.node("CameraRig", "Node3D", ".", {"script": f'ExtResource("{r_camera}")', "target_path": 'NodePath("../Player")'})
    sc.node("Camera3D", "Camera3D", "CameraRig", {"current": "true", "fov": 50.0})
    sc.node("BulletPool", "Node3D", ".", {"script": f'ExtResource("{r_pool}")', "bullet_scene": f'ExtResource("{r_bullet}")',
                                          "pool_size": 60})
    text = sc.text().replace('[node name="BulletPool" type="Node3D" parent="."]',
                             '[node name="BulletPool" type="Node3D" parent="." groups=["bullet_pool"]]')
    text += f'\n[node name="HubFinishes" parent="." instance=ExtResource("{r_finishes}")]\n'
    with open(f"{root}/scenes/hub.tscn", "w", encoding="utf-8") as f:
        f.write(text)
    print("hub ok")


if __name__ == "__main__":
    main(sys.argv[1])
