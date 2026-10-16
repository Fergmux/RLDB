class_name GameRewardPanels
extends RefCounted
## Rewards stage of the series modal: picks remaining, the three reward kinds (add / remove /
## change a basic unit) and the offer of new cards. Local choices that are not sent yet (which
## reward is open, the card to remove, the basic unit being changed) live here.

var gs: GameScreen

## Reward being set up ("", "add", "remove", "basic").
var mode: String = ""
var _remove_sel: int = -1
## Basic-unit change being composed (unit id, chosen Race and Type).
var _basic_sel: int = -1
var _basic_race: String = ""
var _basic_type: String = ""


func _init(screen: GameScreen) -> void:
	gs = screen


## Fills the modal with the rewards stage.
func render() -> void:
	var box := gs.overlays.overlay_box
	var line := gs.overlays.game_result_line()
	if line != "":
		box.add_child(UIStyle.label(line, 16, UIStyle.TEXT, true))
	var r: Dictionary = gs.view["rewards"]
	if r["done"]:
		box.add_child(UIStyle.label("You have finished choosing rewards. Waiting for your opponent…" if not r["opponent_done"] else "Starting soon…", 17, UIStyle.TEXT, true))
		for t in r["taken"]:
			box.add_child(UIStyle.label("• " + t, 14, UIStyle.MUTED))
		return
	# Picks remaining
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 12)
	box.add_child(pr)
	var total: int = r["left"] + r["taken"].size() + (1 if r.get("pending", false) else 0)
	var pips_c := PickPips.new()
	pips_c.left = r["left"]
	pips_c.total = maxi(total, r["left"])
	pips_c.custom_minimum_size = Vector2(maxf(28.0, pips_c.total * 28.0 + 4.0), 28)
	pr.add_child(pips_c)
	pr.add_child(UIStyle.label("%d pick%s remaining" % [r["left"], "" if r["left"] == 1 else "s"], 20, UIStyle.ACCENT, false, true))
	if r["opponent_done"]:
		box.add_child(UIStyle.label("Your opponent has finished.", 13, UIStyle.MUTED))
	for t in r["taken"]:
		box.add_child(UIStyle.label("✓ " + t, 14, UIStyle.GOOD))
	if r.get("pending", false):
		_render_offer(r)
		return
	# Three reward buttons; the chosen one opens its panel below, which closes again once confirmed.
	var modes := [["add", "Add a card", "Choose a card type, then take one of three cards."],
		["remove", "Remove a card", "Take one card out of your deck."],
		["basic", "Change a basic unit", "Give a basic unit a new Race and Type (all copies)."]]
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 12)
	box.add_child(mrow)
	for md in modes:
		var on: bool = mode == md[0]
		var mb: Button = UIStyle.primary_button(md[1], 18) if on else UIStyle.button(md[1], 18)
		mb.custom_minimum_size = Vector2(0, 56)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.tooltip_text = md[2]
		var key: String = md[0]
		mb.pressed.connect(func():
			mode = "" if mode == key else key
			_remove_sel = -1
			_basic_sel = -1
			gs.overlays.refresh())
		mrow.add_child(mb)
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
		_: box.add_child(UIStyle.label("Each pick is one of these three rewards. Choose one to see its options.", 14, UIStyle.MUTED, true))
	var fin := UIStyle.primary_button("Finish rewards" if not r["taken"].is_empty() else "Skip remaining rewards", 16)
	fin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fin.pressed.connect(func(): gs.send({"t": "reward_finish"}))
	box.add_child(fin)


## The type was chosen and the pick is spent: one of the offered cards must be taken.
func _render_offer(r: Dictionary) -> void:
	var box := gs.overlays.overlay_box
	var tname: String = UIStyle.CATEGORY_NAMES.get(String(r.get("offer_type", "")), "card")
	box.add_child(UIStyle.label("Choose your new %s" % tname, 22, UIStyle.GOLD, false, true))
	box.add_child(UIStyle.label("Take one of these cards.", 14, UIStyle.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 10)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER   # the offered cards sit centred in the modal
	box.add_child(flow)
	for i in r["offer"].size():
		var c: Dictionary = r["offer"][i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		var cw := CardWidget.new().setup(MatchView.summary_view(c), "big")
		GameUi.resize_card(cw, Vector2(200, 300))
		var idx: int = i
		cw.pressed.connect(func(_w): gs.send({"t": "reward_add", "index": idx}))
		cell.add_child(cw)
		var b := UIStyle.primary_button("Take %s" % c["name"], 14)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(200, 34)
		b.pressed.connect(func(): gs.send({"t": "reward_add", "index": idx}))
		cell.add_child(b)
		flow.add_child(cell)


## A titled sub-panel of the rewards screen: returns [panel, content VBox].
static func _reward_panel(title: String, note: String) -> Array:
	var pc := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.06, 0.05, 0.045, 0.9), Color(UIStyle.GOLD, 0.45), 1, 10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 14)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(UIStyle.label(title, 18, UIStyle.GOLD, false, true))
	if note != "":
		v.add_child(UIStyle.label(note, 14, UIStyle.MUTED, true))
	return [pc, v]


## Add a card: choose the type first (this spends the pick), then one of three cards of it.
func _reward_add_panel(r: Dictionary) -> Control:
	var pv: Array = _reward_panel("Add a card — choose a type", "Choosing a type uses this pick; then take one of three cards.")
	var tf := HFlowContainer.new()
	tf.add_theme_constant_override("h_separation", 10)
	tf.add_theme_constant_override("v_separation", 10)
	pv[1].add_child(tf)
	for cat in r.get("types", []):
		var col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.BRONZE)
		var tb := UIStyle.button(String(UIStyle.CATEGORY_NAMES.get(cat, cat)), 16)
		tb.custom_minimum_size = Vector2(124, 42)
		var nrm := UIStyle.flat(Color(col.darkened(0.62), 0.97), col, 2, 8)
		var hov := UIStyle.flat(Color(col.darkened(0.45), 0.99), col.lightened(0.3), 2, 8)
		UIStyle.lift_style(nrm, Color(0, 0, 0, 0.5), 4, 2)
		UIStyle.lift_style(hov, Color(col, 0.4), 9, 0)
		tb.add_theme_stylebox_override("normal", nrm)
		tb.add_theme_stylebox_override("hover", hov)
		tb.add_theme_stylebox_override("pressed", hov)
		tb.add_theme_color_override("font_color", UIStyle.category_text_color(cat).lightened(0.2))
		tb.add_theme_color_override("font_hover_color", Color.WHITE)
		tb.tooltip_text = "Uses one pick: shows three %s cards and you take one." % String(UIStyle.CATEGORY_NAMES.get(cat, cat))
		var c2: String = cat
		tb.pressed.connect(func():
			mode = ""
			gs.send({"t": "reward_type", "category": c2}))
		tf.add_child(tb)
	return pv[0]


## Remove a card: pick it from the list (preview on the right), then Confirm.
func _reward_remove_panel(order: Array, counts: Dictionary) -> Control:
	var pv: Array = _reward_panel("Remove a card from your deck", "Choose a card, then confirm. One copy is removed.")
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 14)
	pv[1].add_child(lr)
	var lsc := ScrollContainer.new()
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lsc.custom_minimum_size = Vector2(0, 300)
	lsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_child(lsc)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 4)
	lsc.add_child(GameUi.glow_room(lv, 6))
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
	GameUi.resize_card(prev, Vector2(180, 270))
	right.add_child(prev)
	for c in order:
		var on: bool = int(c["id"]) == _remove_sel
		var label: String = "%s%s" % [c["name"], " ×%d" % counts[c["id"]] if counts[c["id"]] > 1 else ""]
		var b2: Button = UIStyle.primary_button(label, 15) if on else UIStyle.button(label, 15)
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.clip_text = true
		var cc: Dictionary = c
		b2.mouse_entered.connect(func():
			prev.setup(MatchView.summary_view(cc), "big")
			GameUi.resize_card(prev, Vector2(180, 270)))
		b2.pressed.connect(func():
			_remove_sel = int(cc["id"])
			gs.overlays.refresh())
		lv.add_child(b2)
	var ok := UIStyle.primary_button("Confirm removal" if _remove_sel == -1 else "Remove %s" % String(shown.get("name", "")), 15)
	ok.disabled = _remove_sel == -1
	ok.custom_minimum_size = Vector2(180, 38)
	var rid := _remove_sel
	ok.pressed.connect(func():
		mode = ""
		_remove_sel = -1
		gs.send({"t": "reward_remove", "card_id": rid}))
	right.add_child(ok)
	return pv[0]


## Basic-unit change: pick one of your basic units, then a Race and a Type, then Confirm.
## Applies to every copy.
func _basic_change_panel(r: Dictionary, order: Array, counts: Dictionary) -> Control:
	var pv: Array = _reward_panel("Change a basic unit", "Choose a unit, then its new Race and Type. Applies to all copies.")
	var right: VBoxContainer = pv[1]
	var basics := order.filter(func(c): return c["category"] == "basic_unit")
	if basics.is_empty():
		right.add_child(UIStyle.label("No basic units in your deck.", 14, UIStyle.MUTED))
		return pv[0]
	var sel: Dictionary = {}
	for c in basics:
		if int(c["id"]) == _basic_sel:
			sel = c
	var uf := HFlowContainer.new()
	uf.add_theme_constant_override("h_separation", 4)
	uf.add_theme_constant_override("v_separation", 4)
	right.add_child(uf)
	for c in basics:
		var on: bool = int(c["id"]) == _basic_sel
		var ub: Button = UIStyle.primary_button("%s ×%d" % [c["name"], counts[c["id"]]], 14) if on else UIStyle.button("%s ×%d" % [c["name"], counts[c["id"]]], 14)
		var cc: Dictionary = c
		ub.pressed.connect(func():
			_basic_sel = int(cc["id"])
			_basic_race = String(cc["race"])
			_basic_type = String(cc["type"])
			gs.overlays.refresh())
		uf.add_child(ub)
	if sel.is_empty():
		return pv[0]
	for pair in [["Race", r.get("basic_races", []), "_basic_race"], ["Type", r.get("basic_types", []), "_basic_type"]]:
		right.add_child(UIStyle.label(pair[0], 14, UIStyle.GOLD))
		var rf := HFlowContainer.new()
		rf.add_theme_constant_override("h_separation", 4)
		rf.add_theme_constant_override("v_separation", 4)
		right.add_child(rf)
		for val in pair[1]:
			var key: String = pair[2]
			var cur: String = String(get(key))
			var chosen: bool = String(val) == cur
			var vb := UIStyle.button(("✓ " if chosen else "") + String(val), 14)
			if pair[0] == "Type":
				vb.add_theme_color_override("font_color", UIStyle.type_color(val).lightened(0.35))
			if chosen:
				vb.add_theme_stylebox_override("normal", UIStyle.flat(Color(UIStyle.GOLD, 0.22), UIStyle.GOLD_HI, 2, 6))
			var v2: String = String(val)
			vb.pressed.connect(func():
				set(key, v2)
				gs.overlays.refresh())
			rf.add_child(vb)
	var same: bool = _basic_race == String(sel["race"]) and _basic_type == String(sel["type"])
	var ok := UIStyle.primary_button("Confirm: Basic %s (%s)" % [_basic_race, _basic_type] if not same else "Choose a new Race or Type", 15)
	ok.disabled = same
	var fid: int = int(sel["id"])
	ok.pressed.connect(func():
		var cmd := {"t": "reward_basic", "from_id": fid, "to_type": _basic_type, "to_race": _basic_race}
		_basic_sel = -1
		mode = ""
		gs.send(cmd))
	right.add_child(ok)
	return pv[0]
