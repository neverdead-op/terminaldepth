"""Генерирует временные звуки-заглушки в assets/sounds. Запуск: python -I gen_sfx.py <папка>
ВНИМАНИЕ: часть звуков потом заменяет tools/import_sonniss.py (настоящие записи) — после gen_sfx запускать и его."""
import sys, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, cutoff):
    # однополюсный фильтр; cutoff может быть массивом (меняется во времени)
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def sweep(f0, f1, sec, curve=8.0):
    tt = t(sec)
    f = f1 + (f0 - f1) * np.exp(-curve * tt / sec)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def env(sec, attack=0.002, decay=10.0):
    tt = t(sec)
    e = np.exp(-decay * tt)
    a = int(SR * attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def save(path, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    tail = int(SR * 0.005)
    x[-tail:] *= np.linspace(1, 0, tail)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def shot():
    d = 0.22
    n = rng.standard_normal(len(t(d)))
    crack = highpass(lowpass(n, 6000), 700) * env(d, 0.001, 38)
    body = lowpass(n, 1800) * env(d, 0.001, 18) * 0.8
    thump = sweep(180, 55, d, 6) * env(d, 0.001, 22) * 0.9
    return crack + body + thump


def hit_flesh():
    d = 0.12
    n = rng.standard_normal(len(t(d)))
    splat = lowpass(n, np.linspace(2500, 400, len(n))) * env(d, 0.001, 35)
    thud = sweep(240, 90, d, 5) * env(d, 0.001, 30) * 0.8
    return splat + thud


def hit_wall():
    d = 0.09
    n = rng.standard_normal(len(t(d)))
    click = highpass(n, 2500) * env(d, 0.0005, 70)
    ring = np.sin(2 * np.pi * 2900 * t(d)) * env(d, 0.0005, 45) * 0.25
    return click + ring


def explosion():
    d = 1.1
    n = rng.standard_normal(len(t(d)))
    blast = lowpass(n, np.linspace(3500, 250, len(n))) * env(d, 0.003, 4.5)
    crackle = highpass(n, 3000) * env(d, 0.001, 14) * 0.35
    rumble = sweep(110, 38, d, 3) * env(d, 0.005, 3.5) * 0.9
    return blast + crackle + rumble


def dodge():
    d = 0.28
    n = rng.standard_normal(len(t(d)))
    tt = t(d)
    shape = np.sin(np.pi * tt / d) ** 2
    whoosh = lowpass(highpass(n, 300), np.linspace(900, 2600, len(n))) * shape
    return whoosh


def step():
    # тяжёлый ботинок: глухой удар + короткий хруст подошвы
    d = 0.16
    n = rng.standard_normal(len(t(d)))
    thud = sweep(130, 55, d, 7) * env(d, 0.001, 28)
    scuff = lowpass(highpass(n, 400), 2200) * env(d, 0.001, 45) * 0.45
    return thud + scuff


def gunshot(d, crack_cut, crack_decay, body_cut, body_decay, f0, f1, thump_decay, thump_gain):
    n = rng.standard_normal(len(t(d)))
    crack = highpass(lowpass(n, crack_cut), 700) * env(d, 0.001, crack_decay)
    body = lowpass(n, body_cut) * env(d, 0.001, body_decay) * 0.8
    thump = sweep(f0, f1, d, 6) * env(d, 0.001, thump_decay) * thump_gain
    return crack + body + thump


def shot_pistol():
    return gunshot(0.25, 7000, 30, 2200, 16, 220, 70, 20, 0.7)


def shot_rifle():
    return gunshot(0.16, 8000, 45, 2600, 26, 170, 60, 28, 0.6)


def shot_shotgun():
    d = 0.6
    x = gunshot(d, 5000, 18, 1400, 7, 120, 40, 9, 1.2)
    n = rng.standard_normal(len(t(d)))
    tail = lowpass(n, 600) * env(d, 0.02, 5) * 0.5
    return x + tail


def click(d, freq, decay, noise_cut):
    n = rng.standard_normal(len(t(d)))
    return highpass(n, noise_cut) * env(d, 0.0005, decay) + np.sin(2 * np.pi * freq * t(d)) * env(d, 0.0005, decay * 0.7) * 0.4


def pad(x, sec):
    return np.concatenate([x, np.zeros(int(SR * sec))])


def reload_start():
    # магазин вынимается: щелчок + шорох
    a = click(0.05, 1800, 90, 2000)
    n = rng.standard_normal(len(t(0.12)))
    slide = lowpass(highpass(n, 800), 3000) * np.sin(np.pi * t(0.12) / 0.12) * 0.3
    return np.concatenate([a, slide])


def reload_end():
    # магазин встаёт + затвор: два металлических щелчка
    a = click(0.06, 1500, 70, 1500)
    b = click(0.08, 1100, 55, 1200) * 1.2
    return np.concatenate([pad(a, 0.09), b])


def empty():
    return click(0.06, 2400, 110, 3000) * 0.6


def heal():
    # инжектор: щелчок, шипение и мягкий восходящий тон
    d = 0.7
    n = rng.standard_normal(len(t(d)))
    tt = t(d)
    hiss = highpass(lowpass(n, 7000), 2500) * np.exp(-4.5 * tt) * np.minimum(tt / 0.02, 1) * 0.5
    tone = np.sin(2 * np.pi * np.cumsum(np.linspace(420, 760, len(tt))) / SR) * np.sin(np.pi * tt / d) * 0.35
    return np.concatenate([click(0.04, 2000, 100, 2500), hiss + tone])


def crawler_bite():
    d = 0.18
    n = rng.standard_normal(len(t(d)))
    hiss = highpass(n, 1800) * env(d, 0.01, 18) * 0.6
    snap = click(0.05, 900, 80, 800)
    return pad(snap, d - 0.05) + hiss


def crawler_death():
    d = 0.45
    n = rng.standard_normal(len(t(d)))
    squelch = lowpass(n, np.linspace(1800, 200, len(n))) * env(d, 0.002, 9)
    shriek = np.sin(2 * np.pi * np.cumsum(np.linspace(900, 300, len(n))) / SR) * env(d, 0.002, 14) * 0.35
    thud = sweep(150, 50, d, 6) * env(d, 0.001, 15) * 0.6
    return squelch + shriek + thud


def door_open():
    d = 0.55
    n = rng.standard_normal(len(t(d)))
    tt = t(d)
    shape = np.minimum(tt / 0.03, 1) * np.exp(-3.5 * tt)
    hiss = lowpass(highpass(n, 500), np.linspace(4000, 1200, len(n))) * shape
    hum = np.sin(2 * np.pi * np.cumsum(np.linspace(90, 140, len(n))) / SR) * shape * 0.5
    return hiss + hum


def door_close():
    x = door_open()[: int(SR * 0.4)]
    return np.concatenate([x * 0.8, click(0.08, 300, 40, 300) * 0.8])


def tone(freq, d, decay):
    return np.sin(2 * np.pi * freq * t(d)) * env(d, 0.003, decay)


def door_locked():
    # двойной низкий «бип» отказа
    b = np.sign(np.sin(2 * np.pi * 220 * t(0.12))) * 0.4 * env(0.12, 0.003, 4)
    return np.concatenate([pad(b, 0.06), b])


def door_unlock():
    return np.concatenate([pad(tone(660, 0.1, 20), 0.02), tone(990, 0.25, 10)])


def key_pickup():
    return np.concatenate([pad(tone(880, 0.08, 25), 0.01), pad(tone(1175, 0.08, 25), 0.01), tone(1760, 0.3, 9)])


def vent():
    d = 0.35
    n = rng.standard_normal(len(t(d)))
    rattle = highpass(n, 600) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 28 * t(d)))) * env(d, 0.002, 9)
    return lowpass(rattle, 3000)


def spit():
    d = 0.3
    n = rng.standard_normal(len(t(d)))
    wet = lowpass(highpass(n, 500), np.linspace(3000, 800, len(n))) * env(d, 0.005, 12)
    gulp = sweep(300, 120, d, 5) * env(d, 0.002, 18) * 0.5
    return wet + gulp


def acid_splash():
    d = 0.35
    n = rng.standard_normal(len(t(d)))
    fizz = highpass(n, 2500) * env(d, 0.002, 9) * 0.6
    splat = lowpass(n, 900) * env(d, 0.001, 25)
    return fizz + splat


def brute_slam():
    d = 0.7
    n = rng.standard_normal(len(t(d)))
    boom = sweep(90, 30, d, 4) * env(d, 0.001, 6) * 1.2
    debris = lowpass(n, 1500) * env(d, 0.002, 10) * 0.6
    return boom + debris


def brute_death():
    d = 1.2
    tt = t(d)
    n = rng.standard_normal(len(tt))
    groan = np.sin(2 * np.pi * np.cumsum(np.linspace(120, 50, len(tt))) / SR) * np.exp(-2.2 * tt) * (1 + 0.3 * np.sin(2 * np.pi * 7 * tt))
    burst = lowpass(n, np.linspace(2500, 200, len(tt))) * env(d, 0.002, 4) * 0.8
    return groan + burst


def ui_click():
    return click(0.04, 1600, 120, 3000) * 0.5


def ui_open():
    return np.concatenate([pad(tone(520, 0.06, 30), 0.01), tone(780, 0.12, 20)])


def portal_open():
    d = 1.0
    tt = t(d)
    n = rng.standard_normal(len(tt))
    rise = np.sin(2 * np.pi * np.cumsum(np.linspace(110, 330, len(tt))) / SR) * np.minimum(tt / 0.5, 1) * np.exp(-1.5 * np.maximum(tt - 0.6, 0)) * 0.6
    shimmer = highpass(n, 3000) * np.sin(np.pi * tt / d) ** 2 * 0.25
    return rise + shimmer


def portal_enter():
    d = 0.7
    tt = t(d)
    n = rng.standard_normal(len(tt))
    whoosh = lowpass(highpass(n, 300), np.linspace(600, 5000, len(tt))) * np.sin(np.pi * tt / d) ** 2
    tone = np.sin(2 * np.pi * np.cumsum(np.linspace(440, 1320, len(tt))) / SR) * np.exp(-3 * tt) * 0.4
    return whoosh + tone


def level_up():
    # торжественный аккорд вверх + мерцание
    notes = [523, 659, 784, 1047]
    out = np.zeros(int(SR * 1.4))
    for i, f in enumerate(notes):
        start = int(SR * 0.09 * i)
        d = 1.4 - 0.09 * i
        tt = t(d)
        tone = (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2 * tt)) * np.exp(-2.2 * tt) * np.minimum(tt / 0.01, 1)
        out[start:start + len(tone)] += tone[: len(out) - start]
    n = rng.standard_normal(len(out))
    out += highpass(n, 5000) * np.exp(-2.5 * t(1.4)) * 0.15
    return out


def zap():
    # электрический разряд дрона
    d = 0.28
    tt = t(d)
    n = rng.standard_normal(len(tt))
    buzz = np.sign(np.sin(2 * np.pi * np.cumsum(np.linspace(1400, 300, len(tt))) / SR)) * env(d, 0.002, 9) * 0.35
    crackle = highpass(n, 4000) * env(d, 0.001, 18) * 0.5
    return buzz + crackle


def robot_step():
    return click(0.06, 700, 70, 600) * 0.6


# --- Выстрелы v2: щелчок механизма + хлопок + корпус + эхо отсека ---

def room(x, wet=0.35, delays=(0.031, 0.047, 0.071, 0.113), fb=0.45, tail=0.45):
    """Простое «эхо станции»: несколько затухающих задержек с фильтрацией."""
    out = np.concatenate([x, np.zeros(int(SR * tail))])
    acc = np.zeros_like(out)
    for i, dly in enumerate(delays):
        k = int(SR * dly)
        g = wet * (fb ** i)
        echo = np.zeros_like(out)
        echo[k:] = out[:-k] * g
        acc += echo
    acc = lowpass(acc, 2500)
    return out + acc


def gunshot2(d, crack_cut, crack_decay, body_cut, body_decay, f0, f1, thump_decay, thump_gain, mech=0.25, wet=0.35):
    x = gunshot(d, crack_cut, crack_decay, body_cut, body_decay, f0, f1, thump_decay, thump_gain)
    n = rng.standard_normal(len(x))
    snap = highpass(n, 3500) * env(d, 0.0003, 160) * 0.9  # резкий передний фронт
    x = x + snap
    if mech > 0:
        m = click(0.05, 1800, 90, 2000) * mech
        k = int(SR * 0.07)
        x[k:k + len(m)] += m[: len(x) - k]
    return room(x, wet)


def shot_pistol():
    return gunshot2(0.25, 7000, 30, 2200, 16, 220, 70, 20, 0.75, 0.3, 0.3)


def shot_rifle():
    return gunshot2(0.16, 8000, 45, 2600, 26, 170, 60, 28, 0.65, 0.15, 0.25)


def shot_smg():
    return gunshot2(0.12, 9000, 60, 3000, 34, 200, 80, 34, 0.45, 0.0, 0.18)


def shot_sniper():
    d = 0.7
    x = gunshot(d, 9000, 22, 1800, 8, 140, 35, 7, 1.4)
    n = rng.standard_normal(len(x))
    x += highpass(n, 4000) * env(d, 0.0003, 120) * 1.2
    m = click(0.08, 1200, 60, 1500) * 0.4
    k = int(SR * 0.32)
    x[k:k + len(m)] += m
    return room(x, 0.5, fb=0.55, tail=0.8)


def shot_shotgun():
    d = 0.6
    x = gunshot(d, 5000, 18, 1400, 7, 120, 40, 9, 1.3)
    n = rng.standard_normal(len(t(d)))
    x += lowpass(n, 600) * env(d, 0.02, 5) * 0.5
    pump = click(0.06, 900, 70, 900) * 0.5
    k = int(SR * 0.33)
    x[k:k + len(pump)] += pump
    return room(x, 0.45, tail=0.6)


def shot_bow():
    # энергетический лук: щелчок тетивы + нарастающий гул и свист стрелы
    d = 0.45
    tt = t(d)
    twang = np.sin(2 * np.pi * 180 * tt) * np.exp(-14 * tt) * 0.8
    hum = np.sin(2 * np.pi * np.cumsum(np.linspace(900, 2400, len(tt))) / SR) * env(d, 0.005, 7) * 0.35
    n = rng.standard_normal(len(tt))
    whoosh = lowpass(highpass(n, 1200), np.linspace(5000, 1500, len(tt))) * env(d, 0.01, 9) * 0.6
    return room(twang + hum + whoosh, 0.2)


def shot_grenade():
    # глухой «бум-п» трубы и шипение вылетевшей гранаты
    d = 0.5
    tt = t(d)
    thump = sweep(140, 45, d, 5) * env(d, 0.001, 12) * 1.4
    n = rng.standard_normal(len(tt))
    pop = lowpass(n, 1200) * env(d, 0.001, 30) * 0.7
    hiss = highpass(n, 3000) * env(d, 0.05, 6) * 0.15
    return room(thump + pop + hiss, 0.35)


def shot_flame():
    # короткий выдох огня: шумовой поток с «хрустом»
    d = 0.22
    tt = t(d)
    n = rng.standard_normal(len(tt))
    roar = lowpass(n, 900) * np.sin(np.pi * tt / d) ** 0.5 * 0.9
    crackle = highpass(n, 2500) * (rng.random(len(tt)) > 0.985) * 1.5
    return roar + crackle


def explosion():
    d = 1.4
    n = rng.standard_normal(len(t(d)))
    blast = lowpass(n, np.linspace(4000, 200, len(n))) * env(d, 0.002, 4.0)
    crackle = highpass(n, 3000) * env(d, 0.001, 12) * 0.4
    rumble = sweep(100, 32, d, 3) * env(d, 0.005, 3.0) * 1.1
    return room(blast + crackle + rumble, 0.4, tail=0.6)


def chest_open():
    # скрип крышки + замок
    d = 0.6
    tt = t(d)
    creak = np.sin(2 * np.pi * np.cumsum(220 + 60 * np.sin(2 * np.pi * 7 * tt)) / SR) * env(d, 0.05, 4) * 0.3
    lock = click(0.08, 1100, 50, 1200)
    out = creak.copy()
    out[: len(lock)] += lock
    return out


def unique_drop():
    # «звон» редкой добычи: яркий колокол с переливом
    d = 1.6
    tt = t(d)
    out = np.zeros(len(tt))
    for f, g in [(880, 1.0), (1320, 0.6), (1760, 0.4), (2640, 0.25)]:
        out += np.sin(2 * np.pi * f * tt) * np.exp(-2.5 * tt) * g
    out *= np.minimum(tt / 0.005, 1)
    shimmer = highpass(rng.standard_normal(len(tt)), 6000) * np.exp(-3 * tt) * 0.1
    return out + shimmer


def boss_roar():
    d = 1.5
    tt = t(d)
    base = np.sin(2 * np.pi * np.cumsum(np.linspace(95, 60, len(tt)) * (1 + 0.08 * np.sin(2 * np.pi * 9 * tt))) / SR)
    n = rng.standard_normal(len(tt))
    growl = lowpass(n, 500) * 0.8
    shape = np.minimum(tt / 0.15, 1) * np.exp(-1.8 * np.maximum(tt - 0.6, 0))
    return room((base * 0.8 + growl) * shape, 0.4, tail=0.6)


if __name__ == "__main__":
    out = sys.argv[1]
    for name, fn in [("shot", shot), ("hit_flesh", hit_flesh), ("hit_wall", hit_wall),
                     ("explosion", explosion), ("dodge", dodge), ("step", step),
                     
                     ("reload_start", reload_start), ("reload_end", reload_end), ("empty", empty), ("heal", heal),
                     ("crawler_bite", crawler_bite), ("crawler_death", crawler_death), ("door_open", door_open),
                     ("door_close", door_close), ("door_locked", door_locked), ("door_unlock", door_unlock),
                     ("key_pickup", key_pickup), ("vent", vent),
                     ("spit", spit), ("acid_splash", acid_splash), ("brute_slam", brute_slam),
                     ("brute_death", brute_death), ("ui_click", ui_click), ("ui_open", ui_open),
                     ("portal_open", portal_open), ("portal_enter", portal_enter), ("level_up", level_up), ("zap", zap), ("robot_step", robot_step),
                     ("shot_bow", shot_bow),
                      ("chest_open", chest_open),
                     ("unique_drop", unique_drop), ("boss_roar", boss_roar)]:
        save(f"{out}/{name}.wav", fn())
        print("ok", name)
