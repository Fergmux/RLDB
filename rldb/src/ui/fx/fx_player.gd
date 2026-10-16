class_name FxPlayer
extends Node
## Presentation-only effects driven by the public `fx` events of NEW log entries
## (art bible section 6). It never sends commands and never owns state: the board is
## already rendered in its final state, effects animate overlays or transient offsets on
## top of it. Any click calls finish_all(), which snaps everything back to the final state.
##
## Host contract (GameScreen): fx_layer, banner_layer, me(), fx_slot_item(p, zone, slot),
## fx_slot_global_rect(p, zone, slot), plate_of(p), hand_anchor(p), board_global_rect().

const ZONE_KEY := {"unit": "units", "backrow": "backrow", "power": "powers"}
const ZONE_KIND := {"unit": "board", "backrow": "trap", "power": "power"}
const PHASE_NAMES := {"main1": "SETUP PHASE", "battle": "BATTLE PHASE", "main2": "RECOVERY PHASE", "end": "END PHASE"}

var screen: Control
var _tweens: Array = []
var _cleanups: Array = []
var _hidden: Array = []
var _nodes: Array = []
var _banner_q: Array = []
var _banner_active: bool = false
var _banner_node: Control = null
## Spell/Trap spotlights run one at a time from their own queue (never overlapping, never compressed
## by play()'s 3 s batch rule).
var _spot_q: Array = []
var _spot_active: bool = false


## Inner particle node: kind "dust" ring, "ember" rising sparks or "spark" streaks.
class Burst extends Control:
	var kind: String = "dust"
	var col: Color = Color.WHITE
	var count: int = 6
	var radius: float = 40.0
	var t: float = 0.0: set = _set_t
	var seeds: Array[float] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 12:
			seeds.append(randf())

	func _set_t(v: float) -> void:
		t = v
		queue_redraw()

	func _draw() -> void:
		for i in count:
			var a := TAU * float(i) / float(count) + seeds[i % 12] * 0.6
			var d := Vector2(cos(a), sin(a))
			match kind:
				"dust":
					var e := 1.0 - pow(1.0 - t, 2.0)
					draw_circle(d * radius * e * Vector2(1.0, 0.45), 3.2 * (1.0 - t) + 0.5, Color(col, 0.6 * (1.0 - t)), true, -1.0, true)
				"ember":
					var e2 := 1.0 - pow(1.0 - t, 2.0)
					var p := d * radius * 0.5 * e2 * (0.5 + seeds[i % 12]) + Vector2(0, -t * radius * (0.6 + seeds[(i + 3) % 12]))
					draw_circle(p, 2.6 * (1.0 - t) + 0.4, Color(col, 1.0 - t), true, -1.0, true)
				"spark":
					var e3 := 1.0 - pow(1.0 - t, 3.0)
					draw_line(d * radius * (0.25 + e3 * 0.5), d * radius * (0.35 + e3 * 0.75), Color(col, 1.0 - t), 2.5 * (1.0 - t) + 0.5, true)


## Inner rune-ring burst for a triggered effect: two expanding rings carrying a turning circle of
## rune marks, fading out as `t` goes 0 -> 1. Drawn centred on the node position.
class RuneRing extends Control:
	var col: Color = Color.WHITE
	var radius: float = 70.0
	var t: float = 0.0: set = _set_t

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _set_t(v: float) -> void:
		t = v
		queue_redraw()

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - t, 3.0)
		var a := 1.0 - t
		var r := radius * (0.45 + 0.75 * e)
		draw_circle(Vector2.ZERO, r * 0.95, Color(col, 0.16 * a * a), true, -1.0, true)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(col.lightened(0.4), 0.95 * a), 1.0 + 3.0 * a, true)
		draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 56, Color(col, 0.55 * a), 1.0 + 1.2 * a, true)
		var rr := r * 0.9
		for i in 12:
			var ang := float(i) * TAU / 12.0 + t * 1.4
			var c := Vector2(cos(ang), sin(ang)) * rr
			var u := Vector2(cos(ang), sin(ang)) * (2.0 + 3.0 * a)
			var v := Vector2(-u.y, u.x) * 0.6
			draw_colored_polygon(PackedVector2Array([c + u, c + v, c - u, c - v]), Color(col.lightened(0.5), a))


func _tw() -> Tween:
	var t := screen.create_tween()
	_tweens.append(t)
	return t


func busy() -> bool:
	for t in _tweens:
		if t is Tween and t.is_valid() and t.is_running():
			return true
	return _banner_active or _spot_active


## Skips everything running: kills tweens, runs cleanups (resets transient offsets) and
## frees overlay nodes. Idempotent.
func finish_all() -> void:
	for t in _tweens:
		if t is Tween and t.is_valid():
			t.kill()
	_tweens.clear()
	for c in _cleanups:
		if c is Callable and c.is_valid():
			c.call()
	_cleanups.clear()
	for w in _hidden:
		if is_instance_valid(w):
			w.modulate.a = 1.0
	_hidden.clear()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_banner_q.clear()
	_banner_active = false
	_banner_node = null
	_spot_q.clear()
	_spot_active = false


func _later(delay: float, fn: Callable) -> void:
	if delay <= 0.001:
		fn.call()
		return
	var t := _tw()
	t.tween_interval(delay)
	t.tween_callback(fn)


func _fx_pos(global: Vector2) -> Vector2:
	return screen.fx_layer.get_global_transform().affine_inverse() * global


func _add_node(n: Control, layer: Control = null) -> void:
	(layer if layer != null else screen.fx_layer).add_child(n)
	_nodes.append(n)


func _free_node(n: Node) -> void:
	_nodes.erase(n)
	if is_instance_valid(n):
		n.queue_free()


# ---------------------------------------------------------------- scheduling

## Plays the events of the newly seen log entries in order. `prev_mv` is the match view
## before this update (used to draw destroyed cards that are already gone).
func play(events: Array, prev_mv: Dictionary) -> void:
	if events.is_empty():
		return
	if not busy():
		_tweens.clear()
		_cleanups.clear()
	var sched: Array = []   # [time, Callable]
	var spot_marks: Array = []   # sched indices after which a spotlight hold starts
	var t := 0.0
	var attack_end := 0.0
	var turn_in_batch := false
	for e in events:
		if e["k"] == "turn":
			turn_in_batch = true
	var fast := UIStyle.reduce_motion
	for e in events:
		# F02-13: each public event's sound starts with its animation (Sfx rate-limits bursts).
		var snd := Sfx.for_fx(e, screen.me())
		if snd != "":
			var st0 := maxf(t, attack_end) if e["k"] == "attack" else (t + 0.2 if e["k"] == "game_over" else t)
			sched.append([st0, Sfx.play.bind(snd, 0.0, 0.04)])
			if e["k"] == "attack" and not e.get("to", {}).get("direct", false):
				sched.append([st0 + (0.12 if fast else 0.26), Sfx.play.bind("impact", 0.0, 0.04)])
		match String(e["k"]):
			"attack":
				var st := maxf(t, attack_end)
				sched.append([st, _attack.bind(e)])
				attack_end = st + (0.2 if fast else 0.46)
				t = st + (0.1 if fast else 0.2)
			"summon":
				_prehide(int(e["p"]), "unit", int(e["slot"]), t, sched, _arrive.bind(int(e["p"]), "unit", int(e["slot"])))
				t += 0.16
			"play":
				_prehide(int(e["p"]), String(e["zone"]), int(e["slot"]), t, sched, _arrive.bind(int(e["p"]), String(e["zone"]), int(e["slot"])))
				t += 0.16
			"hp":
				sched.append([t, _hp.bind(int(e["p"]), int(e["d"]))])
				t += 0.06
			"ap":
				sched.append([t, _ap.bind(int(e["p"]), int(e["d"]))])
				t += 0.04
			"draw":
				if int(e["p"]) != screen.me():
					sched.append([t, _draw_opp.bind(int(e["p"]), int(e["n"]))])
			"discard":
				sched.append([t, _discard.bind(int(e["p"]), int(e["n"]))])
			"destroy":
				sched.append([t, _destroy.bind(e["at"], prev_mv)])
				t += 0.12
			"status":
				sched.append([t, _status.bind(e["at"], String(e["s"]), int(e.get("n", 1)))])
				t += 0.06
			"stat":
				sched.append([t, _stat.bind(e["at"])])
			"stance":
				var sat: Dictionary = e["at"]
				sched.append([t, _stance.bind(int(sat["p"]), int(sat["slot"]), String(e.get("to", "def")))])
				t += 0.12
			"trigger":
				sched.append([t, _trigger.bind(e["at"])])
				t += 0.1
			"spotlight":
				# The card is shown first; everything after it in this batch (statuses, destroys,
				# HP changes) waits until it has left the screen.
				sched.append([t, _spotlight.bind(e)])
				t += 0.05
				spot_marks.append(sched.size())
			"turn":
				var mine: bool = int(e["p"]) == screen.me()
				sched.append([t, _banner.bind("YOUR TURN" if mine else "OPPONENT'S TURN", "Turn %d" % int(e["turn"]), UIStyle.GOLD_HI if mine else Color("d8c9a8"), mine)])
			"phase":
				var ph := String(e["phase"])
				if ph in ["battle", "main2"] or (ph == "main1" and not turn_in_batch):
					sched.append([t, _banner.bind(PHASE_NAMES[ph], "", Color("e8dcc0"), false)])
			"game_over":
				sched.append([t + 0.2, _game_over.bind(int(e["winner"]))])
	var last := 0.0
	for s in sched:
		last = maxf(last, s[0])
	var k := 1.0 if last <= 3.0 else 3.0 / last
	# Spotlight holds are added after the batch compression so they always last their full time.
	var shift := 0.0
	for i in sched.size():
		while not spot_marks.is_empty() and spot_marks[0] <= i:
			spot_marks.pop_front()
			shift += SPOT_HOLD
		_later((float(sched[i][0]) * k + shift) * UIStyle.dur(1.0), sched[i][1])


func _prehide(p: int, zone: String, slot: int, t: float, sched: Array, fn: Callable) -> void:
	var it: Dictionary = screen.fx_slot_item(p, zone, slot)
	if not it.is_empty() and t > 0.02:
		var w: CardWidget = it["widget"]
		w.modulate.a = 0.0
		_hidden.append(w)
	sched.append([t, fn])


# ---------------------------------------------------------------- helpers

func _float_text(text: String, col: Color, global_pos: Vector2, fs: int, rise: float, life: float, display: bool = true, pop: bool = true) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIStyle.font_display(700) if display else UIStyle.font_bold())
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := UIStyle.font_display(700).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	l.size = Vector2(sz.x + 4, fs * 1.4)
	l.pivot_offset = l.size / 2.0
	var p0 := _fx_pos(global_pos) - l.size / 2.0
	l.position = p0
	_add_node(l)
	var reduced := UIStyle.reduce_motion
	if not reduced and pop:
		l.scale = Vector2(1.3, 1.3)
	var tw := _tw()
	if reduced:
		tw.tween_interval(life * 0.7)
		tw.tween_property(l, "modulate:a", 0.0, life * 0.3)
	else:
		tw.set_parallel(true)
		tw.tween_property(l, "scale", Vector2.ONE, UIStyle.dur(0.09))
		tw.tween_property(l, "position:y", p0.y - rise, UIStyle.dur(life)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, UIStyle.dur(0.25)).set_delay(UIStyle.dur(life - 0.25))
	tw.chain().tween_callback(_free_node.bind(l))


func _burst(kind: String, global_center: Vector2, col: Color, count: int, radius: float, life: float) -> void:
	if UIStyle.reduce_motion:
		return
	var b := Burst.new()
	b.kind = kind
	b.col = col
	b.count = count
	b.radius = radius
	b.size = Vector2(4, 4)
	b.position = _fx_pos(global_center)
	_add_node(b)
	var tw := _tw()
	tw.tween_property(b, "t", 1.0, UIStyle.dur(life))
	tw.tween_callback(_free_node.bind(b))


func _reset_widget(w: CardWidget, holder: Control) -> void:
	if is_instance_valid(w):
		w.position = Vector2.ZERO
		w.scale = Vector2.ONE
		w.rotation = 0.0
		w.modulate = Color.WHITE
		w.fx_flash = 0.0
		w.fx_glow = Color(1, 1, 1, 0)
	if is_instance_valid(holder):
		holder.z_index = 0


func _shake(node: Control, amp: float) -> void:
	if UIStyle.reduce_motion:
		return
	var rest := node.position
	_cleanups.append(func(): if is_instance_valid(node): node.position = rest)
	var tw := _tw()
	for dx in [amp, -amp, amp * 0.6, -amp * 0.3, 0.0]:
		tw.tween_property(node, "position:x", rest.x + dx, UIStyle.dur(0.03))
	tw.tween_callback(func(): if is_instance_valid(node): node.position = rest)


# ---------------------------------------------------------------- effects

func _arrive(p: int, zone: String, slot: int) -> void:
	var it: Dictionary = screen.fx_slot_item(p, zone, slot)
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	_hidden.erase(w)
	var rect: Rect2 = holder.get_global_rect()
	_cleanups.append(_reset_widget.bind(w, holder))
	if UIStyle.reduce_motion:
		w.modulate.a = 0.0
		var tr := _tw()
		tr.tween_property(w, "modulate:a", 1.0, 0.08)
		tr.tween_callback(_reset_widget.bind(w, holder))
		return
	var origin: Vector2 = screen.hand_anchor(p)
	w.position = origin - rect.get_center()
	w.scale = Vector2(1.18, 1.18)
	w.modulate.a = 0.0
	holder.z_index = 20
	var tw := _tw()
	tw.set_parallel(true)
	tw.tween_property(w, "modulate:a", 1.0, UIStyle.dur(0.08))
	tw.tween_property(w, "position", Vector2.ZERO, UIStyle.dur(0.22)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.22)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		_burst("dust", Vector2(rect.get_center().x, rect.end.y - 6), Color("c8b896"), 6, 46.0, 0.35)
		w.fx_glow = Color(UIStyle.GOLD_HI, 0.7))
	tw.chain().tween_property(w, "scale", Vector2(0.94, 0.94), UIStyle.dur(0.05))
	tw.chain().tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.05))
	tw.parallel().tween_property(w, "fx_glow", Color(UIStyle.GOLD_HI, 0.0), UIStyle.dur(0.15))
	tw.chain().tween_callback(_reset_widget.bind(w, holder))


func _attack(e: Dictionary) -> void:
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
			_shake(pl, 6.0)
		elif not tw_item.is_empty():
			var tw_w: CardWidget = tw_item["widget"]
			var tw_h: Control = tw_item["holder"]
			var fl := _tw()
			tw_w.fx_flash = 0.8
			fl.tween_property(tw_w, "fx_flash", 0.0, UIStyle.dur(0.12))
			if not UIStyle.reduce_motion:
				var rest := Vector2.ZERO
				var sh := _tw()
				for dx in [6.0, -6.0, 4.0, -2.0, 0.0]:
					sh.tween_property(tw_w, "position:x", rest.x + dx, UIStyle.dur(0.03))
				sh.tween_callback(_reset_widget.bind(tw_w, tw_h))
				_cleanups.append(_reset_widget.bind(tw_w, tw_h))
		_burst("spark", start_c + dir * (0.6 if not direct else 0.55), Color("ffe08a"), 8, 36.0, 0.25)
	_cleanups.append(_reset_widget.bind(w, holder))
	if UIStyle.reduce_motion:
		w.fx_glow = Color(UIStyle.TARGET, 0.8)
		var tr := _tw()
		tr.tween_callback(impact)
		tr.tween_property(w, "fx_glow", Color(UIStyle.TARGET, 0.0), 0.15)
		tr.tween_callback(_reset_widget.bind(w, holder))
		return
	var wind := -dir.normalized() * 8.0
	var lunge := dir * 0.6
	holder.z_index = 30
	var tw := _tw()
	tw.tween_property(w, "position", wind, UIStyle.dur(0.08)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "position", lunge, UIStyle.dur(0.11)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_callback(impact)
	tw.tween_interval(UIStyle.dur(0.04))
	tw.tween_property(w, "position", Vector2.ZERO, UIStyle.dur(0.13)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_reset_widget.bind(w, holder))


func _hp(p: int, d: int) -> void:
	if d == 0:
		return
	var pl: PlayerPlate = screen.plate_of(p)
	var heal := d > 0
	_float_text(("+%d" % d) if heal else ("%d" % d), UIStyle.GOOD if heal else Color("ff6b5e"), pl.hp_anchor(), 28, 22.0, 0.7)
	pl.pulse()
	if not heal:
		_shake(pl, 5.0)


func _ap(p: int, d: int) -> void:
	if d == 0:
		return
	var pl: PlayerPlate = screen.plate_of(p)
	_float_text(("%+d AP" % d), UIStyle.COST_COLORS["ap"], pl.ap_anchor(), 17, 22.0, 0.7, true, false)


func _draw_opp(p: int, n: int) -> void:
	if UIStyle.reduce_motion:
		return
	var from: Vector2 = screen.pile_anchor(p, "draw")
	var to: Vector2 = screen.hand_anchor(p)
	for i in mini(n, 5):
		var g := CardWidget.new().setup({"hidden": true, "zone": "hand"}, "back")
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.auto_hover = false
		g.modulate.a = 0.0
		g.scale = Vector2(0.6, 0.6)
		g.position = _fx_pos(from) - g.size / 2.0
		_add_node(g)
		var dest := _fx_pos(to) - g.size / 2.0
		var tw := _tw()
		tw.tween_interval(UIStyle.dur(0.07) * i)
		tw.set_parallel(false)
		tw.tween_property(g, "modulate:a", 1.0, UIStyle.dur(0.05))
		tw.set_parallel(true)
		tw.tween_property(g, "position", dest, UIStyle.dur(0.28)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "scale", Vector2.ONE, UIStyle.dur(0.28))
		tw.tween_property(g, "modulate:a", 0.0, UIStyle.dur(0.08)).set_delay(UIStyle.dur(0.22))
		tw.chain().tween_callback(_free_node.bind(g))


## End of turn: the cards left in hand fly to the Spent pile (your own cards face up, the
## opponent's as backs from their hand). The ghosts are independent of finish_all(): a hot-seat
## seat switch right after the turn ends does not cut them off, and their destination follows the
## owner's Spent pile wherever it is drawn now.
func _discard(p: int, n: int) -> void:
	if UIStyle.reduce_motion:
		return
	var ghosts := []
	if p == screen.me():
		for g in screen.gone_hand_cards():
			ghosts.append([g["c"], g["v"]])
	else:
		for i in mini(n, 6):
			ghosts.append([screen.hand_anchor(p) + Vector2(float(i) * 14.0 - 35.0, 0), {"hidden": true, "zone": "hand"}])
	var layer: Control = screen.fx_layer
	var viewer: int = screen.me()
	var total := UIStyle.dur(0.06) * float(ghosts.size()) + UIStyle.dur(0.45)
	screen.fx_hold_until = maxi(screen.fx_hold_until, Time.get_ticks_msec() + int(total * 1000.0) + 120)
	var i := 0
	for gh in ghosts:
		var v: Dictionary = gh[1]
		var w := CardWidget.new().setup(v, "back" if v.get("hidden", false) else "hand")
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.auto_hover = false
		w.show_tooltip = false
		w.pivot_offset = w.size / 2.0
		var from: Vector2 = gh[0]
		w.position = _fx_pos(from) - w.size / 2.0
		layer.add_child(w)
		var rot := deg_to_rad(-8.0 + 4.0 * float(i % 4))
		var fly := func(k: float) -> void:
			if not is_instance_valid(w):
				return
			if screen.me() != viewer:
				w.visible = false   # the screen changed seats: never show these cards to the other seat
				return
			var to: Vector2 = screen.pile_anchor(p, "spent")
			var e2 := ease(k, -2.4)   # in-out
			w.position = _fx_pos(from.lerp(to, e2)) - w.size / 2.0
			w.scale = Vector2.ONE.lerp(Vector2(0.55, 0.55), e2)
			w.rotation = rot * e2
			w.modulate.a = 1.0 if k < 0.82 else clampf((1.0 - k) / 0.18, 0.0, 1.0)
		var tw := screen.create_tween()
		tw.tween_interval(UIStyle.dur(0.06) * i)
		tw.tween_method(fly, 0.0, 1.0, UIStyle.dur(0.45))
		tw.tween_callback(w.queue_free)
		i += 1


func _destroy(at: Dictionary, prev_mv: Dictionary) -> void:
	var p := int(at["p"])
	var zone := String(at["zone"])
	var slot := int(at["slot"])
	var rect: Rect2 = screen.fx_slot_global_rect(p, zone, slot)
	var prev_view = null
	if not prev_mv.is_empty() and ZONE_KEY.has(zone):
		var arr: Array = prev_mv["players"][p][ZONE_KEY[zone]]
		if slot < arr.size():
			prev_view = arr[slot]
	_burst("ember", rect.get_center(), Color("ff8a3a"), 8, 50.0, 0.5)
	if prev_view == null:
		return
	# The ghost is the same 2:3 card, turned like it was (Defense units, Trap/Spell zone).
	var rot: bool = zone == "backrow" or (zone == "unit" and String(prev_view.get("stance", "atk")) == "def")
	var g := CardWidget.new().setup(prev_view, ZONE_KIND[zone], "", rot)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.auto_hover = false
	g.position = _fx_pos(rect.get_center() - g.size / 2.0)
	_add_node(g)
	var tw := _tw()
	if UIStyle.reduce_motion:
		tw.tween_property(g, "modulate:a", 0.0, 0.2)
	else:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/dissolve.gdshader")
		g.material = mat
		tw.tween_method(func(v: float): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, UIStyle.dur(0.45))
	tw.tween_callback(_free_node.bind(g))


func _status(at: Dictionary, s: String, _n: int) -> void:
	var p := int(at["p"])
	var zone := String(at["zone"])
	var slot := int(at["slot"])
	var it: Dictionary = screen.fx_slot_item(p, zone, slot)
	var col := UIStyle.RUNE_BLUE if s == "rune" else (Color("6fd38a") if CardDB.is_buff(s) else Color("e8605a"))
	if not it.is_empty():
		var w: CardWidget = it["widget"]
		w.fx_glow = Color(col, 0.9)
		_cleanups.append(func(): if is_instance_valid(w): w.fx_glow = Color(1, 1, 1, 0))
		var tw := _tw()
		tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.2 if UIStyle.reduce_motion else 0.4)).set_trans(Tween.TRANS_SINE)
	var rect: Rect2 = screen.fx_slot_global_rect(p, zone, slot)
	_float_text(s.capitalize(), col.lightened(0.3), rect.get_center() + Vector2(0, -rect.size.y * 0.3), 15, 24.0, 0.7, false, false)


func _stat(at: Dictionary) -> void:
	var it: Dictionary = screen.fx_slot_item(int(at["p"]), String(at["zone"]), int(at["slot"]))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	w.fx_glow = Color(UIStyle.GOLD_HI, 0.6)
	_cleanups.append(func(): if is_instance_valid(w): w.fx_glow = Color(1, 1, 1, 0))
	var tw := _tw()
	tw.tween_property(w, "fx_glow", Color(UIStyle.GOLD_HI, 0.0), UIStyle.dur(0.3))


## Stance change (`to` = "def" | "atk"): the widget is already drawn in its final orientation, so it
## turns from the old orientation (-/+90 degrees about its centre) into place with a small scale
## bounce, a glint and a short label.
func _stance(p: int, slot: int, to: String) -> void:
	var it: Dictionary = screen.fx_slot_item(p, "unit", slot)
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	var to_def := to == "def"
	var col := Color("8ec5ff") if to_def else Color("ff9a7a")
	_cleanups.append(_reset_widget.bind(w, holder))
	var rect: Rect2 = holder.get_global_rect()
	_float_text("Defense" if to_def else "Attack", col, rect.get_center() + Vector2(0, -rect.size.y * 0.32), 15, 20.0, 0.7, false, false)
	if UIStyle.reduce_motion:
		w.fx_glow = Color(col, 0.8)
		var tr := _tw()
		tr.tween_property(w, "fx_glow", Color(col, 0.0), 0.25)
		tr.tween_callback(_reset_widget.bind(w, holder))
		return
	w.pivot_offset = w.size / 2.0
	w.rotation = -PI / 2.0 if to_def else PI / 2.0
	holder.z_index = 20
	var tw := _tw()
	tw.set_parallel(true)
	tw.tween_property(w, "rotation", 0.0, UIStyle.dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2(1.1, 1.1), UIStyle.dur(0.14)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.18)).set_delay(UIStyle.dur(0.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "fx_flash", 0.45, UIStyle.dur(0.08)).set_delay(UIStyle.dur(0.2))
	tw.tween_property(w, "fx_flash", 0.0, UIStyle.dur(0.18)).set_delay(UIStyle.dur(0.28))
	tw.tween_property(w, "fx_glow", Color(col, 0.75), UIStyle.dur(0.1)).set_delay(UIStyle.dur(0.2))
	tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.25)).set_delay(UIStyle.dur(0.3))
	tw.chain().tween_callback(_reset_widget.bind(w, holder))


## A unit / Power effect is used (triggered effect or activated ability): a gold rune ring bursts out
## of the card while it plays the summon-style flourish (pop, then a landing squash with a gold glow
## and a dust puff at its foot) and gives a short horizontal shake (~0.25 s, a few px). Unlike a
## status gain (no label, no colour code). Reduced motion: the glow only. Everything is undone by
## _reset_widget, also from finish_all().
func _trigger(at: Dictionary) -> void:
	var it: Dictionary = screen.fx_slot_item(int(at["p"]), String(at["zone"]), int(at["slot"]))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	var col := UIStyle.GOLD_HI
	_cleanups.append(_reset_widget.bind(w, holder))
	var tw := _tw()
	if UIStyle.reduce_motion:
		w.fx_glow = Color(col, 0.9)
		tw.tween_property(w, "fx_glow", Color(col, 0.0), 0.3)
		tw.tween_callback(_reset_widget.bind(w, holder))
		return
	var grect := w.get_global_rect()
	var foot := Vector2(grect.get_center().x, grect.end.y - 6.0)
	var ring := RuneRing.new()
	ring.col = col
	ring.radius = grect.size.length() * 0.5
	ring.position = _fx_pos(grect.get_center())
	_add_node(ring)
	var rt := _tw()
	rt.tween_property(ring, "t", 1.0, UIStyle.dur(0.5))
	rt.tween_callback(_free_node.bind(ring))
	holder.z_index = 20
	w.pivot_offset = w.size / 2.0
	# Opening glint on its own track so it does not hold up the sequence below.
	var fl := _tw()
	fl.tween_property(w, "fx_flash", 0.45, UIStyle.dur(0.06))
	fl.tween_property(w, "fx_flash", 0.0, UIStyle.dur(0.18))
	# Pop up, settle, then land like a summon: dust, glow, squash, shake.
	tw.tween_property(w, "scale", Vector2(1.12, 1.12), UIStyle.dur(0.09)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.12)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(_burst.bind("dust", foot, Color("c8b896"), 6, 46.0, 0.35))
	tw.set_parallel(true)
	tw.chain().tween_property(w, "scale", Vector2(0.94, 0.94), UIStyle.dur(0.05))
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.07)).set_delay(UIStyle.dur(0.05))
	tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.32)).from(Color(col, 0.8)).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_shake_x.bind(w, 5.0), 0.0, 1.0, UIStyle.dur(0.25))
	tw.chain().tween_callback(_reset_widget.bind(w, holder))


## Damped horizontal shake of a slot widget about its rest position (x = 0); `k` runs 0 -> 1.
func _shake_x(k: float, w: CardWidget, amp: float) -> void:
	if is_instance_valid(w):
		w.position.x = amp * sin(k * TAU * 3.0) * (1.0 - k)


# ---------------------------------------------------------------- spell / trap spotlight

## Queues a big centred view of a Spell/Trap that was cast or activated (fx event "spotlight").
## How long a spotlight occupies the screen (fly-in + hold + exit, before UIStyle.dur scaling);
## later effects of the same batch start once it has gone (reduced motion: ~1.24 s).
const SPOT_HOLD := 1.85


func _spotlight(e: Dictionary) -> void:
	if _spot_q.size() >= 4:
		_spot_q.pop_front()
	_spot_q.append(e)
	if not _spot_active:
		_next_spotlight()


func _next_spotlight() -> void:
	if _spot_q.is_empty():
		_spot_active = false
		return
	_spot_active = true
	_show_spotlight(_spot_q.pop_front())


func _spot_caption(e: Dictionary) -> String:
	match String(e.get("how", "cast")):
		"activate": return "Spell activated"
		"trap": return "Trap activated"
	var p := int(e.get("p", -1))
	var players: Array = screen.mv.get("players", [])
	if p >= 0 and p < players.size() and players[p] is Dictionary and String(players[p].get("name", "")) != "":
		return "%s casts" % String(players[p]["name"])
	return "Spell cast"


## Flies a big card from its origin (hand for a cast, else its slot) to the centre of the board over a
## soft dark backdrop, holds ~1 s with a caption pill above it, then shrinks and fades. Click-through;
## everything is removed by finish_all().
func _show_spotlight(e: Dictionary) -> void:
	var layer: Control = screen.banner_layer if screen.banner_layer != null else screen.fx_layer
	var inv := layer.get_global_transform().affine_inverse()
	var area: Rect2 = screen.board_global_rect()
	var centre := inv * area.get_center()
	var p := int(e.get("p", 0))
	var origin_g: Vector2 = screen.hand_anchor(p)
	if e.get("at") is Dictionary:
		var at: Dictionary = e["at"]
		var sr: Rect2 = screen.fx_slot_global_rect(int(at.get("p", p)), String(at.get("zone", "backrow")), int(at.get("slot", 0)))
		if sr.size != Vector2.ZERO:
			origin_g = sr.get_center()
	var origin := inv * origin_g
	var v: Dictionary = MatchView.summary_view(Series._card_summary(int(e["id"])))
	var accent: Color = UIStyle.CATEGORY_COLORS.get(String(v.get("category", "spell")), UIStyle.GOLD)
	# Backdrop: soft radial dark vignette over the board.
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.62))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var bd := TextureRect.new()
	bd.texture = gt
	bd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bd.stretch_mode = TextureRect.STRETCH_SCALE
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsz := Vector2(area.size.x * 1.1, area.size.y * 1.2)
	bd.size = bsz
	bd.position = centre - bsz / 2.0
	bd.modulate.a = 0.0
	bd.z_index = 95   # above lifted board cards, status glows and floating effect text
	_add_node(bd, layer)
	# The card.
	var c := CardWidget.new()
	c.show_tooltip = false
	c.auto_hover = false
	c.setup(v, "big")
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.pivot_offset = c.size / 2.0
	c.z_index = 96
	_add_node(c, layer)
	var home := centre - c.size / 2.0
	# Caption pill above the card.
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(Color(0.05, 0.04, 0.035, 0.94), accent.lightened(0.15), 2, 16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	pill.add_theme_stylebox_override("panel", sb)
	var lbl := UIStyle.label(_spot_caption(e), 18, UIStyle.TEXT, false, true)
	lbl.add_theme_font_override("font", UIStyle.font_display(700))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)
	_add_node(pill, layer)
	pill.size = pill.get_combined_minimum_size()
	pill.pivot_offset = pill.size / 2.0
	pill.position = Vector2(centre.x - pill.size.x / 2.0, home.y - pill.size.y - 12.0)
	pill.modulate.a = 0.0
	pill.z_index = 97
	var done := func():
		_free_node(bd)
		_free_node(c)
		_free_node(pill)
		_next_spotlight()
	var tw := _tw()
	if UIStyle.reduce_motion:
		c.position = home
		c.modulate.a = 0.0
		tw.set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, 0.12)
		tw.tween_property(bd, "modulate:a", 1.0, 0.12)
		tw.tween_property(pill, "modulate:a", 1.0, 0.12)
		tw.chain().tween_interval(1.0)
		tw.chain().tween_property(c, "modulate:a", 0.0, 0.12)
		tw.parallel().tween_property(bd, "modulate:a", 0.0, 0.12)
		tw.parallel().tween_property(pill, "modulate:a", 0.0, 0.12)
		tw.chain().tween_callback(done)
		return
	c.position = origin - c.size / 2.0
	c.scale = Vector2(0.32, 0.32)
	c.rotation = deg_to_rad(-10.0 if origin.x < centre.x else 10.0)
	c.modulate.a = 0.0
	pill.scale = Vector2(0.7, 0.7)
	# Fly in.
	tw.set_parallel(true)
	tw.tween_property(bd, "modulate:a", 1.0, UIStyle.dur(0.22))
	tw.tween_property(c, "modulate:a", 1.0, UIStyle.dur(0.1))
	tw.tween_property(c, "position", home, UIStyle.dur(0.34)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, UIStyle.dur(0.34)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", 0.0, UIStyle.dur(0.34)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Arrival: glint, accent glow, sparks; the caption pops in.
	tw.chain().tween_callback(func():
		_burst("spark", area.get_center(), accent.lightened(0.4), 12, 170.0, 0.45)
		c.fx_flash = 0.5
		c.fx_glow = Color(accent.lightened(0.2), 0.9))
	tw.parallel().tween_property(c, "fx_flash", 0.0, UIStyle.dur(0.25))
	tw.parallel().tween_property(c, "fx_glow", Color(accent.lightened(0.2), 0.35), UIStyle.dur(0.4))
	tw.parallel().tween_property(pill, "modulate:a", 1.0, UIStyle.dur(0.14))
	tw.parallel().tween_property(pill, "scale", Vector2.ONE, UIStyle.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold ~1 s with a slow breath so it never sits static.
	tw.chain().tween_property(c, "scale", Vector2(1.03, 1.03), UIStyle.dur(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(c, "scale", Vector2.ONE, UIStyle.dur(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Out: shrink, drop slightly and fade.
	tw.chain().tween_property(c, "scale", Vector2(0.6, 0.6), UIStyle.dur(0.24)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "modulate:a", 0.0, UIStyle.dur(0.24))
	tw.parallel().tween_property(c, "position:y", home.y + 24.0, UIStyle.dur(0.24)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(bd, "modulate:a", 0.0, UIStyle.dur(0.24))
	tw.parallel().tween_property(pill, "modulate:a", 0.0, UIStyle.dur(0.16))
	tw.chain().tween_callback(done)


# ---------------------------------------------------------------- banners

func _banner(text: String, sub: String, col: Color, flare: bool) -> void:
	if _banner_q.size() >= 3:
		_banner_q.pop_front()
	_banner_q.append({"text": text, "sub": sub, "col": col, "flare": flare})
	if not _banner_active:
		_next_banner()


func _next_banner() -> void:
	if _banner_q.is_empty():
		_banner_active = false
		return
	_banner_active = true
	var e: Dictionary = _banner_q.pop_front()
	_show_strip(String(e["text"]), String(e["sub"]), e["col"], e["flare"], 0.55)


## Short, click-through pill in the top strip (above the board) so it can never cover a zone the
## player has to pick. Slides down, holds, slides back.
func _show_strip(text: String, sub: String, col: Color, flare: bool, hold: float, final: bool = false) -> void:
	var area: Rect2 = screen.board_global_rect()
	var layer: Control = screen.banner_layer
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(Color(0.05, 0.04, 0.035, 0.92), UIStyle.GOLD, 2, 22)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	pill.add_child(row)
	var title := UIStyle.label(text, 26, col, false, true)
	title.add_theme_font_override("font", UIStyle.font_display(700))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)
	if sub != "":
		var sl := UIStyle.label(sub, 17, UIStyle.MUTED)
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sl)
	pill.reset_size()
	var lp := layer.get_global_transform().affine_inverse() * Vector2(area.get_center().x, 4.0)
	var home := Vector2(lp.x - pill.size.x / 2.0, lp.y)
	pill.position = home
	_banner_node = pill
	_add_node(pill, layer)
	pill.size = pill.get_combined_minimum_size()
	pill.position.x = lp.x - pill.size.x / 2.0
	home = pill.position
	var tw := _tw()
	if UIStyle.reduce_motion:
		pill.modulate.a = 0.0
		tw.tween_property(pill, "modulate:a", 1.0, 0.12)
		tw.tween_interval(hold)
		tw.tween_property(pill, "modulate:a", 0.0, 0.12)
	else:
		pill.position.y = home.y - 70.0
		tw.tween_property(pill, "position:y", home.y, UIStyle.dur(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if flare:
			tw.tween_callback(func(): _burst("spark", Rect2(pill.global_position, pill.size).get_center(), UIStyle.GOLD_HI, 10, 70.0, 0.4))
		tw.tween_interval(UIStyle.dur(hold))
		tw.tween_property(pill, "position:y", home.y - 70.0, UIStyle.dur(0.14)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_free_node(pill)
		_banner_node = null
		if final:
			_banner_active = false
		else:
			_next_banner())


func _game_over(winner: int) -> void:
	var won: bool = winner == screen.me()
	_banner_active = true
	_show_strip("VICTORY" if won else "DEFEAT", "", UIStyle.GOLD_HI if won else Color("e8605a"), won, 1.2, true)
