class_name Kit
extends RefCounted
## Palette, fonts and small widget helpers shared by the UI.

const INK := Color("141217")
const INK2 := Color("1d1a21")
const IVORY := Color("e8e0cc")
const IVORY_DIM := Color("b3aa97")
const GREEN := Color("4f7a63")
const GREEN_DK := Color("23392f")
const BLUE := Color("1d2e5a")
const TILE := Color("3c7fb0")
const MAUVE := Color("9c8494")
const PINK := Color("b87a8a")
const RED := Color("d8342c")
const METAL := Color("7c7a72")

const SPEAKERS := {
	"ARI": {"name": "Ari", "color": Color("f2ebdd")},
	"JAD": {"name": "Jad", "color": Color("a9d18e")},
	"INEZ": {"name": "Inez", "color": Color("d49a64")},
	"DIMA": {"name": "Dima", "color": Color("c2a7d6")},
	"SAL": {"name": "Sal", "color": Color("cfe3dc")},
	"TEODOR": {"name": "Teodor", "color": Color("c49a70")},
	"KAYE": {"name": "Mrs. Kaye", "color": Color("9fb2d8")},
	"NELL": {"name": "Nell", "color": Color("eba2b6")},
	"TOBI": {"name": "Tobi", "color": Color("ead27a")},
	"LINE": {"name": "Recorded voice", "color": Color("9aa39c")},
	"OPERATOR": {"name": "Recorded voice", "color": Color("9aa39c")},
	"RADIO": {"name": "Radio", "color": Color("9aa39c")},
	"MAN": {"name": "Man across the courtyard", "color": Color("b9b0a0")},
	"WOMAN": {"name": "Woman across the courtyard", "color": Color("b9b0a0")},
	"JUNE": {"name": "June Pike", "color": Color("b9b0a0")},
	"ADEYEMI": {"name": "Mr. Adeyemi", "color": Color("b9b0a0")},
	"DRIVER": {"name": "Driver", "color": Color("b9b0a0")},
}

static var _fonts: Dictionary = {}

static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path := ""
	match kind:
		"display":
			path = "res://assets/fonts/FellSC.ttf"
		"display_italic":
			path = "res://assets/fonts/Fell-Italic.ttf"
		"bold":
			path = "res://assets/fonts/Atkinson-Bold.ttf"
		"italic":
			path = "res://assets/fonts/Atkinson-Italic.ttf"
		_:
			path = "res://assets/fonts/Atkinson-Regular.ttf"
	var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	_fonts[kind] = f
	return f

static func speaker_name(id: String) -> String:
	if SPEAKERS.has(id):
		return SPEAKERS[id]["name"]
	return id.capitalize()

static func speaker_color(id: String) -> Color:
	if SPEAKERS.has(id):
		return SPEAKERS[id]["color"]
	return IVORY

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

static func label(text: String, size: int = 18, color: Color = IVORY, kind: String = "text") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font("text"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", IVORY)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", IVORY)
	b.add_theme_stylebox_override("normal", flat(Color(0.12, 0.11, 0.14, 0.92), Color(IVORY_DIM, 0.45), 1, 2, 8))
	b.add_theme_stylebox_override("hover", flat(Color(0.2, 0.19, 0.23, 0.95), IVORY, 1, 2, 8))
	b.add_theme_stylebox_override("focus", flat(Color(0, 0, 0, 0), RED, 2, 2, 8))
	b.add_theme_stylebox_override("pressed", flat(Color(0.09, 0.08, 0.1, 0.95), IVORY, 1, 2, 8))
	b.add_theme_stylebox_override("disabled", flat(Color(0.1, 0.1, 0.1, 0.6), Color(0.3, 0.3, 0.3), 1, 2, 8))
	return b

static func esc_bb(t: String) -> String:
	return t.replace("[", "[lb]")
