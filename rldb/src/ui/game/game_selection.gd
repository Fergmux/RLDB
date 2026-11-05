class_name GameSelection
extends RefCounted
## Clicks and my pending choice: maps cards / zones to prompt options, picks and confirms
## them, click-selects cards (F02-01) and cancels (Esc / right-click).

## Prompt kinds answered by picking cards/zones directly (board, hand or the pile tray) with
## the context banner (F02-07 / F02-10); others (responses, ordering, yes/no) use the banner list.
const PICK_KINDS := ["select", "attack_target", "slot"]
## Prompt zones that mean one of my unit zones.
const UNIT_ZONES := ["unit", "adjacent", "column", "orig", "beside"]

## The host screen this component works on.
var gs: GameScreen


func _init(screen: GameScreen) -> void:
	gs = screen


## Board zone a prompt "slot" option's zone refers to.
static func mapped_zone(oz: String) -> String:
	return "unit" if oz in UNIT_ZONES else oz


## True while one of my choices is answered by picking cards or zones directly (board, Hand or
## the pile tray) under the context banner, instead of from a list.
func board_targeting() -> bool:
	var pd := gs.pending()
	if pd.is_empty() or not pd["mine"] or not (String(pd["kind"]) in PICK_KINDS):
		return false
	for o in pd["options"]:
		if o.has("ref") or o.has("slot") or o.has("card"):
			return true
	return false


## Card options that are neither on the board nor in my Hand: shown in the pile tray (F02-10).
func tray_options(pd: Dictionary) -> Array:
	var items := gs.hand.items
	# F08: an exact-total material choice offers no 0-cost material and none costing more than the total.
	return pd.get("options", []).filter(func(o): return o.has("card") and not o.has("ref") and not items.has(int(o["card"].get("uid", -1))) \
		and GamePromptBanner.payable_option(pd, o))


## My pending option for player p's zone slot, or -1.
func option_for_ref(p: int, zone: String, slot: int) -> int:
	var pd := gs.pending()
	if pd.is_empty() or not pd["mine"]:
		return -1
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["p"] == p and o["ref"]["zone"] == zone and o["ref"]["slot"] == slot:
			return o["i"]
		if o.has("slot") and p == gs.me() and not o.has("ref"):
			if mapped_zone(o.get("zone", "")) == zone and o["slot"] == slot and pd["kind"] == "slot":
				return o["i"]
	return -1


## My pending option for a card by uid, or -1.
func option_for_uid(uid: int) -> int:
	var pd := gs.pending()
	if pd.is_empty() or not pd["mine"]:
		return -1
	for o in pd["options"]:
		if o.has("card") and o["card"].get("uid", -1) == uid:
			return o["i"]
	return -1


## 1-based pick order of a prompt option in an ordered multi-selection, else 0.
func order_no(opt: int) -> int:
	var pd := gs.pending()
	if opt == -1 or pd.is_empty() or int(pd.get("max", 1)) <= 1:
		return 0
	return gs.multi.find(opt) + 1


## Left click: answers my pending choice when the card/zone is one of its options; otherwise
## click-selects the card (F02-01) — details pinned, and for my own card while nothing is
## pending, its legal action buttons. Clicking the selected card again deselects it.
func on_widget_pressed(w: CardWidget) -> void:
	if gs.game_ending():
		return   # J9: the kill was made; no further action, selection or skip
	if gs.sacrifice.on_widget(w):
		return   # L5: in sacrifice mode a click sacrifices a glowing unit and does nothing else
	var opt := -1
	var slots := gs.board.slots
	for k in slots.keys():
		if slots[k]["widget"] == w or slots[k]["bg"] == w:
			var parts: PackedStringArray = (k as String).split(":")
			var pidx := gs.me() if int(parts[0]) == 1 else 1 - gs.me()
			opt = option_for_ref(pidx, parts[1], int(parts[2]))
			break
	if opt == -1 and not w.view.is_empty():
		opt = option_for_uid(w.view.get("uid", -2))
	if opt != -1:
		pick_option(opt)
		return
	if w.view.is_empty() or w.view.get("hidden", false) or not w.view.has("uid"):
		if not w.view.is_empty() and w.view.get("hidden", false):
			deselect()          # face-down/hidden cards are never selectable or inspectable
		return
	var uid: int = w.view["uid"]
	if uid == gs.selected_uid and gs.row_open:
		deselect()
		Sfx.play("cancel")
		return
	select(uid)


## Right click on a card opens the read-only inspection (F03-01); it never selects, targets,
## plays or cancels. A hidden/face-down card does nothing; an empty zone is empty space and
## cancels like Esc.
func on_widget_right(w: CardWidget) -> void:
	if gs.game_ending():
		return
	if gs.inspect.inspect_widget(w):
		return
	if w.view.get("hidden", false):
		return
	cancel()


## Click-selects a visible card: details pinned; the action row opens for my own card.
func select(uid: int) -> void:
	var details := gs.details
	# Selecting a card on the field or in the hand replaces the pile list / log card with its details.
	details.log_card = {}
	if details.pile_zone != "":
		details.close_pile()
	var prev := gs.selected_uid
	gs.selected_uid = uid
	gs.row_open = true
	gs.keyboard.kb_uid = -1
	Sfx.play("select")
	_restyle_selection(prev)
	gs.board.render()
	details.render()
	gs.action_row.rebuild()


## L21 (owner feedback 2026-11-05): a click on one of my piles opens (or closes) its list in the
## details panel. Only one thing is selected at a time, so a click-selected card on the field or in
## the Hand is deselected first (its ring, lift and action row go); the pile then shows as selected.
func open_pile(zone: String) -> void:
	if gs.game_ending():
		return
	deselect()
	gs.details.show_pile(zone)


## Clears the click-selection (and its action row).
func deselect() -> void:
	if gs.selected_uid == -1 and not gs.row_open:
		return
	var prev := gs.selected_uid
	gs.selected_uid = -1
	gs.row_open = false
	_restyle_selection(prev)
	gs.board.render()
	gs.details.render()
	gs.action_row.clear()


## Selected hand cards stay lifted while their action row is open; the previous one drops.
func _restyle_selection(prev: int) -> void:
	var hover := gs.hover
	if prev != -1 and prev != gs.selected_uid:
		var pit := item_for_uid(prev)
		if not pit.is_empty() and not (not hover.hv.is_empty() and hover.hv.get("uid", -9) == prev):
			hover.unlift(pit)
	var it := item_for_uid(gs.selected_uid)
	if not it.is_empty() and it["own"] and it["kind"] == "hand":
		hover.lift(it)


## Hover-style item {key, w, holder, uid, kind, own} for a visible card by uid, or {}.
func item_for_uid(uid: int) -> Dictionary:
	if uid == -1:
		return {}
	var items := gs.hand.items
	if items.has(uid):
		var hi: Dictionary = items[uid]
		return GameHoverController.make_item("h:%d" % uid, hi["widget"], hi["holder"], uid, "hand", true)
	var slots := gs.board.slots
	for k in slots.keys():
		var sl: Dictionary = slots[k]
		var wd: CardWidget = sl["widget"]
		if wd.visible and not wd.view.is_empty() and not wd.view.get("hidden", false) and wd.view.get("uid", -9) == uid:
			return GameHoverController.make_item(k, wd, sl["holder"], uid, Zones.KIND[sl["zone"]], (k as String).begins_with("1:"))
	return {}


## L7 (owner feedback 2026-11-05): the choice I last answered, {id: its pending id, view: the view
## shown when the answer was sent}; {} when none is outstanding.
var _answered: Dictionary = {}


## L7: true while the choice shown is one I have already answered: its reply has not arrived yet
## (online), or a Spell/Trap spotlight still holds the board as it was before the answer. The
## targeting arrow, the combat preview and further picks stay off meanwhile. A reply that still
## shows the same choice (the answer was refused) ends it, so the choice can be answered again.
func answered() -> bool:
	if _answered.is_empty():
		return false
	var pd := gs.pending()
	if pd.is_empty() or not pd.get("mine", false) or int(pd.get("id", -1)) != int(_answered["id"]):
		_answered = {}
		return false
	if is_same(gs.view, _answered["view"]):
		return true            # no reply yet
	# A newer view arrived: only a held spotlight (the board still shows the old state) keeps it.
	if not is_same(gs.mv, gs.view.get("match")):
		return true
	_answered = {}
	return false


## L7: marks my pending choice `pd` answered and hides the targeting arrow at once, before the
## answer is sent (a local host replies, and its effects start, inside the send).
func _answering(pd: Dictionary) -> void:
	_answered = {"id": int(pd.get("id", -1)), "view": gs.view}
	gs.targeting.hide_arrow()


## Picks option i of my choice: toggles it in a multi-selection, else answers at once.
func pick_option(i: int) -> void:
	var pd := gs.pending()
	if pd.is_empty() or not pd.get("mine", false) or answered():
		return                 # L7: already answered (a double click while the reply is on its way)
	if pd["max"] > 1:
		# F08: never silently overpay an exact total; an unofferable option cannot be picked either.
		if not (i in gs.multi) and bool(pd.get("total_exact", false)):
			var o: Dictionary = {}
			for oo in pd.get("options", []):
				if int(oo["i"]) == i:
					o = oo
			if o.is_empty() or not GamePromptBanner.payable_option(pd, o) or GamePromptBanner.would_overpay(pd, gs.multi, i):
				Sfx.play("deny")
				# G09: over the material that was refused.
				gs.prompt.show_toast("Cannot overpay", UIStyle.BAD, 2.0, {"uid": int(o.get("card", {}).get("uid", -1))} if not o.is_empty() else {})
				return
		if i in gs.multi:
			gs.multi.erase(i)
			Sfx.play("cancel")
		else:
			gs.multi.append(i)
			Sfx.play("select")
		gs.render_all()
		return
	# L7: a card or zone picked on the board locks in (target_lock); a banner answer confirms.
	var on_board := board_targeting() and _is_board_option(pd, i)
	_answering(pd)
	Sfx.play(GameSelection.pick_sound(pd, on_board))
	gs.send({"t": "choose", "id": pd["id"], "indices": [i]})


## L1: the sound of answering choice `pd` with one option: a zone to place a card in sets a token on
## the board (zone_pick), any other board pick locks in (target_lock), a banner answer confirms.
static func pick_sound(pd: Dictionary, on_board: bool) -> String:
	if not on_board:
		return "confirm"
	return "zone_pick" if String(pd.get("kind", "")) == "slot" else "target_lock"


## True when option i of choice `pd` is a card or zone (picked on the board, in the Hand or the tray).
static func _is_board_option(pd: Dictionary, i: int) -> bool:
	for o in pd.get("options", []):
		if int(o["i"]) == i:
			return o.has("ref") or o.has("slot") or o.has("card")
	return false


## Sends the multi-selection once it has at least the minimum number of picks.
func confirm_multi() -> void:
	var pd := gs.pending()
	if pd.is_empty() or answered() or MatchView.multi_pick_error(pd, gs.multi) != "":   # F03-04 exact totals
		return
	_answering(pd)             # L7: the arrow goes with the final pick
	Sfx.play("confirm")
	var picks := gs.multi.duplicate()
	gs.multi = []
	gs.send({"t": "choose", "id": pd["id"], "indices": picks})


## Esc / right-click: close popups, cancel a cancellable prompt, otherwise unpin and clear the
## hover. Returns true when it closed or cancelled something.
func cancel() -> bool:
	var menu := gs.menu
	var details := gs.details
	# F22: closing a screen-level panel (inspector, dialog, menu, pile, settings) is a "back".
	if gs.inspect.close_top():
		return _went_back()
	if details.close_method_picker():   # F04 Fusion-method picker
		return _went_back()
	if menu.close_dialog():
		return _went_back()
	# L13: Esc closes the in-game menu like a click off it (close motion and panel_close, not
	# "back"). A menu already closing lets the key through (a second Esc reopens it).
	if menu.close_menu():
		return true
	if gs.overlays.pile_popup.visible:
		gs.overlays.pile_popup.visible = false
		return _went_back()
	if details.pile_zone != "" and gs.pending().is_empty():
		details.close_pile()
		return _went_back()
	if menu.settings_popup.visible:
		menu.settings_popup.visible = false
		return _went_back()
	if gs.sacrifice.active:
		gs.sacrifice.stop()    # L5: Esc / right-click ends sacrifice mode (sacrifice_mode_off)
		gs.hover.clear()
		return true
	var did := false
	var pd := gs.pending()
	if not pd.is_empty() and pd["mine"] and pd["cancellable"] and not answered():
		gs.multi = []
		_answering(pd)         # L7: the arrow goes at once
		Sfx.play("cancel")
		gs.send({"t": "cancel", "id": pd["id"]})
		did = true
	elif gs.selected_uid != -1 or gs.row_open:
		deselect()
		did = true
	gs.hover.clear()
	return did


## The back sound of a closed panel (F22); always true.
func _went_back() -> bool:
	Sfx.play("back")
	return true
