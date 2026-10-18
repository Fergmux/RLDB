class_name FxCardEffects
extends FxPart
## Effects that animate a card in a board slot: arrive (summon / play), attack, destroy ghost,
## status gain, stat change, stance change and effect trigger. Each handler is bound into the
## FxPlayer schedule; everything transient is undone by FxPlayer.finish_all() through the
## cleanups registered here.

const DISSOLVE_SHADER := "res://assets/shaders/dissolve.gdshader"
## Glow colour meaning "no glow".
const NO_GLOW := Color(1, 1, 1, 0)
## Dust puff at a card's foot when it lands.
const DUST_COLOR := Color("c8b896")
## Effect-target arrow (F03-18): seconds fading in, shown, then fading out. Owner feedback
## 2026-10-18: longer, so it is noticed (was 0.55 s + 0.3 s).
const EFFECT_ARROW_IN := 0.12
const EFFECT_ARROW_HOLD := 1.4
const EFFECT_ARROW_FADE := 0.45


## A card arrives in its slot from the owner's hand anchor (summon / play).
func arrive(p: int, zone: String, slot: int) -> void:
	var it: Dictionary = _fx.screen.fx_slot_item(p, zone, slot)
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	_fx.unhide(w)
	var rect: Rect2 = holder.get_global_rect()
	_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	if UIStyle.reduce_motion:
		w.modulate.a = 0.0
		var tr := _fx.new_tween()
		tr.tween_property(w, "modulate:a", 1.0, 0.08)
		tr.tween_callback(_fx.reset_widget.bind(w, holder))
		return
	var origin: Vector2 = _fx.screen.hand_anchor(p)
	w.fx_offset = origin - rect.get_center()
	w.scale = Vector2(1.18, 1.18)
	w.modulate.a = 0.0
	holder.z_index = UiLayers.FX_CARD
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(w, "modulate:a", 1.0, UIStyle.dur(0.08))
	tw.tween_property(w, "fx_offset", Vector2.ZERO, UIStyle.dur(0.22)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.22)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		_dust_puff(Vector2(rect.get_center().x, rect.end.y - 6))
		w.fx_glow = Color(UIStyle.GOLD_HI, 0.7))
	tw.chain().tween_property(w, "scale", Vector2(0.94, 0.94), UIStyle.dur(0.05))
	tw.chain().tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.05))
	tw.parallel().tween_property(w, "fx_glow", Color(UIStyle.GOLD_HI, 0.0), UIStyle.dur(0.15))
	tw.chain().tween_callback(_fx.reset_widget.bind(w, holder))


## Attack event `e`: wind-up, lunge, impact on the target (card flash + shake or player-plate pulse), return.
func attack(e: Dictionary) -> void:
	var screen: Control = _fx.screen
	var from: Dictionary = e["from"]
	var to: Dictionary = e["to"]
	var it: Dictionary = screen.fx_slot_item(int(from["p"]), "unit", int(from["slot"]))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	var start_c: Vector2 = holder.get_global_rect().get_center()
	var target_c: Vector2
	var tw_item: Dictionary = {}
	var direct: bool = to.get("direct", false)
	if direct:
		target_c = screen.side_center(int(to["p"]))   # middle of the defender's side of the board
	else:
		tw_item = screen.fx_slot_item(int(to["p"]), "unit", int(to["slot"]))
		target_c = screen.fx_slot_global_rect(int(to["p"]), "unit", int(to["slot"])).get_center()
	var dir := target_c - start_c
	var impact := func():
		if direct:
			var pl: PlayerPlate = screen.plate_of(int(to["p"]))
			pl.pulse()
			_fx.shake(pl, 6.0)
		elif not tw_item.is_empty():
			var tw_w: CardWidget = tw_item["widget"]
			var tw_h: Control = tw_item["holder"]
			var fl := _fx.new_tween()
			tw_w.fx_flash = 0.8
			fl.tween_property(tw_w, "fx_flash", 0.0, UIStyle.dur(0.12))
			if not UIStyle.reduce_motion:
				var sh := _fx.new_tween()
				for dx in [6.0, -6.0, 4.0, -2.0, 0.0]:
					sh.tween_property(tw_w, "fx_offset:x", dx, UIStyle.dur(0.03))
				sh.tween_callback(_fx.reset_widget.bind(tw_w, tw_h))
				_fx.add_cleanup(_fx.reset_widget.bind(tw_w, tw_h))
		_fx.burst(FxBurst.Kind.SPARK, start_c + dir * (0.6 if not direct else 0.55), Color("ffe08a"), 8, 36.0, 0.25)
	_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	if UIStyle.reduce_motion:
		w.fx_glow = Color(UIStyle.TARGET, 0.8)
		var tr := _fx.new_tween()
		tr.tween_callback(impact)
		tr.tween_property(w, "fx_glow", Color(UIStyle.TARGET, 0.0), 0.15)
		tr.tween_callback(_fx.reset_widget.bind(w, holder))
		return
	var wind := -dir.normalized() * 8.0
	var lunge := dir * 0.6
	holder.z_index = UiLayers.FX_CARD_FRONT
	var tw := _fx.new_tween()
	tw.tween_property(w, "fx_offset", wind, UIStyle.dur(0.08)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "fx_offset", lunge, UIStyle.dur(0.11)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_callback(impact)
	tw.tween_interval(UIStyle.dur(0.04))
	tw.tween_property(w, "fx_offset", Vector2.ZERO, UIStyle.dur(0.13)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_fx.reset_widget.bind(w, holder))


## A status `s` is gained on the card at `at`: coloured glow plus a floating label.
func status(at: Dictionary, s: String, _n: int) -> void:
	var p := int(at["p"])
	var zone := String(at["zone"])
	var slot := int(at["slot"])
	var it: Dictionary = _fx.screen.fx_slot_item(p, zone, slot)
	var col := UIStyle.RUNE_BLUE if s == "rune" else (Color("6fd38a") if CardDB.is_buff(s) else Color("e8605a"))
	if not it.is_empty():
		var w: CardWidget = it["widget"]
		w.fx_glow = Color(col, 0.9)
		_clear_glow_on_finish(w)
		var tw := _fx.new_tween()
		tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.2 if UIStyle.reduce_motion else 0.4)).set_trans(Tween.TRANS_SINE)
	var rect: Rect2 = _fx.screen.fx_slot_global_rect(p, zone, slot)
	_fx.float_text(s.capitalize(), col.lightened(0.3), rect.get_center() + Vector2(0, -rect.size.y * 0.3), 15, 24.0, 0.7, false, false)


## The card at `at` changed ATK / DEF: a short gold glow.
func stat(at: Dictionary) -> void:
	var it: Dictionary = _fx.screen.fx_slot_item(int(at["p"]), String(at["zone"]), int(at["slot"]))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	w.fx_glow = Color(UIStyle.GOLD_HI, 0.6)
	_clear_glow_on_finish(w)
	var tw := _fx.new_tween()
	tw.tween_property(w, "fx_glow", Color(UIStyle.GOLD_HI, 0.0), UIStyle.dur(0.3))


## A chosen effect target (F03-18): the targeting arrow flashes from the source card at `from` to
## the card at `at`, then fades. Shown to both seats; the source is a board position only.
func effect_arrow(from: Dictionary, at: Dictionary) -> void:
	var ra: Rect2 = _fx.screen.fx_slot_global_rect(int(from["p"]), String(from["zone"]), int(from["slot"]))
	var rb: Rect2 = _fx.screen.fx_slot_global_rect(int(at["p"]), String(at["zone"]), int(at["slot"]))
	if ra.size == Vector2.ZERO or rb.size == Vector2.ZERO:
		return
	var arrow := ArrowLayer.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrow.a = _fx.fx_pos(ra.get_center())
	arrow.b = _fx.fx_pos(rb.get_center())
	arrow.on = true
	arrow.modulate.a = 0.0
	_fx.add_node(arrow)
	arrow.queue_redraw()
	var tw := _fx.new_tween()
	tw.tween_property(arrow, "modulate:a", 1.0, UIStyle.dur(EFFECT_ARROW_IN))
	tw.tween_interval(UIStyle.dur(EFFECT_ARROW_HOLD))
	tw.tween_property(arrow, "modulate:a", 0.0, UIStyle.dur(EFFECT_ARROW_FADE))
	tw.tween_callback(_fx.free_node.bind(arrow))


## Stance change (`to` = "def" | "atk"): the widget is already drawn in its final orientation, so it
## turns from the old orientation (-/+90 degrees about its centre) into place with a small scale
## bounce, a glint and a short label.
func stance(p: int, slot: int, to: String) -> void:
	var it: Dictionary = _fx.screen.fx_slot_item(p, "unit", slot)
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	var to_def := to == "def"
	var col := Color("8ec5ff") if to_def else Color("ff9a7a")
	_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	var rect: Rect2 = holder.get_global_rect()
	_fx.float_text("Defense" if to_def else "Attack", col, rect.get_center() + Vector2(0, -rect.size.y * 0.32), 15, 20.0, 0.7, false, false)
	if UIStyle.reduce_motion:
		w.fx_glow = Color(col, 0.8)
		var tr := _fx.new_tween()
		tr.tween_property(w, "fx_glow", Color(col, 0.0), 0.25)
		tr.tween_callback(_fx.reset_widget.bind(w, holder))
		return
	w.pivot_offset = w.size / 2.0
	w.rotation = -PI / 2.0 if to_def else PI / 2.0
	holder.z_index = UiLayers.FX_CARD
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(w, "rotation", 0.0, UIStyle.dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2(1.1, 1.1), UIStyle.dur(0.14)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.18)).set_delay(UIStyle.dur(0.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "fx_flash", 0.45, UIStyle.dur(0.08)).set_delay(UIStyle.dur(0.2))
	tw.tween_property(w, "fx_flash", 0.0, UIStyle.dur(0.18)).set_delay(UIStyle.dur(0.28))
	tw.tween_property(w, "fx_glow", Color(col, 0.75), UIStyle.dur(0.1)).set_delay(UIStyle.dur(0.2))
	tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.25)).set_delay(UIStyle.dur(0.3))
	tw.chain().tween_callback(_fx.reset_widget.bind(w, holder))


## A unit / Power effect is used (triggered effect or activated ability): a gold rune ring bursts out
## of the card while it plays the summon-style flourish (pop, then a landing squash with a gold glow
## and a dust puff at its foot) and gives a short horizontal shake (~0.25 s, a few px). Unlike a
## status gain (no label, no colour code). Reduced motion: the glow only. Everything is undone by
## reset_widget, also from finish_all().
func trigger(at: Dictionary) -> void:
	var it: Dictionary = _fx.screen.fx_slot_item(int(at["p"]), String(at["zone"]), int(at["slot"]))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	var col := UIStyle.GOLD_HI
	_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		w.fx_glow = Color(col, 0.9)
		tw.tween_property(w, "fx_glow", Color(col, 0.0), 0.3)
		tw.tween_callback(_fx.reset_widget.bind(w, holder))
		return
	var grect := w.get_global_rect()
	var foot := Vector2(grect.get_center().x, grect.end.y - 6.0)
	var ring := FxRuneRing.new()
	ring.col = col
	ring.radius = grect.size.length() * 0.5
	ring.position = _fx.fx_pos(grect.get_center())
	_fx.add_node(ring)
	var rt := _fx.new_tween()
	rt.tween_property(ring, "t", 1.0, UIStyle.dur(0.5))
	rt.tween_callback(_fx.free_node.bind(ring))
	holder.z_index = UiLayers.FX_CARD
	w.pivot_offset = w.size / 2.0
	# Opening glint on its own track so it does not hold up the sequence below.
	var fl := _fx.new_tween()
	fl.tween_property(w, "fx_flash", 0.45, UIStyle.dur(0.06))
	fl.tween_property(w, "fx_flash", 0.0, UIStyle.dur(0.18))
	# Pop up, settle, then land like a summon: dust, glow, squash, shake.
	tw.tween_property(w, "scale", Vector2(1.12, 1.12), UIStyle.dur(0.09)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.12)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(_dust_puff.bind(foot))
	tw.set_parallel(true)
	tw.chain().tween_property(w, "scale", Vector2(0.94, 0.94), UIStyle.dur(0.05))
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.07)).set_delay(UIStyle.dur(0.05))
	tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.32)).from(Color(col, 0.8)).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_shake_x.bind(w, 5.0), 0.0, 1.0, UIStyle.dur(0.25))
	tw.chain().tween_callback(_fx.reset_widget.bind(w, holder))


## Dust puff at a card's landing point (global position).
func _dust_puff(global_foot: Vector2) -> void:
	_fx.burst(FxBurst.Kind.DUST, global_foot, DUST_COLOR, 6, 46.0, 0.35)


## Registers a cleanup that removes the glow from `w` when the effects are skipped.
func _clear_glow_on_finish(w: CardWidget) -> void:
	_fx.add_cleanup(func(): if is_instance_valid(w): w.fx_glow = NO_GLOW)


## Damped horizontal shake of a slot widget about its rest position; `k` runs 0 -> 1. Drives the
## widget's fx_offset (F02), so a lifted (hovered) card is shaken in place and never re-anchored.
func _shake_x(k: float, w: CardWidget, amp: float) -> void:
	if is_instance_valid(w):
		w.fx_offset = Vector2(amp * sin(k * TAU * 3.0) * (1.0 - k), 0.0)
