class_name GameDetails
extends RefCounted
## Sidebar card-details panel (inspection only) and the own-pile list that replaces it while
## a pile is open. Shows the hovered card, else the selected card, else a card opened from
## the game log. While drafting it lists the cards picked so far, in the same layout.

## pile_zone value of the draft list.
const DRAFT_ZONE := "draft"
const PILE_NAMES := {"draw": "Draw pile", "spent": "Spent", "exhaust": "Exhaust", "extra": "Extra Deck"}
const PILE_ROW_CARD := Vector2(64, 96)

## The host screen this component works on.
var gs: GameScreen
## Title label of the details panel.
var details_title: Label
## Scroll area holding the card details.
var details_scroll: ScrollContainer
## Card details widget.
var details_view: CardDetailsPanel
## Fade cue shown when the details have more to scroll.
var scroll_cue: ScrollCue
## Own pile shown as a scrollable list in the details panel (instead of a board overlay).
var pile_scroll: ScrollContainer
## Rows of the pile list.
var pile_list: VBoxContainer
## Hint + Close: stays put while the list scrolls.
var pile_head: HBoxContainer
## Hint text above the pile list.
var pile_hint: Label
## Close button of the pile list (hidden for the draft list, which stays while drafting).
var pile_close: Button

## Signature of the details last rendered ("" forces a re-render).
var details_sig: String = ""
## Card opened from the game log (a definition view, not a game instance); cleared by selecting
## another card. Hovering still previews other cards over it.
var log_card: Dictionary = {}
## Own pile listed in the panel ("" while the panel shows card details).
var pile_zone: String = ""
var _pile_sel: int = -1
var _pile_sig: int = 0
## F04: the Fusion unit the player asked to summon from the Extra Deck list, answered for them when
## the Fusion method asks which Fusion unit to summon: {"fu": uid, "at": msec}, or {}.
var fusion_intent: Dictionary = {}
## F04: the Fusion-method picker (a HousePanel over a dim), or null while closed, and its unit.
var _method_dim: ColorRect
var _method_fu: int = -1
var _method_sig: int = 0
## Milliseconds a Fusion intent waits for its "Choose a Fusion unit" prompt.
const INTENT_MS := 4000


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
	pile_head.alignment = BoxContainer.ALIGNMENT_END   # Close stays right when there is no hint
	dv.add_child(pile_head)
	pile_hint = UIStyle.label("", 13, UIStyle.MUTED, true)
	pile_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_head.add_child(pile_hint)
	pile_close = UIStyle.button("Close", 13)
	pile_close.pressed.connect(close_pile)
	pile_head.add_child(pile_close)
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


## Uid of the selected row of the open pile list (-1: none).
func pile_selected() -> int:
	return _pile_sel


## The open pile list's row for card `uid` (null when it is not listed).
func pile_row(uid: int) -> Control:
	for r in pile_list.get_children():
		if r.has_meta("uid") and int(r.get_meta("uid")) == uid and not r.is_queued_for_deletion():
			return r
	return null


## True while this seat is drafting its deck (the panel then lists the picks).
func is_drafting() -> bool:
	var view := gs.view
	return view.get("stage", "") == "decks" and view.has("draft") and not view["deck_ready"][gs.me()]


## While drafting: the cards picked so far, listed like a pile (read-only).
func show_draft() -> void:
	if pile_zone != DRAFT_ZONE:
		pile_zone = DRAFT_ZONE
		_pile_sel = -1
		_pile_sig = 0
	render_pile_list()


## Empty-space click (F03-26): closes the passive pile list (not the draft list, which stays
## while drafting) and a card opened from the log, and drops the hover. Sends nothing and never
## touches a pending choice. True when something closed.
func dismiss_passive() -> bool:
	var did := false
	if not log_card.is_empty():
		log_card = {}
		details_sig = ""
		did = true
	if pile_zone != "" and pile_zone != DRAFT_ZONE:
		close_pile()
		did = true
	elif did:
		render()
	if did:
		gs.hover.clear()
	return did


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
	var drafting := pile_zone == DRAFT_ZONE
	var cards: Array
	if drafting:
		cards = gs.view.get("draft", {}).get("picked", []).map(func(c): return MatchView.summary_view(c))
	else:
		var key := "draw_inspect" if pile_zone == "draw" else pile_zone
		cards = gs.pv(gs.me()).get(key, [])
	var acts := gs.action_row.actions_for_card(_pile_sel) if _pile_sel != -1 else []
	# F04: the Extra Deck rows' Summon buttons follow every legal-action change (phase, AP,
	# materials, zones), so the list re-renders whenever those change.
	var sig := hash([pile_zone, _pile_sel, cards, acts, gs.board.ready_uids.keys(), gs.mv.get("actions", []), gs.mv.get("extra_avail", {}), gs.locked()])
	_sync_method_picker()
	details_scroll.visible = false
	pile_scroll.visible = true
	pile_head.visible = true
	pile_close.visible = not drafting
	if drafting:
		pile_hint.text = "The cards you have drafted so far."
		details_title.text = "Your draft (%d)" % cards.size()
	else:
		pile_hint.text = "Shown in a random order; the real order is unchanged." if pile_zone == "draw" else \
			("" if pile_zone == "extra" else "Hover a card to read it; click to select it.")   # review: the Extra rows' buttons speak for themselves
		details_title.text = "Your %s (%d)" % [PILE_NAMES.get(pile_zone, pile_zone.capitalize()), cards.size()]
	pile_hint.visible = pile_hint.text != ""
	if sig == _pile_sig:
		return
	_pile_sig = sig
	var keep := pile_scroll.scroll_vertical
	GameUi.clear(pile_list)
	if cards.is_empty():
		pile_list.add_child(UIStyle.label("No cards picked yet." if drafting else "Empty.", 14, UIStyle.MUTED))
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
	row.tooltip_text = CardWidget.tooltip_for(c)
	var editable := pile_zone != DRAFT_ZONE   # draft picks are read-only (but can still be inspected)
	if editable:
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pick := func():
		gs.selected_uid = uid
		show_pile(pile_zone, -1 if sel else uid)
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT and editable:
				pick.call()
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				row.accept_event()
				gs.inspect.inspect_card(c))
	# The card + details, then the action buttons across the row's full width (review: Summon
	# Attack and Summon Defense fit on one row instead of stacking in the text column).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hb)
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
	# F04: Extra Deck rows always show their legal summons (no selection needed); other piles show
	# the selected row's actions.
	var buttons := extra_summons(uid) if pile_zone == "extra" else ([] if not sel else _row_actions(uid))
	if not buttons.is_empty():
		var af := HFlowContainer.new()
		af.add_theme_constant_override("h_separation", 6)
		af.add_theme_constant_override("v_separation", 4)
		col.add_child(af)
		for e in buttons:
			var b := UIStyle.primary_button(String(e["label"]), 13)
			b.custom_minimum_size = Vector2(0, 30)
			b.tooltip_text = String(e["full"])
			b.set_meta("summon_kind", String(e["kind"]))
			b.pressed.connect(e["run"])
			af.add_child(b)
	return row


## The selected row's legal actions as buttons [{label, full, kind, run}] (none while locked).
func _row_actions(uid: int) -> Array:
	var out := []
	for a in gs.action_row.actions_for_card(uid):
		var act: Dictionary = a
		out.append({"label": a["label"], "full": a.get("full", a["label"]), "kind": a["t"], "run": func():
			close_pile()
			gs.row_open = true
			gs.action_row.run_action(uid, act)})
	return out


## F04: every summon of Extra Deck card `uid` that is legal right now, as buttons
## [{label, full, kind, run}]. Ritual / Arcane come from the view's legal actions (the authority's
## validate: phase, materials, AP, zones); Fusion from `extra_avail` (the Fusion methods the
## authority can activate now that can summon this unit). Nothing while I cannot act.
func extra_summons(uid: int) -> Array:
	var out := []
	if gs.locked():
		return out
	for a in gs.action_row.actions_for_card(uid):
		if String(a["t"]) in ["ritual", "arcane"]:
			var act: Dictionary = a
			out.append({"label": a["label"], "full": a.get("full", a["label"]), "kind": a["t"], "run": func():
				close_pile()
				gs.row_open = true
				gs.action_row.run_action(uid, act)})
	var ms := fusion_methods_for(uid)
	if not ms.is_empty():
		out.append({"label": "Fusion Summon", "kind": "fusion",
			"full": "Fusion Summon this unit" + (" (choose how: %d ways)" % ms.size() if ms.size() > 1 else " with %s" % method_label(ms[0])),
			"run": func(): start_fusion(uid)})
	return out


## F04: the Fusion methods that can summon Fusion unit `fu` right now (from `extra_avail`). Two
## copies of the same card used the same way (two Fusion Ceremonies in Hand) are one choice.
func fusion_methods_for(fu: int) -> Array:
	var out := []
	var seen := {}
	for m in gs.mv.get("extra_avail", {}).get("methods", []):
		if String(m.get("kind", "")) == "fusion" and fu in m.get("targets", []).map(func(x): return int(x)):
			var key := "%s|%d|%d|%s" % [m.get("t", ""), int(find_card(int(m.get("via", -1))).get("id", -1)), int(m.get("idx", -1)), str(m.get("targets", []))]
			if seen.has(key):
				continue
			seen[key] = true
			out.append(m)
	return out


## Readable name of a Fusion method: its card and how it is used.
func method_label(m: Dictionary) -> String:
	var c := find_card(int(m.get("via", -1)))
	var nm := String(c.get("name", "a card"))
	match String(m.get("t", "")):
		"cast": return "Cast %s" % nm
		"activate_set": return "Activate %s" % nm
		"ability":
			var abs: Array = c.get("abilities", [])
			var i := int(m.get("idx", -1))
			if i >= 0 and i < abs.size():
				return "%s: %s" % [nm, String(abs[i].get("short", abs[i].get("label", "ability")))]
			return "%s ability" % nm
	return nm


## The action of a Fusion method without its card: Cast, Activate or the ability's short label.
func method_action(m: Dictionary) -> String:
	match String(m.get("t", "")):
		"cast": return "Cast"
		"activate_set": return "Activate"
		"ability":
			var abs: Array = find_card(int(m.get("via", -1))).get("abilities", [])
			var i := int(m.get("idx", -1))
			if i >= 0 and i < abs.size():
				return String(abs[i].get("short", abs[i].get("label", "Ability")))
			return "Ability"
	return "Use"


## The full description of a Fusion method: its card and, for an ability, the whole ability text.
func method_full(m: Dictionary) -> String:
	if String(m.get("t", "")) == "ability":
		var c := find_card(int(m.get("via", -1)))
		var abs: Array = c.get("abilities", [])
		var i := int(m.get("idx", -1))
		if i >= 0 and i < abs.size():
			return "%s: %s" % [String(c.get("name", "a card")), String(abs[i].get("label", abs[i].get("short", "ability")))]
	return method_label(m)


## F04: Fusion Summon of `fu` from the Extra Deck list. One method runs at once; several open the
## method picker. Never picks a method on the player's behalf.
func start_fusion(fu: int) -> void:
	var ms := fusion_methods_for(fu)
	if ms.is_empty() or gs.locked():
		Sfx.play("deny")
		return
	if ms.size() == 1:
		run_fusion(fu, ms[0])
	else:
		open_method_picker(fu)


## Sends Fusion method `m` (still legal) and records that `fu` is the unit to summon with it.
func run_fusion(fu: int, m: Dictionary) -> void:
	var still := false
	for x in fusion_methods_for(fu):
		if x.get("t") == m.get("t") and int(x.get("via", -1)) == int(m.get("via", -2)) and int(x.get("idx", -1)) == int(m.get("idx", -1)):
			still = true
	if not still or gs.locked():
		Sfx.play("deny")
		return
	close_method_picker()
	var cmd := {"t": String(m["t"]), "uid": int(m["via"])}
	if String(m["t"]) == "ability":
		cmd["idx"] = int(m["idx"])
	fusion_intent = {"fu": fu, "at": Time.get_ticks_msec()}
	close_pile()
	gs.selected_uid = -1
	gs.row_open = false
	gs.acting_uid = int(m["via"])
	gs.action_row.clear()
	Sfx.play("confirm")
	gs.send(cmd)


## F04: answers the Fusion method's "Choose a Fusion unit to summon" prompt with the unit chosen in
## the Extra Deck list. Returns true when it answered (the banner then waits for the next prompt).
## Any other prompt of mine, or a stale intent, drops the intent.
func consume_fusion_intent() -> bool:
	if fusion_intent.is_empty():
		return false
	if Time.get_ticks_msec() - int(fusion_intent["at"]) > INTENT_MS:
		fusion_intent = {}
		return false
	var pd := gs.pending()
	if pd.is_empty() or not bool(pd.get("mine", false)):
		return false            # not there yet (resolving / the command in flight)
	var fu := int(fusion_intent["fu"])
	fusion_intent = {}
	if String(pd.get("kind", "")) != "select" or int(pd.get("max", 1)) != 1:
		return false
	for o in pd.get("options", []):
		var c: Dictionary = o.get("card", {})
		if int(c.get("uid", -1)) == fu and String(c.get("zone", "")) == "extra":
			gs.selection.pick_option.call_deferred(int(o["i"]))
			return true
	return false


## F04: the picker of how to Fusion Summon `fu` when several methods can: each method's card
## with what it does; click one to continue. Cancel, Esc or a click outside close it.
func open_method_picker(fu: int) -> void:
	close_method_picker()
	_method_fu = fu
	var ms := fusion_methods_for(fu)
	_method_sig = hash(ms)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = UiLayers.MODAL_PICKER
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gs.add_child(dim)
	_method_dim = dim
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_method_picker())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var fc := find_card(fu)
	var hp := HousePanel.new("Fusion Summon", "%d ways" % ms.size(), Vector2(22, 18), 10)
	hp.arm = 18.0
	center.add_child(hp)
	hp.add_headline("Choose how to summon %s" % String(fc.get("name", "this unit")), 22, true)
	var note := UIStyle.label("Each of these can Fusion Summon it now. You choose the materials next.", 14, UIStyle.TEXT_DIM, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(420, 0)
	hp.body.add_child(note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	hp.body.add_child(row)
	for m in ms:
		var mm: Dictionary = m
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		row.add_child(cell)
		var holder := MarginContainer.new()
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			holder.add_theme_constant_override(side, 5)
		cell.add_child(holder)
		var cw := CardWidget.new().setup(find_card(int(m["via"])), "hand")
		cw.tooltip_text = method_label(m)
		cw.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cw.set_meta("fusion_method", true)
		cw.pressed.connect(func(_w): run_fusion(fu, mm))
		cw.right_pressed.connect(gs.inspect.inspect_widget)
		cw.mouse_entered.connect(func(): gs.overlays._lift(cw, 1.05))
		cw.mouse_exited.connect(func(): gs.overlays._lift(cw, 1.0))
		holder.add_child(cw)
		# The card is shown above, so the button names only the action; the full label is the tooltip.
		var b := UIStyle.button(method_action(m), 13)
		b.custom_minimum_size = Vector2(CardWidget.SIZES["hand"].x + 40.0, 34)
		b.set_meta("method_button", true)
		b.tooltip_text = method_full(m)
		b.pressed.connect(func(): run_fusion(fu, mm))
		cell.add_child(b)
	hp.body.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), true, 10.0))
	var cancel := UIStyle.button("Cancel", 15)
	cancel.custom_minimum_size = Vector2(140, 40)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func():
		Sfx.play("cancel")
		close_method_picker())
	hp.body.add_child(cancel)
	hp.appear()
	gs.hover.clear()


## True while the Fusion-method picker is open.
func method_picker_open() -> bool:
	return _method_dim != null and is_instance_valid(_method_dim)


## Closes the Fusion-method picker; true when it was open.
func close_method_picker() -> bool:
	var was := method_picker_open()
	if was:
		_method_dim.queue_free()
	_method_dim = null
	_method_fu = -1
	return was


## Revalidates an open method picker against the current state: closes it when I can no longer
## act or the unit has no method left, rebuilds it when the set of methods changed.
func _sync_method_picker() -> void:
	if not method_picker_open():
		return
	var fu := _method_fu
	var ms := fusion_methods_for(fu)
	if gs.locked() or ms.size() < 2:
		close_method_picker()
	elif hash(ms) != _method_sig:
		open_method_picker(fu)
