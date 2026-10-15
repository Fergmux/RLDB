class_name UIStyle
extends RefCounted
## Shared design tokens (art bible), bundled fonts, UI settings and small widget
## factories for the code-built UI. Tune colours here, never per widget.

# ---- palette (design/art/art-bible.md section 2) ----
const BG := Color("0e0d0c")            # table_deep
const TABLE_WOOD := Color("2a211a")
const TABLE_INLAY := Color("3a2e22")
const PANEL := Color("1f1c1a")         # panel_slate
const PANEL_LIGHT := Color("2a2623")   # panel_raised
const PANEL_INK := Color("12100f")
const BRONZE := Color("7a5a30")
const GOLD := Color("d4a64a")
const GOLD_HI := Color("f0cf7a")
const TEXT := Color("ece4d2")
const MUTED := Color("c2b8a2")
const DISABLED := Color("918874")
const ON_GOLD := Color("1a1208")
const ACCENT := GOLD
const GOOD := Color("6fd38a")
const BAD := Color("e8605a")
const TARGET := Color("ffd84a")
const SELECT := Color("63b3ff")
const HOVER := Color("f0cf7a")
const RUNE_BLUE := Color("5aa2ff")
const ZONE_TINT := {"unit": Color("3b2a1a"), "trap": Color("3a1c1c"), "power": Color("1c2a3d")}

const TYPE_COLORS := {
	"Water": Color("3f86d6"), "Fire": Color("d4533a"), "Earth": Color("8f7340"),
	"Lightning": Color("e0bd32"), "Heavenly": Color("f0e4b0"), "Necrotic": Color("7e4fb5"),
	"Physical": Color("98979a"), "": Color("5b5a58"),
}
const CATEGORY_COLORS := {
	"basic_unit": Color("6d6a66"), "unit": Color("9a8f7c"), "spell": Color("2f9a6a"),
	"trap": Color("a8386f"), "power": Color("c9a23a"), "fusion": Color("7f5fd0"),
	"ritual": Color("3f7fd0"), "arcane": Color("1fb0a0"),
}
const CATEGORY_NAMES := {
	"basic_unit": "Basic Unit", "unit": "Unit", "spell": "Spell", "trap": "Trap", "power": "Power",
	"fusion": "Fusion Unit", "ritual": "Ritual Unit", "arcane": "Arcane Unit",
}
const COST_COLORS := {"ap": Color("f2b544"), "ritual": Color("4a8fe0"), "arcane": Color("1fb0a0"), "fusion": Color("9d7ae8")}
const STATUS_SHORT := {
	"retain": "RET", "reveal": "REV", "eternal": "ETR", "burn": "BRN", "pierce": "PRC", "cleanse": "CLN",
	"paralyse": "PAR", "medic": "MED", "curse": "CRS", "poison": "PSN", "infiltrate": "INF", "blind": "BLD",
	"nimble": "NIM", "debilitate": "DEB", "rune": "RUNE",
}

# ---- fonts ----
const FONT_BODY := "res://assets/fonts/AlegreyaSans-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/AlegreyaSans-Bold.ttf"
const FONT_ITALIC := "res://assets/fonts/AlegreyaSans-Italic.ttf"
const FONT_DISPLAY := "res://assets/fonts/Cinzel-Variable.ttf"
const WGHT_TAG := 2003265652   # OpenType 'wght'

static var _fonts := {}


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


static func font_body() -> Font:
	return _font(FONT_BODY)


static func font_bold() -> Font:
	return _font(FONT_BOLD)


static func font_italic() -> Font:
	return _font(FONT_ITALIC)


## Cinzel at a given weight (600 names/titles, 700 numbers).
static func font_display(weight: int = 600) -> Font:
	var key := "cinzel%d" % weight
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = _font(FONT_DISPLAY)
		fv.variation_opentype = {WGHT_TAG: weight}
		_fonts[key] = fv
	return _fonts[key]


# ---- settings (persisted in user://ui_settings.cfg) ----
const SETTINGS_PATH := "user://ui_settings.cfg"
static var reduce_motion: bool = false
static var fast_anim: bool = false
static var _settings_loaded: bool = false


static func load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		reduce_motion = bool(cf.get_value("ui", "reduce_motion", false))
		fast_anim = bool(cf.get_value("ui", "fast_anim", false))


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ui", "reduce_motion", reduce_motion)
	cf.set_value("ui", "fast_anim", fast_anim)
	cf.save(SETTINGS_PATH)


static func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	save_settings()


static func set_fast_anim(on: bool) -> void:
	fast_anim = on
	save_settings()


## Scales an animation duration (seconds) by the "fast animations" option.
static func dur(sec: float) -> float:
	return sec * (0.5 if fast_anim else 1.0)


# ---- factories ----
static func flat(color: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


static func label(text: String, size: int = 14, color: Color = TEXT, wrap: bool = false, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display:
		l.add_theme_font_override("font", font_display(600))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_bold())
	b.focus_mode = Control.FOCUS_NONE
	return b


## Gold-filled primary action button.
static func primary_button(text: String, size: int = 15) -> Button:
	var b := button(text, size)
	var n := flat(GOLD, GOLD_HI, 1, 6)
	var h := flat(GOLD_HI, Color.WHITE, 1, 6)
	var p := flat(GOLD.darkened(0.15), GOLD_HI, 1, 6)
	var d := flat(PANEL, Color("30343f").darkened(0.3), 1, 6)
	for s in [n, h, p, d]:
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 5
		s.content_margin_bottom = 5
	p.content_margin_top = 6
	p.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ON_GOLD)
	b.add_theme_color_override("font_disabled_color", DISABLED)
	return b


## Panel style (bronze trim on slate, rounded). `color` lets overlays use a denser fill.
static func panel_style(color: Color = PANEL, border: Color = BRONZE, radius: int = 10) -> StyleBoxFlat:
	var sb := flat(color, border, 2, radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb


static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color))
	return p


static func type_color(t) -> Color:
	return TYPE_COLORS.get(t if t != null else "", TYPE_COLORS[""])


static func make_theme() -> Theme:
	load_settings()
	var th := Theme.new()
	th.default_font = font_body()
	th.default_font_size = 14
	var normal := flat(PANEL_LIGHT, BRONZE, 1, 6)
	var hover := flat(PANEL_LIGHT.lightened(0.08), GOLD, 1, 6)
	var pressed := flat(PANEL, GOLD, 1, 6)
	var disabled := flat(PANEL, Color("2a2623"), 1, 6)
	for s in [normal, hover, pressed, disabled]:
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 5
		s.content_margin_bottom = 5
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 4
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	# Wider, higher-contrast scrollbars so scrollable panels read as scrollable.
	var track := flat(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0, 5)
	track.content_margin_left = 5
	track.content_margin_right = 5
	var grab := flat(Color(GOLD, 0.7), Color.TRANSPARENT, 0, 5)
	var grab_hi := flat(GOLD_HI, Color.TRANSPARENT, 0, 5)
	for sb in [grab, grab_hi]:
		sb.content_margin_left = 5
		sb.content_margin_right = 5
	th.set_stylebox("scroll", "VScrollBar", track)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	th.set_font("font", "Button", font_bold())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", GOLD_HI)
	th.set_color("font_pressed_color", "Button", GOLD_HI)
	th.set_color("font_disabled_color", "Button", DISABLED)
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_color", "CheckBox", TEXT)
	th.set_color("font_hover_color", "CheckBox", GOLD_HI)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("normal_font", "RichTextLabel", font_body())
	th.set_font("bold_font", "RichTextLabel", font_bold())
	th.set_font("italics_font", "RichTextLabel", font_italic())
	return th
