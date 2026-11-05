class_name FxControlMove
extends FxPart
## L9 / L8 (owner feedback 2026-11-05): Hypnotise taking a unit, and the unit going home at end of turn.
## The rules emit {"k": "control", "from", "to", "p", "id", "back"[, "dest"]}; before this the unit simply
## jumped between zones. Now it lifts out of its old zone, glides across the board on a gentle arc with
## a violet hypnotic swirl and trail, and settles into its new zone with a soft ring. Taking control
## winds the swirl in (clockwise) and locks with a bright violet ring; the return unwinds it
## (anticlockwise) and the ring breaks into motes as the spell lifts. A unit sent to Spent on its
## return (its zone was filled) gets the swirl in its old zone and the usual flight to the pile.
## Under reduce motion: no travel, a short violet glow on the unit where it lands.
## The sound comes with the event (Sfx.for_fx: control_steal / control_return).

## Seconds: lift, glide, settle.
const LIFT := 0.14
const GLIDE := 0.62
const SETTLE := 0.2
## Card lift scale while it travels.
const LIFT_SCALE := 1.14
## Arc height as a fraction of the travel distance (at least ARC_MIN px).
const ARC_K := 0.28
const ARC_MIN := 50.0
const VIOLET := Color("b07ae0")
const VIOLET_DEEP := Color("6a2fb0")


## Seconds the whole move takes (FxPlayer schedules what follows after it).
static func length_for() -> float:
	return LIFT + GLIDE + SETTLE


## Plays control event `e` for a unit that lands in a zone ("to" not empty).
func move(e: Dictionary) -> void:
	var from: Dictionary = e.get("from", {})
	var to: Dictionary = e.get("to", {})
	if from.is_empty() or to.is_empty():
		return
	var it: Dictionary = _fx.screen.fx_slot_item(int(to["p"]), String(to.get("zone", "unit")), int(to["slot"]))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	_fx.unhide(w)
	var rt: Rect2 = holder.get_global_rect()
	var rf: Rect2 = _fx.screen.fx_slot_global_rect(int(from["p"]), String(from.get("zone", "unit")), int(from["slot"]))
	var back := bool(e.get("back", false))
	_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	if UIStyle.reduce_motion or rf.size == Vector2.ZERO:
		w.modulate.a = 0.0
		w.fx_glow = Color(VIOLET, 0.9)
		var tr := _fx.new_tween()
		tr.tween_property(w, "modulate:a", 1.0, 0.1)
		tr.tween_property(w, "fx_glow", Color(VIOLET, 0.0), 0.3)
		tr.tween_callback(_fx.reset_widget.bind(w, holder))
		return
	var d := rf.get_center() - rt.get_center()
	var dist := d.length()
	var arc := Vector2(0, -maxf(ARC_MIN, dist * ARC_K))
	var ctrl := d * 0.5 + arc
	holder.z_index = UiLayers.FX_CARD_FRONT
	w.fx_offset = d
	w.fx_glow = Color(VIOLET, 0.0)
	var trail := Trail.new()
	trail.spin = -1.0 if back else 1.0
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.radius = rt.size.x * 0.85
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = mat
	trail.z_as_relative = false
	trail.z_index = UiLayers.FX
	_fx.add_node(trail)
	var to_c := rt.get_center()
	var sway := 0.07 * signf(d.x if absf(d.x) > 1.0 else 1.0)
	var tw := _fx.new_tween()
	# Lift: the card rises and the swirl gathers round it.
	tw.set_parallel(true)
	tw.tween_property(w, "scale", Vector2.ONE * LIFT_SCALE, UIStyle.dur(LIFT)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "fx_glow", Color(VIOLET, 0.85), UIStyle.dur(LIFT))
	tw.tween_property(trail, "gather", 1.0, UIStyle.dur(LIFT))
	trail.head = _fx.fx_pos(to_c + d)
	# Glide along the arc.
	tw.chain().tween_method(func(f: float) -> void:
		if not is_instance_valid(w) or not is_instance_valid(trail):
			return
		var off := _bezier(d, ctrl, Vector2.ZERO, f)
		w.fx_offset = off
		w.rotation = sin(f * PI) * sway
		trail.push(_fx.fx_pos(to_c + off), f), 0.0, 1.0, UIStyle.dur(GLIDE)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Settle: a small squash, the glow and the swirl let go.
	tw.chain().tween_property(w, "scale", Vector2(0.95, 0.95), UIStyle.dur(SETTLE * 0.45)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(trail, "landed", 1.0, UIStyle.dur(SETTLE + 0.3))
	tw.chain().tween_property(w, "scale", Vector2.ONE, UIStyle.dur(SETTLE * 0.55)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(w, "fx_glow", Color(VIOLET, 0.0), UIStyle.dur(SETTLE + 0.15))
	tw.chain().tween_callback(_fx.reset_widget.bind(w, holder))
	# The landing ring and the trail's fade are tails (they never hold the next view back).
	tw.chain().tween_callback(func() -> void:
		if not is_instance_valid(trail):
			return
		var tail := _fx.tail_tween()
		tail.tween_property(trail, "landed", 2.0, UIStyle.dur(0.35))
		tail.tween_callback(_fx.free_node.bind(trail)))


## A violet swirl over the zone at `at` (a unit sent from there to Spent on its return).
func swirl_at(at: Dictionary) -> void:
	if at.is_empty() or UIStyle.reduce_motion:
		return
	var r: Rect2 = _fx.screen.fx_slot_global_rect(int(at["p"]), String(at.get("zone", "unit")), int(at["slot"]))
	if r.size == Vector2.ZERO:
		return
	var trail := Trail.new()
	trail.spin = -1.0
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.radius = r.size.x * 0.85
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = mat
	trail.z_as_relative = false
	trail.z_index = UiLayers.FX
	_fx.add_node(trail)
	trail.push(_fx.fx_pos(r.get_center()), 1.0)
	var tw := _fx.new_tween()
	tw.tween_property(trail, "gather", 1.0, UIStyle.dur(0.2))
	tw.tween_property(trail, "landed", 2.0, UIStyle.dur(0.5))
	tw.tween_callback(_fx.free_node.bind(trail))


static func _bezier(a: Vector2, c: Vector2, b: Vector2, f: float) -> Vector2:
	var u := 1.0 - f
	return a * u * u + c * 2.0 * u * f + b * f * f


## The hypnotic swirl: spiral arms turning round the travelling card, a fading ribbon behind it and,
## on landing, a ring (bright on taking control, breaking into motes on the return). Additive.
class Trail extends Control:
	## +1 winds clockwise (taking control), -1 unwinds (the return).
	var spin := 1.0
	## Swirl radius (px, fx-layer space).
	var radius := 50.0
	## 0 -> 1 while the card lifts.
	var gather := 0.0: set = _set_gather
	## 0 -> 1 settling, 1 -> 2 the ring and the swirl fading.
	var landed := 0.0: set = _set_landed
	## Current card centre (fx-layer space).
	var head := Vector2.ZERO
	var _pts: PackedVector2Array = PackedVector2Array()
	var _f := 0.0

	func _set_gather(v: float) -> void:
		gather = v
		queue_redraw()

	func _set_landed(v: float) -> void:
		landed = v
		queue_redraw()

	## Moves the head to `p` at glide progress `f`, keeping a short ribbon behind it.
	func push(p: Vector2, f: float) -> void:
		head = p
		_f = f
		_pts.append(p)
		if _pts.size() > 18:
			_pts.remove_at(0)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf(2.0 - landed, 0.0, 1.0)
		var a := gather * fade
		if a <= 0.01:
			return
		var soft := FxStatusArt.soft_texture()
		var turn := (_f * 7.0 + landed * 3.0) * spin
		# The ribbon behind the card.
		var n := _pts.size()
		for i in range(1, n):
			var k := float(i) / float(n)
			draw_line(_pts[i - 1], _pts[i], Color(FxControlMove.VIOLET, 0.5 * k * a * (1.0 - clampf(landed, 0.0, 1.0))), radius * 0.35 * k, true)
		# The swirl: three spiral arms (a fine line and a string of motes) turning round the card.
		var spread := 1.0 - 0.35 * clampf(landed, 0.0, 1.0)
		for arm in 3:
			var line := PackedVector2Array()
			for j in 13:
				var f := float(j) / 12.0
				var ang := turn + float(arm) * TAU / 3.0 + f * 2.8 * spin
				var r := radius * (0.3 + 0.8 * f) * spread
				var p := head + Vector2(cos(ang), sin(ang) * 0.82) * r
				line.append(p)
				if j % 2 == 0:
					var s := radius * (0.2 - 0.12 * f)
					draw_texture_rect(soft, Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(FxControlMove.VIOLET, 0.95 * a * (1.0 - f * 0.5)))
				if j % 4 == 0:
					draw_circle(p, maxf(1.0, radius * 0.035), Color(1.0, 0.92, 1.0, 0.95 * a), true, -1.0, true)
			draw_polyline(line, Color(0.9, 0.75, 1.0, 0.7 * a), maxf(1.0, radius * 0.035), true)
		draw_texture_rect(soft, Rect2(head - Vector2(radius, radius) * 1.1, Vector2(radius, radius) * 2.2), false, Color(FxControlMove.VIOLET_DEEP, 0.35 * a))
		# The landing ring.
		if landed > 0.0:
			var rk := clampf(landed - 0.2, 0.0, 1.8) / 1.8
			var rr := radius * (0.7 + 0.7 * rk)
			if spin > 0.0:
				draw_arc(head, rr, 0.0, TAU, 48, Color(0.85, 0.65, 1.0, 0.9 * (1.0 - rk)), maxf(1.0, radius * 0.06), true)
			else:
				for i in 16:
					var ang2 := float(i) * TAU / 16.0
					draw_arc(head, rr, ang2, ang2 + TAU / 32.0, 4, Color(0.85, 0.65, 1.0, 0.9 * (1.0 - rk)), maxf(1.0, radius * 0.06), true)
