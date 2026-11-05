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
## Selection (#29): gold filigree corner brackets, the house accent; the cool blue is kept for the
## magic preview only (PREVIEW).
const SELECT := Color("f0cf7a")
## Neutral steel-silver of state chips (stance, protecting), apart from the element colours (#88).
const STATE_STEEL := Color("b4b6bc")
const HOVER := Color("f0cf7a")
## D12: hoverable status words (StatusHelp) are drawn in this lavender and underlined, on dark panels.
const STATUS_LINK := Color("c3a2ff")
## The same hue, darkened for light (parchment) surfaces.
const STATUS_LINK_ON_LIGHT := Color("5e3aa8")
const RUNE_BLUE := Color("5aa2ff")
## "This card can act now" highlight (user feedback 2026-10-16: warm yellow with a soft glow, not green).
## Distinct from TARGET by behaviour: TARGET pulses with a fill, READY is a steady outer glow + chevron badge.
const READY := Color("f5c542")
## Provisional combat-preview stat styling (F02-12): cyan, distinct from committed buff green / debuff red.
const HOVER_GLOW := Color("fff6e4")
const PREVIEW := Color("7fe6ff")
## Material grain strengths (UiSurface): panels and plates (leather), buttons (brushed metal),
## screen backdrops (wood) and the px one backdrop tile spans.
const PANEL_GRAIN := 0.55
const BUTTON_GRAIN := 0.24
## Bright gold faces show the grain more strongly: a lighter touch there.
const GOLD_GRAIN := 0.07
## Soft top light on buttons (polished metal, user feedback 2026-10-18); halved while pressed.
const BUTTON_SHEEN := 0.1
const BACKDROP_GRAIN := 0.85
const BACKDROP_TILE := 640.0
const ZONE_TINT := {"unit": Color("3b2a1a"), "trap": Color("3a1c1c"), "power": Color("1c2a3d")}

const TYPE_COLORS := {
	"Water": Color("3f86d6"), "Fire": Color("d4533a"), "Earth": Color("5fae3c"),
	"Lightning": Color("e0bd32"), "Light": Color("f0e4b0"), "Dark": Color("7e4fb5"),
	"Physical": Color("98979a"), "": Color("5b5a58"),
}
## Card-kind colours (user decision 2026-10-16): Trap red, Power light blue, Unit brown, Fusion dark blue,
## Ritual purple, Spell green, Arcane grey. Used on card frames, pills, the deck builder and the game log.
const CATEGORY_COLORS := {
	"basic_unit": Color("7a5636"), "unit": Color("8b5a2b"), "spell": Color("2e9e48"),
	"trap": Color("c8352e"), "power": Color("6ec6f0"), "fusion": Color("2747a8"),
	"ritual": Color("8e4fd0"), "arcane": Color("9a9ca3"),
	"extra": Color("2747a8"),
}
const CATEGORY_NAMES := {
	"basic_unit": "Basic Unit", "unit": "Unit", "spell": "Spell", "trap": "Trap", "power": "Power",
	"fusion": "Fusion Unit", "ritual": "Ritual Unit", "arcane": "Arcane Unit",
	"extra": "Extra Deck",       # F03-11: the combined Fusion/Ritual/Arcane reward and draft group
}
const COST_COLORS := {"ap": Color("f2b544"), "ritual": Color("a874e0"), "arcane": Color("b4b6bc"), "fusion": Color("5a7fe0")}
const STATUS_SHORT := {
	"retain": "RET", "reveal": "REV", "eternal": "ETR", "burn": "BRN", "pierce": "PRC", "cleanse": "CLN",
	"paralyse": "PAR", "medic": "MED", "curse": "CRS", "poison": "PSN", "infiltrate": "INF", "blind": "BLD",
	"nimble": "NIM", "debilitate": "DEB", "rune": "RUNE",
}

# ---- fonts ----
## L10 (owner, 5 Nov: "no default Arial looking font in the game"): every face is a FontVariation
## resource over the bundled TTF with a themed fallback chain, so no glyph is ever drawn in a system
## font. Alegreya Sans (body) falls back to Noto Sans Symbols 2 for UI symbols (check mark, bullet,
## menu bars); Cinzel (display) falls back to Alegreya Sans (arrows, rare punctuation), then to the
## symbols. The same body face is the project-wide default (project.godot gui/theme/custom_font and
## the base theme assets/themes/base_theme.tres), so text outside the game theme is themed too.
const FONT_BODY := "res://assets/fonts/body_regular.tres"
const FONT_BOLD := "res://assets/fonts/body_bold.tres"
const FONT_ITALIC := "res://assets/fonts/body_italic.tres"
const FONT_BOLD_ITALIC := "res://assets/fonts/body_bold_italic.tres"
const FONT_DISPLAY := "res://assets/fonts/display.tres"
## The project-wide base theme (fonts only; colours and boxes come from make_theme()).
const BASE_THEME := "res://assets/themes/base_theme.tres"
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


## Alegreya Sans Bold Italic (RichTextLabel [b][i]).
static func font_bold_italic() -> Font:
	return _font(FONT_BOLD_ITALIC)


## True when `font` or one of its fallbacks (FontVariation bases and fallback chains, followed
## recursively) has a glyph for code point `ch`, so it never falls through to a system font.
static func font_covers(font: Font, ch: int, _depth: int = 0) -> bool:
	if font == null or _depth > 8:
		return false
	if font is FontFile and (font as FontFile).has_char(ch):
		return true
	if font is FontVariation:
		var fv := font as FontVariation
		if fv.base_font != null and font_covers(fv.base_font, ch, _depth + 1):
			return true
		if fv.fallbacks.is_empty() and fv.base_font != null:
			for fb in fv.base_font.fallbacks:
				if font_covers(fb, ch, _depth + 1):
					return true
	for fb in font.fallbacks:
		if font_covers(fb, ch, _depth + 1):
			return true
	return false


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
## Window mode used until the player picks one in Settings.
const DEFAULT_WINDOW_MODE := "fullscreen"
## Window mode: "windowed", "borderless" (borderless full screen) or "fullscreen" (exclusive).
static var window_mode: String = DEFAULT_WINDOW_MODE
## 2D anti-aliasing (MSAA) level: 0 off, 2, 4 or 8 samples, applied to the root viewport's `msaa_2d`
## (the whole game is 2D Controls drawn into the root viewport; there are no SubViewports and no 3D).
## Needs the Forward+/Mobile renderer (D3D12 / Vulkan); on the OpenGL fallback it has no effect (lines
## and shapes are still drawn anti-aliased). F13: the default is 4x, mirrored by the project setting
## rendering/anti_aliasing/quality/msaa_2d so the first frames before apply_aa() match.
const DEFAULT_AA := 4
## The default before F13. A legacy settings file always wrote aa_level, so a saved 8 without
## aa_explicit is the old default rather than a choice (choosing the selected item fires no signal).
const LEGACY_DEFAULT_AA := 8
static var aa_level: int = DEFAULT_AA
## True once the player picked a level in Settings (persisted as ui/aa_explicit).
static var aa_explicit: bool = false
const AA_LEVELS := [[0, "Off"], [2, "2x"], [4, "4x"], [8, "8x"]]
const WINDOW_MODES := [["windowed", "Windowed"], ["borderless", "Borderless"], ["fullscreen", "Fullscreen"]]
static var _settings_loaded: bool = false


## Loads the persisted UI settings once (later calls are no-ops).
static func load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		reduce_motion = bool(cf.get_value("ui", "reduce_motion", false))
		fast_anim = bool(cf.get_value("ui", "fast_anim", false))
		window_mode = String(cf.get_value("ui", "window_mode", DEFAULT_WINDOW_MODE))
		var aa := aa_from(cf)
		aa_level = aa[0]
		aa_explicit = aa[1]


## F13: the MSAA level a settings file asks for, as [level, explicit]. An explicit choice is kept; a
## legacy file (no ui/aa_explicit) keeps any level other than the old default 8, which was never a
## choice and becomes DEFAULT_AA. Unknown values fall back to DEFAULT_AA.
static func aa_from(cf: ConfigFile) -> Array:
	if not cf.has_section_key("ui", "aa_level"):
		return [DEFAULT_AA, false]
	var lv := int(cf.get_value("ui", "aa_level", DEFAULT_AA))
	var known := false
	for e in AA_LEVELS:
		if int(e[0]) == lv:
			known = true
	if not known:
		return [DEFAULT_AA, false]
	if bool(cf.get_value("ui", "aa_explicit", false)):
		return [lv, true]
	if lv == LEGACY_DEFAULT_AA:
		return [DEFAULT_AA, false]
	return [lv, true]


## Writes the UI settings to SETTINGS_PATH.
static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)   # keep other sections (e.g. [progress])
	cf.set_value("ui", "reduce_motion", reduce_motion)
	cf.set_value("ui", "fast_anim", fast_anim)
	cf.set_value("ui", "window_mode", window_mode)
	cf.set_value("ui", "aa_level", aa_level)
	cf.set_value("ui", "aa_explicit", aa_explicit)
	cf.save(SETTINGS_PATH)


## Sets and saves the "reduced motion" option.
static func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	save_settings()


## Sets and saves the "fast animations" option.
static func set_fast_anim(on: bool) -> void:
	fast_anim = on
	save_settings()


## Applies and saves the window mode (persisted; applied at start-up by main).
static func set_window_mode(mode: String) -> void:
	window_mode = mode
	save_settings()
	apply_window_mode()


## Applies `window_mode` to the main window.
static func apply_window_mode() -> void:
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)   # borderless full screen in Godot 4
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Sets, saves and applies the MSAA level (0, 2, 4 or 8).
static func set_aa_level(n: int) -> void:
	aa_level = n
	aa_explicit = true
	save_settings()
	apply_aa()


## Applies the MSAA level to the main window (the root viewport, where the whole game is drawn).
static func apply_aa() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	load_settings()
	tree.root.msaa_2d = msaa_for(aa_level)


## The Viewport MSAA mode for a level of AA_LEVELS (0, 2, 4, 8).
static func msaa_for(level: int) -> Viewport.MSAA:
	match level:
		2: return Viewport.MSAA_2X
		4: return Viewport.MSAA_4X
		8: return Viewport.MSAA_8X
	return Viewport.MSAA_DISABLED


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


# ---- spacing scale (design review 1.4.2, D5): one 4 px base unit ----
## Spacing tokens in layout px at 1600x900. Margins are written with these names, never as numbers.
const SPACE := {"xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24, "xxl": 32, "xxxl": 48}
## Screen safe margins: HUD elements (Menu button, plates, sidebar) and full-page screens.
const SAFE_HUD := 24
const SAFE_PAGE := 32
## Content never sits closer than this to a frame line, a scrollbar or a filigree corner.
const CONTENT_FLOOR := 12


## The px of spacing token `token` ("xs" .. "xxxl"). An unknown token is a programming error: it
## asserts in debug builds and falls back to "md".
static func sp(token: String) -> int:
	assert(SPACE.has(token), "unknown spacing token '%s'" % token)
	return int(SPACE.get(token, SPACE["md"]))


## Sets the padding of `target` from spacing tokens: `token` on every side, or `token`
## horizontally and `v_token` vertically. `target` is a StyleBox (content margins; a SurfaceBox or
## DepthBox also pads the flat box inside it), a MarginContainer (its margin constants), a
## GridContainer (h / v separation) or a BoxContainer (separation, from `token`). Returns `target`.
static func pad(target: Object, token: String, v_token: String = "") -> Object:
	var h := sp(token)
	var v := sp(v_token) if v_token != "" else h
	if target is StyleBox:
		var sb := target as StyleBox
		sb.content_margin_left = h
		sb.content_margin_right = h
		sb.content_margin_top = v
		sb.content_margin_bottom = v
		if sb is UiSurface.SurfaceBox and (sb as UiSurface.SurfaceBox).flat != null:
			pad((sb as UiSurface.SurfaceBox).flat, token, v_token)
		elif sb is DepthBox and (sb as DepthBox).base != null:
			pad((sb as DepthBox).base, token, v_token)
	elif target is MarginContainer:
		var m := target as MarginContainer
		m.add_theme_constant_override("margin_left", h)
		m.add_theme_constant_override("margin_right", h)
		m.add_theme_constant_override("margin_top", v)
		m.add_theme_constant_override("margin_bottom", v)
	elif target is GridContainer:
		(target as Control).add_theme_constant_override("h_separation", h)
		(target as Control).add_theme_constant_override("v_separation", v)
	elif target is BoxContainer:
		(target as Control).add_theme_constant_override("separation", h)
	return target


## A MarginContainer padded with `token` (and `v_token` vertically).
static func margin(token: String, v_token: String = "") -> MarginContainer:
	var m := MarginContainer.new()
	pad(m, token, v_token)
	return m


# ---- depth (design review 1.3): one warm light from above, five levels ----
const DEPTH_TABLE := 0
const DEPTH_PLATE := 1
const DEPTH_RAISED := 2
const DEPTH_FLOATING := 3
const DEPTH_MODAL := 4
## Drop shadow of each depth level: [offset y, blur px, colour].
const DEPTH := [
	[0, 0, Color(0, 0, 0, 0.0)],
	[3, 8, Color(0, 0, 0, 0.5)],
	[4, 10, Color(0, 0, 0, 0.55)],
	[10, 24, Color(0, 0, 0, 0.6)],
	[16, 40, Color(0, 0, 0, 0.7)],
]
## Depth 3 adds a faint gold top rim; depth 4 frames add a gold outer glow of their own.
const DEPTH_FLOAT_RIM := Color(0.941, 0.812, 0.478, 0.15)
const DEPTH_MODAL_GLOW := Color(0.831, 0.651, 0.29, 0.35)
const DEPTH_MODAL_GLOW_PX := 12


## Gives `sb` the drop shadow of depth level `depth` (DEPTH_TABLE .. DEPTH_MODAL, clamped) and
## returns it. Level 3 also lights a borderless box's top edge with DEPTH_FLOAT_RIM.
static func lift(sb: StyleBoxFlat, depth: int) -> StyleBoxFlat:
	var d: Array = DEPTH[clampi(depth, 0, DEPTH.size() - 1)]
	lift_style(sb, d[2], int(d[1]), int(d[0]))
	if depth == DEPTH_FLOATING and sb.border_width_top == 0 and sb.border_width_left == 0:
		sb.border_width_top = 1
		sb.border_color = DEPTH_FLOAT_RIM
	return sb


# ---- motion vocabulary (design review 1.4.5) ----
## Motion tokens: [duration s (before dur()), transition, ease].
const MOTION := {
	"tick": [0.08, Tween.TRANS_SINE, Tween.EASE_OUT],
	"hover": [0.12, Tween.TRANS_QUAD, Tween.EASE_OUT],
	"hover_out": [0.18, Tween.TRANS_QUAD, Tween.EASE_OUT],
	"press": [0.06, Tween.TRANS_QUAD, Tween.EASE_OUT],
	"press_back": [0.14, Tween.TRANS_BACK, Tween.EASE_OUT],
	"panel_in": [0.26, Tween.TRANS_BACK, Tween.EASE_OUT],
	"tooltip_in": [0.14, Tween.TRANS_QUAD, Tween.EASE_OUT],
	"panel_out": [0.16, Tween.TRANS_QUAD, Tween.EASE_IN],
	"slide": [0.32, Tween.TRANS_QUART, Tween.EASE_OUT],
	"crossfade": [0.18, Tween.TRANS_SINE, Tween.EASE_IN_OUT],
	"card_move": [0.38, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT],
	"hit_stop": [0.09, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT],
	"impact": [0.22, Tween.TRANS_ELASTIC, Tween.EASE_OUT],
	"count": [0.4, Tween.TRANS_QUART, Tween.EASE_OUT],
	"stagger": [0.04, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT],
	"breathe": [2.4, Tween.TRANS_SINE, Tween.EASE_IN_OUT],
	"sweep": [0.9, Tween.TRANS_SINE, Tween.EASE_IN_OUT],
	"celebrate": [1.2, Tween.TRANS_BACK, Tween.EASE_OUT],
	"reduced": [0.12, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT],
}
## Specular sweep repeat period (s) and the idle breathing amplitude (+/- brightness).
const SWEEP_PERIOD := 6.0
const BREATHE_AMP := 0.08
## panel_in: start scale and rise (px).
const PANEL_IN_SCALE := 0.94
const PANEL_IN_RISE := 12.0


## Duration (s) of motion token `name`, scaled by the fast-animations option.
static func motion(name: String) -> float:
	assert(MOTION.has(name), "unknown motion token '%s'" % name)
	return dur(float((MOTION.get(name, MOTION["hover"]) as Array)[0]))


## Tweens `obj`.`prop` to `value` on `tw` with motion token `name` (its duration, transition, ease).
static func tween_token(tw: Tween, obj: Object, prop: NodePath, value: Variant, name: String) -> PropertyTweener:
	var m: Array = MOTION.get(name, MOTION["hover"])
	return tw.tween_property(obj, prop, value, motion(name)).set_trans(m[1]).set_ease(m[2])


## A fresh tween on `node`, kept in its metadata under `key`; the tween kept there before (a hover
## still easing in, say) is killed first, so two eases of one property never fight.
static func restart_tween(node: Node, key: StringName) -> Tween:
	if node.has_meta(key):
		var old = node.get_meta(key)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := node.create_tween()
	node.set_meta(key, tw)
	return tw


## 1 +/- `amp` on the `breathe` sine at clock time `t` (s), for idle glows and pulsing rims;
## exactly 1 under reduce motion (one static state).
static func breathe(t: float, amp: float = BREATHE_AMP, period: float = 2.4) -> float:
	if reduce_motion:
		return 1.0
	return 1.0 + amp * sin(t / maxf(period, 0.001) * TAU)


## Opening motion of a modal or panel (`panel_in`: alpha 0 -> 1, scale 0.94 -> 1 with a BACK
## overshoot, rising 12 px) or of a tooltip (`tooltip_in`: 140 ms, no overshoot, no rise). Under
## reduce motion it is a 120 ms fade. The rise is skipped inside a Container (it owns the position).
## Returns the tween, or null when `node` is not in the tree (it is then left at rest).
static func tween_in(node: Control, name: String = "panel_in") -> Tween:
	node.modulate.a = 1.0
	node.scale = Vector2.ONE
	if not node.is_inside_tree():
		return null
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	node.modulate.a = 0.0
	if reduce_motion:
		tw.tween_property(node, "modulate:a", 1.0, motion("reduced"))
		return tw
	tw.set_parallel(true)
	tween_token(tw, node, "modulate:a", 1.0, "tooltip_in" if name == "tooltip_in" else "hover")
	if name == "tooltip_in":
		node.scale = Vector2(0.97, 0.97)
		tween_token(tw, node, "scale", Vector2.ONE, name)
		return tw
	node.scale = Vector2(PANEL_IN_SCALE, PANEL_IN_SCALE)
	tween_token(tw, node, "scale", Vector2.ONE, "panel_in")
	if not (node.get_parent() is Container):
		var rest := node.position
		node.position = rest + Vector2(0, PANEL_IN_RISE)
		tween_token(tw, node, "position", rest, "panel_in")
	return tw


## Closing motion (`panel_out`: alpha to 0 and scale to 0.97; a 120 ms fade under reduce motion),
## then hides `node`, or frees it with `free_after`. Returns the tween (null when not in the tree:
## the node is then hidden or freed at once).
static func tween_out(node: Control, free_after: bool = false) -> Tween:
	if not node.is_inside_tree():
		if free_after:
			node.queue_free()
		else:
			node.visible = false
		return null
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	if reduce_motion:
		tw.tween_property(node, "modulate:a", 0.0, motion("reduced"))
	else:
		tw.set_parallel(true)
		tween_token(tw, node, "modulate:a", 0.0, "panel_out")
		tween_token(tw, node, "scale", Vector2(0.97, 0.97), "panel_out")
	tw.chain().tween_callback(node.queue_free if free_after else node.hide)
	return tw


# ---- factories ----
## Flat rounded StyleBox with an optional border and small content margins.
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


## Label at `size` px in `color`; `wrap` word-wraps, `display` uses Cinzel 600.
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


## The game's standard (JuicyButton) button in the bold body face, in the theme's Secondary
## (bronze-iron) family. Same as secondary_button().
static func button(text: String, size: int = 14) -> Button:
	var b := JuicyButton.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_bold())
	b.focus_mode = Control.FOCUS_NONE
	b.hover_inner_glow = SECONDARY_INNER_GLOW
	return b


# ---- button families (design review 1.4.4) ----
## Button heights (px): small, standard and the hero call to action; minimum width and the
## horizontal padding of a sized button.
const BUTTON_H := {"small": 36, "standard": 44, "hero": 52}
const BUTTON_MIN_W := 120
const BUTTON_PAD_X := 20
## Horizontal text padding of every family (unsized buttons; the md token, its 16 px floor).
const BUTTON_TEXT_PAD := 16
## Secondary (bronze-iron) face: the middle of the #2b2724 -> #1d1a18 gradient (the sheen supplies
## the top light), its border and hover state.
const IRON := Color("252220")
const SECONDARY_INNER_GLOW := Color(0.831, 0.651, 0.29, 0.2)
## Danger (ember) face and edges.
const EMBER := Color("4a1714")
const EMBER_EDGE := Color(0.91, 0.376, 0.353, 0.7)
const EMBER_EDGE_HI := Color("ff8a7a")
const EMBER_TEXT := Color("ffd8d2")
const EMBER_INNER_GLOW := Color(0.91, 0.376, 0.353, 0.16)
## Disabled (every family): readable label on a plain slate plate with no shadow and no grain.
const DISABLED_EDGE := Color("3a342c")
## Keyboard focus ring: 2 px GOLD_HI, 3 px outside the button, pulsing on the breathe loop.
const FOCUS_RING := GOLD_HI
const FOCUS_RING_GAP := 3.0
const FOCUS_RING_W := 2.0


## The four state boxes of button family `family` ("primary", "secondary", "danger", "steel", "wine"):
## {normal, hover, pressed, disabled} as StyleBoxes (grain and sheen on all but disabled).
## Pressed sits 1 px lower (content margins) with a short shadow; hover glows per family.
static func button_styles(family: String) -> Dictionary:
	var face: Color
	var edge: Color
	var foot: Color
	var hover_face: Color
	var hover_edge: Color
	var hover_glow := Color(0, 0, 0, 0)
	var hover_glow_px := 0
	var grain_name := UiSurface.METAL
	var grain := BUTTON_GRAIN
	match family:
		"primary":
			face = GOLD
			edge = GOLD_HI
			foot = GOLD.darkened(0.35)
			hover_face = GOLD_HI
			hover_edge = Color.WHITE
			hover_glow = Color(GOLD_HI, 0.45)
			hover_glow_px = 9
			grain = GOLD_GRAIN
		"danger":
			face = EMBER
			edge = EMBER_EDGE
			foot = EMBER.darkened(0.45)
			hover_face = EMBER.lightened(0.08)
			hover_edge = EMBER_EDGE_HI
			hover_glow = Color(BAD, 0.4)
			hover_glow_px = 8
			grain_name = UiSurface.LEATHER
			grain = PANEL_GRAIN
		"steel":   # the Defense answer (#34): cool steel-silver plate
			face = Color("23272d")
			edge = Color(STATE_STEEL, 0.7)
			foot = Color("23272d").darkened(0.45)
			hover_face = Color("2a2f36")
			hover_edge = STATE_STEEL.lightened(0.2)
			hover_glow = Color(STATE_STEEL, 0.35)
			hover_glow_px = 8
		"wine":
			face = WINE
			edge = WINE_EDGE.darkened(0.15)
			foot = WINE_EDGE.darkened(0.15)
			hover_face = WINE.lightened(0.1)
			hover_edge = WINE_EDGE.lightened(0.35)
			hover_glow = Color(WINE_EDGE, 0.4)
			hover_glow_px = 8
			grain_name = UiSurface.LEATHER
			grain = PANEL_GRAIN
		_:   # secondary
			face = IRON
			edge = BRONZE
			foot = BRONZE.darkened(0.35)
			hover_face = IRON.lightened(0.05)
			hover_edge = Color(GOLD, 0.9)
	var n := flat(face, edge, 1, 6)
	n.border_width_bottom = 2
	var h := flat(hover_face, hover_edge, 1, 6)
	h.border_width_bottom = 2
	var p := flat(face.darkened(0.15), edge, 1, 6)
	var d := flat(PANEL, DISABLED_EDGE, 1, 6)
	for s in [n, h, p, d]:
		s.content_margin_left = BUTTON_TEXT_PAD
		s.content_margin_right = BUTTON_TEXT_PAD
		s.content_margin_top = 5
		s.content_margin_bottom = 5
	p.content_margin_top = 6
	p.content_margin_bottom = 4
	# StyleBoxFlat has one border colour: the gold face takes the darker foot all round (its 2 px
	# bottom reads as the bevel), the dark faces keep their edge colour.
	n.border_color = foot if family == "primary" else edge
	lift(n, DEPTH_RAISED)
	if hover_glow.a > 0.0:
		lift_style(h, hover_glow, hover_glow_px, 0)
	else:
		lift(h, DEPTH_RAISED)
	lift_style(p, Color(0, 0, 0, 0.45), 2, 1)
	return {
		"normal": UiSurface.box(n, grain_name, grain, BUTTON_SHEEN),
		"hover": UiSurface.box(h, grain_name, grain, BUTTON_SHEEN),
		"pressed": UiSurface.box(p, grain_name, grain, BUTTON_SHEEN * 0.5),
		"disabled": d,
	}


## Applies family `family` to button `b` (styles, label colours, the click family and the inner
## hover glow). The Secondary family is also the theme default of every plain Button.
static func style_button(b: Button, family: String) -> Button:
	var st := button_styles(family)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_stylebox_override("hover_pressed", st["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())   # JuicyButton draws the ring
	var text_col := TEXT
	var hover_col := GOLD_HI
	match family:
		"primary":
			text_col = ON_GOLD
			hover_col = ON_GOLD
		"danger":
			text_col = EMBER_TEXT
			hover_col = Color.WHITE
		"wine":
			text_col = Color("e2c9c3")
			hover_col = TEXT
		"steel":
			text_col = Color("e6e9ee")
			hover_col = Color.WHITE
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_hover_color", hover_col)
	b.add_theme_color_override("font_pressed_color", hover_col)
	b.add_theme_color_override("font_hover_pressed_color", hover_col)
	b.add_theme_color_override("font_disabled_color", DISABLED)
	b.set_meta(Sfx.FAMILY_META, family)
	if b is JuicyButton:
		var jb := b as JuicyButton
		match family:
			"secondary":
				jb.hover_inner_glow = SECONDARY_INNER_GLOW
			"danger":
				jb.hover_inner_glow = EMBER_INNER_GLOW
			_:
				jb.hover_inner_glow = Color(0, 0, 0, 0)
	return b


## Sizes `b` to button size `kind` ("small" 36, "standard" 44, "hero" 52 px high), at least
## BUTTON_MIN_W wide, with BUTTON_PAD_X of horizontal text padding. Returns `b`.
static func size_button(b: Button, kind: String = "standard") -> Button:
	var h := int(BUTTON_H.get(kind, BUTTON_H["standard"]))
	b.custom_minimum_size = Vector2(maxf(b.custom_minimum_size.x, BUTTON_MIN_W), maxf(b.custom_minimum_size.y, h))
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		if b.has_theme_stylebox_override(st):
			var sb := b.get_theme_stylebox(st)
			sb.content_margin_left = maxf(sb.content_margin_left, BUTTON_PAD_X)
			sb.content_margin_right = maxf(sb.content_margin_right, BUTTON_PAD_X)
	return b


## Gold-filled primary action button (exactly one per view).
static func primary_button(text: String, size: int = 15) -> Button:
	return style_button(button(text, size), "primary")


## Bronze-iron secondary button (Cancel, Close, Back, every non-primary action). Holds default
## focus in a destructive confirmation.
static func secondary_button(text: String, size: int = 15) -> Button:
	return style_button(button(text, size), "secondary")


## Ember danger button for destructive confirms (Concede, Delete deck, Quit to desktop, Remove).
static func danger_button(text: String, size: int = 15) -> Button:
	return style_button(button(text, size), "danger")


## Face of a "stand down" button (D13 Skip for the rest of this turn): deep wine leather.
const WINE := Color("3b1d22")
const WINE_EDGE := Color("8a4b4f")


## A secondary, "stand down" button (D13): deep wine leather with a rose-bronze edge and muted
## text, clearly apart from the gold primary and the iron secondary. Hover warms the edge and
## brightens the text.
static func wine_button(text: String, size: int = 14) -> Button:
	return style_button(button(text, size), "wine")


const BACKGROUND := "res://assets/art/background.jpg"   # full 4096x4096 original (a JPEG), kept for 4K screens


## Full-screen background (user-supplied wood table art): scaled to cover the whole rect with the
## overflow cropped, plus an optional dark veil (`dim` 0..1) so cards and text keep their contrast.
const MENU_BACKGROUND := "res://assets/art/menu_background.jpg"   # 4096x4096 forest arch (a JPEG)


## Loaded background textures, kept for the whole run: a screen change (back to the menu after
## a duel) never depends on reloading a 4096x4096 image (playtest feedback 08, G10).
static var _backgrounds := {}


## The texture at `path`, loaded once; a failed load is retried on the next call.
static func background_texture(path: String) -> Texture2D:
	var t: Texture2D = _backgrounds.get(path)
	if t == null:
		t = load(path) as Texture2D
		if t == null:
			push_warning("Background image could not be loaded: %s" % path)
		else:
			_backgrounds[path] = t
	return t


static func background(dim: float = 0.0, path: String = BACKGROUND) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = background_texture(path)
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
static func lift_style(sb: StyleBoxFlat, col: Color, sz: int, dy: int) -> void:
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


## PanelContainer with `panel_style(color)` and a leather grain.
static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSurface.box(panel_style(color), UiSurface.LEATHER, PANEL_GRAIN))
	return p


## Card-kind colour lifted for text on the dark log/panel background (dark blue and brown stay legible).
static func category_text_color(cat: String) -> Color:
	var c: Color = CATEGORY_COLORS.get(cat, TEXT)
	return c.lightened(0.45) if c.get_luminance() < 0.3 else c.lightened(0.1)


## Colour of element type `t` (null or unknown -> neutral grey).
static func type_color(t) -> Color:
	return TYPE_COLORS.get(t if t != null else "", TYPE_COLORS[""])


# ---- F3 inset wells and F4 chips (design review 1.4.3) ----
## F3 inset: the ink well, its engraved edge (dark top / left, faint gold bottom / right) and the
## inner shadow (0 2 6 #000 60%).
const INSET_DARK := Color(0, 0, 0, 0.7)
const INSET_LIGHT := Color(0.831, 0.651, 0.29, 0.12)
const INSET_SHADOW_PX := 6.0
const INSET_SHADOW_A := 0.6
## F4 chip: the colour's share of the fill over ink, its border alpha and the top highlight.
const CHIP_FILL_A := 0.22
const CHIP_EDGE_A := 0.7
const CHIP_HIGHLIGHT := Color(1, 1, 1, 0.1)


## F3 inset well style: PANEL_INK (or `fill`), engraved edges, an inner shadow from the top edge
## and `grain` leather (0.25 for the log). Padding: the md token (12 px). Sits inside an F1 / F2
## frame, never directly on the table.
static func inset_style(fill: Color = PANEL_INK, radius: int = 6, grain: float = 0.0) -> DepthBox:
	var base := flat(fill, Color(0, 0, 0, 0), 0, radius)
	pad(base, "md")
	var d := DepthBox.new()
	d.base = base
	d.engrave_dark = INSET_DARK
	d.engrave_light = INSET_LIGHT
	d.inner_shadow_px = INSET_SHADOW_PX
	d.inner_shadow_a = INSET_SHADOW_A
	d.grain = grain
	return d


## F4 chip / pill / tag style in colour `col`: the colour at 22% over ink, a 1 px border at 70%,
## a 1 px white top highlight at 10% and a 4 px top-lit gradient. Padding sm / xs.
static func chip_style(col: Color, radius: int = 6) -> DepthBox:
	var fill := PANEL_INK.lerp(Color(col, 1.0), CHIP_FILL_A)
	var base := flat(fill, Color(col, CHIP_EDGE_A * col.a), 1, radius)
	pad(base, "sm", "xs")
	var d := DepthBox.new()
	d.base = base
	d.top_highlight = CHIP_HIGHLIGHT
	d.top_band = Color(col.lightened(0.3), 0.18)
	d.top_band_px = 4.0
	return d


## An F3 inset PanelContainer (text wells, log, stat boxes, input fields).
static func inset(fill: Color = PANEL_INK, grain: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", inset_style(fill, 6, grain))
	return p


## An F4 chip: `text` at `size` px (bold body face) in a light tint of `col`, on chip_style(col).
static func chip(text: String, col: Color, size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip_style(col))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, col.lightened(0.45))
	l.add_theme_font_override("font", font_bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# ---- scroll bars (design review #105, 1.4.2) ----
## Track width, thumb width and the gap between scrolled content and the track (px).
const SCROLL_TRACK_W := 8
const SCROLL_THUMB_W := 6
const SCROLL_CONTENT_GAP := 12


## Puts the house scroll bars on theme `th`: an 8 px engraved ink track (F3) with a 6 px gold thumb
## that brightens on hover and lights on press, and the 12 px content-to-track gap. Returns `th`.
static func apply_scrollbar_theme(th: Theme) -> Theme:
	var track := inset_style(Color(0.02, 0.016, 0.012, 0.85), 4)
	track.inner_shadow_px = 3.0
	track.base.content_margin_left = SCROLL_TRACK_W / 2.0
	track.base.content_margin_right = SCROLL_TRACK_W / 2.0
	track.base.content_margin_top = 2
	track.base.content_margin_bottom = 2
	track.base = track.base   # re-sync the DepthBox's own margins
	var side := (SCROLL_TRACK_W - SCROLL_THUMB_W) / 2
	var thumbs := []
	for c in [Color(GOLD, 0.62), Color(GOLD_HI, 0.95), GOLD_HI.lightened(0.25)]:
		var g := flat(c, Color(0, 0, 0, 0), 0, 3)
		g.border_width_left = side
		g.border_width_right = side
		g.border_color = Color(0, 0, 0, 0)
		g.border_blend = false
		g.content_margin_left = SCROLL_THUMB_W / 2.0
		g.content_margin_right = SCROLL_THUMB_W / 2.0
		g.content_margin_top = 12
		g.content_margin_bottom = 12
		thumbs.append(g)
	th.set_stylebox("scroll", "VScrollBar", track)
	th.set_stylebox("scroll_focus", "VScrollBar", track)
	th.set_stylebox("grabber", "VScrollBar", thumbs[0])
	th.set_stylebox("grabber_highlight", "VScrollBar", thumbs[1])
	th.set_stylebox("grabber_pressed", "VScrollBar", thumbs[2])
	th.set_constant("scrollbar_v_separation", "ScrollContainer", SCROLL_CONTENT_GAP)
	return th


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


## Builds the game-wide Theme (buttons, scrollbars, tooltips, check boxes, labels).
static func make_theme() -> Theme:
	load_settings()
	var th := Theme.new()
	th.default_font = font_body()
	th.default_font_size = 14
	# Every plain Button is the Secondary (bronze-iron) family, brushed-metal grain (UiSurface).
	var bs := button_styles("secondary")
	for k in bs:
		th.set_stylebox(k, "Button", bs[k])
	th.set_stylebox("hover_pressed", "Button", bs["pressed"])
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())   # JuicyButton draws the focus ring
	# Scroll bars: an 8 px engraved ink track with a 6 px gold thumb that brightens on hover (#105).
	apply_scrollbar_theme(th)
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
	# L10: [b][i] and [code] stay in the house face too (the engine default was a faux-bold sans).
	th.set_font("bold_italics_font", "RichTextLabel", font_bold_italic())
	th.set_font("mono_font", "RichTextLabel", font_body())
	apply_popup_theme(th)
	return th


## Popup list rows: inner padding, row gap and the marker size (px).
const POPUP_PAD := Vector2(10, 6)
const POPUP_ROW_GAP := 6
const POPUP_FONT := 15
const POPUP_MARK := 14


## L10 (extra): dropdown lists (OptionButton / PopupMenu) in the house style instead of the engine's
## grey box: an ink panel with a bronze rim and a soft shadow, a faint gold hover band, body text at
## 15 px, and a small gold diamond marking the chosen item. Returns `th`.
static func apply_popup_theme(th: Theme) -> Theme:
	var panel_sb := flat(Color(0.045, 0.038, 0.03, 0.98), Color(BRONZE, 0.95), 1, 6)
	panel_sb.content_margin_left = POPUP_PAD.x / 2.0
	panel_sb.content_margin_right = POPUP_PAD.x / 2.0
	panel_sb.content_margin_top = POPUP_PAD.y
	panel_sb.content_margin_bottom = POPUP_PAD.y
	lift(panel_sb, DEPTH_FLOATING)
	panel_sb.border_color = Color(BRONZE, 0.95)
	th.set_stylebox("panel", "PopupMenu", panel_sb)
	var hover := flat(Color(GOLD, 0.14), Color(GOLD, 0.35), 1, 4)
	th.set_stylebox("hover", "PopupMenu", hover)
	var sep := StyleBoxLine.new()
	sep.color = Color(BRONZE, 0.6)
	sep.thickness = 1
	th.set_stylebox("separator", "PopupMenu", sep)
	th.set_font("font", "PopupMenu", font_body())
	th.set_font_size("font_size", "PopupMenu", POPUP_FONT)
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", GOLD_HI)
	th.set_color("font_disabled_color", "PopupMenu", DISABLED)
	th.set_color("font_accelerator_color", "PopupMenu", TEXT_DIM)
	th.set_color("font_separator_color", "PopupMenu", GOLD)
	th.set_constant("v_separation", "PopupMenu", POPUP_ROW_GAP)
	th.set_constant("h_separation", "PopupMenu", 8)
	th.set_constant("item_start_padding", "PopupMenu", int(POPUP_PAD.x))
	th.set_constant("item_end_padding", "PopupMenu", int(POPUP_PAD.x) + 6)
	var on := _marker_icon(true)
	var off := _marker_icon(false)
	for k in ["radio_checked", "checked"]:
		th.set_icon(k, "PopupMenu", on)
		th.set_icon(k + "_disabled", "PopupMenu", on)
	for k in ["radio_unchecked", "unchecked"]:
		th.set_icon(k, "PopupMenu", off)
		th.set_icon(k + "_disabled", "PopupMenu", off)
	return th


static var _markers := {}


## The popup row marker (POPUP_MARK px): a gold diamond for the chosen row, a blank of the same
## size for the others so every label lines up. Drawn at 4x and downsampled. Cached.
static func _marker_icon(on: bool) -> ImageTexture:
	if _markers.has(on):
		return _markers[on]
	var n := POPUP_MARK * 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if on:
		var c := (n - 1) / 2.0
		var r := n * 0.3
		for y in n:
			for x in n:
				var d := absf(x - c) + absf(y - c)
				if d <= r:
					# Lit from above: a brighter upper half, a pale core.
					var col := GOLD_HI if y < c else GOLD
					if d < r * 0.35:
						col = col.lerp(Color.WHITE, 0.35)
					img.set_pixel(x, y, col)
	img.resize(POPUP_MARK, POPUP_MARK, Image.INTERPOLATE_LANCZOS)
	_markers[on] = ImageTexture.create_from_image(img)
	return _markers[on]
