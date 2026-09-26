"""Textures for the interface: paper, bakelite, the dialogue column, the oval
frame round the place where Ari would be, the exchange's background, and the
title art (a render of the deep end, passed in).

    python3 tools/art/gen_ui.py [title_render.png]
"""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(11)
R = random.Random(11)


def periodic_noise(w, h, octaves=((4, 1.0), (8, 0.5), (16, 0.25), (32, 0.12))):
    """Noise that tiles: a sum of sinusoids with whole-number frequencies."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    out = np.zeros((h, w), np.float32)
    for f, amp in octaves:
        for _ in range(6):
            fx, fy = rng.integers(-f, f + 1), rng.integers(-f, f + 1)
            ph = rng.random() * math.tau
            out += amp * np.sin(math.tau * (fx * xx / w + fy * yy / h) + ph)
    out -= out.min()
    return out / max(out.max(), 1e-6)


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"), optimize=True)
    print(name, img.size)


def paper():
    W = H = 512
    n = periodic_noise(W, H)
    fine = rng.normal(0, 1, (H, W)).astype(np.float32)
    base = np.array([236, 228, 208], np.float32)
    a = base[None, None, :] - (n[..., None] - 0.5) * 18 + fine[..., None] * 3.0
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for _ in range(420):
        x, y = R.randrange(W), R.randrange(H)
        L = R.randint(3, 12)
        t = R.random() * math.pi
        d.line([(x, y), ((x + math.cos(t) * L) % W, (y + math.sin(t) * L) % H)], fill=(212, 202, 180))
    save(img, "paper")


def bakelite():
    W = H = 256
    swirl = periodic_noise(W, H, ((2, 1.0), (4, 0.6), (8, 0.3)))
    vein = np.abs(np.sin(swirl * 18.0))
    t = np.clip(0.55 * swirl + 0.45 * (1 - vein) ** 3, 0, 1)
    dark = np.array([22, 15, 12], np.float32)
    light = np.array([74, 44, 28], np.float32)
    a = dark[None, None, :] * (1 - t[..., None]) + light[None, None, :] * t[..., None]
    a += rng.normal(0, 2.0, (H, W, 1))
    save(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), "bakelite")


def panel_column():
    """The dialogue column: dark card, a hairline of brass inside the edge.
    Drawn as a 9-slice with 24px margins."""
    S = 96
    a = np.zeros((S, S, 4), np.float32)
    a[..., :3] = np.array([19, 18, 22], np.float32) / 255
    a[..., 3] = 0.96
    a[..., :3] += rng.normal(0, 0.006, (S, S, 1))
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, S - 1, S - 1], outline=(58, 54, 60, 255), width=1)
    d.rectangle([7, 7, S - 8, S - 8], outline=(150, 126, 76, 120), width=1)
    d.rectangle([10, 10, S - 11, S - 11], outline=(150, 126, 76, 50), width=1)
    for (x, y) in [(7, 7), (S - 8, 7), (7, S - 8), (S - 8, S - 8)]:
        d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=(176, 148, 90, 200))
    save(img, "panel_column")


def oval_frame():
    """A devotional frame round an empty oval: gilt gone green in the
    mouldings, a bead row, a small plaque that says 247."""
    W, H = 300, 400
    K = 3
    w, h = W * K, H * K
    cx, cy = w / 2, h / 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # distance inside the ellipse, in units of the outer ring
    rx, ry = w / 2 - 6 * K, h / 2 - 6 * K
    rr = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    inner = 1.0 - 30.0 / (W / 2)
    ring = (rr <= 1.0) & (rr >= inner)
    t = np.clip((rr - inner) / (1.0 - inner), 0, 1)
    # the moulding's profile: a round, a hollow, a round
    prof = 0.55 + 0.45 * np.cos(t * math.tau * 1.5)
    ang = np.arctan2((yy - cy) / ry, (xx - cx) / rx)
    light = 0.5 + 0.5 * np.cos(ang + 2.3)
    shade = np.clip(prof * 0.7 + light * 0.45 * prof, 0, 1.2)
    gold = np.array([184, 146, 74], np.float32) / 255
    dark = np.array([62, 44, 22], np.float32) / 255
    patina = np.array([86, 120, 96], np.float32) / 255
    col = dark[None, None, :] * (1 - shade[..., None]) + gold[None, None, :] * shade[..., None]
    hollow = np.clip(1 - prof, 0, 1) ** 2
    blot = periodic_noise(w, h, ((6, 1.0), (12, 0.5)))
    col = col * (1 - hollow[..., None] * blot[..., None] * 0.8) + patina[None, None, :] * hollow[..., None] * blot[..., None] * 0.8
    a = np.zeros((h, w, 4), np.float32)
    a[..., :3] = col
    a[..., 3] = ring.astype(np.float32)
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    # beads round the inner edge
    n = 64
    for i in range(n):
        th = math.tau * i / n
        br = inner + 0.04
        x = cx + math.cos(th) * rx * br
        y = cy + math.sin(th) * ry * br
        r = 3.2 * K
        d.ellipse([x - r, y - r, x + r, y + r], fill=(200, 164, 90, 255), outline=(70, 50, 26, 255), width=K)
    # a plaque at the foot: 247
    pw, ph = 70 * K, 26 * K
    px, py = cx - pw / 2, h - 6 * K - ph + 4 * K
    d.rounded_rectangle([px, py, px + pw, py + ph], 6 * K, fill=(40, 30, 18, 255), outline=(200, 164, 90, 255), width=2 * K)
    try:
        from PIL import ImageFont
        f = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "FellSC.ttf"), 20 * K)
        tw = f.getlength("247")
        d.text((cx - tw / 2, py + 1 * K), "247", font=f, fill=(222, 196, 130, 255))
    except Exception:
        pass
    # and a little crest at the head: a knot of wire, a bulb
    d.ellipse([cx - 9 * K, 2 * K, cx + 9 * K, 20 * K], fill=(200, 164, 90, 255), outline=(70, 50, 26, 255), width=K)
    d.ellipse([cx - 4 * K, 7 * K, cx + 4 * K, 15 * K], fill=(255, 214, 130, 255))
    img = img.resize((W, H), Image.LANCZOS)
    save(img, "oval_frame")


def exchange_bg():
    """Behind the exchange windows: the frame's circuitry, barely there."""
    W, H = 1280, 720
    a = np.zeros((H, W, 3), np.float32)
    a[:] = np.array([11, 11, 14], np.float32)
    n = periodic_noise(W, H, ((3, 1.0), (6, 0.5)))
    a += (n[..., None] - 0.5) * 8
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    # relay banks, ghosted
    for bx in range(20, W, 64):
        for by in range(20, H, 110):
            if R.random() < 0.55:
                d.rectangle([bx, by, bx + 56, by + 96], outline=(40, 46, 44, 60), width=1)
                for k in range(6):
                    d.rectangle([bx + 6, by + 8 + k * 14, bx + 50, by + 16 + k * 14], fill=(34, 40, 38, 40))
    # traces: right-angled runs with pads, green and blue
    for _ in range(170):
        x, y = R.randrange(W), R.randrange(H)
        col = R.choice([(46, 84, 68, 70), (40, 58, 96, 60), (70, 60, 40, 40)])
        pts = [(x, y)]
        for _ in range(R.randint(2, 6)):
            if R.random() < 0.5:
                x += R.choice([-1, 1]) * R.randint(20, 160)
            else:
                y += R.choice([-1, 1]) * R.randint(20, 120)
            pts.append((x, y))
        d.line(pts, fill=col, width=2)
        d.ellipse([pts[-1][0] - 4, pts[-1][1] - 4, pts[-1][0] + 4, pts[-1][1] + 4], outline=col, width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    a = np.asarray(img, np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = 1 - 0.55 * (((xx - W * 0.53) / W) ** 2 + ((yy - H * 0.35) / H) ** 2) * 2.4
    a *= np.clip(v, 0.2, 1)[..., None]
    save(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), "exchange_bg")


def title_art(src):
    im = Image.open(src).convert("RGB")
    save(im, "title_art")


def shadow_tex():
    """A soft shadow for 9-slice drawing: a rounded rect, blurred, alpha only."""
    S, M = 128, 30
    im = Image.new("L", (S, S), 0)
    ImageDraw.Draw(im).rounded_rectangle([M, M, S - M, S - M], 8, fill=255)
    im = im.filter(ImageFilter.GaussianBlur(11))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.putalpha(im)
    save(out, "shadow")


def stamp_mask():
    """Where a rubber stamp's ink didn't take: blotches and specks, tiling."""
    S = 256
    n = periodic_noise(S, S, ((8, 1.0), (16, 0.6), (32, 0.4)))
    specks = rng.random((S, S)).astype(np.float32)
    a = np.clip((n - 0.62) * 5.0, 0, 1) + (specks > 0.93) * 0.9
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    save(Image.fromarray(out, "RGBA"), "stamp_mask")


def grain_tex():
    """Film grain: light and dark specks on transparency, tiling."""
    S = 256
    v = rng.random((S, S)).astype(np.float32)
    out = np.zeros((S, S, 4), np.uint8)
    light = v > 0.5
    out[..., 0] = np.where(light, 255, 0)
    out[..., 1] = out[..., 0]
    out[..., 2] = out[..., 0]
    out[..., 3] = (np.abs(v - 0.5) * 2 * 90).astype(np.uint8)
    save(Image.fromarray(out, "RGBA"), "grain")


def vignette_tex():
    W, H = 640, 360
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    a = np.clip((d - 0.55) / 0.75, 0, 1) ** 1.6
    out = np.zeros((H, W, 4), np.uint8)
    out[..., 3] = (a * 200).astype(np.uint8)
    save(Image.fromarray(out, "RGBA"), "vignette")


def glow_tex():
    """A round falloff for lamp light, additive."""
    S = 256
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S / 2)
    a = np.clip(1 - d, 0, 1) ** 2.2
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (a * 255).astype(np.uint8)
    save(Image.fromarray(out, "RGBA"), "glow")


if __name__ == "__main__":
    paper()
    bakelite()
    panel_column()
    oval_frame()
    exchange_bg()
    shadow_tex()
    stamp_mask()
    grain_tex()
    vignette_tex()
    glow_tex()
    if len(sys.argv) > 1:
        title_art(sys.argv[1])
