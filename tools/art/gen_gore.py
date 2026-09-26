"""Blood, low resolution: pools, spatter, a handprint dragged down tiles,
drips, a drag trail. Hard-edged pixels, a dark core and a lighter wet rim,
a few specular pixels, dithered at the edges so it sits in the dithered
rooms. Written to assets/tex/blood_*.png.

    python3 tools/art/gen_gore.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tex")
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], float) / 16.0

DARK = np.array([40, 3, 4], float)
MID = np.array([96, 10, 12], float)
WET = np.array([140, 22, 20], float)
SHINE = np.array([214, 150, 140], float)


def noise(n, power, seed):
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.normal(size=(n, n)))
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    rad = np.sqrt(fx * fx + fy * fy)
    rad[0, 0] = 1
    out = np.real(np.fft.ifft2(f / rad ** power))
    out -= out.min()
    return out / out.max()


def paint(mask, seed, h=None):
    """mask: 0..1 coverage. Returns RGBA with a dark core, wet rim, shine."""
    n = mask.shape[0]
    w = mask.shape[1]
    th = np.tile(BAYER4, (n // 4 + 1, w // 4 + 1))[:n, :w]
    cover = mask > th * 0.9 + 0.05
    depth = np.clip(mask, 0, 1)
    rgb = np.zeros((n, w, 3))
    t1 = np.clip((depth - 0.2) * 2.0, 0, 1)[..., None]
    rgb = WET * (1 - t1) + MID * t1
    t2 = np.clip((depth - 0.65) * 3.0, 0, 1)[..., None]
    rgb = rgb * (1 - t2) + DARK * t2
    r = np.random.default_rng(seed)
    shine = (r.random((n, w)) < 0.012) & (depth > 0.55)
    rgb[shine] = SHINE
    # posterise to a handful of reds
    rgb = np.floor(rgb / 16 + th[..., None] * 0.8) * 16
    a = np.where(cover, 255, 0)
    img = np.zeros((n, w, 4), np.uint8)
    img[..., :3] = np.clip(rgb, 0, 255)
    img[..., 3] = a
    return img


def blob(n, cx, cy, rx, ry, seed, rough=0.35):
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    nz = noise(n, 1.4, seed)
    return np.clip(1.25 - d - (nz - 0.5) * rough * 2, 0, 1)


def disc(n, cx, cy, r):
    yy, xx = np.mgrid[0:n, 0:n]
    return np.clip(1.4 - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(r, 0.5), 0, 1)


def pool():
    n = 128
    m = blob(n, 64, 64, 42, 34, 1, 0.55)
    m = np.maximum(m, blob(n, 88, 80, 20, 16, 2, 0.5))
    m = np.maximum(m, blob(n, 40, 44, 16, 14, 3, 0.5))
    return paint(m, 4)


def splat():
    n = 128
    r = np.random.default_rng(7)
    m = blob(n, 64, 64, 18, 15, 8, 0.6)
    for k in range(70):
        a = r.uniform(0, 2 * np.pi)
        dist = r.uniform(16, 58)
        rad = r.uniform(0.8, 3.2) * (1.2 - dist / 70)
        m = np.maximum(m, disc(n, 64 + np.cos(a) * dist, 64 + np.sin(a) * dist, rad))
        if r.random() < 0.3:
            # a streak thrown outward
            for s in np.linspace(0, 1, 6):
                m = np.maximum(m, disc(n, 64 + np.cos(a) * (dist - 10 * s), 64 + np.sin(a) * (dist - 10 * s), rad * (1 - s * 0.6)))
    return paint(m, 9)


def hand():
    n = 128
    m = np.zeros((n, n))
    # the palm, then fingers, then everything dragged down
    m = np.maximum(m, blob(n, 64, 52, 16, 18, 11, 0.3))
    for dx, ln in [(-14, 22), (-5, 27), (5, 28), (14, 22)]:
        for s in np.linspace(0, 1, 14):
            m = np.maximum(m, disc(n, 64 + dx + s * dx * 0.18, 36 - s * ln, 4.2 - s * 0.9))
    for s in np.linspace(0, 1, 12):
        m = np.maximum(m, disc(n, 64 + 20 + s * 7, 54 - s * 15, 4.0))
    r = np.random.default_rng(12)
    for k in range(12):
        x = int(64 + r.uniform(-15, 15))
        top = 60 + r.uniform(-4, 6)
        ln = r.uniform(18, 66)
        wd = int(r.choice([1, 2, 2, 3]))
        for y in np.arange(top, min(top + ln, 127), 1.0):
            v = 0.95 - (y - top) / (ln * 1.5)
            sl = slice(x - wd // 2, x + (wd + 1) // 2 + 1)
            m[int(y), sl] = np.maximum(m[int(y), sl], v)
        yy, xx = np.mgrid[0:n, 0:n]
        m = np.maximum(m, np.clip(1.25 - np.sqrt((xx - x) ** 2 + (yy - min(top + ln, 125)) ** 2) / (wd + 0.9), 0, 1))
    img = paint(m, 13)
    return img[:, 32:96]


def drip():
    w, h = 64, 128
    img = np.zeros((h, w))
    r = np.random.default_rng(21)
    img[:10, :] = 1.0
    img[:14, :] = np.maximum(img[:14, :], noise(128, 1.2, 22)[:14, :64] * 1.3)
    for k in range(10):
        x = int(r.uniform(3, 61))
        ln = int(r.uniform(18, 118))
        wd = r.choice([1, 2, 2, 3])
        for y in range(8, ln):
            img[y, max(0, x - wd // 2): x + (wd + 1) // 2] = 1.0 - (y / ln) * 0.3
        yy, xx = np.mgrid[0:h, 0:w]
        img = np.maximum(img, np.clip(1.3 - np.sqrt((xx - x) ** 2 + (yy - ln) ** 2) / (wd + 0.8), 0, 1))
    return paint(img, 23)


def trail():
    n = 128
    m = np.zeros((n, n))
    r = np.random.default_rng(31)
    for k in range(5):
        y0 = 40 + k * 12 + r.uniform(-3, 3)
        for x in range(4, 124):
            y = y0 + np.sin(x * 0.05 + k) * 3
            fadek = 1.0 - x / 150
            m[int(y) - 1: int(y) + 2, x] = np.maximum(m[int(y) - 1: int(y) + 2, x], fadek * r.uniform(0.6, 1.0))
    m = np.maximum(m, blob(n, 14, 64, 12, 30, 32, 0.4))
    return paint(m, 33)


if __name__ == "__main__":
    for name, fn in [("blood_pool", pool), ("blood_splat", splat), ("blood_hand", hand), ("blood_drip", drip), ("blood_trail", trail)]:
        Image.fromarray(fn()).save(os.path.join(OUT, name + ".png"))
        print("wrote", name)
