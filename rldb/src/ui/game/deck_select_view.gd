class_name DeckSelectView
extends RefCounted
## "Choose your deck" stage of the series modal (F04-02): lobby bar, Structured / Custom tabs,
## uniform deck tiles in a smooth scrolling plate, the locked-in waiting state, the F06-05 / F06-06
## draft setup (basic unit, category order, pick sequence) and the draft offer.
## Renders into the overlay's content box; sends commands through the host screen.

## Size of the chosen basic unit's card in the draft setup.
const SETUP_CARD := Vector2(180, 270)

## Which tab is open: "structured" (starter decks) or "custom" (saved decks).
var tab: String = "structured"
## The ScrollArea holding the tiles (null when this stage shows no list); the overlay sizes to it.
var list_area: ScrollArea
var ov: GameSeriesOverlay

## Draft setup being composed locally (F06-05 / F06-06) until "Start drafting" sends it:
## the category order and the basic unit's Type and Race. `_setup_for` names the series and seat
## it belongs to, so a new series starts from that seat's defaults.
var _setup_for: String = ""
var _order: Array = []
var _btype: String = ""
var _brace: String = ""
## [category, "up" / "down"]: the arrow to focus again after a keyboard move (the list rebuilds).
var _focus_after: Array = []
## The Choose basic unit picker (a HousePanel over a dim), or null while closed.
var _picker_dim: ColorRect


func _init(overlay: GameSeriesOverlay) -> void:
	ov = overlay


## Fills the overlay for the deck stage. Returns true when the content is a fixed-height layout
## (a scrolling list), false when the modal should shrink to its content.
func render() -> bool:
	list_area = null
	_tiles.clear()
	var gs := ov.gs
	var view := gs.view
	var p := gs.me()
	var box := ov.overlay_box
	_lobby_bar(box)
	if view["deck_ready"][p]:
		_waiting(box)
		return false
	if view.has("starters"):
		_close_picker()
		_tabs_and_list(box)
		return true
	if not view["draft"].get("setup_done", true):
		_draft_setup(box)
		return false
	_close_picker()
	_draft(box)
	return false


# ---------------------------------------------------------------- lobby (online host)
func _lobby_bar(box: VBoxContainer) -> void:
	var gs := ov.gs
	var net: Dictionary = gs.view.get("net", {})
	if net.is_empty() or not net.get("is_host", false) or net.get("opponent_connected", true):
		return
	var plate := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.1, 0.08, 0.045, 0.95), Color(UIStyle.GOLD, 0.7), 1, 9)
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	plate.add_theme_stylebox_override("panel", sb)
	box.add_child(plate)
	var lob := HBoxContainer.new()
	lob.add_theme_constant_override("separation", 12)
	plate.add_child(lob)
	var dot := WaitPlate.StatusDot.new(false)
	lob.add_child(dot)
	var msg := UIStyle.label(net.get("message", "Waiting for an opponent to join…"), 16, UIStyle.ACCENT, true)
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lob.add_child(msg)
	if net.get("transport", "") == "steam":
		var inv := UIStyle.primary_button("Invite", 15)
		inv.tooltip_text = "Invite a Steam friend to this lobby."
		inv.pressed.connect(func(): gs.get_tree().call_group("net_session", "invite_friend"))
		lob.add_child(inv)


# ---------------------------------------------------------------- waiting (deck locked in)
func _waiting(box: VBoxContainer) -> void:
	var gs := ov.gs
	var view := gs.view
	var p := gs.me()
	var opp_ready: bool = view["deck_ready"][1 - p]
	var opp_doing := "choosing a deck…"
	if view.has("draft"):
		opp_doing = _opponent_doing(view["draft"])
	var chips := [
		{"text": "%s: deck locked in" % String(view["names"][p]), "done": true},
		{"text": "%s: %s" % [String(view["names"][1 - p]), "deck locked in" if opp_ready else opp_doing], "done": opp_ready},
	]
	var wp := WaitPlate.new("Deck locked in", "You will play %s.\nWaiting for your opponent…" % String(view["deck_name"]) if not opp_ready else "You will play %s.\nStarting soon…" % String(view["deck_name"]), chips)
	box.add_child(wp)


# ---------------------------------------------------------------- tabs + tiles
func _tabs_and_list(box: VBoxContainer) -> void:
	var gs := ov.gs
	var view := gs.view
	var starters: Array = view["starters"]
	var custom_ok: bool = view.get("deck_mode", "starter") != "draft"
	var saved: Array = DeckStore.list() if custom_ok else []
	if tab == "custom" and not custom_ok:
		tab = "structured"
	# Tabs sit on the plate's top edge.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	tabs.add_child(_tab_button("structured", "Structured", starters.size(), "shield"))
	if custom_ok:
		tabs.add_child(_tab_button("custom", "Custom", saved.size(), "tome"))
	var hint := UIStyle.label("Starter decks, ready to play" if tab == "structured" else "Decks you built and saved", 14, UIStyle.TEXT_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	tabs.add_child(hint)
	# Plate with the scrolling tile list.
	var plate := PanelContainer.new()
	var psb := UIStyle.flat(Color(0.035, 0.03, 0.026, 0.82), Color(UIStyle.BRONZE, 0.75), 2, 8)
	for s in [SIDE_LEFT, SIDE_TOP, SIDE_BOTTOM]:
		psb.set_content_margin(s, 8)
	psb.set_content_margin(SIDE_RIGHT, 6)
	plate.add_theme_stylebox_override("panel", psb)
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(plate)
	var area := ScrollArea.new()
	area.custom_minimum_size = Vector2(0, 220)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plate.add_child(area)
	list_area = area
	var inner := MarginContainer.new()
	# F01: the content fills the plate's height, so a sparse or empty tab keeps the same plate and
	# its empty-state panel sits in the middle of it.
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_right", 8)
	inner.add_theme_constant_override("margin_top", 4)
	inner.add_theme_constant_override("margin_bottom", 4)
	inner.add_theme_constant_override("margin_left", 2)
	area.set_content(inner)
	var wide: bool = ov.modal_width() >= 1000.0
	var grid := GridContainer.new()
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(grid)
	if tab == "structured":
		for i in starters.size():
			var s: Dictionary = starters[i]
			var idx: int = i
			_add_tile(grid, "s%d" % i, s["name"], s["theme"], s["main"], s["extra"], "Choose deck", func(): ov.gs.send({"t": "pick_starter", "index": idx}))
	elif saved.is_empty():
		inner.remove_child(grid)
		grid.queue_free()
		inner.add_child(_empty_custom())
	else:
		var n := 0
		for d in saved:
			var main := []
			var extra := []
			for id in d["cards"]:
				var def := CardDB.get_def(int(id))
				if def.is_empty():
					continue
				var sm := Series.card_summary(int(id))
				if CardDB.is_extra_category(def["category"]):
					extra.append(sm)
				else:
					main.append(sm)
			var deck: Dictionary = d
			_add_tile(grid, "c%d" % n, d["name"], "Saved custom deck", main, extra, "Use this deck", func(): ov.gs.send({"t": "custom_deck", "cards": deck["cards"], "name": deck["name"]}), DeckStore.validate(deck["cards"]))
			n += 1


func _add_tile(grid: GridContainer, id: String, title: String, theme: String, main: Array, extra: Array, btn: String, on_pick: Callable, blocked: String = "") -> void:
	var t := DeckTile.new({"title": title, "theme": theme, "main": main, "extra": extra, "btn_text": btn, "open": ov.deck_open.get(id, false), "blocked": blocked})
	t.chosen.connect(on_pick)
	t.toggled.connect(func(): _toggle_tile(id))
	_tiles[id] = t
	grid.add_child(t)


## Opens tile `id`'s full card list (closing any other) or closes it. G02: the tiles change in
## place; rebuilding the modal reset every tile's rim and glow and the list's scroll for a frame
## or two, which showed as a flash on both opening and closing.
func _toggle_tile(id: String) -> void:
	var was: bool = ov.deck_open.get(id, false)
	for k in ov.deck_open.keys():
		var other = _tiles.get(k)
		if other != null and is_instance_valid(other):
			other.set_open(false)
	ov.deck_open.clear()
	ov.deck_open[id] = not was
	var t = _tiles.get(id)
	if t == null or not is_instance_valid(t):
		_remember_scroll()
		ov.refresh()
		return
	t.set_open(not was)
	ov.mark_rendered()


## Keeps the list where it is across the re-render a selection causes.
func _remember_scroll() -> void:
	if list_area != null and is_instance_valid(list_area):
		_saved_scroll = list_area.scroll.scroll_vertical


var _saved_scroll: int = 0
## Deck tiles of the shown list by id ("s0", "c1", ...), for opening and closing in place.
var _tiles: Dictionary = {}


## Re-applies the remembered scroll position once the new list has been laid out.
func restore_scroll() -> void:
	if list_area == null or _saved_scroll == 0:
		return
	var a := list_area
	if not a.is_inside_tree():
		return
	var tree := a.get_tree()
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(a):
		a.scroll.scroll_vertical = _saved_scroll
		a.scroll.scroll_to(float(_saved_scroll))
	_saved_scroll = 0


func _empty_custom() -> Control:
	var wp := OrnatePanel.new(10, 22)
	wp.arm = 14.0
	wp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	wp.add_child(v)
	var g := TabGlyph.new("tome", UIStyle.GOLD)
	g.custom_minimum_size = Vector2(64, 64)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(g)
	var t := UIStyle.label("No saved decks yet", 22, UIStyle.GOLD, false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UIStyle.label("Decks you build and save in the Deck Builder appear here, ready to play. Until then, pick a Structured deck.", 15, UIStyle.MUTED, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var go := UIStyle.button("Show Structured decks", 14)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func():
		tab = "structured"
		ov.refresh())
	v.add_child(go)
	return wp


func _tab_button(key: String, text: String, count: int, glyph: String) -> Button:
	var on: bool = tab == key
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(190, 46)
	var fills := {"normal": Color(0.085, 0.07, 0.056, 0.95), "hover": Color(0.14, 0.11, 0.075, 0.98), "pressed": Color(0.07, 0.057, 0.04, 0.98)}
	for k in fills:
		var sb := UIStyle.flat(fills[k], UIStyle.BRONZE, 2, 10)
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		if on:
			sb = UIStyle.flat(Color(0.2, 0.15, 0.08, 0.99), UIStyle.GOLD, 2, 10)
			sb.corner_radius_bottom_left = 0
			sb.corner_radius_bottom_right = 0
			UIStyle.lift_style(sb, Color(UIStyle.GOLD, 0.35), 10, 0)
		elif k == "hover":
			sb.border_color = UIStyle.GOLD
		sb.border_width_bottom = 0
		b.add_theme_stylebox_override(k, sb)
	b.pressed.connect(func():
		if tab != key:
			tab = key
			ov.deck_open.clear()
			ov.refresh())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var g := TabGlyph.new(glyph, UIStyle.GOLD_HI if on else UIStyle.BRONZE.lightened(0.35))
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(g)
	var l := UIStyle.label(text, 18, UIStyle.GOLD_HI if on else UIStyle.MUTED, false, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	var cp := GameUi.pill(str(count), UIStyle.GOLD if on else UIStyle.BRONZE, 13)
	cp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(cp)
	return b


# ---------------------------------------------------------------- draft
func _draft(box: VBoxContainer) -> void:
	var gs := ov.gs
	var dr: Dictionary = gs.view["draft"]
	var cat := String(dr["category"])
	var col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.GOLD)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 14)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(strip)
	var pips := DraftPips.new(int(dr["step"]), int(dr["total"]))
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(pips)
	strip.add_child(UIStyle.label("Pick %d of %d" % [dr["step"] + 1, dr["total"]], 18, UIStyle.TEXT, false, true))
	var chip := GameUi.pill(String(dr.get("category_label", cat.capitalize())), col, 16)
	strip.add_child(chip)
	# F06-05 / F06-06: this seat's order and its chosen basic unit, then the other seat's progress.
	var info := HFlowContainer.new()
	info.alignment = FlowContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("h_separation", 10)
	info.add_theme_constant_override("v_separation", 6)
	box.add_child(info)
	var b: Dictionary = dr.get("basic", {})
	if not b.is_empty() and int(dr.get("basic_copies", 0)) > 0:
		info.add_child(GameUi.pill("%s (%s) ×%d" % [b["name"], b["type"], int(dr["basic_copies"])], UIStyle.type_color(b["type"]), 14))
	var labels: Dictionary = dr.get("labels", {})
	var q: Dictionary = dr.get("quota", {})
	var parts := []
	for c in dr.get("cat_order", []):
		parts.append("%d %s" % [int(q.get(c, 0)), String(labels.get(c, c))])
	if not parts.is_empty():
		info.add_child(UIStyle.label("Your order: " + "  ›  ".join(parts), 14, UIStyle.MUTED))
	var od: Dictionary = dr.get("opponent", {})
	if not od.is_empty() and not gs.view["deck_ready"][1 - gs.me()]:
		info.add_child(ov.rewards._info_chip("%s %s" % [String(gs.view["names"][1 - gs.me()]), _opponent_doing(dr)], false))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for i in dr["offer"].size():
		var c: Dictionary = dr["offer"][i]
		var colm := CenterContainer.new()
		colm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colm.custom_minimum_size = Vector2(0, GameSeriesOverlay.DRAFT_CARD_ROOM)
		row.add_child(colm)
		var cw := CardWidget.new().setup(MatchView.summary_view(c), "big")
		cw.tooltip_text = "Pick %s" % c["name"]
		var idx: int = i
		cw.pressed.connect(func(_w): gs.send({"t": "draft_pick", "index": idx}))
		cw.right_pressed.connect(gs.inspect.inspect_widget)
		cw.mouse_entered.connect(func(): ov._lift(cw, GameSeriesOverlay.DRAFT_HOVER_SCALE))
		cw.mouse_exited.connect(func(): ov._lift(cw, 1.0))
		colm.add_child(cw)


# ---------------------------------------------------------------- draft setup (F06-05 / F06-06)

## What the other seat is doing in a draft (its progress only; its offers are never sent).
func _opponent_doing(dr: Dictionary) -> String:
	var od: Dictionary = dr.get("opponent", {})
	if od.is_empty():
		return "drafting…"
	if not od.get("setup_done", false):
		return "is setting up their draft…"
	return "is drafting (pick %d of %d)…" % [mini(int(od["step"]) + 1, int(od["total"])), int(od["total"])]


## Starts the local setup from the seat's defaults when the series or seat changed.
func _sync_setup(dr: Dictionary) -> void:
	var key := "%s#%d" % [String(ov.gs.view.get("save_id", "")), ov.gs.me()]
	var cats: Array = dr.get("cat_order", [])
	var same_set := _order.size() == cats.size() and cats.all(func(c): return c in _order)
	if key == _setup_for and same_set:
		return
	_setup_for = key
	_order = cats.duplicate()
	var b: Dictionary = dr.get("basic", {})
	_btype = String(b.get("type", ""))
	_brace = String(b.get("race", ""))


## The card summary of the locally chosen basic unit ({} when there is none).
func _chosen_basic(dr: Dictionary) -> Dictionary:
	for c in dr.get("basic_options", []):
		if String(c["type"]) == _btype and String(c["race"]) == _brace:
			return c
	return {}


## The setup screen: the basic unit (left), the orderable categories (right), the resulting pick
## sequence, then Start drafting. The other seat's progress is shown above.
func _draft_setup(box: VBoxContainer) -> void:
	var gs := ov.gs
	var dr: Dictionary = gs.view["draft"]
	_sync_setup(dr)
	var intro := UIStyle.label("Before the picks begin, choose your basic unit and the order you draft the categories in. Each player sets up their own draft.", 15, UIStyle.TEXT_DIM, true)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro)
	var opp_ready: bool = gs.view["deck_ready"][1 - gs.me()]
	box.add_child(ov.rewards._info_chip("%s %s" % [String(gs.view["names"][1 - gs.me()]), "has finished drafting" if opp_ready else _opponent_doing(dr)], opp_ready))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	box.add_child(cols)
	cols.add_child(_basic_plate(dr))
	# The order and the sequence it gives share the right-hand column, beside the basic unit.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_order_plate(dr))
	var sq := _sequence_plate(dr)
	sq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sq)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	box.add_child(foot)
	foot.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), true, 12.0))
	var go := UIStyle.primary_button("Start drafting", 18)
	go.custom_minimum_size = Vector2(280, 46)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var copies := int(dr.get("basic_copies", 0))
	var ready := copies <= 0 or not _chosen_basic(dr).is_empty()
	go.disabled = not ready
	go.tooltip_text = "Locks in your basic unit and category order, then the picks begin." if ready else "Choose a basic unit first."
	go.pressed.connect(func():
		_close_picker()
		var cmd := {"t": "draft_setup", "order": _order.duplicate()}
		if copies > 0:
			cmd["basic_type"] = _btype
			cmd["basic_race"] = _brace
		gs.send(cmd))
	foot.add_child(go)


## Left plate: the chosen basic unit as a real card, its copies and Choose basic unit.
func _basic_plate(dr: Dictionary) -> Control:
	var copies := int(dr.get("basic_copies", 0))
	var pv: Array = GameRewardPanels._reward_panel("Basic unit", "You get %d copies. They are not drafted picks." % copies if copies > 0 else "This draft gives no basic units.")
	var v: VBoxContainer = pv[1]
	pv[0].custom_minimum_size = Vector2(SETUP_CARD.x + 70.0, 0)
	if copies <= 0:
		return pv[0]
	var c := _chosen_basic(dr)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = SETUP_CARD + Vector2(14, 14)
	v.add_child(holder)
	var cw := CardWidget.new().setup(MatchView.summary_view(c) if not c.is_empty() else null, "big")
	GameUi.resize_card(cw, SETUP_CARD)
	cw.tooltip_text = "Right-click to inspect"
	cw.right_pressed.connect(ov.gs.inspect.inspect_widget)
	cw.pressed.connect(func(_w): _open_picker(dr))
	cw.mouse_entered.connect(func(): ov._lift(cw, 1.04))
	cw.mouse_exited.connect(func(): ov._lift(cw, 1.0))
	holder.add_child(cw)
	if not c.is_empty():
		var nm := UIStyle.label("%s (%s) ×%d" % [c["name"], c["type"], copies], 16, UIStyle.GOLD_HI, false, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
	var choose := UIStyle.button("Choose basic unit", 15)
	choose.custom_minimum_size = Vector2(0, 40)
	choose.tooltip_text = "Pick its Type and Race"
	choose.pressed.connect(func(): _open_picker(dr))
	v.add_child(choose)
	return pv[0]


## Right plate: the categories in drafting order, reordered with each row's up / down arrows
## (owner answer 2026-10-17 §8: no drag-and-drop anywhere; the arrows work by mouse and keyboard).
func _order_plate(dr: Dictionary) -> Control:
	var pv: Array = GameRewardPanels._reward_panel("Draft order", "You draft these from top to bottom. Use the arrows to change the order.")
	var v: VBoxContainer = pv[1]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	v.add_child(list)
	var q: Dictionary = dr.get("quota", {})
	var labels: Dictionary = dr.get("labels", {})
	var focus_btn: Button = null
	for i in _order.size():
		var cat: String = _order[i]
		var row := OrderRow.new(cat, i + 1, String(labels.get(cat, cat.capitalize())), int(q.get(cat, 0)))
		list.add_child(row)
		var up := _arrow_button(true, "Move %s up" % String(labels.get(cat, cat)))
		up.disabled = i == 0
		up.pressed.connect(func(): _move(cat, -1))
		var down := _arrow_button(false, "Move %s down" % String(labels.get(cat, cat)))
		down.disabled = i == _order.size() - 1
		down.pressed.connect(func(): _move(cat, 1))
		row.tail.add_child(up)
		row.tail.add_child(down)
		if not _focus_after.is_empty() and _focus_after[0] == cat:
			var want: Button = up if _focus_after[1] == "up" else down
			focus_btn = want if not want.disabled else (down if want == up else up)
	if _order.is_empty():
		v.add_child(UIStyle.label("No categories to draft.", 14, UIStyle.MUTED))
	_focus_after = []
	if focus_btn != null:
		focus_btn.grab_focus.call_deferred()
	return pv[0]


func _arrow_button(up: bool, tip: String) -> Button:
	var b := UIStyle.button("", 13)
	b.custom_minimum_size = Vector2(36, 34)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	var g := ArrowGlyph.new(up)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(g)
	return b


## Keyboard / button move of a category by `delta` places.
func _move(cat: String, delta: int) -> void:
	var i := _order.find(cat)
	var j := clampi(i + delta, 0, _order.size() - 1)
	if i == -1 or j == i:
		return
	_order.remove_at(i)
	_order.insert(j, cat)
	_focus_after = [cat, "up" if delta < 0 else "down"]
	if ov != null:
		ov.refresh()


## The pick sequence of the current order: the basic unit first, then a bar of the categories with
## their pick numbers.
func _sequence_plate(dr: Dictionary) -> Control:
	var pv: Array = GameRewardPanels._reward_panel("Your pick sequence", "")
	var v: VBoxContainer = pv[1]
	var q: Dictionary = dr.get("quota", {})
	var labels: Dictionary = dr.get("labels", {})
	var segs := []
	var n := 0
	for cat in _order:
		var k := int(q.get(cat, 0))
		segs.append({"cat": cat, "from": n + 1, "to": n + k, "label": String(labels.get(cat, cat))})
		n += k
	var bar := SequenceBar.new(segs, n)
	v.add_child(bar)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	var c := _chosen_basic(dr)
	var copies := int(dr.get("basic_copies", 0))
	if copies > 0 and not c.is_empty():
		flow.add_child(GameUi.pill("First: %s (%s) ×%d" % [c["name"], c["type"], copies], UIStyle.type_color(c["type"]), 13))
	for sg in segs:
		var rng: String = "Pick %d" % sg["from"] if sg["from"] == sg["to"] else "Picks %d–%d" % [sg["from"], sg["to"]]
		flow.add_child(GameUi.pill("%s: %s" % [rng, sg["label"]], UIStyle.category_text_color(String(sg["cat"])), 13))
	var tot := UIStyle.label("%d picks in total, %d cards with the basic units" % [n, n + maxi(copies, 0)], 13, UIStyle.TEXT_DIM)
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tot)
	return pv[0]


## Opens the Type x Race picker over the series modal; Use takes the choice, Cancel / Esc /
## a click outside leave it unchanged.
func _open_picker(dr: Dictionary) -> void:
	_close_picker()
	var gs := ov.gs
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = UiLayers.MODAL_PICKER
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gs.add_child(dim)
	_picker_dim = dim
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_picker())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var copies := int(dr.get("basic_copies", 0))
	var hp := HousePanel.new("Choose basic unit", "×%d copies" % copies, Vector2(22, 18), 10)
	hp.arm = 18.0
	center.add_child(hp)
	hp.add_headline("Choose your basic unit", 24, true)
	var note := UIStyle.label("Pick a Type and a Race. You start your draft with %d copies of it." % copies, 14, UIStyle.TEXT_DIM, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(560, 0)
	hp.body.add_child(note)
	var picker := BasicUnitPicker.new(dr.get("basic_types", []), dr.get("basic_races", []), dr.get("basic_options", []), _btype, _brace)
	hp.body.add_child(picker)
	hp.body.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), true, 10.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	hp.body.add_child(row)
	var cancel := UIStyle.button("Cancel", 15)
	cancel.custom_minimum_size = Vector2(140, 40)
	var sc := Shortcut.new()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	sc.events = [esc]
	cancel.shortcut = sc
	cancel.pressed.connect(_close_picker)
	row.add_child(cancel)
	var use := UIStyle.primary_button("", 15)
	use.custom_minimum_size = Vector2(300, 40)
	row.add_child(use)
	var sync := func():
		var c: Dictionary = picker.chosen()
		use.disabled = c.is_empty()
		use.text = "Use %s (%s)" % [c["name"], c["type"]] if not c.is_empty() else "Choose a Type and a Race"
	sync.call()
	picker.changed.connect(func(_t, _r): sync.call())
	use.pressed.connect(func():
		_btype = picker.type
		_brace = picker.race
		_close_picker()
		ov.refresh())
	hp.appear()
	picker.focus_first.call_deferred()


## Closes the basic-unit picker, if open.
func _close_picker() -> void:
	if _picker_dim != null and is_instance_valid(_picker_dim):
		_picker_dim.queue_free()
	_picker_dim = null


## A category row of the draft order: position, icon, name and pick count, then its up / down
## arrow buttons (in `tail`). Rows are not draggable (owner answer 2026-10-17 §8): the arrows are
## the only way to reorder, by mouse or keyboard.
class OrderRow extends PanelContainer:
	var cat := ""
	var tail: HBoxContainer
	var _col := UIStyle.GOLD

	func _init(c: String, pos: int, title: String, count: int) -> void:
		cat = c
		_col = UIStyle.CATEGORY_COLORS.get(c, UIStyle.BRONZE)
		var sb := UIStyle.flat(Color(_col.darkened(0.82), 0.96), Color(_col.lightened(0.15), 0.7), 2, 9)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		add_theme_stylebox_override("panel", sb)
		mouse_filter = Control.MOUSE_FILTER_PASS
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		var num := UIStyle.label(str(pos), 20, UIStyle.GOLD_HI, false, true)
		num.custom_minimum_size = Vector2(22, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(num)
		var ic := ChoiceTile.Icon.new(c, _col, 34.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var nm := UIStyle.label(title, 18, UIStyle.TEXT, false, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(nm)
		var cp := GameUi.pill("%d pick%s" % [count, "" if count == 1 else "s"], UIStyle.category_text_color(c), 14)
		cp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		GameUi.ignore_mouse(cp)
		h.add_child(cp)
		tail = HBoxContainer.new()
		tail.add_theme_constant_override("separation", 4)
		h.add_child(tail)



## Up / down triangle drawn on an arrow button (dimmed while disabled).
class ArrowGlyph extends Control:
	var up := true

	func _init(u: bool) -> void:
		up = u
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var b := get_parent() as Button
		var col: Color = Color(UIStyle.GOLD_HI, 0.3) if b != null and b.disabled else UIStyle.GOLD_HI
		var c := size / 2.0
		var k := 7.0
		var pts := PackedVector2Array([c + Vector2(-k, k * 0.5), c + Vector2(k, k * 0.5), c + Vector2(0, -k * 0.6)]) if up \
			else PackedVector2Array([c + Vector2(-k, -k * 0.5), c + Vector2(k, -k * 0.5), c + Vector2(0, k * 0.6)])
		draw_colored_polygon(pts, col)


## The pick sequence as one bar: a segment per category (its colour, width by pick count) with the
## pick numbers where they fit.
class SequenceBar extends Control:
	var segs: Array = []
	var total := 1

	func _init(s: Array, t: int) -> void:
		segs = s
		total = maxi(t, 1)
		custom_minimum_size = Vector2(0, 30)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := UIStyle.font_display(700)
		var x := 0.0
		draw_style_box(UIStyle.flat(Color(0.03, 0.025, 0.02, 0.9), Color(UIStyle.BRONZE, 0.8), 1, 8), Rect2(Vector2.ZERO, size))
		for sg in segs:
			var n: int = int(sg["to"]) - int(sg["from"]) + 1
			if n <= 0:
				continue
			var w := (size.x - 4.0) * float(n) / float(total)
			var r := Rect2(Vector2(2.0 + x, 2.0), Vector2(w, size.y - 4.0))
			var col: Color = UIStyle.CATEGORY_COLORS.get(String(sg["cat"]), UIStyle.BRONZE)
			Ornate.vgradient(self, r.grow(-1.0), col.lightened(0.05), col.darkened(0.45))
			if x > 0.0:
				draw_line(r.position, r.position + Vector2(0, r.size.y), Color(0, 0, 0, 0.8), 2.0)
			var txt := String(sg["label"]) if n == 1 else "%s ×%d" % [String(sg["label"]), n]
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			if tw + 8.0 > w:
				txt = str(n)
				tw = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			if tw + 4.0 <= w:
				draw_string_outline(f, Vector2(r.position.x + (w - tw) / 2.0, r.position.y + r.size.y / 2.0 + 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.85))
				draw_string(f, Vector2(r.position.x + (w - tw) / 2.0, r.position.y + r.size.y / 2.0 + 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.97, 0.9))
			x += w


## Row of gems: picks made are filled, the current one glows, the rest are sockets.
class DraftPips extends Control:
	var step := 0
	var total := 1

	func _init(s: int, t: int) -> void:
		step = s
		total = maxi(t, 1)
		var n := mini(total, 14)
		custom_minimum_size = Vector2(n * 16.0, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := mini(total, 14)
		for i in n:
			var c := Vector2(8.0 + i * 16.0, size.y / 2.0)
			var idx := int(float(i) * total / n)
			if idx < step:
				Ornate.diamond(self, c, 6.5, UIStyle.GOLD.darkened(0.2))
			elif idx == step:
				Ornate.diamond(self, c, 8.0, Color(UIStyle.GOLD_HI, 0.35))
				Ornate.diamond(self, c, 6.0, UIStyle.GOLD_HI)
			else:
				Ornate.diamond(self, c, 6.0, Color(UIStyle.BRONZE, 0.5))
				Ornate.diamond(self, c, 3.5, Color(0.05, 0.04, 0.03, 1.0))


## Small vector glyph for the tabs: "shield" (Structured) or "tome" (Custom).
class TabGlyph extends Control:
	var kind := "shield"
	var col := UIStyle.GOLD

	func _init(k: String, c: Color) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(22, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if kind == "shield":
			var pts := PackedVector2Array([Vector2(0.1 * w, 0.06 * h), Vector2(0.9 * w, 0.06 * h), Vector2(0.9 * w, 0.52 * h), Vector2(0.5 * w, 0.96 * h), Vector2(0.1 * w, 0.52 * h)])
			draw_colored_polygon(pts, Color(col.darkened(0.55), 0.9))
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, col, 1.8, true)
			draw_line(Vector2(0.5 * w, 0.2 * h), Vector2(0.5 * w, 0.72 * h), col, 1.5, true)
		else:
			var r := Rect2(0.1 * w, 0.08 * h, 0.8 * w, 0.84 * h)
			draw_rect(r, Color(col.darkened(0.55), 0.9))
			draw_rect(r, col, false, 1.8)
			draw_line(Vector2(0.28 * w, r.position.y), Vector2(0.28 * w, r.end.y), col, 1.5, true)
			for i in 3:
				var y := r.position.y + (0.28 + 0.2 * i) * r.size.y
				draw_line(Vector2(0.42 * w, y), Vector2(0.78 * w, y), Color(col, 0.7), 1.3, true)
