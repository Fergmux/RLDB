class_name GameScreen
extends Control
## Match UI for one seat (design/ux/match-board.md). Renders the redacted series view from a
## SeatClient and sends commands; it never computes rules itself. All legality, costs,
## damage and statuses come from the authority's view. Effects (FxPlayer) are presentation
## only: the board is always rendered in its final state first.
##
## This node is the coordinator: it owns the view, the shared selection state and the
## layers, and delegates building, layout and rendering to the components in src/ui/game/.

signal back_to_menu
## Leave without the main menu's own confirmation (the in-game menu already warned).
signal leave_to_menu

const SIDEBAR_W := 360.0
const TOP_H := 44.0
const HAND_H := 190.0
const MAX_FX_ENTRIES := 25
const VERDICT_COLORS := {"good": Color("5fd068"), "bad": Color("e5534b"), "neutral": Color("b9a6e8")}

## Draw order of the screen's layers (z_index). Equal values fall back to child order.
const Z_LIFTED_CARD := 40
const Z_ARROW := 55
const Z_FX := 60
const Z_TRAY := 65
const Z_WAIT := 66
const Z_BANNER := 70
const Z_TOAST := 80
const Z_PILE_POPUP := 90
const Z_GAME_MENU := 95
const Z_HOVER := 100

var client: SeatClient
var view: Dictionary = {}
var mv: Dictionary = {}          # match view (may be the finished game between games)
var prev_mv: Dictionary = {}
var fx: FxPlayer
var fx_layer: Control
var banner_layer: Control
var hover_layer: Control
var arrow: ArrowLayer
## Hot-seat: the seat switch waits until this time (msec) so an animation that belongs to the
## current seat (end-of-turn discard) finishes on its own screen.
var fx_hold_until: int = 0
## Commands sent by this screen (dev/QA: proves hover and previews send nothing).
var debug_sent: int = 0

# Shared selection state (read and written by the components).
var selected_uid: int = -1       # pinned in the details panel
var multi: Array = []            # selected option indices for a multi-select prompt
var peek_uid: int = -1           # hovered card whose details are shown
var row_open: bool = false       # action row shown for the click-selected card (F02-01)
var acting_uid: int = -1         # card whose action opened the current choice (arrow source)

# Layout (set by _relayout).
var play_area: Rect2 = Rect2()
var sidebar_w: float = SIDEBAR_W   # effective sidebar width in screen units
var side_k: float = 1.0            # sidebar scale on wide windows

## Components (each builds its own nodes on this screen, in the order _ready calls them).
var board: GameBoardView
var hand: GameHandView
var hover: GameHoverController
var action_row: GameActionRow
var selection: GameSelection
var keyboard: GameKeyboard
var prompt: GamePromptBanner
var preview: GameCombatPreview
var targeting: GameTargeting
var sidebar: GameSidebar
var details: GameDetails
var game_log: GameLog
var menu: GameMenu
var overlays: GameSeriesOverlay

var _fx_seq: int = -1
var _fx_game: int = -99
var _last_stage: String = ""
var _laid_size: Vector2 = Vector2.ZERO
var _multi_pid: int = -1           # pending choice the current multi-pick belongs to
## A view whose display is held back while a Spell/Trap spotlight plays: the board and log keep
## showing the state before it until the card has left, then the effects apply.
var _held: Dictionary = {}
var _held_gen: int = 0
## Series whose game-1 coin flip has been shown (static: hot-seat seats share it).
static var _coin_shown: Dictionary = {}


func _init() -> void:
	board = GameBoardView.new(self)
	hand = GameHandView.new(self)
	hover = GameHoverController.new(self)
	action_row = GameActionRow.new(self)
	selection = GameSelection.new(self)
	keyboard = GameKeyboard.new(self)
	prompt = GamePromptBanner.new(self)
	preview = GameCombatPreview.new(self)
	targeting = GameTargeting.new(self)
	sidebar = GameSidebar.new(self)
	details = GameDetails.new(self)
	game_log = GameLog.new(self)
	menu = GameMenu.new(self)
	overlays = GameSeriesOverlay.new(self)


func _ready() -> void:
	UIStyle.load_settings()
	Sfx.load_settings()
	Sfx._free_voice()          # create the voice pool now so the first game sounds are not dropped
	theme = UIStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Child order is draw order among equal z_index values: keep it.
	board.build_table()
	board.build()
	hand.build()
	sidebar.build()
	menu.build_top_strip()
	prompt.build()
	hover_layer = _passive_layer()
	hover_layer.z_index = Z_HOVER
	arrow = ArrowLayer.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(arrow)
	fx_layer = _passive_layer()
	fx_layer.z_index = Z_FX
	overlays.build_pause()
	overlays.build_modals()
	menu.build_popups()
	prompt.build_notices()
	banner_layer = _passive_layer()
	fx = FxPlayer.new()
	fx.screen = self
	add_child(fx)
	resized.connect(_relayout)
	_relayout()


## Binds this screen to a seat. Safe to call before the node entered the tree: it waits for _ready.
func attach(c: SeatClient) -> void:
	if not is_node_ready():
		await ready
	if client != null and client.view_changed.is_connected(_on_view):
		client.view_changed.disconnect(_on_view)
		client.status_changed.disconnect(_on_status)
	client = c
	client.view_changed.connect(_on_view)
	client.status_changed.connect(_on_status)
	selected_uid = -1
	peek_uid = -1
	keyboard.kb_uid = -1
	row_open = false
	acting_uid = -1
	prompt.seen_toast_seq = -1
	preview.reset()
	action_row.clear()
	overlays.overlay_sig = 0
	prompt.prompt_sig = 0
	details.details_sig = ""
	sidebar.series_sig = 0
	multi = []
	_held = {}
	_held_gen += 1
	var same_game: bool = not c.last_view.is_empty() and int(c.last_view.get("game_no", -1)) == _fx_game
	if not same_game:
		_fx_seq = -1
		_fx_game = -99
		prev_mv = {}
		mv = {}
	fx.finish_all()
	hover.clear()
	hand.reset()
	game_log.reset()
	for pl in board.plates:
		(pl as PlayerPlate).reset_hp_max()
	if not c.last_view.is_empty():
		_on_view(c.last_view)


## A full-rect click-through layer added on top of the current children.
func _passive_layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _relayout() -> void:
	if size.x < 200.0 or size.y < 200.0:
		return
	_laid_size = size
	var w := size.x
	var h := size.y
	# Wide windows: the sidebar (and its text) grows a little instead of floating in empty space.
	side_k = clampf(w / 1600.0, 1.0, 1.2)
	sidebar_w = SIDEBAR_W * side_k
	play_area = Rect2(0, TOP_H, w - sidebar_w, h - TOP_H - HAND_H)
	board.layout(w, h)
	sidebar.layout(w, h)
	menu.layout(w)
	prompt.place_banner()
	prompt.place_tray()
	overlays.layout_pause(w, h)
	menu.layout_popups(w)
	hand.layout([], true)
	board.place_opp_hand()
	overlays.place_modals()


# ---------------------------------------------------------------- view handling

func _on_status(text: String) -> void:
	prompt.on_status(text)


func _on_view(v: Dictionary) -> void:
	if not _held.is_empty():
		_release_held()
	prev_mv = mv
	view = v
	mv = v.get("match", {})
	if v["stage"] != _last_stage:
		_last_stage = v["stage"]
	# A multi-pick belongs to one prompt: clear it whenever the pending choice changes (QA-F02-01).
	var pid: int = int(mv.get("pending", {}).get("id", -1)) if not mv.is_empty() else -1
	if pid != _multi_pid:
		multi = []
		_multi_pid = pid
	var events := _collect_fx()
	hand.draws_me = 0
	for e in events:
		if e["k"] == "draw" and int(e["p"]) == me():
			hand.draws_me += int(e["n"])
	if _laid_size != size:
		_relayout()
	if selected_uid != -1 and details.find_card(selected_uid).is_empty():
		selected_uid = -1
		row_open = false
	if acting_uid != -1 and mv.get("pending", {}).is_empty():
		acting_uid = -1
	var spots := events.filter(func(e): return e["k"] == "spotlight")
	if not spots.is_empty() and not prev_mv.is_empty():
		_hold_for_spotlight(spots, events.filter(func(e): return e["k"] != "spotlight"))
		return
	_render_all()
	prompt.show_log_toasts()
	_maybe_coin_flip()
	if not events.is_empty():
		fx.play(events, prev_mv)


## Shows the spotlight over the board as it was before the Spell/Trap (a Spell cast from your
## hand already leaves the hand), then applies the new state and its effects once it has gone.
func _hold_for_spotlight(spots: Array, rest: Array) -> void:
	var shown: Dictionary = prev_mv.duplicate(true)
	for e in spots:
		if String(e.get("how", "")) == "cast" and int(e.get("p", -1)) == me():
			var cards: Array = shown["players"][me()].get("hand", [])
			for i in cards.size():
				if int(cards[i].get("id", -1)) == int(e["id"]):
					cards.remove_at(i)
					break
	_held = {"mv": mv, "prev": prev_mv, "events": rest}
	_held_gen += 1
	var gen := _held_gen
	mv = shown
	_render_all()
	fx.play(spots, prev_mv)
	get_tree().create_timer(UIStyle.dur(FxPlayer.SPOT_HOLD) * spots.size()).timeout.connect(func():
		if gen == _held_gen and not _held.is_empty():
			_release_held())


## Skips running effects and any held spotlight at once, exactly like a click does (tests use it).
func skip_effects() -> void:
	fx.finish_all()
	if not _held.is_empty():
		_release_held()
	fx.finish_all()


## Applies a view held back for a spotlight (and plays its effects).
func _release_held() -> void:
	var h := _held
	_held = {}
	_held_gen += 1
	mv = h["mv"]
	prev_mv = h["prev"]
	_render_all()
	prompt.show_log_toasts()
	if not (h["events"] as Array).is_empty():
		fx.play(h["events"], h["prev"])


## Game 1 of a series starts with a coin flip naming who goes first (once per series).
func _maybe_coin_flip() -> void:
	if mv.is_empty() or view.get("stage", "") != "game" or int(view.get("game_no", 0)) != 1 or int(mv.get("turn", 0)) != 1:
		return
	var key := String(view.get("save_id", "local"))
	if _coin_shown.has(key):
		return
	_coin_shown[key] = true
	var first: int = int(mv["active"])
	var coin := CoinFlip.new()
	coin.position = play_area.position
	coin.size = play_area.size
	add_child(coin)
	coin.play(String(_pv(first)["name"]), String(_pv(1 - first)["name"]), first == me())


## New presentation events since the last view; empty (skip animations) on first load,
## game switch or a burst of many entries (reconnect).
func _collect_fx() -> Array:
	if mv.is_empty():
		return []
	var entries: Array = mv.get("log", [])
	var maxseq := 0
	var fresh := []
	for e in entries:
		maxseq = maxi(maxseq, int(e["seq"]))
		if int(e["seq"]) > _fx_seq:
			fresh.append(e)
	var game_no: int = view.get("game_no", 0)
	var skip := _fx_seq < 0 or game_no != _fx_game or fresh.size() > MAX_FX_ENTRIES
	_fx_seq = maxseq
	_fx_game = game_no
	if skip:
		return []
	var out := []
	for e in fresh:
		out.append_array(e.get("fx", []))
	return out


## Renders every part of the screen from the current view (order matters).
func _render_all() -> void:
	board.render()
	sidebar.render_turnbar()
	prompt.render()
	details.render()
	game_log.render()
	sidebar.render_series()
	overlays.render()
	overlays.render_pause()
	action_row.refresh()
	if details.pile_zone != "":
		if view.get("stage", "") != "game" or mv.is_empty():
			details.close_pile()
		else:
			details.render_pile_list()


## My seat index in the match.
func me() -> int:
	return view.get("you", 0)


## Player p's view in the current match.
func _pv(p: int) -> Dictionary:
	return mv["players"][p]


## The pending choice ({} when none).
func _pending() -> Dictionary:
	if mv.is_empty():
		return {}
	return mv.get("pending", {})


## Sends a command through the seat client (hides the toast).
func _send(cmd: Dictionary) -> void:
	debug_sent += 1
	prompt.hide_toast()
	if client != null:
		client.send(cmd)


## True while I cannot act on the board (spotlight held, no game, game over, a choice pending,
## resolving, or the network match paused).
func _locked() -> bool:
	if not _held.is_empty():
		return true   # a spotlight is showing; the board is not the current state yet
	if mv.is_empty() or view.get("stage", "") != "game" or mv["winner"] != -1:
		return true
	if not mv.get("pending", {}).is_empty() or mv.get("resolving", false):
		return true
	var net: Dictionary = view.get("net", {})
	return net.get("paused", false)


## True while a modal, popup, menu or pause covers the board (no hover).
func hover_blocked() -> bool:
	return overlays.overlay.visible or overlays.pile_popup.visible or menu.settings_popup.visible or menu.game_menu.visible \
		or overlays.pause_dim.visible or mv.is_empty()


## True while a series is being played on this screen (leaving it would forfeit).
func has_live_series() -> bool:
	return view.get("stage", "") not in ["", "over"]


# ---------------------------------------------------------------- input

## Clicks on the bare table (not on a card, button or panel) clear the selection.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _pending().is_empty() or not _pending().get("mine", false):
			selection.deselect()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		if keyboard.handle_key(ke):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		selection.cancel()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and is_visible_in_tree():
		var ke := event as InputEventKey
		if ke.keycode in GameKeyboard.GAME_KEYS and keyboard.handle_key(ke):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and keyboard.kb_uid != -1 and (event as InputEventMouseMotion).relative.length() > 3.0:
		keyboard.kb_uid = -1
		if action_row.stack != null:
			action_row.rebuild()
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]):
		if fx != null and fx.busy():
			fx.finish_all()
		if not _held.is_empty():
			_release_held()   # a click skips the spotlight and applies its effects at once


func _process(_d: float) -> void:
	if not is_visible_in_tree():
		return
	targeting.update_arrow()
	if not hover.forced:
		hover.update(get_global_mouse_position())
	preview.update()


# ---------------------------------------------------------------- FxPlayer host contract

## Slot item {zone_node, bg, holder, widget, ...} of player p's zone slot, or {}.
func fx_slot_item(p: int, zone: String, slot: int) -> Dictionary:
	return board.slot_item(p, zone, slot)


## Global rect of the card box in player p's zone slot.
func fx_slot_global_rect(p: int, zone: String, slot: int) -> Rect2:
	return board.slot_global_rect(p, zone, slot)


## Player p's plate.
func plate_of(p: int) -> PlayerPlate:
	return board.plate_of(p)


## Global point cards fly to/from for player p's hand.
func hand_anchor(p: int) -> Vector2:
	return board.hand_anchor(p)


## Centre of a player's unit block (direct-attack animations aim here).
func side_center(p: int) -> Vector2:
	return board.side_center(p)


## Where cards fly to/from for a player's pile (draw animations).
func pile_anchor(p: int, zone: String) -> Vector2:
	return board.pile_anchor(p, zone)


## Cards that left my hand in the last render, [{c: global centre, v: card view}] (discard fx).
func gone_hand_cards() -> Array:
	return hand.gone_cards()


## Global rect of the play area.
func board_global_rect() -> Rect2:
	return get_global_transform() * play_area


# ---------------------------------------------------------------- forwarders
# Members that tests, dev drivers and the main menu reach on the screen; they live in components.

var _area: Rect2:
	get:
		return play_area
var _slots: Dictionary:
	get:
		return board.slots
var _piles: Array:
	get:
		return board.piles
var _hand_items: Dictionary:
	get:
		return hand.items
var _hand_order: Array:
	get:
		return hand.order
var _hv: Dictionary:
	get:
		return hover.hv
var _stack: Control:
	get:
		return action_row.stack
var ctx_banner: PanelContainer:
	get:
		return prompt.ctx_banner
var banner_title: Label:
	get:
		return prompt.banner_title
var banner_btns: HBoxContainer:
	get:
		return prompt.banner_btns
var banner_flow: HFlowContainer:
	get:
		return prompt.banner_flow
var tray: PanelContainer:
	get:
		return prompt.tray
var tray_box: VBoxContainer:
	get:
		return prompt.tray_box
var wait_chip: PanelContainer:
	get:
		return prompt.wait_chip
var wait_label: Label:
	get:
		return prompt.wait_label
var toast: Label:
	get:
		return prompt.toast
var phase_btn: Button:
	get:
		return sidebar.phase_btn
var details_title: Label:
	get:
		return details.details_title
var details_scroll: ScrollContainer:
	get:
		return details.details_scroll
var details_view: CardDetailsPanel:
	get:
		return details.details_view
var pile_scroll: ScrollContainer:
	get:
		return details.pile_scroll
var pile_list: VBoxContainer:
	get:
		return details.pile_list
var log_label: RichTextLabel:
	get:
		return game_log.label
var pile_popup: PanelContainer:
	get:
		return overlays.pile_popup
var _overlay_sig: int:
	get:
		return overlays.overlay_sig
	set(v):
		overlays.overlay_sig = v
var _deck_open: Dictionary:
	get:
		return overlays.deck_open
var _preview_text: String:
	get:
		return preview.text
var _preview_verdict: String:
	get:
		return preview.verdict
var _preview_ws: Array:
	get:
		return preview.ws


## Click-selects a visible card (details pinned; action row for my own card).
func _select(uid: int) -> void:
	selection.select(uid)


## Picks option i of my pending choice.
func _pick_option(i: int) -> void:
	selection.pick_option(i)


## Confirms the current multi-selection.
func _confirm_multi() -> void:
	selection.confirm_multi()


## Left click on a card widget.
func _on_widget_pressed(w: CardWidget) -> void:
	selection.on_widget_pressed(w)


## Legal actions of a card.
func _actions_for_card(uid: int) -> Array:
	return action_row.actions_for_card(uid)


## Runs action `a` of card `uid` if it is still legal.
func _run_action(uid: int, a: Dictionary) -> void:
	action_row.run_action(uid, a)


## Tab / Shift+Tab keyboard cycling over my actionable cards.
func _kb_cycle(dir: int) -> void:
	keyboard.cycle(dir)


## Card whose details are shown.
func _details_uid() -> int:
	return details.details_uid()


## Opens a card by definition id (game-log link).
func _show_card_def(id: int) -> void:
	details.show_card_def(id)


## Lists one of my piles in the details panel.
func _show_pile(zone: String, sel_uid: int = -1) -> void:
	details.show_pile(zone, sel_uid)


## Returns the details panel from a pile list to card details.
func _close_pile() -> void:
	details.close_pile()


## Re-renders the series-stage modal (if its view changed).
func _render_overlay() -> void:
	overlays.render()


## Opens or closes the in-game menu.
func _toggle_game_menu() -> void:
	menu.toggle()


## Return to menu (quit = false) or Quit to desktop, forfeiting a live series after a warning.
func _confirm_forfeit(quit: bool) -> void:
	menu.confirm_forfeit(quit)


## Dev/test API: force the hover state on a hand card (index).
func debug_hover_hand(index: int) -> void:
	hover.debug_hover_hand(index)


## Dev/test API: force the hover state on a field slot.
func debug_hover_slot(p: int, zone: String, slot: int) -> void:
	hover.debug_hover_slot(p, zone, slot)


## Dev/test API: release a forced hover.
func debug_clear_hover() -> void:
	hover.debug_clear()


## Music and sound-effect volume sliders with mute boxes (game settings and main menu).
static func audio_controls(fs: int) -> Control:
	return GameMenu.audio_controls(fs)


## One-line outcome for a battle preview (also used by tests).
static func preview_text(pv: Dictionary, a_name: String, t_name: String) -> String:
	return GameCombatPreview.preview_text(pv, a_name, t_name)
