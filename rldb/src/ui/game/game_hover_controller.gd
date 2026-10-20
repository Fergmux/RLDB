class_name GameHoverController
extends RefCounted
## Hover is inspection only (F02-01): the card under the pointer lifts (and shows its tooltip);
## it never shows action buttons and never sends anything. J4 (owner, 22 Oct): it no longer
## shows the card in the details panel, which follows clicks only. Over the selected card's
## action row, the tray or the banner nothing else hovers.

## Owner feedback 2026-10-18: a hovered hand card grows enough to read its whole text (hand cards
## carry no tooltip). 1.75 x 120x180 = 210x315.
const HAND_SCALE := 1.75
## Rise of a hovered hand card: the growth above its centre plus the old 25 px lift, so its bottom
## edge stays where it was and the card grows upwards.
const HAND_LIFT := -92.0
const FIELD_SCALE := 1.08
## Seconds the pointer may leave a hovered card before it drops.
const CLOSE_DELAY := 0.12

## The host screen this component works on.
var gs: GameScreen
## Hovered item {key, w, holder, uid, kind, own}, or {}.
var hv: Dictionary = {}
## Set by the debug_* hovers: the pointer does not move the hover.
var forced: bool = false
var _close_at: float = -1.0


func _init(screen: GameScreen) -> void:
	gs = screen


## The hover/selection item dictionary {key, w, holder, uid, kind, own} (one shape everywhere).
static func make_item(key: String, w: CardWidget, holder: Control, uid: int, kind: String, own: bool) -> Dictionary:
	return {"key": key, "w": w, "holder": holder, "uid": uid, "kind": kind, "own": own}


## F06: true while my pending choice is a zone to summon / place a card in. Field cards then do
## not hover (no enlargement, lift or peek) so the legal zones stay readable; the zone highlights
## and clicks are unaffected. Read from the current state every frame, so ordinary hover returns
## by itself when the choice is made, cancelled or replaced (a new prompt, the game ending).
func zone_choice() -> bool:
	var pd := gs.pending()
	return not pd.is_empty() and bool(pd.get("mine", false)) and String(pd.get("kind", "")) == "slot"


## D2: uid of the hand card being summoned / set while its zone is chosen (-1: none). That card stays at
## its normal size for the whole choice so its hover lift never covers the zones being picked.
func placing_hand_uid() -> int:
	if not zone_choice():
		return -1
	var pd := gs.pending()
	var uid := int(pd.get("placing_uid", gs.acting_uid))
	return uid if gs.hand.items.has(uid) else -1


## D2: drops the lift of hand card `uid` at once (it was just chosen to be summoned or set).
func release_hand(uid: int) -> void:
	if not hv.is_empty() and int(hv.get("uid", -9)) == uid:
		clear()
	elif gs.hand.items.has(uid):
		var it: Dictionary = gs.hand.items[uid]
		unlift(make_item("h:%d" % uid, it["widget"], it["holder"], uid, "hand", true))


## Visible card under global point m (hand cards topmost first), skipping `exclude_key`.
## `field`: false leaves the board's cards out (F06 zone choice).
func items_under(m: Vector2, exclude_key: String, field: bool = true) -> Dictionary:
	var hand := gs.hand
	var placing := placing_hand_uid()
	# Hand cards: topmost (last) first.
	for i in range(hand.order.size() - 1, -1, -1):
		var uid: int = hand.order[i]
		if uid == placing:
			continue
		var it: Dictionary = hand.items[uid]
		var h: Control = it["holder"]
		if "h:%d" % uid != exclude_key and h.get_global_rect().has_point(m):
			return make_item("h:%d" % uid, it["widget"], h, uid, "hand", true)
	if not field:
		return {}
	var slots := gs.board.slots
	for k in slots.keys():
		var sl: Dictionary = slots[k]
		var w: CardWidget = sl["widget"]
		if k == exclude_key or not w.visible or w.view.is_empty() or w.view.get("hidden", false):
			continue
		# The card box is the displayed card (2:3, or 3:2 when turned), not the whole zone.
		var h2: Control = sl["holder"]
		if h2.get_global_rect().has_point(m):
			return make_item(k, w, h2, int(w.view.get("uid", -1)), Zones.KIND[sl["zone"]], (k as String).begins_with("1:"))
	return {}


## Follows the pointer at global point m (called every frame unless forced).
func update(m: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if gs.hover_blocked():
		if not hv.is_empty():
			clear()
		return
	var placing := placing_hand_uid()
	if placing != -1 and not hv.is_empty() and int(hv.get("uid", -9)) == placing:
		clear()          # D2: the card being summoned shrinks back at once, even under a forced hover
		return
	var prompt := gs.prompt
	var on_row := gs.action_row.stack_rect().grow(3.0).has_point(m) or (prompt.tray.visible and prompt.tray.get_global_rect().has_point(m)) \
		or (prompt.ctx_banner.visible and prompt.ctx_banner.get_global_rect().has_point(m))
	var field := not zone_choice()
	if not hv.is_empty():
		if not is_instance_valid(hv["w"]) or not (hv["w"] as Node).is_inside_tree():
			clear()
			return
		if not field and hv["kind"] != "hand":
			clear()          # F06: a field card hovered when the zone choice opened drops at once
			return
		var tr := target_rect(hv)
		if tr.has_point(m) or (on_row and hv["uid"] == gs.selected_uid):
			_close_at = -1.0
		else:
			var cand := {} if on_row else items_under(m, hv["key"], field)
			if not cand.is_empty():
				set_hover(cand)
			else:
				var region := tr.grow(10.0).merge((hv["holder"] as Control).get_global_rect())
				if region.has_point(m) and not on_row:
					_close_at = -1.0
				elif _close_at < 0.0:
					_close_at = now + CLOSE_DELAY
				elif now >= _close_at:
					clear()
	elif not on_row:
		var cand2 := items_under(m, "", field)
		if not cand2.is_empty():
			set_hover(cand2)


## [scale, lift offset] of a hovered card of this kind (smaller with reduced motion).
static func lift_params(kind: String) -> Array:
	var hand := kind == "hand"
	var sc := HAND_SCALE if hand else FIELD_SCALE
	var lift := Vector2(0, HAND_LIFT) if hand else Vector2.ZERO
	# Reduced motion keeps the hand card's readable size (it changes at once, without the bounce).
	if UIStyle.reduce_motion and not hand:
		sc = minf(sc, 1.05)
	return [sc, lift]


## Global rect a lifted item occupies (its holder scaled and offset by lift_params).
func target_rect(it: Dictionary) -> Rect2:
	var hr: Rect2 = (it["holder"] as Control).get_global_rect()
	var lp := lift_params(it["kind"])
	var c := hr.get_center() + (lp[1] as Vector2)
	return Rect2(c - hr.size * float(lp[0]) / 2.0, hr.size * float(lp[0]))


## A selected hand card stays lifted while its action row is open.
func _keeps_lift(it: Dictionary) -> bool:
	return gs.row_open and it.get("uid", -9) == gs.selected_uid and it.get("kind", "") == "hand"


## Raises and scales an item above its neighbours.
func lift(it: Dictionary) -> void:
	var w: CardWidget = it["w"]
	var holder: Control = it["holder"]
	holder.z_index = UiLayers.LIFTED_CARD
	if it["kind"] == "hand":
		gs.hand.layer.move_child(holder, -1)
	var lp := lift_params(it["kind"])
	_kill_tween(w)
	var tw := w.create_tween()
	w.set_meta("hv_tw", tw)
	tw.set_parallel(true)
	var d := UIStyle.dur(0.12 if it["kind"] == "hand" else 0.1)
	if UIStyle.reduce_motion:
		d = 0.05
	# Real size change, not `scale` (F04-05); the face keeps its resting layout, drawn scaled with crisp text (F05-03).
	tw.tween_property(w, "lift_offset", lp[1], d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "lift_k", float(lp[0]), d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if it["kind"] == "hand":
		tw.tween_property(holder, "rotation", 0.0, d)


## Makes `it` the hovered item: lifts it (the details panel keeps the clicked card, J4).
func set_hover(it: Dictionary) -> void:
	if not hv.is_empty():
		unlift(hv)
	hv = it
	_close_at = -1.0
	(it["w"] as CardWidget).hovered = true
	lift(it)
	# #32: a hand card lifting makes the soft paper-slide cue (rate-limited with every hover cue).
	if it["kind"] == "hand" and it.get("own", true):
		Sfx.hover_card()
	var stack := gs.action_row.stack
	if stack != null:
		gs.hover_layer.move_child(stack, -1)


static func _kill_tween(w: CardWidget) -> void:
	if w.has_meta("hv_tw"):
		var t: Tween = w.get_meta("hv_tw")
		if t != null and t.is_valid():
			t.kill()


## Drops a lifted item back to rest (unless it is the selected hand card with its row open).
func unlift(it: Dictionary) -> void:
	var w: CardWidget = it["w"]
	if not is_instance_valid(w):
		return
	w.hovered = false
	if _keeps_lift(it):
		return
	var holder: Control = it["holder"]
	_kill_tween(w)
	var tw := w.create_tween()
	w.set_meta("hv_tw", tw)
	tw.set_parallel(true)
	var d := UIStyle.dur(0.09)
	tw.tween_property(w, "lift_offset", Vector2.ZERO, d)
	tw.tween_property(w, "lift_k", 1.0, d)
	if it["kind"] == "hand" and holder.has_meta("rest_rot"):
		tw.tween_property(holder, "rotation", float(holder.get_meta("rest_rot")), d)
	tw.chain().tween_callback(func():
		if is_instance_valid(holder):
			holder.z_index = 0)
	if it["kind"] == "hand":
		# The hand order can still list cards removed in this same render; skip them.
		var hand := gs.hand
		var idx := 0
		for huid in hand.order:
			if hand.items.has(huid):
				hand.layer.move_child(hand.items[huid]["holder"], idx)
				idx += 1


## Ends any hover.
func clear() -> void:
	if not hv.is_empty():
		unlift(hv)
	hv = {}
	forced = false
	_close_at = -1.0


## Dev/test API: force the hover state on a hand card (index).
func debug_hover_hand(index: int) -> void:
	var hand := gs.hand
	if index < 0 or index >= hand.order.size():
		return
	var uid: int = hand.order[index]
	var it: Dictionary = hand.items[uid]
	forced = false
	set_hover(make_item("h:%d" % uid, it["widget"], it["holder"], uid, "hand", true))
	forced = true


## Dev/test API: force the hover state on player p's field slot.
func debug_hover_slot(p: int, zone: String, slot: int) -> void:
	var board := gs.board
	var it: Dictionary = board.slot_item(p, zone, slot)
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	forced = false
	set_hover(make_item(GameBoardView.key(board.side_of(p), zone, slot), w, it["holder"], int(w.view.get("uid", -1)), Zones.KIND[zone], p == gs.me()))
	forced = true


## Dev/test API: release a forced hover.
func debug_clear() -> void:
	forced = false
	clear()
