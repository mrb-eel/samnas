"""The archive photographs: renders from scenes/photo_render.tscn, printed.

    godot --path . res://scenes/photo_render.tscn -- <renders_dir>
    python3 tools/art/gen_photos.py <renders_dir>

Black and white, toned, grained, a little soft, with dust and handling marks,
on a paper border. Mrs. Doyle moved during the exposure: three renders of her
laughing are averaged so she smears and nobody else does.
"""
import os, sys, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "docs")
FONTS = os.path.join(ROOT, "assets", "fonts")
sys.path.insert(0, HERE)
import gen_docs  # noqa: E402  (printout, hand fonts)

rng = np.random.default_rng(58)
R = random.Random(58)


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), np.float32) / 255.0


def develop(rgb, tone, contrast=1.25, grain=0.05, blur=0.8, vignette=0.45, lift=0.05):
    lum = rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11
    lum = lum / max(np.percentile(lum, 99.5), 1e-3)
    lum = np.clip((lum - 0.5) * contrast + 0.5, 0, 1)
    h, w = lum.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = xx / w - 0.5, yy / h - 0.5
    lum *= 1 - vignette * (nx ** 2 + ny ** 2) * 1.6
    img = Image.fromarray((np.clip(lum, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    lum = np.asarray(img, np.float32) / 255.0
    g = rng.normal(0, 1, (h // 2 + 1, w // 2 + 1)).astype(np.float32)
    g = np.asarray(Image.fromarray(((g - g.min()) / np.ptp(g) * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) / 255.0 - 0.5
    lum = np.clip(lum + g * grain * 2, 0, 1)
    lum = lift + lum * (1 - lift * 1.4)
    # toning: shadows and highlights pulled toward the paper's colours
    dark, light = np.array(tone[0], np.float32) / 255, np.array(tone[1], np.float32) / 255
    out = dark[None, None, :] * (1 - lum[..., None]) + light[None, None, :] * lum[..., None]
    return out


def handle(img_arr, specks=900, scratches=4, crease=None):
    h, w, _ = img_arr.shape
    img = Image.fromarray((np.clip(img_arr, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(specks):
        x, y = R.randrange(w), R.randrange(h)
        r = R.choice([0.6, 0.8, 1.0, 1.4])
        col = (250, 246, 236) if R.random() < 0.7 else (30, 26, 22)
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    for _ in range(scratches):
        x = R.randrange(w)
        y0 = R.randrange(h // 2)
        pts = [(x + R.uniform(-3, 3), y) for y in range(y0, min(h, y0 + R.randint(h // 5, h // 2)), 30)]
        d.line(pts, fill=(236, 232, 222, 90), width=1)
    if crease:
        # a corner folded once and flattened again: a pale line, a dark one beside it
        (x0, y0), (x1, y1) = crease
        d.line([(x0, y0), (x1, y1)], fill=(246, 240, 228, 110), width=2)
        d.line([(x0 + 2, y0 + 2), (x1 + 2, y1 + 2)], fill=(40, 34, 28, 60), width=1)
    return img


def border(img, pad, base, deckle=False, caption=None):
    w, h = img.size
    top, side, bottom = pad
    W, H = w + side * 2, h + top + bottom
    a = np.empty((H, W, 3), np.float32)
    a[:] = base
    a += rng.normal(0, 3, (H, W, 1))
    paper = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    paper.paste(img, (side, top))
    if deckle:
        m = Image.new("L", (W, H), 255)
        md = ImageDraw.Draw(m)
        for x in range(0, W, 9):
            dd = R.randint(0, 7)
            md.rectangle([x, 0, x + 9, dd], fill=0)
            md.rectangle([x, H - dd, x + 9, H], fill=0)
        for y in range(0, H, 9):
            dd = R.randint(0, 7)
            md.rectangle([0, y, dd, y + 9], fill=0)
            md.rectangle([W - dd, y, W, y + 9], fill=0)
        bg = Image.new("RGB", (W, H), (30, 28, 26))
        bg.paste(paper, (0, 0), m)
        paper = bg
    if caption:
        caption(paper, (side, top + h), W, H)
    return paper


def arrivals(src):
    a = load(os.path.join(src, "photo_1958_0.png"))
    b = load(os.path.join(src, "photo_1958_1.png"))
    c = load(os.path.join(src, "photo_1958_2.png"))
    rgb = a * 0.45 + b * 0.33 + c * 0.22
    t = develop(rgb, ((46, 32, 22), (238, 222, 192)), contrast=1.3, grain=0.055, blur=1.0, vignette=0.55, lift=0.06)
    img = handle(t, specks=900, scratches=3, crease=((rgb.shape[1] * 0.78, 0), (rgb.shape[1], rgb.shape[0] * 0.3)))

    def cap(p, xy, W, H):
        gen_docs.seed("photo_arrivals")
        gen_docs.write(p, (xy[0] + 10, xy[1] + 22), "Ferrier St. Baths · Arrivals · winter 1958", "clerk_a", 44, (90, 86, 80), alpha=0.8)
    out = border(img, (40, 44, 110), (236, 230, 214), deckle=True, caption=cap)
    out.save(os.path.join(OUT, "photo_arrivals.jpg"), quality=88, optimize=True)
    gen_docs.printout(out, "photo_arrivals", dots=200)
    return out


def attendants(src):
    rgb = load(os.path.join(src, "photo_1965.png"))
    t = develop(rgb, ((22, 22, 26), (236, 234, 228)), contrast=1.35, grain=0.045, blur=0.7, vignette=0.4, lift=0.04)
    img = handle(t, specks=700, scratches=2)

    def cap(p, xy, W, H):
        d = ImageDraw.Draw(p)
        f = ImageFont.truetype(os.path.join(FONTS, "FellSC.ttf"), 34)
        text = "MUNICIPAL ATTENDANTS · FERRIER ST. BATHS · 1965"
        d.text(((W - f.getlength(text)) / 2, xy[1] + 26), text, font=f, fill=(40, 38, 40))
    out = border(img, (34, 34, 96), (240, 238, 232), deckle=False, caption=cap)
    out.save(os.path.join(OUT, "photo_attendants.jpg"), quality=88, optimize=True)
    gen_docs.printout(out, "photo_attendants", dots=200)
    return out


if __name__ == "__main__":
    src = sys.argv[1]
    a = arrivals(src)
    b = attendants(src)
    print("arrivals", a.size, "attendants", b.size)
