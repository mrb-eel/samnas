class_name Kit
extends RefCounted
## The look of the whole interface, in one place: palette, typefaces, and
## the materials everything is made of. Nothing on screen is a panel. It's
## paper, tape, bakelite, brass, enamel, tile, and the red cord.

# ------------------------------------------------------------------ palette

const NIGHT := Color("0c0b10")
const INK := Color("16131a")
const INK2 := Color("1f1b22")
const SOOT := Color("2a2326")
const PAPER := Color("ebe2cc")
const PAPER_SHADE := Color("d6c9ab")
const PAPER_DARK := Color("b9aa8a")
const IVORY := Color("e8e0cc")
const IVORY_DIM := Color("b3aa97")
const GREEN := Color("4f7a63")
const GREEN_DK := Color("23392f")
const BLUE := Color("22385e")
const TILE := Color("3c6fa6")
const MAUVE := Color("8a6a8e")
const PINK := Color("b0607a")
const RED := Color("d2332a")
const CORD := Color("a52a22")
const CORD_DK := Color("64150f")
const BRASS := Color("c29c54")
const BRASS_DK := Color("6e5427")
const BRASS_LT := Color("ecd592")
const BAKELITE := Color("2a1c14")
const BAKELITE_LT := Color("4b3120")
const TAPE := Color(0.86, 0.78, 0.58, 0.9)
const CARBON := Color("3b3f9e")
const METAL := Color("7c7a72")
const AMBER := Color("f3b34c")
const LAMP_GREEN := Color("7fd08a")

## Everybody's name, a light colour for dark surfaces, and an ink for stamping
## paper (the same inks as their portrait cameos).
const SPEAKERS := {
	"ARI": {"name": "Ari", "color": Color("f2ebdd"), "ink": Color("b8261f")},
	"JAD": {"name": "Jad", "color": Color("a9c7e8"), "ink": Color("22385e")},
	"INEZ": {"name": "Inez", "color": Color("9fd0b4"), "ink": Color("2c5c4e")},
	"DIMA": {"name": "Dima", "color": Color("c9aed8"), "ink": Color("6e4c74")},
	"SAL": {"name": "Sal", "color": Color("a8d4d8"), "ink": Color("264e58")},
	"TEODOR": {"name": "Teodor", "color": Color("d8b48c"), "ink": Color("5c3a24")},
	"KAYE": {"name": "Mrs. Kaye", "color": Color("eaa8c0"), "ink": Color("a03c60")},
	"NELL": {"name": "Nell", "color": Color("e0a0cc"), "ink": Color("56284c")},
	"TOBI": {"name": "Tobi", "color": Color("ead27a"), "ink": Color("8a6a08")},
	"LINE": {"name": "Recorded voice", "color": Color("b8bdb4"), "ink": Color("4a4e48")},
	"OPERATOR": {"name": "Recorded voice", "color": Color("b8bdb4"), "ink": Color("4a4e48")},
	"RADIO": {"name": "Radio", "color": Color("b8bdb4"), "ink": Color("4a4e48")},
	"MAN": {"name": "Man across the courtyard", "color": Color("c9c0b0"), "ink": Color("54493e")},
	"WOMAN": {"name": "Woman across the courtyard", "color": Color("c9c0b0"), "ink": Color("54493e")},
	"JUNE": {"name": "June Pike", "color": Color("c9c0b0"), "ink": Color("4c5a3a")},
	"ADEYEMI": {"name": "Mr. Adeyemi", "color": Color("c9c0b0"), "ink": Color("3a3a54")},
	"DRIVER": {"name": "Driver", "color": Color("c9c0b0"), "ink": Color("54493e")},
}

## Label-maker tape colours for whose eyes the stage is looking through.
const VIEW_TAPE := {
	"jad": Color("1f3f78"), "inez": Color("2f6a52"), "dima": Color("6e4c80"), "sal": Color("255a66"),
	"teodor": Color("6a4428"), "kaye": Color("a83c64"), "nell": Color("5e2a56"), "tobi": Color("9a7a10"),
	"ari": Color("b8262a"), "plan": Color("1c2c50"), "heard": Color("1a1a1c"),
}

# ------------------------------------------------------------------ type

const FONT_FILES := {
	"prose": "Fraunces-Regular", "prose_i": "Fraunces-Italic", "prose_b": "Fraunces-SemiBold",
	"display": "Fraunces-Black", "display_i": "Fraunces-BlackItalic",
	"stamp": "Stencil-Black", "stamp_b": "Stencil-Bold",
	"dot": "Doto-Black", "dotline": "DotGothic16",
	"dymo": "Dymo-Bold", "marker": "Marker", "hand": "Caveat",
	"clean": "Atkinson-Regular", "clean_b": "Atkinson-Bold", "clean_i": "Atkinson-Italic",
}
## In clean-text mode the reading faces become Atkinson Hyperlegible.
const CLEAN_SWAP := {"prose": "clean", "prose_i": "clean_i", "prose_b": "clean_b", "text": "clean", "italic": "clean_i", "bold": "clean_b"}
## Older names still used around the code.
const ALIAS := {"text": "prose", "italic": "prose_i", "bold": "prose_b", "display_italic": "display_i"}

static var _fonts: Dictionary = {}

static func font(kind: String) -> Font:
	var k := kind
	if Settings.clean_text and CLEAN_SWAP.has(k):
		k = CLEAN_SWAP[k]
	k = ALIAS.get(k, k)
	if _fonts.has(k):
		return _fonts[k]
	var file: String = FONT_FILES.get(k, "Fraunces-Regular")
	var path := "res://assets/fonts/%s.ttf" % file
	var f: Font = ThemeDB.fallback_font
	if ResourceLoader.exists(path):
		var ff: FontFile = load(path)
		# Atkinson carries the glyphs the display faces lack
		var fb_path := "res://assets/fonts/Atkinson-Regular.ttf"
		if file != "Atkinson-Regular" and ResourceLoader.exists(fb_path):
			ff = ff.duplicate()
			ff.fallbacks = [load(fb_path)]
		f = ff
	_fonts[k] = f
	return f

static func speaker_name(id: String) -> String:
	if SPEAKERS.has(id):
		return SPEAKERS[id]["name"]
	return id.capitalize()

static func speaker_color(id: String) -> Color:
	if SPEAKERS.has(id):
		return SPEAKERS[id]["color"]
	return IVORY

static func speaker_ink(id: String) -> Color:
	if SPEAKERS.has(id):
		return SPEAKERS[id]["ink"]
	return Color("4a4238")

# ------------------------------------------------------------------ widgets

static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 0, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

static func empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

static func tex_box(path: String, margin: int, pad: int = 0, fallback: StyleBox = null) -> StyleBox:
	if not ResourceLoader.exists(path):
		return fallback if fallback else flat(INK2, IVORY_DIM, 1, 0, pad)
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

static func label(text: String, size: int = 18, color: Color = IVORY, kind: String = "prose") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## A plain button for the few places a real button is still the honest thing
## (the name form). Everything else is drawn.
static func button(text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font("dymo"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color("f4f0e6"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("f4f0e6"))
	b.add_theme_stylebox_override("normal", flat(Color("1a1a1c"), Color(0, 0, 0, 0), 0, 6, 10))
	b.add_theme_stylebox_override("hover", flat(Color("b8262a"), Color(0, 0, 0, 0), 0, 6, 10))
	b.add_theme_stylebox_override("focus", flat(Color(0, 0, 0, 0), AMBER, 2, 6, 10))
	b.add_theme_stylebox_override("pressed", flat(Color("7a1a16"), Color(0, 0, 0, 0), 0, 6, 10))
	b.add_theme_stylebox_override("disabled", flat(Color(0.1, 0.1, 0.1, 0.6), Color(0, 0, 0, 0), 0, 6, 10))
	return b

static func esc_bb(t: String) -> String:
	return t.replace("[", "[lb]")

## A small repeatable hash in 0..1 for jitter that doesn't flicker.
static func rnd(a: float, b: float = 0.0, c: float = 0.0) -> float:
	var x := sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453
	return x - floor(x)

# ------------------------------------------------------------------ materials

static var _tex_cache: Dictionary = {}

static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t

static var _shadow_box: StyleBoxTexture

## A soft shadow under a rect, cast away from the lamp at the top left.
## lift 0 lies flat on the wall; 1 is held up close to you.
static func shadow(ci: CanvasItem, r: Rect2, lift: float = 0.2, strength: float = 1.0) -> void:
	if _shadow_box == null:
		var t := tex("res://assets/ui/shadow.png")
		if t == null:
			return
		_shadow_box = StyleBoxTexture.new()
		_shadow_box.texture = t
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_shadow_box.set_texture_margin(side, 30)
	var off := Vector2(0.55, 1.0) * (3.0 + lift * 16.0)
	var grow := 10.0 + lift * 14.0
	var sr := Rect2(r.position + off - Vector2(grow, grow), r.size + Vector2(grow, grow) * 2.0)
	_shadow_box.modulate_color = Color(0, 0, 0, clampf((0.62 - lift * 0.18) * strength, 0, 1))
	ci.draw_style_box(_shadow_box, sr)

## Paper: a sheet with a soft shadow, fibre texture, and edges that aren't
## quite straight. Drawn in the canvas item's current transform.
static func paper(ci: CanvasItem, r: Rect2, col: Color = PAPER, lift: float = 0.15, seed: float = 0.0, ragged: float = 0.0) -> void:
	shadow(ci, r, lift)
	if ragged <= 0.0:
		ci.draw_rect(r, col)
	else:
		var pts := PackedVector2Array()
		var n := int(r.size.x / 7.0)
		for i in range(n + 1):
			pts.append(Vector2(r.position.x + r.size.x * i / n, r.position.y + rnd(seed, i) * ragged))
		for i in range(n + 1):
			pts.append(Vector2(r.end.x - r.size.x * i / n, r.end.y - rnd(seed + 9.0, i) * ragged))
		ci.draw_colored_polygon(pts, col)
	var t := tex("res://assets/ui/paper.png")
	if t:
		ci.draw_texture_rect(t, r, true, Color(1, 1, 1, 0.42))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.25))
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.12))

## Masking tape, torn at both ends.
static func tape(ci: CanvasItem, center: Vector2, angle: float, length: float = 70.0, width: float = 22.0, col: Color = TAPE) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var nor := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var half := length * 0.5
	var steps := 5
	for i in range(steps + 1):
		var s := -width * 0.5 + width * i / steps
		pts.append(center - dir * (half + rnd(center.x, i) * 4.0) + nor * s)
	for i in range(steps + 1):
		var s2 := width * 0.5 - width * i / steps
		pts.append(center + dir * (half + rnd(center.y, i) * 4.0) + nor * s2)
	ci.draw_colored_polygon(pts, col)
	ci.draw_line(center - dir * half + nor * (width * 0.5 - 2), center + dir * half + nor * (width * 0.5 - 2), Color(1, 1, 1, 0.18), 1.0)

## Embossed label-maker tape. Returns the tape's size.
static func dymo(ci: CanvasItem, pos: Vector2, text: String, size: int = 16, tape_col: Color = Color("1a1a1c"), angle: float = 0.0, letter_col: Color = Color("f2efe8")) -> Vector2:
	var f := font("dymo")
	var s := text.to_upper()
	var spacing := size * 0.14
	var w := 0.0
	for ch in s:
		w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	var h := size * 1.45
	var tape_size := Vector2(w + size * 1.1, h)
	ci.draw_set_transform(pos, angle)
	var r := Rect2(Vector2.ZERO, tape_size)
	ci.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(r, tape_col)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, h * 0.42)), Color(1, 1, 1, 0.09))
	ci.draw_rect(Rect2(Vector2(0, h - 2), Vector2(r.size.x, 2)), Color(0, 0, 0, 0.25))
	# notched ends, as the cutter leaves them
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.5, 0), Vector2(3, h * 0.5), Vector2(-0.5, h)]), Color(0, 0, 0, 0.0))
	var x := size * 0.55
	var base := h * 0.5 + size * 0.36
	for ch in s:
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ci.draw_string(f, Vector2(x + 0.8, base + 1.2), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.55))
		ci.draw_string(f, Vector2(x - 0.6, base - 0.6), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.35))
		ci.draw_string(f, Vector2(x, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, letter_col)
		x += cw + spacing
	ci.draw_set_transform(Vector2.ZERO)
	return tape_size

static func dymo_size(text: String, size: int = 16) -> Vector2:
	var f := font("dymo")
	var spacing := size * 0.14
	var w := 0.0
	for ch in text.to_upper():
		w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	return Vector2(w + size * 1.1, size * 1.45)

## A rubber stamp in one ink, a little uneven, boxed or not.
static func stamp(ci: CanvasItem, pos: Vector2, text: String, col: Color, size: int = 22, angle: float = 0.0, boxed: bool = true, paper_col: Color = PAPER) -> Vector2:
	var f := font("stamp")
	var s := text.to_upper()
	var ts := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pad := Vector2(size * 0.4, size * 0.16)
	var box := Vector2(ts.x + pad.x * 2.0, size * 1.12 + pad.y * 2.0)
	ci.draw_set_transform(pos, angle)
	var ink := Color(col, 0.88)
	ci.draw_string(f, Vector2(pad.x, pad.y + size * 0.92), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	ci.draw_string(f, Vector2(pad.x + 0.7, pad.y + size * 0.92 + 0.4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, 0.25))
	if boxed:
		ci.draw_rect(Rect2(Vector2.ZERO, box), ink, false, 2.2)
		ci.draw_rect(Rect2(Vector2(3.5, 3.5), box - Vector2(7, 7)), Color(col, 0.5), false, 1.0)
	# ink that didn't take
	var mask := tex("res://assets/ui/stamp_mask.png")
	if mask:
		var off := Vector2(rnd(pos.x, pos.y) * 180.0, rnd(pos.y, pos.x) * 180.0)
		ci.draw_texture_rect_region(mask, Rect2(Vector2(-2, -2), box + Vector2(4, 4)), Rect2(off, box + Vector2(4, 4)), Color(paper_col, 0.75))
	ci.draw_set_transform(Vector2.ZERO)
	return box

## A brass jack in a bakelite face: a ring, a hole, a glint.
static func jack(ci: CanvasItem, c: Vector2, r: float = 11.0, plugged: bool = false) -> void:
	ci.draw_circle(c + Vector2(1.5, 2.5), r + 2.0, Color(0, 0, 0, 0.45))
	ci.draw_circle(c, r + 1.5, BRASS_DK)
	ci.draw_circle(c, r, BRASS)
	ci.draw_arc(c, r - 1.5, PI * 1.05, PI * 1.75, 10, BRASS_LT, 2.0)
	ci.draw_circle(c, r * 0.48, Color("0a0806") if not plugged else BRASS_DK)
	if plugged:
		ci.draw_circle(c, r * 0.3, CORD_DK)

## A lamp cap: dark when off, lit and haloed when on.
static func lamp(ci: CanvasItem, c: Vector2, r: float, col: Color, on: bool) -> void:
	ci.draw_circle(c + Vector2(1, 2), r + 2.5, Color(0, 0, 0, 0.5))
	ci.draw_circle(c, r + 2.0, Color("1a1410"))
	if on:
		ci.draw_circle(c, r * 3.2, Color(col, 0.08))
		ci.draw_circle(c, r * 2.0, Color(col, 0.16))
		ci.draw_circle(c, r, col)
		ci.draw_circle(c - Vector2(r * 0.3, r * 0.35), r * 0.35, Color(1, 1, 1, 0.6))
	else:
		ci.draw_circle(c, r, Color(col.darkened(0.72), 1.0))
		ci.draw_circle(c - Vector2(r * 0.3, r * 0.35), r * 0.3, Color(1, 1, 1, 0.12))

static func text(ci: CanvasItem, pos: Vector2, s: String, kind: String, size: int, col: Color, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(font(kind), pos, s, align, width, size, col)

static func text_w(s: String, kind: String, size: int) -> float:
	return font(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# ------------------------------------------------------------------ mosaic

## 5x7 letters for tile mosaics, the way the baths spelled its name in the
## entrance floor.
const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	",": [".....", ".....", ".....", ".....", ".##..", "..#..", ".#..."],
	"·": [".....", ".....", "..#..", ".###.", "..#..", ".....", "....."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
	"'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}

## Tiles across a mosaic line of text (letters are 5 wide with a gap of 1).
static func mosaic_cols(s: String) -> int:
	return maxi(0, s.length() * 6 - 1)

## Lay a line of mosaic lettering. `t` 0..1 is how much of it is laid (tiles
## go down in a sweep); `border` adds a band of tiles round it.
static func mosaic(ci: CanvasItem, origin: Vector2, s: String, tile: float, t: float = 1.0,
		letter: Color = Color("1f3f78"), ground: Color = Color("e6dfcc"), border_col: Color = Color("3d6e5a"),
		border: int = 2, grout: Color = Color("2e2a26"), seed: float = 0.0) -> Vector2:
	var txt := s.to_upper()
	var cols := mosaic_cols(txt) + border * 2 + 2
	var rows := 7 + border * 2 + 2
	var size := Vector2(cols, rows) * tile
	ci.draw_rect(Rect2(origin - Vector2(2, 2), size + Vector2(4, 4)), grout)
	var total := float(cols + rows)
	for y in rows:
		for x in cols:
			var order := (x + y * 0.6) / total
			if order > t * 1.15:
				continue
			var appear := clampf((t * 1.15 - order) * 8.0, 0.0, 1.0)
			var gx := x - border - 1
			var gy := y - border - 1
			var col := ground
			var edge := x < border or y < border or x >= cols - border or y >= rows - border
			if edge:
				col = border_col
				if (x < border and y < border) or (x >= cols - border and y >= rows - border) or (x < border and y >= rows - border) or (x >= cols - border and y < border):
					col = RED.darkened(0.15)
			elif gy >= 0 and gy < 7 and gx >= 0:
				var ci_idx := gx / 6
				var cx := gx % 6
				if ci_idx < txt.length() and cx < 5:
					var g: Array = GLYPHS.get(txt[ci_idx], GLYPHS[" "])
					if str(g[gy])[cx] == "#":
						col = letter
			var j := rnd(x + seed, y)
			col = col.lightened((j - 0.5) * 0.14)
			var inset := 1.0 + rnd(y + seed, x) * 0.8
			var sz := (tile - inset * 2.0) * (0.6 + 0.4 * appear)
			var p := origin + Vector2(x, y) * tile + Vector2(tile - sz, tile - sz) * 0.5 + Vector2(rnd(x, y, 3.0) - 0.5, rnd(y, x, 5.0) - 0.5) * 0.9
			if j > 0.992 and not edge:
				# a tile gone: grout and a lighter rim
				ci.draw_rect(Rect2(p, Vector2(sz, sz)), Color("1a1714"))
				continue
			ci.draw_rect(Rect2(p, Vector2(sz, sz)), col)
			ci.draw_rect(Rect2(p, Vector2(sz, 1.0)), Color(1, 1, 1, 0.22))
			ci.draw_rect(Rect2(p + Vector2(0, sz - 1.0), Vector2(sz, 1.0)), Color(0, 0, 0, 0.22))
			if j < 0.012:
				ci.draw_line(p + Vector2(sz * 0.2, 0), p + Vector2(sz * 0.8, sz), Color(0, 0, 0, 0.45), 1.0)
	return size
