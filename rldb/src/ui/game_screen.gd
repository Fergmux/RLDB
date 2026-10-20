class_name GameScreen
extends Control
## Match UI for one seat (design/ux/match-board.md). Renders the redacted series view from a
## SeatClient and sends commands; it never computes rules itself. All legality, costs,
## damage and statuses come from the authority's view. Effects (FxPlayer) are presentation
## only: the board is always rendered in its final state first.
##
## This node is the coordinator: it owns the view, the shared selection state and the
## layers, and delegates building, layout and rendering to the components in src/ui/game/.

## Emitted to return to the main menu (the menu confirms a live series).
signal back_to_menu
## Leave without the main menu's own confirmation (the in-game menu already warned).
signal leave_to_menu

const SIDEBAR_W := 360.0
const TOP_H := 44.0
const HAND_H := 190.0
const MAX_FX_ENTRIES := 25
const VERDICT_COLORS := {"good": Color("5fd068"), "bad": Color("e5534b"), "neutral": Color("b9a6e8")}


## Seat client this screen renders.
var client: SeatClient
## Latest redacted series view.
var view: Dictionary = {}
## Match view (may be the finished game between games).
var mv: Dictionary = {}
## Match view before the latest update.
var prev_mv: Dictionary = {}
## Effect player.
var fx: FxPlayer
## Layer effects are drawn on.
var fx_layer: Control
## Layer of phase banners.
var banner_layer: Control
## Layer of the hovered card.
var hover_layer: Control
## Targeting arrow layer.
var arrow: ArrowLayer
## Red screen-edge pulse on the struck plate's side for a big hit (D4, HpVial.big_hit).
var hit_vignette: HpVial.HitVignette
## Hot-seat: the seat switch waits until this time (msec) so an animation that belongs to the
## current seat (end-of-turn discard) finishes on its own screen.
var fx_hold_until: int = 0
## Commands sent by this screen (dev/QA: proves hover and previews send nothing).
var debug_sent: int = 0

# Shared selection state (read and written by the components).
## Pinned in the details panel.
var selected_uid: int = -1
## Selected option indices for a multi-select prompt.
var multi: Array = []
## Hovered card whose details are shown.
var peek_uid: int = -1
## Action row shown for the click-selected card (F02-01).
var row_open: bool = false
## Card whose action opened the current choice (arrow source).
var acting_uid: int = -1

# Layout (set by _relayout).
## The play field rect (set by layout).
var play_area: Rect2 = Rect2()
## Effective sidebar width in screen units.
var sidebar_w: float = SIDEBAR_W
## Sidebar scale on wide windows.
var side_k: float = 1.0

## Components (each builds its own nodes on this screen, in the order _ready calls them).
var board: GameBoardView
## Hand component.
var hand: GameHandView
## Hover component.
var hover: GameHoverController
## Action row component.
var action_row: GameActionRow
## Selection component.
var selection: GameSelection
## Keyboard component.
var keyboard: GameKeyboard
## Prompt banner component.
var prompt: GamePromptBanner
## Combat preview component.
var preview: GameCombatPreview
## Targeting component.
var targeting: GameTargeting
## Sidebar component.
var sidebar: GameSidebar
## Details component.
var details: GameDetails
## Log component.
var game_log: GameLog
## In-game menu component.
var menu: GameMenu
## Series overlay component.
var overlays: GameSeriesOverlay
## Right-click card inspection and pile browser component (F03-01 / F03-02).
var inspect: GameInspect
## A1 in-game chat (online only).
var chat: GameChat
## A2 spectating: badges, the Spectators list, the live cursor.
var spectate: GameSpectate

var _fx_seq: int = -1
var _fx_game: int = -99
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
	inspect = GameInspect.new(self)
	chat = GameChat.new(self)
	spectate = GameSpectate.new(self)


func _ready() -> void:
	UIStyle.load_settings()
	Sfx.load_settings()
	Sfx.warm_up()          # create the voice pool now so the first game sounds are not dropped
	theme = UIStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Child order is draw order among equal z_index values: keep it.
	board.build_table()
	board.build()
	inspect.build()
	hand.build()
	sidebar.build()
	menu.build_top_strip()
	prompt.build()
	hover_layer = passive_layer()
	hover_layer.z_index = UiLayers.HOVER
	arrow = ArrowLayer.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(arrow)
	fx_layer = passive_layer()
	fx_layer.z_index = UiLayers.FX
	hit_vignette = HpVial.HitVignette.new()
	hit_vignette.z_index = UiLayers.FX
	add_child(hit_vignette)
	for pl in board.plates:
		var plate: PlayerPlate = pl
		plate.hp_bar.big_hit.connect(func(_amount: int) -> void:
			hit_vignette.pulse(plate.get_global_rect().get_center().x < get_global_rect().get_center().x))
	overlays.build_pause()
	overlays.build_modals()
	menu.build_popups()
	prompt.build_notices()
	banner_layer = passive_layer()
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
	chat.attach(c)
	spectate.attach(c)
	inspect.close_all()
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
## The nodes a camera move (FxPlayer.camera_shake) moves: the table and board, the hand, the arrows
## and the effects. Never the sidebar, the top strip, the input panel or the modals.
func camera_nodes() -> Array:
	var out := []
	for n in [board.table, board.deco, board.layer, hand.layer, arrow, hover_layer, fx_layer]:
		if n != null and is_instance_valid(n):
			out.append(n)
	return out


func passive_layer() -> Control:
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
	chat.layout(w)
	spectate.layout(w)
	hand.layout([], true)
	board.place_opp_hand()
	overlays.place_modals()


# ---------------------------------------------------------------- view handling

func _on_status(text: String) -> void:
	prompt.on_status(text)


func _on_view(v: Dictionary) -> void:
	# F06-02: battle music while a game is in progress, menu music between games.
	Music.set_mode("battle" if String(v.get("stage", "")) == "game" else "menu")
	if not _held.is_empty():
		_release_held()
	prev_mv = mv
	view = v
	mv = v.get("match", {})
	# A multi-pick belongs to one prompt: clear it whenever the pending choice changes (QA-F02-01).
	var pid: int = int(mv.get("pending", {}).get("id", -1)) if not mv.is_empty() else -1
	if pid != _multi_pid:
		multi = []
		_multi_pid = pid
	var events := _collect_fx()
	fx.expect_game_end(events)   # F03-13: the result modal waits for the victory / defeat presentation
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
	_claim_ap_sounds(events)
	render_all()
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
	render_all()
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
	_claim_ap_sounds(h["events"])
	render_all()
	prompt.show_log_toasts()
	if not (h["events"] as Array).is_empty():
		fx.play(h["events"], h["prev"])


## D6: the AP changes the effects announce ("ap" fx, FxPlayer plays ap_gain / ap_loss) are claimed on
## the plates before they render, so their gems stay silent for them: one sound per AP change.
func _claim_ap_sounds(events: Array) -> void:
	if mv.is_empty():
		return
	for e in events:
		if String(e.get("k", "")) == "ap" and int(e.get("p", -1)) in [0, 1]:
			plate_of(int(e["p"])).claim_ap_sound()


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
	# Owner feedback 2026-10-18: the opening hands are dealt after the coin flip, not under it.
	hand.layer.modulate.a = 0.0
	board.opp_hand_box.modulate.a = 0.0
	coin.finished.connect(_deal_after_coin)
	coin.tree_exiting.connect(_deal_after_coin)   # backstop: the coin removed early
	coin.play(String(pv(first)["name"]), String(pv(1 - first)["name"]), first == me() and not is_spectator(), first)


## Shows the hands once the coin flip is done: mine dealt in from the draw pile, the opponent's
## faded in. Runs once per coin (finished, or the coin leaving early).
func _deal_after_coin() -> void:
	if hand.layer.modulate.a >= 1.0:
		return
	hand.layer.modulate.a = 1.0
	hand.deal_all()
	create_tween().tween_property(board.opp_hand_box, "modulate:a", 1.0, UIStyle.dur(0.3))


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
		# F12: tag HP changes with their cause from the authoritative log line ("battle" / "direct"), so a
		# killing blow can be told apart from effect damage resolved in the same batch.
		var via := FxStrike.hp_cause(String(e.get("text", "")))
		for f in e.get("fx", []):
			if via != "" and String(f.get("k", "")) == "hp" and not f.has("via"):
				f = (f as Dictionary).duplicate()
				f["via"] = via
			out.append(f)
	return out


## Renders every part of the screen from the current view (order matters).
func render_all() -> void:
	board.render()
	sidebar.render_turnbar()
	prompt.render()
	details.render()
	game_log.render()
	sidebar.render_series()
	overlays.render()
	overlays.render_pause()
	action_row.refresh()
	spectate.render()
	if details.is_drafting():
		details.show_draft()
	elif details.pile_zone != "":
		if view.get("stage", "") != "game" or mv.is_empty():
			details.close_pile()
		else:
			details.render_pile_list()
	inspect.refresh()


## My seat index in the match.
func me() -> int:
	return view.get("you", 0)


## Player p's view in the current match.
func pv(p: int) -> Dictionary:
	return mv["players"][p]


## The pending choice ({} when none).
func pending() -> Dictionary:
	if mv.is_empty():
		return {}
	return mv.get("pending", {})


## Sends a command through the seat client (hides the toast).
func send(cmd: Dictionary) -> void:
	debug_sent += 1
	prompt.hide_toast()
	if client != null:
		client.send(cmd)


## True while I cannot act on the board (spotlight held, no game, game over, a choice pending,
## resolving, or the network match paused).
func locked() -> bool:
	if not _held.is_empty():
		return true   # a spotlight is showing; the board is not the current state yet
	if is_spectator():
		return true   # A2: a spectator only watches
	if mv.is_empty() or view.get("stage", "") != "game" or mv["winner"] != -1:
		return true
	if not mv.get("pending", {}).is_empty() or mv.get("resolving", false):
		return true
	var net: Dictionary = view.get("net", {})
	return net.get("paused", false)


## True while a modal, popup, menu or pause covers the board (no hover).
func hover_blocked() -> bool:
	return overlays.overlay.visible or overlays.pile_popup.visible or menu.settings_popup.visible or menu.game_menu.visible \
		or overlays.pause_dim.visible or mv.is_empty() or inspect.is_open() or details.method_picker_open() or over_side_popover()


## True for a hot-seat series (both players at this screen).
func is_hotseat() -> bool:
	return String(view.get("mode", "")) == "local"


## True in a networked (LAN / Steam) series.
func is_network() -> bool:
	return view.has("net")


## A2: true when this screen watches a networked series as a spectator.
func is_spectator() -> bool:
	return bool(view.get("spectator", false)) or bool(view.get("net", {}).get("spectator", false))


## A2: true while the mouse is over the chat box or the Spectators list (no board hover there).
func over_side_popover() -> bool:
	var m := get_local_mouse_position()
	for p in [chat.panel, spectate.panel]:
		if p != null and p.visible and Rect2(p.position, p.size).has_point(m):
			return true
	return false


## True while a series is being played on this screen (leaving it unsaved would forfeit).
func has_live_series() -> bool:
	return view.get("stage", "") not in ["", "over"]


# ---------------------------------------------------------------- input

## Clicks on the bare table (not on a card, button or panel) clear the selection and close the
## passive right-pane pile list / log card (F03-26); a pending choice of mine is never cancelled.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		details.dismiss_passive()
		if pending().is_empty() or not pending().get("mine", false):
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
	if event is InputEventKey and event.pressed and is_visible_in_tree() and chat.is_open():
		# A1: Esc closes the chat box first; while typing, no key is a game shortcut.
		if (event as InputEventKey).keycode == KEY_ESCAPE and not event.echo:
			chat.close_box()
			get_viewport().set_input_as_handled()
			return
		if chat.typing():
			return
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
	spectate.process()
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
