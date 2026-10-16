class_name GamePromptBanner
extends RefCounted
## My pending choice and the notices over the board: the F02-07 context banner (what is being
## chosen, non-card options, Confirm / Cancel), the F02-10 pile tray, the opponent-is-deciding
## notice and the short toast.

const TRAY_GAP := 10.0
const TRAY_PAD := 14.0
const TRAY_MAX_COLS := 8
const TRAY_MIN_W := 280.0
const BANNER_MIN_W := 300.0
const BANNER_MAX_W := 380.0
## Narrowest free column beside the board the banner may sit in (F03-25), and its margin to the zones.
const BANNER_SIDE_MIN_W := 220.0
const BANNER_SIDE_MAX_W := 300.0
const BANNER_GAP := 12.0
## Breathing border period (s).
const BANNER_BREATH := 1.4
const OPTION_H := 32

## The host screen this component works on.
var gs: GameScreen
## Banner explaining the pending choice.
var ctx_banner: PanelContainer
## Banner headline.
var banner_title: Label
## Banner explanatory text.
var banner_sub: RichTextLabel
## Banner buttons (skip, confirm ...).
var banner_btns: HFlowContainer
## Banner flow of option buttons.
var banner_flow: HFlowContainer
## Tray offering pile cards for a choice.
var tray: PanelContainer
## Container of the tray cards.
var tray_box: VBoxContainer
## Notice that the opponent is responding.
var wait_chip: PanelContainer
## Text of the wait notice.
var wait_label: Label
## Short toast message over the board.
var toast: Label
## uid -> card view shown only for the current choice (tray cards).
var tray_cards: Dictionary = {}
## Hash of the prompt last rendered (0 forces a re-render).
var prompt_sig: int = 0
## Last log seq checked for toast entries (-1: none yet; set on attach).
var seen_toast_seq: int = -1

var _banner_how: String = ""
## Who must act and that input is needed (small caps line above the headline).
var banner_tag: Label
var _banner_style: StyleBoxFlat
var _banner_tween: Tween
var _banner_pid: int = -2
var _wait_tween: Tween
var _toast_game: int = -99


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the context banner and the pile tray (hidden).
func build() -> void:
	# F02-07 / F03-25 context banner: a tall, narrow card with a gold pulse. It sits in the free
	# column beside the board (or the top strip when there is none) so it never covers a target.
	ctx_banner = PanelContainer.new()
	var bs := UIStyle.flat(Color(0.1, 0.075, 0.04, 0.98), UIStyle.GOLD, 3, 12)
	bs.border_width_left = 8
	bs.content_margin_left = 18
	bs.content_margin_right = 14
	bs.content_margin_top = 12
	bs.content_margin_bottom = 12
	bs.shadow_color = Color(UIStyle.GOLD, 0.35)
	bs.shadow_size = 14
	bs.shadow_offset = Vector2(0, 2)
	_banner_style = bs
	ctx_banner.add_theme_stylebox_override("panel", bs)
	ctx_banner.visible = false
	ctx_banner.z_index = UiLayers.BANNER
	gs.add_child(ctx_banner)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 6)
	ctx_banner.add_child(bcol)
	banner_tag = UIStyle.label("", 12, UIStyle.GOLD, false, true)
	banner_tag.clip_text = true
	banner_tag.custom_minimum_size = Vector2(40, 0)
	bcol.add_child(banner_tag)
	banner_title = UIStyle.label("", 21, UIStyle.GOLD_HI, true, true)
	banner_title.custom_minimum_size = Vector2(40, 0)
	bcol.add_child(banner_title)
	banner_sub = RichTextLabel.new()
	banner_sub.bbcode_enabled = true
	banner_sub.fit_content = true
	banner_sub.custom_minimum_size = Vector2(40, 21)
	banner_sub.scroll_active = false
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.mouse_filter = Control.MOUSE_FILTER_PASS
	banner_sub.add_theme_font_size_override("normal_font_size", 16)
	banner_sub.add_theme_font_size_override("bold_font_size", 17)
	banner_sub.add_theme_font_override("normal_font", UIStyle.font_body())
	banner_sub.add_theme_font_override("bold_font", UIStyle.font_bold())
	bcol.add_child(banner_sub)
	banner_flow = HFlowContainer.new()
	banner_flow.add_theme_constant_override("h_separation", 6)
	banner_flow.add_theme_constant_override("v_separation", 6)
	bcol.add_child(banner_flow)
	banner_btns = HFlowContainer.new()
	banner_btns.add_theme_constant_override("h_separation", 6)
	banner_btns.add_theme_constant_override("v_separation", 6)
	bcol.add_child(banner_btns)
	# F02-10 pile tray: cards offered only for this choice; click a card to choose it.
	tray = PanelContainer.new()
	var tsb := UIStyle.panel_style(Color(0.07, 0.062, 0.056, 0.97), UIStyle.GOLD, 12)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		tsb.set_content_margin(side, TRAY_PAD)
	tsb.shadow_size = 14
	tsb.shadow_color = Color(0, 0, 0, 0.6)
	tray.add_theme_stylebox_override("panel", tsb)
	tray.visible = false
	tray.z_index = UiLayers.TRAY
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
	wait_chip.z_index = UiLayers.WAIT
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
	toast.z_index = UiLayers.TOAST
	toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	toast.visible = false
	gs.add_child(toast)


## The choice banner and the pile tray follow the pending choice (rebuilt only when it changes).
func render() -> void:
	var view := gs.view
	var mv := gs.mv
	var pd := gs.pending()
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
	var pd := gs.pending()
	var on: bool = not pd.is_empty() and pd.get("mine", false) and not gs.overlays.overlay.visible and gs.view.get("stage", "") == "game"
	ctx_banner.visible = on
	_animate_banner(on, int(pd.get("id", -1)) if on else -1)
	GameUi.clear(banner_btns)
	GameUi.clear(banner_flow)
	banner_flow.visible = false
	if not on:
		return
	banner_title.text = String(pd["prompt"])
	banner_tag.text = ("%s · your decision" % String(gs.pv(gs.me())["name"])).to_upper()
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
	var type_choice := is_type_choice(pd)
	for o in pd["options"]:
		if pick and (o.has("ref") or o.has("slot") or o.has("card")):
			continue
		var idx: int = o["i"]
		var chosen: bool = idx in gs.multi
		var label := ("✓ " if chosen else "") + String(o["label"])
		var b: Button
		if type_choice:
			b = type_button(String(o["label"]), 15)
			b.set_meta("type_choice", String(o["label"]))
		elif pd["kind"] == "attack_target" or (not pick and String(o["label"]).begins_with("Activate")):
			b = UIStyle.primary_button(label, 14)
		else:
			b = UIStyle.button(label, 14)
		b.custom_minimum_size = Vector2(0, OPTION_H + (6 if type_choice else 0))
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


## Where the banner goes (F03-25). Preferred: the free column left of the board below the
## opponent's hand (tall and narrow, clear of every zone, pile and plate). If that column is too
## narrow (small window) it falls back to the top strip, centred between the seat label and the
## opponent's plate.
func place_banner() -> void:
	if ctx_banner == null:
		return
	var area := gs.play_area
	var board := gs.board
	var col_left := 14.0
	var col_right := area.end.x
	var top := area.position.y + 6.0
	var have_zones := not board.slots.is_empty()
	if have_zones:
		# Left edge of the leftmost zone or pile.
		var edge := area.end.x
		for k in board.slots:
			edge = minf(edge, (board.slots[k]["zone_node"] as Control).position.x)
		for side in 2:
			for z in board.piles[side]:
				edge = minf(edge, (board.piles[side][z] as Control).position.x)
		col_right = edge - BANNER_GAP
		top = board.opp_hand_box.position.y + CardWidget.SIZES["back"].y + BANNER_GAP
	var side_w := minf(BANNER_SIDE_MAX_W, col_right - col_left)
	if have_zones and side_w >= BANNER_SIDE_MIN_W:
		_size_banner(side_w)
		ctx_banner.position = Vector2(col_left, top)
		return
	var left := area.position.x + 230.0
	var plates := board.plates
	var right := (plates[0] as Control).position.x - 10.0 if not plates.is_empty() else area.end.x - 230.0
	var bw := clampf(right - left, BANNER_MIN_W, BANNER_MAX_W)
	_size_banner(bw)
	ctx_banner.position = Vector2(maxf(area.position.x + 8.0, (left + right) / 2.0 - bw / 2.0), 10.0)


func _size_banner(w: float) -> void:
	ctx_banner.size = Vector2(w, 0)
	ctx_banner.size = Vector2(w, ctx_banner.get_combined_minimum_size().y)
	ctx_banner.pivot_offset = ctx_banner.size / 2.0


## Attention treatment (F03-25): a pop and gold flare when a new choice appears, then a gentle
## breathing border and glow. Static (bright border, no motion) with UIStyle.reduce_motion.
func _animate_banner(on: bool, pid: int) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	if not on:
		_banner_pid = -2
		return
	_banner_style.border_color = UIStyle.GOLD_HI
	_banner_style.shadow_color = Color(UIStyle.GOLD, 0.45)
	_banner_style.shadow_size = 14
	ctx_banner.scale = Vector2.ONE
	if UIStyle.reduce_motion:
		return
	var fresh := pid != _banner_pid
	_banner_pid = pid
	if not fresh:
		_breathe()
		return
	ctx_banner.scale = Vector2(0.92, 0.92)
	_banner_style.shadow_color = Color(UIStyle.GOLD_HI, 0.95)
	_banner_style.shadow_size = 34
	_banner_tween = gs.create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(ctx_banner, "scale", Vector2.ONE, UIStyle.dur(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner_style, "shadow_size", 14, UIStyle.dur(0.7)).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_property(_banner_style, "shadow_color", Color(UIStyle.GOLD, 0.45), UIStyle.dur(0.7)).set_trans(Tween.TRANS_SINE)
	_banner_tween.chain().tween_callback(_breathe)


func _breathe() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = gs.create_tween().set_loops()
	var half := UIStyle.dur(BANNER_BREATH) / 2.0
	_banner_tween.tween_property(_banner_style, "border_color", UIStyle.GOLD.darkened(0.25), half).set_trans(Tween.TRANS_SINE)
	_banner_tween.parallel().tween_property(_banner_style, "shadow_color", Color(UIStyle.GOLD, 0.12), half).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_property(_banner_style, "border_color", UIStyle.GOLD_HI, half).set_trans(Tween.TRANS_SINE)
	_banner_tween.parallel().tween_property(_banner_style, "shadow_color", Color(UIStyle.GOLD, 0.5), half).set_trans(Tween.TRANS_SINE)


## True when every option of a choice is a Type name (Waang, Chaos Witch, ...): those render as
## Type-coloured buttons with the Type icon (F03-27). Only the offered options are shown.
static func is_type_choice(pd: Dictionary) -> bool:
	if pd.is_empty() or String(pd.get("kind", "")) != "mode":
		return false
	var opts: Array = pd.get("options", [])
	if opts.is_empty():
		return false
	for o in opts:
		var l := String(o.get("label", ""))
		if l == "No type":
			continue
		if l == "" or not UIStyle.TYPE_COLORS.has(l):
			return false
	return true


## Readable text colour (white or near-black, whichever contrasts more) on a fill.
static func type_text_color(fill: Color) -> Color:
	var dark := Color(0.06, 0.05, 0.05)
	return dark if _contrast(fill, dark) >= _contrast(fill, Color.WHITE) else Color.WHITE


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## WCAG contrast ratio of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## A Type declaration button: filled in the Type's colour (hover lighter with a glow, pressed
## darker), the Type icon on the left and the Type name as text, so the Type is never told by
## colour alone.
static func type_button(type_name: String, size: int = 15) -> Button:
	var ty := "" if type_name == "No type" else type_name
	var col := UIStyle.type_color(ty)
	var b := UIStyle.button(type_name, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var fills := {"normal": col, "hover": col.lightened(0.18), "pressed": col.darkened(0.2)}
	for k in fills:
		var fill: Color = fills[k]
		var sb := UIStyle.flat(fill, col.lightened(0.45) if k != "pressed" else col.lightened(0.2), 2, 8)
		sb.content_margin_left = 42
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if k == "hover":
			UIStyle.lift_style(sb, Color(fill, 0.55), 9, 0)
		b.add_theme_stylebox_override(k, sb)
		b.add_theme_color_override("font_color" if k == "normal" else "font_%s_color" % k, type_text_color(fill))
	b.add_theme_color_override("font_focus_color", type_text_color(col))
	var badge := TypeIcons.TypeBadge.new(ty)
	badge.set_anchor_and_offset(SIDE_TOP, 0.5, -13.0)
	badge.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 13.0)
	badge.set_anchor_and_offset(SIDE_LEFT, 0.0, 9.0)
	badge.set_anchor_and_offset(SIDE_RIGHT, 0.0, 35.0)
	b.add_child(badge)
	return b


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
		if ctx_banner != null and ctx_banner.visible:
			place_banner()


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
	var pd := gs.pending()
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
