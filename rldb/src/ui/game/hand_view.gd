class_name GameHandView
extends RefCounted
## My hand along the bottom of the play area: one widget per card (kept across renders so
## hover state and tweens survive), a gentle fan from five cards and the deal-in animation for
## cards drawn since the last view.

const SPAN_MAX := 1000.0
const CARD_GAP := 8.0

var gs: GameScreen
var layer: Control
var empty_label: Label
## uid -> {holder, widget, hash, placed}
var items: Dictionary = {}
## Hand uids in display order.
var order: Array = []
## Cards I drew in the events of the current view (they are dealt in).
var draws_me: int = 0
## uid -> {"c": global centre, "v": card view} of hand cards removed by the last render.
var _gone: Dictionary = {}


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the hand layer and its empty-hand label.
func build() -> void:
	layer = gs._passive_layer()
	empty_label = UIStyle.label("Your hand is empty.", 14, UIStyle.MUTED)
	empty_label.modulate.a = 0.6
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(empty_label)


## Frees every hand widget (a new seat attached).
func reset() -> void:
	for uid in items.keys():
		(items[uid]["holder"] as Node).queue_free()
	items.clear()
	order.clear()


## Cards that left my hand in the last render, [{c: global centre, v: card view}] (discard fx).
func gone_cards() -> Array:
	return _gone.values()


## Places the hand cards; `new_ids` are dealt in from the draw pile unless `instant`.
func layout(new_ids: Array, instant: bool) -> void:
	var n := order.size()
	var area := gs.play_area
	var sy := gs.size.y
	empty_label.visible = n == 0 and not gs.mv.is_empty()
	empty_label.position = Vector2(area.size.x / 2.0 - 60.0, sy - GameScreen.HAND_H / 2.0 - 10.0)
	if n == 0:
		return
	var hv := gs.hover.hv
	var cw: float = CardWidget.SIZES["hand"].x
	var step := cw + CARD_GAP
	if n * cw + (n - 1) * CARD_GAP > SPAN_MAX:
		step = (SPAN_MAX - cw) / float(n - 1)
	var span := step * (n - 1) + cw
	var x0 := area.size.x / 2.0 - span / 2.0
	var top := sy - GameScreen.HAND_H + 6.0
	var fan := n >= 5 and not UIStyle.reduce_motion
	var deck := gs.pile_anchor(gs.me(), "draw") if not gs.mv.is_empty() else Vector2(100, sy)
	var new_i := 0
	for i in n:
		var uid: int = order[i]
		var it: Dictionary = items[uid]
		var holder: Control = it["holder"]
		var t := 0.0
		if n > 1:
			t = (float(i) - float(n - 1) / 2.0) / (float(n - 1) / 2.0)
		var pos := Vector2(x0 + i * step, top + (t * t * 6.0 if fan else 0.0))
		var rot := deg_to_rad(t * 2.0) if fan else 0.0
		holder.set_meta("rest_rot", rot)
		holder.set_meta("rest_pos", pos)
		var is_hv: bool = (not hv.is_empty() and hv.get("uid", -9) == uid and hv.get("kind", "") == "hand") or (gs.row_open and uid == gs.selected_uid)
		if uid in new_ids and not instant and not UIStyle.reduce_motion:
			holder.position = pos
			holder.rotation = rot
			var w: CardWidget = it["widget"]
			w.position = deck - (pos + holder.size / 2.0)
			w.scale = Vector2(0.5, 0.5)
			w.modulate.a = 0.0
			var tw := gs.create_tween()
			tw.tween_interval(UIStyle.dur(0.07) * new_i)
			tw.tween_property(w, "modulate:a", 1.0, UIStyle.dur(0.06))
			tw.parallel().tween_property(w, "position", Vector2.ZERO, UIStyle.dur(0.28)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.28)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			new_i += 1
			continue
		if instant or UIStyle.reduce_motion or not it.get("placed", false):
			holder.position = pos
			if not is_hv:
				holder.rotation = rot
		else:
			if holder.position.distance_to(pos) > 0.5 or (not is_hv and absf(holder.rotation - rot) > 0.001):
				var tw2 := gs.create_tween()
				tw2.tween_property(holder, "position", pos, UIStyle.dur(0.15)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
				if not is_hv:
					tw2.parallel().tween_property(holder, "rotation", rot, UIStyle.dur(0.15))
		it["placed"] = true
		if not is_hv:
			layer.move_child(holder, i + 1)   # keep the empty-hand label at index 0


## Syncs the hand widgets with my hand in the view and marks options / playable cards.
func render(targeting: bool) -> void:
	var mv := gs.mv
	var sel := gs.selection
	var cards: Array = []
	if not mv.is_empty():
		cards = gs._pv(gs.me()).get("hand", [])
	var seen := {}
	var new_ids := []
	var new_order := []
	var my_turn: bool = not mv.is_empty() and mv["active"] == gs.me() and mv["winner"] == -1 and mv.get("pending", {}).is_empty()
	var ready := gs.board.ready_uids
	_gone.clear()
	for c in cards:
		var uid: int = c["uid"]
		seen[uid] = true
		new_order.append(uid)
		var it: Dictionary = items.get(uid, {})
		if it.is_empty():
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.size = CardWidget.SIZES["hand"]
			holder.pivot_offset = holder.size / 2.0
			var w := CardWidget.new()
			w.auto_hover = false
			w.pressed.connect(sel.on_widget_pressed)
			w.right_pressed.connect(sel.on_widget_right)
			holder.add_child(w)
			layer.add_child(holder)
			it = {"holder": holder, "widget": w, "hash": -1, "placed": false}
			items[uid] = it
			new_ids.append(uid)
		var wd: CardWidget = it["widget"]
		var hsh := hash(c)
		if it["hash"] != hsh:
			wd.setup(c, "hand")
			it["hash"] = hsh
		var opt := sel.option_for_uid(uid)
		var playable: bool = my_turn and ready.has(uid)
		var strong := targeting and opt == -1 and uid != gs.board.src_uid
		var soft := not strong and not playable and opt == -1 and my_turn
		wd.set_marks(opt != -1, uid == gs.selected_uid or (opt != -1 and opt in gs.multi), strong, soft)
		wd.set_ready(playable)
		wd.order_no = sel.order_no(opt)
	for uid in items.keys():
		if not seen.has(uid):
			var h: Control = items[uid]["holder"]
			_gone[uid] = {"c": h.get_global_rect().get_center(), "v": (items[uid]["widget"] as CardWidget).view}
			if not gs.hover.hv.is_empty() and gs.hover.hv.get("uid", -9) == uid:
				gs.hover.clear()
			h.queue_free()
			items.erase(uid)
	order = new_order
	var anim := new_ids if draws_me > 0 else []
	if anim.size() > draws_me:
		anim = anim.slice(anim.size() - draws_me)
	layout(anim, false)
