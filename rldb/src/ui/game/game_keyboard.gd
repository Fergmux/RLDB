class_name GameKeyboard
extends RefCounted
## Keyboard fallback for the match. 1-9 pick prompt options, Enter confirms a multi-select or
## ends the phase, Esc cancels, Tab / Shift+Tab walk your actionable cards (opening the card's
## action row) and the arrow keys + Enter choose an action.

## Game keys are handled before GUI focus navigation, so a focused button can neither swallow
## Tab/arrows nor double-handle Enter (the board has its own keyboard scheme).
const GAME_KEYS := [KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]

## The host screen this component works on.
var gs: GameScreen
## Keyboard-focused card (-1: none; the mouse takes over when it moves).
var kb_uid: int = -1
## Keyboard-focused action in its row.
var kb_idx: int = 0


func _init(screen: GameScreen) -> void:
	gs = screen


## Handles a key press; returns true when the key was used.
func handle_key(e: InputEventKey) -> bool:
	var k: int = e.keycode
	var overlays := gs.overlays
	if k == KEY_ESCAPE:
		if overlays.decks != null and overlays.decks.bot_stage() and overlays.overlay.visible and not gs.menu.settings_popup.visible and not gs.menu.game_menu.visible:
			overlays.decks.back_to_own()   # J24: Esc on "Choose the bot's deck" goes back to your own
			return true
		if not gs.selection.cancel() and not overlays.pause_dim.visible:
			gs.menu.toggle()   # nothing to close or cancel: Esc opens the game menu
		return true
	var view := gs.view
	var mv := gs.mv
	if overlays.pile_popup.visible or gs.menu.settings_popup.visible or overlays.pause_dim.visible or view.is_empty():
		return false
	var is_enter: bool = k == KEY_ENTER or k == KEY_KP_ENTER
	if view.get("stage", "") != "game":
		return false
	if mv.is_empty() or mv["winner"] != -1:
		return false
	var pd := gs.pending()
	if not pd.is_empty():
		if not pd["mine"]:
			return false
		if is_enter and pd["max"] > 1 and gs.multi.size() >= pd["min"]:
			gs.selection.confirm_multi()
			return true
		return false
	if gs.hover_blocked() or mv.get("resolving", false):
		return false
	if gs.sacrifice.active:
		return _sacrifice_key(k, e.shift_pressed, is_enter)
	if k == KEY_TAB:
		cycle(-1 if e.shift_pressed else 1)
		return true
	var row := gs.action_row
	if kb_uid != -1 and row.stack != null:
		var acts := row.actions_for_card(kb_uid)
		if k == KEY_UP or k == KEY_LEFT or k == KEY_DOWN or k == KEY_RIGHT:
			var step := -1 if (k == KEY_UP or k == KEY_LEFT) else 1
			kb_idx = clampi(kb_idx + step, 0, maxi(acts.size() - 1, 0))
			row.rebuild()
			return true
		if is_enter or k == KEY_SPACE:
			if kb_idx < acts.size() and acts[kb_idx]["ok"]:
				row.run_action(kb_uid, acts[kb_idx])
			return true
	if is_enter and mv["active"] == gs.me():
		for a in mv.get("actions", []):
			if a["t"] == "next_phase" and a["ok"]:
				gs.send({"t": "next_phase"})
				return true
	return false


## L5 sacrifice mode's keys: Tab / Shift+Tab and the arrows walk the sacrificable units, Enter or
## Space sacrifices the focused one (nothing without a focus: Enter never ends the phase from the
## mode). Esc is handled before (it ends the mode). Every other key is left alone.
func _sacrifice_key(k: int, shift: bool, is_enter: bool) -> bool:
	var sac := gs.sacrifice
	if k == KEY_TAB:
		sac.cycle(-1 if shift else 1)
		return true
	if k in [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		sac.cycle(-1 if (k == KEY_UP or k == KEY_LEFT) else 1)
		return true
	if is_enter or k == KEY_SPACE:
		if sac.kb_uid != -1:
			sac.try_sacrifice(sac.kb_uid)
		else:
			Sfx.play("deny")
		return true
	return false


## Cards of yours that currently have at least one legal action (hand first, then the field).
func _kb_cards() -> Array:
	var out := []
	if gs.locked():
		return out
	var hand := gs.hand
	for uid in hand.order:
		if _has_ok_action(uid):
			var it: Dictionary = hand.items[uid]
			out.append(GameHoverController.make_item("h:%d" % uid, it["widget"], it["holder"], uid, "hand", true))
	var slots := gs.board.slots
	for zone in GameBoardView.ZONE_SLOTS:
		for slot in GameBoardView.ZONE_SLOTS[zone]:
			var key := GameBoardView.key(1, zone, slot)
			var sl: Dictionary = slots[key]
			var wd: CardWidget = sl["widget"]
			if wd.view.is_empty() or wd.view.get("hidden", false):
				continue
			var uid2: int = wd.view.get("uid", -1)
			if uid2 != -1 and _has_ok_action(uid2):
				out.append(GameHoverController.make_item(key, wd, sl["holder"], uid2, Zones.KIND[zone], true))
	return out


func _has_ok_action(uid: int) -> bool:
	# The card's row actions (J11: a sacrifice alone does not make a card Tab-selectable).
	return not gs.action_row.actions_for_card(uid).is_empty()


## Tab / Shift+Tab: click-select the next/previous card of yours that can act, opening its
## action row (keyboard equivalent of a click, F02-01).
func cycle(dir: int) -> void:
	var list := _kb_cards()
	if list.is_empty():
		return
	var cur := -1
	for i in list.size():
		if list[i]["uid"] == gs.selected_uid:
			cur = i
	var nxt := 0
	if cur == -1:
		nxt = 0 if dir > 0 else list.size() - 1
	else:
		nxt = wrapi(cur + dir, 0, list.size())
	var uid: int = list[nxt]["uid"]
	gs.selection.select(uid)
	kb_uid = uid
	kb_idx = 0
	gs.action_row.rebuild()
