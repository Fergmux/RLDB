class_name GamePromptBanner
extends RefCounted
## My pending choice and the notices over the board: the F02-07 context banner (what is being
## chosen, non-card options, Confirm / Cancel), the F02-10 pile tray, the opponent-is-deciding
## notice and the short toast.

const TRAY_GAP := 10.0
const TRAY_PAD := 14.0
const TRAY_MAX_COLS := 8
const TRAY_MIN_W := 280.0
const BANNER_MIN_W := 460.0
const BANNER_MAX_W := 640.0
const OPTION_H := 32

var gs: GameScreen
var ctx_banner: PanelContainer
var banner_title: Label
var banner_sub: RichTextLabel
var banner_btns: HBoxContainer
var banner_flow: HFlowContainer
var tray: PanelContainer
var tray_box: VBoxContainer
var wait_chip: PanelContainer
var wait_label: Label
var toast: Label
## uid -> card view shown only for the current choice (tray cards).
var tray_cards: Dictionary = {}
## Hash of the prompt last rendered (0 forces a re-render).
var prompt_sig: int = 0
## Last log seq checked for toast entries (-1: none yet; set on attach).
var seen_toast_seq: int = -1

var _banner_how: String = ""
var _wait_tween: Tween
var _toast_game: int = -99


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the context banner and the pile tray (hidden).
func build() -> void:
	# F02-07 context banner: covers the top strip (never the board) while I pick targets.
	ctx_banner = PanelContainer.new()
	var bs := UIStyle.flat(Color(0.09, 0.07, 0.045, 0.97), UIStyle.GOLD, 2, 12)
	bs.border_width_left = 6
	bs.content_margin_left = 16
	bs.content_margin_right = 10
	bs.content_margin_top = 6
	bs.content_margin_bottom = 6
	bs.shadow_color = Color(0, 0, 0, 0.55)
	bs.shadow_size = 10
	bs.shadow_offset = Vector2(0, 3)
	ctx_banner.add_theme_stylebox_override("panel", bs)
	ctx_banner.visible = false
	ctx_banner.z_index = GameScreen.Z_BANNER
	gs.add_child(ctx_banner)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 4)
	ctx_banner.add_child(bcol)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	bcol.add_child(bh)
	banner_flow = HFlowContainer.new()
	banner_flow.add_theme_constant_override("h_separation", 6)
	banner_flow.add_theme_constant_override("v_separation", 4)
	bcol.add_child(banner_flow)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_child(bv)
	banner_title = UIStyle.label("", 17, UIStyle.GOLD_HI, false, true)
	banner_title.clip_text = true
	banner_title.custom_minimum_size = Vector2(40, 0)
	banner_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bv.add_child(banner_title)
	banner_sub = RichTextLabel.new()
	banner_sub.bbcode_enabled = true
	banner_sub.fit_content = false
	banner_sub.custom_minimum_size = Vector2(40, 21)
	banner_sub.clip_contents = true
	banner_sub.scroll_active = false
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner_sub.mouse_filter = Control.MOUSE_FILTER_PASS
	banner_sub.add_theme_font_size_override("normal_font_size", 15)
	banner_sub.add_theme_font_size_override("bold_font_size", 16)
	banner_sub.add_theme_font_override("normal_font", UIStyle.font_body())
	banner_sub.add_theme_font_override("bold_font", UIStyle.font_bold())
	bv.add_child(banner_sub)
	banner_btns = HBoxContainer.new()
	banner_btns.add_theme_constant_override("separation", 6)
	banner_btns.alignment = BoxContainer.ALIGNMENT_END
	bh.add_child(banner_btns)
	# F02-10 pile tray: cards offered only for this choice; click a card to choose it.
	tray = PanelContainer.new()
	var tsb := UIStyle.panel_style(Color(0.07, 0.062, 0.056, 0.97), UIStyle.GOLD, 12)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		tsb.set_content_margin(side, TRAY_PAD)
	tsb.shadow_size = 14
	tsb.shadow_color = Color(0, 0, 0, 0.6)
	tray.add_theme_stylebox_override("panel", tsb)
	tray.visible = false
	tray.z_index = GameScreen.Z_TRAY
	gs.add_child(tray)
	var tsc := ScrollContainer.new()
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray.add_child(tsc)
	tray_box = VBoxContainer.new()
	tray_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_box.add_theme_constant_override("separation", 8)
	tsc.add_child(tray_box)


## Builds the opponent-is-deciding notice and the toast (hidden).
func build_notices() -> void:
	# Opponent-is-deciding notice in the middle of the board (user feedback: otherwise the game
	# looks stuck). Click-through.
	wait_chip = PanelContainer.new()
	var wsb := UIStyle.flat(Color(0.05, 0.04, 0.035, 0.9), Color(UIStyle.GOLD, 0.75), 2, 22)
	wsb.content_margin_left = 26
	wsb.content_margin_right = 26
	wsb.content_margin_top = 8
	wsb.content_margin_bottom = 8
	wsb.shadow_color = Color(0, 0, 0, 0.5)
	wsb.shadow_size = 8
	wait_chip.add_theme_stylebox_override("panel", wsb)
	wait_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wait_chip.z_index = GameScreen.Z_WAIT
	wait_chip.visible = false
	wait_label = UIStyle.label("", 22, UIStyle.GOLD_HI, false, true)
	wait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wait_chip.add_child(wait_label)
	gs.add_child(wait_chip)
	toast = UIStyle.label("", 15, UIStyle.BAD, true)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 4)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := UIStyle.flat(Color(0.06, 0.05, 0.045, 0.94), Color(UIStyle.GOLD, 0.7), 1, 8)
	tsb.content_margin_left = 14
	tsb.content_margin_right = 14
	tsb.content_margin_top = 6
	tsb.content_margin_bottom = 6
	toast.add_theme_stylebox_override("normal", tsb)
	toast.add_theme_font_size_override("font_size", 17)
	toast.z_index = GameScreen.Z_TOAST
	toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	toast.visible = false
	gs.add_child(toast)


## The choice banner and the pile tray follow the pending choice (rebuilt only when it changes).
func render() -> void:
	var view := gs.view
	var mv := gs.mv
	var pd := gs._pending()
	var sig := hash([view.get("stage", ""), view.get("net", {}), pd, mv.get("active", -1), mv.get("winner", -1), mv.get("resolving", false),
		gs.multi, view.get("deck_ready", []), view.get("you", 0)])
	if sig == prompt_sig:
		return
	prompt_sig = sig
	gs.targeting.hover_opt = -1
	_render_banner()
	_render_tray()


func _multi_status(pd: Dictionary) -> String:
	var total_txt := ""
	if pd.get("min_total", 0) > 0:
		var total := 0
		for i in gs.multi:
			total += maxi(pd["options"][i].get("card", {}).get("cost", 0), 0)
		total_txt = "  ·  cost total %d / %d" % [total, pd["min_total"]]
	var rng := "%d" % pd["min"] if pd["min"] == pd["max"] else "%d–%d" % [pd["min"], pd["max"]]
	return "Selected %d of %s%s" % [gs.multi.size(), rng, total_txt]


## F02-07 context banner: what is being chosen, for which effect, how many and in what order,
## plus the non-card options (e.g. a direct attack), Confirm and Cancel. It covers only the top
## strip, never a target card.
func _render_banner() -> void:
	var pd := gs._pending()
	var on: bool = not pd.is_empty() and pd.get("mine", false) and not gs.overlays.overlay.visible and gs.view.get("stage", "") == "game"
	ctx_banner.visible = on
	GameUi.clear(banner_btns)
	GameUi.clear(banner_flow)
	banner_flow.visible = false
	if not on:
		return
	banner_title.text = String(pd["prompt"])
	var pick := gs.selection.board_targeting()
	var how := ""
	if pick:
		var what := "zone" if pd["kind"] == "slot" else "card"
		if int(pd["max"]) > 1:
			how = _multi_status(pd)
		else:
			how = "Click a highlighted %s%s." % [what, " in the tray" if not gs.selection.tray_options(pd).is_empty() else ""]
		if pd["kind"] == "attack_target":
			how = "Hover a target to preview the battle, click to attack."
	elif pd["kind"] == "trap_response":
		how = "Your opponent is waiting: activate a Trap or pass."
	elif int(pd["max"]) > 1:
		how = _multi_status(pd)
	_banner_how = how
	update_banner_sub()
	# Card/zone options are picked on the board; every other option is a button here.
	var row: Control = banner_btns if pick else banner_flow
	for o in pd["options"]:
		if pick and (o.has("ref") or o.has("slot") or o.has("card")):
			continue
		var idx: int = o["i"]
		var chosen: bool = idx in gs.multi
		var label := ("✓ " if chosen else "") + String(o["label"])
		var b := UIStyle.primary_button(label, 14) if (pd["kind"] == "attack_target" or (not pick and String(o["label"]).begins_with("Activate"))) else UIStyle.button(label, 14)
		b.custom_minimum_size = Vector2(0, OPTION_H)
		b.pressed.connect(gs.selection.pick_option.bind(idx))
		b.mouse_entered.connect(func(): gs.targeting.hover_opt = idx)
		b.mouse_exited.connect(func(): if gs.targeting.hover_opt == idx: gs.targeting.hover_opt = -1)
		row.add_child(b)
	if not pick and row.get_child_count() > 0:
		banner_flow.visible = true
	if int(pd["max"]) > 1:
		var c := UIStyle.primary_button("Confirm", 14)
		c.custom_minimum_size = Vector2(0, OPTION_H)
		c.disabled = gs.multi.size() < int(pd["min"])
		c.pressed.connect(gs.selection.confirm_multi)
		banner_btns.add_child(c)
	if pd["cancellable"]:
		var x := UIStyle.button("Cancel", 14)
		x.custom_minimum_size = Vector2(0, OPTION_H)
		x.pressed.connect(gs.selection.cancel)
		banner_btns.add_child(x)
	place_banner()


## The choice banner: centred over the play area like a toast, a margin below the window top,
## narrower than the board column so the seat label and Settings / Menu stay visible.
func place_banner() -> void:
	if ctx_banner == null:
		return
	var area := gs.play_area
	# Centred between the seat label (left) and the opponent's plate (right).
	var left := area.position.x + 230.0
	var plates := gs.board.plates
	var right := (plates[0] as Control).position.x - 10.0 if not plates.is_empty() else area.end.x - 230.0
	var bw := clampf(right - left, BANNER_MIN_W, BANNER_MAX_W)
	ctx_banner.size = Vector2(bw, 0)
	ctx_banner.position = Vector2(maxf(area.position.x + 8.0, (left + right) / 2.0 - bw / 2.0), 10.0)


## Banner sub-line: how to answer the choice, or the hovered battle target coloured by the
## expected outcome (the full breakdown is the tooltip).
func update_banner_sub() -> void:
	if banner_sub == null:
		return
	var pv := gs.preview
	var t := "[color=#c2b8a2]%s[/color]" % _banner_how.replace("[", "(")
	if pv.text != "":
		# Only the target, coloured by the expected outcome (green / red / purple); the full
		# breakdown stays in the tooltip.
		var col: Color = GameScreen.VERDICT_COLORS.get(pv.verdict, UIStyle.TEXT)
		t = "[b][color=#%s]%s[/color][/b]" % [col.to_html(false), pv.target.replace("[", "(")]
	if banner_sub.text != t:
		banner_sub.text = t
		banner_sub.tooltip_text = pv.text if pv.text != "" else _banner_how


## Columns of the pile tray: as many as fit the play area (max 8), never more than the cards.
func _tray_cols(n: int) -> int:
	var cw: float = CardWidget.SIZES["mini"].x
	var fit := int(floor((gs.play_area.size.x - 80.0 - 2.0 * TRAY_PAD + TRAY_GAP) / (cw + TRAY_GAP)))
	return clampi(mini(n, fit), 1, TRAY_MAX_COLS)


## The tray hugs its cards (same padding on every side) and sits in the middle of the play area.
func place_tray() -> void:
	if tray == null:
		return
	var area := gs.play_area
	var n := maxi(1, tray_cards.size())
	var cols := _tray_cols(n)
	var cw: float = CardWidget.SIZES["mini"].x
	var grid_w := cols * cw + (cols - 1) * TRAY_GAP
	var w := maxf(grid_w, TRAY_MIN_W) + 2.0 * TRAY_PAD
	var need := tray_box.get_combined_minimum_size()
	var h := minf(need.y + 2.0 * TRAY_PAD, area.size.y - 40.0)
	if need.y + 2.0 * TRAY_PAD > area.size.y - 40.0:
		w += 12.0   # room for the scroll bar
	tray.size = Vector2(w, h)
	tray.position = (area.position + (area.size - tray.size) / 2.0).round()


## F02-10 tray of the cards offered from a pile (Spent, Draw, Extra, an opponent's pile when
## the effect allows it). Click a card to choose it; multi-choices keep their order and use
## the banner's Confirm. Hover shows the card's details; the tray never offers other cards.
func _render_tray() -> void:
	var pd := gs._pending()
	var opts: Array = gs.selection.tray_options(pd) if gs.selection.board_targeting() else []
	tray_cards.clear()
	GameUi.clear(tray_box)
	tray.visible = not opts.is_empty() and not gs.overlays.overlay.visible
	if not tray.visible:
		return
	var head := "Choose %s" % ("a card" if int(pd["max"]) <= 1 else "cards")
	var hl := UIStyle.label(head, 16, UIStyle.GOLD, true, true)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tray_box.add_child(hl)
	var flow := GridContainer.new()
	flow.columns = _tray_cols(opts.size())
	flow.add_theme_constant_override("h_separation", int(TRAY_GAP))
	flow.add_theme_constant_override("v_separation", int(TRAY_GAP))
	flow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tray_box.add_child(flow)
	for o in opts:
		var cv: Dictionary = o["card"]
		var uid: int = int(cv.get("uid", -1))
		tray_cards[uid] = cv
		var idx: int = o["i"]
		var w := CardWidget.new().setup(cv, "mini")
		w.set_marks(true, idx in gs.multi)
		w.order_no = gs.selection.order_no(idx)
		w.pressed.connect(func(_w): gs.selection.pick_option(idx))
		w.mouse_entered.connect(func():
			gs.peek_uid = uid
			gs.details.render())
		w.mouse_exited.connect(func():
			if gs.peek_uid == uid:
				gs.peek_uid = -1
				gs.details.render())
		flow.add_child(w)
	place_tray()
	_fit_tray.call_deferred()


func _fit_tray() -> void:
	await gs.get_tree().process_frame
	place_tray()


## Shows (text != "") or hides the centre-of-board wait notice; it breathes gently while shown.
func show_wait(text: String) -> void:
	if text == "":
		if wait_chip.visible:
			wait_chip.visible = false
			if _wait_tween != null and _wait_tween.is_valid():
				_wait_tween.kill()
		return
	wait_label.text = text
	wait_chip.reset_size()
	var sz := wait_chip.get_combined_minimum_size()
	wait_chip.size = sz
	var area := gs.play_area
	wait_chip.position = Vector2(area.position.x + (area.size.x - sz.x) / 2.0, gs.board.deco.mid_y - sz.y / 2.0)
	if wait_chip.visible:
		return
	wait_chip.visible = true
	wait_chip.modulate.a = 1.0
	if not UIStyle.reduce_motion:
		_wait_tween = gs.create_tween().set_loops()
		_wait_tween.tween_property(wait_chip, "modulate:a", 0.65, 0.9).set_trans(Tween.TRANS_SINE)
		_wait_tween.tween_property(wait_chip, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


## Short non-blocking message over the board; it never waits for input.
func show_toast(text: String, col: Color, secs: float) -> void:
	var area := gs.play_area
	toast.text = text
	toast.visible = text != ""
	toast.size = Vector2.ZERO
	toast.position = Vector2(area.position.x + (area.size.x - minf(area.size.x - 120.0, toast.get_combined_minimum_size().x)) / 2.0, GameScreen.TOP_H + 8.0)
	toast.add_theme_color_override("font_color", col)
	var t := gs.get_tree().create_timer(secs)
	t.timeout.connect(func():
		if toast.text == text:
			toast.text = ""
			toast.visible = false)


## Hides the toast at once (a command was sent).
func hide_toast() -> void:
	toast.text = ""
	toast.visible = false


## A rejected command / status message from the seat client.
func on_status(text: String) -> void:
	if text != "":
		Sfx.play("deny")
	show_toast(text, UIStyle.BAD, 4.0)


## F02-09: log entries flagged as toasts (e.g. a triggered effect with no legal target)
## also show briefly over the board. Only new entries of the current game; never on attach.
func show_log_toasts() -> void:
	var mv := gs.mv
	if mv.is_empty():
		return
	var game_no: int = gs.view.get("game_no", 0)
	var entries: Array = mv.get("log", [])
	var maxseq := -1
	for e in entries:
		maxseq = maxi(maxseq, int(e["seq"]))
	if game_no != _toast_game or seen_toast_seq < 0:
		_toast_game = game_no
		seen_toast_seq = maxseq
		return
	var shown := []
	for e in entries:
		if int(e["seq"]) > seen_toast_seq and e.get("toast", false) and String(e["text"]) != "":
			shown.append(String(e["text"]))
	seen_toast_seq = maxi(seen_toast_seq, maxseq)
	if not shown.is_empty():
		Sfx.play("notice")
		show_toast("  ·  ".join(shown.slice(maxi(0, shown.size() - 2))), UIStyle.GOLD_HI, 4.5)
