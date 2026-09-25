"""The collage in chapter 4: what everybody at the meeting thinks Ari is.

    godot --path . res://scenes/collage_render.tscn -- <renders_dir>
    python3 tools/art/gen_collage.py <renders_dir>

Every piece comes from somewhere different, so every piece is printed
differently: the chair in the deep end as newsprint, Mrs. Kaye's young lady
from the council as a colour magazine, Teodor's tall young man as an old
studio photograph, June's idea as a party snapshot with the friend torn off,
the attendant from the archive, the number on a scrap, the face Tobi left for
later, the badge the council would issue. Each is cut out with scissors and
casts a small shadow on whatever is under it.
"""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "collage")
DOCS = os.path.join(ROOT, "assets", "docs")
FONTS = os.path.join(ROOT, "assets", "fonts")
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, HERE)
import gen_docs  # noqa: E402

rng = np.random.default_rng(4)
R = random.Random(4)


def F(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), int(size))


def arr(img):
    return np.asarray(img, np.float32) / 255.0


def to_img(a, mode="RGB"):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), mode)


def lowfreq(h, w, scale, amp):
    n = rng.normal(0, 1, (max(2, h // scale), max(2, w // scale))).astype(np.float32)
    n = np.asarray(Image.fromarray(((n - n.min()) / (np.ptp(n) + 1e-6) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255.0
    return (n - 0.5) * 2 * amp


def screen(tone, cell, angle):
    h, w = tone.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ca, sa = math.cos(angle), math.sin(angle)
    u = (xx * ca + yy * sa) / cell
    v = (-xx * sa + yy * ca) / cell
    du, dv = u - np.floor(u) - 0.5, v - np.floor(v) - 0.5
    return (np.sqrt(du ** 2 + dv ** 2) / 0.7071 < np.sqrt(np.clip(tone, 0, 1))).astype(np.float32)


def crop_alpha(img, pad=0):
    bb = img.getchannel("A").getbbox()
    return img.crop((max(0, bb[0] - pad), max(0, bb[1] - pad), min(img.width, bb[2] + pad), min(img.height, bb[3] + pad)))


def cut(printed, mask, margin=10, paper=(244, 240, 230), rough=2.0, torn=False, shadow=True):
    """Scissors: the printed thing on a sliver of its own paper, cut a little
    wide of the edge, lifted off the page with a shadow under it."""
    h, w = mask.shape
    P = margin * 3 + 24
    W, H = w + P * 2, h + P * 2
    m = np.zeros((H, W), np.float32)
    m[P:P + h, P:P + w] = mask
    mi = Image.fromarray((m * 255).astype(np.uint8))
    grown = mi
    for _ in range(max(1, margin // 5)):
        grown = grown.filter(ImageFilter.MaxFilter(11))
    g = arr(grown.filter(ImageFilter.GaussianBlur(3.0 if not torn else 1.2)))
    g = g + lowfreq(H, W, 18 if not torn else 5, 0.18 * rough / 2)
    if torn:
        g = g + lowfreq(H, W, 2, 0.12)
    cutm = (g > 0.5).astype(np.float32)
    out = np.zeros((H, W, 4), np.float32)
    out[..., :3] = np.array(paper, np.float32) / 255
    out[..., 3] = cutm
    if torn:
        # the torn edge shows the paper's white fibres
        inner = arr(Image.fromarray((cutm * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)))
        fib = np.clip(cutm - inner, 0, 1)
        out[..., :3] = out[..., :3] * (1 - fib[..., None]) + fib[..., None] * np.array([0.98, 0.97, 0.95])
    pr = np.zeros((H, W, 3), np.float32)
    pr[P:P + h, P:P + w] = printed
    pm = np.zeros((H, W), np.float32)
    pm[P:P + h, P:P + w] = mask
    pm = pm * cutm
    out[..., :3] = out[..., :3] * (1 - pm[..., None]) + pr * pm[..., None]
    img = to_img(out, "RGBA")
    if shadow:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        a = Image.fromarray((cutm * 120).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
        sh.putalpha(a)
        base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        base.alpha_composite(sh, (7, 9))
        base.alpha_composite(img)
        img = base
    return crop_alpha(img, 2)


# ------------------------------------------------------------------ print styles

def newsprint(rgb, cell=5.5):
    lum = rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11
    lo, hi = np.percentile(lum, 2), np.percentile(lum, 99)
    dark = (1 - np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1)) ** 1.35
    ink = np.maximum(screen(dark * 0.92, cell, math.radians(45)), (dark > 0.95).astype(np.float32))
    paper = np.array([0.9, 0.88, 0.82], np.float32)
    return paper[None, None, :] * (1 - ink[..., None] * 0.9)


def magazine(rgb, cell=4.2):
    c, m, y = 1 - rgb[..., 0], 1 - rgb[..., 1], 1 - rgb[..., 2]
    k = np.minimum(np.minimum(c, m), y) * 0.85
    c, m, y = [(ch - k) / np.maximum(1 - k, 1e-3) for ch in (c, m, y)]
    out = np.ones(rgb.shape, np.float32) * np.array([0.97, 0.96, 0.94], np.float32)
    for ch, ang, ink in ((c, 15, (0.0, 0.62, 0.86)), (m, 75, (0.86, 0.0, 0.47)), (y, 0, (1.0, 0.9, 0.0)), (k, 45, (0.1, 0.1, 0.12))):
        dots = screen(np.clip(ch, 0, 1), cell, math.radians(ang))
        out = out * (1 - dots[..., None] * (1 - np.array(ink, np.float32)))
    return out


def sepia(rgb, grain=0.05):
    lum = rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11
    lum = np.clip((lum - 0.5) * 1.25 + 0.55, 0, 1)
    h, w = lum.shape
    lum = np.clip(lum + rng.normal(0, grain, (h, w)).astype(np.float32), 0, 1)
    dark, light = np.array([0.2, 0.13, 0.08]), np.array([0.94, 0.86, 0.72])
    return dark[None, None, :] * (1 - lum[..., None]) + light[None, None, :] * lum[..., None]


def snapshot_colour(rgb):
    out = rgb * 0.88 + 0.08
    out[..., 0] *= 1.04
    out[..., 2] *= 0.9
    lum = out.mean(-1, keepdims=True)
    out = lum + (out - lum) * 0.8
    h, w, _ = out.shape
    return np.clip(out + rng.normal(0, 0.025, (h, w, 1)).astype(np.float32), 0, 1)


def bw_photo(rgb, grain=0.06):
    lum = rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11
    lum = np.clip((lum - 0.45) * 1.4 + 0.5, 0, 1)
    h, w = lum.shape
    lum = np.clip(lum + rng.normal(0, grain, (h, w)).astype(np.float32), 0, 1)
    t = np.array([0.93, 0.92, 0.89])
    return lum[..., None] * t[None, None, :] + 0.05


# ------------------------------------------------------------------ pieces

def load_render(src, name, scale):
    im = Image.open(os.path.join(src, name + ".png")).convert("RGBA")
    im = crop_alpha(im, 4)
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    a = arr(im)
    return a[..., :3], a[..., 3]


def chair_phone(src):
    rgb, al = load_render(src, "chair_phone", 0.8)
    return cut(newsprint(rgb), al, margin=12, paper=(230, 225, 210))


def kaye_glasses(src):
    rgb, al = load_render(src, "kaye_glasses", 0.5)
    return cut(magazine(rgb), al, margin=8, paper=(248, 246, 240))


def teodor_coat(src):
    im = Image.open(os.path.join(src, "teodor_coat.png")).convert("RGBA")
    im = crop_alpha(im, 30)
    im = im.resize((int(im.width * 0.5), int(im.height * 0.5)), Image.LANCZOS)
    a = arr(im)
    h, w = a.shape[:2]
    # a studio backdrop behind him, fading out, cut round him loosely
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    backdrop = np.ones((h, w, 3), np.float32) * (0.62 - 0.25 * yy)[..., None]
    rgb = a[..., :3] * a[..., 3:4] + backdrop * (1 - a[..., 3:4])
    mask = np.clip(arr(Image.fromarray((a[..., 3] * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(21)).filter(ImageFilter.MaxFilter(15))), 0, 1)
    return cut(sepia(rgb), mask, margin=5, paper=(236, 228, 208), rough=3.0)


def june_friend(src):
    im = Image.open(os.path.join(src, "june_friend.png")).convert("RGB")
    im = im.resize((int(im.width * 0.46), int(im.height * 0.46)), Image.LANCZOS)
    a = snapshot_colour(arr(im))
    h, w = a.shape[:2]
    b = 12
    photo = np.ones((h + b * 2, w + b * 2, 3), np.float32) * np.array([0.96, 0.95, 0.92], np.float32)
    photo[b:b + h, b:b + w] = a
    H, W = photo.shape[:2]
    # torn across, taking the friend's head with it
    mask = np.ones((H, W), np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    tear_y = H * 0.66 - (xx - W * 0.46) * 0.95 + lowfreq(H, W, 6, 9.0)
    gone = (xx > W * 0.46) & (yy < tear_y)
    mask[gone] = 0.0
    return cut(photo, mask, margin=1, paper=(250, 249, 246), torn=True)


def attendant_cap(src):
    rgb, al = load_render(src, "attendant_cap", 0.52)
    return cut(bw_photo(rgb), al, margin=6, paper=(238, 236, 230))


def number_scrap():
    gen_docs.seed("number_scrap")
    W, H = 360, 170
    p = gen_docs.paper(W, H, base=(246, 244, 236), grain=2.5)
    d = ImageDraw.Draw(p)
    for y in range(18, H, 30):
        d.line([(0, y), (W, y)], fill=(170, 190, 220), width=1)
    gen_docs.write(p, (26, 34), "01632 960 247", "adeyemi", 52, gen_docs.BIRO)
    gen_docs.write(p, (30, 108), "for the form", "anon", 30, (60, 60, 70), alpha=0.8)
    a = arr(p)
    mask = np.ones((H, W), np.float32)
    return cut(a, mask, margin=1, paper=(246, 244, 236), torn=True)


def tobi_face():
    im = Image.open(os.path.join(DOCS, "tobi_drawing.jpg")).convert("RGB")
    im = im.crop((210, 0, 480, 330)).resize((245, 300), Image.LANCZOS)
    a = arr(im)
    H, W = a.shape[:2]
    mask = np.ones((H, W), np.float32)
    return cut(a, mask, margin=1, paper=(214, 196, 150), torn=True)


def responder_badge():
    W, H = 250, 380
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    # the lanyard, red, through the slot
    d.rectangle([W // 2 - 22, 0, W // 2 + 22, 70], fill=(190, 38, 44, 255))
    d.rectangle([W // 2 - 12, 58, W // 2 + 12, 92], fill=(170, 170, 176, 255))
    d.rounded_rectangle([8, 84, W - 8, H - 8], 16, fill=(250, 250, 248, 255), outline=(200, 200, 204, 255), width=2)
    d.rounded_rectangle([W // 2 - 26, 96, W // 2 + 26, 106], 5, fill=(60, 60, 64, 255))
    d.rectangle([8, 118, W - 8, 170], fill=(34, 62, 104, 255))
    d.text((20, 124), "COMMUNITY SERVICES", font=F("Atkinson-Bold.ttf", 19), fill=(240, 240, 235, 255))
    d.text((20, 148), "Ferrier Court", font=F("Atkinson-Regular.ttf", 15), fill=(210, 220, 235, 255))
    # the photograph square: to follow
    d.rectangle([24, 184, 124, 304], fill=(214, 216, 220, 255), outline=(150, 150, 156, 255))
    d.ellipse([54, 206, 94, 250], fill=(176, 178, 184, 255))
    d.pieslice([40, 248, 108, 330], 180, 360, fill=(176, 178, 184, 255))
    d.rectangle([24, 290, 124, 304], fill=(214, 216, 220, 255))
    d.text((34, 286), "PHOTO TO FOLLOW", font=F("Atkinson-Regular.ttf", 9), fill=(110, 110, 116, 255))
    d.text((134, 190), "ARI", font=F("Atkinson-Bold.ttf", 44), fill=(20, 20, 26, 255))
    d.text((134, 244), "COMMUNITY", font=F("Atkinson-Bold.ttf", 13), fill=(20, 20, 26, 255))
    d.text((134, 262), "RESPONDER", font=F("Atkinson-Bold.ttf", 13), fill=(20, 20, 26, 255))
    d.text((134, 282), "G/1", font=F("Atkinson-Regular.ttf", 13), fill=(60, 60, 66, 255))
    x = 24
    while x < W - 26:
        wbar = R.choice([1, 2, 3])
        d.rectangle([x, 318, x + wbar, 350], fill=(20, 20, 26, 255))
        x += wbar + R.choice([1, 2, 3])
    d.text((24, 352), "Valid from 06:00 26/09", font=F("Atkinson-Regular.ttf", 11), fill=(90, 90, 96, 255))
    a = arr(card)
    # the plastic's shine, and a magazine print over the lot (it's from a council brochure)
    shine = np.clip(1 - np.abs(np.linspace(-1, 1, W)[None, :] + np.linspace(-1, 1, H)[:, None] * 0.6 - 0.2) * 3, 0, 1) * 0.18
    rgb = np.clip(a[..., :3] + shine[..., None], 0, 1)
    return cut(magazine(rgb, cell=3.4), a[..., 3], margin=8, paper=(248, 246, 240))


def main(src):
    pieces = {
        "chair_phone": lambda: chair_phone(src),
        "kaye_glasses": lambda: kaye_glasses(src),
        "teodor_coat": lambda: teodor_coat(src),
        "june_friend": lambda: june_friend(src),
        "attendant_cap": lambda: attendant_cap(src),
        "number_scrap": number_scrap,
        "tobi_face": tobi_face,
        "responder_badge": responder_badge,
    }
    for name, fn in pieces.items():
        img = fn()
        img.save(os.path.join(OUT, name + ".png"), optimize=True)
        print(name, img.size)


if __name__ == "__main__":
    main(sys.argv[1])
