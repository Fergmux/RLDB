class_name GamePromptBanner
extends RefCounted
## My pending choice and the notices over the board: the F02-07 context banner (what is being
## chosen, non-card options, Confirm / Cancel), the F02-10 pile tray, the opponent-is-deciding
## notice and the short toast.

const TRAY_GAP := 10.0
## Padding inside the tray's house plate (clears the corner flourishes).
const TRAY_PAD := 20.0
const TRAY_MAX_COLS := 8
const TRAY_MIN_W := 280.0
const BANNER_MIN_W := 300.0
const BANNER_MAX_W := 380.0
## Narrowest free column beside the board the banner may sit in (F03-25), and its margin to the zones.
const BANNER_SIDE_MIN_W := 170.0
## Below this width the side column is "narrow": the card strip stacks the card above its text and
## shows fewer rules lines, so the panel stays in the free column instead of covering the board.
const BANNER_NARROW_W := 240.0
## Rules lines of the card strip in the narrow side column and in the top-centre fallback.
const SUBJECT_LINES_NARROW := 3
const BANNER_SIDE_MAX_W := 300.0
const BANNER_GAP := 12.0
## Breathing border period (s).
const BANNER_BREATH := 1.4
const OPTION_H := 32
## F05: size of the card image in the input panel, and the most rules-text lines shown there
## (the full text is its tooltip and the right-click inspection).
const SUBJECT_CARD := Vector2(64, 96)
const SUBJECT_LINES := 6
## Type-choice buttons (F03): the icon box's left inset and its largest side (the left content
## margin of 42 px holds it with a gap before the label).
const TYPE_ICON_X := 9.0
const TYPE_ICON_MAX := 28.0

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
## F08: circles of an exact material cost (shown only for exact-total choices).
var cost_pips: CostPips
## F05: the card the choice is about (image, name and rules text), hidden when there is none.
var subject_box: PanelContainer
var subject_card: CardWidget
var subject_name: Label
var subject_text: Label
## Tray offering pile cards for a choice (a HousePanel).
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
## Who must act and that input is needed (the header strip title of the plate).
var banner_tag: Label
var _banner_pid: int = -2
var _wait_tween: Tween
var _toast_game: int = -99


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the context banner and the pile tray (hidden).
func build() -> void:
	# F02-07 / F03-25 context banner: a tall, narrow card with a gold pulse. It sits in the free
	# column beside the board (or the top strip when there is none) so it never covers a target.
	var plate := PromptPlate.new()
	ctx_banner = plate
	ctx_banner.visible = false
	ctx_banner.z_index = UiLayers.BANNER
	gs.add_child(ctx_banner)
	var bcol := plate.body
	banner_tag = plate.title_label
	banner_title = plate.add_headline("", 21)
	_build_subject(bcol)
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
	cost_pips = CostPips.new()
	cost_pips.visible = false
	bcol.add_child(cost_pips)
	banner_flow = HFlowContainer.new()
	banner_flow.add_theme_constant_override("h_separation", 6)
	banner_flow.add_theme_constant_override("v_separation", 6)
	bcol.add_child(banner_flow)
	banner_btns = HFlowContainer.new()
	banner_btns.add_theme_constant_override("h_separation", 6)
	banner_btns.add_theme_constant_override("v_separation", 6)
	bcol.add_child(banner_btns)
	# F02-10 pile tray: cards offered only for this choice; click a card to choose it.
	tray = HousePanel.new("Choose a card", "", Vector2(TRAY_PAD, TRAY_PAD), 8)
	tray.visible = false
	tray.z_index = UiLayers.TRAY
	gs.add_child(tray)
	var tsc := ScrollContainer.new()
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(tray as HousePanel).body.add_child(tsc)
	tray_box = VBoxContainer.new()
	tray_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_box.add_theme_constant_override("separation", 8)
	tsc.add_child(tray_box)


## F05: the card-context strip of the input panel: the card on the left, its name and rules
## text beside it. Right-click the card to inspect it in full.
func _build_subject(col: VBoxContainer) -> void:
	subject_box = PanelContainer.new()
	var sb := UIStyle.flat(Color(0.045, 0.035, 0.025, 0.92), Color(UIStyle.BRONZE, 0.75), 1, 8)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	subject_box.add_theme_stylebox_override("panel", sb)
	subject_box.visible = false
	subject_box.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(subject_box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subject_box.add_child(h)
	subject_card = CardWidget.new().setup(null, "mini")
	GameUi.resize_card(subject_card, SUBJECT_CARD)
	subject_card.auto_hover = false
	subject_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	subject_card.tooltip_text = "Right-click to inspect"
	subject_card.right_pressed.connect(func(w): gs.inspect.inspect_widget(w))
	h.add_child(subject_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	subject_name = UIStyle.label("", 15, UIStyle.GOLD_HI, true, true)
	subject_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(subject_name)
	subject_text = UIStyle.label("", 13, UIStyle.TEXT, true)
	subject_text.max_lines_visible = SUBJECT_LINES
	subject_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subject_text.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(subject_text)


## F05: the visible card my choice `pd` is about, or {}: the card a placement prompt names (a
## Fusion unit), else the choice's source. Only cards this seat may see are ever used: the source
## is given only when visible (MatchView._add_source) and the name is matched among my own visible
## cards; a Trap response names no card (which face-down card may respond stays hidden).
func subject_for(pd: Dictionary) -> Dictionary:
	if pd.is_empty() or not bool(pd.get("mine", false)) or String(pd.get("kind", "")) == "trap_response":
		return {}
	var src := gs.details.find_card(int(pd.get("source_uid", -1)))
	var prompt := String(pd.get("prompt", ""))
	if not src.is_empty() and prompt.contains(String(src.get("name", "~"))):
		return src
	# The prompt names another card of mine (the Fusion unit being summoned with a Spell's
	# materials, zone and stance): show that one. Longest name wins ("Dragon" vs "Ultimate Dragon").
	var best := {}
	var pv := gs.pv(gs.me())
	for z in ["extra", "hand"]:
		for c in pv.get(z, []):
			if c == null or c.get("hidden", false):
				continue
			var nm := String(c.get("name", ""))
			if nm != "" and prompt.contains(nm) and nm.length() > String(best.get("name", "")).length():
				best = c
	return best if not best.is_empty() else src


func _render_subject(pd: Dictionary) -> void:
	var c := subject_for(pd)
	subject_box.visible = not c.is_empty()
	if c.is_empty():
		return
	subject_card.setup(c, "mini")
	GameUi.resize_card(subject_card, SUBJECT_CARD)
	subject_name.text = String(c.get("name", ""))
	var txt := String(c.get("text", "")).strip_edges()
	subject_text.text = txt if txt != "" else "No rules text."
	subject_text.tooltip_text = txt
	subject_box.tooltip_text = "%s\n%s" % [String(c.get("name", "")), txt]


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
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 10)
	wrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wait_chip.add_child(wrow)
	var rune := WaitPlate.Rune.new()
	rune.custom_minimum_size = Vector2(30, 30)
	rune.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrow.add_child(rune)
	wrow.add_child(wait_label)
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
	# F04: a Fusion started from the Extra Deck list answers its "which Fusion unit" prompt
	# with the unit the player chose there; the banner then shows the next step instead.
	if gs.details.consume_fusion_intent():
		return
	prompt_sig = sig
	gs.targeting.hover_opt = -1
	_render_banner()
	_render_tray()


func _multi_status(pd: Dictionary) -> String:
	var ep := exact_payment(pd, gs.multi)
	if not ep.is_empty():
		return exact_status(ep)
	var total_txt := ""
	if pd.get("min_total", 0) > 0:
		var total := 0
		for i in gs.multi:
			# The option's `value` is the material's current (modified) cost, as the authority counts it.
			var o: Dictionary = pd["options"][i]
			total += maxi(int(o.get("value", o.get("card", {}).get("cost", 0))), 0)
		total_txt = "  ·  cost total %d / %s%d" % [total, "exactly " if pd.get("total_exact", false) else "", pd["min_total"]]
	var rng := "%d" % pd["min"] if pd["min"] == pd["max"] else "%d–%d" % [pd["min"], pd["max"]]
	return "Selected %d of %s%s" % [gs.multi.size(), rng, total_txt]


## F08: the exact-total payment of a material choice for picks `picks`:
## {"need", "paid", "remaining", "costs"} (costs: each pick's current cost, in pick order), or {}
## when the choice has no exact total. Values are the authority's current modified costs.
static func exact_payment(pd: Dictionary, picks: Array) -> Dictionary:
	if pd.is_empty() or not bool(pd.get("total_exact", false)) or not pd.has("total_required"):
		return {}
	var need := int(pd["total_required"])
	var costs := []
	for i in picks:
		costs.append(option_value(pd, int(i)))
	var paid := 0
	for v in costs:
		paid += int(v)
	return {"need": need, "paid": paid, "remaining": need - paid, "costs": costs}


## Current cost an option pays (its `value`, else its card's cost; never below 0).
static func option_value(pd: Dictionary, i: int) -> int:
	for o in pd.get("options", []):
		if int(o["i"]) == i:
			return maxi(int(o.get("value", o.get("card", {}).get("cost", 0))), 0)
	return 0


## F08: whether option `o` is offered at all in an exact-total choice: its cost must be above 0
## and no more than the whole total (other choices offer every option).
static func payable_option(pd: Dictionary, o: Dictionary) -> bool:
	var ep := exact_payment(pd, [])
	if ep.is_empty():
		return true
	var v := option_value(pd, int(o["i"]))
	return v > 0 and v <= int(ep["need"])


## F08: true when adding option `i` to `picks` would pay more than the exact total. A picked
## option never overpays (it can always be deselected).
static func would_overpay(pd: Dictionary, picks: Array, i: int) -> bool:
	if i in picks:
		return false
	var ep := exact_payment(pd, picks)
	if ep.is_empty():
		return false
	return option_value(pd, i) > int(ep["remaining"])


## Status line of an exact payment: what is still owed, or that it is paid exactly.
static func exact_status(ep: Dictionary) -> String:
	var need := int(ep["need"])
	var paid := int(ep["paid"])
	if paid == 0:
		return "Pay exactly %d: select materials whose costs fill the circles." % need
	if paid == need:
		return "Exact cost paid (%d of %d). Confirm to continue." % [paid, need]
	return "%d of %d paid · %d remaining." % [paid, need, need - paid]


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
	_render_subject(pd)
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
	var ep := exact_payment(pd, gs.multi)
	cost_pips.visible = not ep.is_empty()
	if not ep.is_empty():
		cost_pips.set_payment(int(ep["need"]), ep["costs"])
		cost_pips.tooltip_text = exact_status(ep)
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
		c.disabled = MatchView.multi_pick_error(pd, gs.multi) != ""   # count and exact Arcane total (F03-04)
		c.pressed.connect(gs.selection.confirm_multi)
		banner_btns.add_child(c)
	if pd["cancellable"] and not gs.view.has("tutorial"):   # a forced tutorial step has no Cancel button
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
		_after_banner_settles()
		return
	var left := area.position.x + 230.0
	var plates := board.plates
	var right := (plates[0] as Control).position.x - 10.0 if not plates.is_empty() else area.end.x - 230.0
	var bw := clampf(right - left, BANNER_MIN_W, BANNER_MAX_W)
	_size_banner(bw)
	ctx_banner.position = Vector2(maxf(area.position.x + 8.0, (left + right) / 2.0 - bw / 2.0), 10.0)
	_after_banner_settles()


## Re-places the tray once the banner has measured itself (HousePanel.fit settles over frames).
func _after_banner_settles() -> void:
	if tray == null or not tray.visible or not is_instance_valid(gs) or not gs.is_inside_tree():
		return
	var tree := gs.get_tree()
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(gs) and gs.is_inside_tree() and is_instance_valid(tray) and tray.visible:
		place_tray()


func _size_banner(w: float) -> void:
	_fit_subject(w)
	# F04-13: the plate measures itself in passes after layout (see HousePanel.fit), so wrapped
	# labels that were laid out at a stale width cannot leave it too tall.
	(ctx_banner as HousePanel).fit(w)


## The card strip (F05) adapts to the panel width: side by side when there is room, otherwise the
## card sits above a shorter text so the panel does not grow over the board.
func _fit_subject(w: float) -> void:
	if subject_box == null or subject_text == null:
		return
	var narrow := w < BANNER_NARROW_W or ctx_banner.position.y < 20.0
	subject_text.max_lines_visible = SUBJECT_LINES_NARROW if narrow else SUBJECT_LINES
	var row := subject_card.get_parent()
	if row is BoxContainer:
		(row as BoxContainer).vertical = w < BANNER_NARROW_W


## Attention treatment (F03-25): a pop and gold flare when a new choice appears, then a gentle
## breathing border and glow (HousePanel.attend). Static with UIStyle.reduce_motion.
func _animate_banner(on: bool, pid: int) -> void:
	var plate := ctx_banner as HousePanel
	if not on:
		plate.calm()
		_banner_pid = -2
		return
	var fresh := pid != _banner_pid
	_banner_pid = pid
	plate.attend(fresh)


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
	# F03: a fixed square icon box, centred on the button's vertical middle. The bottom anchor is
	# set before the top one: setting the top anchor (0.5) above a bottom anchor still at 0 made
	# Godot clamp it back to 0, which stretched the box from the button's top and drew every icon
	# high (Waang's Type choice). The box scales with the label size, not with the button height.
	var px := icon_box(size)
	var badge := TypeIcons.TypeBadge.new(ty, px)
	badge.anchor_bottom = 0.5
	badge.anchor_top = 0.5
	badge.anchor_left = 0.0
	badge.anchor_right = 0.0
	badge.offset_top = -px / 2.0
	badge.offset_bottom = px / 2.0
	badge.offset_left = TYPE_ICON_X
	badge.offset_right = TYPE_ICON_X + px
	badge.set_meta("type_icon", true)
	b.add_child(badge)
	return b


## Side of the Type icon box of a Type button whose label is `font_px` (fits the left margin).
static func icon_box(font_px: int) -> float:
	return clampf(roundf(font_px * 1.6), 18.0, TYPE_ICON_MAX)


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
	var chrome := (tray as HousePanel).chrome_size()
	var w := maxf(grid_w, TRAY_MIN_W) + chrome.x
	var need := tray_box.get_combined_minimum_size()
	var h := minf(need.y + chrome.y, area.size.y - 40.0)
	if need.y + chrome.y > area.size.y - 40.0:
		w += 12.0   # room for the scroll bar
	tray.size = Vector2(w, h)
	tray.position = (area.position + (area.size - tray.size) / 2.0).round()
	# The input panel (taller with its card context, F05) must never cover the offered cards: when
	# it sits over the tray (the top-strip fallback), the tray moves down below it.
	if ctx_banner != null and ctx_banner.visible:
		var br := Rect2(ctx_banner.position, ctx_banner.size)
		if br.intersects(Rect2(tray.position, tray.size)):
			tray.position.y = roundf(br.end.y + BANNER_GAP)
			tray.size.y = maxf(chrome.y + 60.0, minf(tray.size.y, area.end.y - tray.position.y - 8.0))


## F02-10 tray of the cards offered from a pile (Spent, Draw, Extra, an opponent's pile when
## the effect allows it). Click a card to choose it; multi-choices keep their order and use
## the banner's Confirm. Hover shows the card's details; the tray never offers other cards.
func _render_tray() -> void:
	var pd := gs.pending()
	var opts: Array = gs.selection.tray_options(pd) if gs.selection.board_targeting() else []
	tray_cards.clear()
	GameUi.clear(tray_box)
	var was_open := tray.visible
	tray.visible = not opts.is_empty() and not gs.overlays.overlay.visible
	if not tray.visible:
		return
	var house := tray as HousePanel
	house.set_title("Choose %s" % ("a card" if int(pd["max"]) <= 1 else "cards"))
	house.set_tag("%d offered" % opts.size())
	if not was_open:
		house.appear()   # pops in when it opens, not on every pick of a multi-choice
	var lead := Control.new()   # room above the cards for their order badges (the scroll clips)
	lead.custom_minimum_size = Vector2(0, 6)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_box.add_child(lead)
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
		# F08: a material that would pay more than what remains is visibly unavailable.
		var over := would_overpay(pd, gs.multi, idx)
		w.set_marks(not over, idx in gs.multi, over)
		if over:
			w.tooltip_text = "Cannot overpay"
			w.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		w.set_meta("overpay", over)
		w.order_no = gs.selection.order_no(idx)
		w.pressed.connect(func(_w): gs.selection.pick_option(idx))
		w.right_pressed.connect(gs.inspect.inspect_widget)
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
		# The screen (and its toast) may be gone by now: a SceneTree timer outlives it.
		if is_instance_valid(toast) and toast.text == text:
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
