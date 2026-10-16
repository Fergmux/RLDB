class_name GameSelection
extends RefCounted
## Clicks and my pending choice: maps cards / zones to prompt options, picks and confirms
## them, click-selects cards (F02-01) and cancels (Esc / right-click).

## Prompt kinds answered by picking cards/zones directly (board, hand or the pile tray) with
## the context banner (F02-07 / F02-10); others (responses, ordering, yes/no) use the banner list.
const PICK_KINDS := ["select", "attack_target", "slot"]
## Prompt zones that mean one of my unit zones.
const UNIT_ZONES := ["unit", "adjacent", "column", "orig"]

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
	return pd.get("options", []).filter(func(o): return o.has("card") and not o.has("ref") and not items.has(int(o["card"].get("uid", -1))))


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
	gs.fx.finish_all()
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
	gs.fx.finish_all()
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
	gs.peek_uid = -1
	gs.row_open = true
	gs.keyboard.kb_uid = -1
	Sfx.play("select")
	_restyle_selection(prev)
	gs.board.render()
	details.render()
	gs.action_row.rebuild()


## Clears the click-selection (and its action row).
func deselect() -> void:
	if gs.selected_uid == -1 and not gs.row_open:
		return
	var prev := gs.selected_uid
	gs.selected_uid = -1
	gs.row_open = false
	gs.peek_uid = -1
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


## Picks option i of my choice: toggles it in a multi-selection, else answers at once.
func pick_option(i: int) -> void:
	var pd := gs.pending()
	if pd["max"] > 1:
		if i in gs.multi:
			gs.multi.erase(i)
			Sfx.play("cancel")
		else:
			gs.multi.append(i)
			Sfx.play("select")
		gs.render_all()
		return
	Sfx.play("confirm")
	gs.send({"t": "choose", "id": pd["id"], "indices": [i]})


## Sends the multi-selection once it has at least the minimum number of picks.
func confirm_multi() -> void:
	var pd := gs.pending()
	if pd.is_empty() or gs.multi.size() < int(pd["min"]):
		return
	Sfx.play("confirm")
	var picks := gs.multi.duplicate()
	gs.multi = []
	gs.send({"t": "choose", "id": pd["id"], "indices": picks})


## Esc / right-click: close popups, cancel a cancellable prompt, otherwise unpin and clear the
## hover. Returns true when it closed or cancelled something.
func cancel() -> bool:
	var menu := gs.menu
	var details := gs.details
	if gs.inspect.close_top():
		return true
	if menu.close_dialog():
		return true
	if menu.game_menu.visible:
		menu.game_menu.visible = false
		return true
	if gs.overlays.pile_popup.visible:
		gs.overlays.pile_popup.visible = false
		return true
	if details.pile_zone != "" and gs.pending().is_empty():
		details.close_pile()
		return true
	if menu.settings_popup.visible:
		menu.settings_popup.visible = false
		return true
	var did := false
	var pd := gs.pending()
	if not pd.is_empty() and pd["mine"] and pd["cancellable"]:
		gs.multi = []
		Sfx.play("cancel")
		gs.send({"t": "cancel", "id": pd["id"]})
		did = true
	elif gs.selected_uid != -1 or gs.row_open:
		deselect()
		did = true
	gs.hover.clear()
	return did
