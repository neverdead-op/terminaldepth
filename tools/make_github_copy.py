"""Собирает чистую копию проекта для GitHub рядом с ним: ../terminal-depth-github.

Берёт только то, что нужно игре: project.godot, scenes, scripts, data, assets (без zip-архивов),
addons, tools, docs, главные .md и из animation/ — только файлы, на которые ссылается код.
Не берёт: .godot (кэш импорта), _packs, work, output, ztest, art_source, сырые выгрузки моделей
(GUN 1, MODEL 1, pistol, «Новая папка», «2D окружение», коломет.obj), zip-архивы.
Запуск: python tools/make_github_copy.py   (повторный запуск обновляет копию; .git копии не трогает)
"""
import os, re, shutil, sys
from pathlib import Path

R = Path(__file__).resolve().parents[1]
DST = R.parent / "terminal-depth-github"
DIRS = ["addons", "assets", "data", "docs", "scenes", "scripts", "tools"]
ROOT_FILES = ["project.godot", "icon.svg", "icon.svg.import", "export_presets.cfg", "AGENTS.md", "CLAUDE.md", "PROJECT_MAP.md"]
SKIP_EXT = {".zip", ".blend1", ".tmp"}


def skip(p: Path) -> bool:
    return p.suffix.lower() in SKIP_EXT or p.name.endswith(".blend1")


def copy(src: Path) -> int:
    rel = src.relative_to(R)
    dst = DST / rel
    if dst.exists() and dst.stat().st_size == src.stat().st_size and dst.stat().st_mtime >= src.stat().st_mtime:
        return 0
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return src.stat().st_size


wanted: list[Path] = []
for name in ROOT_FILES:
    if (R / name).exists():
        wanted.append(R / name)
for d in DIRS:
    for root, dirs, files in os.walk(R / d):
        for f in files:
            p = Path(root) / f
            if not skip(p):
                wanted.append(p)

# animation/: только то, на что есть ссылки res://animation/... в коде и сценах (+ .import и соседние текстуры).
refs = set()
pattern = re.compile(r'res://(animation/[^"\n]+)')
for d in ["scripts", "scenes", "data", "assets"]:
    for root, _, files in os.walk(R / d):
        for f in files:
            # .tres-библиотеки анимаций уже запечены: пути к fbx в них — только пометки.
            if f.endswith((".gd", ".tscn")):
                text = (Path(root) / f).read_text(encoding="utf-8", errors="ignore")
                refs.update(m.group(1) for m in pattern.finditer(text))
for ref in sorted(refs):
    p = R / ref
    if not p.is_file():
        continue
    stem = p.stem
    for sibling in p.parent.iterdir():
        # Сам файл, его .import и текстуры, извлечённые при импорте (Ch15_nonPBR_0.png …).
        if sibling.is_file() and (sibling.name.startswith(stem + ".") or sibling.name.startswith(stem + "_")):
            wanted.append(sibling)

total = 0
big = []
for p in sorted(set(wanted)):
    total += copy(p)
    if p.stat().st_size > 95 * 1024 * 1024:
        big.append(p.relative_to(R).as_posix())
size = sum(f.stat().st_size for f in DST.rglob("*") if f.is_file() and ".git" not in f.parts)
print("files", len(set(wanted)), "copied MB", total // 1048576, "copy size MB", size // 1048576)
print("over 95 MB (need Git LFS):", big)
