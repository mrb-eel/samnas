"""Painted faces for the figures (see scripts/sets/figure.gd).

    python3 tools/art/gen_faces.py

A face texture wraps the front of the sculpted head: u runs across the face
(0.5 is the middle of the nose), v runs from crown (0) to chin (1). Named
people get their own face, skin already in it, in several expressions.
Generic faces for everybody else are drawn in greys on white and multiplied
by the figure's skin colour.
"""
import os, math, random, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "tex"))
S = 256
SS = 4                      # drawn at 4x and reduced, for clean edges

# where things are, in texture pixels (see figure.gd _head_uv / _sculpt)
EYE_Y, EYE_DX = 120, 47
BROW_Y = 104
NOSE_Y = 166
MOUTH_Y = 192
CHIN_Y = 236


def c(v):
    return tuple(int(max(0, min(255, x))) for x in v)


def mix(a, b, t):
    return c([a[i] * (1 - t) + b[i] * t for i in range(3)])


class Face:
    def __init__(self, name, skin, hair, eyes=(70, 48, 30), brow=1.0, brow_col=None, lips=None, age=0.0,
                 stubble=0.0, freckles=0.0, eye_w=1.0, eye_h=1.0, mouth_w=1.0, lip_full=1.0, blush=0.25,
                 lids=0.0, modulate=False, seed=None, lashes=0.0, mole=None, hairline=None):
        self.__dict__.update(locals())
        del self.__dict__["self"]
        self.brow_col = brow_col or mix(hair, (20, 16, 14), 0.35)
        self.lips = lips or mix(skin, (150, 60, 70), 0.35)
        self.R = random.Random(seed if seed is not None else zlib.crc32(name.encode()))

    # ------------------------------------------------------------------
    def draw(self, expr="neutral"):
        W = S * SS
        base = (255, 255, 255) if self.modulate else self.skin
        img = Image.new("RGB", (W, W), base)
        d = ImageDraw.Draw(img, "RGBA")
        k = SS

        def P(x, y):
            return (x * k, y * k)

        def ell(cx, cy, rx, ry, fill):
            d.ellipse([(cx - rx) * k, (cy - ry) * k, (cx + rx) * k, (cy + ry) * k], fill=fill)

        def line(pts, fill, w):
            d.line([P(x, y) for x, y in pts], fill=fill, width=max(1, int(w * k)), joint="curve")

        dark = (0, 0, 0)
        sk = self.skin if not self.modulate else (255, 255, 255)
        if not self.modulate and self.hairline is not None:
            hm = Image.new("L", (W, W), 0)
            hd = ImageDraw.Draw(hm)
            top = self.hairline
            pts = [(0, 0), (W, 0), (W, (top + 40) * k)]
            for i in range(21):
                x = 256 - i * 12.8
                y = top + 34 * abs((x - 128) / 128) ** 1.6 + self.R.uniform(-2.5, 2.5)
                pts.append((x * k, y * k))
            pts.append((0, (top + 40) * k))
            hd.polygon(pts, fill=255)
            hm = hm.filter(ImageFilter.GaussianBlur(2.2 * k))
            img.paste(Image.new("RGB", (W, W), self.hair), (0, 0), hm)
            d = ImageDraw.Draw(img, "RGBA")
        shade = lambda a: (*mix(sk, (60, 30, 30) if not self.modulate else (120, 120, 120), 1.0)[:3], a)
        # soft modelling: under the brow, the sides of the nose, under the lip, the jaw
        for (cx, cy, rx, ry, a) in [(128 - EYE_DX, EYE_Y + 1, 27, 14, 40), (128 + EYE_DX, EYE_Y + 1, 27, 14, 40),
                                    (114, NOSE_Y - 16, 6, 26, 30), (142, NOSE_Y - 16, 6, 26, 30),
                                    (128, MOUTH_Y + 17, 20, 7, 30), (128, CHIN_Y + 20, 80, 16, 40)]:
            ell(cx, cy, rx, ry, shade(a))
        if not self.modulate and self.blush > 0:
            for s in (-1, 1):
                ell(128 + s * 56, 156, 22, 14, (*mix(self.skin, (210, 90, 90), 0.5), int(60 * self.blush)))
        # age: the forehead, the corners of the eyes, the folds from nose to mouth
        if self.age > 0:
            a = int(90 * self.age)
            for i in range(3):
                y = 78 + i * 8
                line([(94, y + 1), (128, y - 1), (162, y + 1)], shade(a), 1.1)
            for s in (-1, 1):
                ex = 128 + s * (EYE_DX + 24)
                for j in (-1, 0, 1):
                    line([(ex, EYE_Y + j * 3), (ex + s * 7, EYE_Y + j * 5)], shade(a), 0.9)
                line([(128 + s * 20, NOSE_Y - 4), (128 + s * 32, MOUTH_Y + 2), (128 + s * 30, MOUTH_Y + 16)], shade(int(a * 1.2)), 1.4)
            for s in (-1, 1):
                line([(128 + s * (EYE_DX - 14), EYE_Y + 12), (128 + s * (EYE_DX + 12), EYE_Y + 13)], shade(a), 1.0)
        # freckles
        for _ in range(int(60 * self.freckles)):
            x = 128 + self.R.uniform(-66, 66)
            y = 146 + self.R.uniform(-14, 14)
            ell(x, y, 1.1, 1.1, (*mix(sk, (120, 70, 40), 0.6), 150))
        if self.mole:
            ell(self.mole[0], self.mole[1], 1.6, 1.6, (70, 40, 30, 200))
        # stubble
        if self.stubble > 0:
            st = Image.new("L", (W, W), 0)
            sd = ImageDraw.Draw(st)
            sd.ellipse([(128 - 58) * k, (NOSE_Y + 6) * k, (128 + 58) * k, (CHIN_Y + 30) * k], fill=255)
            sd.ellipse([(128 - 22) * k, (MOUTH_Y - 6) * k, (128 + 22) * k, (MOUTH_Y + 8) * k], fill=0)
            st = st.filter(ImageFilter.GaussianBlur(10 * k))
            n = (np.random.default_rng(3).random((W, W)) > 0.55).astype(np.float32)
            m = np.asarray(st, np.float32) / 255.0 * n * self.stubble * 0.5
            layer = Image.new("RGB", (W, W), mix(sk, (30, 24, 22), 0.75))
            img.paste(layer, (0, 0), Image.fromarray((m * 255).astype(np.uint8)))
            d = ImageDraw.Draw(img, "RGBA")
        # nose: nostrils and a little shadow under the tip
        for s in (-1, 1):
            ell(128 + s * 9, NOSE_Y + 1, 4.2, 2.6, shade(130))
            line([(128 + s * 14, NOSE_Y - 6), (128 + s * 16, NOSE_Y), (128 + s * 12, NOSE_Y + 4)], shade(70), 1.4)
        line([(119, NOSE_Y + 5), (128, NOSE_Y + 8), (137, NOSE_Y + 5)], shade(60), 1.4)
        # eyes
        closed = expr == "closed"
        smile = expr in ("smile", "open")
        worried = expr == "worried"
        ew, eh = 17 * self.eye_w, 6.2 * self.eye_h
        for s in (-1, 1):
            ex, ey = 128 + s * EYE_DX, EYE_Y
            if closed:
                line([(ex - ew, ey + 1), (ex, ey + 3), (ex + ew, ey + 1)], (*mix(sk, dark, 0.7), 230), 1.6)
                continue
            lift = 1.2 if smile else 0.0
            white = (238, 232, 224) if not self.modulate else (250, 250, 250)
            d.polygon([P(ex - ew, ey), P(ex - ew * 0.3, ey - eh), P(ex + ew * 0.5, ey - eh * 0.9), P(ex + ew, ey - lift * 0.3),
                       P(ex + ew * 0.4, ey + eh * (0.7 - 0.25 * lift)), P(ex - ew * 0.4, ey + eh * (0.75 - 0.25 * lift))], fill=white)
            iris = self.eyes if not self.modulate else (70, 70, 70)
            ell(ex + s * 0.6, ey - 0.4, 6.0 * self.eye_h, 6.0 * self.eye_h, (*iris, 255))
            ell(ex + s * 0.6, ey - 0.4, 2.8, 2.8, (18, 14, 14, 255))
            ell(ex + s * 0.6 + 2.0, ey - 2.4, 1.4, 1.4, (255, 255, 255, 210))
            # the upper lid, heavy; the lower, faint
            lid = (*mix(sk, dark, 0.78), 255)
            line([(ex - ew - 1, ey + 0.5), (ex - ew * 0.3, ey - eh - 0.4), (ex + ew * 0.5, ey - eh * 0.9 - 0.4), (ex + ew + 1, ey - lift * 0.3)], lid, 2.0 + self.lashes)
            if self.lids > 0:
                line([(ex - ew * 0.9, ey - eh - 2.6), (ex + ew * 0.2, ey - eh - 3.4), (ex + ew, ey - eh * 0.5 - 1.5)], shade(int(110 * self.lids)), 1.2)
            line([(ex - ew * 0.6, ey + eh * 0.85), (ex + ew * 0.6, ey + eh * 0.85)], shade(70), 1.0)
        # brows
        bc = (*self.brow_col, 255) if not self.modulate else (90, 90, 90, 255)
        for s in (-1, 1):
            ex = 128 + s * EYE_DX
            inner, outer = ex - s * 18, ex + s * 20
            yi = BROW_Y + (-5 if worried else 1 if expr == "cross" else 0)
            yo = BROW_Y - 2 + (2 if worried else 0)
            line([(inner, yi), (ex, BROW_Y - 4), (outer, yo)], bc, 2.4 * self.brow)
        # mouth
        mw = 25 * self.mouth_w
        lip = (*self.lips, 255) if not self.modulate else (190, 170, 170, 255)
        seam = (*mix(self.lips, dark, 0.55), 255) if not self.modulate else (110, 90, 90, 255)
        my = MOUTH_Y
        if expr == "open":
            d.polygon([P(128 - mw, my - 1), P(128, my - 4), P(128 + mw, my - 1), P(128 + mw * 0.6, my + 9), P(128, my + 12), P(128 - mw * 0.6, my + 9)], fill=seam)
            d.polygon([P(128 - mw * 0.7, my), P(128 + mw * 0.7, my), P(128 + mw * 0.5, my + 3), P(128 - mw * 0.5, my + 3)], fill=(236, 230, 220, 255))
        else:
            curve = -4 if smile else (2.5 if worried else 0.6)
            ul = 4.4 * self.lip_full
            ll = 5.6 * self.lip_full
            d.polygon([P(128 - mw, my + curve * 0.3), P(128 - mw * 0.4, my - ul), P(128, my - ul * 0.6), P(128 + mw * 0.4, my - ul),
                       P(128 + mw, my + curve * 0.3), P(128 + mw * 0.5, my + ll), P(128 - mw * 0.5, my + ll)], fill=lip)
            line([(128 - mw, my + curve * 0.3), (128 - mw * 0.5, my + curve * 0.1 + 0.5), (128, my + 0.8), (128 + mw * 0.5, my + curve * 0.1 + 0.5), (128 + mw, my + curve * 0.3)], seam, 1.3)
            if smile:
                for s in (-1, 1):
                    line([(128 + s * (mw + 1), my - 2), (128 + s * (mw + 4), my + 1)], shade(90), 1.0)
        img = img.resize((S, S), Image.LANCZOS)
        return img


def save(face, expr):
    img = face.draw(expr)
    img.save(os.path.join(OUT, "face_%s_%s.png" % (face.name, expr)), optimize=True)


PEOPLE = [
    # Jad: tired, stubble, heavy brows
    Face("jad", (170, 122, 90), (26, 22, 20), eyes=(52, 34, 22), brow=1.35, stubble=0.8, lids=0.8, age=0.15, mouth_w=1.05, hairline=60),
    # Inez: seventy-one, weathered, direct
    Face("inez", (200, 160, 136), (184, 180, 172), eyes=(70, 80, 72), brow=0.9, brow_col=(120, 110, 100), age=0.9, lids=0.6, mouth_w=0.95, lip_full=0.7, blush=0.15, hairline=62),
    # Dima: freckles, quick
    Face("dima", (216, 184, 168), (90, 58, 42), eyes=(80, 96, 70), brow=1.0, freckles=0.9, blush=0.4, lashes=0.4, lip_full=1.05, hairline=58),
    # Sal: glasses (3D), even, patient
    Face("sal", (200, 152, 120), (42, 36, 32), eyes=(58, 40, 28), brow=1.1, age=0.25, mouth_w=0.95, blush=0.2, hairline=60),
    # Teodor: old man, long face
    Face("teodor", (216, 184, 160), (200, 196, 188), eyes=(90, 110, 130), brow=1.4, brow_col=(170, 166, 160), age=1.0, lids=1.0, lip_full=0.65, blush=0.35),
    # Mrs. Kaye
    Face("kaye", (224, 196, 176), (216, 208, 208), eyes=(90, 100, 110), brow=0.7, brow_col=(160, 150, 150), age=1.0, lids=0.8, lips=(170, 90, 100), blush=0.5, lip_full=0.8, hairline=66),
    # Nell
    Face("nell", (106, 70, 54), (26, 20, 18), eyes=(40, 26, 18), brow=1.1, lashes=0.6, blush=0.15, lip_full=1.25, mouth_w=1.05, hairline=58),
    # June Pike
    Face("june", (216, 184, 160), (168, 160, 152), eyes=(80, 90, 100), brow=0.8, age=0.8, blush=0.45, hairline=64),
    # Mr. Adeyemi
    Face("adeyemi", (90, 58, 42), (26, 22, 20), eyes=(36, 24, 16), brow=1.2, age=0.45, lip_full=1.2, mouth_w=1.1, stubble=0.25, hairline=56),
    # the plaster Virgin in the frame: painted, eyes lowered
    Face("virgin", (232, 220, 204), (60, 50, 44), eyes=(70, 80, 110), brow=0.7, brow_col=(120, 96, 80), lips=(196, 120, 120), blush=0.35, lip_full=0.8, mouth_w=0.8),
    # the Municipal Attendant, Grade III: one face, eleven times
    Face("attendant", (208, 176, 152), (42, 36, 32), eyes=(60, 60, 64), brow=1.15, lip_full=0.85, blush=0.1, hairline=60),
]
GENERIC = [
    Face("gen_m", (255, 255, 255), (80, 80, 80), brow=1.2, modulate=True, seed=1),
    Face("gen_f", (255, 255, 255), (80, 80, 80), brow=0.9, lashes=0.5, lip_full=1.1, modulate=True, seed=2),
]


def main():
    n = 0
    for f in PEOPLE:
        for e in ("neutral", "smile", "worried", "closed"):
            save(f, e)
            n += 1
    for f in GENERIC:
        for e in ("neutral", "smile", "closed", "open"):
            save(f, e)
            n += 1
    print("faces:", n)


if __name__ == "__main__":
    main()
