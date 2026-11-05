class_name GameLog
extends RefCounted
## Sidebar game log: appends only new entries of the current game, colours lines by kind and
## turns card names into links that open the card's details.

## Entries shown when (re)attaching; the full history is one click away.
const LOG_BACKFILL := 100
## #46: the log well's leather grain and padding (px).
const LOG_GRAIN := 0.25
const LOG_PAD := 14
## #47: the winner line: GOLD_HI bold after a small crown.
const WIN_COLOR := "#f0cf7a"
const CROWN_PX := 15

## The host screen this component works on.
var gs: GameScreen
## Panel holding the log.
var panel: PanelContainer
## Rich text label showing the game log.
var label: RichTextLabel

var _seq_shown: int = 0
var _game: int = -1
var _full := false

## Card-name matcher and name -> category / id lookups (static: built once from CardDB).
static var _name_re: RegEx
static var _name_cat: Dictionary = {}
static var _name_id: Dictionary = {}


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the log panel into the sidebar column and returns it.
func build(col: VBoxContainer) -> PanelContainer:
	panel = GameUi.side_panel()
	panel.size_flags_vertical = Control.SIZE_FILL   # #48: a fixed share of the sidebar (GameSidebar.log_height)
	col.add_child(panel)
	var lv := VBoxContainer.new()
	UIStyle.pad(lv, "sm")
	panel.add_child(lv)
	# H11 (owner, 21 Oct): the header carries the collapse / expand toggle at its right.
	var head := HBoxContainer.new()
	head.name = "LogHead"
	head.add_theme_constant_override("separation", UIStyle.sp("sm"))
	lv.add_child(head)
	var title := GameUi.header("Game log")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	toggle = LogToggle.new(GameLog.expanded())
	toggle.name = "LogToggle"
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.pressed.connect(func(): set_expanded(not GameLog.expanded()))
	head.add_child(toggle)
	# #46: an F3 ink well with leather grain (not a terminal-black box), 14 px padding and md between
	# the text and its scrollbar.
	var lbg := PanelContainer.new()
	var lsb := UIStyle.inset_style(UIStyle.PANEL_INK, 6, LOG_GRAIN)
	lsb.base.content_margin_left = LOG_PAD
	# D5: 12 px above and below the text; the scrollbar track sits 6 px in from the frame (§1.4.2).
	lsb.base.content_margin_top = UIStyle.CONTENT_FLOOR
	lsb.base.content_margin_bottom = UIStyle.CONTENT_FLOOR
	lsb.base.content_margin_right = 6
	lsb.base = lsb.base
	lbg.add_theme_stylebox_override("panel", lsb)
	lbg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(lbg)
	label = RichTextLabel.new()
	var tsb := StyleBoxEmpty.new()
	tsb.content_margin_right = UIStyle.SCROLL_CONTENT_GAP
	label.add_theme_stylebox_override("normal", tsb)
	label.install_effect(LogFreshFx.new())
	label.bbcode_enabled = true
	label.meta_clicked.connect(_on_meta)
	label.scroll_following = true
	label.selection_enabled = true
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 14)
	label.add_theme_constant_override("line_separation", 3)
	label.meta_underlined = false
	# Card names in the log are links: the pointer shows it and a click opens the card's details.
	label.meta_hover_started.connect(func(m): if str(m).begins_with("card:"): label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND)
	label.meta_hover_ended.connect(func(_m): label.mouse_default_cursor_shape = Control.CURSOR_ARROW)
	StatusHelp.watch_rich(label)
	lbg.add_child(label)
	# H1 release check: lines scrolled up out of view no longer stop on a cut glyph at the well's top
	# edge; they sink into a short ink fade, shown only while earlier lines are hidden.
	top_fade = TopFade.new()
	top_fade.name = "TopFade"
	label.add_child(top_fade)
	var vs := label.get_v_scroll_bar()
	vs.value_changed.connect(func(v: float) -> void: top_fade.visible = v > 0.5)
	top_fade.visible = false
	return panel


## The ink fade over the top of the log text (visible while the log is scrolled down).
var top_fade: Control
## H11: the collapse / expand button in the log header.
var toggle: LogToggle


# ---------------------------------------------------------------- H11 log size
## Settings section and key of the log size choice (kept in the UI settings file, beside [ui]).
const SIZE_SECTION := "layout"
const SIZE_KEY := "log_expanded"
## Automated runs (GdUnit, -s drivers, --*-shots) keep the choice in this file instead.
const TEST_SETTINGS_PATH := "user://test_ui_layout.cfg"
static var _expanded: bool = false
static var _expanded_loaded: bool = false


## Where the log size choice is saved: the UI settings file, or a test file in automated runs.
static func settings_path() -> String:
	return TEST_SETTINGS_PATH if DeckStore.PATH == DeckStore.TEST_PATH else UIStyle.SETTINGS_PATH


## True while the viewer has chosen the tall game log (the short one is the default).
static func expanded() -> bool:
	if not _expanded_loaded:
		_expanded_loaded = true
		var cf := ConfigFile.new()
		if cf.load(settings_path()) == OK:
			_expanded = bool(cf.get_value(SIZE_SECTION, SIZE_KEY, false))
	return _expanded


## Records the viewer's log size choice (and saves it when `persist`), keeping the file's other
## sections.
static func store_expanded(on: bool, persist: bool = true) -> void:
	_expanded = on
	_expanded_loaded = true
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.load(settings_path())
	cf.set_value(SIZE_SECTION, SIZE_KEY, on)
	cf.save(settings_path())


## Switches the log between its short and tall size: saves the choice, plays toggle_on / toggle_off,
## turns the chevron and eases the panel to its new height (GameSidebar.animate_log; instant under
## reduce motion). `persist` false leaves the saved choice alone (screenshots, tests).
func set_expanded(on: bool, persist: bool = true) -> void:
	if on == GameLog.expanded():
		return
	GameLog.store_expanded(on, persist)
	Sfx.play("toggle_on" if on else "toggle_off")
	if toggle != null and is_instance_valid(toggle):
		toggle.set_open(on)
	if gs != null and gs.sidebar != null:
		gs.sidebar.animate_log()


## H11: the log header's collapse / expand button: a small iron plate with a gold chevron pointing
## down while the log is short (more to show) and up while it is tall; the chevron turns over on a
## toggle. A JuicyButton (hover lift, press, the shared hover cue); the click sound is the toggle's.
class LogToggle extends JuicyButton:
	const SIZE := Vector2(30, 24)
	## 0 = chevron down (short log), 1 = up (tall log); eased by set_open.
	var turn: float = 0.0:
		set(v):
			turn = v
			queue_redraw()
	var open := false

	func _init(is_open: bool = false) -> void:
		super()
		UIStyle.style_button(self, "secondary")
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb := get_theme_stylebox(st)
			sb.content_margin_left = 0
			sb.content_margin_right = 0
			sb.content_margin_top = 0
			sb.content_margin_bottom = 0
		custom_minimum_size = SIZE
		focus_mode = Control.FOCUS_NONE
		set_meta(Sfx.BUTTON_META, "none")   # set_expanded plays toggle_on / toggle_off
		open = is_open
		turn = 1.0 if is_open else 0.0
		_tip()

	## Shows the tall (`on`) or short state, turning the chevron (instant under reduce motion).
	func set_open(on: bool) -> void:
		open = on
		_tip()
		var to := 1.0 if on else 0.0
		if UIStyle.reduce_motion or not is_inside_tree():
			turn = to
			return
		var tw := UIStyle.restart_tween(self, &"turn_tw")
		UIStyle.tween_token(tw, self, "turn", to, "slide")

	func _tip() -> void:
		tooltip_text = "Show less of the game log" if open else "Show more of the game log"

	func _draw() -> void:
		super()
		var c := size / 2.0
		var w := 6.0
		var h := 3.5 * cos(turn * PI)   # +: pointing down, -: pointing up
		var col := UIStyle.GOLD_HI if _hover else UIStyle.GOLD
		var pts := PackedVector2Array([c + Vector2(-w, -h), c + Vector2(0, h), c + Vector2(w, -h)])
		draw_polyline(pts, Color(0, 0, 0, 0.5), 3.6, true)
		draw_polyline(pts, col, 2.0, true)


class TopFade extends Control:
	const H := 18.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_TOP_WIDE)
		offset_bottom = H
		offset_right = -float(UIStyle.SCROLL_CONTENT_GAP)   # clear of the scrollbar

	func _draw() -> void:
		var top := Color(UIStyle.PANEL_INK, 0.95)
		var clear := Color(UIStyle.PANEL_INK, 0.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([top, top, clear, clear]))


## Forgets what was shown (a new seat or series attached).
func reset() -> void:
	_seq_shown = 0
	_game = -1
	label.clear()


## A card link opens its details; "show_all" re-renders the whole game log (the history must
## stay reviewable).
func _on_meta(meta) -> void:
	if str(meta).begins_with("card:"):
		var id := int(str(meta).substr(5))
		if CardDB.has(id):
			gs.details.show_card_def(id)
		return
	if str(meta) == "show_all":
		_full = true
		_game = -1
		render()


## Appends the log entries not shown yet (the whole recent log on a new game).
func render() -> void:
	var mv := gs.mv
	if mv.is_empty():
		return
	var game_no: int = gs.view.get("game_no", 0)
	var entries: Array = mv.get("log", [])
	var fresh_game := game_no != _game
	if fresh_game:
		label.clear()
		_seq_shown = 0
		_game = game_no
		label.append_text("[color=#f2b544][b]Game %d[/b][/color]\n" % game_no)
		# Re-attaching (hot-seat seat swap, reconnect) must not re-parse the whole history.
		if entries.size() > LOG_BACKFILL and not _full:
			_seq_shown = int(entries[entries.size() - LOG_BACKFILL - 1]["seq"])
			label.append_text("[color=#d4a64a][url=show_all](%d earlier entries — click to show the full history)[/url][/color]\n" % (entries.size() - LOG_BACKFILL))
		_full = false
	# Only walk the new tail of the log, not the whole array every view.
	var start := entries.size()
	while start > 0 and int(entries[start - 1]["seq"]) > _seq_shown:
		start -= 1
	# #46: lines arriving during play rise in, staggered (not a backfill on a new game or attach).
	var animate := not fresh_game and not UIStyle.reduce_motion
	var t0 := Time.get_ticks_msec()
	var n_new := 0
	for i in range(start, entries.size()):
		var e: Dictionary = entries[i]
		_seq_shown = e["seq"]
		var t: String = e["text"]
		if t == "":
			continue
		var col := "#ddd4c0"
		var bold := false
		var fresh_open := ""
		var fresh_close := ""
		if animate:
			fresh_open = "[fresh t=%d]" % (t0 + n_new * LogFreshFx.STAGGER_MS)
			fresh_close = "[/fresh]"
			n_new += 1
		if t.begins_with("—"):
			# Turn header: a centred divider ("TURN 2 · BEN") with breathing room above it.
			var head := t.trim_prefix("—").trim_suffix("—").strip_edges().replace(": ", " · ").to_upper()
			# L10: the rules are em dashes in the house face (box-drawing lines fell back to a system font).
			label.append_text("\n[center]%s[color=#8a7350]———  [/color][color=#f0cf7a][b]%s[/b][/color][color=#8a7350]  ———[/color]%s[/center]\n" % [fresh_open, head.replace("[", "("), fresh_close])
			continue
		if t.begins_with("GAME OVER"):
			# #47: the winner line in gold after a crown (no off-palette magenta).
			label.add_image(crown_texture(), CROWN_PX, CROWN_PX, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			label.append_text(" %s[color=%s][b]%s[/b][/color]%s\n" % [fresh_open, WIN_COLOR, StatusHelp.linkify(_tint_names(t.replace("[", "(").replace("]", ")"), WIN_COLOR)), fresh_close])
			continue
		elif t.contains(" Damage") and t.contains("(HP "):
			col = "#ff8a8a"
		elif t.contains(" heals ") and t.contains("(HP "):
			col = "#8fe3a8"
		elif t.contains("activates Trap"):
			col = "#" + UIStyle.category_text_color("trap").to_html(false)
			bold = true
		elif t.contains("activates set Spell"):
			col = "#" + UIStyle.category_text_color("spell").to_html(false)
			bold = true
		elif t.begins_with("Battle:"):
			col = "#ffd84a"
		# Card names link to the card; status names show their effect on hover (2026-10-18).
		var body := StatusHelp.linkify(_tint_names(t.replace("[", "(").replace("]", ")"), col))
		if bold:
			body = "[b]%s[/b]" % body
		label.append_text("%s[color=%s]%s[/color]%s\n" % [fresh_open, col, body, fresh_close])
	if n_new > 0:
		_settle_fresh_at(t0 + (n_new - 1) * LogFreshFx.STAGGER_MS + int(LogFreshFx.GLOW_S * 1000.0))


# H7 (21 Oct): a [fresh] tag makes the RichTextLabel process and redraw every frame for as long
# as the tag is in its text, i.e. for the rest of the game. Once the newest line has come to rest
# (plain text from then on) its processing is switched off; the next fresh line turns it back on.
var _fresh_until := 0


func _settle_fresh_at(until_ms: int) -> void:
	_fresh_until = maxi(_fresh_until, until_ms)
	if not label.is_inside_tree():
		return
	var wait := float(_fresh_until - Time.get_ticks_msec()) / 1000.0 + 0.05
	label.get_tree().create_timer(maxf(wait, 0.0)).timeout.connect(_settle_fresh)


func _settle_fresh() -> void:
	if not is_instance_valid(label):
		return
	if Time.get_ticks_msec() < _fresh_until:
		# A later batch is still animating, or the (frame-time) timer ran ahead of the clock.
		_settle_fresh_at(_fresh_until)
		return
	label.set_process_internal(false)
	label.queue_redraw()


static var _crown: Texture2D


## #47: a small gilded crown for the log's winner line (an SVG rasterised once at 2x for crisp edges).
static func crown_texture() -> Texture2D:
	if _crown != null:
		return _crown
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>" \
		+ "<defs><linearGradient id='g' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#fff1c4'/>" \
		+ "<stop offset='0.5' stop-color='#f0cf7a'/><stop offset='1' stop-color='#a97c34'/></linearGradient></defs>" \
		+ "<path d='M4 24 L3 9 L10.5 15.5 L16 5 L21.5 15.5 L29 9 L28 24 Z' fill='url(#g)' stroke='#2a1a08' stroke-width='1.6' stroke-linejoin='round'/>" \
		+ "<rect x='4' y='24.5' width='24' height='4' rx='1' fill='url(#g)' stroke='#2a1a08' stroke-width='1.4'/>" \
		+ "<circle cx='16' cy='17' r='2.2' fill='#e8605a' stroke='#2a1a08' stroke-width='0.8'/></svg>"
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK:
		img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(UIStyle.GOLD_HI, 1.0))
	img.generate_mipmaps()
	_crown = ImageTexture.create_from_image(img)
	return _crown


## Wraps every card name in a log line in its card-kind colour (Trap red, Spell green, ...).
## A name already in the line's own colour is left plain.
static func _tint_names(body: String, line_col: String) -> String:
	if _name_re == null:
		var names: Array = []
		for d in CardDB.all():
			var nm := String(d["name"])
			if nm.length() >= 3 and not _name_cat.has(nm):
				_name_cat[nm] = String(d["category"])
				_name_id[nm] = int(d["id"])
				names.append(nm)
		names.sort_custom(func(a, b): return a.length() > b.length())
		var alts := PackedStringArray()
		for nm in names:
			var esc := ""
			for ch in nm:
				esc += ("\\" + ch) if ".^$*+?()[]{}|\\/-".contains(ch) else ch
			alts.append(esc)
		_name_re = RegEx.new()
		_name_re.compile("(?<!\\w)(" + "|".join(alts) + ")(?!\\w)")
	var out := ""
	var at := 0
	for m in _name_re.search_all(body):
		var col := "#" + UIStyle.category_text_color(_name_cat.get(m.get_string(), "")).to_html(false)
		out += body.substr(at, m.get_start() - at)
		var nm_s := m.get_string() if col == line_col else "[color=%s]%s[/color]" % [col, m.get_string()]
		out += "[url=card:%d]%s[/url]" % [int(_name_id.get(m.get_string(), -1)), nm_s]   # click: show the card
		at = m.get_end()
	return out + body.substr(at)
