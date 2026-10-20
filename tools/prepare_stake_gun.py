"""Подготовка модели коломёта автора (коломет.obj, ~2 млн треугольников) для игры без Blender.

Упрощение — слияние вершин по сетке (vertex clustering): вершины в одной ячейке CELL м
с близкими UV сливаются, вырожденные треугольники выбрасываются. Швы UV сохраняются.
Текстуры из «Новая папка» уменьшаются до 2048 и копируются в assets/weapons/stake_gun/.
Запуск: python tools/prepare_stake_gun.py 0.006 1000  (ячейка 6 мм, UV не делят ячейки —
иначе сетка рассыпается на дыры; так собрана текущая модель, ~48 тыс. треугольников).
Текстуры (2048) сделаны отдельно из «Новая папка»: 21b819ef… → albedo, 11689928… → rough.
"""
import sys, json
from pathlib import Path
import numpy as np

R = Path(__file__).resolve().parents[1]
SRC = R / "коломет.obj"
OUT = R / "assets/weapons/stake_gun"
OUT.mkdir(parents=True, exist_ok=True)
CELL = float(sys.argv[1]) if len(sys.argv) > 1 else 0.004
UV_CELL = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0 / 512.0

verts, uvs, faces = [], [], []
with open(SRC, encoding="utf-8", errors="ignore") as f:
    for line in f:
        t = line[:2]
        if t == "v ":
            verts.append(line[2:].split()[:3])
        elif t == "vt":
            uvs.append(line[3:].split()[:2])
        elif t == "f ":
            parts = line[2:].split()
            faces.append([p.split("/")[0] for p in parts[:3]] + [p.split("/")[1] for p in parts[:3]])
V = np.array(verts, dtype=np.float64)
T = np.array(uvs, dtype=np.float64)
F = np.array(faces, dtype=np.int64) - 1
fv, ft = F[:, :3], F[:, 3:]
print("source", len(V), "verts", len(F), "tris", flush=True)

# Ключ угла: ячейка позиции + ячейка UV.
corner_v = fv.reshape(-1)
corner_t = ft.reshape(-1)
pk = np.floor(V[corner_v] / CELL).astype(np.int64)
tk = np.floor(T[corner_t] / UV_CELL).astype(np.int64)
keys = np.concatenate([pk, tk], axis=1)
uniq, inverse = np.unique(keys, axis=0, return_inverse=True)
inverse = inverse.reshape(-1)
count = np.bincount(inverse).astype(np.float64)
pos = np.stack([np.bincount(inverse, V[corner_v][:, i]) for i in range(3)], 1) / count[:, None]
uv = np.stack([np.bincount(inverse, T[corner_t][:, i]) for i in range(2)], 1) / count[:, None]
tri = inverse.reshape(-1, 3)
# Вырожденные: два угла в одной ячейке позиции.
cell_id = np.unique(pk, axis=0, return_inverse=True)[1].reshape(-1, 3)
ok = (cell_id[:, 0] != cell_id[:, 1]) & (cell_id[:, 1] != cell_id[:, 2]) & (cell_id[:, 0] != cell_id[:, 2])
tri = tri[ok]
tri = np.unique(np.sort(tri, axis=1), axis=0, return_index=True)[1]
tri = inverse.reshape(-1, 3)[ok][np.sort(tri)]
used = np.unique(tri)
remap = np.full(len(pos), -1, dtype=np.int64)
remap[used] = np.arange(len(used))
pos, uv, tri = pos[used], uv[used], remap[tri]
print("game", len(pos), "verts", len(tri), "tris", flush=True)

lines = ["mtllib stake_gun.mtl", "o StakeGun"]
lines += ["v %.5f %.5f %.5f" % tuple(p) for p in pos]
lines += ["vt %.5f %.5f" % tuple(t) for t in uv]
lines.append("usemtl StakeGun")
lines.append("s 1")
lines += ["f %d/%d %d/%d %d/%d" % (a + 1, a + 1, b + 1, b + 1, c + 1, c + 1) for a, b, c in tri]
(OUT / "stake_gun.obj").write_text("\n".join(lines) + "\n", encoding="utf-8")
(OUT / "stake_gun.mtl").write_text("newmtl StakeGun\nmap_Kd stake_gun_albedo.png\n", encoding="utf-8")
lo, hi = pos.min(0), pos.max(0)
(OUT / "asset_report.json").write_text(json.dumps({"source_triangles": int(len(F)), "game_triangles": int(len(tri)),
    "cell_m": CELL, "bounds_lo": lo.round(4).tolist(), "bounds_hi": hi.round(4).tolist()}, indent=2), encoding="utf-8")
print("bounds", lo.round(3), hi.round(3))
