class_name FxPlayer
extends Node
## Presentation-only effects driven by the public `fx` events of NEW log entries
## (art bible section 6). It never sends commands and never owns state: the board is
## already rendered in its final state, effects animate overlays or transient offsets on
## top of it. Any click calls finish_all(), which snaps everything back to the final state.
##
## FxPlayer schedules the events and owns the shared bookkeeping (tweens, cleanups, hidden
## widgets, overlay nodes). The effects themselves live in components that create everything
## through the public helpers below, so finish_all() cleans them all: FxCardEffects,
## FxResourceEffects, FxSpotlight and FxBanner.
##
## Host contract (GameScreen): fx_layer, banner_layer, me(), fx_slot_item(p, zone, slot),
## fx_slot_global_rect(p, zone, slot), plate_of(p), hand_anchor(p), board_global_rect().

## Seconds one Spell/Trap spotlight occupies the screen (see FxSpotlight.HOLD).
const SPOT_HOLD := FxSpotlight.HOLD
## A batch is compressed to fit this many seconds (spotlight holds are added afterwards).
const MAX_BATCH_TIME := 3.0

## The host screen (GameScreen) that owns the layers and answers the host contract.
var screen: GameScreen

var _tweens: Array = []
var _cleanups: Array = []
var _hidden: Array = []
var _nodes: Array = []
var _cards := FxCardEffects.new(self)
var _resources := FxResourceEffects.new(self)
var _spotlight := FxSpotlight.new(self)
var _banner := FxBanner.new(self)


## True while any effect, banner or spotlight is still running.
func busy() -> bool:
	for t in _tweens:
		if t is Tween and t.is_valid() and t.is_running():
			return true
	return _banner.is_active() or _spotlight.is_active()


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
	_banner.reset()
	_spotlight.reset()


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
				sched.append([st, _cards.attack.bind(e)])
				attack_end = st + (0.2 if fast else 0.46)
				t = st + (0.1 if fast else 0.2)
			"summon":
				_prehide(int(e["p"]), "unit", int(e["slot"]), t, sched, _cards.arrive.bind(int(e["p"]), "unit", int(e["slot"])))
				t += 0.16
			"play":
				_prehide(int(e["p"]), String(e["zone"]), int(e["slot"]), t, sched, _cards.arrive.bind(int(e["p"]), String(e["zone"]), int(e["slot"])))
				t += 0.16
			"hp":
				sched.append([t, _resources.hp.bind(int(e["p"]), int(e["d"]))])
				t += 0.06
			"ap":
				sched.append([t, _resources.ap.bind(int(e["p"]), int(e["d"]))])
				t += 0.04
			"draw":
				if int(e["p"]) != screen.me():
					sched.append([t, _resources.draw_opp.bind(int(e["p"]), int(e["n"]))])
			"discard":
				sched.append([t, _resources.discard.bind(int(e["p"]), int(e["n"]))])
			"destroy":
				sched.append([t, _cards.destroy.bind(e["at"], prev_mv)])
				t += 0.12
			"status":
				sched.append([t, _cards.status.bind(e["at"], String(e["s"]), int(e.get("n", 1)))])
				t += 0.06
			"stat":
				sched.append([t, _cards.stat.bind(e["at"])])
			"stance":
				var sat: Dictionary = e["at"]
				sched.append([t, _cards.stance.bind(int(sat["p"]), int(sat["slot"]), String(e.get("to", "def")))])
				t += 0.12
			"trigger":
				sched.append([t, _cards.trigger.bind(e["at"])])
				t += 0.1
			"spotlight":
				# The card is shown first; everything after it in this batch (statuses, destroys,
				# HP changes) waits until it has left the screen.
				sched.append([t, _spotlight.enqueue.bind(e)])
				t += 0.05
				spot_marks.append(sched.size())
			"turn":
				var mine: bool = int(e["p"]) == screen.me()
				sched.append([t, _banner.enqueue.bind("YOUR TURN" if mine else "OPPONENT'S TURN", "Turn %d" % int(e["turn"]), UIStyle.GOLD_HI if mine else Color("d8c9a8"), mine)])
			"phase":
				var ph := String(e["phase"])
				if ph in ["battle", "main2"] or (ph == "main1" and not turn_in_batch):
					sched.append([t, _banner.enqueue.bind(FxBanner.PHASE_NAMES[ph], "", Color("e8dcc0"), false)])
			"game_over":
				sched.append([t + 0.2, _banner.show_game_over.bind(int(e["winner"]))])
	var last := 0.0
	for s in sched:
		last = maxf(last, s[0])
	var k := 1.0 if last <= MAX_BATCH_TIME else MAX_BATCH_TIME / last
	# Spotlight holds are added after the batch compression so they always last their full time.
	var shift := 0.0
	for i in sched.size():
		while not spot_marks.is_empty() and spot_marks[0] <= i:
			spot_marks.pop_front()
			shift += SPOT_HOLD
		_later((float(sched[i][0]) * k + shift) * UIStyle.dur(1.0), sched[i][1])


## Runs `fn` after `delay` seconds (at once when the delay is negligible), on a tracked tween.
func _later(delay: float, fn: Callable) -> void:
	if delay <= 0.001:
		fn.call()
		return
	var t := new_tween()
	t.tween_interval(delay)
	t.tween_callback(fn)


## Hides the widget about to arrive until its scheduled time, then queues `fn` at `t`.
func _prehide(p: int, zone: String, slot: int, t: float, sched: Array, fn: Callable) -> void:
	var it: Dictionary = screen.fx_slot_item(p, zone, slot)
	if not it.is_empty() and t > 0.02:
		var w: CardWidget = it["widget"]
		w.modulate.a = 0.0
		_hidden.append(w)
	sched.append([t, fn])


# ---------------------------------------------------------------- helpers for the components

## A tween on the host screen that finish_all() will kill.
func new_tween() -> Tween:
	var t := screen.create_tween()
	_tweens.append(t)
	return t


## Registers `fn` to run from finish_all() (resets transient widget offsets).
func add_cleanup(fn: Callable) -> void:
	_cleanups.append(fn)


## Forgets that `w` was pre-hidden (its arrival effect now owns its alpha).
func unhide(w: CardWidget) -> void:
	_hidden.erase(w)


## Converts a global position into fx_layer coordinates.
func fx_pos(global: Vector2) -> Vector2:
	return screen.fx_layer.get_global_transform().affine_inverse() * global


## Adds an overlay node to `layer` (default: the fx layer); finish_all() frees it.
func add_node(n: Control, layer: Control = null) -> void:
	(layer if layer != null else screen.fx_layer).add_child(n)
	_nodes.append(n)


## Frees an overlay node added with add_node().
func free_node(n: Node) -> void:
	_nodes.erase(n)
	if is_instance_valid(n):
		n.queue_free()


## Floating outlined label at a global position: pops, rises `rise` px over `life` s and fades.
func float_text(text: String, col: Color, global_pos: Vector2, fs: int, rise: float, life: float, display: bool = true, pop: bool = true) -> void:
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
	var p0 := fx_pos(global_pos) - l.size / 2.0
	l.position = p0
	add_node(l)
	var reduced := UIStyle.reduce_motion
	if not reduced and pop:
		l.scale = Vector2(1.3, 1.3)
	var tw := new_tween()
	if reduced:
		tw.tween_interval(life * 0.7)
		tw.tween_property(l, "modulate:a", 0.0, life * 0.3)
	else:
		tw.set_parallel(true)
		tw.tween_property(l, "scale", Vector2.ONE, UIStyle.dur(0.09))
		tw.tween_property(l, "position:y", p0.y - rise, UIStyle.dur(life)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, UIStyle.dur(0.25)).set_delay(UIStyle.dur(life - 0.25))
	tw.chain().tween_callback(free_node.bind(l))


## Particle burst of `kind` centred on a global position, animated over `life` s (skipped under reduced motion).
func burst(kind: FxBurst.Kind, global_center: Vector2, col: Color, count: int, radius: float, life: float) -> void:
	if UIStyle.reduce_motion:
		return
	var b := FxBurst.new()
	b.kind = kind
	b.col = col
	b.count = count
	b.radius = radius
	b.size = Vector2(4, 4)
	b.position = fx_pos(global_center)
	add_node(b)
	var tw := new_tween()
	tw.tween_property(b, "t", 1.0, UIStyle.dur(life))
	tw.tween_callback(free_node.bind(b))


## Puts a slot widget and its holder back to their rest state (no offset, scale, glow or lift).
func reset_widget(w: CardWidget, holder: Control) -> void:
	if is_instance_valid(w):
		w.position = Vector2.ZERO
		w.scale = Vector2.ONE
		w.rotation = 0.0
		w.modulate = Color.WHITE
		w.fx_flash = 0.0
		w.fx_glow = FxCardEffects.NO_GLOW
	if is_instance_valid(holder):
		holder.z_index = 0


## Damped horizontal shake of `node` about its current position (skipped under reduced motion).
func shake(node: Control, amp: float) -> void:
	if UIStyle.reduce_motion:
		return
	var rest := node.position
	add_cleanup(func(): if is_instance_valid(node): node.position = rest)
	var tw := new_tween()
	for dx in [amp, -amp, amp * 0.6, -amp * 0.3, 0.0]:
		tw.tween_property(node, "position:x", rest.x + dx, UIStyle.dur(0.03))
	tw.tween_callback(func(): if is_instance_valid(node): node.position = rest)
