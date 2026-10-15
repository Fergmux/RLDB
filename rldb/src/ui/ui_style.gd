class_name UIStyle
extends RefCounted
## Shared colours and small widget factories for the code-built UI.

const BG := Color("161820")
const PANEL := Color("22252f")
const PANEL_LIGHT := Color("2c303c")
const TEXT := Color("e8e6e1")
const MUTED := Color("9aa0ab")
const ACCENT := Color("f2b544")
const GOOD := Color("6fd38a")
const BAD := Color("ff6b6b")
const TARGET := Color("ffd84a")
const SELECT := Color("63b3ff")

const TYPE_COLORS := {
	"Water": Color("3a7bd5"), "Fire": Color("d9534f"), "Earth": Color("9a7442"),
	"Lightning": Color("d8b31f"), "Heavenly": Color("e9dcae"), "Necrotic": Color("7a4bb0"),
	"Physical": Color("8a8f98"), "": Color("4d5260"),
}
const CATEGORY_COLORS := {
	"basic_unit": Color("6b7280"), "unit": Color("9ca3af"), "spell": Color("2e9e64"),
	"trap": Color("b0367a"), "power": Color("c9a23a"), "fusion": Color("8b5cf6"),
	"ritual": Color("3b82f6"), "arcane": Color("14b8a6"),
}
const CATEGORY_NAMES := {
	"basic_unit": "Basic Unit", "unit": "Unit", "spell": "Spell", "trap": "Trap", "power": "Power",
	"fusion": "Fusion Unit", "ritual": "Ritual Unit", "arcane": "Arcane Unit",
}
const COST_COLORS := {"ap": Color("f2b544"), "ritual": Color("5aa2ff"), "arcane": Color("2dd4bf"), "fusion": Color("b794f6")}
const STATUS_SHORT := {
	"retain": "RET", "reveal": "REV", "eternal": "ETR", "burn": "BRN", "pierce": "PRC", "cleanse": "CLN",
	"paralyse": "PAR", "medic": "MED", "curse": "CRS", "poison": "PSN", "infiltrate": "INF", "blind": "BLD",
	"nimble": "NIM", "debilitate": "DEB", "rune": "RUNE",
}


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


static func label(text: String, size: int = 14, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(color, Color.TRANSPARENT, 0, 8))
	return p


static func type_color(t) -> Color:
	return TYPE_COLORS.get(t if t != null else "", TYPE_COLORS[""])


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 14
	var normal := flat(Color("343946"), Color("4a5163"), 1, 6)
	var hover := flat(Color("3f4555"), ACCENT, 1, 6)
	var pressed := flat(Color("2a2f3a"), ACCENT, 1, 6)
	var disabled := flat(Color("262932"), Color("30343f"), 1, 6)
	for s in [normal, hover, pressed, disabled]:
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 5
		s.content_margin_bottom = 5
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_disabled_color", "Button", Color("6b7180"))
	th.set_color("font_color", "Label", TEXT)
	return th
