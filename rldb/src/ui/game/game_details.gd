class_name GameDetails
extends RefCounted
## Sidebar card-details panel (inspection only) and the own-pile list that replaces it while
## a pile is open. Shows the hovered card, else the selected card, else a card opened from
## the game log.

const PILE_NAMES := {"draw": "Draw pile", "spent": "Spent", "exhaust": "Exhaust", "extra": "Extra Deck"}
const PILE_ROW_CARD := Vector2(64, 96)

var gs: GameScreen
var details_title: Label
var details_scroll: ScrollContainer
var details_view: CardDetailsPanel
var scroll_cue: ScrollCue
## Own pile shown as a scrollable list in the details panel (instead of a board overlay).
var pile_scroll: ScrollContainer
var pile_list: VBoxContainer
var pile_head: HBoxContainer      # hint + Close: stays put while the list scrolls
var pile_hint: Label

## Signature of the details last rendered ("" forces a re-render).
var details_sig: String = ""
## Card opened from the game log (a definition view, not a game instance); cleared by selecting
## another card. Hovering still previews other cards over it.
var log_card: Dictionary = {}
## Own pile listed in the panel ("" while the panel shows card details).
var pile_zone: String = ""
var _pile_sel: int = -1
var _pile_sig: int = 0


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the details panel into the sidebar column and returns it.
func build(col: VBoxContainer) -> PanelContainer:
	var panel := GameUi.side_panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.75   # F02-05: details get most of the height
	col.add_child(panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	panel.add_child(dv)
	var dh := GameUi.header("Card details")
	details_title = dh.get_child(0)
	dv.add_child(dh)
	pile_head = HBoxContainer.new()
	pile_head.add_theme_constant_override("separation", 6)
	pile_head.visible = false
	dv.add_child(pile_head)
	pile_hint = UIStyle.label("", 13, UIStyle.MUTED, true)
	pile_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_head.add_child(pile_hint)
	var pclose := UIStyle.button("Close", 13)
	pclose.pressed.connect(close_pile)
	pile_head.add_child(pclose)
	pile_scroll = ScrollContainer.new()
	pile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pile_scroll.visible = false
	dv.add_child(pile_scroll)
	pile_list = VBoxContainer.new()
	pile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_list.add_theme_constant_override("separation", 6)
	pile_scroll.add_child(GameUi.glow_room(pile_list, 6))
	details_scroll = ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(details_scroll)
	details_view = CardDetailsPanel.new()
	details_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details_view)
	scroll_cue = ScrollCue.new()
	dv.add_child(scroll_cue)
	var vb := details_scroll.get_v_scroll_bar()
	vb.changed.connect(_update_scroll_cue)
	vb.value_changed.connect(func(_v): _update_scroll_cue())
	return panel


func _update_scroll_cue() -> void:
	if details_scroll == null or scroll_cue == null:
		return
	var vb := details_scroll.get_v_scroll_bar()
	var more := vb.max_value - vb.page > 3.0 and vb.value + vb.page < vb.max_value - 3.0
	if scroll_cue.visible != more:
		scroll_cue.visible = more
	scroll_cue.queue_redraw()


## Visible card view by uid anywhere in the match (or offered in the pile tray), or {}.
func find_card(uid: int) -> Dictionary:
	var mv := gs.mv
	if mv.is_empty() or uid == -1:
		return {}
	if gs.prompt.tray_cards.has(uid):
		return gs.prompt.tray_cards[uid]
	for p in 2:
		var pv: Dictionary = mv["players"][p]
		for z in ["units", "backrow", "powers", "hand", "spent", "exhaust", "extra", "draw_inspect"]:
			for c in pv.get(z, []):
				if c != null and not c.get("hidden", false) and c.get("uid", -1) == uid:
					return c
	return {}


## Opens a card by definition id (game-log link). A copy visible in the match is selected
## exactly like clicking it; otherwise the card's definition is shown.
func show_card_def(id: int) -> void:
	if pile_zone != "":
		close_pile()
	# A copy you can see in the match opens exactly like clicking it on the board / in hand.
	if not gs.mv.is_empty():
		for p in [gs.me(), 1 - gs.me()]:
			for z in ["units", "backrow", "powers", "hand"]:
				for c in gs.pv(p).get(z, []):
					if c != null and not c.get("hidden", false) and int(c.get("id", -1)) == id and gs.selection.item_for_uid(int(c["uid"])).size() > 0:
						gs.selection.select(int(c["uid"]))
						return
	log_card = MatchView.def_view(id)
	gs.selected_uid = -1
	gs.row_open = false
	gs.action_row.clear()
	details_sig = ""
	Sfx.play("select")
	gs.board.render()
	render()


## Card whose details are shown: the hovered (peeked) card, else the selected one.
func details_uid() -> int:
	return gs.peek_uid if gs.peek_uid != -1 else gs.selected_uid


## Shows the current card's details (with the reasons its actions are unavailable).
func render() -> void:
	if pile_zone != "":
		return   # the pile list occupies the panel until it is closed
	var duid := details_uid()
	var c := find_card(duid)
	if c.is_empty() and gs.peek_uid == -1 and not log_card.is_empty():
		c = log_card                      # opened from the game log
		duid = -7
	var notes := []
	if not c.is_empty():
		for a in gs.mv.get("actions", []):
			if a.get("uid", -1) == duid and not a["ok"] and a.get("reason", "") != "":
				notes.append("Cannot %s: %s" % [String(a["label"]).to_lower(), a["reason"]])
	var uid_key := duid if not c.is_empty() else -1
	var sig := "%d|%d|%d" % [uid_key, hash(c), hash(notes)]
	if sig == details_sig:
		return
	var same_card: bool = details_sig.begins_with("%d|" % uid_key)
	details_sig = sig
	var keep: int = details_scroll.scroll_vertical if same_card else 0
	if c.is_empty():
		details_view.show_empty("Hover a card to read it, or click it to select it (its actions appear on the card).")
	else:
		details_view.show_card(c, notes)
	details_scroll.set_deferred("scroll_vertical", keep)
	_update_scroll_cue.call_deferred()


## Own pile inspection in the details panel (user feedback 2026-10-16: a scrollable list, not a
## board overlay). Draw is listed in a random display order. Clicking a row selects it; its legal
## actions (Ritual / Arcane Summon from the Extra Deck) appear in that row. Clicking the same pile
## again, Close, Esc or right-click returns the panel to card details.
func show_pile(zone: String, sel_uid: int = -1) -> void:
	if zone == pile_zone and sel_uid == -1 and _pile_sel == -1:
		close_pile()
		return
	pile_zone = zone
	_pile_sel = sel_uid
	_pile_sig = 0
	gs.hover.clear()
	render_pile_list()
	Sfx.play("select")


## Returns the panel from the pile list to card details.
func close_pile() -> void:
	pile_zone = ""
	_pile_sel = -1
	_pile_sig = 0
	pile_scroll.visible = false
	pile_head.visible = false
	details_scroll.visible = true
	details_title.text = "Card details"
	details_sig = ""
	render()


## Lists the open pile's cards (rebuilt only when the pile, selection or actions changed).
func render_pile_list() -> void:
	var pv := gs.pv(gs.me())
	var key := "draw_inspect" if pile_zone == "draw" else pile_zone
	var cards: Array = pv.get(key, [])
	var acts := gs.action_row.actions_for_card(_pile_sel) if _pile_sel != -1 else []
	var sig := hash([pile_zone, _pile_sel, cards, acts, gs.board.ready_uids.keys()])
	details_scroll.visible = false
	pile_scroll.visible = true
	pile_head.visible = true
	pile_hint.text = "Shown in a random order; the real order is unchanged." if pile_zone == "draw" else "Hover a card to read it; click to select it."
	details_title.text = "Your %s (%d)" % [PILE_NAMES.get(pile_zone, pile_zone.capitalize()), cards.size()]
	if sig == _pile_sig:
		return
	_pile_sig = sig
	var keep := pile_scroll.scroll_vertical
	GameUi.clear(pile_list)
	if cards.is_empty():
		pile_list.add_child(UIStyle.label("Empty.", 14, UIStyle.MUTED))
	var sel_row: Control = null
	for c in cards:
		var r := _pile_row(c)
		pile_list.add_child(r)
		if int(c["uid"]) == _pile_sel:
			sel_row = r
	pile_scroll.set_deferred("scroll_vertical", keep)
	if sel_row != null:
		_reveal_pile_row.call_deferred(sel_row)


## Scrolls the list so the selected row, including its action buttons, is fully visible.
func _reveal_pile_row(row: Control) -> void:
	await gs.get_tree().process_frame
	if is_instance_valid(row):
		pile_scroll.ensure_control_visible(row)


## One list row: small card, name, kind / cost / race·type line and the effect text; the selected
## row shows its actions.
func _pile_row(c: Dictionary) -> Control:
	var uid: int = int(c["uid"])
	var sel := uid == _pile_sel
	var can_act: bool = gs.board.ready_uids.has(uid)
	var row := PanelContainer.new()
	row.set_meta("uid", uid)
	var sb := UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.95) if sel else Color(UIStyle.PANEL_INK, 0.9),
		UIStyle.SELECT if sel else (UIStyle.READY if can_act else Color(UIStyle.BRONZE, 0.6)), 2 if (sel or can_act) else 1, 8)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", sb)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = CardWidget.tooltip_for(c)
	var pick := func():
		gs.selected_uid = uid
		show_pile(pile_zone, -1 if sel else uid)
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pick.call())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)
	var w := CardWidget.new().setup(c, "mini")
	w.auto_hover = false
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUi.resize_card(w, PILE_ROW_CARD)
	w.set_ready(can_act)
	w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(w)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	# The same layout as the card details panel, in compact form (name, tags, stats, timing
	# blocks, statuses), so the list reads like the details pane.
	var dp := CardDetailsPanel.new()
	dp.compact = true
	dp.add_theme_constant_override("separation", 3)
	dp.show_card(c)
	GameUi.ignore_mouse(dp)
	vb.add_child(dp)
	if sel and not gs.locked():
		var af := HFlowContainer.new()
		af.add_theme_constant_override("h_separation", 6)
		af.add_theme_constant_override("v_separation", 4)
		vb.add_child(af)
		for a in gs.action_row.actions_for_card(uid):
			var b := UIStyle.primary_button(String(a["label"]), 13)
			b.tooltip_text = String(a.get("full", a["label"]))
			var act: Dictionary = a
			b.pressed.connect(func():
				close_pile()
				gs.row_open = true
				gs.action_row.run_action(uid, act))
			af.add_child(b)
	return row
