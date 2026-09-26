"""Paper for Hold My Place: forms, slips, letters, the ledger, the poster.

    python3 tools/art/gen_docs.py

Documents are drawn flat and full size, with no margin, so one image serves
both as a prop on a 3D set and as the page in the document viewer (which adds
its own shadow). Things that are photographs of paper (Nell's photo of her
form, the pictures Sal sends) are laid out on a surface and put through a
cheap phone camera. Anything that reaches Ari through the booking printer
also gets <id>_print.png: a coarse dot printout on a perforated strip.

Everybody writes in their own hand (see HANDS). Jad's neat capitals are the
same on all nine forms, including the one for his own flat.
"""
import os, math, random, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "docs")
FONTS = os.path.join(ROOT, "assets", "fonts")
HANDFONTS = os.path.join(HERE, "fonts")
os.makedirs(OUT, exist_ok=True)

R = random.Random(1)
NP = np.random.default_rng(1)


def seed(name):
    """Each document gets its own random stream, so editing one doesn't reshuffle the rest."""
    global R, NP
    s = zlib.crc32(name.encode())
    R = random.Random(s)
    NP = np.random.default_rng(s)


INK = (28, 26, 32)
GREY = (100, 100, 108)
BIRO = (34, 52, 130)
BIRO_BLACK = (34, 34, 42)
PENCIL = (116, 114, 110)
FELT_RED = (186, 36, 70)
CARBON = (72, 62, 156)
NAVY = (34, 56, 96)
RED = (170, 40, 34)

_fc = {}


def _font(path, size):
    key = (path, int(size))
    if key not in _fc:
        _fc[key] = ImageFont.truetype(path, max(6, int(size)))
    return _fc[key]


def F(name, size):
    return _font(os.path.join(FONTS, name), size)


TYPE = lambda s: F("SpecialElite.ttf", s)
SANS = lambda s: F("Atkinson-Regular.ttf", s)
SANSB = lambda s: F("Atkinson-Bold.ttf", s)
SANSI = lambda s: F("Atkinson-Italic.ttf", s)
OLD = lambda s: F("FellSC.ttf", s)
OLDI = lambda s: F("Fell-Italic.ttf", s)

# who: (font, size factor, capitals only)
HANDS = {
    "nell": ("ReenieBeanie.ttf", 1.18, False),
    "jad": ("ArchitectsDaughter.ttf", 0.8, True),
    "jad_sig": ("ArchitectsDaughter.ttf", 0.86, False),
    "sal": ("Caveat.ttf", 1.0, False),
    "inez": ("GochiHand.ttf", 0.88, True),
    "teodor": ("LaBelleAurore.ttf", 0.82, False),
    "kaye": ("Zeyada.ttf", 1.15, False),
    "tobi": ("Schoolbell.ttf", 0.9, True),
    "anon": ("NothingYouCouldDo.ttf", 0.92, False),
    "clerk_a": ("CedarvilleCursive.ttf", 0.85, False),
    "clerk_b": ("DawningOfANewDay.ttf", 1.1, False),
    "adeyemi": ("Kalam.ttf", 0.8, False),
    "pike": ("PatrickHand.ttf", 0.92, False),
    "rostami": ("DawningOfANewDay.ttf", 1.1, False),
    "rusu": ("NothingYouCouldDo.ttf", 0.92, False),
    "hollis": ("CedarvilleCursive.ttf", 0.85, False),
}


def hand_font(who, size):
    fname, k, _ = HANDS[who]
    base = FONTS if fname == "ReenieBeanie.ttf" else HANDFONTS
    return _font(os.path.join(base, fname), size * k)


def write(img, xy, text, who="nell", size=40, fill=BIRO, jitter=1.2, wobble=1.2, slant=0.0, track=1.0, alpha=1.0):
    """Handwriting. Each word sits on its own slightly-off baseline at its own
    slight angle, and the pen's pressure wanders across it. xy is top-left."""
    if HANDS[who][2]:
        text = text.upper()
    f = hand_font(who, size)
    asc, desc = f.getmetrics()
    sp = f.getlength(" ")
    x, y = xy
    for word in text.split(" "):
        if word == "":
            x += sp * track
            continue
        wl = f.getlength(word)
        pad = int(asc * 0.5) + 10
        w, h = int(wl + pad * 2), int(asc + desc + pad * 2)
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).text((pad, pad), word, font=f, fill=255)
        if slant:
            m = m.transform(m.size, Image.AFFINE, (1, slant, -slant * (pad + asc), 0, 1, 0), resample=Image.BICUBIC)
        a = R.uniform(-wobble, wobble)
        if a:
            m = m.rotate(a, resample=Image.BICUBIC, center=(pad, pad + asc))
        arr = np.asarray(m, np.float32)
        ramp = np.linspace(R.uniform(0.8, 1.0), R.uniform(0.8, 1.0), w, dtype=np.float32)[None, :]
        arr = arr * ramp * alpha * (0.86 + 0.14 * NP.random(arr.shape, dtype=np.float32))
        m = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
        img.paste(Image.new("RGB", m.size, fill), (int(round(x - pad)), int(round(y - pad + R.uniform(-jitter, jitter)))), m)
        x += (wl + sp) * track + R.uniform(-0.5, 1.2)
    return x


def measure(text, who, size):
    if HANDS[who][2]:
        text = text.upper()
    return hand_font(who, size).getlength(text)


def write_fit(img, xy, text, who, size, maxw, **kw):
    while size > 12 and measure(text, who, size) > maxw:
        size -= 1
    return write(img, xy, text, who, size, **kw)


def paper(w, h, base=(240, 236, 224), grain=3.5, mottle=10.0, fibres=0.0, age=0.0, edge_age=0.0):
    a = np.empty((h, w, 3), np.float32)
    a[:] = base
    a += NP.normal(0, grain, (h, w, 1)).astype(np.float32)
    low = NP.normal(0, 1, (h // 48 + 3, w // 48 + 3))
    low = (low - low.min()) / (np.ptp(low) + 1e-6)
    low = np.asarray(Image.fromarray((low * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255.0
    a -= (low[..., None] - 0.5) * mottle
    if age > 0:
        a[..., 2] -= age * 34
        a[..., 1] -= age * 12
    if edge_age > 0:
        yy, xx = np.mgrid[0:h, 0:w]
        dist = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)).astype(np.float32)
        e = np.clip(1 - dist / (min(w, h) * 0.07), 0, 1) ** 2
        a -= e[..., None] * np.array([16, 30, 56], np.float32) * edge_age
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    if fibres > 0:
        d = ImageDraw.Draw(img)
        c = tuple(int(v * 0.86) for v in base)
        for _ in range(int(w * h / 9000 * fibres)):
            x, y = R.randrange(w), R.randrange(h)
            L = R.randint(3, 14)
            t = R.random() * math.pi
            d.line([(x, y), (x + math.cos(t) * L, y + math.sin(t) * L)], fill=c)
    return img


def box(d, x, y, w, h, label="", font=None, col=INK, lw=2):
    d.rectangle([x, y, x + w, y + h], outline=col, width=lw)
    if label:
        d.text((x + 7, y + 4), label, font=font or SANS(15), fill=col)


def wrap_lines(text, font, maxw):
    lines, cur = [], ""
    for w in text.split(" "):
        t = (cur + " " + w).strip()
        if font.getlength(t) > maxw and cur:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def para(d, xy, text, font, maxw, fill=INK, leading=1.3):
    x, y = xy
    for ln in wrap_lines(text, font, maxw):
        d.text((x, y), ln, font=font, fill=fill)
        y += font.size * leading
    return y


def centre(d, y, text, font, w, fill=INK):
    d.text(((w - font.getlength(text)) / 2, y), text, font=font, fill=fill)


def fit_font(maker, text, maxw, size):
    while size > 8 and maker(size).getlength(text) > maxw:
        size -= 1
    return maker(size)


def tape(img, cx, cy, w=120, h=38, rot=0.0):
    """A strip of old sellotape, gone yellow."""
    t = Image.new("L", (w, h), 0)
    ImageDraw.Draw(t).rectangle([0, 0, w, h], fill=130)
    a = np.asarray(t, np.float32).copy()
    a[:, :3] = 40
    a[:, -3:] = 40
    a *= 0.85 + 0.3 * NP.random(a.shape)
    t = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).rotate(rot, expand=True, resample=Image.BICUBIC)
    img.paste(Image.new("RGB", t.size, (232, 214, 150)), (int(cx - t.width / 2), int(cy - t.height / 2)), t)


def dotmatrix(img, xy, text, pitch=3.2, dot=2.6, col=(40, 38, 52), font="Atkinson-Regular.ttf", px=11):
    """Text from a dot-matrix head: the glyphs rendered tiny without
    antialiasing, then each pixel struck as one round dot."""
    f = F(font, px)
    w = int(f.getlength(text)) + 4
    m = Image.new("1", (w, px + 6), 0)
    ImageDraw.Draw(m).text((1, 1), text, font=f, fill=1)
    a = np.asarray(m)
    d = ImageDraw.Draw(img)
    x0, y0 = xy
    for yy, xx in zip(*np.nonzero(a)):
        cx = x0 + xx * pitch + R.uniform(-0.25, 0.25)
        cy = y0 + yy * pitch
        d.ellipse([cx, cy, cx + dot, cy + dot], fill=col)
    return x0 + w * pitch


def photocopy(img, strength=1.0):
    """What a copy shop's machine does to a page: greys it, thickens the type,
    leaves specks and the shadow of the lid along one edge."""
    g0 = ImageOps.grayscale(img)
    g = Image.blend(g0, g0.filter(ImageFilter.MinFilter(3)), 0.35)
    a = np.asarray(g, np.float32)
    a = 238 - (238 - a) * 1.15
    a -= 6 * strength
    h, w = a.shape
    specks = NP.random((h, w)) > 0.9993
    a[specks] = 70
    edge = (np.clip(1 - np.arange(w, dtype=np.float32) / 26.0, 0, 1) ** 2)[::-1]
    a -= edge[None, :] * 70 * strength
    a = np.clip(a, 0, 255).astype(np.uint8)
    rgb = np.stack([a, a, np.clip(a.astype(np.int16) + 2, 0, 255).astype(np.uint8)], -1)
    return Image.fromarray(rgb)


def save(img, name, q=86):
    img.convert("RGB").save(os.path.join(OUT, name + ".jpg"), quality=q, optimize=True, subsampling=0)
    return img


# ------------------------------------------------------------------ the printer

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 + 1 / 32


def printout(img, name, dots=None, pitch=3):
    """How the booking printer sees a picture: ordered dots, black on a
    perforated strip. Paper tone goes to nothing; only marks print."""
    if dots is None:
        dots = 150 if img.height > img.width else 200
    g = np.asarray(ImageOps.grayscale(img), np.float32) / 255.0
    lo, hi = np.percentile(g, 1.0), np.percentile(g, 50)
    g = np.clip((g - lo) / max(hi - lo, 1e-3), 0, 1)
    h = int(round(img.height * dots / img.width))
    small = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((dots, h), Image.LANCZOS), np.float32) / 255.0
    th = np.tile(BAYER, (h // 4 + 1, dots // 4 + 1))[:h, :dots]
    on = small < th * 0.92
    margin_x, margin_y = 34, 24
    W, H = dots * pitch + margin_x * 2, h * pitch + margin_y * 2
    strip = Image.new("RGB", (W, H), (238, 232, 214))
    d = ImageDraw.Draw(strip)
    r = pitch * 0.46
    for yy, xx in zip(*np.nonzero(on)):
        cx = margin_x + xx * pitch + pitch / 2
        cy = margin_y + yy * pitch + pitch / 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(40, 38, 50))
    for y in range(10, H, 22):
        d.ellipse([9, y, 19, y + 10], fill=(22, 20, 24))
        d.ellipse([W - 19, y, W - 9, y + 10], fill=(22, 20, 24))
    for y in range(0, H, 6):
        d.point((27, y), fill=(190, 180, 160))
        d.point((W - 28, y), fill=(190, 180, 160))
    strip.save(os.path.join(OUT, name + "_print.png"), optimize=True)


# ------------------------------------------------------------------ the camera

def _coeffs(dst, src):
    m = []
    for (x, y), (u, v) in zip(dst, src):
        m.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        m.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    return np.linalg.solve(np.array(m, np.float64), np.array(src, np.float64).reshape(8)).tolist()


def photograph(scene, out_w, keystone=(0.035, 0.02), light=(0.18, -0.22), warmth=(1.05, 1.0, 0.9), vignette=0.5, blur=0.7, noise=5.0):
    """A phone held not quite square over a table under a ceiling light."""
    W, H = scene.size
    kx, ky = keystone[0] * W, keystone[1] * H
    src = [(kx, ky), (W - kx * 0.4, ky * 0.3), (W + kx * 0.2, H), (-kx * 0.3, H - ky * 0.5)]
    img = scene.transform((W, H), Image.PERSPECTIVE, _coeffs([(0, 0), (W, 0), (W, H), (0, H)], src), Image.BICUBIC)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nx, ny = xx / W - 0.5, yy / H - 0.5
    lit = (1.0 + light[0] * nx * 2 + light[1] * ny * 2) * (1.0 - vignette * (nx ** 2 + ny ** 2) * 1.5)
    a = np.asarray(img, np.float32) * lit[..., None] * np.array(warmth, np.float32)[None, None, :]
    a += NP.normal(0, noise, a.shape).astype(np.float32)
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    img = img.resize((out_w, int(H * out_w / W)), Image.LANCZOS)
    return img.filter(ImageFilter.UnsharpMask(radius=1.4, percent=50, threshold=2))


def drop(canvas, sheet, xy, rot=0.0, shadow=0.55, blur=9, offset=(6, 9)):
    """Lay a sheet on a surface, turned a little, with a soft shadow under it."""
    s = sheet.convert("RGBA").rotate(rot, expand=True, resample=Image.BICUBIC)
    sh = Image.new("L", canvas.size, 0)
    sh.paste(s.split()[3].point(lambda v: int(v * shadow)), (xy[0] + offset[0], xy[1] + offset[1]))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste((0, 0, 0), (0, 0), sh)
    canvas.paste(s, xy, s)


def wood(w, h, base=(122, 82, 50)):
    """A kitchen table: stretched noise with rings through it."""
    n = NP.normal(0, 1, (h // 6 + 2, w // 90 + 2))
    n = np.asarray(Image.fromarray(((n - n.min()) / np.ptp(n) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255
    yy = np.arange(h, dtype=np.float32)[:, None]
    rings = 0.5 + 0.5 * np.sin(yy * 0.09 + n * 9.0)
    a = np.empty((h, w, 3), np.float32)
    a[:] = base
    a *= (0.78 + 0.3 * rings)[..., None]
    a += NP.normal(0, 3, (h, w, 1))
    for y in range(0, h, 170):
        a[max(0, y - 1):y + 2] *= 0.55
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def formica(w, h, base=(150, 160, 164)):
    """A council desk: grey-blue laminate with a fine speckle."""
    a = np.empty((h, w, 3), np.float32)
    a[:] = base
    a += NP.normal(0, 4, (h, w, 1))
    sp = NP.random((h, w))
    a[sp > 0.985] *= 0.8
    a[sp < 0.01] *= 1.1
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))


def cardboard(w, h):
    a = np.empty((h, w, 3), np.float32)
    a[:] = (170, 128, 84)
    xx = np.arange(w, dtype=np.float32)[None, :]
    a *= (0.96 + 0.04 * np.sin(xx * 0.55))[..., None]
    a += NP.normal(0, 4, (h, w, 1))
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


# ------------------------------------------------------------------ the slip

def slip():
    seed("slip")
    W, H = 900, 640
    img = paper(W, H, base=(196, 214, 232), grain=3, mottle=8)
    d = ImageDraw.Draw(img)
    # pre-printed on the stock, in council blue
    blue = (30, 56, 104)
    d.text((40, 28), "COMMUNITY SERVICES", font=SANSB(30), fill=blue)
    d.text((40, 66), "Arrivals & Registration  /  Transition", font=SANS(20), fill=blue)
    d.text((W - 250, 34), "APPOINTMENT", font=SANSB(28), fill=blue)
    d.line([(40, 102), (W - 40, 102)], fill=blue, width=2)
    for lab, y in [("To", 128), ("Purpose", 228), ("When", 318), ("Where", 368), ("Bring", 458)]:
        d.text((40, y + 2), lab, font=SANS(19), fill=blue)
    # the machine's part, struck through the ribbon in dots; the ribbon was running out
    dotmatrix(img, (150, 124), "ARI (SURNAME NOT GIVEN)")
    dotmatrix(img, (150, 166), "OFFICE G/1, FERRIER COURT")
    faint = (96, 100, 124)
    dotmatrix(img, (150, 224), "ARRIVAL REGISTRATION &", col=faint)
    dotmatrix(img, (150, 266), "RESPONDER INDUCTION", col=faint)
    dotmatrix(img, (150, 314), "SAT 26 SEP   05:30")
    dotmatrix(img, (150, 364), "FERRIER COURT, LOBBY")
    dotmatrix(img, (150, 406), "(OVERNIGHT SUPPORT DESK)")
    dotmatrix(img, (150, 454), "THIS SLIP; ONE WITNESS")
    d.line([(40, 516), (W - 40, 516)], fill=blue, width=1)
    d.text((40, 530), "Ref.", font=SANS(17), fill=blue)
    dotmatrix(img, (84, 530), "ARP-2/FC/0009", pitch=2.4, dot=2.0)
    d.text((40, 572), "This appointment was made automatically. Please do not reply to this slip.", font=SANS(17), fill=blue)
    # the tractor-feed edge torn off, leaving half-holes
    for y in range(14, H, 26):
        d.arc([W - 16, y, W + 4, y + 12], 90, 270, fill=(160, 178, 200), width=2)
    save(img, "slip")


# ------------------------------------------------------------------ the lobby notice

def notice_lobby():
    seed("notice_lobby")
    W, H = 900, 1240
    img = paper(W, H, base=(242, 238, 226))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 150], fill=(34, 62, 104))
    d.text((50, 36), "OVERNIGHT SUPPORT SERVICE", font=SANSB(44), fill=(240, 240, 235))
    d.text((50, 92), "Ferrier Court", font=SANS(30), fill=(210, 220, 235))
    d.text((50, 200), "FINAL NIGHT", font=SANSB(78), fill=(34, 62, 104))
    body = ["From 06:00 on Saturday 26 September,", "every resident of Ferrier Court is covered", "by their Designated Personal Contact", "under the DPC Scheme.", "", "The Overnight Support Service will close.", "", "Your new Community Responder,", "ARI,", "begins duties at 06:00.", "", "Thank you for thirty-five years."]
    y = 330
    for ln in body:
        d.text((50, y), ln, font=SANSB(46) if ln == "ARI," else SANS(34), fill=INK)
        y += 50 if ln else 26
    d.text((50, y + 30), "Community Services", font=SANSB(28), fill=(34, 62, 104))
    # somebody's biro, pressed hard
    write(img, (80, 1010), "WHO IS ARI ??", "anon", 74, BIRO_BLACK, wobble=2.5)
    # and in the corner, lightly, in pencil: the same hand as Nell's form
    write(img, (650, 1150), "ask jad", "nell", 40, PENCIL, alpha=0.75)
    for x, yy in [(14, 10), (W - 50, 10), (14, H - 38), (W - 50, H - 38)]:
        tape(img, x + 18, yy + 14, 70, 26, R.uniform(-20, 20))
    save(img, "notice_lobby")


# ------------------------------------------------------------------ Tobi's drawing

def tobi_drawing():
    seed("tobi_drawing")
    W, H = 1100, 780
    img = paper(W, H, base=(212, 194, 150), grain=6, mottle=16, fibres=1.6)
    # the paper's tooth: where the crayon catches and where it skips
    t = NP.random((H, W)).astype(np.float32)
    t = np.asarray(Image.fromarray((t * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9)), np.float32)
    tooth = np.argsort(np.argsort(t.ravel())).reshape(H, W).astype(np.float32) / (W * H)

    def apply(mask, col, pressure=0.72):
        m = np.asarray(mask, np.float32) / 255.0
        a = m * np.clip((tooth - (1 - pressure)) * 5.0, 0, 1)
        img.paste(Image.new("RGB", (W, H), col), (0, 0), Image.fromarray((a * 255).astype(np.uint8)))

    def line(pts, col, w=9, passes=3, pressure=0.75):
        m = Image.new("L", (W, H), 0)
        md = ImageDraw.Draw(m)
        for _ in range(passes):
            md.line([(x + R.uniform(-2.5, 2.5), y + R.uniform(-2.5, 2.5)) for x, y in pts], fill=255, width=w, joint="curve")
        apply(m.filter(ImageFilter.GaussianBlur(0.8)), col, pressure)

    def scribble(region, col, angle=None, spacing=8, width=7, pressure=0.7, overshoot=3):
        bb = region.getbbox()
        if not bb:
            return
        cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
        diag = int(math.hypot(bb[2] - bb[0], bb[3] - bb[1])) + 40
        st = Image.new("L", (diag, diag), 0)
        sd = ImageDraw.Draw(st)
        pts, y, left = [], 0.0, True
        while y < diag:
            pts.append((R.uniform(0, 14) if left else diag - R.uniform(0, 14), y))
            y += spacing * R.uniform(0.7, 1.3)
            left = not left
        sd.line(pts, fill=255, width=width, joint="curve")
        st = st.rotate(R.uniform(20, 70) if angle is None else angle, resample=Image.BICUBIC)
        full = Image.new("L", (W, H), 0)
        full.paste(st, (int(cx - diag / 2), int(cy - diag / 2)))
        reg = region.filter(ImageFilter.MaxFilter(overshoot * 2 + 1)) if overshoot else region
        apply(ImageChops.multiply(full, reg), col, pressure)

    def poly(pts):
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).polygon(pts, fill=255)
        return m

    def ellipse(bb):
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).ellipse(bb, fill=255)
        return m

    NIGHT = (40, 50, 110)
    # a strip of night along the top, started with energy and not finished
    scribble(poly([(0, 0), (W, 0), (W, 70), (720, 96), (430, 60), (0, 104)]), NIGHT, angle=8, spacing=11, pressure=0.62)
    # the moon and some stars
    scribble(ellipse([930, 18, 1010, 98]), (236, 204, 60), pressure=0.85)
    for sx, sy in [(560, 40), (660, 110), (80, 150), (160, 60), (1040, 150)]:
        for k in range(4):
            a = k * math.pi / 4
            line([(sx - math.cos(a) * 14, sy - math.sin(a) * 14), (sx + math.cos(a) * 14, sy + math.sin(a) * 14)], (236, 204, 60), 5, 1)
    # grass
    scribble(poly([(0, 640), (W, 630), (W, 690), (0, 700)]), (70, 140, 60), angle=80, spacing=6, pressure=0.7)
    # the building, a lot of windows, the lit ones yellow
    bx0, by0, bx1, by1 = 650, 170, 990, 660
    scribble(poly([(bx0, by0), (bx1, by0), (bx1, by1), (bx0, by1)]), (112, 110, 124), angle=65, spacing=9, pressure=0.6, overshoot=5)
    line([(bx0, by0), (bx1, by0), (bx1, by1), (bx0, by1), (bx0, by0)], (44, 38, 40), 7, 2)
    line([(830, by0), (830, by0 - 50), (810, by0 - 60)], (44, 38, 40), 5, 2)
    line([(830, by0 - 40), (860, by0 - 55)], (44, 38, 40), 5, 1)
    for r in range(6):
        for c in range(5):
            x, y = bx0 + 22 + c * 64, by0 + 24 + r * 66
            lit = (r * 5 + c) % 3 == 0
            wm = poly([(x, y), (x + 38, y), (x + 38, y + 40), (x, y + 40)])
            scribble(wm, (242, 200, 54) if lit else (46, 52, 92), angle=R.uniform(30, 60), spacing=6, width=6, pressure=0.85, overshoot=2)
    scribble(poly([(795, 590), (845, 590), (845, 660), (795, 660)]), (110, 62, 34), angle=90, spacing=6, pressure=0.85)
    # a person in an enormous brown coat, arms out, the sleeves right over the hands
    coat = [(262, 262), (418, 262), (500, 640), (180, 640)]
    scribble(poly(coat), (124, 76, 38), angle=75, spacing=7, pressure=0.78, overshoot=4)
    line(coat + [coat[0]], (70, 42, 22), 8, 2)
    for (x0, y0, x1, y1) in [(270, 300, 70, 200), (410, 300, 610, 200)]:
        sleeve = Image.new("L", (W, H), 0)
        ImageDraw.Draw(sleeve).line([(x0, y0), (x1, y1)], fill=255, width=46)
        scribble(sleeve, (124, 76, 38), spacing=6, pressure=0.8, overshoot=0)
        line([(x0, y0 - 22), (x1, y1 - 22)], (70, 42, 22), 5, 1)
        line([(x0, y0 + 22), (x1, y1 + 22)], (70, 42, 22), 5, 1)
    for bx, by in [(340, 360), (340, 430), (340, 500), (340, 570)]:
        scribble(ellipse([bx - 9, by - 9, bx + 9, by + 9]), (40, 30, 26), pressure=0.9, overshoot=0)
    line([(300, 640), (294, 692)], (40, 40, 60), 20, 2)
    line([(380, 640), (388, 692)], (40, 40, 60), 20, 2)
    scribble(ellipse([262, 682, 312, 708]), (30, 28, 30), pressure=0.9, overshoot=0)
    scribble(ellipse([370, 682, 420, 708]), (30, 28, 30), pressure=0.9, overshoot=0)
    # the face: nothing. A clean oval, everything round it carefully coloured up to its edge
    face = [290, 118, 392, 246]
    hair = ImageChops.subtract(ellipse([262, 88, 420, 268]), ellipse(face))
    hair = ImageChops.subtract(hair, poly([(300, 240), (382, 240), (400, 272), (282, 272)]))
    scribble(hair, (58, 40, 30), angle=35, spacing=4, width=7, pressure=0.92, overshoot=0)
    scribble(hair, (58, 40, 30), angle=-30, spacing=6, width=6, pressure=0.8, overshoot=0)
    ImageDraw.Draw(img).ellipse(face, outline=(150, 140, 120), width=1)
    # ARI, big and red
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).text((256, -6), "ARI", font=hand_font("tobi", 118), fill=255)
    apply(m.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(0.8)), (206, 40, 40), 0.85)
    # the caption, the letters shrinking as the room runs out
    text = "A PERSON WHO HELPS IN OUR COMMUNITY  BY TOBI AMADI 3B"
    x, size = 28.0, 46.0
    for i, ch in enumerate(text):
        f = hand_font("tobi", size)
        if ch != " ":
            m = Image.new("L", (W, H), 0)
            gl = Image.new("L", (80, 90), 0)
            ImageDraw.Draw(gl).text((10, 6), ch, font=f, fill=255)
            if ch == "S" and i < 20:
                bb = gl.getbbox()
                if bb:
                    gl.paste(ImageOps.mirror(gl.crop(bb)), bb[:2])
            gl = gl.rotate(R.uniform(-8, 8), resample=Image.BICUBIC)
            m.paste(gl, (int(x - 10), int(718 + (46 - size) * 0.6 + R.uniform(-3, 3))))
            apply(m.filter(ImageFilter.MaxFilter(3)), (36, 44, 116), 0.9)
        x += f.getlength(ch) + 2
        if i > 24:
            size = max(20.0, size - 0.9)
    save(img, "tobi_drawing")
    printout(img, "tobi_drawing", dots=200)


# ------------------------------------------------------------------ DPC-1

DPC_FIELDS = {
    "resident": (50, 185, 800, 70), "flat": (50, 271, 800, 70), "household": (50, 357, 800, 70),
    "contact": (50, 486, 800, 76), "relationship": (50, 578, 390, 70), "telephone": (460, 578, 390, 70),
    "signature": (50, 736, 520, 90), "date": (590, 736, 260, 90),
    "countersig": (50, 916, 520, 80), "cdate": (590, 916, 260, 80),
}


def dpc_blank(copy=True):
    """The one-page reformatted DPC-1, as run off at Aldine Copy & Print."""
    W, H = 900, 1273
    img = paper(W, H, base=(246, 246, 242), grain=2.5, mottle=5)
    d = ImageDraw.Draw(img)
    d.text((50, 40), "DPC-1", font=SANSB(40), fill=INK)
    d.text((190, 44), "DESIGNATED PERSONAL CONTACT NOMINATION", font=SANSB(26), fill=INK)
    d.text((50, 96), "Community Services  ·  Overnight Support Transition", font=SANS(20), fill=INK)
    d.line([(50, 132), (850, 132)], fill=INK, width=2)
    d.text((50, 150), "1   ABOUT YOU", font=SANSB(22), fill=INK)
    labels = {"resident": "Resident", "flat": "Flat", "household": "Household", "contact": "Contact name",
              "relationship": "Relationship", "telephone": "Telephone", "signature": "Resident signature",
              "date": "Date", "countersig": "Contact countersignature", "cdate": "Date"}
    for k, (x, y, w, h) in DPC_FIELDS.items():
        box(d, x, y, w, h, labels[k])
    d.text((50, 450), "2   YOUR DESIGNATED PERSONAL CONTACT", font=SANSB(22), fill=INK)
    d.text((50, 664), "“My contact will answer calls, accompany me to appointments,", font=SANS(22), fill=INK)
    d.text((50, 694), "and respond in an emergency.”", font=SANS(22), fill=INK)
    d.text((50, 846), "3   CONTACT DECLARATION", font=SANSB(22), fill=INK)
    d.text((50, 880), "I agree to be the Designated Personal Contact named above.", font=SANS(20), fill=INK)
    para(d, (50, 1024), "Return to Community Services, Transition Team, by hand or by post. A nomination that has not been countersigned by the contact by 06:00 on Saturday 26 September will be treated as incomplete.", SANS(19), 800)
    d.text((50, 1222), "One-page reformatted copy. Original form DPC-1 (2 pp.)", font=SANS(15), fill=GREY)
    return photocopy(img) if copy else img


def dpc_filled(resident, flat, household, sig, date, who, sig_who=None):
    img = dpc_blank()
    f = DPC_FIELDS
    col = BIRO if who not in ("teodor", "kaye", "jad") else BIRO_BLACK
    for key, val in (("resident", resident), ("flat", flat), ("household", household)):
        x, y, w, h = f[key]
        write_fit(img, (x + 22, y + 24), val, who, 40, w - 40, fill=col)
    # Jad's part, the same on every one: neat capitals, a black fineliner
    x, y, w, h = f["contact"]
    write(img, (x + 26, y + 24), "ARI", "jad", 48, BIRO_BLACK, wobble=0.5, jitter=0.5)
    x, y, w, h = f["relationship"]
    write(img, (x + 22, y + 26), "FRIEND", "jad", 36, BIRO_BLACK, wobble=0.5, jitter=0.5)
    x, y, w, h = f["telephone"]
    write(img, (x + 20, y + 26), "01632 960 247", "jad", 34, BIRO_BLACK, wobble=0.5, jitter=0.5)
    x, y, w, h = f["signature"]
    write_fit(img, (x + 28, y + 30), sig, sig_who or who, 54, w - 50, fill=col, slant=-0.15)
    x, y, w, h = f["date"]
    write(img, (x + 22, y + 32), date, who, 42, fill=col)
    return img


NINE = [
    # resident, flat, household, signature, date, hand
    ("Olu & Grace Adeyemi", "1D, Ferrier Court", "O. Adeyemi; G. Adeyemi", "O. Adeyemi", "14 Aug", "adeyemi"),
    ("June Pike", "1B, Ferrier Court", "June Pike", "J. Pike", "14 Aug", "pike"),
    ("Kaveh Rostami", "2A, Ferrier Court", "K. Rostami", "K. Rostami", "14 Aug", "rostami"),
    ("Stefan Rusu", "6A, Ferrier Court", "S. Rusu", "S. Rusu", "15 Aug", "rusu"),
    ("D. Hollis", "6C, Ferrier Court", "Mr D. Hollis", "D. Hollis", "15 Aug", "hollis"),
    ("Bernadette Kaye", "2C, Ferrier Court", "Mrs B. Kaye", "B. Kaye", "14 Aug", "kaye"),
    ("Teodor Vass", "5A, Ferrier Court", "Teodor Vass", "T. Vass", "15 Aug", "teodor"),
    ("Nell Amadi", "3B, Ferrier Court", "Nell Amadi; Tobi Amadi (7)", "N. Amadi", "14 Aug", "nell"),
    ("Jad Abdallah", "4B, Ferrier Court", "J. Abdallah", "J. Abdallah", "15 Aug", "jad"),
]


def dpc_forms():
    seed("dpc_forms")
    save(dpc_blank(), "dpc_blank")
    forms = {}
    for row in NINE:
        who = row[5]
        forms[who] = dpc_filled(*row[:5], who, sig_who="jad_sig" if who == "jad" else None)
    save(forms["teodor"], "dpc_form")
    save(forms["nell"], "dpc_nell")
    # Nell's photo of her copy, on the kitchen table, over one of Tobi's drawings
    seed("nell_form")
    scene = wood(1100, 1440, (132, 92, 58))
    under = paper(700, 500, base=(200, 180, 140), grain=6, fibres=1.0)
    ud = ImageDraw.Draw(under)
    for k in range(26):
        y = 60 + k * 9
        ud.line([(380 + R.uniform(-6, 6), y), (560 + R.uniform(-10, 10), y + 14)], fill=(210, 60, 50), width=5)
    for k in range(22):
        y = 330 + k * 7
        ud.line([(60 + R.uniform(-8, 8), y), (640 + R.uniform(-20, 20), y + 6)], fill=(70, 140, 60), width=5)
    ud.ellipse([420, 180, 520, 280], outline=(240, 200, 50), width=7)
    drop(scene, under, (-160, -120), rot=12)
    drop(scene, forms["nell"].resize((860, 1216), Image.LANCZOS), (110, 110), rot=-2.2)
    pen = Image.new("RGBA", (380, 40), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pen)
    pd.rounded_rectangle([4, 6, 300, 34], 12, fill=(40, 110, 190, 255))
    pd.rounded_rectangle([280, 4, 376, 36], 12, fill=(230, 230, 236, 255))
    pd.polygon([(4, 12), (0, 20), (4, 28)], fill=(20, 20, 20, 255))
    drop(scene, pen, (640, 1290), rot=24, blur=5)
    photo = photograph(scene, 1000)
    save(photo, "nell_form")
    printout(photo, "nell_form")
    # Sal's photo: the nine, spread out on the desk in G/1 to compare
    seed("dpc_stack")
    scene = formica(1700, 1260)
    order = ["adeyemi", "pike", "rostami", "rusu", "hollis", "kaye", "teodor", "nell", "jad"]
    for i, who in enumerate(order):
        r, c = divmod(i, 3)
        f = forms[who].resize((400, 566), Image.LANCZOS)
        drop(scene, f, (70 + c * 540 + R.randint(-20, 20), 40 + r * 300 + R.randint(-14, 14)), rot=R.uniform(-5, 5), blur=7)
    photo = photograph(scene, 1400, keystone=(0.03, 0.02), light=(-0.1, -0.2), warmth=(0.97, 1.0, 1.04), vignette=0.4)
    save(photo, "dpc_stack")
    printout(photo, "dpc_stack")


# ------------------------------------------------------------------ the leaflet

def leaflet():
    seed("leaflet")
    W, H = 820, 1160
    img = paper(W, H, base=(246, 244, 238))
    d = ImageDraw.Draw(img)
    green, dark = (92, 150, 110), (30, 64, 44)
    d.rectangle([0, 0, W, 210], fill=green)
    d.text((40, 40), "ARRIVALS", font=SANSB(72), fill=(250, 250, 245))
    d.text((44, 130), "A guide for new persons", font=SANS(34), fill=(240, 250, 240))
    # clip art: a smiling telephone with arms
    cx, cy = 640, 124
    cream = (250, 250, 245)
    # arms first, so the body sits over their roots: one waving, one on the hip
    d.line([(cx + 58, cy + 10), (cx + 104, cy - 18), (cx + 118, cy - 58)], fill=dark, width=7, joint="curve")
    d.ellipse([cx + 104, cy - 82, cx + 132, cy - 54], fill=cream, outline=dark, width=4)
    d.line([(cx - 58, cy + 10), (cx - 100, cy + 26), (cx - 84, cy + 50)], fill=dark, width=7, joint="curve")
    d.rounded_rectangle([cx - 66, cy - 26, cx + 66, cy + 58], 18, fill=cream, outline=dark, width=4)
    d.arc([cx - 72, cy - 70, cx + 72, cy + 10], 200, 340, fill=dark, width=18)
    for s in (-1, 1):
        d.rounded_rectangle([cx + s * 62 - 20, cy - 52, cx + s * 62 + 20, cy - 26], 8, fill=dark)
    d.ellipse([cx - 28, cy - 6, cx - 14, cy + 8], fill=dark)
    d.ellipse([cx + 14, cy - 6, cx + 28, cy + 8], fill=dark)
    d.arc([cx - 28, cy, cx + 28, cy + 40], 20, 160, fill=dark, width=5)
    for k in range(5):
        d.arc([cx - 104 + k * 9, cy - 36 + k * 10, cx - 84 + k * 9, cy - 16 + k * 10], 0, 300, fill=dark, width=3)
    y = 250
    paras = [
        ("Some people arrive without the usual.", SANSB(30)),
        ("If you have come into being through a telephone line, a public address system, a radio frequency or another means of address, you may be an arrival.", SANS(26)),
        ("You are a person. You are entitled to register.", SANSB(28)),
        ("Registration gives you a name in law, a record, and access to services.", SANS(26)),
        ("You may be offered work. You do not have to accept work in order to register.", SANSB(26)),
        ("Where to go: Arrivals & Registration, Community Services (now part of Transition).", SANS(24)),
        ("Receiving rooms: most have closed. Please ask.", SANS(24)),
    ]
    for txt, f in paras:
        y = para(d, (40, y), txt, f, 740, leading=1.28) + 20
    y += 10
    d.rectangle([40, y, W - 40, y + 190], outline=dark, width=3)
    d.text((62, y + 16), "WHAT TO BRING", font=SANSB(24), fill=dark)
    d.text((62, y + 56), "Nothing. You may bring a witness:", font=SANS(24), fill=INK)
    d.text((62, y + 88), "somebody who will say they were there.", font=SANS(24), fill=INK)
    d.text((62, y + 134), "You do not need to know your name yet.", font=SANSB(24), fill=INK)
    d.line([(40, 1070), (W - 40, 1070)], fill=GREY, width=1)
    d.text((40, 1082), "Also available in large print, on audio cassette, and in other languages.", font=SANS(17), fill=GREY)
    d.text((40, 1110), "Community Services leaflet A/7", font=SANS(17), fill=GREY)
    save(img, "leaflet_arrivals")
    printout(img, "leaflet_arrivals")


# ------------------------------------------------------------------ the register

def register_page():
    seed("register_page")
    W, H = 1200, 860
    img = paper(W, H, base=(230, 220, 192), age=0.6, edge_age=0.8, mottle=16)
    # the gutter of the book, and the red cloth of the spine beyond it
    g = np.asarray(img, np.float32).copy()
    shade = np.clip(1 - np.arange(W, dtype=np.float32) / 90.0, 0, 1) ** 1.6
    g *= (1 - 0.45 * shade)[None, :, None]
    img = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 14, H], fill=(118, 32, 30))
    cols = [(52, "No."), (120, "Date"), (262, "Name as registered"), (560, "Called for by"), (838, "Remarks")]
    d.text((440, 22), "RECEIVING REGISTER · FERRIER ST. BATHS", font=OLD(30), fill=(64, 40, 30))
    for x, lab in cols:
        d.text((x, 72), lab, font=OLDI(24), fill=(96, 40, 30))
    for i in range(20):
        d.line([(34, 110 + i * 37), (1182, 110 + i * 37)], fill=(160, 170, 190), width=1)
    for x, _ in cols[1:]:
        d.line([(x - 12, 66), (x - 12, 842)], fill=(176, 64, 54), width=2)
    rows = [
        ("52", "14.1.1963", "Mr. R. Achebe", "his sister, Mrs. Obi", "Registered, housed. Fenwick Rd.", "clerk_a"),
        ("53", "22.3.1963", "Mrs. I. Sokol", "the Sokol family", "Registered.", "clerk_a"),
        ("54", "5.10.1963", "M. Shaw ('Nanny')", "the Pryce children", "Registered.", "clerk_a"),
        ("55", "19.12.1963", "Mr. F. Quayle", "Baths, lost property", "Registered, housed.", "clerk_a"),
        ("56", "11.1.1964", "Miss C. Adu", "St Anne's switchboard", "Registered. Employed at own request.", "clerk_a"),
        ("57", "20.2.1964", "Mr. W. Lusk", "the Lusk family", "Registered, housed.", "clerk_a"),
    ]
    for n, date in [("58", "4.3.1964"), ("59", "11.6.1964"), ("60", "30.9.1964"), ("61", "2.2.1965"), ("62", "18.5.1965"),
                    ("63", "1.9.1965"), ("64", "7.12.1965"), ("65", "20.3.1966"), ("66", "6.7.1966"), ("67", "14.10.1966"), ("68", "2.12.1966")]:
        rows.append((n, date, "Attendant", "Baths enquiries line", "Regd. & appointed, Mun. Attendant Gr. III", "clerk_b"))
    rows.append(("69", "7.8.1967", "Mrs. P. Oyelaran", "the Oyelaran family", "Registered, housed.", "clerk_a"))
    widths = [60, 130, 285, 265, 340]
    for i, row in enumerate(rows):
        yy = 110 + i * 37 - 30
        for (x, _), val, w in zip(cols, row[:5], widths):
            write_fit(img, (x, yy), val, row[5], 34, w, fill=(40, 40, 76), jitter=0.8, wobble=0.8)
    save(img, "register_page")


# ------------------------------------------------------------------ the poster

def poster():
    seed("poster")
    W, H = 820, 1160
    img = paper(W, H, base=(236, 226, 198), age=0.5, edge_age=1.0, mottle=18)
    d = ImageDraw.Draw(img)
    d.rectangle([26, 26, W - 26, H - 26], outline=NAVY, width=6)
    d.rectangle([38, 38, W - 38, H - 38], outline=NAVY, width=2)
    centre(d, 58, "MINISTRY OF HEALTH", OLD(22), W, RED)
    tf = fit_font(OLD, "THE RECEIVED PERSON", W - 120, 64)
    centre(d, 88, "THE RECEIVED PERSON", tf, W, NAVY)
    centre(d, 168, "What to expect in your first week", OLDI(32), W, NAVY)
    d.line([(90, 222), (W - 90, 222)], fill=RED, width=3)
    # the body, drawn stiffly, by someone who had only ever had one described to them
    cx, lw = 250, 3
    d.ellipse([cx - 44, 250, cx + 44, 356], outline=NAVY, width=lw)
    d.chord([cx - 58, 290, cx - 34, 318], 90, 270, outline=NAVY, width=2)
    d.chord([cx + 34, 290, cx + 58, 318], 270, 90, outline=NAVY, width=2)
    d.rectangle([cx - 14, 356, cx + 14, 378], outline=NAVY, width=lw)
    torso = [(cx - 84, 384), (cx + 84, 384), (cx + 62, 612), (cx - 62, 612)]
    # a halftone in the chest: cold
    for yy in range(396, 500, 9):
        for xx in range(cx - 80, cx + 80, 9):
            r = 1.2 + 2.4 * (1 - (yy - 396) / 104)
            if abs(xx - cx) < 80 - (yy - 384) * 0.09:
                d.ellipse([xx - r, yy - r, xx + r, yy + r], fill=(118, 146, 186))
    d.line(torso + [torso[0]], fill=NAVY, width=lw)
    # the stomach: an empty circle, dotted
    for k in range(28):
        a = k / 28 * math.tau
        px, py = cx + math.cos(a) * 36, 552 + math.sin(a) * 30
        d.ellipse([px - 2, py - 2, px + 2, py + 2], fill=NAVY)
    for s in (-1, 1):
        arm = [(cx + s * 84, 388), (cx + s * 104, 396), (cx + s * 126, 640), (cx + s * 100, 642)]
        d.line(arm + [arm[0]], fill=NAVY, width=lw)
        d.ellipse([cx + s * 113 - 18, 628, cx + s * 113 + 18, 680], outline=NAVY, width=lw)
        leg = [(cx + s * 8, 612), (cx + s * 60, 612), (cx + s * 50, 834), (cx + s * 18, 834)]
        d.line(leg + [leg[0]], fill=NAVY, width=lw)
        d.ellipse([cx + s * 34 - 34, 826, cx + s * 34 + 34, 852], outline=NAVY, width=lw)
    labels = [(300, "the head", (cx + 44, 300)), (440, "the chest, which will be cold", (cx + 60, 440)),
              (552, "the stomach, which will be empty", (cx + 36, 552)), (730, "the legs", (cx + 54, 730))]
    for yy, t, (ax, ay) in labels:
        d.line([(ax + 6, ay), (432, yy)], fill=NAVY, width=1)
        d.ellipse([ax - 4, ay - 4, ax + 4, ay + 4], fill=NAVY)
        d.text((440, yy - 16), t, font=fit_font(OLDI, t, W - 70 - 440, 27), fill=INK)
    d.text((cx - 108, 866), "Fig. 1. The received person, front view.", font=OLDI(18), fill=NAVY)
    d.line([(90, 900), (W - 90, 900)], fill=RED, width=2)
    left = ["You will be hungry. This is normal. Eat little and often.", "You will be cold.",
            "You may not recognise your reflection. This is normal. Do not stare at mirrors for long periods; your face will settle."]
    right = ["You may hear the line for some weeks. This will fade.", "Rest.", "Registration is your right."]
    y = 914
    for t in left:
        y = para(d, (60, y), t, OLD(18), 350, INK, 1.18) + 5
    assert y < H - 72, y
    y = 914
    for t in right:
        y = para(d, (432, y), t, OLD(18), 334, INK, 1.18) + 5
    d.text((432, y + 2), "Ask the attendant.", font=OLD(25), fill=RED)
    centre(d, H - 64, "Issued 1956  ·  Crown copyright  ·  Display in receiving rooms", OLDI(15), W, NAVY)
    # the pin holes of fifty years
    for x, yy in [(20, 18), (W - 30, 20), (22, H - 30), (W - 32, H - 28)]:
        d.ellipse([x, yy, x + 8, yy + 8], fill=(60, 50, 40))
        d.ellipse([x - 5, yy - 5, x + 13, yy + 13], outline=(150, 110, 70))
    save(img, "poster_received")


# ------------------------------------------------------------------ ARP-2

ARP_BOXES = {"nominee": (50, 170, 800, 76), "building": (50, 262, 800, 76), "sign": (50, 470, 800, 160)}


def arp2_top():
    seed("arp2_top")
    W, H = 900, 1273
    img = paper(W, H, base=(247, 246, 242), grain=2.5)
    d = ImageDraw.Draw(img)
    d.text((50, 40), "ARP-2", font=SANSB(44), fill=INK)
    d.text((210, 48), "ARRIVAL & RESPONDER PACKET", font=SANSB(30), fill=INK)
    d.text((50, 104), "TOP SHEET  ·  Carbon set. Do not separate.", font=SANS(22), fill=GREY)
    d.line([(50, 140), (850, 140)], fill=INK, width=2)
    x, y, w, h = ARP_BOXES["nominee"]
    box(d, x, y, w, h, "Nominee")
    d.text((x + 30, y + 26), "ARI", font=TYPE(40), fill=INK)
    x, y, w, h = ARP_BOXES["building"]
    box(d, x, y, w, h, "Building")
    d.text((x + 30, y + 28), "Ferrier Court (42 households)", font=TYPE(32), fill=INK)
    d.text((50, 410), "Please sign below to complete your registration.", font=SANSB(30), fill=INK)
    x, y, w, h = ARP_BOXES["sign"]
    box(d, x, y, w, h, "Signature", lw=4)
    d.text((50, 668), "Thank you. Your registration will be processed.", font=SANS(22), fill=GREY)
    d.rectangle([50, 1030, 850, 1180], outline=GREY, width=1)
    d.text((64, 1040), "FOR OFFICE USE", font=SANSB(16), fill=GREY)
    d.text((64, 1076), "Received by ...............................   Date ....................", font=SANS(18), fill=GREY)
    d.text((64, 1116), "Keyed  [   ]      Ref.  ARP-2/FC/0009", font=SANS(18), fill=GREY)
    d.text((50, 1214), "ARP-2 (3 pp.)  Top copy: white.  Page 1: yellow.  Page 2: pink.", font=SANS(15), fill=GREY)
    save(img, "arp2_top")


def arp2_under():
    seed("arp2_under")

    def carbon_page(base, title, fields, body, sign_label, extra=None):
        W, H = 900, 1273
        pg = paper(W, H, base=base, grain=2.5, mottle=6)
        d = ImageDraw.Draw(pg)
        d.text((50, 40), title[0], font=SANSB(36), fill=INK)
        d.text((50, 92), title[1], font=fit_font(SANSB, title[1], 800, 22), fill=INK)
        d.line([(50, 140), (850, 140)], fill=INK, width=2)
        for key, lab in fields:
            x, y, w, h = ARP_BOXES[key]
            box(d, x, y, w, h, lab)
        x, y, w, h = ARP_BOXES["sign"]
        box(d, x, y, w, h, sign_label, lw=3)
        yy = 360
        for ln in body[0]:
            d.text((50, yy), ln, font=SANS(22), fill=INK)
            yy += 32
        yy = 660
        for ln in body[1]:
            d.text((50, yy), ln, font=SANS(24), fill=INK)
            yy += 36 if ln else 14
        if extra:
            extra(d)
        # what the top sheet's typing left, pressed through in carbon
        x, y, w, h = ARP_BOXES["nominee"]
        d.text((x + 30, y + 26), "ARI", font=TYPE(40), fill=CARBON)
        x, y, w, h = ARP_BOXES["building"]
        d.text((x + 30, y + 28), "Ferrier Court (42 households)", font=TYPE(32), fill=CARBON)
        a = np.asarray(pg, np.float32) * (1 - 0.05 * NP.random((H, W)))[..., None]
        return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

    def r1_extra(d):
        box(d, 50, 780, 800, 150, "Body record")

    p1 = carbon_page((246, 236, 176), ("PAGE 1", "R-1 SECTION  ·  REGISTRATION OF ARRIVAL"),
                     [("nominee", "Name of arrival"), ("building", "Place of arrival")],
                     (["Witness: ..............................................", "Date:  26 September"], []),
                     "Signature of arrival", r1_extra)
    p2 = carbon_page((246, 214, 214), ("PAGE 2", "RA-3 SECTION  ·  APPOINTMENT OF COMMUNITY RESPONDER (SOLE)"),
                     [("nominee", "Appointee"), ("building", "Area of responsibility")],
                     (["The appointee is sole designated responder for all", "residents of the area of responsibility."],
                      ["Availability:  continuous.", "Remuneration:  £9.60 per hour of active response time.",
                       "Accommodation:  Office G/1 (charge applies).", "Commencement:  06:00, 26 September.", "",
                       "On commencement the Overnight Support Service", "will cease."]),
                     "Signature of appointee, accepting the terms of appointment")
    scene = Image.new("RGB", (1560, 1100), (44, 42, 48))
    a = np.asarray(scene, np.float32) + NP.normal(0, 3, (1100, 1560, 1))
    scene = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    drop(scene, p1.resize((700, 990), Image.LANCZOS), (40, 50), rot=1.2, shadow=0.7)
    drop(scene, p2.resize((700, 990), Image.LANCZOS), (800, 44), rot=-0.8, shadow=0.7)
    save(scene, "arp2_under")


# ------------------------------------------------------------------ R-1

def r1_form():
    W, H = 860, 1180
    img = paper(W, H, base=(234, 228, 206), age=0.5, edge_age=0.6)
    d = ImageDraw.Draw(img)
    d.text((50, 40), "R-1", font=OLD(64), fill=INK)
    d.text((170, 52), "REGISTRATION OF ARRIVAL", font=OLD(40), fill=INK)
    d.text((170, 102), "Arrivals Act 1952  ·  1971 printing", font=OLDI(24), fill=(80, 70, 60))
    d.line([(50, 146), (810, 146)], fill=INK, width=2)
    y = 180
    for lab in ["Name in full", "Date of arrival", "Place of arrival", "Witness", "Clerk"]:
        box(d, 50, y, 760, 80, lab, OLDI(22))
        y += 96
    d.rectangle([50, y + 10, 84, y + 44], outline=INK, width=3)
    d.text((100, y + 12), "Arrival deferred at the request of the person", font=OLD(26), fill=INK)
    d.text((50, 1120), "Form R-1. Keep flat. Return the top copy to the Registrar.", font=OLDI(20), fill=(90, 80, 70))
    return img


def r1_docs():
    seed("r1")
    form = r1_form()
    save(form, "r1_form")
    # Sal's photo: a form off the top of the box, and the note stapled to the box
    scene = cardboard(1200, 1500)
    sd = ImageDraw.Draw(scene)
    sd.text((70, 1300), "R-1 (1971)  x 500", font=SANSB(44), fill=(70, 50, 30))
    sd.text((70, 1360), "COMMUNITY SERVICES · STORES", font=SANS(30), fill=(90, 66, 40))
    note = paper(720, 190, base=(248, 246, 236), grain=2)
    nd = ImageDraw.Draw(note)
    nd.text((26, 22), "Arrivals Act 1952, s.4:", font=TYPE(28), fill=INK)
    nd.text((26, 70), "Registration of an arrival shall not be", font=TYPE(28), fill=INK)
    nd.text((26, 114), "conditional upon any offer of employment.", font=TYPE(28), fill=INK)
    drop(scene, form.resize((760, 1043), Image.LANCZOS), (60, 40), rot=2.0)
    drop(scene, note, (420, 1060), rot=-3.0, blur=5)
    sd = ImageDraw.Draw(scene)
    for sx in (470, 1030):
        sd.rectangle([sx, 1072, sx + 40, 1078], fill=(170, 170, 176))
    photo = photograph(scene, 1000, light=(0.15, -0.3), warmth=(0.98, 1.0, 1.02), vignette=0.45)
    save(photo, "r1_standalone")
    printout(photo, "r1_standalone")


# ------------------------------------------------------------------ Jad's letter

def jad_letter():
    seed("jad_letter")
    W, H = 880, 1244
    img = paper(W, H, base=(250, 250, 246), grain=2)
    d = ImageDraw.Draw(img)
    text = ["To every household at Ferrier Court,", "and to Community Services.", "",
            "I filled in the DPC-1 forms for nine households in", "August, at a table in the lobby. Where people had", "nobody who could promise to come, I wrote ARI, the", "name from the council's sample form, and gave a", "number that rang in the building.", "",
            "There was no Ari. The forms were my idea and my", "handwriting. The people who signed them did so", "because the council asked them to name somebody", "and they were frightened of losing help.", "",
            "The Overnight Support Service was closed on the", "grounds that every resident had a contact. That", "wasn't true, and it isn't their fault. I'd like the", "closure looked at again.", ""]
    y = 90
    for ln in text:
        d.text((80, y), ln, font=SANS(28), fill=INK)
        y += 42 if ln else 24
    write(img, (80, y + 20), "Jad Abdallah", "jad_sig", 64, BIRO_BLACK, slant=-0.2)
    d.text((80, y + 110), "Flat 4B", font=SANS(26), fill=INK)
    d.text((80, 1180), "Printed at Aldine Copy & Print, 04:12. 42 copies. Paid.", font=SANS(18), fill=GREY)
    save(img, "jad_letter")
    printout(img, "jad_letter")


# ------------------------------------------------------------------ Inez's terms

def rota_note():
    seed("rota_note")
    W, H = 760, 980
    img = paper(W, H, base=(244, 240, 222))
    d = ImageDraw.Draw(img)
    for y in range(120, H, 44):
        d.line([(0, y), (W, y)], fill=(170, 190, 220), width=1)
    d.line([(90, 0), (90, H)], fill=(220, 150, 150), width=2)
    lines = ["247: TERMS", "CALLS 8AM TO 11PM UNLESS", "SOMEBODY IS ACTUALLY IN TROUBLE.", "NOBODY HAS TO LEND EYES.", "ARI CAN SAY NO TOO.",
             "FRAME CHECKED MON & THU (I.C.)", "HOW: SEE GREEN BOOK, SHELF 2.", "NOBODY SITS WITH ARI.", "TENANT, NOT VIGIL.", "HOLD: WHATEVER ARI PICKED."]
    y = 64
    for i, ln in enumerate(lines):
        write_fit(img, (110, y), ln, "inez", 56 if i == 0 else 40, W - 140, fill=BIRO_BLACK, wobble=0.8)
        y += 62 if i == 0 else 44
    d.line([(110, y + 40), (700, y + 38)], fill=(40, 40, 40), width=2)
    write(img, (110, y + 52), "NAMES:", "inez", 36, BIRO_BLACK)
    tape(img, 130, 18, 150, 40, -4)
    tape(img, W - 130, 18, 150, 40, 5)
    save(img, "rota_note")
    printout(img, "rota_note")


# ------------------------------------------------------------------ the roster

def roster(name, limited):
    seed(name)
    W, H = 1100, 820
    img = paper(W, H, base=(246, 245, 240), grain=2.5)
    d = ImageDraw.Draw(img)
    d.text((40, 28), "COMMUNITY RESPONDER ROSTER", font=SANSB(32), fill=INK)
    d.text((40, 76), "Building:", font=SANS(20), fill=INK)
    d.text((40, 106), "Responder:", font=SANS(20), fill=INK)
    d.text((640, 76), "Week from:", font=SANS(20), fill=INK)
    write(img, (150, 62), "Ferrier Court", "sal", 38, BIRO)
    write(img, (160, 94), "ARI", "sal", 40, BIRO)
    write(img, (760, 62), "Sat 26 Sept", "sal", 38, BIRO)
    days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    times = ["06-10", "10-14", "14-18", "18-22", "22-02", "02-06"]
    gx, gy, cw, rh = 150, 150, 126, 64
    top, bot = gy + 44, gy + 44 + 6 * rh
    for i, t in enumerate(times):
        d.text((52, top + i * rh + 20), t, font=SANS(18), fill=INK)
    for j, dd in enumerate(days):
        d.text((gx + j * cw + 40, gy + 12), dd, font=SANSB(20), fill=INK)
    for i in range(len(times) + 2):
        yy = gy if i == 0 else top + (i - 1) * rh
        d.line([(40, yy), (gx + 7 * cw, yy)], fill=INK, width=2 if i < 2 else 1)
    for j in range(8):
        d.line([(gx + j * cw, gy), (gx + j * cw, bot)], fill=INK, width=1)
    d.line([(40, gy), (40, bot)], fill=INK, width=1)
    # CONTINUOUS down the left of every day, and an arrow on to the bottom
    for j in range(7):
        x = gx + j * cw
        m = Image.new("L", (230, 56), 0)
        ImageDraw.Draw(m).text((6, 2), "CONTINUOUS", font=hand_font("sal", 38), fill=255)
        m = m.rotate(-90, expand=True, resample=Image.BICUBIC)
        img.paste(Image.new("RGB", m.size, BIRO), (int(x + 2), top + 6), m)
        d.line([(x + 26, top + 222), (x + 26, bot - 12)], fill=BIRO, width=2)
        d.polygon([(x + 20, bot - 20), (x + 32, bot - 20), (x + 26, bot - 8)], fill=BIRO)
    if limited:
        # struck through, one stroke down each, initialled once
        for j in range(7):
            x = gx + j * cw
            d.line([(x + 24 + R.uniform(-2, 2), top + 2), (x + 30 + R.uniform(-2, 2), bot - 4)], fill=BIRO_BLACK, width=3)
        write(img, (gx + 7 * cw + 8, top + 2), "S.B.", "sal", 34, BIRO_BLACK)
        for j in range(4):
            for i in (4, 5):
                write(img, (gx + j * cw + 52, top + i * rh + 12), "ARI", "sal", 36, BIRO_BLACK)
        for j in (4, 5):
            for i in (4, 5):
                write(img, (gx + j * cw + 44, top + i * rh + 14), "T.V.", "teodor", 30, (70, 44, 30))
        write(img, (gx + 6 * cw + 40, top + 4 * rh + 14), "T.V.?", "teodor", 30, (70, 44, 30))
        write(img, (gx + 1 * cw + 46, top + 3 * rh + 12), "N.A.", "nell", 36, (50, 60, 160))
        y = bot + 18
        write(img, (40, y), "ARI: NIGHTS 22:00 - 06:00, MON - THU.   S.B.", "sal", 36, BIRO_BLACK)
        write(img, (40, y + 44), "N. AMADI - Tuesdays", "nell", 40, (50, 60, 160))
        write(img, (420, y + 48), "T. Vass - nights (most)", "teodor", 32, (70, 44, 30))
        write(img, (40, y + 92), "I. CARVALHO - THE FRAME", "inez", 30, BIRO_BLACK)
        write_fit(img, (40, y + 134), "DAYS ARE NOBODY'S. THAT'S THE POINT.", "nell", 48, W - 90, fill=FELT_RED, wobble=2)
    save(img, name)


# ------------------------------------------------------------------ small paper

def timetable():
    seed("timetable")
    W, H = 440, 640
    img = paper(W, H, base=(250, 250, 246), grain=2)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 92], fill=(150, 30, 40))
    d.text((20, 12), "36", font=SANSB(56), fill=(255, 255, 255))
    d.text((110, 18), "N36", font=SANSB(30), fill=(255, 220, 220))
    d.text((110, 54), "Ferrier Street (Baths)", font=SANS(22), fill=(255, 255, 255))
    d.text((20, 104), "towards Fenwick Road, St Anne's, City", font=SANS(18), fill=INK)
    d.text((20, 140), "Mon - Fri", font=SANSB(20), fill=INK)
    d.text((230, 140), "Saturday", font=SANSB(20), fill=INK)
    wk = ["04:40", "05:10", "05:35", "05:58", "06:20", "06:42", "07:04", "07:26", "07:48"]
    sat = ["04:52", "05:22", "05:47", "06:12", "06:50", "07:20", "07:55", "08:25", "08:55"]
    for i, (a, b) in enumerate(zip(wk, sat)):
        d.text((24, 176 + i * 46), a, font=SANS(28), fill=INK)
        d.text((234, 176 + i * 46), b, font=SANS(28), fill=INK)
    d.text((20, H - 40), "Times are approximate.", font=SANS(16), fill=GREY)
    y = 176 + 3 * 46
    d.ellipse([214, y - 10, 336, y + 42], outline=BIRO, width=3)
    d.ellipse([208, y - 16, 344, y + 46], outline=BIRO, width=2)
    save(img, "timetable")


def letter_crest():
    seed("letter_crest")
    W, H = 820, 1160
    img = paper(W, H, base=(250, 250, 246), grain=2)
    d = ImageDraw.Draw(img)
    navy = (34, 62, 104)
    d.ellipse([60, 50, 170, 160], outline=navy, width=6)
    d.text((88, 78), "CS", font=SANSB(40), fill=navy)
    d.text((200, 70), "Community Services", font=SANSB(36), fill=navy)
    d.text((200, 118), "Housing Support  ·  Plan Status", font=SANS(26), fill=INK)
    d.multiline_text((60, 200), "Ms N. Amadi\nFlat 3B, Ferrier Court", font=SANS(22), fill=INK, spacing=6)
    d.multiline_text((560, 200), "14 September\nRef. HS/FC/3B", font=SANS(22), fill=INK, spacing=6)
    y = 300
    for ln in ["Dear Ms Amadi,", "", "Your support plan is currently marked", "INCOMPLETE.", "",
               "Please ensure your Designated Personal Contact", "has countersigned form DPC-1 by 06:00 on", "Saturday 26 September.", "",
               "If your plan is incomplete on that date, the support", "set out in it may be reviewed.", "", "Yours sincerely,", "", "Transition Team"]:
        d.text((60, y), ln, font=SANSB(30) if ln == "INCOMPLETE." else SANS(28), fill=INK)
        y += 42 if ln else 22
    d.line([(60, H - 80), (W - 60, H - 80)], fill=navy, width=1)
    d.text((60, H - 66), "This letter was produced automatically.", font=SANS(17), fill=GREY)
    save(img, "letter_crest")


# ------------------------------------------------------------------

MINE = ["slip", "notice_lobby", "tobi_drawing", "nell_form", "dpc_form", "dpc_stack", "dpc_blank", "dpc_nell",
        "leaflet_arrivals", "register_page", "poster_received", "arp2_top", "arp2_under", "r1_form", "r1_standalone",
        "jad_letter", "rota_note", "roster_limited", "roster_continuous", "timetable", "letter_crest"]


def main():
    for n in MINE:
        for ext in (".png", "_print.png", ".jpg", ".png.import", ".jpg.import", "_print.png.import"):
            p = os.path.join(OUT, n + ext)
            if os.path.exists(p):
                os.remove(p)
    slip()
    notice_lobby()
    tobi_drawing()
    dpc_forms()
    leaflet()
    register_page()
    poster()
    arp2_top()
    arp2_under()
    r1_docs()
    jad_letter()
    rota_note()
    roster("roster_limited", True)
    roster("roster_continuous", False)
    timetable()
    letter_crest()
    print("docs:", sorted(f for f in os.listdir(OUT) if f.endswith((".png", ".jpg"))))


if __name__ == "__main__":
    main()
