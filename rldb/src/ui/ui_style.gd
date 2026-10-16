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
## Dimmer parchment for subtitles, notes and captions (menu, deck builder).
const TEXT_DIM := Color("a79c88")
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
## "This card can act now" highlight (user feedback 2026-10-16: warm yellow with a soft glow, not green).
## Distinct from TARGET by behaviour: TARGET pulses with a fill, READY is a steady outer glow + chevron badge.
const READY := Color("f5c542")
## Provisional combat-preview stat styling (F02-12): cyan, distinct from committed buff green / debuff red.
const HOVER_GLOW := Color("fff6e4")
const PREVIEW := Color("7fe6ff")
const ZONE_TINT := {"unit": Color("3b2a1a"), "trap": Color("3a1c1c"), "power": Color("1c2a3d")}

const TYPE_COLORS := {
	"Water": Color("3f86d6"), "Fire": Color("d4533a"), "Earth": Color("8f7340"),
	"Lightning": Color("e0bd32"), "Heavenly": Color("f0e4b0"), "Necrotic": Color("7e4fb5"),
	"Physical": Color("98979a"), "": Color("5b5a58"),
}
## Card-kind colours (user decision 2026-10-16): Trap red, Power light blue, Unit brown, Fusion dark blue,
## Ritual purple, Spell green, Arcane grey. Used on card frames, pills, the deck builder and the game log.
const CATEGORY_COLORS := {
	"basic_unit": Color("7a5636"), "unit": Color("8b5a2b"), "spell": Color("2e9e48"),
	"trap": Color("c8352e"), "power": Color("6ec6f0"), "fusion": Color("2747a8"),
	"ritual": Color("8e4fd0"), "arcane": Color("9a9ca3"),
}
const CATEGORY_NAMES := {
	"basic_unit": "Basic Unit", "unit": "Unit", "spell": "Spell", "trap": "Trap", "power": "Power",
	"fusion": "Fusion Unit", "ritual": "Ritual Unit", "arcane": "Arcane Unit",
}
const COST_COLORS := {"ap": Color("f2b544"), "ritual": Color("a874e0"), "arcane": Color("b4b6bc"), "fusion": Color("5a7fe0")}
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


## Cinzel at its default weight, unvaried (menu items and screen titles).
static func font_title() -> Font:
	return _font(FONT_DISPLAY)


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
## Window mode: "windowed", "borderless" (borderless full screen) or "fullscreen" (exclusive).
static var window_mode: String = "windowed"
## 2D anti-aliasing (MSAA) level: 0 off, 2, 4 or 8 samples. Needs the Mobile/Forward renderer; on
## the OpenGL fallback it has no effect (lines and shapes are still drawn anti-aliased).
static var aa_level: int = 8
const AA_LEVELS := [[0, "Off"], [2, "2x"], [4, "4x"], [8, "8x"]]
const WINDOW_MODES := [["windowed", "Windowed"], ["borderless", "Borderless"], ["fullscreen", "Fullscreen"]]
static var _settings_loaded: bool = false


static func load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		reduce_motion = bool(cf.get_value("ui", "reduce_motion", false))
		fast_anim = bool(cf.get_value("ui", "fast_anim", false))
		window_mode = String(cf.get_value("ui", "window_mode", "windowed"))
		aa_level = int(cf.get_value("ui", "aa_level", 8))


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ui", "reduce_motion", reduce_motion)
	cf.set_value("ui", "fast_anim", fast_anim)
	cf.set_value("ui", "window_mode", window_mode)
	cf.set_value("ui", "aa_level", aa_level)
	cf.save(SETTINGS_PATH)


static func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	save_settings()


static func set_fast_anim(on: bool) -> void:
	fast_anim = on
	save_settings()


## Applies and saves the window mode (persisted; applied at start-up by main).
static func set_window_mode(mode: String) -> void:
	window_mode = mode
	save_settings()
	apply_window_mode()


static func apply_window_mode() -> void:
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)   # borderless full screen in Godot 4
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func set_aa_level(n: int) -> void:
	aa_level = n
	save_settings()
	apply_aa()


## Applies the MSAA level to the main window.
static func apply_aa() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var v: Viewport.MSAA = Viewport.MSAA_DISABLED
	match aa_level:
		2: v = Viewport.MSAA_2X
		4: v = Viewport.MSAA_4X
		8: v = Viewport.MSAA_8X
	tree.root.msaa_2d = v


## Display and Anti-aliasing pickers (window mode, MSAA level).
static func display_controls(fs: int) -> Control:
	load_settings()
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	g.add_child(label("Display", fs, TEXT))
	var ob := OptionButton.new()
	for i in WINDOW_MODES.size():
		ob.add_item(WINDOW_MODES[i][1], i)
		if WINDOW_MODES[i][0] == window_mode:
			ob.select(i)
	ob.item_selected.connect(func(i): set_window_mode(WINDOW_MODES[i][0]))
	g.add_child(ob)
	g.add_child(label("Anti-aliasing", fs, TEXT))
	var ab := OptionButton.new()
	for i in AA_LEVELS.size():
		ab.add_item(AA_LEVELS[i][1], i)
		if int(AA_LEVELS[i][0]) == aa_level:
			ab.select(i)
	ab.item_selected.connect(func(i): set_aa_level(int(AA_LEVELS[i][0])))
	g.add_child(ab)
	return g


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


## Title label in the Cinzel display face at its default weight (menu and deck-builder headings).
## Unlike `label(..., display = true)`, which uses the 600-weight variation.
static func title_label(text: String, size: int, color: Color = GOLD) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_title())
	return l


## Full-rect MarginContainer with the same margin on every side (screen-level layouts).
static func full_rect_margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m


static func button(text: String, size: int = 14) -> Button:
	var b := JuicyButton.new()
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
	n.border_width_bottom = 2
	n.border_color = GOLD.darkened(0.35)
	_lift(n, Color(0, 0, 0, 0.5), 4, 2)
	_lift(h, Color(GOLD_HI, 0.45), 9, 0)          # warm glow on hover
	_lift(p, Color(0, 0, 0, 0.45), 2, 1)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ON_GOLD)
	b.add_theme_color_override("font_disabled_color", DISABLED)
	return b


const BACKGROUND := "res://assets/art/background.jpg"   # full 4096x4096 original (a JPEG), kept for 4K screens


## Full-screen background (user-supplied wood table art): scaled to cover the whole rect with the
## overflow cropped, plus an optional dark veil (`dim` 0..1) so cards and text keep their contrast.
const MENU_BACKGROUND := "res://assets/art/menu_background.jpg"   # 4096x4096 forest arch (a JPEG)


static func background(dim: float = 0.0, path: String = BACKGROUND) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # crisp when scaled below 4K
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	if dim > 0.0:
		var veil := ColorRect.new()
		veil.color = Color(0, 0, 0, dim)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(veil)
	return root


## Drop shadow / glow on a button style (depth instead of a flat slab).
static func _lift(sb: StyleBoxFlat, col: Color, sz: int, dy: int) -> void:
	sb.shadow_color = col
	sb.shadow_size = sz
	sb.shadow_offset = Vector2(0, dy)


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


## Card-kind colour lifted for text on the dark log/panel background (dark blue and brown stay legible).
static func category_text_color(cat: String) -> Color:
	var c: Color = CATEGORY_COLORS.get(cat, TEXT)
	return c.lightened(0.45) if c.get_luminance() < 0.3 else c.lightened(0.1)


static func type_color(t) -> Color:
	return TYPE_COLORS.get(t if t != null else "", TYPE_COLORS[""])


## Check box icon (22 px), drawn at 4x and downsampled so its edges are smooth.
static func _check_icon(on: bool) -> ImageTexture:
	var n := 88
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rim := GOLD if on else Color(BRONZE, 1.0).lightened(0.15)
	var fill := Color(0.12, 0.09, 0.04, 1.0) if on else Color(0.05, 0.045, 0.04, 0.95)
	var r := 14.0
	for y in n:
		for x in n:
			# Rounded square: distance to the inner rect.
			var dx := maxf(maxf(8.0 + r - x, x - (n - 8.0 - r)), 0.0)
			var dy := maxf(maxf(8.0 + r - y, y - (n - 8.0 - r)), 0.0)
			var d := sqrt(dx * dx + dy * dy)
			if d <= r:
				img.set_pixel(x, y, rim if d > r - 7.0 else fill)
	if on:
		# Tick: two thick strokes.
		var pts := [Vector2(24, 46), Vector2(39, 61), Vector2(66, 29)]
		for i in 2:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			for y in n:
				for x in n:
					var p := Vector2(x, y)
					var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
					if p.distance_to(a + (b - a) * t) <= 6.5:
						img.set_pixel(x, y, GOLD_HI)
	img.resize(22, 22, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


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
	normal.border_width_bottom = 2
	normal.border_color = BRONZE.darkened(0.25)
	_lift(normal, Color(0, 0, 0, 0.5), 4, 2)
	_lift(hover, Color(GOLD, 0.32), 8, 0)
	_lift(pressed, Color(0, 0, 0, 0.45), 2, 1)
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
	# Card-effect tooltips: near-black panel so the text reads over the board (user feedback).
	var tip := flat(Color(0.035, 0.03, 0.025, 0.97), Color(GOLD, 0.55), 1, 6)
	tip.content_margin_left = 10
	tip.content_margin_right = 10
	tip.content_margin_top = 7
	tip.content_margin_bottom = 7
	tip.shadow_color = Color(0, 0, 0, 0.6)
	tip.shadow_size = 8
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", TEXT)
	th.set_font("font", "TooltipLabel", font_body())
	th.set_font_size("font_size", "TooltipLabel", 15)
	th.set_font("font", "Button", font_bold())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", GOLD_HI)
	th.set_color("font_pressed_color", "Button", GOLD_HI)
	th.set_color("font_disabled_color", "Button", DISABLED)
	th.set_color("font_color", "Label", TEXT)
	# Check boxes: no button frame (it made ticked boxes look like stuck buttons), just a custom
	# gold-rimmed box with a gold tick, and the label beside it.
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 2
		e.content_margin_right = 6
		e.content_margin_top = 3
		e.content_margin_bottom = 3
		th.set_stylebox(st, "CheckBox", e)
	th.set_icon("unchecked", "CheckBox", _check_icon(false))
	th.set_icon("checked", "CheckBox", _check_icon(true))
	th.set_icon("unchecked_disabled", "CheckBox", _check_icon(false))
	th.set_icon("checked_disabled", "CheckBox", _check_icon(true))
	th.set_constant("h_separation", "CheckBox", 10)
	th.set_color("font_color", "CheckBox", TEXT)
	th.set_color("font_pressed_color", "CheckBox", TEXT)
	th.set_color("font_hover_color", "CheckBox", GOLD_HI)
	th.set_color("font_hover_pressed_color", "CheckBox", GOLD_HI)
	th.set_color("font_focus_color", "CheckBox", TEXT)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("normal_font", "RichTextLabel", font_body())
	th.set_font("bold_font", "RichTextLabel", font_bold())
	th.set_font("italics_font", "RichTextLabel", font_italic())
	return th
