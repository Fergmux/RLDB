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
var _piles := FxPileEffects.new(self)
var _game_end := FxGameEnd.new(self)
var _strike := FxStrike.new(self)
## True from the moment a view that ends the game arrives until its victory / defeat presentation has
## finished (or been skipped): GameSeriesOverlay keeps the result modal back meanwhile (F03-13).
var game_end_hold := false
var _hold_gen := 0
var _cam_users := 0
var _cam_rest := {}


## True while any effect, banner or spotlight is still running.
func busy() -> bool:
	for t in _tweens:
		if t is Tween and t.is_valid() and t.is_running():
			return true
	return _banner.is_active() or _spotlight.is_active() or _game_end.is_active()


## Called by the screen with the events of a NEW view before it renders: when they end the game the
## result modal waits for the victory / defeat presentation. Safety net: released after 8 s regardless
## (plus the extra seconds a killing-blow sequence adds, F04-07).
func expect_game_end(events: Array) -> void:
	for e in events:
		if String(e.get("k", "")) == "game_over":
			game_end_hold = true
			_hold_gen += 1
			var gen := _hold_gen
			var safety := 8.0 + FxStrike.hold_extra(FxStrike.detect(events))
			screen.get_tree().create_timer(safety).timeout.connect(func():
				if gen == _hold_gen:
					release_game_end_hold())
			return


## Lets the result modal appear (idempotent).
func release_game_end_hold() -> void:
	if not game_end_hold:
		return
	game_end_hold = false
	_hold_gen += 1
	if screen != null and screen.overlays != null:
		screen.overlays.render()


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
	_game_end.reset()
	release_game_end_hold()


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
	var lethal := FxStrike.detect(events)   # F04-07: the killing blow of this batch, if it has one
	var claimed := {}   # hp event index -> true when a direct attack shows that damage itself
	var special := {}   # player -> kind of the special summon whose materials were just shown
	for i in events.size():
		var e: Dictionary = events[i]
		# F03-17: a Fusion / Ritual / Arcane summon waits for its materials to be drawn in.
		var summon_kind := ""
		if e["k"] == "summon" and special.has(int(e["p"])):
			summon_kind = String(special[int(e["p"])])
			special.erase(int(e["p"]))
			t += 0.55
		# F02-13: each public event's sound starts with its animation (Sfx rate-limits bursts).
		var snd := Sfx.for_fx(e, screen.me())
		if summon_kind != "":
			snd = FxPileEffects.KIND_SOUND[summon_kind]
		elif e["k"] == "game_over":
			snd = ""   # FxGameEnd plays the victory / defeat sound itself
		elif e["k"] == "hp" and not lethal.is_empty() and i == int(lethal["hp"]):
			snd = ""   # the killing blow plays its own boom
		if snd != "":
			var st0 := maxf(t, attack_end) if e["k"] == "attack" else (t + 0.2 if e["k"] == "game_over" else t)
			sched.append([st0, Sfx.play.bind(snd, 0.0, 0.04)])
			if e["k"] == "attack" and not e.get("to", {}).get("direct", false):
				sched.append([st0 + (0.12 if fast else 0.26), Sfx.play.bind("impact", 0.0, 0.04)])
		match String(e["k"]):
			"attack":
				var st := maxf(t, attack_end)
				if bool(e["to"].get("direct", false)):
					# F04-07: a bigger direct attack; the killing one plays the slow-motion explosion.
					var hi := FxStrike.hp_after(events, i)
					var dmg := -int(events[hi]["d"]) if hi >= 0 else 0
					if hi >= 0:
						claimed[hi] = true
					if not lethal.is_empty() and int(lethal["attack"]) == i:
						sched.append([st, _strike.lethal.bind(e, lethal)])
					else:
						sched.append([st, _strike.direct.bind(e, dmg)])
					attack_end = st + (0.3 if fast else 0.9)
					t = st + (0.1 if fast else 0.3)
				else:
					sched.append([st, _cards.attack.bind(e)])
					attack_end = st + (0.2 if fast else 0.46)
					t = st + (0.1 if fast else 0.2)
			"summon":
				var arrive_fn: Callable = _cards.arrive.bind(int(e["p"]), "unit", int(e["slot"]))
				if summon_kind != "":
					arrive_fn = _piles.arrive_special.bind(int(e["p"]), int(e["slot"]), summon_kind)
				_prehide(int(e["p"]), "unit", int(e["slot"]), t, sched, arrive_fn)
				t += 0.16
			"material":
				# Gather point: the slot of the summon that follows in this batch (else the unit block).
				var mp := int(e["p"])
				var gather: Vector2 = screen.side_center(mp)
				for j in range(i + 1, events.size()):
					if events[j]["k"] == "summon" and int(events[j]["p"]) == mp:
						gather = screen.fx_slot_global_rect(mp, "unit", int(events[j]["slot"])).get_center()
						break
				special[mp] = String(e.get("kind", "fusion"))
				sched.append([t, _piles.material.bind(e, prev_mv, gather)])
				t += 0.14
			"exhaust":
				sched.append([t, _piles.exhaust.bind(e, prev_mv)])
				t += 0.3
			"play":
				_prehide(int(e["p"]), String(e["zone"]), int(e["slot"]), t, sched, _cards.arrive.bind(int(e["p"]), String(e["zone"]), int(e["slot"])))
				t += 0.16
			"hp":
				if not lethal.is_empty() and i == int(lethal["hp"]):
					if String(lethal["mode"]) == "effect":
						sched.append([t, _strike.flourish.bind(lethal)])   # smaller final-blow flourish
					# a killing direct attack shows this damage itself
				else:
					sched.append([t, _resources.hp.bind(int(e["p"]), int(e["d"]), claimed.has(i))])
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
				sched.append([t, _piles.destroy.bind(e, prev_mv)])
				t += 0.12
			"status":
				sched.append([t, _cards.status.bind(e["at"], String(e["s"]), int(e.get("n", 1)))])
				t += 0.06
			"stat":
				if e.has("from"):
					sched.append([t, _cards.effect_arrow.bind(e["from"], e["at"])])
					t += 0.35
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
				if lethal.is_empty():
					sched.append([t + 0.2, _game_end.start.bind(int(e["winner"]))])
				# else: the killing blow starts the victory / defeat look when it has played
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


## Starts the victory / defeat presentation for `winner` (the killing blow calls this when it is done).
func start_game_end(winner: int) -> void:
	_game_end.start(winner)


## Camera-shake equivalent (F04-07): jolts the whole screen node (board, sidebar and hand) with a decaying
## wobble, scaled up just enough that the window edge never shows. Skipped under reduced motion.
func camera_shake(amp: float, secs: float) -> void:
	if UIStyle.reduce_motion or screen == null:
		return
	var n: Control = screen
	if _cam_users == 0:
		_cam_rest = {"pos": n.position, "scale": n.scale, "pivot": n.pivot_offset}
		n.pivot_offset = n.size / 2.0
	_cam_users += 1
	var restore := func():
		if is_instance_valid(n) and not _cam_rest.is_empty():
			n.position = _cam_rest["pos"]
			n.scale = _cam_rest["scale"]
			n.pivot_offset = _cam_rest["pivot"]
	add_cleanup(func():
		_cam_users = 0
		restore.call())
	var wobble := func(p: float):
		if not is_instance_valid(n):
			return
		var k := pow(1.0 - p, 2.0) * amp
		n.position = _cam_rest["pos"] + Vector2(sin(p * 97.0) * k, cos(p * 83.0) * k * 0.8)
		var sc: float = 1.0 + 2.4 * k / maxf(n.size.x, 1.0)
		n.scale = Vector2(sc, sc) * (_cam_rest["scale"] as Vector2)
	var tw := new_tween()
	tw.tween_method(wobble, 0.0, 1.0, UIStyle.dur(secs))
	tw.tween_callback(func():
		_cam_users = maxi(_cam_users - 1, 0)
		if _cam_users == 0:
			restore.call())


## Full-window colour flash: rises to `peak` alpha, holds, then fades (capped and slowed under reduced motion).
func screen_flash(col: Color, peak: float, hold: float, fade: float, origin: Vector2 = Vector2(-1.0e6, 0.0)) -> void:
	var layer: Control = screen.banner_layer if screen.banner_layer != null else screen.fx_layer
	# A radial flash from `origin` (global; the window centre by default), never fully opaque.
	var win: Rect2 = screen.get_global_rect()
	var o: Vector2 = win.get_center() if origin.x < -1.0e5 else origin
	var g := Gradient.new()
	g.set_color(0, Color(col, 1.0))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.3, Color(col, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rad := win.size.length() * 0.9
	r.size = Vector2(rad, rad) * 2.0
	var ladd := CanvasItemMaterial.new()
	ladd.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = ladd
	r.z_index = UiLayers.SCREEN_FLASH
	r.modulate.a = 0.0
	add_node(r, layer)
	r.position = layer.get_global_transform().affine_inverse() * o - r.size / 2.0
	var reduced := UIStyle.reduce_motion
	peak = minf(peak, 0.68)
	var tw := new_tween()
	tw.tween_property(r, "modulate:a", minf(peak, 0.3) if reduced else peak, 0.2 if reduced else UIStyle.dur(0.03))
	tw.tween_interval(UIStyle.dur(hold))
	tw.tween_property(r, "modulate:a", 0.0, UIStyle.dur(fade) * (1.5 if reduced else 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(free_node.bind(r))


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
