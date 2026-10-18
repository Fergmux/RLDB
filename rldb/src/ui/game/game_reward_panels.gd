class_name GameRewardPanels
extends RefCounted
## Rewards stage of the series modal (F04-03): picks remaining as gems, the reward kinds as
## illustrated tiles (add / remove / change basic units / add a basic unit), the sub-panel of the open reward and the
## offer of new cards. Local choices that are not sent yet (which reward is open, the card to
## remove, the basic-unit Type and Race) live here.

const OFFER_CARD := Vector2(168, 252)
const PREVIEW_CARD := Vector2(150, 225)

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


func _init(screen: GameScreen) -> void:
	gs = screen


## Fills the modal with the rewards stage.
func render() -> void:
	var box := gs.overlays.overlay_box
	var line := gs.overlays.game_result_line()
	if line != "":
		box.add_child(_result_plate(line))
	var r: Dictionary = gs.view["rewards"]
	if r["done"]:
		var p := gs.me()
		var chips := [{"text": "You: rewards chosen", "done": true},
			{"text": "%s: %s" % [String(gs.view["names"][1 - p]), "rewards chosen" if r["opponent_done"] else "choosing rewards…"], "done": r["opponent_done"]}]
		box.add_child(WaitPlate.new("Rewards chosen", "Starting soon…" if r["opponent_done"] else "Waiting for your opponent…", chips, not r["opponent_done"]))
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
	# The reward kinds as illustrated tiles; the open one shows its panel below.
	var modes := [["add", "Add a card", "Pick a card type, then take one of three.", "add", UIStyle.GOOD.darkened(0.15)],
		["remove", "Remove a card", "Take one card out of your deck.", "remove", UIStyle.BAD],
		["basic", "Change basic units", "Every basic unit becomes a new Type and Race.", "swap", UIStyle.RUNE_BLUE],
		["extra_basic", "Add a basic unit", "One more copy of your basic unit, same Type and Race.", "add", UIStyle.GOLD.darkened(0.25)]]
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 10)
	box.add_child(mrow)
	for md in modes:
		var key: String = md[0]
		var tile := ChoiceTile.new(md[1], md[2] if mode == "" else "", md[4], md[3])
		tile.selected = mode == key
		tile.custom_minimum_size = Vector2(0, 150 if mode == "" else 0)
		tile.tooltip_text = md[2]
		tile.pressed.connect(func():
			mode = "" if mode == key else key
			_remove_sel = -1
			_basic_type = ""
			_basic_race = ""
			gs.overlays.refresh())
		mrow.add_child(tile)
	var counts := {}
	var order := []
	for c in gs.view["deck"]:
		if not counts.has(c["id"]):
			order.append(c)
		counts[c["id"]] = counts.get(c["id"], 0) + 1
	match mode:
		"add": box.add_child(_reward_add_panel(r))
		"remove": box.add_child(_reward_remove_panel(order, counts))
		"basic": box.add_child(_basic_change_panel(r, order, counts))
		"extra_basic": box.add_child(_extra_basic_panel(order, counts))
	box.add_child(_footer(true, r))


# ------------------------------------------------------------------ pieces
func _result_plate(line: String) -> Control:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.05, 0.04, 0.03, 0.8), Color(UIStyle.BRONZE, 0.7), 1, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var l := UIStyle.label(line, 15, UIStyle.MUTED, true)
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
	var cap := UIStyle.label("PICKS", 12, UIStyle.TEXT_DIM, false, true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## Rewards already taken this round, one ticked chip each.
func _taken_flow(taken: Array) -> Control:
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_CENTER
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 6)
	for t in taken:
		f.add_child(_info_chip(String(t), true))
	return f


## Bottom row: View your deck, then Finish / Skip (when `with_finish`).
func _footer(with_finish: bool, r: Dictionary = {}) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), true, 12.0))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	if gs.view.has("deck"):
		var see := UIStyle.button("View your deck", 15)
		see.custom_minimum_size = Vector2(190, 40)
		var g := DeckSelectView.TabGlyph.new("tome", UIStyle.GOLD)
		g.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		g.offset_left = 12
		g.offset_right = 34
		g.offset_top = -12
		g.offset_bottom = 12
		see.add_child(g)
		see.pressed.connect(gs.overlays._show_deck)
		h.add_child(see)
	if with_finish:
		var fin := UIStyle.primary_button("Finish rewards" if not r["taken"].is_empty() else "Skip remaining rewards", 16)
		fin.custom_minimum_size = Vector2(230, 40)
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
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 12)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER   # the offered cards sit centred in the modal
	box.add_child(flow)
	var sig := offer_sig(r)
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
		cw.pressed.connect(func(_w): take_offer(idx, sig))
		cw.right_pressed.connect(gs.inspect.inspect_widget)
		cw.mouse_entered.connect(func(): gs.overlays._lift(cw, 1.05))
		cw.mouse_exited.connect(func(): gs.overlays._lift(cw, 1.0))
		holder.add_child(cw)
		flow.add_child(holder)
	box.add_child(_footer(false))


## Signature of an offer: which cards, and how many picks are left (a new offer differs).
static func offer_sig(r: Dictionary) -> int:
	return hash([r.get("offer", []), r.get("left", 0), r.get("taken", []).size()])


## Takes offered card `idx` of the offer `sig` through the normal reward command. A repeated
## click on the same offer (double click, click during the round trip) sends nothing; after 2 s
## without an answer (a rejected take) the offer can be clicked again.
func take_offer(idx: int, sig: int) -> bool:
	var now := Time.get_ticks_msec()
	if sig == _took_sig and now - _took_at < 2000:
		return false
	var r: Dictionary = gs.view.get("rewards", {})
	if not r.get("pending", false) or offer_sig(r) != sig or idx < 0 or idx >= r.get("offer", []).size():
		return false
	_took_sig = sig
	_took_at = now
	Sfx.play("confirm")
	gs.send({"t": "reward_add", "index": idx})
	return true


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
	var t := UIStyle.label(title, 18, UIStyle.GOLD, false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
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
	var cap := UIStyle.label("IN YOUR DECK", 12, UIStyle.GOLD, false, true)
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
