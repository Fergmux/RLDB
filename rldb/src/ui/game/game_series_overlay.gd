class_name GameSeriesOverlay
extends RefCounted
## Series-stage modal of the match screen (deck choice, rewards, who goes first, series over),
## the "your deck" popup and the network pause veil. Built on the GameScreen node; it renders
## from the screen's series view and sends commands through it.

## Series-over screen (design review #65): the score size, the loser's score opacity and the
## width of the hero Back to main menu button.
const SCORE_SIZE := 44
const LOSER_SCORE_ALPHA := 0.6
const HERO_CTA_W := 240.0

const DECK_SORT := ["basic_unit", "unit", "spell", "trap", "power", "fusion", "ritual", "arcane"]
const PAUSE_W := 440.0
## Draft offer: scale of a hovered card, and the row height that leaves room for it.
const DRAFT_HOVER_SCALE := 1.06
const DRAFT_CARD_ROOM := 400.0

## The host screen this component works on.
## When the current network pause began (ms; the "Waiting m:ss" count, #67).
var _paused_at: int = 0

var gs: GameScreen
## Reward sub-panels shown on the rewards stage.
var rewards: GameRewardPanels

## Dim shown while the match is paused.
var pause_dim: ColorRect
## Panel with the pause message.
var pause_panel: PanelContainer
## Content of the pause panel.
var pause_box: VBoxContainer
## Dim behind the series overlay (the whole window; clicks on the top strip's buttons pass through).
var overlay_dim: ModalDim
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
	# Above the series modal, which used to hide the veil between duels; below the in-game menu so
	# Menu still works while paused.
	pause_dim.z_index = UiLayers.PAUSE
	gs.add_child(pause_dim)
	var pp := HousePanel.new("Match paused", "Network", Vector2(22, 18), 8)
	pause_panel = pp
	pause_panel.custom_minimum_size = Vector2(PAUSE_W, 0)
	pause_dim.add_child(pause_panel)
	pause_box = pp.body


## Builds the stage modal (dim + scrolling panel) and the deck popup.
func build_modals() -> void:
	overlay_dim = ModalDim.new()
	overlay_dim.pass_through = gs.menu.over_top_button
	overlay_dim.color = Color(0, 0, 0, 0.6)
	overlay_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_dim.visible = false
	overlay_dim.z_index = UiLayers.SERIES_MODAL   # J10: above every board layer of the finished game
	gs.add_child(overlay_dim)
	var op := HousePanel.new("Series", "", Vector2(10, 10), 4)
	op.arm = 22.0
	overlay = op
	overlay.visible = false
	overlay.z_index = UiLayers.SERIES_MODAL
	gs.add_child(overlay)
	# Controls take clicks in tree order, not z order: the pause veil and the top strip's popovers (Chat,
	# Spectators), built earlier but drawn above the modal, must also come after it in the tree, or the
	# modal and its dim under them would take their clicks.
	for late in [pause_dim, gs.chat.panel, gs.spectate.panel]:
		if late != null and (late as Node).get_parent() == gs:
			gs.move_child(late, -1)
	var sc := SmoothScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	op.body.add_child(sc)
	overlay_box = VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", 12)
	var wrap := GameUi.glow_room(overlay_box, 14)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(wrap)
	var pp := HousePanel.new("Your deck", "", Vector2(12, 12), 6)
	pile_popup = pp
	pile_popup.visible = false
	gs.add_child(pile_popup)
	var ps := ScrollContainer.new()
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pp.body.add_child(ps)
	pile_box = VBoxContainer.new()
	pile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_box.add_theme_constant_override("separation", 6)
	ps.add_child(GameUi.glow_room(pile_box, 12))


## Places the pause veil over the play field (below the top strip).
func layout_pause(w: float, h: float) -> void:
	pause_dim.position = Vector2(0, GameScreen.TOP_H)
	pause_dim.size = Vector2(w - gs.sidebar_w, h - GameScreen.TOP_H)
	pause_panel.position = (pause_dim.size - Vector2(PAUSE_W, 160)) / 2.0


## Centres the stage modal (and the pile popup) in the left-hand play area. J15 (owner, 22 Oct): its dim
## fills the window from the top edge (the top strip's buttons are raised above it in place) and, after a
## game (rewards, next game, series over), the sidebar too. During the deck choice the sidebar stays live:
## it holds the draft's "Your draft" list.
func place_modals() -> void:
	var region := Rect2(0, GameScreen.TOP_H, gs.size.x - gs.sidebar_w, gs.size.y - GameScreen.TOP_H)
	overlay_dim.position = Vector2.ZERO
	overlay_dim.size = Vector2(gs.size.x - gs.sidebar_w, gs.size.y) if String(gs.view.get("stage", "")) == "decks" else gs.size
	var sz := Vector2(minf(_overlay_want.x, region.size.x - 40.0), minf(_overlay_want.y, region.size.y - 24.0))
	# F01: the content's minimum width follows the window, so a small window never forces the
	# modal wider than the play area (it would clip); the content scrolls inside instead.
	if overlay_box != null and _overlay_stage != "":
		var mw := _content_w(sz.x)
		if not is_equal_approx(overlay_box.custom_minimum_size.x, mw):
			overlay_box.custom_minimum_size.x = mw
	overlay.size = sz
	overlay.position = region.position + (region.size - sz) / 2.0
	pile_popup.position = Vector2(40, GameScreen.TOP_H + 26.0)
	pile_popup.size = Vector2(maxf(200.0, gs.size.x - gs.sidebar_w - 80.0), maxf(160.0, gs.size.y - GameScreen.TOP_H - GameScreen.HAND_H - 40.0))


## Shrinks the modal to its content once the layout has settled (two frames).
func _fit_overlay() -> void:
	if not gs.is_inside_tree():
		return
	var tree := gs.get_tree()
	await tree.process_frame
	await tree.process_frame
	# The screen may have been closed meanwhile (left to the menu right after a re-render).
	if not is_instance_valid(gs) or not is_instance_valid(overlay) or not overlay.visible:
		return
	var need := overlay_box.get_combined_minimum_size().y + _chrome_h()
	if _fixed_height:
		# F01: the deck list keeps the modal's full size on every tab (sparse, empty or long), so
		# switching tabs never collapses or moves it; the list scrolls inside.
		need = _overlay_max.y
	_overlay_want = Vector2(_overlay_max.x, minf(need, _overlay_max.y))
	place_modals()


## Width of the stage modal in the current window (its stage maximum, narrowed to the play area).
func modal_width() -> float:
	return minf(_overlay_max.x, gs.size.x - gs.sidebar_w - 40.0)


## Minimum width of the modal's content for a modal `w` wide (chrome, glow room and slack off).
func _content_w(w: float) -> float:
	return maxf(240.0, w - 84.0 - (overlay as HousePanel).chrome_size().x + 20.0)


## Height the modal adds around its content: the house plate's margins and header strip, the glow
## room around the content (14 px a side) and 20 px of slack.
func _chrome_h() -> float:
	return (overlay as HousePanel).chrome_size().y + 28.0 + 20.0


## Pause veil: shown while the network match is paused, with the host's claim button.
func render_pause() -> void:
	var net: Dictionary = gs.view.get("net", {})
	var paused: bool = not net.is_empty() and net.get("paused", false)
	var opening := paused and not pause_dim.visible
	pause_dim.visible = paused
	GameUi.clear(pause_box)
	if not paused:
		return
	if opening:
		(pause_panel as HousePanel).appear()
		_paused_at = Time.get_ticks_msec()
	# Design review #67: a turning rune ring beside the title and a "Waiting m:ss" count, so the
	# wait reads as alive; a secondary "Leave match" offers the way out (the usual leave choices).
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", UIStyle.sp("md"))
	pause_box.add_child(hrow)
	var runes := PauseRunes.new()
	runes.name = "PauseRunes"
	hrow.add_child(runes)
	var head := UIStyle.label("Match paused", 26, UIStyle.BAD, true, true)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(head)
	TitleText.apply(head, TitleText.Tier.SCREEN, 26)
	pause_box.add_child(Ornate.Rule.new(Color(UIStyle.BAD, 0.55), true, 10.0))
	pause_box.add_child(UIStyle.label(net["message"] if net.get("message", "") != "" else "Waiting for the connection to be restored. Nothing can happen until both players are connected.", 14, UIStyle.TEXT, true))
	if net.get("is_host", false) and gs.view.get("stage", "") == "game" and net.get("claim_in", -1) >= 0:
		var wait: int = net["claim_in"]
		var claim := UIStyle.primary_button("Claim this game (opponent absent)" if wait == 0 else "Claim this game available in %d s" % wait, 14)
		claim.disabled = wait > 0
		claim.tooltip_text = "Wins the current game only; the series continues."
		claim.pressed.connect(func(): gs.send({"t": "claim_game"}))
		pause_box.add_child(claim)
	var since := Elapsed.new(_paused_at)
	since.name = "PauseElapsed"
	pause_box.add_child(since)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UIStyle.sp("md"))
	pause_box.add_child(foot)
	var note := UIStyle.label("You can still use Menu or inspect the log.", 13, UIStyle.MUTED, true)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(note)
	var leave := UIStyle.size_button(UIStyle.secondary_button("Leave match", 14), "small")
	leave.name = "LeaveMatch"
	leave.tooltip_text = "Save the series for later, or forfeit it, and return to the main menu."
	leave.pressed.connect(func(): gs.menu.confirm_forfeit(false))
	foot.add_child(leave)
	pause_panel.set_deferred("size", Vector2(PAUSE_W, 0))


## J15: the series modal's full-window dim. It takes every click (the finished board stays out of reach)
## except those over the top strip's buttons, which sit above it: Controls take clicks in tree order,
## not by z_index, so the dim lets those points through itself.
class ModalDim extends ColorRect:
	## Callable(global point: Vector2) -> bool: true where a click must reach what is under the dim.
	var pass_through: Callable

	func _has_point(point: Vector2) -> bool:
		if not Rect2(Vector2.ZERO, size).has_point(point):
			return false
		return not (pass_through.is_valid() and bool(pass_through.call(get_global_transform() * point)))


## "Waiting m:ss" since the pause began (#67), counting up once a second.
class Elapsed extends Label:
	var start_ms := 0

	func _init(from_ms: int) -> void:
		start_ms = from_ms
		add_theme_font_size_override("font_size", 14)
		add_theme_color_override("font_color", UIStyle.TEXT)
		_tick()

	func _process(_d: float) -> void:
		_tick()

	func _tick() -> void:
		var s := maxi(0, (Time.get_ticks_msec() - start_ms) / 1000)
		var t := "Waiting %d:%02d" % [s / 60, s % 60]
		if t != text:
			text = t


## A small rune ring turning once every PERIOD seconds beside the pause title (#67); still under
## reduce motion.
class PauseRunes extends Control:
	const PERIOD := 3.0
	const MARKS := 12

	func _init() -> void:
		custom_minimum_size = Vector2(36, 36)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if not UIStyle.reduce_motion and is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		var turn := 0.0 if UIStyle.reduce_motion else fposmod(float(Time.get_ticks_msec()) / 1000.0 / PERIOD, 1.0) * TAU
		draw_circle(c, r + 2.0, Color(UIStyle.BAD, 0.08), true, -1.0, true)
		draw_arc(c, r, 0.0, TAU, 40, Color(UIStyle.GOLD, 0.55), 1.5, true)
		draw_arc(c, r - 7.0, 0.0, TAU, 40, Color(UIStyle.GOLD, 0.3), 1.0, true)
		for i in MARKS:
			var a := turn + TAU * float(i) / MARKS
			var d := Vector2(cos(a), sin(a))
			var lit := 0.35 + 0.65 * (float(i) / MARKS)
			draw_line(c + d * (r - 5.5), c + d * (r - 1.5), Color(UIStyle.GOLD_HI, lit), 1.6, true)
		draw_circle(c, 2.5, Color(UIStyle.BAD, 0.8), true, -1.0, true)


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
	(pile_popup as HousePanel).set_tag("%d cards" % cards.size())
	var head := HBoxContainer.new()
	pile_box.add_child(head)
	var tl := UIStyle.label("Your deck (%d cards)" % cards.size(), 18, UIStyle.GOLD_HI, true, true)
	TitleText.apply(tl, TitleText.Tier.SECTION, 18)
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
	(pile_popup as HousePanel).appear()


## Shows the modal for the current series stage (hidden during a game); re-renders only when
## the series view changed.
func render() -> void:
	var view := gs.view
	var stage: String = view.get("stage", "")
	if stage != "game" and stage != "" and gs.fx != null and gs.fx.game_end_hold:
		return   # F03-13: held back until the victory / defeat presentation has played
	if rewards != null and rewards.folding() and overlay.visible:
		return   # L2: a reward fold is playing; its end renders the latest view (GameRewardPanels._after)
	var sig := _view_sig()
	if sig == overlay_sig:
		return
	overlay_sig = sig
	GameUi.clear(overlay_box)
	if stage == "game" or stage == "":
		overlay.visible = false
		overlay_dim.visible = false
		gs.menu.raise_top_strip(gs.coin_playing())   # K3: the coin flip's full-window dim raises it too
		_overlay_stage = ""
		rewards.mode = ""
		return
	var opening := not overlay.visible
	if opening:
		clear_board_interactions()
	overlay.visible = true
	overlay_dim.visible = true
	gs.menu.raise_top_strip(true)
	var house := overlay as HousePanel
	house.set_title("Series · %s" % String({"decks": "deck choice", "rewards": "rewards", "first_player": "next game", "over": "final result"}.get(stage, stage)))
	house.set_tag("Best of %d" % int(view.get("best_of", 3)))
	if opening:
		house.appear()
	gs.hover.clear()
	var want := Vector2(1000, 800)
	match stage:
		"decks": want = Vector2(1180, 860)
		"rewards": want = Vector2(740, 900)
		"first_player": want = Vector2(660, 640)   # G05: room for the ready plate; fits to content
		"over": want = Vector2(660, 760)
	_overlay_max = want
	# Re-rendering the same stage keeps the current size (no full-size flash); _fit_overlay then
	# grows or shrinks it to the new content.
	if stage != _overlay_stage:
		_overlay_want = want
		_overlay_stage = stage
	overlay_box.custom_minimum_size = Vector2(_content_w(modal_width()), 0)
	if stage != "over":
		overlay_box.add_child(_stage_header(stage))
	_fixed_height = false
	if gs.is_spectator():
		_render_spectator(stage)
		place_modals()
		_fit_overlay()
		return
	match stage:
		"decks": _render_decks()
		"rewards": rewards.render()
		"first_player": _render_first()
		"over": _render_over()
	if stage == "first_player" and view.has("deck"):
		var see := UIStyle.size_button(UIStyle.secondary_button("View your deck", 14), "small")
		see.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		see.pressed.connect(_show_deck)
		overlay_box.add_child(see)
	place_modals()
	_fit_overlay()


## J9 / J10 (owner, 22 Oct): drops everything the finished game left in hand: the click-selection and its
## action row, a hover lift, an open card inspector or pile browser, the Fusion-method picker and a status
## tip. Called when the killing blow's view arrives and again when the series modal opens.
func clear_board_interactions() -> void:
	gs.selection.deselect()
	gs.keyboard.kb_uid = -1
	gs.action_row.clear()
	gs.hover.clear()
	gs.inspect.close_all()
	gs.details.close_method_picker()
	StatusTip.hide_all()


## Shared stage header: Cinzel title between flourished rules, then seat plates around the score.
func _stage_header(stage: String) -> Control:
	var view := gs.view
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := UIStyle.label(stage_title(stage), 30, UIStyle.GOLD, false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	TitleText.apply(t, TitleText.Tier.SCREEN, 30)   # D3: T2 screen title
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.8), true, 16.0))
	var score := func(t: String) -> Label:
		var sc := UIStyle.label(t, 26, UIStyle.GOLD_HI, false, true)
		sc.add_theme_font_override("font", UIStyle.font_display(700))
		return sc
	var spec := gs.is_spectator()
	v.add_child(score_row(_seat_plate(String(view["names"][0]), gs.me() == 0 and not spec), _seat_plate(String(view["names"][1]), gs.me() == 1 and not spec),
		view["scores"], score, 14))
	return v


## "<left> 2 – 1 <right>" with the dash on the row's centre line, whatever the names' or scores'
## widths: each half (seat and its score) fills half the row and hugs the dash. `make_label` builds
## each piece of score text (Callable(String) -> Label).
static func score_row(left: Control, right: Control, scores: Array, make_label: Callable, sep: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", sep)
	var halves := []
	for i in 2:
		var h := HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.alignment = BoxContainer.ALIGNMENT_END if i == 0 else BoxContainer.ALIGNMENT_BEGIN
		h.add_theme_constant_override("separation", sep)
		halves.append(h)
	var n0: Control = make_label.call(str(scores[0]))
	var n1: Control = make_label.call(str(scores[1]))
	for c in [left, n0, n1, right]:
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	halves[0].add_child(left)
	halves[0].add_child(n0)
	halves[1].add_child(n1)
	halves[1].add_child(right)
	var dash: Control = make_label.call("–")
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(halves[0])
	row.add_child(dash)
	row.add_child(halves[1])
	return row


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


## Signature of what the modal shows: the series view (without the match) and the open deck tile.
func _view_sig() -> int:
	var view := gs.view
	if String(view.get("stage", "")) == "game":
		return 1
	var vv := view.duplicate()
	vv.erase("match")
	return hash([vv, deck_open])


## Records the current content as rendered after a change made in place (G02: a deck tile opened
## or closed without a rebuild), so the next view update does not rebuild for it.
func mark_rendered() -> void:
	overlay_sig = _view_sig()


## Forces the modal to rebuild now (after a local choice that the view does not reflect).
func refresh() -> void:
	overlay_sig = 0
	render()


## Title of a series stage ("" for the game itself).
func stage_title(stage: String) -> String:
	if gs.is_spectator():
		match stage:
			"decks": return "The players are choosing decks" if gs.view.get("deck_mode", "starter") == "starter" else "The players are drafting"
			"rewards": return "Game %d complete — rewards" % gs.view["game_no"]
			"first_player": return "Next game"
			"over": return "Series over"
	if stage == "decks" and decks != null and decks.bot_stage():
		return "Choose the bot's deck"   # J24: the second deck screen of a bot series
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


## Hover lift of a draft / reward card: eases its lift (lift_k, about its centre: real size, resting text layout, F04-05 / F05-03) to `to`.
func _lift(cw: CardWidget, to: float) -> void:
	if not is_instance_valid(cw):
		return
	var t := UIStyle.restart_tween(cw, "lift_tw")
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


## Who-goes-first stage (G05 / G06), centred: the last game's result, the loser's choice and the
## Start next duel button. The next duel starts once the loser has chosen and both seats have
## pressed Start (the bot presses at once; in hot-seat one press counts for both players).
func _render_first() -> void:
	var view := gs.view
	var me := gs.me()
	var opp := String(view["names"][1 - me])
	var nx: Dictionary = view.get("next", {})
	var chosen: bool = bool(nx.get("first_chosen", false))
	var first: int = int(nx.get("first_player", -1))
	var you_ready: bool = bool(nx.get("you_ready", false))
	var opp_ready: bool = bool(nx.get("opponent_ready", false))
	var next_no: int = int(view["game_no"]) + 1
	var line := game_result_line()
	if line != "":
		overlay_box.add_child(_centred(line, 17, UIStyle.TEXT))
	var chooser: bool = int(view["last_loser"]) == me
	if chooser:
		overlay_box.add_child(_centred("You lost the last game, so you choose who goes first in game %d." % next_no, 18, UIStyle.ACCENT))
		# Design review #60: the two answers are one segmented choice (the chosen one fills gold with a
		# check mark); Start next duel below is the screen's primary, disabled until a choice is made.
		var whos := [me, 1 - me]
		var sel := -1
		if chosen:
			sel = whos.find(first)
		# H22 (owner, 21 Oct): the two answers stand SPLIT_GAP apart, with extra room above and below.
		var seg := SegmentedChoice.new(["I go first", "My opponent goes first"], sel, 17, SegmentedChoice.SPLIT_GAP)
		seg.name = "FirstPlayerChoice"
		seg.set_disabled(you_ready)
		for i in seg.buttons.size():
			seg.buttons[i].tooltip_text = "Chosen" if i == sel else "Choose this"
		seg.chosen.connect(func(i: int): gs.send({"t": "first_player", "who": int(whos[i])}))
		var room := MarginContainer.new()
		room.name = "FirstPlayerRoom"
		room.add_theme_constant_override("margin_top", UIStyle.sp("sm"))
		room.add_theme_constant_override("margin_bottom", UIStyle.sp("md"))
		room.add_child(seg)
		overlay_box.add_child(room)
	elif chosen:
		overlay_box.add_child(_centred(("%s chose you to go first in game %d." if first == me else "%s chose to go first in game %d.") % [opp, next_no], 18, UIStyle.ACCENT))
	else:
		overlay_box.add_child(_centred("%s lost the last game and is choosing who goes first in game %d…" % [opp, next_no], 17, UIStyle.TEXT))
	if you_ready:
		var sub := "Waiting for %s to choose who goes first…" % opp if not chosen else "Waiting for %s to start the next duel…" % opp
		var chips := [{"text": "You: ready", "done": true},
			{"text": "%s: %s" % [opp, "ready" if opp_ready else "not ready yet"], "done": opp_ready}]
		var wp := WaitPlate.new("Ready for game %d" % next_no, sub, chips)
		wp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wp.custom_minimum_size = Vector2(minf(420.0, overlay_box.custom_minimum_size.x), 0)
		overlay_box.add_child(wp)
		return
	var start := UIStyle.primary_button("Start next duel", 19)
	start.custom_minimum_size = Vector2(260, 52)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.disabled = chooser and not chosen
	start.tooltip_text = "Choose who goes first, then start the next duel." if start.disabled else "Start game %d" % next_no
	start.pressed.connect(func(): gs.send({"t": "start_duel"}))
	overlay_box.add_child(start)
	if opp_ready and not gs.is_hotseat():
		overlay_box.add_child(_centred("%s is ready." % opp, 15, UIStyle.GOOD))


## A2: what a spectator sees between duels: each player's public progress as a ready plate, the
## last result and, at the end, the winner (no Victory / Defeat: the spectator did not play). Only
## "Stop watching" / "Back to main menu" can be pressed; nothing is sent to the host.
func _render_spectator(stage: String) -> void:
	var view := gs.view
	var names: Array = view["names"]
	if stage == "over":
		var w := 0 if int(view["scores"][0]) > int(view["scores"][1]) else 1
		var forfeit: int = int(view.get("forfeit_by", -1))
		if forfeit != -1:
			w = 1 - forfeit
		var res := UIStyle.label("%s WINS" % String(names[w]).to_upper(), 46, UIStyle.GOLD_HI, true, true)
		res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_box.add_child(res)
		TitleText.apply(res, TitleText.Tier.HERO, 46)
		overlay_box.add_child(_centred("Series won %d – %d" % [maxi(view["scores"][0], view["scores"][1]), mini(view["scores"][0], view["scores"][1])], 19, UIStyle.TEXT))
		if forfeit != -1:
			overlay_box.add_child(_centred("%s left and forfeited the series." % names[forfeit], 16, UIStyle.BAD))
		overlay_box.add_child(score_row(UIStyle.label(names[0], 20, UIStyle.TEXT, false, true), UIStyle.label(names[1], 20, UIStyle.TEXT, false, true),
			view["scores"], func(t: String) -> Label: return UIStyle.label(t, 40, UIStyle.GOLD, false, true), 18))
		for h in view.get("history", []):
			overlay_box.add_child(_centred("Game %d — %s won (turn %d, HP %d–%d)" % [h["game"], names[h["winner"]], h["turns"], h["hp"][0], h["hp"][1]], 15, UIStyle.MUTED))
		var b := UIStyle.primary_button("Back to main menu", 17)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): gs.back_to_menu.emit())
		overlay_box.add_child(b)
		return
	var line := game_result_line()
	if line != "" and stage != "decks":
		overlay_box.add_child(_centred(line, 17, UIStyle.TEXT))
	var title := ""
	var sub := ""
	var chips := []
	match stage:
		"decks":
			title = "Deck choice"
			sub = "The duel starts once both players have locked in a deck."
			var dp: Array = view.get("draft_progress", [])
			for p in 2:
				var ready: bool = bool(view["deck_ready"][p])
				var prog := ""
				var doing := "choosing"
				if not ready and dp.size() == 2 and int(dp[p].get("total", 0)) > 0:
					prog = " (%d / %d picks)" % [int(dp[p]["step"]), int(dp[p]["total"])]
					if int(dp[p]["step"]) >= int(dp[p]["total"]):
						doing = "confirming"   # J30: every card drafted, not yet confirmed
				chips.append({"text": "%s: %s" % [names[p], "deck ready" if ready else doing + prog], "done": ready})
		"rewards":
			title = "Choosing rewards"
			sub = "Each player picks new cards for their deck. You will see the next duel when it starts."
			var rd: Array = view.get("rewards_done", [false, false])
			for p in 2:
				chips.append({"text": "%s: %s" % [names[p], "done" if rd[p] else "choosing"], "done": bool(rd[p])})
		"first_player":
			var nx: Dictionary = view.get("next", {})
			var loser := int(view.get("last_loser", 0))
			title = "Game %d" % (int(view["game_no"]) + 1)
			if bool(nx.get("first_chosen", false)):
				var fp := int(nx.get("first_player", 0))
				sub = "%s will go first." % names[fp]
			else:
				sub = "%s lost the last game and is choosing who goes first." % names[loser]
			var rdy: Array = nx.get("ready", [false, false])
			for p in 2:
				chips.append({"text": "%s: %s" % [names[p], "ready" if rdy[p] else "not ready yet"], "done": bool(rdy[p])})
	var wp := WaitPlate.new(title, sub, chips)
	wp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wp.custom_minimum_size = Vector2(minf(460.0, overlay_box.custom_minimum_size.x), 0)
	overlay_box.add_child(wp)
	overlay_box.add_child(_centred("You are spectating. The players make every choice here.", 14, GameChat.SPECTATOR_COLOR))


## A centred, wrapping label for the stage modal.
func _centred(text: String, fs: int, col: Color) -> Label:
	var l := UIStyle.label(text, fs, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Game history rows on the series-over screen (#66): side padding and height (px).
const HISTORY_PAD_X := 14
const HISTORY_ROW_H := 36


func _render_over() -> void:
	var view := gs.view
	var w := 0 if view["scores"][0] > view["scores"][1] else 1
	var forfeit: int = view.get("forfeit_by", -1)
	if forfeit != -1:
		w = 1 - forfeit
	var won: bool = w == gs.me()
	var res := UIStyle.label("VICTORY" if won else "DEFEAT", 64, UIStyle.GOLD_HI if won else UIStyle.BAD, false, true)
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.name = "ResultTitle"
	overlay_box.add_child(res)
	TitleText.apply(res, TitleText.Tier.HERO if won else TitleText.Tier.HERO_DEFEAT, 64)   # D3 / #64
	var sub := UIStyle.label("%s wins the series" % view["names"][w], 20, UIStyle.TEXT, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(sub)
	if forfeit != -1:
		var ff := UIStyle.label("%s left and forfeited the series." % view["names"][forfeit], 16, UIStyle.BAD, true)
		ff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_box.add_child(ff)
	# Design review #65: the score is the headline number (44 px), the loser's at 60% opacity.
	var srow := score_row(UIStyle.label(view["names"][0], 20, UIStyle.TEXT, false, true), UIStyle.label(view["names"][1], 20, UIStyle.TEXT, false, true),
		view["scores"], func(t: String) -> Label: return UIStyle.label(t, SCORE_SIZE, UIStyle.GOLD, false, true), 18)
	srow.name = "ScoreRow"
	var nums := [srow.get_child(0).get_child(1), srow.get_child(2).get_child(0)]
	(nums[1 - w] as Control).modulate.a = LOSER_SCORE_ALPHA
	overlay_box.add_child(srow)
	overlay_box.add_child(GameUi.header("Game history"))
	for h in view["history"]:
		var hw: bool = h["winner"] == gs.me()
		# Design review #66: a win row has a gold edge, a loss an ember edge at 50%; 14 px sides, 36 px rows.
		var rowp := PanelContainer.new()
		var rsb := UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.9), Color(UIStyle.GOLD, 0.8) if hw else Color(UIStyle.BAD, 0.5), 1, 6)
		UIStyle.pad(rsb, "lg", "xs")
		rsb.content_margin_left = HISTORY_PAD_X
		rsb.content_margin_right = HISTORY_PAD_X
		if hw:
			UIStyle.lift_style(rsb, Color(UIStyle.GOLD, 0.18), 6, 0)
		rowp.add_theme_stylebox_override("panel", UiSurface.box(rsb, UiSurface.LEATHER, UIStyle.PANEL_GRAIN * 0.5))
		rowp.custom_minimum_size.y = HISTORY_ROW_H
		rowp.name = "HistoryRow"
		overlay_box.add_child(rowp)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		rowp.add_child(hb)
		hb.add_child(GameUi.pill("WIN" if hw else "LOSS", UIStyle.GOOD if hw else UIStyle.BAD))
		var t := UIStyle.label("Game %d — %s won" % [h["game"], view["names"][h["winner"]]], 16, UIStyle.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(t)
		hb.add_child(UIStyle.label("Turn %d · HP %d–%d" % [h["turns"], h["hp"][0], h["hp"][1]], 14, UIStyle.MUTED))
	# Design review #65: the final call to action is a hero CTA (52 px high, 240 px wide).
	var b := UIStyle.size_button(UIStyle.primary_button("Back to main menu", 18), "hero")
	b.name = "BackToMenu"
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, HERO_CTA_W)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): gs.back_to_menu.emit())
	overlay_box.add_child(b)
