"""Вырезает звуки для игры из библиотеки Sonniss GDC (архивы в _packs/sonniss/*.zip) в assets/sounds.
Запуск из папки проекта: python -I tools/import_sonniss.py .
Нужен ffmpeg в PATH. В каждом файле библиотеки — много дублей подряд: находим отдельные «события»
(звук между паузами) и берём нужное по номеру, обрезаем, нормализуем, делаем моно 44.1 кГц.
Фоновые петли (ambient_*) — кусок из середины с плавной склейкой конца с началом, формат .ogg.
"""
import glob
import os
import subprocess
import sys
import tempfile
import wave
import zipfile

import numpy as np

SR = 44100

# имя в игре: (часть пути в библиотеке, номер события, максимум секунд, громкость 0..1)
SOUNDS = {
    "crawler_bite": ("Violent Humanoid Creature Exhale Short 4", 0, 0.9, 0.9),
    "crawler_death": ("Flutter Death Vocal Stuttered Long 05", 0, 1.6, 0.9),
    "zombie_growl": ("Werewolf Growl Menacing Monstrous 06", 0, 1.8, 0.85),
    "zombie_attack": ("Orc Male Attack Long Heavy Hit Charged Up 03", 0, 1.2, 0.9),
    "brute_slam": ("Quick Heavy Weapon Swing To Thud Impact Var 01", 1, 1.2, 1.0),
    "brute_death": ("Sea Beast Creature Pain Intense Yell Long 04", 0, 2.2, 0.95),
    "boss_roar": ("ANMLRept_T Rex", 0, 3.0, 1.0),
    "explosion": ("Explosion Small Blast Enemy Death Crunchy Boom", 0, 1.6, 1.0),
    "explosion_big": ("EffectiveTrailer_Booms_Vol2_011", 0, 3.0, 1.0),
    "hit_flesh": ("Hit Blood Spill Splat Wood Impact Light Hit Squelch", 0, 0.35, 0.8),
    "gore_splat": ("Gore Designed Transient Heavy Impact Smash 01", 0, 1.0, 0.9),
    "hit_wall": ("Metal Old File Impact Tap Against Tire Iron", 0, 0.35, 0.7),
    "zap": ("ELECArc_ArcDesign15", 0, 0.6, 0.85),
    "spit": ("Liquid Impact, Bubble, Sci Fi, Hit 04", 0, 0.7, 0.8),
    "acid_splash": ("Impact Water Deep Submerge Bubble Drown Ship Hit 05", 0, 0.8, 0.8),
    "shot_flame": ("Whoosh Fire Deep Growl Monster Saturated Crisp 03", 0, 0.5, 0.8),
    "ui_click": ("Interface Percussion Snap", 0, 0.25, 0.7),
    "ui_open": ("Interface Accept Glassy Snap", 0, 0.5, 0.7),
    "door_locked": ("Interface Deny Low Fat Dark", 0, 0.8, 0.8),
    "door_open": ("Tower Deploy Hitech Robot Motor Dark Thump Servo Whine 04", 0, 1.0, 0.8),
    "door_close": ("Click Deep Mechanism Latch Button Nearfield Thunk 02", 0, 0.6, 0.8),
    "door_unlock": ("Click Deep Mechanism Latch Button Nearfield Thunk 02", 1, 0.6, 0.8),
    "key_pickup": ("Interface Sci-Fi Ping Down", 0, 0.8, 0.75),
    "chest_open": ("Mechanism Counting Machine Interact Loose Container Short 01", 0, 1.0, 0.85),
    "level_up": ("Collect Scifi Futuristic Electronic Bass Burst Sweep Heavy 04", 0, 2.0, 0.9),
    "unique_drop": ("Button Arp Twinkle", 0, 1.6, 0.8),
    "portal_open": ("ELECArc_ArcPowerUpDesign04", 0, 2.0, 0.85),
    "portal_enter": ("Woosh Sweep Slide Infographics Basic", 0, 1.2, 0.8),
    "alarm": ("EffectiveTrailer_Alarms_Vol2_HalfNotes_003", 0, 3.0, 0.8),
}
# Выстрелы: настоящие записи из GDC 2016 (Pole Position, Audiobeast, Fascinated Sound).
# Хвост короче (до 0.55 с), чтобы очереди не превращались в кашу.
GUNS = {
    "shot_pistol": ("Glock_18_1m_left_off_axis_MKH416_clean_Six_shots", 0, 0.5, 1.0),
    "shot_heavy_pistol": ("Colt_M1911_.45_ACP_Pistol_10m_MKH8040_Pair_001_Single_Shot", 0, 0.7, 1.0),
    "shot_magnum": ("HK_VP70_9mm_1m_in_front_RE20_clean_Double_shots", 0, 0.7, 1.0),
    "shot_machine_pistol": ("Beretta_93R_9mm_1m_left_on_ground_DPA4062_clean_Triple_shots", 0, 0.35, 1.0),
    "shot_smg": ("HK_MP7_4.6mm_1m_left_off_axis_MKH416_clean_Four_shots", 0, 0.35, 1.0),
    "shot_rifle": ("HK_416_5.56mm_1m_left_off_axis_MKH416_clean_Six_shots", 0, 0.45, 1.0),
    "shot_carbine": ("HK_416_5.56mm_on_gun_DPA4062_clean_Seven_shots", 0, 0.45, 1.0),
    "shot_battle": ("AKM_7.62x39mm_1m_left_on_ground_DPA4062_clean_Triple_shots", 0, 0.5, 1.0),
    "shot_marksman": ("FN_FAL_7.62x51mm_1.5m_behind_right_clean_2_shots", 0, 0.8, 1.0),
    "shot_sniper": ("Barrett_M98B_.338_Lapua_2m_right_MKH60_clean_Single_shots", 0, 1.2, 1.0),
    "shot_lmg": ("HK_MG4_5.56mm_1m_left_off_axis_MKH416_clean_Bursts", 0, 0.4, 1.0),
    "shot_shotgun": ("Remington_870_12g_Pump_Action_Shotgun_10m_U87_001_Single_Shot", 0, 1.0, 1.0),
    "shot_grenade": ("Automatic Cannon - MK44 - 03 - Single Shot with Report", 0, 1.0, 1.0),
}
# Минимальный промежуток до «следующего выстрела» в записи (с): ближе — это эхо того же выстрела.
MIN_GAP = {"shot_smg": 0.05, "shot_lmg": 0.06, "shot_machine_pistol": 0.05, "shot_sniper": 0.15}

# фоновые петли: (часть пути, секунд)
AMBIENT = {
    "ambient_station": ("Roomtone Space Ship Interior Muted", 30.0),
    "ambient_industrial": ("Dark Industrial Ambience", 30.0),
    "ambient_reactor": ("Scifi Loop Ship Reactor Synth Layer", 20.0),
    # «Музыка» — тёмные кинематографичные дроны (настоящей музыки в библиотеке нет).
    "music_hub": ("Yvaine,drone,electric,Pentatonic,DI,position7,light,oceanic,euphoric", 60.0),
    "music_floor": ("Tension - future war  2 ambience desolate dispairing and inevitable", 60.0),
    "music_floor2": ("alien_drone_003", 50.0),
}


def find(zips, needle):
    for z in zips:
        for n in z.namelist():
            if needle in n and n.lower().endswith(".wav"):
                return z, n
    raise SystemExit(f"не найдено: {needle}")


def decode(z, name, tmp):
    src = os.path.join(tmp, "src.wav")
    with open(src, "wb") as f:
        f.write(z.read(name))
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def events(x, frame=0.01, rel_db=-32.0, gap=0.15):
    n = int(SR * frame)
    frames = len(x) // n
    rms = np.sqrt(np.mean(x[: frames * n].reshape(frames, n) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms / (rms.max() + 1e-12))
    on = db > rel_db
    out, start, quiet = [], None, 0
    for i, v in enumerate(on):
        if v:
            if start is None:
                start = i
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet * frame >= gap:
                out.append((start * n, (i - quiet + 1) * n))
                start, quiet = None, 0
    if start is not None:
        out.append((start * n, frames * n))
    return [(a, b) for a, b in out if (b - a) > SR * 0.04]


def cut(x, k, max_sec):
    ev = events(x)
    a, b = ev[min(k, len(ev) - 1)] if ev else (0, len(x))
    a = max(0, a - int(SR * 0.005))
    b = min(len(x), b + int(SR * 0.12), a + int(SR * max_sec))
    y = x[a:b].copy()
    fade = min(len(y) // 4, int(SR * 0.08))
    if fade > 0:
        y[-fade:] *= np.linspace(1, 0, fade)
    return y


def cut_attack(x, max_sec):
    """Один выстрел из очереди с хвостом (последний выстрел первой очереди в записи)."""
    env = np.abs(x)
    n = int(SR * 0.002)
    frames = len(env) // n
    e = env[: frames * n].reshape(frames, n).max(axis=1)
    thr = e.max() * 0.35
    hits = [i for i in range(1, frames) if e[i] > thr and e[i - 1] <= thr * 0.6]
    # Берём ПОСЛЕДНИЙ выстрел очереди первого события: у него естественный хвост без наложения следующего.
    ev = events(x)
    first_end = ev[0][1] if ev else len(x)
    in_first = [h for h in hits if h * n < first_end]
    a = (in_first[-1] if in_first else (hits[0] if hits else 0)) * n
    b = min(a + int(SR * max_sec), len(x))
    a = max(0, a - int(SR * 0.003))
    y = x[a:b].copy()
    fade = min(len(y) // 3, int(SR * 0.03))
    y[-fade:] *= np.linspace(1, 0, fade)
    return y


def single_shot(x, min_gap, max_sec):
    """Ровно один выстрел: от первой сильной атаки до следующей (не ближе min_gap), затем свой хвост эха,
    чтобы обрез не был слышен. Так в звуке не остаётся соседних выстрелов — «двоение» пропадает."""
    k = int(SR * 0.001)
    frames = len(x) // k
    e = np.abs(x[: frames * k]).reshape(frames, k).max(axis=1)
    thr = e.max() * 0.3
    attacks = [i * k for i in range(1, frames) if e[i] > thr and e[i - 1] <= thr * 0.5]
    a = attacks[0] if attacks else int(np.argmax(e) * k)
    nxt = next((t for t in attacks if t > a + int(SR * min_gap)), len(x))
    b = min(nxt - int(SR * 0.004), a + int(SR * max_sec), len(x))
    a = max(0, a - int(SR * 0.002))
    y = x[a:b].copy()
    fade = min(len(y) // 3, int(SR * 0.02))
    y[-fade:] *= np.linspace(1, 0, fade)
    # Хвост: несколько затухающих отражений «отсека», мягче исходника.
    tail = int(SR * 0.35)
    out = np.concatenate([y, np.zeros(tail)])
    rev = np.zeros_like(out)
    for i, d in enumerate((0.023, 0.037, 0.053, 0.079, 0.113, 0.167)):
        n = int(SR * d)
        g = 0.32 * (0.62 ** i)
        rev[n:] += out[:-n] * g
    rev = np.convolve(rev, np.ones(24) / 24, mode="same")  # убираем «звон» отражений
    out = out + rev
    out[-int(SR * 0.05):] *= np.linspace(1, 0, int(SR * 0.05))
    return out


def save_wav(path, y, gain):
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.95 * gain
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())


def save_loop(path, x, sec, tmp):
    mid = len(x) // 2
    n = int(SR * sec)
    a = max(0, mid - n // 2)
    y = x[a:a + n].copy()
    xf = int(SR * 2.0)
    # плавная склейка: конец перетекает в начало
    head = y[:xf].copy()
    y = y[xf:]
    y[-xf:] = y[-xf:] * np.linspace(1, 0, xf) + head * np.linspace(0, 1, xf)
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.7
    tmpwav = os.path.join(tmp, "loop.wav")
    save_wav(tmpwav, y, 1.0)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmpwav, "-c:a", "libvorbis", "-q:a", "4", path], check=True)


def main(root):
    zips = []
    for p in sorted(glob.glob(os.path.join(root, "_packs/sonniss*/*.zip"))):
        try:
            zips.append(zipfile.ZipFile(p))
        except zipfile.BadZipFile:
            print("пропускаю битый архив:", p)
    out = os.path.join(root, "assets/sounds")
    with tempfile.TemporaryDirectory() as tmp:
        for name, (needle, k, max_sec, gain) in SOUNDS.items():
            z, n = find(zips, needle)
            save_wav(os.path.join(out, name + ".wav"), cut(decode(z, n, tmp), k, max_sec), gain)
            print("ok", name)
        for name, (needle, k, max_sec, gain) in GUNS.items():
            z, n = find(zips, needle)
            x = decode(z, n, tmp)
            y = single_shot(x, MIN_GAP.get(name, 0.1), max_sec) if name != "shot_shotgun" else cut(x, k, max_sec)
            save_wav(os.path.join(out, name + ".wav"), y, gain)
            print("ok", name)
        for name, (needle, sec) in AMBIENT.items():
            z, n = find(zips, needle)
            save_loop(os.path.join(out, name + ".ogg"), decode(z, n, tmp), sec, tmp)
            print("ok", name)


if __name__ == "__main__":
    main(sys.argv[1])
