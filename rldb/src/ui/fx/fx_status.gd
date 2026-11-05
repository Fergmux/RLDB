class_name FxStatus
extends FxPart
## L8 (owner feedback 2026-11-05): "each status application should have a cool animated effect and
## sound effect that clearly shows what has happened, as well as the text."
##
## Every status event on a board card plays three layers together:
##   1. its own animated look (FxStatusArt: goo for Poison, a flame flare for Burn, arcs for Paralyse...),
##   2. the status badge stamped onto the card (it pops at the centre, then shrinks into the card's
##      status row, so the player sees the badge that now sits there), with a glow in its colour,
##   3. the name in its accent colour ("Poison", "Burn ×2").
## The sound is scheduled by FxPlayer with the event (Sfx "status_<name>", "status_blocked",
## "poison_tick" / "burn_tick", "status_expire").
##
## Events: "status" (applied), "status_blocked" (a Cleanse / Curse stack stopped it: a ward flash),
## "status_tick" (Poison / Burn / Medic paying out), "status_expire" (it wore off).
##
## Several statuses landing on one card in one batch are staggered by FxPlayer (STAGGER) and a new look
## fades the one still playing on that card, so they never pile into mush. Under reduce_motion each is a
## short tinted flash with the badge shown in place and the name, no particles or travel.
##
## L4: the first HOLD_K of each look runs on FxPlayer.new_tween() (it holds the next view back), the
## rest on tail_tween() (its fade never does).

## Seconds of each look.
const LENGTH := 0.95
const TICK_LENGTH := 0.7
const BLOCKED_LENGTH := 1.0
const EXPIRE_LENGTH := 0.6
## Reduce-motion flash length.
const FLASH_LENGTH := 0.45
## Seconds between two statuses landing on the same card in one batch (FxPlayer schedules them).
const STAGGER := 0.42
## Fraction of a look that holds the queue of waiting views (L4); the rest is a tail.
const HOLD_K := 0.65
## Seconds after its start when an application look is at its fullest (evidence driver).
const PEAK_AT := 0.36
## The badge stamp: radius as a fraction of the card width, and its timeline (fractions of LENGTH).
const STAMP_K := 0.27
## Height of the stamp's centre on the card (fraction of its height): high on the art, so each look's
## centre motif (the padlock, the eye, the cross, the sigil) stays in view.
const STAMP_Y := 0.21
const STAMP_IN := 0.16
const STAMP_FLY := 0.38
const STAMP_END := 0.62
## Floating name: font size (base px) and rise (px).
const NAME_FS := 17
const NAME_RISE := 26.0
## Ward colours: Cleanse white-gold, Curse violet.
const WARD_CLEANSE := Color("ffe9a8")
const WARD_CURSE := Color("b98aff")

## The sound of status event `e` (FxPlayer schedules it with the look): "status_<name>" when applied,
## "status_blocked", "poison_tick" / "burn_tick" (Medic paying out: "status_medic"), "status_expire".
static func sound_for(e: Dictionary) -> String:
	var s := String(e.get("s", ""))
	match String(e.get("k", "")):
		"status":
			return "status_" + s if s != "" else ""
		"status_blocked":
			return "status_blocked"
		"status_tick":
			return s + "_tick" if s in ["poison", "burn"] else "status_" + s
		"status_expire":
			return "status_expire"
	return ""


## The looks playing per card slot ("p:zone:slot" -> [nodes]); a new look fades the old one.
var _live := {}
## The name label rising over each card slot; a new one sends the old one up and out at once.
var _names := {}


## A status was applied: `at` {p, zone, slot}, `s` the status, `n` the stacks added.
func apply(at: Dictionary, s: String, n: int) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var col := CardStatusIcons.accent(s)
	var label := s.capitalize() + (" ×%d" % n if n > 1 else "")
	_glow(at, col, 0.95)
	_name(at, rect, label, col, NAME_FS, 1.0)
	if UIStyle.reduce_motion:
		_still_badge(rect, s, n)
		return
	_look(at, rect, s, "apply", "", LENGTH)
	_stamp(rect, s, n, LENGTH)


## Poison / Burn / Medic paid out `n` from the card at `at`: a smaller, quicker look and a badge pulse.
func tick(at: Dictionary, s: String, n: int) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var col := CardStatusIcons.accent(s)
	_glow(at, col, 0.8)
	if UIStyle.reduce_motion:
		_still_badge(rect, s, n)
		return
	_look(at, rect, s, "tick", "", TICK_LENGTH)
	_pulse(rect, s, TICK_LENGTH)


## A Cleanse (`by` "cleanse") or Curse ("curse") stack stopped `s` on the card at `at`: a ward dome
## flashes and the stopped badge bounces off it, with "<Status> blocked" in the ward's colour.
func blocked(at: Dictionary, s: String, by: String) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var wc := WARD_CLEANSE if by == "cleanse" else WARD_CURSE
	_glow(at, wc, 0.95)
	_name(at, rect, "%s blocked" % s.capitalize(), wc, NAME_FS - 1, 1.1)
	if UIStyle.reduce_motion:
		_still_badge(rect, by, 1)
		return
	_look(at, rect, s, "blocked", by, BLOCKED_LENGTH)
	_bounce(rect, s, BLOCKED_LENGTH)


## Status `s` wore off the card at `at`: a ring and motes in its colour, the badge fading up.
func expire(at: Dictionary, s: String) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var col := CardStatusIcons.accent(s)
	_name(at, rect, "%s fades" % s.capitalize(), Color(col, 0.9), NAME_FS - 3, 0.8)
	if UIStyle.reduce_motion:
		return
	_look(at, rect, s, "expire", "", EXPIRE_LENGTH)
	_fade_up(rect, s, EXPIRE_LENGTH)


# ---------------------------------------------------------------- pieces

static func _slot_key(at: Dictionary) -> String:
	return "%d:%s:%d" % [int(at.get("p", 0)), String(at.get("zone", "")), int(at.get("slot", 0))]


## The status name in its colour, rising from just above the card (clear of the badge stamp). A name
## still showing on that card is lifted away and faded first, so two never overlap.
func _name(at: Dictionary, rect: Rect2, text: String, col: Color, fs: int, life: float) -> void:
	var key := _slot_key(at)
	# QA final: untyped, because a skip (FxPlayer.finish_all) frees the label it remembers, and assigning
	# a freed instance to a typed variable is a script error that stopped every later name on the card.
	var old = _names.get(key, null)
	if old != null and is_instance_valid(old):
		var ot := _fx.tail_tween().set_parallel(true)
		ot.tween_property(old, "modulate:a", 0.0, UIStyle.dur(0.14))
		ot.tween_property(old, "position:y", old.position.y - fs * 0.9, UIStyle.dur(0.14))
	var l := Label.new()
	l.text = text
	var font := UIStyle.font_display(700)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	l.size = Vector2(sz.x + 8, fs * 1.4)
	l.pivot_offset = l.size / 2.0
	var p0 := _fx.fx_pos(Vector2(rect.get_center().x, rect.position.y - rect.size.y * 0.02)) - Vector2(l.size.x / 2.0, l.size.y * 0.8)
	l.position = p0
	_fx.add_text(l)
	_names[key] = l
	var tw := _fx.tail_tween()
	if UIStyle.reduce_motion:
		tw.tween_interval(life * 0.7)
		tw.tween_property(l, "modulate:a", 0.0, life * 0.3)
	else:
		l.scale = Vector2(1.35, 1.35)
		tw.set_parallel(true)
		tw.tween_property(l, "scale", Vector2.ONE, UIStyle.dur(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position:y", p0.y - NAME_RISE, UIStyle.dur(life)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, UIStyle.dur(0.25)).set_delay(UIStyle.dur(life - 0.25))
	tw.chain().tween_callback(func() -> void:
		if _names.get(key, null) == l:
			_names.erase(key)
		_fx.free_node(l))


func _rect(at: Dictionary) -> Rect2:
	if at.is_empty() or _fx.screen == null:
		return Rect2()
	return _fx.screen.fx_slot_global_rect(int(at.get("p", 0)), String(at.get("zone", "unit")), int(at.get("slot", 0)))


## The card's own glow, pulsing in `col` once.
func _glow(at: Dictionary, col: Color, peak: float) -> void:
	var it: Dictionary = _fx.screen.fx_slot_item(int(at.get("p", 0)), String(at.get("zone", "unit")), int(at.get("slot", 0)))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	w.fx_glow = Color(col, peak)
	_fx.add_cleanup_on(w, func(cw: CardWidget) -> void: cw.fx_glow = FxCardEffects.NO_GLOW)
	var tw := _fx.new_tween()
	var d := FLASH_LENGTH if UIStyle.reduce_motion else 0.55
	tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(d)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## The two FxStatusArt passes over the card, `t` tweened over `length` (HOLD_K of it holding the queue).
func _look(at: Dictionary, rect: Rect2, s: String, mode: String, ward: String, length: float) -> void:
	var slot_key := _slot_key(at)
	_fade_live(slot_key)
	var seed_value := hash([slot_key, s, mode, Time.get_ticks_msec()])
	var nodes: Array = []
	for g in [false, true]:
		var art := FxStatusArt.new()
		art.glow = g
		art.key = s
		art.mode = mode
		art.ward = ward
		art.seed_value = seed_value
		if g:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			art.material = mat
		_place(art, rect)
		art.z_as_relative = false
		art.z_index = UiLayers.FX
		_fx.add_node(art)
		nodes.append(art)
	_live[slot_key] = nodes
	var main := _fx.new_tween().set_parallel(true)
	for art in nodes:
		main.tween_property(art, "t", HOLD_K, UIStyle.dur(length * HOLD_K))
	main.chain().tween_callback(func() -> void:
		var live: Array = nodes.filter(func(n): return is_instance_valid(n))
		if live.is_empty():
			return
		var tail := _fx.tail_tween().set_parallel(true)
		for art in live:
			tail.tween_property(art, "t", 1.0, UIStyle.dur(length * (1.0 - HOLD_K)))
		tail.chain().tween_callback(func() -> void:
			for art in live:
				_fx.free_node(art)
			if _live.get(slot_key, []) == nodes:
				_live.erase(slot_key)))


## Fades out the look still playing on a card (a new one starts there).
func _fade_live(slot_key: String) -> void:
	var old: Array = _live.get(slot_key, [])
	_live.erase(slot_key)
	var alive := old.filter(func(n): return is_instance_valid(n))
	if alive.is_empty():
		return
	var tw := _fx.tail_tween().set_parallel(true)
	for n in alive:
		tw.tween_property(n, "modulate:a", 0.0, UIStyle.dur(0.14))


## Positions `c` over the card box `rect` (global) in fx-layer coordinates.
func _place(c: Control, rect: Rect2) -> void:
	var a := _fx.fx_pos(rect.position)
	var b := _fx.fx_pos(rect.end)
	c.position = a
	c.size = b - a


## The badge stamp: pops at the card's centre, holds, then shrinks into the status row and fades.
func _stamp(rect: Rect2, s: String, n: int, length: float) -> void:
	var st := _badge_node(rect, s, n)
	# The status row sits over the art's lower edge, just above the name banner.
	var to := _fx.fx_pos(Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.52)) - st.size / 2.0
	st.scale = Vector2(0.2, 0.2)
	st.modulate.a = 0.0
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "modulate:a", 1.0, UIStyle.dur(length * STAMP_IN * 0.6))
	tw.tween_property(st, "scale", Vector2.ONE, UIStyle.dur(length * STAMP_IN)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(UIStyle.dur(length * (STAMP_FLY - STAMP_IN)))
	tw.chain().tween_property(st, "position", to, UIStyle.dur(length * (STAMP_END - STAMP_FLY))).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(st, "scale", Vector2(0.42, 0.42), UIStyle.dur(length * (STAMP_END - STAMP_FLY))).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(st, "modulate:a", 0.0, UIStyle.dur(length * 0.12)).set_delay(UIStyle.dur(length * (STAMP_END - STAMP_FLY - 0.12)))
	tw.chain().tween_callback(_fx.free_node.bind(st))


## A quick badge pulse at the centre (ticks).
func _pulse(rect: Rect2, s: String, length: float) -> void:
	var st := _badge_node(rect, s, 1, 0.22)
	st.scale = Vector2(0.6, 0.6)
	st.modulate.a = 0.0
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "modulate:a", 1.0, UIStyle.dur(length * 0.12))
	tw.tween_property(st, "scale", Vector2(1.15, 1.15), UIStyle.dur(length * 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(st, "modulate:a", 0.0, UIStyle.dur(length * 0.35))
	tw.chain().tween_callback(_fx.free_node.bind(st))


## The stopped badge drops onto the ward, strikes it and spins off, fading.
func _bounce(rect: Rect2, s: String, length: float) -> void:
	var st := _badge_node(rect, s, 1, 0.26)
	var rest: Vector2 = st.position
	var r := rect.size.x * 0.62
	var hit := rest + Vector2(0, -r * 0.62)
	st.position = rest + Vector2(0, -rect.size.y * 0.75)
	st.modulate.a = 0.0
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "modulate:a", 1.0, UIStyle.dur(length * 0.08))
	tw.tween_property(st, "position", hit, UIStyle.dur(length * 0.24)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(st, "position", hit + Vector2(rect.size.x * 0.55, -rect.size.y * 0.35), UIStyle.dur(length * 0.4)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(st, "rotation", 2.4, UIStyle.dur(length * 0.4))
	tw.parallel().tween_property(st, "scale", Vector2(0.55, 0.55), UIStyle.dur(length * 0.4))
	tw.parallel().tween_property(st, "modulate:a", 0.0, UIStyle.dur(length * 0.3)).set_delay(UIStyle.dur(length * 0.12))
	tw.chain().tween_callback(_fx.free_node.bind(st))


## The badge fades up and away (expire).
func _fade_up(rect: Rect2, s: String, length: float) -> void:
	var st := _badge_node(rect, s, 1, 0.2)
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "position:y", st.position.y - rect.size.y * 0.25, UIStyle.dur(length)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "modulate:a", 0.0, UIStyle.dur(length)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_fx.free_node.bind(st))


## Reduce motion: the badge shown in place at the centre, fading out.
func _still_badge(rect: Rect2, s: String, n: int) -> void:
	var st := _badge_node(rect, s, n)
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(FLASH_LENGTH * 0.5))
	tw.tween_property(st, "modulate:a", 0.0, UIStyle.dur(FLASH_LENGTH * 0.5))
	tw.tween_callback(_fx.free_node.bind(st))


## A badge Control centred on the card (radius `k` x card width), above the looks.
func _badge_node(rect: Rect2, s: String, n: int, k: float = STAMP_K) -> Control:
	var a := _fx.fx_pos(rect.position)
	var b := _fx.fx_pos(rect.end)
	var r := (b.x - a.x) * k
	var st := Stamp.new()
	st.key = s
	st.n = n
	st.size = Vector2(r, r) * 2.0
	st.pivot_offset = st.size / 2.0
	st.position = _fx.fx_pos(Vector2(rect.get_center().x, rect.position.y + rect.size.y * STAMP_Y)) - st.size / 2.0
	st.z_as_relative = false
	st.z_index = UiLayers.FX + 1
	_fx.add_node(st)
	return st


## The status badge as a node (CardStatusIcons.draw_token), with its stack count above 1.
class Stamp extends Control:
	var key := ""
	var n := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		draw_texture_rect(FxStatusArt.soft_texture(), Rect2(Vector2.ZERO - Vector2(r, r) * 0.5, size + Vector2(r, r)), false, Color(CardStatusIcons.accent(key), 0.55))
		CardStatusIcons.draw_token(self, size / 2.0, r, key, n, CardStatusIcons.kind_of(key), n > 1)
