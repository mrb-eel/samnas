"""Generates the low-resolution texture library for the 3D sets.

    python3 tools/art/gen_textures.py

Everything is small on purpose: rooms render at a fraction of screen
resolution with nearest filtering, so a 64px texture is already generous.
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tex")
FONTS = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts")
os.makedirs(OUT, exist_ok=True)
R = random.Random(247)
NP = np.random.default_rng(247)

IVORY = (232, 224, 204)
INK = (20, 18, 23)
GREEN = (79, 122, 99)
GREEN_DK = (35, 57, 47)
BLUE = (29, 46, 90)
TILE = (60, 127, 176)
MAUVE = (156, 132, 148)
PINK = (184, 122, 138)
RED = (216, 52, 44)


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))


def noise(w, h, amp, scale=1):
    n = NP.normal(0, amp, (h // scale + 1, w // scale + 1))
    n = np.kron(n, np.ones((scale, scale)))[:h, :w]
    return n


def tint(base, w, h, amp=10, scale=1):
    a = np.zeros((h, w, 3), np.float32)
    a[:] = base
    n = noise(w, h, amp, scale)
    a += n[..., None]
    return a


def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def grime(a, amount=0.25, dark=40):
    h, w = a.shape[:2]
    blob = noise(w, h, 1.0, 8)
    blob = Image.fromarray(((blob - blob.min()) / (np.ptp(blob) + 1e-6) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
    b = np.asarray(blob, np.float32) / 255.0
    a -= (b[..., None] ** 3) * dark * amount * 4
    return a


def tiles(name, base, grout, n, size=64, var=12, dirt=0.3):
    s = size // n
    a = np.zeros((size, size, 3), np.float32)
    for ty in range(n):
        for tx in range(n):
            c = np.array(base, np.float32) + R.uniform(-var, var)
            a[ty * s:(ty + 1) * s, tx * s:(tx + 1) * s] = c
    a += noise(size, size, 4)[..., None]
    for i in range(0, size, s):
        a[i, :] = grout
        a[:, i] = grout
    a = grime(a, dirt)
    save(to_img(a), name)


def checker(name, c1, c2, n=4, size=64):
    s = size // n
    a = np.zeros((size, size, 3), np.float32)
    for y in range(n):
        for x in range(n):
            a[y * s:(y + 1) * s, x * s:(x + 1) * s] = c1 if (x + y) % 2 == 0 else c2
    a += noise(size, size, 6)[..., None]
    a = grime(a, 0.35)
    save(to_img(a), name)


def wood(name, base, w=64, h=128, boards=4):
    a = tint(base, w, h, 5)
    bw = w // boards
    for b in range(boards):
        shade = R.uniform(-14, 14)
        a[:, b * bw:(b + 1) * bw] += shade
        for i in range(10):
            x = b * bw + R.randint(1, bw - 2)
            a[:, x] -= R.uniform(6, 16)
        a[:, b * bw] = np.array(base) * 0.45
    a = grime(a, 0.2)
    save(to_img(a), name)


def wallpaper(name, base, motif, size=64):
    a = tint(base, size, size, 4)
    img = to_img(a)
    d = ImageDraw.Draw(img)
    for cy in range(0, size, 16):
        for cx in range(0, size, 16):
            ox = 8 if (cy // 16) % 2 else 0
            x, y = cx + ox, cy + 8
            d.polygon([(x, y - 5), (x + 4, y), (x, y + 5), (x - 4, y)], outline=motif)
            d.point((x, y), fill=motif)
    a = np.asarray(img, np.float32)
    a = grime(a, 0.3)
    save(to_img(a), name)


def paint(name, base, size=64, stains=True):
    a = tint(base, size, size, 5, 2)
    if stains:
        a = grime(a, 0.4)
    save(to_img(a), name)


def brick(name, size=64):
    a = np.zeros((size, size, 3), np.float32)
    a[:] = (70, 60, 58)
    bh, bw = 8, 16
    for row in range(size // bh):
        off = (bw // 2) if row % 2 else 0
        for col in range(-1, size // bw + 1):
            x0 = col * bw + off
            c = np.array((96, 50, 42), np.float32) + R.uniform(-14, 14)
            x1, x2 = max(0, x0 + 1), min(size, x0 + bw)
            if x2 > x1:
                a[row * bh + 1:(row + 1) * bh, x1:x2] = c
    a += noise(size, size, 5)[..., None]
    a = grime(a, 0.4)
    save(to_img(a), name)


def speckle(name, base, flecks, size=64, density=0.08):
    a = tint(base, size, size, 4)
    m = NP.random((size, size)) < density
    for i, c in enumerate(flecks):
        mm = m & (NP.random((size, size)) < 1.0 / (i + 1))
        a[mm] = c
    a = grime(a, 0.25)
    save(to_img(a), name)


def circuit(name, board, trace, size=128, chips=7):
    img = to_img(tint(board, size, size, 6))
    d = ImageDraw.Draw(img)
    for i in range(70):
        x, y = R.randrange(size), R.randrange(size)
        for j in range(R.randint(2, 5)):
            if R.random() < 0.5:
                nx, ny = x + R.choice([-1, 1]) * R.randint(4, 30), y
            else:
                nx, ny = x, y + R.choice([-1, 1]) * R.randint(4, 30)
            d.line([(x, y), (nx, ny)], fill=trace, width=1)
            x, y = nx, ny
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=(200, 180, 110))
    for c in range(chips):
        w, h = R.randint(10, 26), R.randint(8, 18)
        x, y = R.randrange(2, size - w - 2), R.randrange(2, size - h - 2)
        d.rectangle([x, y, x + w, y + h], fill=(24, 24, 26))
        for px in range(x + 2, x + w - 1, 3):
            d.line([(px, y - 2), (px, y)], fill=(190, 190, 180))
            d.line([(px, y + h), (px, y + h + 2)], fill=(190, 190, 180))
        d.line([(x + 2, y + 2), (x + w // 2, y + 2)], fill=(90, 90, 90))
    for i in range(10):
        x, y = R.randrange(size - 8), R.randrange(size - 4)
        d.rectangle([x, y, x + R.randint(4, 12), y + 1], fill=(220, 220, 210))
    for i in range(6):
        x, y = R.randrange(size - 6), R.randrange(size - 10)
        d.rectangle([x, y, x + 4, y + 9], fill=(40, 60, 150))
        d.rectangle([x, y + 2, x + 4, y + 3], fill=(180, 60, 50))
    a = grime(np.asarray(img, np.float32), 0.2)
    save(to_img(a), name)


def relays(name, size=128):
    img = to_img(tint((42, 40, 44), size, size, 4))
    d = ImageDraw.Draw(img)
    for row in range(8):
        y = 4 + row * 16
        d.rectangle([0, y + 12, size, y + 14], fill=(90, 86, 70))
        for col in range(10):
            x = 3 + col * 12 + (row % 2) * 2
            base = (58, 56, 60) if R.random() > 0.15 else (70, 30, 28)
            d.rectangle([x, y, x + 9, y + 11], fill=base, outline=(22, 22, 24))
            d.rectangle([x + 2, y + 2, x + 7, y + 4], fill=(160, 130, 70))
            d.line([(x + 1, y + 8), (x + 8, y + 8)], fill=(120, 118, 110))
    a = grime(np.asarray(img, np.float32), 0.3)
    save(to_img(a), name)


def wires(name, size=128):
    img = to_img(tint((22, 22, 26), size, size, 3))
    d = ImageDraw.Draw(img)
    cols = [(180, 40, 40), (210, 180, 60), (40, 70, 160), (220, 220, 210), (60, 140, 80), (150, 90, 150), (200, 120, 50), (20, 20, 20)]
    for i in range(60):
        c = R.choice(cols)
        x0, y0 = R.randrange(size), 0
        pts = [(x0, y0)]
        x, y = x0, y0
        while y < size:
            x += R.randint(-6, 6)
            y += R.randint(4, 10)
            pts.append((x, y))
        d.line(pts, fill=c, width=R.choice([1, 1, 2]))
    for i in range(8):
        y = R.randrange(size)
        d.line([(0, y), (size, y + R.randint(-10, 10))], fill=R.choice(cols), width=2)
    a = grime(np.asarray(img, np.float32), 0.2)
    save(to_img(a), name)


def metal(name, base=(128, 126, 120), size=64):
    a = tint(base, size, size, 2)
    for y in range(size):
        a[y, :] += R.uniform(-6, 6)
    img = to_img(a)
    d = ImageDraw.Draw(img)
    for i in range(14):
        x, y = R.randrange(size), R.randrange(size)
        d.line([(x, y), (x + R.randint(-16, 16), y + R.randint(-4, 4))], fill=(170, 168, 160))
    a = grime(np.asarray(img, np.float32), 0.3)
    save(to_img(a), name)


def cork(name, size=64):
    a = tint((150, 110, 70), size, size, 18)
    save(to_img(grime(a, 0.2)), name)


def facade(name, size=256, floors=6, cols=7, lit=None, seed=3):
    rr = random.Random(seed)
    a = tint((92, 90, 92), size, size, 6, 2)
    img = to_img(grime(a, 0.35))
    d = ImageDraw.Draw(img)
    fh = size // floors
    cw = size // cols
    for f in range(floors):
        d.line([(0, f * fh), (size, f * fh)], fill=(70, 68, 70), width=2)
        for c in range(cols):
            x0, y0 = c * cw + 6, f * fh + 8
            x1, y1 = x0 + cw - 12, y0 + fh - 16
            on = (lit is None and rr.random() < 0.28) or (lit is not None and (f, c) in lit)
            fill = (236, 196, 120) if on else (26, 30, 40)
            if on and rr.random() < 0.4:
                fill = (220, 170, 150)
            d.rectangle([x0, y0, x1, y1], fill=fill, outline=(50, 50, 54))
            d.line([((x0 + x1) // 2, y0), ((x0 + x1) // 2, y1)], fill=(50, 50, 54))
            if on and rr.random() < 0.5:
                d.rectangle([x0 + 1, y0 + 1, x0 + (x1 - x0) // 3, y1 - 1], fill=(170, 120, 130))
    save(img, name)


def crochet(name, size=64):
    img = Image.new("RGB", (size, size), PINK)
    d = ImageDraw.Draw(img)
    s = 16
    cols = [(210, 140, 160), (110, 160, 120), (232, 220, 200), (190, 100, 120)]
    for y in range(0, size, s):
        for x in range(0, size, s):
            for k in range(4):
                c = cols[(k + (x // s) + (y // s)) % len(cols)]
                d.rectangle([x + k * 2, y + k * 2, x + s - 1 - k * 2, y + s - 1 - k * 2], outline=c, width=2)
            d.rectangle([x, y, x + s - 1, y + s - 1], outline=(60, 50, 55))
    a = np.asarray(img, np.float32) + noise(size, size, 6)[..., None]
    save(to_img(a), name)


def corduroy(name, base=(118, 82, 52), size=32):
    a = tint(base, size, size, 3)
    for x in range(0, size, 3):
        a[:, x] -= 26
        a[:, x + 1] += 8 if x + 1 < size else 0
    save(to_img(grime(a, 0.2)), name)


def plastic_bag(name, size=64):
    a = tint((70, 110, 190), size, size, 6, 2)
    for i in range(12):
        x = R.randrange(size)
        a[:, max(0, x - 1):x + 1] += R.uniform(-30, 40)
    save(to_img(a), name)


def skin(name, base=(176, 128, 98), size=32):
    save(to_img(tint(base, size, size, 4, 2)), name)


def text_texture(name, w, h, bg, fg, lines, font="SpecialElite.ttf", size=10, border=None):
    img = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(os.path.join(FONTS, font), size)
    y = 4
    for ln in lines:
        tw = d.textlength(ln, font=f)
        d.text(((w - tw) / 2, y), ln, fill=fg, font=f)
        y += size + 2
    if border:
        d.rectangle([0, 0, w - 1, h - 1], outline=border)
    save(img, name)


def door_panel(name):
    w, h = 64, 128
    img = to_img(tint((140, 140, 136), w, h, 4))
    d = ImageDraw.Draw(img)
    for i in range(0, 20, 3):
        d.line([(20, 8 + i), (44, 8 + i)], fill=(40, 40, 40))
    for r in range(7):
        for c in range(6):
            x, y = 6 + c * 9, 34 + r * 12
            d.rectangle([x, y, x + 6, y + 8], fill=(60, 60, 62))
            if R.random() < 0.35:
                d.rectangle([x, y + 1, x + 6, y + 3], fill=(230, 220, 190))
    d.rectangle([20, 118, 44, 124], fill=(30, 30, 30))
    save(img, name)


def vending(name):
    w, h = 64, 128
    img = to_img(tint((150, 40, 40), w, h, 4))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 8, 44, 96], fill=(30, 34, 40))
    cols = [(220, 190, 60), (60, 120, 200), (200, 80, 60), (90, 160, 90), (230, 230, 220)]
    for r in range(5):
        for c in range(4):
            d.rectangle([7 + c * 9, 12 + r * 16, 13 + c * 9, 22 + r * 16], fill=R.choice(cols))
        d.line([(6, 24 + r * 16), (42, 24 + r * 16)], fill=(120, 120, 120))
    d.rectangle([48, 20, 60, 50], fill=(30, 30, 30))
    d.rectangle([8, 104, 40, 118], fill=(20, 20, 20))
    d.rectangle([47, 60, 61, 70], fill=(232, 224, 204))
    save(img, name)


def copier(name):
    w, h = 64, 64
    img = to_img(tint((196, 194, 186), w, h, 3))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 60, 18], fill=(170, 168, 160), outline=(90, 90, 90))
    d.rectangle([40, 7, 56, 15], fill=(60, 140, 90))
    for i in range(3):
        d.rectangle([6, 26 + i * 12, 58, 34 + i * 12], outline=(120, 120, 116))
        d.line([(28, 30 + i * 12), (36, 30 + i * 12)], fill=(80, 80, 80))
    save(img, name)


def cross(name):
    img = Image.new("RGB", (32, 32), (10, 30, 14))
    d = ImageDraw.Draw(img)
    d.rectangle([12, 4, 20, 28], fill=(80, 255, 120))
    d.rectangle([4, 12, 28, 20], fill=(80, 255, 120))
    save(img, name)


def wired_glass(name):
    img = Image.new("RGBA", (32, 32), (120, 150, 160, 90))
    d = ImageDraw.Draw(img)
    for i in range(-32, 64, 8):
        d.line([(i, 0), (i + 32, 32)], fill=(40, 40, 40, 200))
        d.line([(i + 32, 0), (i, 32)], fill=(40, 40, 40, 200))
    img.save(os.path.join(OUT, name + ".png"))


def keytag(name):
    img = Image.new("RGB", (32, 20), (170, 140, 100))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(os.path.join(FONTS, "ReenieBeanie.ttf"), 18)
    d.text((5, -2), "247", fill=(20, 20, 20), font=f)
    d.ellipse([26, 7, 30, 11], fill=(90, 70, 50))
    save(img, name)


def token(name):
    img = Image.new("RGB", (32, 32), (150, 118, 50))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 30, 30], fill=(184, 150, 72), outline=(110, 84, 30))
    d.ellipse([6, 6, 25, 25], outline=(130, 100, 40))
    f = ImageFont.truetype(os.path.join(FONTS, "SpecialElite.ttf"), 11)
    d.text((9, 9), "47", fill=(90, 66, 20), font=f)
    save(img, name)


def label_tape(name, text="ARI"):
    img = Image.new("RGB", (48, 12), (22, 22, 22))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(os.path.join(FONTS, "Atkinson-Bold.ttf"), 10)
    d.text((14, 0), text, fill=(240, 240, 235), font=f)
    save(img, name)


def tram_postcard(name):
    img = to_img(tint((200, 180, 140), 32, 22, 6))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 8, 28, 16], fill=(170, 50, 40))
    d.line([(2, 18), (30, 18)], fill=(40, 40, 40))
    d.line([(16, 2), (16, 8)], fill=(40, 40, 40))
    save(img, name)


def lamp_glass(name):
    img = Image.new("RGB", (32, 32), (20, 30, 40))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 29, 29], fill=(200, 240, 255), outline=(120, 120, 110))
    d.ellipse([8, 8, 23, 23], fill=(255, 255, 250))
    save(img, name)


def bread(name):
    a = tint((170, 110, 55), 32, 32, 12, 2)
    save(to_img(a), name)


def pleat(name):
    a = tint((226, 200, 150), 32, 32, 3)
    for x in range(0, 32, 4):
        a[:, x] -= 30
    save(to_img(a), name)


def leaves(name, size=64):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(30):
        x, y = R.randrange(size), R.randrange(size)
        c = R.choice([(120, 80, 40, 255), (150, 110, 50, 255), (90, 60, 30, 255), (210, 200, 180, 255)])
        d.ellipse([x, y, x + R.randint(2, 5), y + R.randint(1, 3)], fill=c)
    img.save(os.path.join(OUT, name + ".png"))


def main():
    tiles("pool_tile", TILE, (150, 172, 184), 8, var=10, dirt=0.45)
    tiles("pool_tile_deep", (46, 96, 150), (120, 150, 170), 8, var=10, dirt=0.55)
    tiles("white_tile", (226, 228, 220), (170, 172, 168), 8, var=6, dirt=0.35)
    tiles("lobby_floor", (118, 72, 50), (70, 50, 40), 2, var=14, dirt=0.5)
    tiles("ceiling_tile", (200, 196, 180), (150, 146, 136), 2, var=5, dirt=0.4)
    checker("checker", (26, 24, 28), (214, 206, 188))
    wood("wood_panel", (110, 84, 86))
    wood("wood_light", (160, 120, 80), boards=3)
    wallpaper("wallpaper_mauve", (140, 116, 130), (170, 146, 158))
    wallpaper("wallpaper_green", (96, 118, 100), (120, 142, 124))
    paint("paint_ivory", (206, 198, 176))
    paint("paint_green", (74, 112, 90))
    paint("paint_cream", (214, 204, 170))
    paint("paint_blue", (70, 86, 120))
    paint("concrete", (112, 110, 108))
    paint("asphalt", (40, 40, 44))
    brick("brick")
    speckle("lino", (110, 118, 104), [(160, 160, 150), (60, 64, 58)])
    speckle("carpet", (110, 80, 96), [(140, 100, 120), (70, 50, 60)], density=0.2)
    speckle("fleece_mauve", (130, 110, 140), [(150, 130, 160)], density=0.2)
    circuit("circuit_green", (40, 110, 60), (110, 190, 110))
    circuit("circuit_blue", (30, 70, 140), (110, 160, 220))
    circuit("circuit_purple", (140, 40, 150), (220, 130, 230), chips=5)
    relays("relays")
    wires("wires")
    metal("metal")
    metal("metal_dark", (80, 80, 84))
    cork("cork")
    facade("facade")
    facade("facade_opposite", lit={(3, 3), (1, 5), (4, 1)}, seed=9)
    crochet("crochet")
    corduroy("corduroy")
    corduroy("coat_navy", (40, 48, 80))
    plastic_bag("bag_blue")
    skin("skin_jad", (170, 120, 90))
    skin("skin_pale", (214, 180, 160))
    skin("skin_dark", (110, 74, 56))
    door_panel("door_panel")
    vending("vending")
    copier("copier")
    cross("chemist_cross")
    wired_glass("wired_glass")
    keytag("keytag")
    token("token")
    label_tape("label_ari")
    tram_postcard("tram_postcard")
    lamp_glass("lamp_glass")
    bread("bread")
    pleat("shade_pleat")
    leaves("leaves")
    text_texture("sign_desk", 48, 16, (240, 236, 220), (30, 30, 30), ["BACK IN 10 MINS. S."], size=7)
    text_texture("sign_receiving", 64, 16, (220, 220, 210), (40, 60, 120), ["RECEIVING"], font="Atkinson-Bold.ttf", size=11)
    text_texture("sign_exact", 32, 16, (240, 236, 220), (30, 30, 30), ["EXACT MONEY", "AND EVEN THEN"], size=5)
    text_texture("sign_bakery", 64, 16, (40, 40, 40), (240, 200, 90), ["FENWICK RD BAKERY"], font="Atkinson-Bold.ttf", size=8)
    text_texture("sign_copy", 64, 16, (200, 40, 40), (250, 250, 240), ["ALDINE COPY & PRINT"], font="Atkinson-Bold.ttf", size=7)
    text_texture("sign_247", 20, 10, (230, 230, 220), (20, 20, 20), ["247"], font="Atkinson-Bold.ttf", size=8)
    text_texture("sign_hold", 32, 12, (30, 30, 30), (240, 180, 70), ["HOLD"], font="Atkinson-Bold.ttf", size=9)
    print("textures:", len(os.listdir(OUT)))


if __name__ == "__main__":
    main()
