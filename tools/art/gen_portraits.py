"""Portrait cameos, printed in two colours.

    godot --path . res://scenes/portrait_render.tscn -- <renders_dir>
    python3 tools/art/gen_portraits.py <renders_dir>

Each regular is printed like a small risograph: one ink for them and a paper
ivory, a halftone screen in the shadows, a hard keyline where the figure meets
the air, and the second pass a hair off register. Ari hears these people
more than it sees them; the cameo is what the voice looks like.
"""
import os, sys, glob
import numpy as np
from PIL import Image, ImageFilter, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "portraits")
os.makedirs(OUT, exist_ok=True)

IVORY = (236, 228, 208)
# one ink per person, from the palette
INK = {
    "jad": (34, 52, 104),        # deep blue
    "inez": (44, 92, 78),        # oxidized green
    "dima": (112, 78, 116),      # faded mauve
    "sal": (38, 78, 88),         # a council teal
    "teodor": (92, 60, 40),      # old photograph brown
    "kaye": (160, 64, 96),       # bruised pink
    "nell": (86, 40, 76),        # plum
}
rng = np.random.default_rng(7)


def screen(tone, cell=7, angle=0.4):
    """Halftone: dots whose size follows darkness, on a turned grid."""
    h, w = tone.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ca, sa = np.cos(angle), np.sin(angle)
    u = (xx * ca + yy * sa) / cell
    v = (-xx * sa + yy * ca) / cell
    du, dv = u - np.floor(u) - 0.5, v - np.floor(v) - 0.5
    dist = np.sqrt(du ** 2 + dv ** 2) / 0.7071
    return (dist < np.sqrt(np.clip(tone, 0, 1)) * 1.0).astype(np.float32)


def print_one(path, who):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    a = np.asarray(im, np.float32) / 255.0
    alpha = a[..., 3]
    lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    lum = np.where(alpha > 0.01, lum / np.maximum(alpha, 1e-3), 1.0)
    # tones on one curve for everybody, so a darker skin prints denser:
    # paper for the light, solid ink for the darkest, dots between
    fig = alpha > 0.5
    lo, hi = np.percentile(lum[fig], 2), np.percentile(lum[fig], 98)
    local = 1.0 - np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1)
    glob_ = np.clip(1.0 - lum * 1.1, 0, 1) ** 1.2 * 0.8 + 0.04
    dark = np.clip(glob_ * 0.55 + local * 0.45, 0, 1)
    t = 1.0 - dark
    solid = (dark > 0.86).astype(np.float32)
    dots = screen(np.clip((dark - 0.06) / 0.78, 0, 1), cell=5.4, angle=0.38)
    ink = np.clip(np.maximum(solid, dots) * alpha, 0, 1)
    # the keyline where the figure meets the air, and where tone breaks sharply
    edge = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES)
    e = np.asarray(edge.filter(ImageFilter.MaxFilter(3)), np.float32) / 255.0
    g = Image.fromarray((t * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES)
    ge = np.asarray(g, np.float32) / 255.0
    line = np.clip(e * 1.2 + (ge > 0.2) * 0.9, 0, 1)
    ink = np.clip(ink + line, 0, 1)
    # the ink doesn't lie flat: a little starvation, a little grain
    starve = rng.random((h, w)).astype(np.float32)
    ink *= (starve > 0.06).astype(np.float32)
    col = np.array(INK[who], np.float32) / 255.0
    pap = np.array(IVORY, np.float32) / 255.0
    rgb = pap[None, None, :] * (1 - ink[..., None]) + col[None, None, :] * ink[..., None]
    # a second, lighter pass of the same ink under everything, off register
    under = np.roll(np.roll(alpha * (0.35 * (t < 0.92)), 3, axis=0), -2, axis=1)
    rgb = rgb * (1 - under[..., None] * 0.25) + (col * 0.5 + pap * 0.5)[None, None, :] * under[..., None] * 0.25
    out_alpha = np.clip(np.maximum(alpha, np.roll(np.roll(alpha, 3, axis=0), -2, axis=1) * 0.9), 0, 1)
    out = np.dstack([rgb, out_alpha])
    img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")
    # crop to the figure, with a little air, and bring down to cameo size
    bb = img.getbbox()
    if bb:
        img = img.crop((max(0, bb[0] - 8), max(0, bb[1] - 8), min(w, bb[2] + 8), h))
    img = img.resize((int(img.width * 0.75), int(img.height * 0.75)), Image.LANCZOS)
    return img


def main(src):
    n = 0
    for path in sorted(glob.glob(os.path.join(src, "*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        who = name.split("_")[0]
        if who not in INK:
            continue
        print_one(path, who).save(os.path.join(OUT, name + ".png"), optimize=True)
        n += 1
    print("portraits:", n)


if __name__ == "__main__":
    main(sys.argv[1])
