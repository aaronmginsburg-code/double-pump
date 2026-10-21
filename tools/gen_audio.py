"""Synthesises every Double Pump sound effect and music loop from scratch (numpy + scipy).

All audio is original: generated from noise, oscillators and envelopes in this script,
no samples from any game or library. Output: assets/audio/*.ogg (44.1 kHz, Vorbis).
Re-run after tweaking:  python3 tools/gen_audio.py
"""
import os
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1337)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def env_exp(dur, decay, attack=0.001):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    return a * np.exp(-t / decay)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    sos = signal.butter(order, f, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, f, order=2):
    sos = signal.butter(order, f, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def sine(freq, dur, phase=0.0):
    t = t_axis(dur)
    if callable(freq):
        f = freq(t)
        return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)
    return np.sin(2 * np.pi * freq * t + phase)


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]
    return buf


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def fade(x, fin=0.002, fout=0.01):
    n_in, n_out = int(SR * fin), int(SR * fout)
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def save(name, x, peak=0.9):
    x = fade(norm(np.asarray(x, dtype=np.float64), peak))
    sf.write(os.path.join(OUT, name + ".ogg"), x.astype(np.float32), SR, format="OGG", subtype="VORBIS")


def metal_click(dur=0.08, freqs=(1850, 3150, 4420, 6100), decay=0.025, noise_amt=0.6):
    x = bp(noise(dur), 1500, 9000) * env_exp(dur, 0.006) * noise_amt
    for i, f in enumerate(freqs):
        x += sine(f, dur, i) * env_exp(dur, decay * (1 - i * 0.15)) * (0.5 / (i + 1))
    return x


# ---------------------------------------------------------------- weapon
def shotgun_fire():
    dur = 1.2
    crack = hp(noise(0.012), 2500) * env_exp(0.012, 0.003) * 1.2
    body = lp(noise(dur), 2600, 4) * env_exp(dur, 0.09) * 1.0
    low = lp(noise(dur), 500, 4) * env_exp(dur, 0.16) * 1.4
    thump = sine(lambda t: 38 + 110 * np.exp(-t / 0.03), dur) * env_exp(dur, 0.12) * 1.1
    tail = bp(noise(dur), 200, 1800) * env_exp(dur, 0.35, 0.02) * 0.25
    x = body + low + thump + tail
    x = place(x, crack, 0)
    return np.tanh(x * 2.2)


def pump_cycle():
    # Lines up with the Pump animation: back at 0.183 s, forward at 0.433 s.
    x = np.zeros(int(SR * 0.62))
    slide = bp(noise(0.12), 900, 4000) * env_exp(0.12, 0.05, 0.03) * 0.18
    place(x, slide, 0.07)
    place(x, metal_click(0.1, (1650, 2900, 4100), 0.03), 0.183)
    place(x, slide * 0.8, 0.33)
    place(x, metal_click(0.12, (2100, 3400, 5200, 7000), 0.035) * 1.2, 0.433)
    return x


def equip():
    x = np.zeros(int(SR * 0.45))
    place(x, bp(noise(0.18), 500, 3000) * env_exp(0.18, 0.06, 0.05) * 0.4, 0)
    place(x, metal_click(0.08, (1200, 2300, 3500), 0.02), 0.3)
    return x


def swap():
    x = np.zeros(int(SR * 0.25))
    place(x, bp(noise(0.12), 700, 5000) * env_exp(0.12, 0.03, 0.02) * 0.5, 0)
    place(x, metal_click(0.06, (2400, 3900), 0.015) * 0.7, 0.11)
    return x


def shell_insert():
    x = np.zeros(int(SR * 0.3))
    place(x, bp(noise(0.05), 400, 2500) * env_exp(0.05, 0.01) * 0.6, 0)
    place(x, metal_click(0.09, (1450, 2600, 3800), 0.022) * 0.9, 0.06)
    return x


def empty_click():
    return metal_click(0.12, (3000, 4700, 6900), 0.012, 0.9)


def shell_bounce():
    x = np.zeros(int(SR * 0.5))
    for i, at in enumerate((0.0, 0.14, 0.24, 0.3)):
        place(x, (sine(1900 - i * 80, 0.06) * 0.4 + sine(5200, 0.06) * 0.2) * env_exp(0.06, 0.012) * (0.8 ** i), at)
    return x


def reload_start():
    return bp(noise(0.2), 300, 2500) * env_exp(0.2, 0.06, 0.04) * 0.6


# ---------------------------------------------------------------- combat feedback
def hit_body():
    x = sine(2600, 0.07) * env_exp(0.07, 0.015) + hp(noise(0.07), 3000) * env_exp(0.07, 0.004) * 0.3
    return x


def hit_head():
    x = sine(1760, 0.35) * env_exp(0.35, 0.08) * 0.8 + sine(2637, 0.35) * env_exp(0.35, 0.06) * 0.5
    x += sine(3520, 0.35) * env_exp(0.35, 0.03) * 0.3
    return x


def elimination():
    x = np.zeros(int(SR * 0.7))
    place(x, sine(lambda t: 90 * np.exp(-t / 0.08) + 45, 0.4) * env_exp(0.4, 0.12) * 1.2, 0)
    for i, f in enumerate((880, 1318.5, 1760)):
        place(x, (sine(f, 0.35) + 0.3 * sine(f * 2, 0.35)) * env_exp(0.35, 0.1) * 0.45, 0.05 + i * 0.06)
    return np.tanh(x * 1.3)


def double_pump_elim():
    x = np.zeros(int(SR * 1.0))
    place(x, sine(lambda t: 110 * np.exp(-t / 0.08) + 45, 0.45) * env_exp(0.45, 0.14) * 1.2, 0)
    notes = (659.3, 987.8, 1318.5, 1975.5)
    for i, f in enumerate(notes):
        tone = (signal.square(2 * np.pi * f * t_axis(0.3)) * 0.25 + sine(f, 0.3)) * env_exp(0.3, 0.09)
        place(x, tone * 0.5, 0.04 + i * 0.07)
    place(x, (sine(1975.5, 0.5) + sine(2637, 0.5) * 0.6) * env_exp(0.5, 0.18) * 0.4, 0.33)
    return np.tanh(x * 1.2)


def damage_taken():
    return np.tanh((lp(noise(0.25), 400) * 2 + sine(lambda t: 70 + 60 * np.exp(-t / 0.05), 0.25)) * env_exp(0.25, 0.06) * 1.5)


def death():
    return sine(lambda t: 300 * np.exp(-t / 0.4) + 60, 0.9) * env_exp(0.9, 0.3) * 0.7 + lp(noise(0.9), 300) * env_exp(0.9, 0.2) * 0.6


def spawn():
    x = np.zeros(int(SR * 0.6))
    for i, f in enumerate((523.3, 784, 1046.5)):
        place(x, sine(f, 0.4) * env_exp(0.4, 0.12, 0.01) * 0.4, i * 0.05)
    return x


# ---------------------------------------------------------------- match / UI
def tick():
    return (sine(1000, 0.12) + 0.3 * sine(2000, 0.12)) * env_exp(0.12, 0.04)


def go_horn():
    d = 1.0
    x = sum(signal.sawtooth(2 * np.pi * f * t_axis(d)) for f in (220, 277.2, 329.6, 440)) * 0.25
    x = lp(x, 2500) * np.clip(t_axis(d) / 0.02, 0, 1) * np.exp(-np.maximum(t_axis(d) - 0.55, 0) / 0.12)
    return x


def match_end():
    d = 1.4
    x = np.zeros(int(SR * d))
    for i, f in enumerate((392, 329.6, 261.6)):
        seg = lp(signal.sawtooth(2 * np.pi * f * t_axis(0.5)), 2000) * env_exp(0.5, 0.2, 0.01) * 0.5
        place(x, seg, i * 0.25)
    return x


def arpeggio(notes, step, length, wave="square", decay=0.18):
    x = np.zeros(int(SR * (step * len(notes) + length)))
    for i, f in enumerate(notes):
        tt = t_axis(length)
        osc = signal.square(2 * np.pi * f * tt) if wave == "square" else signal.sawtooth(2 * np.pi * f * tt, 0.5)
        place(x, lp(osc * 0.4 + np.sin(2 * np.pi * f * tt) * 0.6, 3500) * env_exp(length, decay, 0.005), i * step)
    return x


def victory():
    x = arpeggio((523.3, 659.3, 784, 1046.5, 1318.5), 0.09, 0.9, decay=0.3)
    chord = sum(np.sin(2 * np.pi * f * t_axis(1.4)) for f in (523.3, 659.3, 784, 1046.5)) * env_exp(1.4, 0.6, 0.02) * 0.4
    return place(np.concatenate([x, np.zeros(int(SR * 1.0))]), chord, 0.45)


def defeat():
    return arpeggio((392, 349.2, 311.1, 261.6), 0.16, 0.9, wave="tri", decay=0.35)


def ui_click():
    return (sine(1400, 0.05) * 0.6 + hp(noise(0.05), 4000) * 0.2) * env_exp(0.05, 0.01)


def ui_hover():
    return sine(2200, 0.04) * env_exp(0.04, 0.008) * 0.5


def vote():
    return arpeggio((880, 1318.5), 0.05, 0.2, decay=0.06)


def reward():
    return arpeggio((1318.5, 1760, 2637), 0.05, 0.25, wave="tri", decay=0.08)


def level_up():
    return arpeggio((523.3, 659.3, 784, 1046.5, 784, 1046.5, 1318.5), 0.07, 0.4, decay=0.15)


# ---------------------------------------------------------------- ambience + music
def loop_safe(x, xfade=1.0):
    n = int(SR * xfade)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    out = x[n:].copy()
    out[-n:] = tail * (1 - w) + head * w
    return out


def amb_warehouse():
    d = 21
    hum = sum(np.sin(2 * np.pi * f * t_axis(d)) * a for f, a in ((60, 0.3), (120, 0.18), (180, 0.06)))
    air = lp(noise(d), 700) * 0.5
    x = hum + air
    for at in rng.uniform(1, d - 2, 6):
        place(x, metal_click(0.6, (310, 620, 990), 0.25, 0.2) * 0.25, at)
    return loop_safe(x)


def amb_desert():
    d = 21
    w = bp(noise(d), 250, 1400)
    gust = 0.45 + 0.4 * np.sin(2 * np.pi * t_axis(d) / 7.0) + 0.15 * np.sin(2 * np.pi * t_axis(d) / 3.1)
    x = w * gust
    for at in rng.uniform(1, d - 2, 4):  # distant creaks
        place(x, sine(lambda t: 180 + 40 * np.sin(t * 9), 0.7) * env_exp(0.7, 0.3, 0.2) * 0.1, at)
    return loop_safe(x)


def amb_rooftops():
    d = 21
    traffic = lp(noise(d), 350) * 0.8 + bp(noise(d), 600, 1600) * 0.12
    x = traffic
    for at in rng.uniform(1, d - 2, 3):  # far horns
        place(x, lp(signal.square(2 * np.pi * 415 * t_axis(0.5)), 1200) * env_exp(0.5, 0.25, 0.03) * 0.05, at)
    return loop_safe(x)


def music_menu():
    bpm = 118
    beat = 60 / bpm
    bars = 8
    d = bars * 4 * beat
    x = np.zeros(int(SR * d) + SR)
    roots = [110, 110, 87.31, 98, 110, 110, 130.81, 98]  # A A F G A A C G
    for bar, root in enumerate(roots):
        for b in range(4):
            at = (bar * 4 + b) * beat
            kick = sine(lambda t: 50 + 90 * np.exp(-t / 0.03), 0.3) * env_exp(0.3, 0.09)
            place(x, kick * 0.9, at)
            if b % 2 == 1:
                place(x, hp(noise(0.2), 1500) * env_exp(0.2, 0.05) * 0.35, at)
            for s in range(2):
                hat = hp(noise(0.05), 7000) * env_exp(0.05, 0.012) * 0.15
                place(x, hat, at + s * beat / 2 + beat / 4)
            bass = lp(signal.sawtooth(2 * np.pi * root * t_axis(beat * 0.9)), 700) * env_exp(beat * 0.9, 0.18, 0.005)
            place(x, bass * 0.45, at)
        chord = sum(lp(signal.sawtooth(2 * np.pi * root * m * 2 * t_axis(beat * 4)), 1800) for m in (1, 1.25 if bar % 4 != 2 else 1.2, 1.5))
        place(x, chord * env_exp(beat * 4, 1.2, 0.08) * 0.08, bar * 4 * beat)
        if bar % 2 == 0:
            lead = arpeggio([root * 4 * m for m in (1, 1.5, 2, 1.5, 1.25, 1.5)], beat / 2, beat / 2, decay=0.1)
            place(x, lead * 0.12, bar * 4 * beat + 2 * beat)
    return x[: int(SR * d)]


SOUNDS = {
    "Fire": shotgun_fire,
    "Pump": pump_cycle,
    "Equip": equip,
    "Swap": swap,
    "ShellInsert": shell_insert,
    "ReloadStart": reload_start,
    "EmptyClick": empty_click,
    "ShellBounce": shell_bounce,
    "HitBody": hit_body,
    "HitHead": hit_head,
    "Elimination": elimination,
    "DoublePumpElim": double_pump_elim,
    "DamageTaken": damage_taken,
    "Death": death,
    "Spawn": spawn,
    "CountdownTick": tick,
    "MatchStart": go_horn,
    "MatchEnd": match_end,
    "Victory": victory,
    "Defeat": defeat,
    "UIClick": ui_click,
    "UIHover": ui_hover,
    "Vote": vote,
    "Reward": reward,
    "LevelUp": level_up,
    "AmbWarehouse": amb_warehouse,
    "AmbDustTown": amb_desert,
    "AmbRooftops": amb_rooftops,
    "MusicMenu": music_menu,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = fn()
        peak = 0.5 if name.startswith("Amb") else 0.8 if name.startswith("Music") else 0.92
        save(name, x, peak)
        print(f"{name:16s} {len(x) / SR:6.2f} s")
