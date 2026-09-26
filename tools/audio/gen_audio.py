"""Every sound in the building, synthesised: relays, rings, the tube with a
tick in it, rain on a skylight, the council's hold tune, the Casio, shoes on
tile. Written as small mono OGG files into assets/audio/, plus captions.json.

    python3 tools/audio/gen_audio.py            # everything
    python3 tools/audio/gen_audio.py ring knock # just these

Everything is deliberately a bit cheap: 32 kHz, band-limited, some hiss.
"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(247)

NOTE = {"A4": 440.0, "B4": 493.88, "Cs5": 554.37, "D5": 587.33, "E5": 659.25, "Fs5": 739.99, "Gs5": 830.61, "A5": 880.0}


# ------------------------------------------------------------------ tools

def t_(sec):
    return np.arange(int(sec * SR)) / SR


def silence(sec):
    return np.zeros(int(sec * SR))


def white(sec):
    return rng.standard_normal(int(sec * SR))


def pink(sec):
    n = int(sec * SR)
    x = rng.standard_normal(n)
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(n, 1 / SR)
    fr[0] = 1.0
    f /= np.sqrt(fr)
    y = np.fft.irfft(f, n)
    return y / (np.abs(y).max() + 1e-9)


def brown(sec):
    y = np.cumsum(rng.standard_normal(int(sec * SR)))
    y = signal.sosfilt(signal.butter(1, 20, "hp", fs=SR, output="sos"), y)
    return y / (np.abs(y).max() + 1e-9)


def lp(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, "lp", fs=SR, output="sos"), x)


def hp(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, "hp", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], "bp", fs=SR, output="sos"), x)


def env_exp(sec, decay, attack=0.002):
    t = t_(sec)
    e = np.exp(-t / max(decay, 1e-4))
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return e * a


def fade(x, fin=0.01, fout=0.05):
    n = len(x)
    a = int(fin * SR)
    b = int(fout * SR)
    y = x.copy()
    if a > 0:
        y[:a] *= np.linspace(0, 1, a)
    if b > 0:
        y[-b:] *= np.linspace(1, 0, b)
    return y


def mix(*xs):
    """Sum sounds of different lengths."""
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[: len(x)] += x
    return out


def place(buf, snd, at, gain=1.0):
    i = int(at * SR)
    if i >= len(buf):
        return buf
    j = min(len(buf), i + len(snd))
    buf[i:j] += snd[: j - i] * gain
    return buf


def reverb(x, sec, damp=6000.0, wet=0.3, pre=0.01):
    """Convolution with decaying filtered noise: a cheap room."""
    ir = white(sec) * np.exp(-t_(sec) * (6.9 / sec))
    ir = lp(ir, damp)
    ir[: int(pre * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - wet) + y * wet * 1.6


def norm(x, peak=0.8):
    m = np.abs(x).max()
    return x if m < 1e-9 else x / m * peak


def loop_seamless(x, xf=1.0):
    """Crossfade the tail into the head so the bed loops without a click."""
    n = int(xf * SR)
    head = x[:n].copy()
    tail = x[-n:].copy()
    w = np.linspace(0, 1, n)
    y = x[: len(x) - n].copy()
    y[:n] = tail * (1 - w) + head * w
    return y


def save(name, x, peak=0.8, loop=False, xf=1.0):
    if loop:
        x = loop_seamless(x, xf)
    x = norm(np.nan_to_num(x), peak)
    path = os.path.join(OUT, name + ".ogg")
    sf.write(path, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote", name, "%.1fs" % (len(x) / SR))


def tone(freq, sec, kind="sine", vib=0.0, vib_hz=5.0):
    t = t_(sec)
    f = freq * (1 + vib * np.sin(2 * np.pi * vib_hz * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.7
    if kind == "pulse":
        return np.where((ph / (2 * np.pi)) % 1 < 0.28, 1.0, -0.4)
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1
    raise ValueError(kind)


def hum(sec, base=50.0, harmonics=(1, 2, 3, 4, 6), amps=(1, 0.6, 0.35, 0.2, 0.1), drift=0.2):
    t = t_(sec)
    y = np.zeros_like(t)
    for h, a in zip(harmonics, amps):
        y += a * np.sin(2 * np.pi * base * h * t + drift * np.sin(2 * np.pi * 0.13 * t * h))
    return y


def click(decay=0.004, color=3000, sec=0.04):
    c = white(sec) * env_exp(sec, decay, 0.0003)
    return bp(c, color * 0.5, min(color * 2.0, SR / 2 - 100))


def relay_click():
    """A relay: a hard tick with a metallic ring after it."""
    sec = 0.09
    t = t_(sec)
    tick = click(0.0025, rng.uniform(2500, 5000), sec)
    ring = np.sin(2 * np.pi * rng.uniform(1800, 3600) * t) * env_exp(sec, 0.012) * 0.25
    return tick + ring


def thud(freq=90, sec=0.25, decay=0.06):
    t = t_(sec)
    f = freq * (1 + 1.5 * np.exp(-t / 0.01))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(sec, decay, 0.001)
    return body + lp(white(sec), 900) * env_exp(sec, decay * 0.4, 0.0005) * 0.6


def tape_wobble(x, depth=0.0025, rate=0.7):
    """Wow and flutter: resample along a wobbling time base."""
    n = len(x)
    t = np.arange(n)
    wob = depth * SR * (np.sin(2 * np.pi * rate * t / SR) + 0.3 * np.sin(2 * np.pi * 6.1 * t / SR))
    idx = np.clip(t + wob, 0, n - 1)
    return np.interp(idx, t, x)


# ------------------------------------------------------------------ effects

def fx_relay_burst():
    buf = silence(1.6)
    at = 0.02
    while at < 1.4:
        buf = place(buf, relay_click(), at, rng.uniform(0.4, 1.0))
        at += rng.choice([0.018, 0.03, 0.05, 0.11, 0.2], p=[0.35, 0.3, 0.2, 0.1, 0.05])
    return reverb(buf, 0.4, 5000, 0.2)


def ring_phrase(notes, cut_last=True):
    out = []
    for i, n in enumerate(notes):
        dur = 0.22 if not (cut_last and i == len(notes) - 1) else 0.09
        x = (tone(NOTE[n], dur, "pulse") * 0.6 + tone(NOTE[n] * 2, dur, "sine") * 0.2)
        x = fade(x, 0.004, 0.02) * (1.0 if dur > 0.1 else 0.9)
        out.append(x)
        out.append(silence(0.04))
    return np.concatenate(out)


def fx_ring():
    one = ring_phrase(["E5", "Cs5", "D5"])
    buf = silence(6.0)
    for at in [0.0, 0.5, 2.6, 3.1]:
        buf = place(buf, one, at)
    buf = lp(hp(buf, 300), 3800)
    return reverb(buf, 0.35, 4000, 0.15)


def fx_ring_out():
    buf = silence(6.4)
    t = t_(0.4)
    burst = (np.sin(2 * np.pi * 400 * t) + np.sin(2 * np.pi * 450 * t)) * 0.5
    burst = fade(burst, 0.01, 0.02)
    for cyc in range(3):
        at = cyc * 3.0
        buf = place(buf, burst, at)
        buf = place(buf, burst, at + 0.6)
    return lp(hp(buf, 300), 3400)


def fx_pickup():
    buf = silence(0.5)
    buf = place(buf, click(0.006, 1500, 0.08), 0.0, 1.0)
    buf = place(buf, thud(160, 0.2, 0.03) * 0.5, 0.03)
    buf = place(buf, lp(white(0.25), 2000) * env_exp(0.25, 0.08) * 0.3, 0.05)
    return buf


def fx_hangup():
    buf = silence(0.6)
    buf = place(buf, thud(120, 0.4, 0.07), 0.0)
    buf = place(buf, click(0.004, 2400, 0.06) * 0.7, 0.01)
    buf = place(buf, click(0.003, 3000, 0.05) * 0.4, 0.09)
    return buf


def fx_plug_in():
    buf = silence(0.4)
    scrape = bp(white(0.12), 2000, 6000) * env_exp(0.12, 0.05) * 0.5
    buf = place(buf, scrape, 0.0)
    buf = place(buf, click(0.003, 3500, 0.05), 0.1, 1.2)
    buf = place(buf, thud(300, 0.12, 0.02) * 0.4, 0.1)
    return buf


def fx_plug_out():
    buf = silence(0.35)
    buf = place(buf, click(0.003, 3000, 0.05), 0.0, 1.0)
    scrape = bp(white(0.1), 2000, 6000) * env_exp(0.1, 0.04) * 0.4
    buf = place(buf, scrape, 0.02)
    return buf


def fx_key_throw():
    buf = silence(0.35)
    buf = place(buf, click(0.004, 1800, 0.06), 0.0, 1.0)
    buf = place(buf, thud(140, 0.25, 0.04) * 0.9, 0.005)
    buf = place(buf, click(0.003, 4000, 0.04) * 0.4, 0.05)
    return reverb(buf, 0.25, 4000, 0.15)


def fx_key_dead():
    buf = silence(0.3)
    buf = place(buf, thud(70, 0.25, 0.05), 0.0)
    return lp(buf, 1200)


def fx_door_buzz():
    t = t_(1.3)
    buzz = np.sign(np.sin(2 * np.pi * 50 * t)) * 0.5 + np.sin(2 * np.pi * 100 * t) * 0.3
    buzz = bp(buzz, 80, 2500) * fade(np.ones_like(t), 0.02, 0.05)
    buf = np.concatenate([buzz, silence(0.5)])
    buf = place(buf, thud(110, 0.4, 0.06) * 1.2, 1.3)
    buf = place(buf, click(0.004, 2000, 0.06), 1.31)
    return buf


def fx_knock():
    buf = silence(1.6)
    for at in [0.0, 0.42, 0.84]:
        k = mix(thud(95, 0.3, 0.05), lp(click(0.005, 900, 0.08), 1500) * 0.6)
        buf = place(buf, k, at, 1.0)
    return reverb(buf, 0.5, 3000, 0.25)


def fx_lamp_switch():
    buf = silence(1.4)
    buf = place(buf, thud(80, 0.35, 0.05) * 1.0, 0.0)
    buf = place(buf, click(0.004, 1400, 0.06) * 0.8, 0.0)
    t = t_(1.3)
    h = hum(1.3, 50, (2, 4, 6), (1, 0.4, 0.2)) * np.clip(t / 0.9, 0, 1) * 0.35
    buf = place(buf, h, 0.08)
    return reverb(buf, 1.6, 3000, 0.4)


def fx_paper():
    buf = silence(0.7)
    at = 0.0
    while at < 0.5:
        n = int(rng.uniform(0.02, 0.08) * SR)
        crk = bp(white(n / SR), 1500, 7000) * env_exp(n / SR, n / SR / 3)
        buf = place(buf, crk, at, rng.uniform(0.3, 1.0))
        at += rng.uniform(0.02, 0.06)
    return buf


def fx_printer():
    buf = silence(1.8)
    at = 0.0
    while at < 1.6:
        # a head pass: a quick run of pin strikes
        for k in range(rng.integers(12, 22)):
            buf = place(buf, bp(white(0.006), 1500, 6000) * env_exp(0.006, 0.0015), at, rng.uniform(0.4, 0.9))
            at += 0.0065
        at += rng.uniform(0.06, 0.14)
        buf = place(buf, thud(200, 0.08, 0.015) * 0.4, at)
    motor = lp(white(1.8), 400) * 0.06
    return buf + motor


def fx_tape_click():
    buf = silence(0.3)
    buf = place(buf, click(0.003, 2600, 0.05), 0.0, 1.0)
    buf = place(buf, thud(250, 0.1, 0.02) * 0.4, 0.004)
    return buf


def fx_tape_play():
    buf = silence(1.4)
    buf = place(buf, fx_tape_click(), 0.0)
    t = t_(1.3)
    motor = (np.sin(2 * np.pi * (60 + 40 * np.clip(t / 0.4, 0, 1)) * t) * 0.15 + lp(white(1.3), 800) * 0.2) * np.clip(t / 0.3, 0, 1)
    buf = place(buf, motor, 0.06)
    return buf


def fx_stamp():
    buf = silence(0.5)
    buf = place(buf, thud(110, 0.4, 0.05), 0.0)
    buf = place(buf, lp(click(0.004, 800, 0.05), 1500), 0.0, 0.6)
    return reverb(buf, 0.3, 3000, 0.2)


def fx_tick():
    return click(0.0012, 4000, 0.02)


def fx_click():
    buf = silence(0.1)
    buf = place(buf, click(0.002, 2500, 0.04), 0.0)
    buf = place(buf, thud(400, 0.05, 0.008) * 0.3, 0.0)
    return buf


def fx_type_tick():
    buf = silence(0.2)
    for at in [0.0, 0.05, 0.09]:
        buf = place(buf, bp(white(0.008), 2000, 6000) * env_exp(0.008, 0.002), at, rng.uniform(0.5, 1.0))
    return buf


def fx_flap():
    buf = silence(0.25)
    buf = place(buf, click(0.003, 3000, 0.04), 0.0, 1.0)
    buf = place(buf, click(0.002, 4500, 0.03) * 0.6, 0.03)
    return buf


def fx_view_open():
    sec = 1.4
    t = t_(sec)
    sweep = bp(pink(sec), 200, 6000)
    e = np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 2
    sh = np.sin(2 * np.pi * (220 + 180 * t / sec) * t) * 0.15
    return (sweep * 0.6 + sh) * e


def fx_water_tremble():
    sec = 2.2
    buf = silence(sec)
    buf = place(buf, thud(60, 0.4, 0.08) * 0.8, 0.0)
    buf = place(buf, thud(55, 0.4, 0.08) * 0.6, 0.35)
    g = lp(brown(1.8), 500) * np.sin(np.pi * t_(1.8) / 1.8) * 0.8
    buf = place(buf, g, 0.3)
    for i in range(14):
        b = np.sin(2 * np.pi * rng.uniform(300, 900) * t_(0.05)) * env_exp(0.05, 0.012)
        buf = place(buf, b * 0.3, rng.uniform(0.4, 2.0))
    return hp(reverb(buf, 1.2, 4000, 0.35), 30)


def fx_rupture():
    sec = 3.0
    t = t_(sec)
    swell = pink(sec) * np.clip(t / 1.4, 0, 1) ** 2
    drone = sum(np.sin(2 * np.pi * f * t) for f in (55, 110, 164.8, 220)) * 0.2 * np.clip(t / 1.2, 0, 1)
    x = (swell * 0.7 + drone)
    cut = int(1.5 * SR)
    x[cut:] *= np.exp(-(t[cut:] - 1.5) / 0.04)
    return reverb(x, 2.0, 5000, 0.3)


def fx_chapter():
    buf = silence(2.0)
    buf = place(buf, thud(55, 0.8, 0.2), 0.0)
    buf = place(buf, relay_click() * 0.8, 0.0)
    buf = place(buf, hum(1.8, 50, (1, 2, 3), (1, 0.5, 0.2)) * env_exp(1.8, 0.7) * 0.25, 0.05)
    return reverb(buf, 1.2, 3000, 0.3)


def fx_board_open():
    buf = silence(0.8)
    buf = place(buf, thud(130, 0.3, 0.05) * 0.8, 0.0)
    at = 0.08
    for i in range(5):
        buf = place(buf, relay_click() * 0.5, at)
        at += rng.uniform(0.03, 0.1)
    return buf


def fx_hold_on():
    buf = silence(1.2)
    for at, n in [(0.0, "E5"), (0.25, "Cs5")]:
        x = tone(NOTE[n], 0.6, "sine") * env_exp(0.6, 0.25, 0.01) + tone(NOTE[n] * 2, 0.6, "sine") * env_exp(0.6, 0.12, 0.01) * 0.3
        buf = place(buf, x * 0.6, at)
    return lp(buf, 3500)


def fx_casio(n):
    sec = 1.3
    f = NOTE[n]
    x = tone(f, sec, "pulse") * 0.5 + tone(f * 1.003, sec, "pulse") * 0.35 + tone(f * 2, sec, "sine") * 0.15
    e = env_exp(sec, 0.45, 0.004) * 0.85 + 0.15 * env_exp(sec, 0.08, 0.002)
    x = lp(x * e, 5000)
    x = fade(x, 0.002, 0.08)
    return reverb(x, 0.5, 3500, 0.2)


def fx_step(kind, k):
    sec = 0.22
    if kind == "tile":
        x = click(0.006, rng.uniform(1600, 2400), sec) * 1.0 + thud(rng.uniform(160, 220), sec, 0.018) * 0.5
        x = reverb(x, 0.6, 5000, 0.25)
    else:
        x = lp(thud(rng.uniform(90, 130), sec, 0.03) + lp(white(sec), 1200) * env_exp(sec, 0.02) * 0.6, 1600)
    return x * rng.uniform(0.8, 1.0)


def fx_scuff():
    return bp(white(0.3), 800, 4000) * env_exp(0.3, 0.1, 0.03) * 0.5


# ------------------------------------------------------------------ rooms (loops)

def events(sec, make, rate, gain=(0.5, 1.0)):
    buf = silence(sec)
    at = rng.uniform(0, 1 / rate)
    while at < sec - 0.5:
        buf = place(buf, make(), at, rng.uniform(*gain))
        at += rng.exponential(1 / rate)
    return buf


def room_tone(sec, lp_hz=600, level=0.25):
    return lp(pink(sec), lp_hz) * level


def amb_line_dark():
    sec = 24
    x = hum(sec, 50, (1, 2, 3), (0.4, 0.25, 0.1)) * 0.12
    x += lp(white(sec), 6000) * 0.02
    x += events(sec, relay_click, 0.6, (0.05, 0.2))
    return reverb(x, 0.8, 3000, 0.3)


def amb_street_night():
    sec = 30
    wind = lp(pink(sec), 350) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t_(sec)) ** 2)
    traffic = lp(brown(sec), 180) * 0.4
    x = wind * 0.5 + traffic
    # a bus passing
    bt = t_(7.0)
    bus = lp(brown(7.0), 250) * np.sin(np.pi * bt / 7.0) ** 3 * 1.2 + np.sin(2 * np.pi * 45 * bt) * 0.1 * np.sin(np.pi * bt / 7.0) ** 3
    x = place(x, bus, 12.0)
    x += hum(sec, 100, (1, 3), (0.2, 0.05)) * 0.03
    x += events(sec, lambda: click(0.01, 1200, 0.1) * 0.6, 0.08, (0.1, 0.3))
    return x


def amb_tube(sec, tick=True):
    t = t_(sec)
    buzz = hum(sec, 100, (1, 2, 3, 5, 7), (1, 0.5, 0.3, 0.15, 0.08)) * 0.12
    buzz += bp(white(sec), 3000, 9000) * 0.012
    if tick:
        # the starter trying, once a second
        for k in range(int(sec)):
            buzz = place(buzz, click(0.004, 3200, 0.05) * 0.5, k + 0.02)
            buzz[int((k + 0.02) * SR): int((k + 0.08) * SR)] *= 0.6
    return buzz


def amb_lobby_hum():
    sec = 24
    x = amb_tube(sec, True)
    comp = hum(sec, 48, (1, 2, 3), (1, 0.6, 0.3)) * 0.06 * (0.5 + 0.5 * (np.sin(2 * np.pi * t_(sec) / sec) > -0.3))
    x += comp + room_tone(sec, 400, 0.08)
    return reverb(x, 0.9, 4000, 0.25)


def amb_lobby_morning():
    sec = 24
    x = room_tone(sec, 900, 0.2) + lp(brown(sec), 200) * 0.25
    def bird():
        n = rng.integers(2, 5)
        out = []
        for i in range(n):
            f0 = rng.uniform(2500, 4200)
            d = rng.uniform(0.05, 0.12)
            tt = t_(d)
            out.append(np.sin(2 * np.pi * (f0 + 900 * tt / d) * tt) * np.sin(np.pi * tt / d) * 0.3)
            out.append(silence(rng.uniform(0.03, 0.08)))
        return np.concatenate(out)
    x += lp(events(sec, bird, 0.25, (0.1, 0.25)), 5000)
    return reverb(x, 0.8, 4000, 0.2)


def amb_office_room():
    sec = 24
    x = room_tone(sec, 500, 0.15) + hum(sec, 50, (1, 2), (0.3, 0.2)) * 0.03
    x += events(sec, lambda: click(0.004, 2500, 0.05) * 0.3, 0.1, (0.05, 0.15))
    return reverb(x, 0.4, 3000, 0.15)


def amb_building_night():
    sec = 30
    x = lp(brown(sec), 150) * 0.3 + room_tone(sec, 300, 0.1)
    # the lift motor through the wall
    lt = t_(6.0)
    lift = (hum(6.0, 45, (1, 2, 3), (1, 0.5, 0.3)) * 0.12 + lp(white(6.0), 300) * 0.1) * np.sin(np.pi * lt / 6.0) ** 2
    x = place(x, lift, 8.0)
    # water in pipes
    def pipe():
        d = rng.uniform(0.8, 2.0)
        return lp(white(d), 700) * np.sin(np.pi * t_(d) / d) * 0.3
    x += events(sec, pipe, 0.12, (0.2, 0.5))
    # a distant television
    tv = bp(pink(sec), 300, 2500) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 2.3 * t_(sec)))) * 0.03
    x += tv
    return reverb(x, 1.2, 2500, 0.3)


def amb_flat_night():
    sec = 24
    x = room_tone(sec, 600, 0.12)
    # the radio, low: speech-shaped noise, syllables
    syl = np.zeros(int(sec * SR))
    at = 0.0
    while at < sec - 0.3:
        d = rng.uniform(0.08, 0.22)
        s = bp(white(d), rng.uniform(250, 500), rng.uniform(1500, 2800)) * np.sin(np.pi * t_(d) / d)
        syl = place(syl, s, at, rng.uniform(0.3, 1.0))
        at += d + (rng.uniform(0.02, 0.08) if rng.random() < 0.85 else rng.uniform(0.3, 0.7))
    x += lp(syl, 3000) * 0.06
    return reverb(x, 0.5, 3000, 0.2)


def amb_nell_bath():
    sec = 20
    fan = bp(white(sec), 150, 1500) * 0.1 + hum(sec, 75, (1, 2), (1, 0.4)) * 0.04
    drip = events(sec, lambda: np.sin(2 * np.pi * rng.uniform(900, 1400) * t_(0.06)) * env_exp(0.06, 0.012), 0.35, (0.2, 0.5))
    return reverb(fan + drip, 0.9, 6000, 0.35)


def amb_exchange_relays():
    sec = 30
    x = hum(sec, 50, (1, 2, 3, 4), (0.5, 0.3, 0.2, 0.1)) * 0.08
    x += bp(white(sec), 200, 2000) * 0.03
    # relays: runs of clicks, sometimes bursts
    buf = silence(sec)
    at = 0.2
    while at < sec - 1:
        if rng.random() < 0.18:
            for i in range(rng.integers(4, 14)):
                buf = place(buf, relay_click(), at, rng.uniform(0.2, 0.6))
                at += rng.uniform(0.015, 0.05)
        else:
            buf = place(buf, relay_click(), at, rng.uniform(0.1, 0.4))
        at += rng.exponential(0.5)
    x += buf * 0.5
    return reverb(x, 0.9, 5000, 0.35)


def amb_pool_hall():
    sec = 30
    x = lp(pink(sec), 200) * 0.15 + lp(brown(sec), 90) * 0.2
    drip = events(sec, lambda: np.sin(2 * np.pi * rng.uniform(700, 1200) * t_(0.05)) * env_exp(0.05, 0.01), 0.2, (0.2, 0.6))
    creak = events(sec, lambda: bp(white(0.4), 200, 800) * np.sin(np.pi * t_(0.4) / 0.4) * 0.4, 0.04, (0.1, 0.3))
    return reverb(x + drip + creak, 2.8, 4000, 0.55)


def amb_pool_lamps():
    sec = 12
    t = t_(sec)
    flutter = 0.8 + 0.2 * np.sin(2 * np.pi * 7.3 * t) * (np.sin(2 * np.pi * 0.31 * t) > 0.3)
    x = hum(sec, 100, (1, 2, 3, 4, 6), (1, 0.6, 0.4, 0.2, 0.1)) * flutter * 0.25
    return reverb(x, 2.0, 3000, 0.45)


def amb_receiving_room():
    sec = 24
    x = hum(sec, 50, (1, 2), (0.4, 0.2)) * 0.04 + room_tone(sec, 400, 0.08)
    drip = events(sec, lambda: np.sin(2 * np.pi * rng.uniform(1100, 1500) * t_(0.05)) * env_exp(0.05, 0.01), 0.25, (0.3, 0.6))
    def pipe():
        d = rng.uniform(1.0, 2.5)
        return lp(white(d), 500) * np.sin(np.pi * t_(d) / d) * 0.25
    x += drip + events(sec, pipe, 0.08, (0.2, 0.4))
    return reverb(x, 1.6, 6000, 0.45)


def amb_copyshop():
    sec = 24
    x = bp(white(sec), 200, 3000) * 0.05 + amb_tube(sec, False) * 0.6
    def sweep():
        d = 2.2
        return (hum(d, 60, (1, 2), (1, 0.5)) * 0.2 + bp(white(d), 1000, 4000) * 0.08) * np.sin(np.pi * t_(d) / d)
    x += events(sec, sweep, 0.07, (0.4, 0.8))
    return reverb(x, 0.7, 4000, 0.2)


def amb_bakery():
    sec = 24
    roar = lp(pink(sec), 700) * 0.35 + hum(sec, 60, (1, 2, 3), (1, 0.5, 0.3)) * 0.05
    mixer = np.sin(2 * np.pi * 1.1 * t_(sec)) * lp(brown(sec), 300) * 0.15
    clank = events(sec, lambda: mix(thud(rng.uniform(300, 600), 0.2, 0.04) * 0.4, click(0.01, 2000, 0.1) * 0.5), 0.15, (0.2, 0.5))
    return reverb(roar + mixer + clank, 0.9, 3500, 0.25)


def amb_kaye_kitchen():
    sec = 24
    x = room_tone(sec, 500, 0.08) + hum(sec, 50, (1, 2, 3), (0.5, 0.3, 0.1)) * 0.05
    for k in range(sec):
        x = place(x, click(0.003, 3000, 0.03) * 0.25, k + 0.1)
    return reverb(x, 0.4, 4000, 0.15)


def amb_fog_morning():
    sec = 30
    x = lp(brown(sec), 150) * 0.25 + lp(pink(sec), 400) * 0.08
    def gull():
        d = rng.uniform(0.3, 0.6)
        tt = t_(d)
        return np.sin(2 * np.pi * (1300 - 500 * tt / d) * tt) * np.sin(np.pi * tt / d) * 0.25
    x += lp(events(sec, gull, 0.05, (0.05, 0.12)), 3000)
    return reverb(x, 1.5, 3000, 0.4)


def amb_title_room():
    sec = 30
    x = amb_pool_hall() * 0.6
    x = x[: int(sec * SR)] if len(x) >= int(sec * SR) else np.pad(x, (0, int(sec * SR) - len(x)))
    x += events(sec, relay_click, 0.2, (0.05, 0.15))
    x += hum(sec, 50, (1, 2), (0.3, 0.2)) * 0.03
    return x


# ------------------------------------------------------------------ the hold tapes

def mus_hold_tape():
    # the council's organ: four notes and round again, cheap and bright
    notes = ["E5", "Cs5", "D5", "B4"]
    beat = 0.5
    phrase = []
    for n in notes:
        f = NOTE[n]
        d = beat * (2 if n == "B4" else 1)
        x = (tone(f, d, "saw") * 0.3 + tone(f / 2, d, "square") * 0.3 + tone(f * 2, d, "sine") * 0.15 + tone(f * 1.5, d, "sine") * 0.1)
        x *= np.clip(t_(d) / 0.02, 0, 1) * (0.85 + 0.15 * np.sin(2 * np.pi * 5.5 * t_(d)))
        phrase.append(fade(x, 0.005, 0.03))
    bar = np.concatenate(phrase + [silence(0.5)])
    # a little bass under it, root and fifth
    y = np.concatenate([bar] * 4)
    y = lp(y, 3200)
    y = tape_wobble(y, 0.002, 0.6)
    y += lp(white(len(y) / SR), 7000) * 0.03
    return y


def mus_hold_rain():
    sec = 30
    base = lp(pink(sec), 3000) * 0.3 + hp(white(sec), 2000) * 0.08
    def drop():
        d = rng.uniform(0.01, 0.03)
        return hp(white(d), 1500) * env_exp(d, d / 3)
    drops = events(sec, drop, 60.0, (0.1, 0.5))
    heavy = events(sec, lambda: click(0.01, 1200, 0.08), 1.2, (0.2, 0.6))
    x = base + drops * 0.6 + heavy * 0.5
    x = tape_wobble(reverb(x, 1.2, 5000, 0.3), 0.0015, 0.5)
    return x + lp(white(sec), 6000) * 0.02


def mus_hold_lamps():
    return amb_pool_lamps() * 1.0 + lp(white(12), 5000) * 0.01


# ------------------------------------------------------------------ table

SFX = {
    "relay_burst": fx_relay_burst, "ring": fx_ring, "ring_out": fx_ring_out, "pickup": fx_pickup,
    "hangup": fx_hangup, "plug_in": fx_plug_in, "plug_out": fx_plug_out, "patch_in": fx_plug_in,
    "patch_out": fx_plug_out, "key_throw": fx_key_throw, "key_dead": fx_key_dead, "door_buzz": fx_door_buzz,
    "knock": fx_knock, "lamp_switch": fx_lamp_switch, "paper": fx_paper, "printer": fx_printer,
    "tape_click": fx_tape_click, "tape_play": fx_tape_play, "stamp": fx_stamp, "tick": fx_tick,
    "click": fx_click, "type_tick": fx_type_tick, "flap": fx_flap, "view_open": fx_view_open,
    "water_tremble": fx_water_tremble, "rupture": fx_rupture, "chapter": fx_chapter,
    "board_open": fx_board_open, "hold_on": fx_hold_on, "scuff": fx_scuff,
}
for _n in NOTE:
    SFX["casio_" + _n] = (lambda n=_n: fx_casio(n))
for _k in range(1, 5):
    SFX["step_tile_%d" % _k] = (lambda k=_k: fx_step("tile", k))
    SFX["step_soft_%d" % _k] = (lambda k=_k: fx_step("soft", k))

AMB = {
    "line_dark": amb_line_dark, "street_night": amb_street_night, "lobby_hum": amb_lobby_hum,
    "lobby_morning": amb_lobby_morning, "office_room": amb_office_room, "building_night": amb_building_night,
    "flat_night": amb_flat_night, "nell_bath": amb_nell_bath, "exchange_relays": amb_exchange_relays,
    "pool_hall": amb_pool_hall, "pool_lamps": amb_pool_lamps, "receiving_room": amb_receiving_room,
    "copyshop": amb_copyshop, "bakery": amb_bakery, "kaye_kitchen": amb_kaye_kitchen,
    "fog_morning": amb_fog_morning, "title_room": amb_title_room,
}
MUSIC = {"hold_tape": mus_hold_tape, "hold_rain": mus_hold_rain, "hold_lamps": mus_hold_lamps}

CAPTIONS = {
    "line_dark": "Relays, a long way off, and a hum under them.",
    "street_night": "Wind on a microphone. Traffic somewhere behind it.",
    "lobby_hum": "The tube over the desk hums, with a tick in it, once a second.",
    "lobby_morning": "The lobby in daylight: a door, the road, a bird that's got in somewhere.",
    "office_room": "A small room with a cold floor. Nothing much. The lamp.",
    "building_night": "The building at night: pipes, a lift motor through a wall, a television two floors up.",
    "flat_night": "A radio, low, reading the late news to nobody.",
    "nell_bath": "A bathroom fan. A tap that drips.",
    "exchange_relays": "The frame: relays clicking in runs, and the hum of it.",
    "pool_hall": "The pool hall: a huge dry room, drips landing on nothing.",
    "pool_lamps": "The pool lamps' ballasts, humming, one of them fluttering.",
    "receiving_room": "A tiled room, colder than the pool. Water somewhere in the walls.",
    "copyshop": "Copier fans. A strip light.",
    "bakery": "Ovens roaring. A mixer turning over.",
    "kaye_kitchen": "A kitchen clock. A fridge.",
    "fog_morning": "Fog. The city muffled. A gull.",
    "title_room": "",
}


def main(only):
    todo = []
    for table, loop, peak in [(SFX, False, 0.8), (AMB, True, 0.5), (MUSIC, True, 0.6)]:
        for name, fn in table.items():
            if only and name not in only:
                continue
            todo.append((name, fn, loop, peak))
    for name, fn, loop, peak in todo:
        x = fn()
        save(name, x, peak=peak, loop=loop, xf=1.0 if loop else 0.0)
    with open(os.path.join(OUT, "captions.json"), "w") as f:
        json.dump({k: v for k, v in CAPTIONS.items() if v}, f, indent=1)
    print("captions.json")


if __name__ == "__main__":
    main(set(sys.argv[1:]))
