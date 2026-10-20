class_name DeckSelectView
extends RefCounted
## "Choose your deck" stage of the series modal (F04-02): lobby bar, Structure / Custom tabs,
## uniform deck tiles in a smooth scrolling plate, the locked-in waiting state and the draft
## (category tabs drafted in any order, the basic unit changeable at any time, the offer).
## Renders into the overlay's content box; sends commands through the host screen.


## Which tab is open: "structured" (Structure decks) or "custom" (saved decks).
var tab: String = "structured"
## Fill of the deck pane (the leather grain shows on it).
const PANE_FILL := Color(0.092, 0.074, 0.054, 0.95)
## The tab hint size (px).
const HINT_PX := 13
## Width of the Custom tab's empty state.
const EMPTY_W := 520.0
## Draft offer (review #56): card width (tall / short windows), the gap between cards, the hover
## tilt and the reveal flip of a new offer (per card, staggered by the same step).
const OFFER_W := 260.0
const OFFER_W_SHORT := 236.0
## Window height (px) below which the offer uses OFFER_W_SHORT, so the modal still fits.
const OFFER_TALL_H := 960.0
const OFFER_GAP := 48
const OFFER_TILT_DEG := 2.0
const OFFER_FLIP := 0.12
## Draft pips (review #57): diamond size, pitch, the extra gap every PIP_GROUP pips, the most shown.
const PIP_R := 6.0
const PIP_PITCH := 16.0
const PIP_GROUP := 4
const PIP_GROUP_GAP := 6.0
const PIP_MAX := 24
## The ScrollArea holding the tiles (null when this stage shows no list); the overlay sizes to it.
var list_area: ScrollArea
## The Structure / Custom folder tabs (null when this stage shows none).
var tab_widget: FolderTabs
var ov: GameSeriesOverlay

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
	# Folder tabs joined to the pane that holds the tile list (one widget for every tab strip).
	var ft := FolderTabs.new()
	ft.tab_height = 50.0
	ft.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ft.set_pane_margins(8, 14, 6, 8)
	ft.pane_fill = PANE_FILL   # leather that reads as leather, not a black void (review #54)
	_add_tab(ft, "structured", "Structure", starters.size(), "shield")
	if custom_ok:
		_add_tab(ft, "custom", "Custom", saved.size(), "tome")
	ft.select(tab, false)
	# Review #53: 13 px italic MUTED, its baseline on the tab titles' baseline.
	var hint := UIStyle.label("Structure decks, ready to play" if tab == "structured" else "Decks you built and saved", HINT_PX, UIStyle.MUTED)
	hint.name = "TabHint"
	hint.add_theme_font_override("font", UIStyle.font_italic())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ft.set_trailing(hint, UIStyle.font_italic(), HINT_PX)
	ft.tab_selected.connect(func(key: String):
		if tab != key:
			tab = key
			ov.deck_open.clear()
			ov.refresh())
	box.add_child(ft)
	tab_widget = ft
	var area := ScrollArea.new()
	area.custom_minimum_size = Vector2(0, 220)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ft.pane.add_child(area)
	list_area = area
	var inner := MarginContainer.new()
	# F01: the content fills the pane's height, so a sparse or empty tab keeps the same pane and
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
## Signature of the draft offer last shown (a new one plays the reveal).
var _offer_sig: int = 0
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


## The Custom tab with no saved deck (review #54 / #55): an illustrated empty state laid straight
## on the pane's leather (no frame nested in the modal's frame): the engraved tome, a SCREEN title,
## the explanation and a standard 44 px secondary button back to the Structure decks.
func _empty_custom() -> Control:
	var es := EngravedIcon.empty_state("tome", "No saved decks yet",
		"Decks you build and save in the Deck Builder appear here, ready to play. Until then, pick a Structure deck.",
		"Show Structure decks", func():
			tab = "structured"
			ov.refresh(), EMPTY_W)
	es.name = "EmptyCustom"
	es.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	es.size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	return es


## Adds the deck-source tab `key` to `ft`: its glyph, title and deck count.
func _add_tab(ft: FolderTabs, key: String, title: String, count: int, glyph: String) -> void:
	var on: bool = tab == key
	ft.add_tab(key, title, {"glyph": TabGlyph.new(glyph, UIStyle.GOLD_HI if on else UIStyle.BRONZE.lightened(0.35)),
		"badge": str(count), "min_width": 190.0})


# ---------------------------------------------------------------- draft
## Owner feedback 2026-10-18: no setup step. The categories are tabs drafted in any order (each
## shows its picks left; a category keeps its offer when you switch away), and the basic unit
## can be changed at any time until the draft is done.
func _draft(box: VBoxContainer) -> void:
	var gs := ov.gs
	var dr: Dictionary = gs.view["draft"]
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 14)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(strip)
	var pips := DraftPips.new(int(dr["step"]), int(dr["total"]))
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(pips)
	# The draft's progress line is a SECTION header (D3: gold, a hard dark shadow).
	var pick := UIStyle.label("Pick %d of %d" % [mini(int(dr["step"]) + 1, int(dr["total"])), dr["total"]], 18, UIStyle.GOLD, false, true)
	pick.name = "PickLine"
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(pick)
	var pt := TitleText.apply(pick, TitleText.Tier.SECTION, 18)
	pt.show_underline = false
	TitleText.apply(pick, TitleText.Tier.SECTION, 18)
	var od: Dictionary = dr.get("opponent", {})
	if not od.is_empty() and not gs.view["deck_ready"][1 - gs.me()]:
		strip.add_child(ov.rewards._info_chip("%s %s" % [String(gs.view["names"][1 - gs.me()]), _opponent_doing(dr)], false))
	# Category folder tabs (the basic unit at the right of the strip) joined to the pane with the offer.
	var ft := category_tabs(dr)
	box.add_child(ft)
	# Review #56: the offer is the screen's one decision, so the cards are large, 48 px apart and
	# centred in the pane; a hover lifts and tilts a card; a new offer flips in card by card.
	var row := HBoxContainer.new()
	row.name = "Offer"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", OFFER_GAP)
	ft.pane.add_child(row)
	var cw_w := offer_width(gs.size.y)
	var card := Vector2(cw_w, roundf(cw_w * 1.5))
	var room := ceilf(card.y * GameSeriesOverlay.DRAFT_HOVER_SCALE) + 2.0 * UIStyle.sp("md")
	var sig := offer_sig(dr)
	var fresh := sig != _offer_sig
	_offer_sig = sig
	var cards: Array = []
	for i in dr["offer"].size():
		var c: Dictionary = dr["offer"][i]
		var colm := CenterContainer.new()
		colm.custom_minimum_size = Vector2(ceilf(card.x * GameSeriesOverlay.DRAFT_HOVER_SCALE), room)
		row.add_child(colm)
		var cw := CardWidget.new().setup(MatchView.summary_view(c), "big")
		cw.custom_minimum_size = card
		cw.tooltip_text = "Pick %s" % c["name"]
		cw.hover_sound = true
		var idx: int = i
		cw.pressed.connect(func(_w): gs.send({"t": "draft_pick", "index": idx}))
		cw.right_pressed.connect(gs.inspect.inspect_widget)
		cw.mouse_entered.connect(func():
			ov._lift(cw, GameSeriesOverlay.DRAFT_HOVER_SCALE)
			_tilt(cw, true))
		cw.mouse_exited.connect(func():
			ov._lift(cw, 1.0)
			_tilt(cw, false))
		colm.add_child(cw)
		cards.append(cw)
	if fresh:
		_reveal(cards)


## The draft's category tabs as folder tabs: each shows its icon, name and picks left; the open one
## is joined to the pane below it, a finished one is disabled and shows a tick. The basic unit chip
## and its Change button sit at the right end of the strip. Picking a tab sends `draft_category`.
func category_tabs(dr: Dictionary) -> FolderTabs:
	var ft := FolderTabs.new()
	ft.tab_height = 46.0
	# Five tabs and the basic-unit chip share the strip: a 15 px title and 6 px gaps leave the
	# chip its 24 px from the frame (review #58) without widening the modal.
	ft.font_size = 15
	ft.tab_gap = 6.0
	ft.left_margin = 20.0
	ft.set_pane_margins(10, 14, 10, 10)
	var labels: Dictionary = dr.get("labels", {})
	var left: Dictionary = dr.get("left", {})
	for cat in dr.get("categories", []):
		var key := String(cat)
		var n_left := int(left.get(cat, 0))
		var title := String(labels.get(cat, key.capitalize()))
		var col: Color = UIStyle.CATEGORY_COLORS.get(key, UIStyle.BRONZE)
		var tip := ("Draft %s cards: %d pick%s left." % [title, n_left, "" if n_left == 1 else "s"]) if n_left > 0 else "%s: all picks made." % title
		ft.add_tab(key, title, {"accent": col, "disabled": n_left <= 0, "tooltip": tip,
			"glyph": ChoiceTile.Icon.new(key, col, 26.0), "badge": str(n_left) if n_left > 0 else "\u2713"})
	ft.select(String(dr["category"]), false)
	ft.tab_selected.connect(func(key: String): ov.gs.send({"t": "draft_category", "category": key}))
	var b: Dictionary = dr.get("basic", {})
	if not b.is_empty() and int(dr.get("basic_copies", 0)) > 0:
		# Review #58: an F4 chip at 13 px and a small secondary, 24 px from the frame (FolderTabs).
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UIStyle.sp("md"))
		var chip := UIStyle.chip("Basic: %s (%s) \u00d7%d" % [b["name"], b["type"], int(dr["basic_copies"])], UIStyle.type_color(b["type"]), 13)
		chip.name = "BasicChip"
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		var change := UIStyle.size_button(UIStyle.secondary_button("Change", 14), "small")
		change.name = "ChangeBasic"
		change.custom_minimum_size.x = 0.0   # its own width: the strip is full with five tabs
		change.tooltip_text = "Choose a different Type and Race for your basic units. You can change it until your draft is done."
		change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		change.pressed.connect(func(): _open_picker(dr))
		row.add_child(change)
		ft.set_trailing(row)
	return ft


## Width of a draft offer card for a window `h` px tall (the modal has to fit a short window).
static func offer_width(h: float) -> float:
	return OFFER_W if h >= OFFER_TALL_H else OFFER_W_SHORT


## Identity of a draft offer (its step, category and card ids): a new one flips in.
static func offer_sig(dr: Dictionary) -> int:
	var ids := []
	for c in dr.get("offer", []):
		ids.append(int(c.get("id", -1)))
	return hash([int(dr.get("step", 0)), String(dr.get("category", "")), ids])


## Hover tilt of an offer card: OFFER_TILT_DEG toward the pointer's side, eased; none under
## reduce motion.
func _tilt(cw: CardWidget, on: bool) -> void:
	if not is_instance_valid(cw) or UIStyle.reduce_motion or not cw.is_inside_tree():
		return
	cw.pivot_offset = cw.size / 2.0
	var side := 1.0 if cw.get_local_mouse_position().x >= cw.size.x / 2.0 else -1.0
	var tw := UIStyle.restart_tween(cw, "tilt_tw")
	UIStyle.tween_token(tw, cw, "rotation_degrees", OFFER_TILT_DEG * side if on else 0.0, "hover" if on else "hover_out")


## A new offer's reveal: each card flips open (its width grows from an edge-on sliver) OFFER_FLIP
## after the one before, with the card_draw cue; under reduce motion they fade in together.
func _reveal(cards: Array) -> void:
	if cards.is_empty() or not (cards[0] as Control).is_inside_tree():
		return
	for i in cards.size():
		var cw: CardWidget = cards[i]
		cw.modulate.a = 0.0
		var tw := cw.create_tween()
		if UIStyle.reduce_motion:
			tw.tween_property(cw, "modulate:a", 1.0, UIStyle.motion("reduced"))
			continue
		tw.tween_interval(UIStyle.dur(OFFER_FLIP * i))
		tw.tween_callback(func():
			if not is_instance_valid(cw):
				return
			cw.pivot_offset = cw.size / 2.0
			cw.scale = Vector2(0.04, 1.0)
			cw.modulate.a = 1.0
			Sfx.play("card_draw"))
		tw.tween_property(cw, "scale", Vector2.ONE, UIStyle.dur(OFFER_FLIP * 2.0)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## What the other seat is doing in a draft (its progress only; its offers are never sent).
func _opponent_doing(dr: Dictionary) -> String:
	var od: Dictionary = dr.get("opponent", {})
	if od.is_empty():
		return "drafting…"
	return "is drafting (pick %d of %d)…" % [mini(int(od["step"]) + 1, int(od["total"])), int(od["total"])]


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
	var note := UIStyle.label("Pick a Type and a Race. Your drafted deck gets %d copies of it. You can change it until your draft is done." % copies, 14, UIStyle.TEXT_DIM, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(560, 0)
	hp.body.add_child(note)
	var cur: Dictionary = dr.get("basic", {})
	var picker := BasicUnitPicker.new(dr.get("basic_types", []), dr.get("basic_races", []), dr.get("basic_options", []), String(cur.get("type", "")), String(cur.get("race", "")))
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
		_close_picker()
		gs.send({"t": "draft_basic", "basic_type": picker.type, "basic_race": picker.race}))
	hp.appear()
	picker.focus_first.call_deferred()


## Closes the basic-unit picker, if open.
func _close_picker() -> void:
	if _picker_dim != null and is_instance_valid(_picker_dim):
		_picker_dim.queue_free()
	_picker_dim = null


## Row of diamonds (review #57): picks made are gold, the current one breathes, future ones are
## bronze outlines; grouped in fours by a small extra gap. Past PIP_MAX picks the row samples them.
class DraftPips extends Control:
	var step := 0
	var total := 1

	func _init(s: int, t: int) -> void:
		step = s
		total = maxi(t, 1)
		custom_minimum_size = Vector2(DraftPips.row_width(mini(total, PIP_MAX)), PIP_R * 2.0 + 10.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Width of a row of `n` pips (the groups' extra gaps included).
	static func row_width(n: int) -> float:
		return n * PIP_PITCH + float(maxi(0, (n - 1) / PIP_GROUP)) * PIP_GROUP_GAP

	## Centre x of pip `i`.
	static func pip_x(i: int) -> float:
		return PIP_PITCH / 2.0 + i * PIP_PITCH + float(i / PIP_GROUP) * PIP_GROUP_GAP

	func _process(_d: float) -> void:
		if not UIStyle.reduce_motion and is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var n := mini(total, PIP_MAX)
		var k := UIStyle.breathe(float(Time.get_ticks_msec()) / 1000.0, 0.35)
		for i in n:
			var c := Vector2(pip_x(i), size.y / 2.0)
			var idx := int(float(i) * total / n)
			if idx < step:
				Ornate.diamond(self, c + Vector2(0, 1), PIP_R, Color(0, 0, 0, 0.5))
				Ornate.diamond(self, c, PIP_R, UIStyle.GOLD)
				Ornate.diamond(self, c + Vector2(0, -1.5), PIP_R * 0.45, Color(UIStyle.GOLD_HI, 0.9))
			elif idx == step:
				Ornate.diamond(self, c, PIP_R + 4.0, Color(UIStyle.GOLD_HI, 0.22 * k))
				Ornate.diamond(self, c, PIP_R + 1.0, Color(UIStyle.GOLD_HI, clampf(0.85 * k, 0.0, 1.0)))
				Ornate.diamond(self, c, PIP_R * 0.45, Color(1, 0.97, 0.85, 0.95))
			else:
				Ornate.diamond(self, c, PIP_R, Color(UIStyle.BRONZE.lightened(0.15), 0.85))
				Ornate.diamond(self, c, PIP_R - 1.6, Color(0.05, 0.04, 0.03, 1.0))


## Small vector glyph for the tabs: "shield" (Structure) or "tome" (Custom).
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
