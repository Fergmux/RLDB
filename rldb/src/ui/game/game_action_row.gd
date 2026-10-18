class_name GameActionRow
extends RefCounted
## Action row for the click-selected own card (F02-01/F02-02/F02-04): its legal actions as
## buttons against the card, and running one of them.

const BUTTON_H := 30.0
const BUTTON_GAP := 3.0
const ONE_COL_W := 150.0
const TWO_COL_W := 236.0

## The host screen this component works on.
var gs: GameScreen
## The row's button box (in the hover layer), or null.
var stack: Control
var _sig: String = ""


func _init(screen: GameScreen) -> void:
	gs = screen


## Removes the row.
func clear() -> void:
	if stack != null and is_instance_valid(stack):
		stack.queue_free()
	stack = null
	_sig = ""


## Global rect of the row (Rect2() without one).
func stack_rect() -> Rect2:
	if stack == null or not is_instance_valid(stack):
		return Rect2()
	return stack.get_global_rect()


## Legal actions of a card (only enabled ones; reasons stay in the details panel notes).
func actions_for_card(uid: int) -> Array:
	if gs.locked():
		return []
	var oks := []
	for a in gs.mv.get("actions", []):
		if a.get("uid", -1) == uid and a["ok"]:
			oks.append(a)
	return oks


static func _act_sig(acts: Array) -> String:
	var parts := []
	for a in acts:
		parts.append("%s/%s/%s/%s/%s/%s/%s" % [a["t"], a.get("idx", ""), a.get("stance", ""), a.get("mode", ""), a.get("target", ""), a["ok"], a.get("reason", "")])
	return "|".join(parts)


func _row_wanted() -> bool:
	if not gs.row_open or gs.selected_uid == -1 or gs.locked():
		return false
	var it := gs.selection.item_for_uid(gs.selected_uid)
	return not it.is_empty() and it["own"]


## Rebuilds the row only when the selected card's actions (or keyboard focus) changed.
func refresh() -> void:
	if not _row_wanted():
		if stack != null:
			clear()
		return
	var sig := _sig_for(gs.selected_uid, actions_for_card(gs.selected_uid))
	if sig != _sig or stack == null:
		rebuild()


func _sig_for(uid: int, acts: Array) -> String:
	var kb := gs.keyboard
	return _act_sig(acts) + "#%d" % (kb.kb_idx if uid == kb.kb_uid else -1)


## Action row for the click-selected own card. It sits against the card but OUTSIDE its
## body — above a lifted hand card, just below a field card — so the name plate, ATK/DEF and
## status chips stay visible. Buttons carry short labels; the full description is the tooltip
## and lives in the details panel.
func rebuild() -> void:
	clear()
	if not _row_wanted():
		return
	var uid := gs.selected_uid
	var it := gs.selection.item_for_uid(uid)
	var acts := actions_for_card(uid)
	_sig = _sig_for(uid, acts)
	if acts.is_empty():
		return
	var tr := gs.hover.target_rect(it)
	var kind: String = it["kind"]
	var n := acts.size()
	var hand := kind == "hand"
	var bh := BUTTON_H
	var gap := BUTTON_GAP
	var cols := 1 if (hand or n <= 2) else 2
	var rows := int(ceil(float(n) / float(cols)))
	var w := maxf(tr.size.x, ONE_COL_W if cols == 1 else TWO_COL_W)
	var bw := (w - gap * float(cols - 1)) / float(cols)
	var total := rows * bh + (rows - 1) * gap
	var x := tr.get_center().x - w / 2.0
	var top := 0.0
	if hand:
		top = tr.position.y - total - 6.0
	else:
		top = tr.end.y + 4.0
		if top + total > gs.size.y - GameScreen.HAND_H + 4.0 and it["own"]:
			top = tr.position.y - total - 4.0
	x = clampf(x, 4.0, maxf(4.0, gs.play_area.end.x - w - 4.0))
	top = maxf(top, GameScreen.TOP_H + 2.0)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size = Vector2(w, total)
	box.position = gs.hover_layer.get_global_transform().affine_inverse() * Vector2(x, top)
	var kb := gs.keyboard
	for i in n:
		var a: Dictionary = acts[i]
		var txt: String = String(a["label"]) if a["ok"] else String(a["reason"])
		var b := UIStyle.button(txt, 14)
		b.size = Vector2(bw, bh)
		b.custom_minimum_size = Vector2(bw, bh)
		b.position = Vector2(float(i % cols) * (bw + gap), float(int(i / cols)) * (bh + gap))
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = String(a.get("full", a["label"])) + ("" if a["ok"] else "\n" + String(a["reason"]))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if a["ok"] else Control.CURSOR_ARROW
		# Every action button looks the same (user feedback: no special first button).
		var kbf: bool = uid == kb.kb_uid and i == kb.kb_idx
		var nrm := UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.98), UIStyle.SELECT if kbf else Color(UIStyle.GOLD, 0.75), 3 if kbf else 1, 6)
		nrm.border_width_bottom = 3 if kbf else 2
		var hov := UIStyle.flat(Color(UIStyle.PANEL_LIGHT.lightened(0.12), 0.99), UIStyle.GOLD_HI, 2, 6)
		var dis := UIStyle.flat(Color(UIStyle.PANEL_INK, 0.95), Color(UIStyle.BRONZE, 0.5), 1, 6)
		for st in [nrm, hov, dis]:
			st.content_margin_top = 1
			st.content_margin_bottom = 1
			st.content_margin_left = 5
			st.content_margin_right = 5
		UIStyle.lift_style(nrm, Color(0, 0, 0, 0.55), 5, 2)
		UIStyle.lift_style(hov, Color(UIStyle.GOLD, 0.4), 8, 0)
		b.add_theme_stylebox_override("normal", nrm)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_stylebox_override("disabled", dis)
		b.add_theme_color_override("font_disabled_color", UIStyle.MUTED)
		if a["ok"]:
			b.pressed.connect(run_action.bind(uid, a))
		else:
			b.disabled = true
		box.add_child(b)
	gs.hover_layer.add_child(box)
	stack = box
	if not UIStyle.reduce_motion:
		box.modulate.a = 0.0
		var tw := gs.create_tween()
		tw.tween_property(box, "modulate:a", 1.0, UIStyle.dur(0.08))
	box.set_meta("rect_global", Rect2(Vector2(x, top), Vector2(w, total)))


## Sends action `a` of card `uid` if it is still legal (a stale click is denied).
func run_action(uid: int, a: Dictionary) -> void:
	# Ignore a stale click: the action must still be legal for this card instance.
	var still := false
	for b in gs.mv.get("actions", []):
		if b.get("uid", -1) == uid and b["t"] == a["t"] and b.get("idx", -1) == a.get("idx", -1) \
				and b.get("stance", "") == a.get("stance", "") and b.get("mode", "") == a.get("mode", "") 				and b.get("target", -1) == a.get("target", -1) and b["ok"]:
			still = true
	if not still or gs.locked():
		Sfx.play("deny")
		return
	var cmd := {"t": a["t"], "uid": uid}
	if a.has("idx"):
		cmd["idx"] = a["idx"]
	if a.has("stance"):
		cmd["stance"] = a["stance"]
	if a.has("mode"):
		cmd["mode"] = a["mode"]          # G07: Attack / Attack Direct
	if a.has("target"):
		cmd["target"] = a["target"]      # Ritual Tribute: the Ritual unit
	gs.selected_uid = uid
	gs.acting_uid = uid
	gs.row_open = false
	gs.keyboard.kb_uid = -1
	clear()
	var it := gs.selection.item_for_uid(uid)
	var hv := gs.hover.hv
	if not it.is_empty() and not (not hv.is_empty() and hv["uid"] == uid):
		gs.hover.unlift(it)
	Sfx.play("confirm")
	gs.send(cmd)
