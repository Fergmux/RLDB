class_name GameLog
extends RefCounted
## Sidebar game log: appends only new entries of the current game, colours lines by kind and
## turns card names into links that open the card's details.

## Entries shown when (re)attaching; the full history is one click away.
const LOG_BACKFILL := 100

var gs: GameScreen
var panel: PanelContainer
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
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.8
	col.add_child(panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	panel.add_child(lv)
	lv.add_child(GameUi.header("Game log"))
	var lbg := PanelContainer.new()
	lbg.add_theme_stylebox_override("panel", UIStyle.flat(Color(UIStyle.PANEL_INK, 0.85), Color(UIStyle.BRONZE, 0.4), 1, 6))
	lbg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(lbg)
	label = RichTextLabel.new()
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
	var lsb := UIStyle.flat(Color(0.045, 0.04, 0.035, 0.92), Color(UIStyle.BRONZE, 0.45), 1, 8)
	lsb.content_margin_left = 10
	lsb.content_margin_right = 6
	lsb.content_margin_top = 6
	lsb.content_margin_bottom = 6
	lbg.add_theme_stylebox_override("panel", lsb)
	lbg.add_child(label)
	return panel


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
	for i in range(start, entries.size()):
		var e: Dictionary = entries[i]
		_seq_shown = e["seq"]
		var t: String = e["text"]
		if t == "":
			continue
		var col := "#ddd4c0"
		var bold := false
		if t.begins_with("—"):
			# Turn header: a centred divider ("TURN 2 · BEN") with breathing room above it.
			var head := t.trim_prefix("—").trim_suffix("—").strip_edges().replace(": ", " · ").to_upper()
			label.append_text("\n[center][color=#8a7350]━━━  [/color][color=#f0cf7a][b]%s[/b][/color][color=#8a7350]  ━━━[/color][/center]\n" % head.replace("[", "("))
			continue
		elif t.contains("loses") and t.contains("HP"):
			col = "#ff8a8a"
		elif t.contains("gains") and t.contains("HP"):
			col = "#8fe3a8"
		elif t.contains("activates Trap"):
			col = "#" + UIStyle.category_text_color("trap").to_html(false)
			bold = true
		elif t.contains("activates set Spell"):
			col = "#" + UIStyle.category_text_color("spell").to_html(false)
			bold = true
		elif t.begins_with("Battle:"):
			col = "#ffd84a"
		elif t.begins_with("GAME OVER"):
			col = "#ff9ff3"
			bold = true
		var body := _tint_names(t.replace("[", "(").replace("]", ")"), col)
		if bold:
			body = "[b]%s[/b]" % body
		label.append_text("[color=%s]%s[/color]\n" % [col, body])


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
