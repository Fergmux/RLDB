class_name GameDetails
extends RefCounted
## Sidebar card-details panel (inspection only) and the own-pile list that replaces it while
## a pile is open. Shows the clicked (selected) card, else a card opened from the game log; J4
## (owner, 22 Oct): never the hovered card (hover shows the card's tooltip). While drafting it
## lists the cards picked so far, in the same layout.

## pile_zone value of the draft list.
const DRAFT_ZONE := "draft"
const PILE_NAMES := {"draw": "Draw pile", "spent": "Spent", "exhaust": "Exhaust", "extra": "Extra Deck"}

## The host screen this component works on.
## Pile / draft list rows (#92): inner padding and the height of their action buttons (px).
const ROW_PAD := 12
const ROW_BUTTON_H := 32

var gs: GameScreen
## Title label of the details panel.
var details_title: Label
## Scroll area holding the card details.
var details_scroll: ScrollContainer
## The plain frame holding the details scroll and its overlaid scroll cue (J5); it follows the
## scroll's visibility.
var details_frame: Control
## Card details widget.
var details_view: CardDetailsPanel
## Fade cue over the bottom of the details while they have more to scroll (an overlay, J5).
var scroll_cue: ScrollCue
## Own pile shown as a scrollable list in the details panel (instead of a board overlay).
var pile_scroll: ScrollContainer
## Rows of the pile list.
var pile_list: VBoxContainer
## Hint row: stays put while the list scrolls.
var pile_head: HBoxContainer
## Hint text above the pile list.
var pile_hint: Label

## Signature of the details last rendered ("" forces a re-render).
var details_sig: String = ""
## Card opened from the game log (a definition view, not a game instance); cleared by selecting
## another card.
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


## #42: the illustrated empty state; it takes the panel's height while no card is shown.
var empty_art: DetailsEmptyArt


## #43: the art crop's height in a details scroll `scroll_h` tall: about a third of it, between
## ART_MIN_H and ART_MAX_H, so the rules stay above the fold on a short sidebar.
const ART_MIN_H := 84.0
const ART_MAX_H := 160.0


static func art_crop_height(scroll_h: float) -> float:
	return clampf(roundf(scroll_h * 0.3), ART_MIN_H, ART_MAX_H)


## Shows the illustrated empty state (`on`) or the card details scroll.
func _set_empty(on: bool) -> void:
	empty_art.visible = on
	details_frame.size_flags_vertical = Control.SIZE_FILL if on else Control.SIZE_EXPAND_FILL


## Builds the details panel into the sidebar column and returns it.
func build(col: VBoxContainer) -> PanelContainer:
	var panel := GameUi.side_panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL   # F02-05 / #48: the details take the rest
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
	pile_scroll = ScrollContainer.new()
	pile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pile_scroll.visible = false
	dv.add_child(pile_scroll)
	pile_list = VBoxContainer.new()
	pile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_list.add_theme_constant_override("separation", UIStyle.sp("sm"))
	# #91 / #92: the rows keep the 12 px floor to the scrollbar (6 px of glow room elsewhere).
	var room := GameUi.glow_room(pile_list, 6)
	room.add_theme_constant_override("margin_right", UIStyle.CONTENT_FLOOR)
	pile_scroll.add_child(room)
	details_scroll = ScrollContainer.new()
	details_scroll.name = "DetailsScroll"
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_view = CardDetailsPanel.new()
	details_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_view.art_crop = true   # #43
	details_scroll.add_child(details_view)
	# J5: the cue lies over the bottom of the details (not under them), so nothing jumps as it fades.
	scroll_cue = ScrollCue.new()
	details_frame = scroll_cue.wrap(details_scroll)
	dv.add_child(details_frame)
	empty_art = DetailsEmptyArt.new()   # #42
	empty_art.visible = false
	dv.add_child(empty_art)
	var vb := details_scroll.get_v_scroll_bar()
	vb.changed.connect(_update_scroll_cue)
	vb.value_changed.connect(func(_v): _update_scroll_cue())
	return panel


func _update_scroll_cue() -> void:
	if details_scroll == null or scroll_cue == null:
		return
	var vb := details_scroll.get_v_scroll_bar()
	var more := vb.max_value - vb.page > 3.0 and vb.value + vb.page < vb.max_value - 3.0
	# The cue follows the card details only: never over the illustrated empty state (#42), nor under
	# a pile or draft list (the empty "Your draft (0)" list showed it).
	scroll_cue.set_shown(more and details_scroll.visible and not empty_art.visible)
	scroll_cue.place()


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
	gs.selection.deselect()   # L21: one selection at a time (a selected Hand card drops back too)
	log_card = MatchView.def_view(id)
	details_sig = ""
	Sfx.play("select")
	gs.board.render()
	render()


## Card whose details are shown: the clicked (selected) one (J4: never the hovered one), or -1.
func details_uid() -> int:
	return gs.selected_uid


## Shows the current card's details (with the reasons its actions are unavailable). An open pile
## list holds the panel like a selected card (2026-10-18) until it is closed or another card is
## clicked.
func render() -> void:
	if pile_zone != "":
		if not pile_scroll.visible:
			render_pile_list()
		return
	var duid := details_uid()
	var c := find_card(duid)
	if c.is_empty() and not log_card.is_empty():
		c = log_card                      # opened from the game log
		duid = -7
	var notes := []
	if not c.is_empty():
		for a in gs.mv.get("actions", []):
			if a.get("uid", -1) == duid and not a["ok"] and a.get("reason", "") != "":
				var verb := String(a["label"]).to_lower()
				if verb.begins_with("to "):
					verb = "change " + verb   # stance labels: "To Defense" -> "change to defense"
				notes.append("Cannot %s: %s" % [verb, a["reason"]])
	var uid_key := duid if not c.is_empty() else -1
	var sig := "%d|%d|%d" % [uid_key, hash(c), hash(notes)]
	if sig == details_sig:
		return
	var same_card: bool = details_sig.begins_with("%d|" % uid_key)
	details_sig = sig
	var keep: int = details_scroll.scroll_vertical if same_card else 0
	_set_empty(c.is_empty())
	if c.is_empty():
		details_view.show_empty("")   # #42: the illustrated empty state carries the hint
	else:
		details_view.art_crop_h = art_crop_height(details_scroll.size.y)
		details_view.show_card(c, notes)
	details_scroll.set_deferred("scroll_vertical", keep)
	_update_scroll_cue.call_deferred()


## Own pile inspection in the details panel (user feedback 2026-10-16: a scrollable list, not a
## board overlay). Draw is listed in a random display order. Clicking a row selects it; its legal
## actions (Ritual / Arcane Summon from the Extra Deck) appear in that row. The pile shows the
## selected brackets while open (2026-10-18: no Close button); clicking the same pile again, empty
## space, Esc or right-click returns the panel to card details.
func show_pile(zone: String, sel_uid: int = -1) -> void:
	if zone == pile_zone and sel_uid == -1 and _pile_sel == -1:
		close_pile()
		return
	pile_zone = zone
	_pile_sel = sel_uid
	_pile_sig = 0
	gs.hover.clear()
	render_pile_list()
	gs.board.render()            # the pile's selected brackets
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
	gs.board.render()            # drop the pile's selected brackets


## Lists the open pile's cards (rebuilt only when the pile, selection or actions changed).
func render_pile_list() -> void:
	var drafting := pile_zone == DRAFT_ZONE
	var cards: Array
	if drafting:
		cards = draft_views(gs.view.get("draft", {}).get("picked", []))
	else:
		var key := "draw_inspect" if pile_zone == "draw" else pile_zone
		cards = gs.pv(gs.me()).get(key, [])
	var acts := gs.action_row.actions_for_card(_pile_sel) if _pile_sel != -1 else []
	# F04: the Extra Deck rows' Summon buttons follow every legal-action change (phase, AP,
	# materials, zones), so the list re-renders whenever those change.
	var sig := hash([pile_zone, _pile_sel, cards, acts, gs.board.ready_uids.keys(), gs.mv.get("actions", []), gs.mv.get("extra_avail", {}), gs.locked()])
	_sync_method_picker()
	details_scroll.visible = false
	empty_art.visible = false
	_update_scroll_cue()
	pile_scroll.visible = true
	pile_head.visible = true
	if drafting:
		pile_hint.text = "The cards you have drafted so far."
		details_title.text = "Your draft (%d)" % cards.size()
	else:
		pile_hint.text = "Shown in a random order; the real order is unchanged." if pile_zone == "draw" else \
			("" if pile_zone == "extra" else "Click a card to open its details; click it again to close them.")   # review: the Extra rows' buttons speak for themselves
		details_title.text = "Your %s (%d)" % [PILE_NAMES.get(pile_zone, pile_zone.capitalize()), cards.size()]
	pile_hint.visible = pile_hint.text != ""
	if sig == _pile_sig:
		return
	_pile_sig = sig
	var keep := pile_scroll.scroll_vertical
	GameUi.clear(pile_list)
	if drafting:
		# #59: one engraved card slot per pick of the draft; the slots fill (in the picked card's
		# kind colour) as the draft goes, so progress is visible and the column never sits empty.
		var dr: Dictionary = gs.view.get("draft", {})
		# J29 (owner, 22 Oct): the filled slots show the drafted cards themselves, with the duel's
		# card tooltip; right-click inspects one, and the newest pick lifts into its slot.
		var slots := DraftSlots.new()
		slots.name = "DraftSlots"
		slots.setup(int(dr.get("total", cards.size())), cards, cards.size() > _draft_shown)
		_draft_shown = cards.size()
		for w in slots.cards:
			if w != null:
				(w as CardWidget).right_pressed.connect(gs.inspect.inspect_widget)
		pile_list.add_child(slots)
	elif cards.is_empty():
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


## Picks the draft list last showed (a new one lifts into its slot, J29).
var _draft_shown: int = 0


## J28 (owner, 22 Oct): the drafted cards as full definition views (MatchView.def_view), so the
## draft list's rows and tooltips carry exactly what the duel's pile rows do: the kind, the cost,
## Race and Type, a Fusion's materials, keywords and abilities. Each pick gets its own uid (two
## copies of one card stay two rows). `picked` holds Series.card_summary entries.
static func draft_views(picked: Array) -> Array:
	var out := []
	for i in picked.size():
		var v := MatchView.def_view(int(picked[i].get("id", -1)))
		v["uid"] = -3000 - i
		out.append(v)
	return out


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
	var row := StatusHelp.TipPanel.new()
	row.set_meta("uid", uid)
	var sb := UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.95) if sel else Color(UIStyle.PANEL_INK, 0.9),
		UIStyle.SELECT if sel else (UIStyle.READY if can_act else Color(UIStyle.BRONZE, 0.6)), 2 if (sel or can_act) else 1, 8)
	# #92: 12 px row padding (10 px above and below), so the buttons never sit on the row's edge.
	sb.content_margin_left = ROW_PAD
	sb.content_margin_right = ROW_PAD
	sb.content_margin_top = ROW_PAD - 2
	sb.content_margin_bottom = ROW_PAD - 2
	row.add_theme_stylebox_override("panel", sb)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = CardWidget.tooltip_for(c) + "\n\nRight-click to inspect"   # D15: no Inspect button
	row.set_meta(&"tip_card", c)   # H8: the coloured card tooltip
	var editable := pile_zone != DRAFT_ZONE   # draft picks are read-only (but can still be inspected)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pick := func():
		# Closing the row also drops its card's selection (the panel would show it again once the
		# list closes); a card selected before the list opened is left alone.
		if not sel:
			gs.selected_uid = uid
		elif gs.selected_uid == uid:
			gs.selected_uid = -1
		show_pile(pile_zone, -1 if sel else uid)
	# The card + details, then the action buttons across the row's full width (review: several
	# summon buttons fit on one row instead of stacking in the text column).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	# #91: a compact summary line (thumbnail, name, Type chip, "ATK / DEF" inline), so four Basic
	# Mages no longer make a wall of identical stat boxes; the full compact details open under it
	# once the row is clicked (J3).
	col.add_child(_pile_summary(c, can_act))
	var more := VBoxContainer.new()
	more.name = "RowDetails"
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	more.visible = false
	col.add_child(more)
	var expand := func(on: bool) -> void:
		if not is_instance_valid(more):
			return
		if on and more.get_child_count() == 0:
			# The same layout as the card details panel, in compact form, built on first use.
			var dp := CardDetailsPanel.new()
			dp.compact = true
			dp.add_theme_constant_override("separation", 3)
			dp.show_card(c)
			GameUi.ignore_mouse(dp)
			more.add_child(dp)
		more.visible = on
	# J3 (owner, 22 Oct): the details open on a click only, never on hover, and a second click closes
	# them. In a pile the click selects the row (its actions show with the details); a draft pick is
	# read-only, so there the click only opens or closes the row.
	if sel:
		expand.call(true)
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				row.accept_event()
				if editable:
					pick.call()
				else:
					Sfx.play("select")
					expand.call(not more.visible)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				row.accept_event()
				gs.inspect.inspect_card(c))
	# Hovering highlights the row (a brighter rim and face); the layout never changes.
	var rest_edge := sb.border_color
	var rest_fill := sb.bg_color
	var hover_edge: Color = UIStyle.GOLD_HI.lightened(0.15) if (sel or can_act) else Color(UIStyle.GOLD, 0.9)
	row.mouse_entered.connect(func():
		sb.border_color = hover_edge
		sb.bg_color = rest_fill.lerp(UIStyle.PANEL_LIGHT, 0.55))
	row.mouse_exited.connect(func():
		sb.border_color = rest_edge
		sb.bg_color = rest_fill)
	# F04: Extra Deck rows always show their legal summons (no selection needed); other piles show
	# the selected row's actions.
	var buttons := extra_summons(uid) if pile_zone == "extra" else ([] if not sel else _row_actions(uid))
	if not buttons.is_empty():
		var af := HFlowContainer.new()
		af.add_theme_constant_override("h_separation", UIStyle.sp("sm"))
		af.add_theme_constant_override("v_separation", UIStyle.sp("sm"))
		col.add_child(af)
		for e in buttons:
			var b := UIStyle.primary_button(String(e["label"]), 13)
			b.custom_minimum_size = Vector2(0, ROW_BUTTON_H)   # #92: 32 px, 8 px apart
			b.tooltip_text = String(e["full"])
			b.set_meta("summon_kind", String(e["kind"]))
			b.pressed.connect(e["run"])
			af.add_child(b)
	return row


## H6 (owner, 21 Oct): the row's card is the same small card face as the left input pane's (a "mini"
## CardWidget drawn face up through GamePromptBanner.pane_view), not an art crop, at 7/8 of the pane's
## GamePromptBanner.SUBJECT_CARD so the rows stay compact.
const PILE_CARD := GamePromptBanner.SUBJECT_CARD * 0.875
## H6: the kind a pile row names: units by how they are summoned (Unit / Fusion / Ritual / Arcane),
## other cards by their category.
const ROW_KIND := {"basic_unit": "Unit", "unit": "Unit", "fusion": "Fusion", "ritual": "Ritual", "arcane": "Arcane",
	"spell": "Spell", "trap": "Trap", "power": "Power"}
## H6: text sizes of the row (px): name, chips and the race / materials lines.
const ROW_NAME_PX := 15
const ROW_SMALL_PX := 12
## Most lines a Fusion's materials take in the row (the full text is in the expanded details).
const ROW_MATERIAL_LINES := 2


## The kind a pile row shows for card view `c` (H6).
static func row_kind(c: Dictionary) -> String:
	var cat := String(c.get("category", ""))
	return String(ROW_KIND.get(cat, cat.capitalize()))


## H6: the cost a pile row shows for `c`: {"text", "kind"} ("3 AP", "2 Rune", "1 Arcane"), or the
## Fusion materials as {"text": "Beast Unit + Dragon Unit", "kind": "fusion"}; {} when it has none.
static func row_cost(c: Dictionary) -> Dictionary:
	var kind := String(c.get("cost_kind", "ap"))
	if kind == "fusion" or String(c.get("category", "")) == "fusion":
		for part in c.get("text_parts", []):
			if String(part.get("k", "")) == "Materials" and String(part.get("t", "")) != "":
				return {"text": String(part["t"]), "kind": "fusion"}
		return {}
	var txt := String(c.get("cost_text", ""))
	if txt == "" and c.get("cost") != null:
		txt = "%s AP" % str(c["cost"])
	return {"text": txt, "kind": kind} if txt != "" else {}


## #91 / H6: the summary line of a pile row before it expands: the small card face (as in the left
## input pane), then the name with "ATK / DEF" at the right for units, a line of chips with the kind
## (Unit / Fusion / Ritual / Arcane, or Spell / Trap / Power) and the cost, the Race and Type for
## units, and a Fusion's material cost.
func _pile_summary(c: Dictionary, can_act: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.name = "RowSummary"
	hb.add_theme_constant_override("separation", UIStyle.sp("md"))
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := CardWidget.new()
	w.show_tooltip = false       # the row carries the card's tooltip
	w.setup(GamePromptBanner.pane_view(c), "mini")
	w.auto_hover = false
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUi.resize_card(w, PILE_CARD)
	w.set_ready(can_act)
	w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(w)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UIStyle.sp("xs"))
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var unit := CardDetailsPanel.is_unit_view(c)
	# Name, with the current ATK / DEF at the right for units.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UIStyle.sp("sm"))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	var nm := UIStyle.label(String(c.get("name", "?")), ROW_NAME_PX, UIStyle.TEXT)
	nm.add_theme_font_override("font", UIStyle.font_bold())
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.custom_minimum_size.x = 40.0
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(nm)
	if unit:
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 3)
		stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for part in [[c.get("atk"), CardDetailsPanel.STAT_EDGE["ATK"]], ["/", UIStyle.MUTED], [c.get("def"), CardDetailsPanel.STAT_EDGE["DEF"]]]:
			var l := UIStyle.label("?" if part[0] == null else str(part[0]), 16 if part[0] is not String else 13, part[1])
			l.add_theme_font_override("font", UIStyle.font_display(700))
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
			l.add_theme_constant_override("outline_size", 3)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats.add_child(l)
		top.add_child(stats)
	# Kind and cost chips.
	var chips := HFlowContainer.new()
	chips.name = "RowChips"
	chips.add_theme_constant_override("h_separation", UIStyle.sp("xs"))
	chips.add_theme_constant_override("v_separation", UIStyle.sp("xs"))
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(chips)
	var cat := String(c.get("category", ""))
	var kind_col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.BRONZE)
	chips.add_child(_row_chip(row_kind(c), kind_col, "", true))
	var cost := row_cost(c)
	if not cost.is_empty() and String(cost["kind"]) != "fusion":
		var ck := String(cost["kind"])
		chips.add_child(_row_chip(String(cost["text"]), UIStyle.COST_COLORS.get(ck, UIStyle.COST_COLORS["ap"]),
			{"ap": "circle", "ritual": "square", "arcane": "hex"}.get(ck, "circle")))
	# Race and Type (units).
	if unit:
		var sub := HBoxContainer.new()
		sub.name = "RowRace"
		sub.add_theme_constant_override("separation", UIStyle.sp("xs"))
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(sub)
		var race := String(c.get("race", ""))
		var rl := UIStyle.label(race if race != "" else "No race", ROW_SMALL_PX, UIStyle.MUTED)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(rl)
		var dot := UIStyle.label("·", ROW_SMALL_PX, UIStyle.TEXT_DIM)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(dot)
		var ty = c.get("type", "")
		var ty_s: String = String(ty) if ty != null else ""
		var tb := TypeIcons.TypeBadge.new(ty_s, 15.0)
		tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sub.add_child(tb)
		var tl := UIStyle.label(ty_s if ty_s != "" else "No type", ROW_SMALL_PX, UIStyle.type_color(ty_s).lightened(0.25))
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(tl)
	# A Fusion's material cost.
	if not cost.is_empty() and String(cost["kind"]) == "fusion":
		var mrow := HBoxContainer.new()
		mrow.name = "RowMaterials"
		mrow.add_theme_constant_override("separation", UIStyle.sp("xs"))
		mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(mrow)
		var mk := CardDetailsPanel.Mark.new("diamond", UIStyle.COST_COLORS["fusion"], 9)
		mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var mk_box := MarginContainer.new()
		mk_box.add_theme_constant_override("margin_top", 4)
		mk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mk_box.add_child(mk)
		mrow.add_child(mk_box)
		var ml := UIStyle.label(String(cost["text"]), ROW_SMALL_PX, UIStyle.COST_COLORS["fusion"].lightened(0.45), true)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ml.custom_minimum_size.x = 40.0
		ml.max_lines_visible = ROW_MATERIAL_LINES
		ml.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mrow.add_child(ml)
	return hb


## H6: a small chip of a pile row (the details panel's chip at row scale): a tinted pill with an
## optional marker shape and the text.
func _row_chip(text: String, col: Color, shape: String = "", strong: bool = false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(col.darkened(0.5) if strong else Color(col.darkened(0.62), 0.9), Color(col, 0.9), 1, 9)
	sb.content_margin_left = 6
	sb.content_margin_right = 7
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	if shape != "":
		h.add_child(CardDetailsPanel.Mark.new(shape, col, 8))
	var l := UIStyle.label(text, ROW_SMALL_PX, UIStyle.TEXT)
	l.add_theme_font_override("font", UIStyle.font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return pc


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
	row.add_theme_constant_override("separation", UIStyle.sp("lg"))
	for m in ms:
		var mm: Dictionary = m
		# #93: the card (150 px) and its button are one tile in a joined frame: hovering either
		# lights the frame, lifts the card and warms the button, so the pair reads as one choice.
		var tile := MethodTile.new()
		row.add_child(tile)
		var cw := CardWidget.new().setup(find_card(int(m["via"])), "hand")
		GameUi.resize_card(cw, METHOD_CARD)
		cw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cw.tooltip_text = method_label(m)
		cw.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cw.set_meta("fusion_method", true)
		cw.pressed.connect(func(_w): run_fusion(fu, mm))
		cw.right_pressed.connect(gs.inspect.inspect_widget)
		tile.col.add_child(cw)
		# The card is shown above, so the button names only the action; the full label is the tooltip.
		var b := UIStyle.button(method_action(m), 14)
		b.custom_minimum_size = Vector2(METHOD_CARD.x + 24.0, 36)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.set_meta("method_button", true)
		b.tooltip_text = method_full(m)
		b.pressed.connect(func(): run_fusion(fu, mm))
		tile.col.add_child(b)
		tile.bind(cw, b, func(): run_fusion(fu, mm), func(on: bool): gs.overlays._lift(cw, 1.05 if on else 1.0))
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


## #93: card size in the Fusion-method picker (the hand size was small for its modal).
const METHOD_CARD := Vector2(150, 225)


## #93: one way to Fusion Summon in the method picker: the method's card over its button in one
## joined frame (an F3 well). Hovering anywhere on it lights the rim gold, lifts the card and gives
## the button its hover face, with one ui_hover cue; a click anywhere on it picks the method.
## Under reduced motion the card does not lift (the rim marks the hover).
class MethodTile extends PanelContainer:
	## The tile's content column (the card, then the button).
	var col := VBoxContainer.new()
	var hovered := false
	var _sb: StyleBoxFlat
	var _button: Button
	var _pick: Callable
	var _lift: Callable

	func _init() -> void:
		_sb = UIStyle.flat(Color(0.045, 0.035, 0.025, 0.92), Color(UIStyle.BRONZE, 0.7), 1, 10)
		UIStyle.pad(_sb, "md")
		_sb.shadow_color = Color(0, 0, 0, 0.45)
		_sb.shadow_size = 6
		_sb.shadow_offset = Vector2(0, 3)
		add_theme_stylebox_override("panel", _sb)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		col.add_theme_constant_override("separation", UIStyle.sp("md"))
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(col)

	## Wires the button `b`, the pick action and the card lift (Callable(bool)).
	func bind(_cw: CardWidget, b: Button, pick: Callable, lift: Callable) -> void:
		_button = b
		_pick = pick
		_lift = lift

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _pick.is_valid():
			accept_event()
			_pick.call()

	func _process(_d: float) -> void:
		var h := get_viewport().gui_get_hovered_control() if is_inside_tree() else null
		var on := h != null and (h == self or is_ancestor_of(h))
		if on != hovered:
			set_hover(on)

	## Shows the tile hovered (`on`) or at rest.
	func set_hover(on: bool) -> void:
		hovered = on
		_sb.border_color = UIStyle.GOLD_HI if on else Color(UIStyle.BRONZE, 0.7)
		_sb.set_border_width_all(2 if on else 1)
		_sb.shadow_color = Color(UIStyle.GOLD, 0.35) if on else Color(0, 0, 0, 0.45)
		_sb.shadow_size = 14 if on else 6
		if _button != null:
			if on:
				_button.add_theme_stylebox_override("normal", _button.get_theme_stylebox("hover"))
			else:
				_button.remove_theme_stylebox_override("normal")
		if on:
			Sfx.hover_item()
		if _lift.is_valid() and not UIStyle.reduce_motion:
			_lift.call(on)
