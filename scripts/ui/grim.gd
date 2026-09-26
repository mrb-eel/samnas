class_name Grim
extends RefCounted
## What the interface is made of: council steel painted and scratched,
## bakelite, a green phosphor screen, red buttons, masking tape and label
## tape. Everything is drawn on the 640x360 grid and scaled up by whole
## pixels, so nothing is smoother than the hardware it pretends to be.

const W := 640.0
const H := 360.0

# ---------------------------------------------------------------- palette
const INK := Color("0a0a0b")
const SOOT := Color("15130f")
const STEEL_DK := Color("24221e")
const STEEL := Color("3a3833")
const STEEL_LT := Color("5c574d")
const HILITE := Color("8f8876")
const RUST := Color("7a3b20")
const RUST_LT := Color("a4582c")
const IVORY := Color("d6ccb0")
const IVORY_DIM := Color("8f8871")
const PAPER := Color("cfc3a1")
const PHOS := Color("8dff9a")
const PHOS_MID := Color("4fcf66")
const PHOS_DIM := Color("2c7d3e")
const PHOS_DK := Color("0f2917")
const PHOS_BG := Color("06120a")
const AMBER := Color("f0a83a")
const AMBER_DIM := Color("7a5220")
const RED := Color("d8281c")
const RED_DK := Color("6e130e")
const BLUE := Color("22335a")
const MAUVE := Color("6e5566")
const BRUISE := Color("9a4a62")
const OX := Color("4f7a5c")

## Each person's lamp colour: the one thing on the green screen that isn't green.
const WHO := {
	"jad": Color("8fbf73"), "inez": Color("d08a4a"), "dima": Color("b39ad0"), "sal": Color("bfe0d6"),
	"teodor": Color("b58d63"), "kaye": Color("8fa3cf"), "nell": Color("e392aa"), "ari": Color("f2ebdd"),
	"tobi": Color("e3c96a"), "mikael": Color("9a8a70"),
}

const FONTS := {
	"body": "res://assets/fonts/VT323.ttf",
	"head": "res://assets/fonts/Jersey10.ttf",
	"tiny": "res://assets/fonts/Tiny5.ttf",
	"lcd": "res://assets/fonts/Handjet-Bold.ttf",
	"scan": "res://assets/fonts/Workbench.ttf",
	"stencil": "res://assets/fonts/Stencil-Black.ttf",
	"dymo": "res://assets/fonts/Dymo-Bold.ttf",
	"marker": "res://assets/fonts/Marker.ttf",
	"hand": "res://assets/fonts/Caveat.ttf",
	"plain": "res://assets/fonts/Atkinson-Regular.ttf",
	"plain_b": "res://assets/fonts/Atkinson-Bold.ttf",
	"plain_i": "res://assets/fonts/Atkinson-Italic.ttf",
}
## Faces drawn as hard pixels. The rest (handwriting, plain text) keep
## their edges soft, because at 640 wide they need it to be read at all.
const PIXEL_FONTS := ["body", "head", "tiny", "lcd", "scan"]

static var _fonts: Dictionary = {}
static var _tex: Dictionary = {}

## Plain text: the accessibility setting that swaps the pixel faces for a
## legible one and switches off flicker and scanlines on words.
static func plain() -> bool:
	return Settings.plain_text

static func font(kind: String) -> Font:
	if plain():
		match kind:
			"body", "tiny", "lcd", "scan":
				kind = "plain"
			"head", "stencil", "dymo":
				kind = "plain_b"
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = FONTS.get(kind, FONTS["body"])
	var f: FontFile = load(path).duplicate()
	if kind in PIXEL_FONTS:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	else:
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_fonts[kind] = f
	return f

## Body text size from the settings. The pixel face only looks right at
## its own multiples; the plain face scales freely.
static func body_size() -> int:
	return Settings.body_px()

static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex[path] = t
	return t

static func surf(name: String) -> Texture2D:
	return tex("res://assets/ui/grim/%s.png" % name)

static func rnd(s: float) -> float:
	return fposmod(sin(s * 127.1 + 311.7) * 43758.5453, 1.0)

static func snap(r: Rect2) -> Rect2:
	return Rect2(r.position.round(), r.size.round())

# ---------------------------------------------------------------- text

static func text(ci: CanvasItem, pos: Vector2, s: String, kind: String = "body", size: int = 16, col: Color = PHOS, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(font(kind), pos.round(), s, align, width, size, col)

## Text with a pixel of phosphor smear to its right, the way a cheap tube
## lets bright things bleed.
static func glow_text(ci: CanvasItem, pos: Vector2, s: String, kind: String = "body", size: int = 16, col: Color = PHOS, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := font(kind)
	if not plain():
		ci.draw_string(f, pos.round() + Vector2(1, 0), s, align, width, size, Color(col, col.a * 0.28))
	ci.draw_string(f, pos.round(), s, align, width, size, col)

static func text_w(s: String, kind: String, size: int) -> float:
	return font(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

static func line_h(kind: String, size: int) -> float:
	return font(kind).get_height(size)

## Greedy word wrap, so layout and drawing agree on where lines break.
static func wrap_text(s: String, kind: String, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var f := font(kind)
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var trial := word if line == "" else line + " " + word
			if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width or line == "":
				line = trial
			else:
				out.append(line)
				line = word
		out.append(line)
	return out

static func para(ci: CanvasItem, pos: Vector2, s: String, kind: String, size: int, col: Color, width: float, lh: float = 0.0) -> float:
	var lines := wrap_text(s, kind, size, width)
	if lh <= 0.0:
		lh = line_h(kind, size)
	var y := pos.y
	for l in lines:
		ci.draw_string(font(kind), Vector2(pos.x, y).round(), l, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += lh
	return y - pos.y

# ---------------------------------------------------------------- surfaces

## A plate of painted steel: textured, bevelled one pixel each way, black
## edge, a rivet in each corner. `seed` slides the texture so neighbouring
## plates don't match.
static func plate(ci: CanvasItem, r: Rect2, surface: String = "steel", seed: float = 0.0, rivets: bool = true, tint: Color = Color.WHITE) -> void:
	r = snap(r)
	ci.draw_rect(r, INK)
	var inner := r.grow(-1)
	var t := surf(surface)
	if t:
		var off := Vector2(floorf(rnd(seed) * 128.0), floorf(rnd(seed + 3.1) * 128.0))
		ci.draw_texture_rect_region(t, inner, Rect2(off, inner.size), tint)
	else:
		ci.draw_rect(inner, STEEL * tint)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), Color(HILITE, 0.55))
	ci.draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), Color(HILITE, 0.35))
	ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(inner.size.x, 1)), Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1, 0), Vector2(1, inner.size.y)), Color(0, 0, 0, 0.5))
	if rivets and r.size.x > 24 and r.size.y > 18:
		for c in [Vector2(4, 4), Vector2(r.size.x - 7, 4), Vector2(4, r.size.y - 7), Vector2(r.size.x - 7, r.size.y - 7)]:
			rivet(ci, r.position + c)

static func rivet(ci: CanvasItem, p: Vector2) -> void:
	p = p.round()
	ci.draw_rect(Rect2(p, Vector2(3, 3)), Color("1a1916"))
	ci.draw_rect(Rect2(p, Vector2(2, 2)), Color("6d675a"))
	ci.draw_rect(Rect2(p, Vector2(1, 1)), Color("b3ab96"))

## A hole in the plate: dark lip on top and left, catch-light on the others.
static func inset(ci: CanvasItem, r: Rect2, fill: Color = INK) -> void:
	r = snap(r)
	ci.draw_rect(r, fill)
	ci.draw_rect(Rect2(r.position - Vector2(1, 1), Vector2(r.size.x + 1, 1)), Color(0, 0, 0, 0.8))
	ci.draw_rect(Rect2(r.position - Vector2(1, 1), Vector2(1, r.size.y + 1)), Color(0, 0, 0, 0.8))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y), Vector2(r.size.x + 1, 1)), Color(HILITE, 0.4))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x, 0), Vector2(1, r.size.y)), Color(HILITE, 0.3))

## A green screen set into the plate. `t` is time, for the roll bar.
static func crt(ci: CanvasItem, r: Rect2, t: float = 0.0, bright: float = 1.0) -> void:
	r = snap(r)
	inset(ci, r.grow(1), Color("050806"))
	ci.draw_rect(r, PHOS_BG)
	if plain():
		ci.draw_rect(r, Color("050505"))
		return
	# the phosphor is brighter in the middle
	var g := r.grow(-3)
	ci.draw_rect(g, Color(PHOS_DK, 0.35 * bright))
	ci.draw_rect(g.grow(-6), Color(PHOS_DK, 0.3 * bright))
	# a slow roll bar
	if Settings.reduced_motion == false:
		var ry := r.position.y + fposmod(t * 22.0, r.size.y + 30.0) - 15.0
		var bar := Rect2(r.position.x, ry, r.size.x, 10).intersection(r)
		if bar.size.y > 0:
			ci.draw_rect(bar, Color(PHOS, 0.035))
	# rounded corners of the tube
	var cc := Color("050806")
	for k in [[0, 0], [1, 0], [0, 1]]:
		ci.draw_rect(Rect2(r.position + Vector2(k[0], k[1]), Vector2.ONE), cc)
		ci.draw_rect(Rect2(Vector2(r.end.x - 1 - k[0], r.position.y + k[1]), Vector2.ONE), cc)
		ci.draw_rect(Rect2(Vector2(r.position.x + k[0], r.end.y - 1 - k[1]), Vector2.ONE), cc)
		ci.draw_rect(Rect2(r.end - Vector2(1 + k[0], 1 + k[1]), Vector2.ONE), cc)

## Scanlines over whatever has been drawn in the screen. Call last.
static func crt_glass(ci: CanvasItem, r: Rect2) -> void:
	if plain():
		return
	r = snap(r)
	var y := r.position.y + 1
	while y < r.end.y:
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, 1), Color(0, 0, 0, 0.22))
		y += 2
	# a streak of reflected room light across the glass
	ci.draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(r.size.x * 0.35, 1)), Color(1, 1, 1, 0.05))

## A lamp: a few pixels, and a halo when lit.
static func lamp(ci: CanvasItem, c: Vector2, col: Color, on: bool, r: int = 2) -> void:
	c = c.round()
	if on:
		ci.draw_rect(Rect2(c - Vector2(r + 2, r + 2), Vector2(r * 2 + 5, r * 2 + 5)), Color(col, 0.12))
		ci.draw_rect(Rect2(c - Vector2(r + 1, r + 1), Vector2(r * 2 + 3, r * 2 + 3)), Color(col, 0.22))
	ci.draw_rect(Rect2(c - Vector2(r + 1, r + 1), Vector2(r * 2 + 3, r * 2 + 3)), INK)
	ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2 + 1, r * 2 + 1)), col if on else col.darkened(0.72))
	if on:
		ci.draw_rect(Rect2(c - Vector2(r - 1, r - 1), Vector2(1, 1)), Color(1, 1, 1, 0.8))

## The big red push button, round, in a steel collar.
static func red_button(ci: CanvasItem, c: Vector2, hot: bool, down: bool, r: int = 5, col: Color = RED) -> void:
	c = c.round()
	_disc(ci, c, r + 2, INK)
	_disc(ci, c, r + 1, STEEL_LT)
	var face := col.lightened(0.18) if hot else col
	if down:
		face = col.darkened(0.3)
	_disc(ci, c + (Vector2(0, 1) if down else Vector2.ZERO), r, face.darkened(0.45))
	_disc(ci, c + (Vector2(0, 1) if down else Vector2(-0.5, -0.5)), r - 1, face)
	if not down:
		ci.draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.6), Vector2(2, 1)), Color(1, 1, 1, 0.55))

static func _disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	# pixel disc: row by row, no antialiasing
	var ri := int(ceil(r))
	for y in range(-ri, ri + 1):
		var half := floorf(sqrt(maxf(r * r - y * y, 0.0)))
		if half <= 0 and absf(y) >= r:
			continue
		ci.draw_rect(Rect2(c.x - half, c.y + y, half * 2 + 1, 1), col)

## A strip of masking tape with marker on it. Returns its width.
static func tape(ci: CanvasItem, pos: Vector2, s: String, size: int = 16, ink: Color = Color("1e1a17"), paper: Color = Color("c9b98e")) -> float:
	pos = pos.round()
	var f := font("marker")
	var w := ceilf(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) + 10.0
	var h := float(size) + 4.0
	var r := Rect2(pos, Vector2(w, h))
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.45))
	ci.draw_rect(r, paper)
	ci.draw_rect(Rect2(r.position, Vector2(w, 1)), paper.lightened(0.12))
	# torn ends
	for y in range(0, int(h), 2):
		var j := int(rnd(pos.x + y) * 2.0)
		ci.draw_rect(Rect2(pos.x, pos.y + y, 1 + j, 2), Color(0, 0, 0, 0))
		ci.draw_rect(Rect2(pos.x + w - 1 - j, pos.y + y, 1 + j, 2), paper.darkened(0.25))
	ci.draw_string(f, pos + Vector2(5, h - 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	return w

## Embossed label tape: raised pale letters on coloured plastic.
static func dymo(ci: CanvasItem, pos: Vector2, s: String, size: int = 12, tape_col: Color = Color("20223a"), letter: Color = Color("d8d8d0")) -> float:
	pos = pos.round()
	var f := font("dymo")
	var tw := ceilf(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var r := Rect2(pos, Vector2(tw + 10, size + 4))
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.5))
	ci.draw_rect(r, tape_col)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), tape_col.lightened(0.2))
	ci.draw_string(f, pos + Vector2(5, size + 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6))
	ci.draw_string(f, pos + Vector2(5, size), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, letter)
	return r.size.x

## Checkerboard shade: how old hardware did transparency. One tiled
## texture, not a rect per pixel.
static var _checker: Dictionary = {}
static func dither(ci: CanvasItem, r: Rect2, col: Color, density: int = 2) -> void:
	r = snap(r)
	if not _checker.has(density):
		var img := Image.create(density * 2, density * 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in density * 2:
			for x in density * 2:
				if (x + (y % density)) % density == 0:
					img.set_pixel(x, y, Color.WHITE)
		_checker[density] = ImageTexture.create_from_image(img)
	ci.draw_texture_rect(_checker[density], r, true, col)

## Horizontal bars of wrong colour and shifted blocks, for when the signal
## doesn't hold.
static func glitch(ci: CanvasItem, r: Rect2, t: float, amount: float) -> void:
	if amount <= 0.0 or Settings.reduced_motion or plain():
		return
	var k := floorf(t * 18.0)
	var n := int(amount * 14.0)
	for i in n:
		var s: float = k * 13.0 + i * 7.7
		var y: float = r.position.y + floorf(rnd(s) * r.size.y)
		var h: float = 1.0 + floorf(rnd(s + 1.0) * 5.0)
		var x: float = r.position.x + floorf(rnd(s + 2.0) * r.size.x * 0.7)
		var w: float = 20.0 + floorf(rnd(s + 3.0) * r.size.x * 0.5)
		var cols: Array[Color] = [Color(RED, 0.5), Color(PHOS, 0.35), Color(IVORY, 0.25), Color(0, 0, 0, 0.7)]
		var c: Color = cols[int(rnd(s + 4.0) * 4.0) % 4]
		ci.draw_rect(Rect2(x, y, w, h).intersection(r), c)

## A thin dark band behind text laid over the picture.
static func band(ci: CanvasItem, r: Rect2, a: float = 0.78) -> void:
	r = snap(r)
	ci.draw_rect(r, Color(0.02, 0.02, 0.02, a))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.06))
