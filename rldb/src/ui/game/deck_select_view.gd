class_name DeckSelectView
extends RefCounted
## "Choose your deck" stage of the series modal (F04-02): lobby bar, Structured / Custom tabs,
## uniform deck tiles in a smooth scrolling plate, the locked-in waiting state and the draft offer.
## Renders into the overlay's content box; sends commands through the host screen.

## Which tab is open: "structured" (starter decks) or "custom" (saved decks).
var tab: String = "structured"
## The ScrollArea holding the tiles (null when this stage shows no list); the overlay sizes to it.
var list_area: ScrollArea
var ov: GameSeriesOverlay


func _init(overlay: GameSeriesOverlay) -> void:
	ov = overlay


## Fills the overlay for the deck stage. Returns true when the content is a fixed-height layout
## (a scrolling list), false when the modal should shrink to its content.
func render() -> bool:
	list_area = null
	var gs := ov.gs
	var view := gs.view
	var p := gs.me()
	var box := ov.overlay_box
	_lobby_bar(box)
	if view["deck_ready"][p]:
		_waiting(box)
		return false
	if view.has("starters"):
		_tabs_and_list(box)
		return true
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
		var inv := UIStyle.primary_button("Invite a Steam friend", 15)
		inv.pressed.connect(func(): gs.get_tree().call_group("net_session", "invite_friend"))
		lob.add_child(inv)


# ---------------------------------------------------------------- waiting (deck locked in)
func _waiting(box: VBoxContainer) -> void:
	var gs := ov.gs
	var view := gs.view
	var p := gs.me()
	var opp_ready: bool = view["deck_ready"][1 - p]
	var chips := [
		{"text": "%s: deck locked in" % String(view["names"][p]), "done": true},
		{"text": "%s: %s" % [String(view["names"][1 - p]), "deck locked in" if opp_ready else "choosing a deck…"], "done": opp_ready},
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
	inner.add_theme_constant_override("margin_right", 8)
	inner.add_theme_constant_override("margin_top", 4)
	inner.add_theme_constant_override("margin_bottom", 4)
	inner.add_theme_constant_override("margin_left", 2)
	area.set_content(inner)
	var wide: bool = minf(ov._overlay_max.x, ov.gs.size.x - ov.gs.sidebar_w - 40.0) >= 1000.0
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
			_add_tile(grid, "c%d" % n, d["name"], "Saved custom deck", main, extra, "Use this deck", func(): ov.gs.send({"t": "custom_deck", "cards": deck["cards"], "name": deck["name"]}))
			n += 1


func _add_tile(grid: GridContainer, id: String, title: String, theme: String, main: Array, extra: Array, btn: String, on_pick: Callable) -> void:
	var t := DeckTile.new({"title": title, "theme": theme, "main": main, "extra": extra, "btn_text": btn, "open": ov.deck_open.get(id, false)})
	t.chosen.connect(on_pick)
	t.toggled.connect(func():
		var was: bool = ov.deck_open.get(id, false)
		ov.deck_open.clear()
		ov.deck_open[id] = not was
		_remember_scroll()
		ov.refresh())
	grid.add_child(t)


## Keeps the list where it is across the re-render a selection causes.
func _remember_scroll() -> void:
	if list_area != null and is_instance_valid(list_area):
		_saved_scroll = list_area.scroll.scroll_vertical


var _saved_scroll: int = 0


## Re-applies the remembered scroll position once the new list has been laid out.
func restore_scroll() -> void:
	if list_area == null or _saved_scroll == 0:
		return
	var a := list_area
	await ov.gs.get_tree().process_frame
	await ov.gs.get_tree().process_frame
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
	if String(dr.get("composition", "")) != "":
		var cl := UIStyle.label("Draft: " + String(dr["composition"]), 14, UIStyle.MUTED)    # F03-10
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cl)
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
