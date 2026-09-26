"""Low-fidelity surfaces for the interface: steel, rust, bakelite, grime,
and the pixel cursors. Everything is small, tiling, posterised and
ordered-dithered, so it reads as old hardware at 640x360 and not as a
render.

    python3 tools/art/gen_grim.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "grim")
os.makedirs(OUT, exist_ok=True)

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], float) / 16.0 - 0.47


def noise(n, power, seed):
    """Periodic 1/f^power noise in [0, 1], n x n, tiles seamlessly."""
    r = np.random.default_rng(seed)
    white = r.normal(size=(n, n))
    f = np.fft.fft2(white)
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    rad = np.sqrt(fx * fx + fy * fy)
    rad[0, 0] = 1.0
    f /= rad ** power
    out = np.real(np.fft.ifft2(f))
    out -= out.min()
    out /= out.max()
    return out


def scratches(n, count, seed, length=(6, 40)):
    r = np.random.default_rng(seed)
    m = np.zeros((n, n))
    for _ in range(count):
        x, y = r.uniform(0, n, 2)
        a = r.uniform(0, np.pi) if r.random() < 0.5 else r.normal(0.1, 0.2)
        ln = r.uniform(*length)
        v = r.uniform(0.4, 1.0) * (1 if r.random() < 0.7 else -1)
        for t in np.linspace(0, ln, int(ln * 2)):
            px = int(x + np.cos(a) * t) % n
            py = int(y + np.sin(a) * t) % n
            m[py, px] = v
    return m


def quantise(rgb, levels, dither=1.0):
    """Posterise each channel to `levels` steps with a 4x4 Bayer matrix."""
    h, w, _ = rgb.shape
    th = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w, None] * dither
    q = np.floor(rgb / 255.0 * (levels - 1) + 0.5 + th)
    return np.clip(q / (levels - 1) * 255.0, 0, 255).astype(np.uint8)


def mix(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


def col(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def save(arr, name):
    Image.fromarray(arr).save(os.path.join(OUT, name))
    print("wrote", name, arr.shape)


def steel(n=128):
    base = col("3a3833")
    lo = noise(n, 1.6, 1)
    hi = noise(n, 0.6, 2)
    streak = noise(n, 1.2, 3)
    img = np.ones((n, n, 3)) * base
    img += ((lo - 0.5) * 34)[..., None]
    img += ((hi - 0.5) * 14)[..., None]
    # brushed: horizontal smear
    sm = np.roll(streak, 1, axis=1) + streak + np.roll(streak, -1, axis=1) + np.roll(streak, 2, axis=1)
    img += ((sm / 4 - 0.5) * 10)[..., None]
    s = scratches(n, 60, 4)
    img += (s * 28)[..., None]
    # oily grime pooling
    g = np.clip((noise(n, 1.9, 5) - 0.55) * 3.0, 0, 1)
    img = mix(img, col("1b1a17"), g * 0.8)
    return quantise(np.clip(img, 0, 255), 12)


def rust(n=128):
    st = steel(n).astype(float)
    m = noise(n, 1.7, 11)
    pit = noise(n, 0.4, 12)
    mask = np.clip((m - 0.46) * 4.0, 0, 1)
    rc = mix(np.ones((n, n, 3)) * col("6b3420"), np.ones((n, n, 3)) * col("a4582c"), pit)
    rc = mix(rc, np.ones((n, n, 3)) * col("2e160d"), np.clip((pit - 0.62) * 4, 0, 1))
    img = mix(st, rc, mask)
    # blistered paint edge
    edge = np.clip(1 - np.abs(m - 0.46) * 20, 0, 1)
    img = mix(img, np.ones((n, n, 3)) * col("c9b28a"), edge * 0.35)
    return quantise(np.clip(img, 0, 255), 12)


def bakelite(n=128):
    lo = noise(n, 1.8, 21)
    hi = noise(n, 0.8, 22)
    img = mix(np.ones((n, n, 3)) * col("1c1512"), np.ones((n, n, 3)) * col("3a2a21"), lo * 0.8 + hi * 0.2)
    s = scratches(n, 30, 23, (4, 18))
    img += (s * 16)[..., None]
    return quantise(np.clip(img, 0, 255), 10)


def paint_green(n=128):
    """Chipped council-green paint over steel."""
    st = steel(n).astype(float)
    m = noise(n, 1.5, 31)
    hi = noise(n, 0.7, 32)
    pc = mix(np.ones((n, n, 3)) * col("2f4a3a"), np.ones((n, n, 3)) * col("4d6b55"), hi)
    chip = np.clip((m - 0.72) * 6, 0, 1)
    img = mix(pc, st, chip)
    s = scratches(n, 40, 33)
    img += (s * 24)[..., None]
    return quantise(np.clip(img, 0, 255), 12)


def grime(w=320, h=180):
    """A full-screen smear: dark corners, finger marks, a water stain.
    Alpha only matters; the colour is soot."""
    n = 256
    a = noise(n, 1.4, 41)
    a = np.array(Image.fromarray((a * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), float) / 255.0
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)
    vig = np.clip((cx ** 2 + cy ** 2) ** 1.4 * 0.6, 0, 1)
    alpha = np.clip(vig * 0.9 + (a - 0.6) * 0.8, 0, 0.85)
    th = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    alpha = np.floor(alpha * 6 + 0.5 + th * 0.9) / 6
    img = np.zeros((h, w, 4), np.uint8)
    img[..., 0] = 8
    img[..., 1] = 7
    img[..., 2] = 6
    img[..., 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    return img


# ------------------------------------------------------------------ cursors
# 16x16, drawn by hand. k outline, w ivory, g grey, r red, y amber, b blue, . clear
PAL = {"k": (10, 9, 8, 255), "w": (226, 216, 190, 255), "g": (130, 124, 110, 255), "r": (214, 40, 30, 255),
       "y": (232, 170, 60, 255), "p": (126, 255, 140, 255), "d": (40, 90, 50, 255), ".": (0, 0, 0, 0)}

CURSORS = {
    "point": [
        "k...............",
        "kk..............",
        "kwk.............",
        "kwwk............",
        "kwwwk...........",
        "kwwwwk..........",
        "kwwwwwk.........",
        "kwwwwwwk........",
        "kwwwwwwwk.......",
        "kwwwwwkkkk......",
        "kwwkwwk.........",
        "kwk.kwwk........",
        "kk..kwwk........",
        "k....kwwk.......",
        ".....kwwk.......",
        "......kk........",
    ],
    "walk": [
        "................",
        ".......kk.......",
        "......kwwk......",
        "......kwwk......",
        ".......kk.......",
        "..kk...kk...kk..",
        ".kwwkkkwwkkkwwk.",
        ".kwwwwwwwwwwwwk.",
        "..kk...kk...kk..",
        ".......kk.......",
        "......kwwk......",
        "......kwwk......",
        ".......kk.......",
        "................",
        "................",
        "................",
    ],
    "look": [
        "................",
        "................",
        "................",
        ".....kkkkkk.....",
        "...kkwwwwwwkk...",
        "..kwwwkkkkwwwk..",
        ".kwwwkkrrkkwwwk.",
        "kwwwwkrkkrkwwwwk",
        "kwwwwkrkkrkwwwwk",
        ".kwwwkkrrkkwwwk.",
        "..kwwwkkkkwwwk..",
        "...kkwwwwwwkk...",
        ".....kkkkkk.....",
        "................",
        "................",
        "................",
    ],
    "listen": [
        "................",
        ".....kkkkk......",
        "....kwwwwwk.....",
        "...kwwkkkwwk....",
        "...kwk...kwk....",
        "...kwk.kkkwk....",
        "...kwk.kwwwk....",
        "....kk.kwkwk....",
        "......kwwkk.....",
        ".....kwwk.......",
        ".....kwk........",
        "...k.kwk..k.k...",
        "..kwkkwwkkwkwk..",
        "...kwwwwwwwk....",
        "....kkkkkkk.....",
        "................",
    ],
    "ask": [
        "................",
        "..kkkkkkkkkkkk..",
        ".kwwwwwwwwwwwwk.",
        ".kwwwwwwwwwwwwk.",
        ".kwwkkwwkkwkkwk.",
        ".kwwkkwwkkwkkwk.",
        ".kwwwwwwwwwwwwk.",
        ".kwwwwwwwwwwwwk.",
        "..kkkkwwkkkkkk..",
        ".....kwwk.......",
        ".....kwk........",
        ".....kk.........",
        "................",
        "................",
        "................",
        "................",
    ],
    "use": [
        "......kk........",
        ".....kwwk.......",
        ".....kwwk.......",
        ".....kwwk.......",
        ".....kwwkkk.....",
        ".....kwwkwwkk...",
        "..kk.kwwkwwkwk..",
        ".kwwkkwwkwwkwwk.",
        ".kwwwkwwwwwwwwk.",
        "..kwwwwwwwwwwwk.",
        "..kwwwwwwwwwwk..",
        "...kwwwwwwwwwk..",
        "...kwwwwwwwwk...",
        "....kwwwwwwwk...",
        "....kkkkkkkkk...",
        "................",
    ],
    "read": [
        "................",
        "..kkkkkkkkk.....",
        "..kwwwwwwwkk....",
        "..kwkkkkwwkwk...",
        "..kwwwwwwwkkkk..",
        "..kwkkkkkkkwwk..",
        "..kwwwwwwwwwwk..",
        "..kwkkkkkkkkwk..",
        "..kwwwwwwwwwwk..",
        "..kwkkkkkkwwwk..",
        "..kwwwwwwwwwwk..",
        "..kwrrrwwwwwwk..",
        "..kwwwwwwwwwwk..",
        "..kkkkkkkkkkkk..",
        "................",
        "................",
    ],
    "go": [
        "................",
        "..kkkkkkkk......",
        "..kggggggk......",
        "..kgkkkkgk......",
        "..kgk..kgk.k....",
        "..kgk..kgkkwk...",
        "..kgk.kkkkwwwk..",
        "..kgk.kwwwwwwwk.",
        "..kgk.kwwwwwwwwk",
        "..kgk.kwwwwwwwk.",
        "..kgk.kkkkwwwk..",
        "..kgk..kgkkwk...",
        "..kgk..kgk.k....",
        "..kgkkkkgk......",
        "..kkkkkkkk......",
        "................",
    ],
    "dial": [
        "................",
        "......kkkk......",
        ".....kyyyyk.....",
        ".....kykkyk.....",
        ".....kyyyyk.....",
        "......kyyk......",
        "......kyyk......",
        ".....kkyykk.....",
        "....kyyyyyyk....",
        "....kyyyyyyk....",
        ".....kkyykk.....",
        "......krrk......",
        "......krrk......",
        ".......krk......",
        ".......krrk.....",
        "........kk......",
    ],
    "wait": [
        "................",
        "...kkkkkkkkkk...",
        "...kggggggggk...",
        "....kwwwwwwk....",
        "....kwyyyywk....",
        ".....kwyywk.....",
        "......kwwk......",
        "......kwwk......",
        ".....kwwwwk.....",
        "....kwwyywwk....",
        "....kwyyyywk....",
        "...kggggggggk...",
        "...kkkkkkkkkk...",
        "................",
        "................",
        "................",
    ],
    "no": [
        "................",
        ".....kkkkkk.....",
        "...kkrrrrrrkk...",
        "..krrkkkkkkrrk..",
        "..krk....krrrk..",
        ".krk....krrkrk..",
        ".krk...krrk.krk.",
        ".krk..krrk..krk.",
        ".krk.krrk...krk.",
        ".krkkrrk....krk.",
        "..krrrk....krk..",
        "..krrkkkkkkrrk..",
        "...kkrrrrrrkk...",
        ".....kkkkkk.....",
        "................",
        "................",
    ],
}


def cursors():
    names = list(CURSORS.keys())
    sheet = Image.new("RGBA", (16 * len(names), 16), (0, 0, 0, 0))
    px = sheet.load()
    for i, n in enumerate(names):
        rows = CURSORS[n]
        assert len(rows) == 16, n
        for y, row in enumerate(rows):
            assert len(row) == 16, (n, y, len(row))
            for x, ch in enumerate(row):
                px[i * 16 + x, y] = PAL[ch]
    sheet.save(os.path.join(OUT, "cursors.png"))
    print("wrote cursors.png", names)


if __name__ == "__main__":
    save(steel(), "steel.png")
    save(rust(), "rust.png")
    save(bakelite(), "bakelite.png")
    save(paint_green(), "paint_green.png")
    save(grime(), "grime.png")
    cursors()
