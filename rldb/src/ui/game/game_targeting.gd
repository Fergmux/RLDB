class_name GameTargeting
extends RefCounted
## Targeting arrow and the pending option under the pointer: from the acting card to the
## hovered legal target while I pick, or the enemy attack arrow while I decide a Trap
## response. Read-only: it never sends anything.

const HOSTILE_COLOR := Color("ff6b5e")

## The host screen this component works on.
var gs: GameScreen
## Banner option button under the mouse (-1: none).
var hover_opt: int = -1


func _init(screen: GameScreen) -> void:
	gs = screen


## Updates the arrow layer (called every frame).
func update_arrow() -> void:
	var arrow := gs.arrow
	var pv := gs.preview
	var on := false
	var hostile := false
	var overlay_up := gs.overlays.overlay.visible
	if arrow != null and not gs.mv.is_empty() and not overlay_up and gs.selection.board_targeting():
		var src := _source_rect()
		var dst := _hovered_target_rect()
		if src.size != Vector2.ZERO and dst.size != Vector2.ZERO:
			var inv := arrow.get_global_transform().affine_inverse()
			arrow.a = inv * src.get_center()
			arrow.b = inv * dst.get_center()
			on = true
	elif arrow != null and not overlay_up:
		# Deciding a Trap response to an attack: the enemy's attack arrow, attacker -> its target.
		var cause: Dictionary = gs.pending().get("cause", {}) if gs.pending().get("mine", false) else {}
		var at: Dictionary = cause.get("attacker", {})
		if not at.is_empty():
			var src2 := gs.fx_slot_global_rect(int(at["p"]), "unit", int(at["slot"]))
			var tg: Dictionary = cause.get("target", {})
			var dst2: Vector2 = gs.fx_slot_global_rect(int(tg["p"]), "unit", int(tg["slot"])).get_center() if not tg.is_empty() else gs.side_center(int(cause.get("direct_p", gs.me())))
			if src2.size != Vector2.ZERO:
				var inv2 := arrow.get_global_transform().affine_inverse()
				arrow.a = inv2 * src2.get_center()
				arrow.b = inv2 * dst2
				on = true
				hostile = true
	var want_col: Color = GameScreen.VERDICT_COLORS.get(pv.verdict, UIStyle.TARGET) if pv.text != "" else UIStyle.TARGET
	if hostile:
		want_col = HOSTILE_COLOR
	var want_v := pv.verdict if pv.text != "" else ""
	if on or arrow.on or arrow.col != want_col or arrow.verdict != want_v:
		arrow.on = on
		arrow.col = want_col
		arrow.verdict = want_v
		arrow.queue_redraw()


func _source_rect() -> Rect2:
	# F03-18: an effect's arrow starts at the card whose effect asks (its board zone, from the
	# pending choice), never at an unrelated selected or attacking unit.
	var pd := gs.pending()
	var at: Dictionary = pd.get("source", {})
	if not at.is_empty():
		return gs.fx_slot_global_rect(int(at["p"]), String(at["zone"]), int(at["slot"]))
	var uid := source_uid()
	if uid == -1:
		return Rect2()
	var slots := gs.board.slots
	for k in slots.keys():
		if (k as String).begins_with("1:"):
			var sl: Dictionary = slots[k]
			if (sl["widget"] as CardWidget).view.get("uid", -9) == uid:
				return (sl["holder"] as Control).get_global_rect()
	var items := gs.hand.items
	if items.has(uid):
		return (items[uid]["holder"] as Control).get_global_rect()
	return Rect2()


## The card my current choice belongs to: the card whose action opened it, else the unit the
## prompt names ("... for X"), else my selected card; -1 when unknown.
func source_uid() -> int:
	var pd0 := gs.pending()
	if pd0.has("source_uid"):
		return int(pd0["source_uid"])      # the effect's own card (F03-18)
	var acting := gs.acting_uid
	if acting != -1 and (gs.hand.items.has(acting) or not gs.selection.item_for_uid(acting).is_empty()):
		return acting
	var pd := gs.pending()
	var re := RegEx.new()
	re.compile("for (.+?)[.?:]?$")
	var m := re.search(String(pd.get("prompt", "")))
	if m != null:
		var nm := m.get_string(1)
		for c in gs.pv(gs.me())["units"]:
			if c != null and not c.get("hidden", false) and c.get("name", "") == nm:
				return c["uid"]
	if gs.selected_uid != -1 and _is_mine_card(gs.selected_uid):
		return gs.selected_uid
	return -1


func _is_mine_card(uid: int) -> bool:
	var pv := gs.pv(gs.me())
	for z in ["units", "backrow", "powers", "hand"]:
		for c in pv.get(z, []):
			if c != null and c.get("uid", -9) == uid:
				return true
	return false


func _hovered_target_rect() -> Rect2:
	var o := option_under_pointer()
	return _option_rect(o) if o != -1 else Rect2()


## The pending option the pointer is on: a banner/sidebar option button, or a highlighted
## card / zone on the board or in the Hand. Read-only (arrow and combat preview only).
func option_under_pointer() -> int:
	if hover_opt != -1:
		return hover_opt
	var m := gs.get_global_mouse_position()
	var sel := gs.selection
	var slots := gs.board.slots
	for k in slots.keys():
		var sl: Dictionary = slots[k]
		var parts: PackedStringArray = (k as String).split(":")
		var pidx := gs.me() if int(parts[0]) == 1 else 1 - gs.me()
		var opt := sel.option_for_ref(pidx, parts[1], int(parts[2]))
		if opt == -1:
			continue
		var w: CardWidget = sl["widget"]
		var zone_pick: bool = String(gs.pending().get("kind", "")) == "slot"
		var r: Rect2 = (sl["holder"] as Control).get_global_rect() if (w.visible and not zone_pick) else (sl["zone_node"] as Control).get_global_rect()
		if r.has_point(m):
			return opt
	var items := gs.hand.items
	for uid in items.keys():
		var hr: Rect2 = (items[uid]["holder"] as Control).get_global_rect()
		if hr.has_point(m):
			var ho := sel.option_for_uid(uid)
			if ho != -1:
				return ho
	return -1


func _option_rect(i: int) -> Rect2:
	var pd := gs.pending()
	var items := gs.hand.items
	for o in pd.get("options", []):
		if o["i"] != i:
			continue
		if o.has("ref"):
			return gs.fx_slot_global_rect(o["ref"]["p"], o["ref"]["zone"], o["ref"]["slot"])
		if o.has("slot"):
			var zit: Dictionary = gs.fx_slot_item(gs.me(), GameSelection.mapped_zone(String(o.get("zone", ""))), o["slot"])
			return (zit["zone_node"] as Control).get_global_rect() if not zit.is_empty() else Rect2()
		if o.has("card") and items.has(o["card"].get("uid", -1)):
			return (items[o["card"]["uid"]]["holder"] as Control).get_global_rect()
	return Rect2()
