class_name GameSeriesOverlay
extends RefCounted
## Series-stage modal of the match screen (deck choice, rewards, who goes first, series over),
## the "your deck" popup and the network pause veil. Built on the GameScreen node; it renders
## from the screen's series view and sends commands through it.

const DECK_SORT := ["basic_unit", "unit", "spell", "trap", "power", "fusion", "ritual", "arcane"]
const PAUSE_W := 440.0
## Draft offer: scale of a hovered card, and the row height that leaves room for it.
const DRAFT_HOVER_SCALE := 1.06
const DRAFT_CARD_ROOM := 400.0

## The host screen this component works on.
var gs: GameScreen
## Reward sub-panels shown on the rewards stage.
var rewards: GameRewardPanels

## Dim shown while the match is paused.
var pause_dim: ColorRect
## Panel with the pause message.
var pause_panel: PanelContainer
## Content of the pause panel.
var pause_box: VBoxContainer
## Dim behind the series overlay.
var overlay_dim: ColorRect
## Series-stage modal (rewards, decks, results).
var overlay: PanelContainer
## Content of the series modal.
var overlay_box: VBoxContainer
## Popup listing a pile.
var pile_popup: PanelContainer
## Content of the pile popup.
var pile_box: VBoxContainer

## Hash of the series view last rendered (0 forces a re-render).
var overlay_sig: int = 0
## Deck tile id -> full card list expanded.
var deck_open: Dictionary = {}
var _overlay_want: Vector2 = Vector2(900, 600)
var _overlay_max: Vector2 = Vector2(900, 600)
var _overlay_stage: String = ""
## Deck-select stage renderer (tabs, tiles, waiting state, draft).
var decks: DeckSelectView
## True while the modal keeps its full height (a scrolling list inside).
var _fixed_height: bool = false


func _init(screen: GameScreen) -> void:
	gs = screen
	rewards = GameRewardPanels.new(screen)
	decks = DeckSelectView.new(self)


## Builds the pause veil (dim + panel); shown while a network match is paused.
func build_pause() -> void:
	pause_dim = ColorRect.new()
	pause_dim.color = Color(0, 0, 0, 0.6)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dim.visible = false
	gs.add_child(pause_dim)
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(UIStyle.PANEL, 0.98), UIStyle.GOLD))
	pause_panel.custom_minimum_size = Vector2(PAUSE_W, 0)
	pause_dim.add_child(pause_panel)
	pause_box = VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 8)
	pause_panel.add_child(pause_box)


## Builds the stage modal (dim + scrolling panel) and the deck popup.
func build_modals() -> void:
	overlay_dim = ColorRect.new()
	overlay_dim.color = Color(0, 0, 0, 0.6)
	overlay_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_dim.visible = false
	gs.add_child(overlay_dim)
	var op := OrnatePanel.new(14, 10)
	op.box().shadow_size = 28
	overlay = op
	overlay.visible = false
	gs.add_child(overlay)
	var sc := SmoothScroll.new()
	overlay.add_child(sc)
	overlay_box = VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", 12)
	var wrap := GameUi.glow_room(overlay_box, 14)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(wrap)
	pile_popup = PanelContainer.new()
	pile_popup.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.07, 0.065, 0.06, 0.98), UIStyle.SELECT, 12))
	pile_popup.visible = false
	gs.add_child(pile_popup)
	var ps := ScrollContainer.new()
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pile_popup.add_child(ps)
	pile_box = VBoxContainer.new()
	pile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_box.add_theme_constant_override("separation", 6)
	ps.add_child(GameUi.glow_room(pile_box, 12))


## Places the pause veil over the play field (below the top strip).
func layout_pause(w: float, h: float) -> void:
	pause_dim.position = Vector2(0, GameScreen.TOP_H)
	pause_dim.size = Vector2(w - gs.sidebar_w, h - GameScreen.TOP_H)
	pause_panel.position = (pause_dim.size - Vector2(PAUSE_W, 160)) / 2.0


## Centres the stage modal (and the pile popup) in the left-hand play area.
func place_modals() -> void:
	var region := Rect2(0, GameScreen.TOP_H, gs.size.x - gs.sidebar_w, gs.size.y - GameScreen.TOP_H)
	overlay_dim.position = region.position
	overlay_dim.size = region.size
	var sz := Vector2(minf(_overlay_want.x, region.size.x - 40.0), minf(_overlay_want.y, region.size.y - 24.0))
	overlay.size = sz
	overlay.position = region.position + (region.size - sz) / 2.0
	pile_popup.position = Vector2(40, GameScreen.TOP_H + 26.0)
	pile_popup.size = Vector2(maxf(200.0, gs.size.x - gs.sidebar_w - 80.0), maxf(160.0, gs.size.y - GameScreen.TOP_H - GameScreen.HAND_H - 40.0))


## Shrinks the modal to its content once the layout has settled (two frames).
func _fit_overlay() -> void:
	await gs.get_tree().process_frame
	await gs.get_tree().process_frame
	if not overlay.visible:
		return
	var need := overlay_box.get_combined_minimum_size().y + 68.0
	if _fixed_height:
		need = _overlay_max.y
		var la := decks.list_area
		if la != null and la.scroll.get_child_count() > 0:
			# Hug the tile list when it is shorter than the screen allows.
			need = overlay_box.get_combined_minimum_size().y - la.get_combined_minimum_size().y 				+ (la.scroll.get_child(0) as Control).get_combined_minimum_size().y + 68.0 + 26.0
	_overlay_want = Vector2(_overlay_max.x, minf(need, _overlay_max.y))
	place_modals()


## Pause veil: shown while the network match is paused, with the host's claim button.
func render_pause() -> void:
	var net: Dictionary = gs.view.get("net", {})
	var paused: bool = not net.is_empty() and net.get("paused", false)
	pause_dim.visible = paused
	GameUi.clear(pause_box)
	if not paused:
		return
	pause_box.add_child(UIStyle.label("MATCH PAUSED", 26, UIStyle.BAD, false, true))
	pause_box.add_child(UIStyle.label(net["message"] if net.get("message", "") != "" else "Waiting for the connection to be restored. Nothing can happen until both players are connected.", 14, UIStyle.TEXT, true))
	if net.get("is_host", false) and gs.view.get("stage", "") == "game" and net.get("claim_in", -1) >= 0:
		var wait: int = net["claim_in"]
		var claim := UIStyle.primary_button("Claim this game (opponent absent)" if wait == 0 else "Claim this game available in %d s" % wait, 14)
		claim.disabled = wait > 0
		claim.tooltip_text = "Wins the current game only; the series continues."
		claim.pressed.connect(func(): gs.send({"t": "claim_game"}))
		pause_box.add_child(claim)
	pause_box.add_child(UIStyle.label("You can still use Menu or inspect the log.", 12, UIStyle.MUTED, true))
	pause_panel.set_deferred("size", Vector2(PAUSE_W, 0))


## Your current deck (between games): every card once, with its number of copies.
func _show_deck() -> void:
	GameUi.clear(pile_box)
	var cards: Array = gs.view.get("deck", [])
	var counts := {}
	var order := []
	for c in cards:
		if not counts.has(c["id"]):
			order.append(c)
		counts[c["id"]] = counts.get(c["id"], 0) + 1
	order.sort_custom(func(a, b):
		var ka := DECK_SORT.find(String(a["category"]))
		var kb := DECK_SORT.find(String(b["category"]))
		return ka < kb if ka != kb else String(a["name"]) < String(b["name"]))
	var head := HBoxContainer.new()
	pile_box.add_child(head)
	var tl := UIStyle.label("Your deck (%d cards)" % cards.size(), 18, UIStyle.GOLD, true, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := UIStyle.button("Close", 13)
	close.pressed.connect(func(): pile_popup.visible = false)
	head.add_child(close)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	pile_box.add_child(flow)
	for c in order:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		flow.add_child(cell)
		var w := CardWidget.new().setup(MatchView.summary_view(c), "hand")
		w.auto_hover = true
		w.right_pressed.connect(gs.inspect.inspect_widget)
		cell.add_child(w)
		if int(counts[c["id"]]) > 1:
			var n := UIStyle.label("×%d" % int(counts[c["id"]]), 15, UIStyle.GOLD_HI, false, true)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(n)
	pile_popup.z_index = UiLayers.PILE_POPUP
	pile_popup.visible = true


## Shows the modal for the current series stage (hidden during a game); re-renders only when
## the series view changed.
func render() -> void:
	var view := gs.view
	var stage: String = view.get("stage", "")
	if stage != "game" and stage != "" and gs.fx != null and gs.fx.game_end_hold:
		return   # F03-13: held back until the victory / defeat presentation has played
	var sig := 1
	if stage != "game":
		var vv := view.duplicate()
		vv.erase("match")
		sig = hash([vv, deck_open])
	if sig == overlay_sig:
		return
	overlay_sig = sig
	GameUi.clear(overlay_box)
	if stage == "game" or stage == "":
		overlay.visible = false
		overlay_dim.visible = false
		_overlay_stage = ""
		rewards.mode = ""
		return
	overlay.visible = true
	overlay_dim.visible = true
	gs.hover.clear()
	var want := Vector2(1000, 800)
	match stage:
		"decks": want = Vector2(1180, 860)
		"rewards": want = Vector2(740, 900)
		"first_player": want = Vector2(620, 420)
		"over": want = Vector2(660, 760)
	_overlay_max = want
	# Re-rendering the same stage keeps the current size (no full-size flash); _fit_overlay then
	# grows or shrinks it to the new content.
	if stage != _overlay_stage:
		_overlay_want = want
		_overlay_stage = stage
	overlay_box.custom_minimum_size = Vector2(want.x - 84.0, 0)
	if stage != "over":
		overlay_box.add_child(_stage_header(stage))
	_fixed_height = false
	match stage:
		"decks": _render_decks()
		"rewards": rewards.render()
		"first_player": _render_first()
		"over": _render_over()
	if stage == "first_player" and view.has("deck"):
		var see := UIStyle.button("View your deck", 15)
		see.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		see.pressed.connect(_show_deck)
		overlay_box.add_child(see)
	place_modals()
	_fit_overlay()


## Shared stage header: Cinzel title between flourished rules, then seat plates around the score.
func _stage_header(stage: String) -> Control:
	var view := gs.view
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := UIStyle.label(stage_title(stage), 30, UIStyle.GOLD, false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	t.add_theme_constant_override("outline_size", 4)
	v.add_child(t)
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.8), true, 16.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for i in 2:
		if i == 1:
			var sc := UIStyle.label("%d – %d" % [view["scores"][0], view["scores"][1]], 26, UIStyle.GOLD_HI, false, true)
			sc.add_theme_font_override("font", UIStyle.font_display(700))
			row.add_child(sc)
		row.add_child(_seat_plate(String(view["names"][i]), i == gs.me()))
	var bo := UIStyle.label("BEST OF %d" % int(view["best_of"]), 12, UIStyle.TEXT_DIM, false, true)
	bo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bo)
	return v


func _seat_plate(nm: String, mine: bool) -> Control:
	var p := PanelContainer.new()
	var col: Color = UIStyle.GOLD if mine else UIStyle.BRONZE
	var sb := UIStyle.flat(Color(col.darkened(0.8), 0.95), col, 1, 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	if mine:
		var yt := UIStyle.label("YOU", 11, UIStyle.GOLD, false, true)
		yt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(yt)
	h.add_child(UIStyle.label(nm, 17, UIStyle.TEXT if mine else UIStyle.MUTED, false, true))
	return p


## Forces the modal to rebuild now (after a local choice that the view does not reflect).
func refresh() -> void:
	overlay_sig = 0
	render()


## Title of a series stage ("" for the game itself).
func stage_title(stage: String) -> String:
	match stage:
		"decks": return "Choose your deck" if gs.view.get("deck_mode", "starter") == "starter" else "Draft your deck"
		"rewards": return "Game %d complete — rewards" % gs.view["game_no"]
		"first_player": return "Next game"
		"over": return "Series over"
	return ""


## "X won game N (turn T, HP a–b)." for the last finished game, or "".
func game_result_line() -> String:
	if gs.view.get("history", []).is_empty():
		return ""
	var h: Dictionary = gs.view["history"][-1]
	return "%s won game %d (turn %d, HP %d–%d)." % [gs.view["names"][h["winner"]], h["game"], h["turns"], h["hp"][0], h["hp"][1]]


func _render_decks() -> void:
	_fixed_height = decks.render()
	decks.restore_scroll()


## Hover lift of a draft / reward card: eases its real size (lift_k, about its centre, F04-05) to `to`.
func _lift(cw: CardWidget, to: float) -> void:
	if not is_instance_valid(cw):
		return
	var old = cw.get_meta("lift_tw", null)
	if old is Tween and old.is_valid():
		old.kill()
	var t := cw.create_tween()
	cw.set_meta("lift_tw", t)
	t.tween_property(cw, "lift_k", to, UIStyle.dur(0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The one or two Types most units of a deck share (crest colours).
static func _dominant_types(cards: Array) -> Array:
	var counts := {}
	for c in cards:
		var t: String = c.get("type", "")
		if t != "" and c.get("atk") != null:
			counts[t] = counts.get(t, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var out := []
	for k in keys:
		if out.is_empty() or (out.size() < 2 and counts[k] * 3 >= counts[keys[0]]):
			out.append(k)
	return out


## Up to five showcase cards: Extra Deck cards first, then the strongest units.
static func _key_cards(main: Array, extra: Array) -> Array:
	var out := []
	var seen := {}
	for c in extra:
		if out.size() < 2 and not seen.has(c["id"]):
			seen[c["id"]] = true
			out.append(c)
	var units := main.filter(func(c): return c["category"] != "basic_unit" and c.get("atk") != null)
	units.sort_custom(func(a, b): return int(a["atk"]) + int(a["def"]) > int(b["atk"]) + int(b["def"]))
	for c in units:
		if out.size() < 5 and not seen.has(c["id"]):
			seen[c["id"]] = true
			out.append(c)
	for c in main:
		if out.size() < 5 and not seen.has(c["id"]) and c["category"] != "basic_unit":
			seen[c["id"]] = true
			out.append(c)
	return out


## "Name ×2, Other" list of a deck's cards in first-seen order.
static func _grouped_names(cards: Array) -> String:
	var order := []
	var n := {}
	for c in cards:
		if not n.has(c["id"]):
			order.append(c)
		n[c["id"]] = n.get(c["id"], 0) + 1
	return ", ".join(order.map(func(c): return c["name"] + (" ×%d" % n[c["id"]] if n[c["id"]] > 1 else "")))


func _render_first() -> void:
	var view := gs.view
	var line := game_result_line()
	if line != "":
		overlay_box.add_child(UIStyle.label(line, 17, UIStyle.TEXT, true))
	if view["last_loser"] == gs.me():
		overlay_box.add_child(UIStyle.label("You lost the last game, so you choose who goes first in game %d." % (view["game_no"] + 1), 18, UIStyle.ACCENT, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		overlay_box.add_child(row)
		var b1 := UIStyle.primary_button("I go first", 17)
		b1.pressed.connect(func(): gs.send({"t": "first_player", "who": gs.me()}))
		row.add_child(b1)
		var b2 := UIStyle.button("My opponent goes first", 17)
		b2.pressed.connect(func(): gs.send({"t": "first_player", "who": 1 - gs.me()}))
		row.add_child(b2)
	else:
		overlay_box.add_child(UIStyle.label("Your opponent lost the last game and is choosing who goes first…", 17, UIStyle.TEXT, true))


func _render_over() -> void:
	var view := gs.view
	var w := 0 if view["scores"][0] > view["scores"][1] else 1
	var forfeit: int = view.get("forfeit_by", -1)
	if forfeit != -1:
		w = 1 - forfeit
	var won: bool = w == gs.me()
	var res := UIStyle.label("VICTORY" if won else "DEFEAT", 64, UIStyle.GOLD_HI if won else UIStyle.BAD, false, true)
	res.add_theme_font_override("font", UIStyle.font_display(700))
	res.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	res.add_theme_constant_override("outline_size", 6)
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(res)
	var sub := UIStyle.label("%s wins the series" % view["names"][w], 20, UIStyle.TEXT, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(sub)
	if forfeit != -1:
		var ff := UIStyle.label("%s left and forfeited the series." % view["names"][forfeit], 16, UIStyle.BAD, true)
		ff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_box.add_child(ff)
	var score := HBoxContainer.new()
	score.alignment = BoxContainer.ALIGNMENT_CENTER
	score.add_theme_constant_override("separation", 18)
	overlay_box.add_child(score)
	score.add_child(UIStyle.label(view["names"][0], 20, UIStyle.TEXT, false, true))
	score.add_child(UIStyle.label("%d – %d" % [view["scores"][0], view["scores"][1]], 40, UIStyle.GOLD, false, true))
	score.add_child(UIStyle.label(view["names"][1], 20, UIStyle.TEXT, false, true))
	overlay_box.add_child(UIStyle.label("Game history", 16, UIStyle.GOLD, false, true))
	for h in view["history"]:
		var hw: bool = h["winner"] == gs.me()
		var rowp := PanelContainer.new()
		rowp.add_theme_stylebox_override("panel", UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.9), Color(UIStyle.GOOD if hw else UIStyle.BAD, 0.7), 1, 6))
		overlay_box.add_child(rowp)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		rowp.add_child(hb)
		hb.add_child(GameUi.pill("WIN" if hw else "LOSS", UIStyle.GOOD if hw else UIStyle.BAD))
		var t := UIStyle.label("Game %d — %s won" % [h["game"], view["names"][h["winner"]]], 16, UIStyle.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(t)
		hb.add_child(UIStyle.label("Turn %d · HP %d–%d" % [h["turns"], h["hp"][0], h["hp"][1]], 14, UIStyle.MUTED))
	var b := UIStyle.primary_button("Back to main menu", 17)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): gs.back_to_menu.emit())
	overlay_box.add_child(b)
