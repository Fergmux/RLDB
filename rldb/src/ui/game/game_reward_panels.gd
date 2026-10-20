class_name GameRewardPanels
extends RefCounted
## Rewards stage of the series modal (F04-03): picks remaining as gems, the reward kinds as
## illustrated tiles (add / remove / change basic units / add a basic unit), the sub-panel of the open reward and the
## offer of new cards. Local choices that are not sent yet (which reward is open, the card to
## remove, the basic-unit Type and Race) live here.

const OFFER_CARD := Vector2(168, 252)
const PREVIEW_CARD := Vector2(150, 225)
## Rows of the chosen-rewards list shown before it scrolls.
const LEDGER_MAX_ROWS := 4
const LEDGER_ROW_H := 36.0
## Seconds the other rewards / offered cards take to fold away once one is chosen.
const COLLAPSE_TIME := 0.24
## SECTION header sizes (D3): a sub-panel's title, and the small caps captions of the plates.
const PANEL_HEAD_PX := 18
const CAPTION_PX := 13
## The reward kinds: [key, title, caption, icon, colour].
const MODES := [["add", "Add a card", "Pick a card type, then take one of three.", "add"],
	["remove", "Remove a card", "Take one card out of your deck.", "remove"],
	["basic", "Change basic units", "Every basic unit becomes a new Type and Race.", "swap"],
	["extra_basic", "Add a basic unit", "One more copy of your basic unit, same Type and Race.", "add"]]

## The host screen this component works on.
var gs: GameScreen

## Reward being set up ("", "add", "remove", "basic", "extra_basic").
var mode: String = ""
## F10: signature of the offer whose card was clicked (a second click on the same offer is
## ignored until the authority answers), and when, so a rejected take can be retried.
var _took_sig: int = 0
var _took_at: int = 0
var _remove_sel: int = -1
## Basic-unit change being composed (F06-04: the chosen Type and Race for every basic unit).
var _basic_race: String = ""
var _basic_type: String = ""
## Rows of the chosen-rewards list already shown (a longer list animates its new rows in).
var _ledger_seen: int = 0
## True while a chosen reward / card is folding the others away (blocks a second choice).
var _collapsing: bool = false
## True from choosing a reward kind until its panel is first shown (it then opens with motion).
var _fresh_panel: bool = false


func _init(screen: GameScreen) -> void:
	gs = screen


## Fills the modal with the rewards stage.
func render() -> void:
	var box := gs.overlays.overlay_box
	var line := gs.overlays.game_result_line()
	if line != "":
		box.add_child(_result_plate(line))
	var r: Dictionary = gs.view["rewards"]
	if r["taken"].is_empty():
		_ledger_seen = 0
	if r["done"]:
		# Owner feedback 2026-10-18: no waiting plate, just the line with its dots filling in.
		var wait := WaitingDots.new("Starting soon" if r["opponent_done"] else "Waiting for your opponent", 20)
		wait.custom_minimum_size = Vector2(0, 56)
		wait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(wait)
		if not r["taken"].is_empty():
			box.add_child(_taken_flow(r["taken"]))
		box.add_child(_footer(false))
		return
	# Picks remaining: gems in a plate.
	var total: int = r["left"] + r["taken"].size() + (1 if r.get("pending", false) else 0)
	box.add_child(_picks_plate(r["left"], maxi(total, r["left"])))
	if r["opponent_done"]:
		box.add_child(_info_chip("Your opponent has finished choosing", true))
	if not r["taken"].is_empty():
		box.add_child(_taken_flow(r["taken"]))
	if r.get("pending", false):
		_render_offer(r)
		return
	# The reward kinds as equal illustrated tiles. Once one is chosen they fold away into a single
	# bar naming the choice (with a way back), so its panel below never needs the modal to scroll.
	if mode == "":
		box.add_child(_kinds_row())
	else:
		box.add_child(_chosen_bar(mode))
	var counts := {}
	var order := []
	for c in gs.view["deck"]:
		if not counts.has(c["id"]):
			order.append(c)
		counts[c["id"]] = counts.get(c["id"], 0) + 1
	var sub: Control = null
	match mode:
		"add": sub = _reward_add_panel(r)
		"remove": sub = _reward_remove_panel(order, counts)
		"basic": sub = _basic_change_panel(r, order, counts)
		"extra_basic": sub = _extra_basic_panel(order, counts)
	if sub != null:
		box.add_child(sub)
		# The panel of a reward just chosen opens with the house motion (#106); the tile's own click
		# was its sound. A re-render of the same panel stays still.
		if _fresh_panel and sub is OrnatePanel:
			(sub as OrnatePanel).appear(false)
	_fresh_panel = false
	box.add_child(_footer(true, r))


# ------------------------------------------------------------------ pieces
func _result_plate(line: String) -> Control:
	var p := PanelContainer.new()
	# E1: the plate is as wide as its line (with generous padding), centred, not the modal's full width.
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := UIStyle.flat(Color(0.06, 0.047, 0.032, 0.92), Color(UIStyle.GOLD, 0.55), 1, 10)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	UIStyle.lift_style(sb, Color(0, 0, 0, 0.45), 6, 2)
	p.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, UIStyle.PANEL_GRAIN))
	var l := UIStyle.label(line, 16, UIStyle.TEXT, false)
	l.add_theme_font_override("font", UIStyle.font_bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Plate with the "picks left" gems.
func _picks_plate(left: int, total: int) -> Control:
	var op := OrnatePanel.new(10, 8)
	op.arm = 10.0
	op.frame_inset = 0.0
	op.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	op.accent = UIStyle.BRONZE.lightened(0.2)
	op.box().shadow_size = 8
	op.tooltip_text = "%d pick%s remaining" % [left, "" if left == 1 else "s"]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	op.add_child(h)
	var cap := section_caption("Picks")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cap)
	var pips := PickPips.new()
	pips.left = left
	pips.total = total
	pips.custom_minimum_size = Vector2(PickPips.width_for(total), 36)
	h.add_child(pips)
	return op


func _info_chip(text: String, done: bool) -> Control:
	var col: Color = UIStyle.GOOD if done else UIStyle.MUTED
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(col.darkened(0.8), 0.95), Color(col, 0.75), 1, 13)
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	p.add_child(h)
	h.add_child(WaitPlate.StatusDot.new(done))
	h.add_child(UIStyle.label(text, 14, col.lightened(0.3)))
	return p


## What one entry of the view's `taken` list is: {kind, verb, detail, icon, color}. The list holds
## the series' own sentences ("Added X", "Added another X", "Removed X", "Changed N basic units to X").
static func reward_kind(text: String) -> Dictionary:
	if text.begins_with("Added another "):
		return {"kind": "extra_basic", "verb": "Added another", "detail": text.substr(14), "icon": "add", "color": UIStyle.GOLD}
	if text.begins_with("Added "):
		return {"kind": "add", "verb": "Added", "detail": text.substr(6), "icon": "add", "color": UIStyle.GOOD}
	if text.begins_with("Removed "):
		return {"kind": "remove", "verb": "Removed", "detail": text.substr(8), "icon": "remove", "color": UIStyle.BAD}
	if text.begins_with("Changed "):
		return {"kind": "basic", "verb": "Changed", "detail": text.substr(8), "icon": "swap", "color": UIStyle.RUNE_BLUE}
	return {"kind": "other", "verb": "", "detail": text, "icon": "add", "color": UIStyle.MUTED}


## The rewards chosen so far this round: one aligned row each (icon, what was done, the card), in a
## plate that is as wide as the rows need. Names never wrap: a long one is trimmed with an ellipsis
## (the full text is the row's tooltip), and past LEDGER_MAX_ROWS the list scrolls.
func _taken_flow(taken: Array) -> Control:
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := UIStyle.flat(Color(0.05, 0.04, 0.03, 0.9), Color(UIStyle.BRONZE, 0.8), 1, 10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 8
	UIStyle.lift_style(sb, Color(0, 0, 0, 0.4), 6, 2)
	plate.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, UIStyle.PANEL_GRAIN))
	plate.custom_minimum_size = Vector2(minf(460.0, maxf(240.0, gs.overlays.overlay_box.custom_minimum_size.x - 40.0)), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	plate.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var cap := section_caption("Rewards chosen")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cap)
	head.add_child(GameUi.pill(str(taken.size()), UIStyle.GOLD, 12))
	v.add_child(head)
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.4), true, 8.0))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _ledger_seen > taken.size():
		_ledger_seen = 0
	var fresh: Array = []
	for i in taken.size():
		var row := _ledger_row(String(taken[i]), i > 0)
		rows.add_child(row)
		if i >= _ledger_seen:
			fresh.append(row)
	if taken.size() > LEDGER_MAX_ROWS:
		var area := ScrollArea.new()
		area.custom_minimum_size = Vector2(0, LEDGER_ROW_H * LEDGER_MAX_ROWS)
		area.set_content(rows)
		v.add_child(area)
	else:
		v.add_child(rows)
	_ledger_seen = taken.size()
	for row in fresh:
		_slide_in(row)
	return plate


## One row of the chosen-rewards list.
func _ledger_row(text: String, divider: bool) -> Control:
	var k := reward_kind(text)
	var col: Color = k["color"]
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, LEDGER_ROW_H)
	row.add_theme_constant_override("separation", 10)
	row.tooltip_text = text
	var ic := ChoiceTile.Icon.new(String(k["icon"]), col, 28.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var verb := UIStyle.label(String(k["verb"]).to_upper(), 12, col.lightened(0.25), false, true)
	verb.custom_minimum_size = Vector2(112, 0)
	verb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	verb.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(verb)
	var detail := UIStyle.label(String(k["detail"]), 16, UIStyle.TEXT)
	detail.add_theme_font_override("font", UIStyle.font_bold())
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail.clip_text = true
	detail.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(detail)
	var tick := UIStyle.label("\u2713", 16, UIStyle.GOOD, false, true)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tick)
	if not divider:
		return row
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.tooltip_text = text
	var line := ColorRect.new()
	line.color = Color(UIStyle.BRONZE, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	wrap.add_child(line)
	wrap.add_child(row)
	return wrap


## A new ledger row eases in (fade and a short slide); instant under reduced motion.
func _slide_in(c: Control) -> void:
	if UIStyle.reduce_motion or not gs.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, UIStyle.dur(0.35)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Bottom row: View your deck, then Finish / Skip (when `with_finish`).
func _footer(with_finish: bool, r: Dictionary = {}) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), true, 12.0))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	# Design review #61: the reward tiles are the screen's primary interaction, so the footer has no
	# gold button: Finish / Skip is a secondary and View your deck a text link with its tome glyph.
	if gs.view.has("deck"):
		var see := TextLink.make("View your deck", 15)
		see.name = "ViewDeckLink"
		see.custom_minimum_size = Vector2(0, 40)
		see.set_lead(34)
		var g := DeckSelectView.TabGlyph.new("tome", UIStyle.GOLD)
		g.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		g.offset_left = 6
		g.offset_right = 28
		g.offset_top = -11
		g.offset_bottom = 11
		see.add_child(g)
		see.pressed.connect(gs.overlays._show_deck)
		h.add_child(see)
	if with_finish:
		var fin := UIStyle.secondary_button("Finish rewards" if not r["taken"].is_empty() else "Skip remaining rewards", 16)
		fin.custom_minimum_size = Vector2(230, 44)
		fin.pressed.connect(func(): gs.send({"t": "reward_finish"}))
		h.add_child(fin)
	return v


## The type was chosen and the pick is spent: one of the offered cards must be taken.
func _render_offer(r: Dictionary) -> void:
	var box := gs.overlays.overlay_box
	var cat := String(r.get("offer_type", ""))
	var tname: String = UIStyle.CATEGORY_NAMES.get(cat, "card")
	var t := UIStyle.label("Choose your new %s" % tname, 24, UIStyle.GOLD, false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(Ornate.Rule.new(Color(UIStyle.CATEGORY_COLORS.get(cat, UIStyle.GOLD).lightened(0.2), 0.8), true, 12.0))
	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 14)
	flow.alignment = BoxContainer.ALIGNMENT_CENTER   # the offered cards sit centred in the modal
	box.add_child(flow)
	var sig := offer_sig(r)
	var holders: Array = []
	for i in r["offer"].size():
		var c: Dictionary = r["offer"][i]
		# F10: the card itself is the button (no Take card button or click glyph under it).
		var holder := MarginContainer.new()   # room for the hover lift, so the neighbours do not shift
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			holder.add_theme_constant_override(side, 6)
		var cw := CardWidget.new().setup(MatchView.summary_view(c), "big")
		GameUi.resize_card(cw, OFFER_CARD)
		cw.tooltip_text = "Take %s\nRight-click to inspect" % c["name"]
		cw.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cw.set_meta("reward_offer", i)
		var idx: int = i
		cw.pressed.connect(func(_w): pick_offer(idx, sig, holders, flow))
		cw.right_pressed.connect(gs.inspect.inspect_widget)
		cw.mouse_entered.connect(func(): gs.overlays._lift(cw, 1.05))
		cw.mouse_exited.connect(func(): gs.overlays._lift(cw, 1.0))
		holder.add_child(cw)
		flow.add_child(holder)
		holders.append(holder)
	equalize(holders)
	box.add_child(_footer(false))


## The size every control of `sizes` takes so they all match: the widest and the tallest minimum.
static func equal_size(sizes: Array) -> Vector2:
	var out := Vector2.ZERO
	for sz in sizes:
		out = Vector2(maxf(out.x, (sz as Vector2).x), maxf(out.y, (sz as Vector2).y))
	return out


## Makes every control of `ctrls` the same size: each one's minimum becomes the largest minimum
## among them, so if one grows (wrapped text) they all grow with it.
func equalize(ctrls: Array) -> void:
	var sizes: Array = []
	for c in ctrls:
		sizes.append((c as Control).get_combined_minimum_size())
	var sz := equal_size(sizes)
	for c in ctrls:
		(c as Control).custom_minimum_size = sz


## The four reward kinds as equal tiles (same width, same height, whatever their text wraps to).
func _kinds_row() -> Control:
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 10)
	var tiles: Array = []
	for md in MODES:
		var key: String = md[0]
		var tile := ChoiceTile.new(md[1], md[2], _mode_color(key), md[3])
		tile.custom_minimum_size = Vector2(0, 150)
		tile.size_flags_stretch_ratio = 1.0
		tile.tooltip_text = md[2]
		tile.pressed.connect(func(): choose_mode(key, mrow))
		mrow.add_child(tile)
		tiles.append(tile)
	return mrow


func _mode_color(key: String) -> Color:
	match key:
		"add": return UIStyle.GOOD.darkened(0.15)
		"remove": return UIStyle.BAD
		"basic": return UIStyle.RUNE_BLUE
	return UIStyle.GOLD.darkened(0.25)


## Chooses reward kind `key`: the other tiles fold away (eased), then its panel opens under a bar
## that names the choice. `row` is the tile row being folded (null: switch at once).
func choose_mode(key: String, row: Control = null) -> void:
	if _collapsing:
		return
	var go := func():
		_collapsing = false
		mode = key
		_fresh_panel = true
		_remove_sel = -1
		_basic_type = ""
		_basic_race = ""
		gs.overlays.refresh()
	if row == null or UIStyle.reduce_motion or not gs.is_inside_tree():
		go.call()
		return
	_collapsing = true
	_fold(row, go)


## Fades `c` out while its height eases to nothing, then calls `done`.
func _fold(c: Control, done: Callable) -> void:
	var h := c.size.y
	c.custom_minimum_size.y = h
	c.clip_contents = true
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 0.0, UIStyle.dur(COLLAPSE_TIME)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "custom_minimum_size:y", 0.0, UIStyle.dur(COLLAPSE_TIME)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(done)


## The bar that stands in for the reward tiles once one is chosen: its icon and name, and a button
## back to the full list.
func _chosen_bar(key: String) -> Control:
	var md: Array = []
	for m in MODES:
		if m[0] == key:
			md = m
	var col := _mode_color(key)
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(col.darkened(0.78), 0.97), Color(UIStyle.GOLD, 0.7), 2, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	UIStyle.lift_style(sb, Color(col, 0.25), 8, 0)
	p.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, UIStyle.PANEL_GRAIN * 0.6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := ChoiceTile.Icon.new(String(md[3]), col, 38.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", 0)
	h.add_child(tv)
	tv.add_child(UIStyle.label(String(md[1]), 19, UIStyle.GOLD_HI, false, true))
	var cap := UIStyle.label(String(md[2]), 13, UIStyle.TEXT_DIM)
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.clip_text = true
	tv.add_child(cap)
	var back := UIStyle.button("Choose another reward", 14)
	back.custom_minimum_size = Vector2(0, 36)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.set_meta(Sfx.BUTTON_META, "back")
	back.pressed.connect(func():
		mode = ""
		_remove_sel = -1
		_basic_type = ""
		_basic_race = ""
		gs.overlays.refresh())
	h.add_child(back)
	# The bar eases in where the tiles were.
	if not UIStyle.reduce_motion and gs.is_inside_tree():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, UIStyle.dur(0.22))
	return p


## A card of the offer was clicked: the other cards fold away, the chosen one stays with a line
## naming it, and the take is sent once they have gone. Same guards as `take_offer`.
func pick_offer(idx: int, sig: int, holders: Array, flow: Control) -> bool:
	if not _claim_offer(idx, sig):
		return false
	Sfx.play("confirm")
	if UIStyle.reduce_motion or not gs.is_inside_tree() or idx >= holders.size():
		gs.send({"t": "reward_add", "index": idx})
		return true
	var r: Dictionary = gs.view.get("rewards", {})
	var nm := String(r["offer"][idx]["name"])
	var tw := flow.create_tween()
	tw.set_parallel(true)
	for i in holders.size():
		var hd: Control = holders[i]
		if i == idx:
			continue
		var w := hd.size.x
		hd.custom_minimum_size.x = w
		hd.clip_contents = true
		tw.tween_property(hd, "modulate:a", 0.0, UIStyle.dur(COLLAPSE_TIME)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(hd, "custom_minimum_size:x", 0.0, UIStyle.dur(COLLAPSE_TIME)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var note := UIStyle.label("Taking %s\u2026" % nm, 18, UIStyle.GOLD_HI, false, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate.a = 0.0
	flow.get_parent().add_child(note)
	flow.get_parent().move_child(note, flow.get_index() + 1)
	tw.tween_property(note, "modulate:a", 1.0, UIStyle.dur(COLLAPSE_TIME))
	tw.chain().tween_callback(func():
		gs.send({"t": "reward_add", "index": idx})
		_recover_after(2.1))
	return true


## If the take was refused (the offer is still showing) put the offer back so it can be tried again.
func _recover_after(sec: float) -> void:
	await gs.get_tree().create_timer(sec).timeout
	if is_instance_valid(gs) and gs.view.get("rewards", {}).get("pending", false):
		gs.overlays.refresh()


## Signature of an offer: which cards, and how many picks are left (a new offer differs).
static func offer_sig(r: Dictionary) -> int:
	return hash([r.get("offer", []), r.get("left", 0), r.get("taken", []).size()])


## Takes offered card `idx` of the offer `sig` through the normal reward command. A repeated
## click on the same offer (double click, click during the round trip) sends nothing; after 2 s
## without an answer (a rejected take) the offer can be clicked again.
func take_offer(idx: int, sig: int) -> bool:
	if not _claim_offer(idx, sig):
		return false
	Sfx.play("confirm")
	gs.send({"t": "reward_add", "index": idx})
	return true


## The guards of a take: true (and the offer marked taken) for the first valid click on a live offer.
func _claim_offer(idx: int, sig: int) -> bool:
	var now := Time.get_ticks_msec()
	if sig == _took_sig and now - _took_at < 2000:
		return false
	var r: Dictionary = gs.view.get("rewards", {})
	if not r.get("pending", false) or offer_sig(r) != sig or idx < 0 or idx >= r.get("offer", []).size():
		return false
	_took_sig = sig
	_took_at = now
	return true


## A small caps plate caption ("PICKS", "REWARDS CHOSEN", "IN YOUR DECK") as a SECTION header
## (D3: flat gold, a hard dark shadow, no underline: the plates carry their own rules).
static func section_caption(text: String) -> Label:
	var cap := UIStyle.label(text.to_upper(), CAPTION_PX, UIStyle.GOLD, false, true)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tt := TitleText.apply(cap, TitleText.Tier.SECTION, CAPTION_PX)
	tt.show_underline = false
	TitleText.apply(cap, TitleText.Tier.SECTION, CAPTION_PX)
	return cap


## A titled sub-panel of the rewards screen: returns [panel, content VBox].
static func _reward_panel(title: String, note: String) -> Array:
	var pc := OrnatePanel.new(10, 14)
	pc.arm = 12.0
	pc.frame_inset = 5.0
	pc.accent = UIStyle.BRONZE.lightened(0.25)
	pc.top_col = Color(0.1, 0.082, 0.062)
	pc.bottom_col = Color(0.05, 0.042, 0.034)
	pc.box().shadow_size = 8
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var t := UIStyle.label(title.to_upper(), PANEL_HEAD_PX, UIStyle.GOLD, false, true)
	t.name = "PanelTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	# SECTION tier (D3); the house rule below is its underline.
	var tt := TitleText.apply(t, TitleText.Tier.SECTION, PANEL_HEAD_PX)
	tt.show_underline = false
	TitleText.apply(t, TitleText.Tier.SECTION, PANEL_HEAD_PX)
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.55), true, 8.0))
	if note != "":
		var n := UIStyle.label(note, 14, UIStyle.TEXT_DIM, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
	return [pc, v]


## Add a card: choose the type first (this spends the pick), then one of three cards of it.
func _reward_add_panel(r: Dictionary) -> Control:
	var pv: Array = _reward_panel("Choose a card type", "Using this pick, you then take one of three cards of that type.")
	var tf := GridContainer.new()
	tf.columns = 3
	tf.add_theme_constant_override("h_separation", 10)
	tf.add_theme_constant_override("v_separation", 10)
	pv[1].add_child(tf)
	for cat in r.get("types", []):
		var col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.BRONZE)
		var tb := ChoiceTile.new(String(UIStyle.CATEGORY_NAMES.get(cat, cat)), "", col, String(cat), true)
		tb.custom_minimum_size = Vector2(0, 54)
		tb.tooltip_text = "Uses one pick: shows three %s cards and you take one." % String(UIStyle.CATEGORY_NAMES.get(cat, cat))
		var c2: String = cat
		tb.pressed.connect(func():
			mode = ""
			gs.send({"t": "reward_type", "category": c2}))
		tf.add_child(tb)
	return pv[0]


## Remove a card: pick it from the list (preview on the right), then Confirm.
func _reward_remove_panel(order: Array, counts: Dictionary) -> Control:
	var pv: Array = _reward_panel("Remove a card", "Choose a card, then confirm. One copy leaves your deck.")
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 14)
	pv[1].add_child(lr)
	var area := ScrollArea.new()
	area.custom_minimum_size = Vector2(0, 240)
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_child(area)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 5)
	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_right", 8)
	lm.add_theme_constant_override("margin_top", 4)
	lm.add_theme_constant_override("margin_bottom", 4)
	lm.add_child(lv)
	area.set_content(lm)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	lr.add_child(right)
	var prev := CardWidget.new()
	prev.auto_hover = false
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shown: Dictionary = {}
	for c in order:
		if int(c["id"]) == _remove_sel:
			shown = c
	if shown.is_empty() and not order.is_empty():
		shown = order[0]
	prev.setup(MatchView.summary_view(shown) if not shown.is_empty() else null, "big")
	GameUi.resize_card(prev, PREVIEW_CARD)
	right.add_child(prev)
	for c in order:
		var on: bool = int(c["id"]) == _remove_sel
		var label: String = "%s%s" % [c["name"], " ×%d" % counts[c["id"]] if counts[c["id"]] > 1 else ""]
		var row := ChoiceTile.new(label, "", UIStyle.CATEGORY_COLORS.get(c["category"], UIStyle.BRONZE), String(c["category"]), true)
		row.selected = on
		row.custom_minimum_size = Vector2(0, 46)
		var cc: Dictionary = c
		row.mouse_entered.connect(func():
			prev.setup(MatchView.summary_view(cc), "big")
			GameUi.resize_card(prev, PREVIEW_CARD))
		row.pressed.connect(func():
			_remove_sel = int(cc["id"])
			var keep: int = area.scroll.scroll_vertical
			gs.overlays.refresh()
			_keep_scroll_later(keep))
		lv.add_child(row)
	var ok := UIStyle.primary_button("Remove card" if _remove_sel == -1 else "Remove %s" % String(shown.get("name", "")), 15)
	ok.disabled = _remove_sel == -1
	ok.custom_minimum_size = Vector2(PREVIEW_CARD.x, 38)
	ok.clip_text = true
	var rid := _remove_sel
	ok.pressed.connect(func():
		mode = ""
		_remove_sel = -1
		gs.send({"t": "reward_remove", "card_id": rid}))
	right.add_child(ok)
	return pv[0]


var _scroll_keep: int = 0


## The removal list is rebuilt on every selection; put it back where it was once laid out.
func _keep_scroll_later(y: int) -> void:
	_scroll_keep = y
	await gs.get_tree().process_frame
	await gs.get_tree().process_frame
	var found := _find_area(gs.overlays.overlay_box)
	if found != null:
		found.scroll.scroll_vertical = _scroll_keep
		found.scroll.scroll_to(float(_scroll_keep))


func _find_area(n: Node) -> ScrollArea:
	if n is ScrollArea:
		return n
	for ch in n.get_children():
		var f := _find_area(ch)
		if f != null:
			return f
	return null


## F06-04 "Change basic units": the basic units now in the deck, then one Type and one Race in the
## shared picker with the resulting card; Confirm turns EVERY basic unit into it for one pick.
## A change that would alter nothing cannot be confirmed (the authority refuses it too).
## "Add a basic unit" (owner feedback 2026-10-18): the deck's basic unit as a card and a confirm
## button; it copies the most common basic unit, so it always matches the deck's Type and Race.
func _extra_basic_panel(order: Array, counts: Dictionary) -> Control:
	var pv: Array = _reward_panel("Add a basic unit", "Adds one more copy of your basic unit to your deck, for one pick.")
	var col: VBoxContainer = pv[1]
	var ids: Array = []
	for c in gs.view["deck"]:
		ids.append(int(c["id"]))
	var bid := Series.deck_basic(ids)
	if bid == -1:
		col.add_child(_info_chip("No basic units in your deck", false))
		return pv[0]
	var c: Dictionary = {}
	for o in order:
		if int(o["id"]) == bid:
			c = o
	var holder := CenterContainer.new()
	holder.custom_minimum_size = PREVIEW_CARD + Vector2(10, 10)
	col.add_child(holder)
	var cw := CardWidget.new().setup(MatchView.summary_view(c), "big")
	GameUi.resize_card(cw, PREVIEW_CARD)
	cw.tooltip_text = "Right-click to inspect"
	cw.right_pressed.connect(gs.inspect.inspect_widget)
	holder.add_child(cw)
	var have := int(counts.get(bid, 0))
	var ok := UIStyle.primary_button("Add another %s (%s): %d → %d" % [c["name"], c["type"], have, have + 1], 15)
	ok.custom_minimum_size = Vector2(0, 40)
	ok.clip_text = true
	ok.pressed.connect(func():
		mode = ""
		gs.send({"t": "reward_extra_basic"}))
	col.add_child(ok)
	return pv[0]


func _basic_change_panel(r: Dictionary, order: Array, counts: Dictionary) -> Control:
	var pv: Array = _reward_panel("Change basic units", "Choose a Type and a Race. Every basic unit in your deck becomes that unit, for one pick.")
	var col: VBoxContainer = pv[1]
	var basics := order.filter(func(c): return c["category"] == "basic_unit")
	if basics.is_empty():
		col.add_child(_info_chip("No basic units in your deck", false))
		return pv[0]
	var n := 0
	var ids := []
	for c in basics:
		n += int(counts[c["id"]])
		ids.append(int(c["id"]))
	if _basic_type == "" or _basic_race == "":
		_basic_type = String(basics[0]["type"])
		_basic_race = String(basics[0]["race"])
	var now := HFlowContainer.new()
	now.alignment = FlowContainer.ALIGNMENT_CENTER
	now.add_theme_constant_override("h_separation", 8)
	now.add_theme_constant_override("v_separation", 6)
	col.add_child(now)
	var cap := section_caption("In your deck")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	now.add_child(cap)
	for c in basics:
		now.add_child(GameUi.pill("%s (%s) ×%d" % [c["name"], c["type"], counts[c["id"]]], UIStyle.type_color(c["type"]), 14))
	var picker := BasicUnitPicker.new(r.get("basic_types", []), r.get("basic_races", []), r.get("basic_options", []), _basic_type, _basic_race, ids, true)
	col.add_child(picker)
	var ok := UIStyle.primary_button("", 15)
	ok.custom_minimum_size = Vector2(0, 40)
	ok.clip_text = true
	col.add_child(ok)
	var sync := func():
		var c: Dictionary = picker.chosen()
		var same: bool = not c.is_empty() and ids.size() == 1 and int(ids[0]) == int(c["id"])
		ok.disabled = c.is_empty() or same
		if c.is_empty():
			ok.text = "Choose a Type and a Race"
		elif same:
			ok.text = "Your basic units are already %s (%s)" % [c["name"], c["type"]]
		else:
			ok.text = "Change %d basic unit%s to %s (%s)" % [n, "" if n == 1 else "s", c["name"], c["type"]]
	sync.call()
	picker.changed.connect(func(t, rc):
		_basic_type = t
		_basic_race = rc
		sync.call())
	ok.pressed.connect(func():
		var cmd := {"t": "reward_basic", "to_type": _basic_type, "to_race": _basic_race}
		_basic_type = ""
		_basic_race = ""
		mode = ""
		gs.send(cmd))
	return pv[0]
