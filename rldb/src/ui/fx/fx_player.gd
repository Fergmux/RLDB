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
const SHOCKWAVE_SHADER := "res://assets/shaders/canvas_fx_shockwave.gdshader"
## Absolute z of the set-piece vignette and distortion: above the board, below UiLayers.FX_CARD.
const VIGNETTE_Z := 12
const DISTORT_Z := 16
## A batch is compressed to fit this many seconds (spotlight holds are added afterwards).
const MAX_BATCH_TIME := 3.0
## B5: seconds a unit summoned and removed in the same batch stands (as a ghost) before it can be removed.
const TRANSIENT_HOLD := 0.55

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
var _summon := FxSummon.new(self)
var _serpent := FxSerpent.new(self)
## B5: ghosts of cards summoned and removed in the same batch, by transient_key().
var _transient := {}
## True from the moment a view that ends the game arrives until its victory / defeat presentation has
## finished (or been skipped): GameSeriesOverlay keeps the result modal back meanwhile (F03-13).
var game_end_hold := false
var _hold_gen := 0
var _cam_users := 0
var _cam_rest := {}
## F12: the last attack event seen and the game it belongs to. An attack answered in a trap window
## resolves in a later batch, which then carries only the battle damage and game_over.
var _last_attack := {}
var _last_attack_game := -1
## Mode of the last killing blow played ("direct", "unit", "effect" or ""; dev/QA verification only).
var last_lethal_mode := ""
## The schedule of the last play() call, [{t: seconds after the call, tag}] (dev/QA and tests only).
var last_plan: Array = []


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
			var safety := 8.0 + FxStrike.hold_extra(lethal_info(events))
			screen.get_tree().create_timer(safety).timeout.connect(func():
				if gen == _hold_gen:
					release_game_end_hold())
			return


## The killing blow of `events` (FxStrike.detect), with the attack of an earlier batch of this game.
func lethal_info(events: Array) -> Dictionary:
	var prior := {}
	if not _last_attack.is_empty() and screen != null and int(screen.view.get("game_no", -1)) == _last_attack_game:
		prior = _last_attack
	return FxStrike.detect(events, prior)


## Remembers the last attack of a batch for lethal_info(); a new turn or the end of a game forgets it.
func _note_attacks(events: Array) -> void:
	for e in events:
		match String(e.get("k", "")):
			"attack":
				_last_attack = e
				_last_attack_game = int(screen.view.get("game_no", -1)) if screen != null else -1
			"turn", "game_over":
				_last_attack = {}


## F12: a still ghost of the card `e` destroys, held in its slot until the killing blow lands (or null).
func hold_destroy_ghost(e: Dictionary, prev_mv: Dictionary) -> CardWidget:
	return _piles.hold_ghost(e, prev_mv)


## Shows the destruction event `e` now (with its sound); the lethal strike on a unit uses it at the impact.
func play_destroy(e: Dictionary, prev_mv: Dictionary) -> void:
	Sfx.play(Sfx.for_fx(e, screen.me()), 0.0, 0.0)
	_piles.destroy(e, prev_mv)


## B5: a ghost of the unit summoned by `summon_e`, standing in its slot until it is removed (or null).
func summon_ghost(p: int, slot: int, summon_e: Dictionary) -> CardWidget:
	return _piles.summon_ghost(p, slot, summon_e)


## A still ghost of the card destroyed by `e` in its slot (or null when it may not be shown).
func destroy_ghost(e: Dictionary, prev_mv: Dictionary) -> CardWidget:
	return _piles.destroy_ghost(e, prev_mv)


## The card view an event may show (FxPileEffects.ghost_view: public or authorised cards only).
func pile_view(e: Dictionary, prev_mv: Dictionary) -> Dictionary:
	return _piles.ghost_view(e, prev_mv)


## The big punchy damage number of the strikes for a plate at global `plate_c` (placed clear of the edge).
func damage_number(plate_c: Vector2, dmg: int, col: Color, fs: int) -> void:
	_strike.big_number(plate_c, dmg, col, fs)


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
	_transient.clear()
	_banner.reset()
	_spotlight.reset()
	_game_end.reset()
	release_game_end_hold()


# ---------------------------------------------------------------- scheduling

## Plays the events of the newly seen log entries in order. `prev_mv` is the match view
## before this update (used to draw destroyed cards that are already gone).
##
## Holds (never compressed): a Spell/Trap spotlight, a special-summon set piece (FxSummon), the arrival of
## a unit that leaves the field again in the same batch (B5, TRANSIENT_HOLD) and the Divine Serpents'
## strike (FxSerpent) each delay everything after them in the batch by their full length, so the events
## that follow (triggers, destructions, damage) always play after them, in log order.
func play(events: Array, prev_mv: Dictionary) -> void:
	if events.is_empty():
		return
	if not busy():
		_tweens.clear()
		_cleanups.clear()
	var sched: Array = []   # [time, Callable, tag]
	var holds: Array = []   # [sched index from which the hold applies, seconds]
	var t := 0.0
	var attack_end := 0.0
	var turn_in_batch := false
	for e in events:
		if e["k"] == "turn":
			turn_in_batch = true
	var fast := UIStyle.reduce_motion
	var lethal := lethal_info(events)   # F04-07 / F12: the killing blow of this batch, if it has one
	_note_attacks(events)
	var lmode := String(lethal.get("mode", ""))
	if lmode != "":
		last_lethal_mode = lmode
	var lstrike := lmode == "direct" or lmode == "unit"
	var ldestroy := int(lethal.get("destroy", -1))
	var claimed := {}   # hp event index -> true when a direct attack shows that damage itself
	var serpent := FxSerpent.detect(events)   # B5: the Divine Serpents' strike, if this batch has one
	var serpent_owned := {}   # event indices the Serpent strike shows itself (its damage and destructions)
	if not serpent.is_empty():
		_serpent.prepare(serpent)   # the struck HP bar waits for the blow
		serpent_owned[int(serpent["hp"])] = true
		for j in serpent["destroys"]:
			serpent_owned[int(j)] = true
	if not lethal.is_empty() and (serpent.is_empty() or int(serpent["hp"]) != int(lethal["hp"])):
		# D4: the loser's vial holds its value until the killing blow lands, then shatters (FxStrike).
		var lp: PlayerPlate = screen.plate_of(int(lethal["loser"]))
		if is_instance_valid(lp) and not lp.hp_held():
			# The HP before the batch (the damage can exceed what was left); else the real HP plus the blow.
			var before := lp.hp_bar.hp + int(lethal["d"])
			var pls: Array = prev_mv.get("players", [])
			if int(lethal["loser"]) < pls.size():
				before = int(pls[int(lethal["loser"])].get("hp", before))
			lp.hold_hp(before)
			add_cleanup(func() -> void: if is_instance_valid(lp): lp.release_hp(true))
	var mats := {}   # player -> material events of the special summon that follows (F03-17 / D8)
	for i in events.size():
		var e: Dictionary = events[i]
		var k := String(e["k"])
		# F12: the attack was declared in an earlier batch (trap window): the killing blow plays here.
		if lstrike and int(lethal["attack"]) < 0 and i == int(lethal["start"]):
			var st_l := maxf(t, attack_end)
			sched.append([st_l, _lethal_call(lethal, prev_mv), "lethal"])
			attack_end = st_l + (0.3 if fast else 0.9)
			t = st_l + (0.1 if fast else 0.3)
		var summon_kind := ""
		if k == "summon" and mats.has(int(e["p"])):
			summon_kind = String(mats[int(e["p"])][0].get("kind", "fusion"))
		# F02-13: each public event's sound starts with its animation (Sfx rate-limits bursts).
		var snd := Sfx.for_fx(e, screen.me())
		if summon_kind != "" or k == "material" or serpent_owned.has(i):
			snd = ""   # the set pieces play their own layered sounds
		elif k == "game_over":
			snd = ""   # FxGameEnd plays the victory / defeat sound itself
		elif k == "hp" and not lethal.is_empty() and i == int(lethal["hp"]):
			snd = ""   # the killing blow plays its own boom
		elif k == "destroy" and i == ldestroy:
			snd = ""   # F12: shown (with its sound) at the impact of the killing blow
		if snd != "":
			var st0 := maxf(t, attack_end) if k == "attack" else (t + 0.2 if k == "game_over" else t)
			sched.append([st0, Sfx.play.bind(snd, 0.0, 0.04), "sfx:" + snd])
			if k == "attack" and not e.get("to", {}).get("direct", false) and not (lmode == "unit" and i == int(lethal["attack"])):
				sched.append([st0 + (0.12 if fast else 0.26), Sfx.play.bind("impact", 0.0, 0.04), "sfx:impact"])
		match k:
			"attack":
				var st := maxf(t, attack_end)
				if bool(e["to"].get("direct", false)):
					# F04-07: a bigger direct attack; the killing one plays the slow-motion explosion.
					var hi := FxStrike.hp_after(events, i)
					var dmg := -int(events[hi]["d"]) if hi >= 0 else 0
					if hi >= 0:
						claimed[hi] = true
					if not lethal.is_empty() and int(lethal["attack"]) == i:
						sched.append([st, _strike.lethal.bind(e, lethal), "lethal"])
					else:
						sched.append([st, _strike.direct.bind(e, dmg), "direct"])
					attack_end = st + (0.3 if fast else 0.9)
					t = st + (0.1 if fast else 0.3)
				elif lmode == "unit" and int(lethal["attack"]) == i:
					sched.append([st, _lethal_call(lethal, prev_mv), "lethal"])   # F12
					attack_end = st + (0.3 if fast else 0.9)
					t = st + (0.1 if fast else 0.3)
				else:
					sched.append([st, _cards.attack.bind(e), "attack"])
					attack_end = st + (0.2 if fast else 0.46)
					t = st + (0.1 if fast else 0.2)
			"summon":
				var sp := int(e["p"])
				var sslot := int(e["slot"])
				var it: Dictionary = screen.fx_slot_item(sp, "unit", sslot)
				var gone: bool = it.is_empty() or not (it["widget"] as CardWidget).visible
				if summon_kind != "":
					# D8: the Fusion / Ritual / Arcane set piece (materials drawn in, climax, the card slams down).
					_prehide(sp, "unit", sslot, t, sched, _summon.play.bind(summon_kind, sp, sslot, mats[sp], e, prev_mv))
					sched[-1].append("set_piece:%s:%d:%d" % [summon_kind, sp, sslot])
					mats.erase(sp)
					holds.append([sched.size(), FxSummon.length_for(summon_kind)])
				elif gone and e.has("id"):
					# B5: the unit already left the field in this batch: it arrives as a ghost that stands in
					# its slot until whatever removes it plays.
					sched.append([t, _piles.summon_ghost.bind(sp, sslot, e, true), "summon_ghost:%d:%d" % [sp, sslot]])
					holds.append([sched.size(), TRANSIENT_HOLD])
				else:
					_prehide(sp, "unit", sslot, t, sched, _cards.arrive.bind(sp, "unit", sslot))
					sched[-1].append("summon:%d:%d" % [sp, sslot])
				t += 0.16
			"material":
				# Gathered into the set piece of the summon that follows (shown on their own if none does).
				var mp := int(e["p"])
				if not mats.has(mp):
					mats[mp] = []
				mats[mp].append(e)
			"sacrifice":
				# D6: the unit is consumed and its embers drift into the AP gems; the AP gain lands with them.
				sched.append([t, _piles.sacrifice.bind(e, prev_mv), "sacrifice:%d:%d" % [int(e["at"]["p"]), int(e["at"]["slot"])]])
				t += 0.0 if fast else FxPileEffects.SACRIFICE_TO_AP
			"exhaust":
				sched.append([t, _piles.exhaust.bind(e, prev_mv), "exhaust"])
				t += 0.3
			"play":
				_prehide(int(e["p"]), String(e["zone"]), int(e["slot"]), t, sched, _cards.arrive.bind(int(e["p"]), String(e["zone"]), int(e["slot"])))
				sched[-1].append("play")
				t += 0.16
			"hp":
				if serpent_owned.has(i):
					# B5: the Serpents combine and strike this damage into the plate themselves.
					var sl := lethal if (not lethal.is_empty() and i == int(lethal["hp"])) else {}
					sched.append([t, _serpent.play.bind(serpent, events, prev_mv, sl), "serpent"])
					holds.append([sched.size(), FxSerpent.length_for()])
				elif not lethal.is_empty() and i == int(lethal["hp"]):
					if String(lethal["mode"]) == "effect":
						sched.append([t, _strike.flourish.bind(lethal), "flourish"])   # smaller final-blow flourish
					# a killing direct attack shows this damage itself
				else:
					sched.append([t, _resources.hp.bind(int(e["p"]), int(e["d"]), claimed.has(i)), "hp:%d" % int(e["p"])])
				t += 0.06
			"ap":
				sched.append([t, _resources.ap.bind(int(e["p"]), int(e["d"])), "ap:%d" % int(e["p"])])
				t += 0.04
			"draw":
				if int(e["p"]) != screen.me():
					sched.append([t, _resources.draw_opp.bind(int(e["p"]), int(e["n"])), "draw"])
			"discard":
				sched.append([t, _resources.discard.bind(int(e["p"]), int(e["n"])), "discard"])
			"destroy":
				# F12: the killing blow on a unit shows it at its impact; B5: the Serpent strike shows its own.
				if i != ldestroy and not serpent_owned.has(i):
					sched.append([t, _piles.destroy.bind(e, prev_mv), "destroy:%d:%d" % [int(e["at"]["p"]), int(e["at"]["slot"])]])
					t += 0.12
			"status":
				sched.append([t, _cards.status.bind(e["at"], String(e["s"]), int(e.get("n", 1))), "status"])
				t += 0.06
			"stat":
				if e.has("from"):
					sched.append([t, _cards.effect_arrow.bind(e["from"], e["at"]), "arrow"])
					t += 0.35
				sched.append([t, _cards.stat.bind(e["at"]), "stat"])
			"stance":
				var sat: Dictionary = e["at"]
				sched.append([t, _cards.stance.bind(int(sat["p"]), int(sat["slot"]), String(e.get("to", "def"))), "stance"])
				t += 0.12
			"trigger":
				sched.append([t, _cards.trigger.bind(e["at"]), "trigger"])
				t += 0.1
			"spotlight":
				# The card is shown first; everything after it in this batch (statuses, destroys,
				# HP changes) waits until it has left the screen.
				sched.append([t, _spotlight.enqueue.bind(e), "spotlight"])
				t += 0.05
				holds.append([sched.size(), SPOT_HOLD])
			"turn":
				var mine: bool = int(e["p"]) == screen.me()
				sched.append([t, _banner.enqueue.bind("YOUR TURN" if mine else "OPPONENT'S TURN", "Turn %d" % int(e["turn"]), UIStyle.GOLD_HI if mine else Color("d8c9a8"), mine), "turn"])
			"phase":
				var ph := String(e["phase"])
				if ph in ["battle", "main2"] or (ph == "main1" and not turn_in_batch):
					sched.append([t, _banner.enqueue.bind(FxBanner.PHASE_NAMES[ph], "", Color("e8dcc0"), false), "phase"])
			"game_over":
				if lethal.is_empty():
					sched.append([t + 0.2, _game_end.start.bind(int(e["winner"])), "game_end"])
				# else: the killing blow (or the Serpent strike) starts the victory / defeat look when it has played
	# Materials whose summon never came (it failed): each is still drawn in and sent to its pile.
	for mp in mats:
		for me_ in mats[mp]:
			var gather: Vector2 = screen.side_center(int(mp))
			sched.append([t, _piles.material.bind(me_, prev_mv, gather), "material"])
			t += 0.14
	var last := 0.0
	for s in sched:
		last = maxf(last, s[0])
	var kc := 1.0 if last <= MAX_BATCH_TIME else MAX_BATCH_TIME / last
	# Holds are added after the batch compression so they always last their full time.
	var shift := 0.0
	last_plan = []
	for i in sched.size():
		while not holds.is_empty() and int(holds[0][0]) <= i:
			shift += float(holds.pop_front()[1])
		var at := (float(sched[i][0]) * kc + shift) * UIStyle.dur(1.0)
		last_plan.append({"t": at, "tag": String(sched[i][2]) if sched[i].size() > 2 else ""})
		_later(at, sched[i][1])


## The strike call for a killing blow `lethal` (mode "direct" or "unit").
func _lethal_call(lethal: Dictionary, prev_mv: Dictionary) -> Callable:
	var e: Dictionary = lethal["e"]
	if String(lethal["mode"]) == "unit":
		return _strike.lethal_unit.bind(e, lethal, lethal.get("destroy_e", {}), prev_mv)
	return _strike.lethal.bind(e, lethal)


## Starts the victory / defeat presentation for `winner` (the killing blow calls this when it is done).
func start_game_end(winner: int) -> void:
	_game_end.start(winner)


## Camera-shake equivalent (F04-07): jolts the play area (table, board, hand, arrows and effects:
## GameScreen.camera_nodes) with a decaying wobble, scaled up about the play-area centre just enough
## that its edge never shows. The sidebar, top strip, input panel and modals stay still, so the
## Game Log and the Menu never move (UI review F12). Skipped under reduced motion.
func camera_shake(amp: float, secs: float) -> void:
	if UIStyle.reduce_motion or screen == null:
		return
	var nodes: Array = screen.camera_nodes()
	var pivot: Vector2 = screen.play_area.get_center()
	var span: float = maxf(screen.play_area.size.x, 1.0)
	if _cam_users == 0:
		_cam_rest = {}
		for n in nodes:
			var c: Control = n
			_cam_rest[c] = {"pos": c.position, "scale": c.scale, "pivot": c.pivot_offset}
			c.pivot_offset = pivot - c.position      # every node scales about the same point
	_cam_users += 1
	var restore := func():
		for c in _cam_rest:
			if is_instance_valid(c):
				var r: Dictionary = _cam_rest[c]
				c.position = r["pos"]
				c.scale = r["scale"]
				c.pivot_offset = r["pivot"]
		_cam_rest = {}
	add_cleanup(func():
		_cam_users = 0
		restore.call())
	var wobble := func(p: float):
		var k := pow(1.0 - p, 2.0) * amp
		var off := Vector2(sin(p * 97.0) * k, cos(p * 83.0) * k * 0.8)
		var sc: float = 1.0 + 2.4 * k / span
		for c in _cam_rest:
			if is_instance_valid(c):
				var r: Dictionary = _cam_rest[c]
				c.position = (r["pos"] as Vector2) + off
				c.scale = Vector2(sc, sc) * (r["scale"] as Vector2)
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


## Screen-space distortion (canvas_fx_shockwave): a refracting ring expanding from `global_c` to
## `max_radius` px over `life` s with a crest push of `strength` px, plus an optional `swirl` (radians at the
## centre, easing out over `life`). It bends the board and the effects under it (it sits just under the
## other overlays). Returns the node (null under reduced motion: no distortion at all).
func distort(global_c: Vector2, max_radius: float, life: float, strength: float, swirl: float = 0.0, glint: Color = Color(1, 1, 1, 0.0)) -> ColorRect:
	if UIStyle.reduce_motion or screen == null:
		return null
	var win: Rect2 = screen.get_global_rect()
	var h := maxf(win.size.y, 1.0)
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = load(SHOCKWAVE_SHADER)
	mat.set_shader_parameter("centre", (global_c - win.position) / win.size)
	mat.set_shader_parameter("aspect", win.size.x / h)
	mat.set_shader_parameter("width", 0.05)
	mat.set_shader_parameter("swirl_radius", max_radius * 0.6 / h)
	mat.set_shader_parameter("glint", glint)
	r.material = mat
	# Over the table and the resting cards, under the card in flight (FX_CARD) and every effect drawing.
	r.z_as_relative = false
	r.z_index = DISTORT_Z
	add_node(r)
	r.position = fx_pos(win.position)
	r.size = win.size
	var tw := new_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v: float): mat.set_shader_parameter("radius", v), 0.0, max_radius / h, UIStyle.dur(life)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): mat.set_shader_parameter("strength", v), strength / h, 0.0, UIStyle.dur(life)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(v: float): mat.set_shader_parameter("width", v), 0.03, 0.09, UIStyle.dur(life))
	if swirl != 0.0:
		tw.tween_method(func(v: float): mat.set_shader_parameter("swirl", v), swirl, 0.0, UIStyle.dur(life)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(free_node.bind(r))
	return r


## A dark radial vignette over the whole window that fades in over `fade_in`, holds `hold` and fades out
## over `fade_out` (all seconds before UIStyle.dur). `strength` is the edge darkness (0..1); `tint` its colour.
func vignette(strength: float, fade_in: float, hold: float, fade_out: float, tint: Color = Color(0.02, 0.0, 0.03)) -> void:
	if screen == null:
		return
	var win: Rect2 = screen.get_global_rect()
	var g := Gradient.new()
	g.set_color(0, Color(tint, strength * 0.25))
	g.set_color(1, Color(tint, strength))
	g.add_point(0.5, Color(tint, strength * 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 256
	gt.height = 256
	var v := TextureRect.new()
	v.texture = gt
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.z_as_relative = false
	v.z_index = VIGNETTE_Z   # dims the board; the summoned card (FX_CARD) and the effects stay bright
	add_node(v)
	v.position = fx_pos(win.position)
	v.size = win.size
	v.modulate.a = 0.0
	var reduced := UIStyle.reduce_motion
	var tw := new_tween()
	tw.tween_property(v, "modulate:a", 0.6 if reduced else 1.0, UIStyle.dur(fade_in)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(UIStyle.dur(hold))
	tw.tween_property(v, "modulate:a", 0.0, UIStyle.dur(fade_out)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(free_node.bind(v))


## B5: a ghost standing in for a card that was summoned and left the field in the same batch (the board
## already shows its slot empty). `key` is transient_key(p, zone, slot); the destruction takes it back.
func hold_transient(key: String, ghost: CardWidget) -> void:
	_transient[key] = ghost


## Takes (and forgets) the ghost held for `key`, or null.
func take_transient(key: String) -> CardWidget:
	var g = _transient.get(key, null)
	_transient.erase(key)
	return g if g != null and is_instance_valid(g) else null


## The key of a board slot in the transient registry.
static func transient_key(p: int, zone: String, slot: int) -> String:
	return "%d:%s:%d" % [p, zone, slot]


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
		w.fx_offset = Vector2.ZERO
		w.position = Vector2.ZERO   # the slot anchor; a hovered card re-applies its lift about it (F02)
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
