class_name FxStrike
extends FxPart
## Direct attacks and killing blows (F04-07). A direct attack winds up, lunges at the defender's
## player plate and lands with a flash, shockwave, sparks, a screen shake and a big damage number,
## all in the attacker's Type colour. When the hit takes the last HP the same strike plays as the
## lethal sequence: slow motion, a hit-stop, a big magic explosion (radial burst, light rays, flash
## to white, embers, a camera shake and a deep boom), then the F03-13 victory / defeat look.
## Lethal damage from an effect (no direct attack) gets a smaller "final blow" flourish instead.
## F12: a game-winning attack on a unit (battle damage or Pierce overflow) plays the same lethal
## sequence against the unit: slow lunge, hit-stop and explosion on the unit (its destruction shown at
## the impact), then the overflow slams into the loser's plate with the big damage number. It is only
## chosen from an authoritative batch that ends the game (game_over), so traps, prevention and a
## negated attack can never preview a win: a batch without game_over is never lethal.
##
## Presentation only: the outcome is already decided and the rules never wait for it. Everything is
## created through FxPlayer, so a click (finish_all) snaps the lot away and releases the result modal.

## Worst-case real seconds the lethal direct sequence adds before the game-end look starts.
const LETHAL_LEN := 3.4
## Seconds the final-blow flourish adds before the game-end look starts.
const FLOURISH_LEN := 1.0
## Tween speed during the lethal wind-up and lunge (slow motion), and during the hit-stop.
const SLOW_WIND := 0.5
const SLOW_LUNGE := 0.3
const HIT_STOP_SPEED := 0.04
## Real seconds the hit-stop freezes the lunge on the point of impact.
const HIT_STOP := 0.14
## Seconds from the explosion to the start of the victory / defeat look.
const BLAST_TO_END := 1.45
const FLASH_WHITE := Color(1.0, 0.98, 0.92)
## F12: seconds from the impact on a unit to its overflow damage hitting the loser's plate.
const UNIT_OVERFLOW := 0.34
## Fraction of the way to the target unit the lethal lunge travels (it stops on the card, not past it).
const UNIT_LUNGE := 0.78


# ---------------------------------------------------------------- detection (pure, testable)

## Why a log line took HP (its text, F12): "direct" for a direct attack, "battle" for battle damage or
## Pierce overflow, "" otherwise (effects, Burn). GameScreen tags each "hp" event with it as `via`.
static func hp_cause(text: String) -> String:
	if text.contains("(direct attack by "):
		return "direct"
	if text.contains(" (battle)") or text.contains(" (Pierce)"):
		return "battle"
	return ""


## The killing blow of an event batch, or {} when the batch does not end the game by damage.
## {mode: "direct" | "unit" | "effect", winner, loser, attack (event index, -1 when none in the batch),
## hp (index), d (damage dealt), e (the attack event, also when it arrived in an earlier batch), start
## (index the sequence is scheduled at), destroy (index of the target's destruction shown at the impact,
## -1) and destroy_e (that event)}.
## `prior` is the last attack event of earlier batches (F12): an attack answered in a trap window resolves
## in a later batch than its declaration, so that batch carries only the battle damage and game_over.
static func detect(events: Array, prior: Dictionary = {}) -> Dictionary:
	var over := -1
	for i in events.size():
		if String(events[i].get("k", "")) == "game_over":
			over = i
			break
	if over < 0:
		return {}
	var winner := int(events[over].get("winner", -1))
	if winner < 0 or winner > 1:
		return {}
	var loser := 1 - winner
	var hp := -1
	for i in range(over - 1, -1, -1):
		var e: Dictionary = events[i]
		if String(e.get("k", "")) == "hp" and int(e.get("p", -1)) == loser and int(e.get("d", 0)) < 0:
			hp = i
			break
	if hp < 0:
		return {}
	var info := {"mode": "effect", "winner": winner, "loser": loser, "attack": -1, "hp": hp, "d": -int(events[hp]["d"]), "start": hp, "destroy": -1}
	var via := String(events[hp].get("via", ""))
	for i in range(hp - 1, -1, -1):
		var a: Dictionary = events[i]
		if String(a.get("k", "")) == "attack" and bool(a.get("to", {}).get("direct", false)) and int(a["to"].get("p", -1)) == loser:
			info.merge({"mode": "direct", "attack": i, "e": a, "start": i}, true)
			return info
	if via != "battle" and via != "direct":
		return info
	var last := -1   # the attack this damage belongs to: the nearest one before it
	for i in range(hp - 1, -1, -1):
		if String(events[i].get("k", "")) == "attack":
			last = i
			break
	var e: Dictionary = events[last] if last >= 0 else prior
	if e.is_empty() or int(e.get("from", {}).get("p", -1)) != winner or int(e.get("to", {}).get("p", -1)) != loser:
		return info
	var direct := bool(e["to"].get("direct", false))
	if direct != (via == "direct"):
		return info
	info["mode"] = "direct" if direct else "unit"
	info["attack"] = last
	info["e"] = e
	if not direct:
		for i in range(maxi(last, 0), hp):
			var d: Dictionary = events[i]
			var at: Dictionary = d.get("at", {})
			if String(d.get("k", "")) == "destroy" and int(at.get("p", -1)) == loser and String(at.get("zone", "")) == "unit" and int(at.get("slot", -1)) == int(e["to"].get("slot", -2)):
				info["destroy"] = i
				info["destroy_e"] = d
				break
	if last >= 0:
		info["start"] = last
	elif int(info["destroy"]) >= 0:
		info["start"] = int(info["destroy"])
	return info


## Index of the HP loss that belongs to the direct attack at `ai` (the next damage to the defender
## before another attack), or -1.
static func hp_after(events: Array, ai: int) -> int:
	var dp := int(events[ai]["to"].get("p", -1))
	for i in range(ai + 1, events.size()):
		var e: Dictionary = events[i]
		if String(e.get("k", "")) == "attack":
			return -1
		if String(e.get("k", "")) == "hp" and int(e.get("p", -1)) == dp and int(e.get("d", 0)) < 0:
			return i
	return -1


## Extra seconds the game-end hold must outlast because of a killing blow `info` (from detect()).
static func hold_extra(info: Dictionary) -> float:
	if info.is_empty():
		return 0.0
	match String(info["mode"]):
		"direct":
			return LETHAL_LEN
		"unit":
			return LETHAL_LEN + UNIT_OVERFLOW
	return FLOURISH_LEN


# ---------------------------------------------------------------- direct attack

## A direct attack `e` that deals `dmg` (0 when unknown) to the defender's plate.
func direct(e: Dictionary, dmg: int) -> void:
	_run(e, dmg, {})


## The killing direct attack `e`: slow motion, explosion, then the victory / defeat presentation.
func lethal(e: Dictionary, info: Dictionary) -> void:
	_run(e, int(info["d"]), info)


## F12: the game-winning attack `e` on a unit: the lethal sequence aimed at the unit, `destroy_e` (its
## destruction, {} if it survived) shown at the impact, then the overflow damage on the loser's plate.
func lethal_unit(e: Dictionary, info: Dictionary, destroy_e: Dictionary, prev_mv: Dictionary) -> void:
	_run(e, int(info["d"]), info, {"unit": true, "destroy_e": destroy_e, "prev_mv": prev_mv})


func _run(e: Dictionary, dmg: int, info: Dictionary, extra: Dictionary = {}) -> void:
	var screen: Control = _fx.screen
	var from: Dictionary = e["from"]
	var to: Dictionary = e["to"]
	var killing := not info.is_empty()
	var it: Dictionary = screen.fx_slot_item(int(from["p"]), "unit", int(from["slot"]))
	var pl: PlayerPlate = screen.plate_of(int(to["p"]))
	var plate_c: Vector2 = pl.get_global_rect().get_center()
	var on_unit := bool(extra.get("unit", false))
	var target_c: Vector2 = plate_c
	if on_unit:
		target_c = screen.fx_slot_global_rect(int(to["p"]), "unit", int(to["slot"])).get_center()
	var w: CardWidget = null
	var holder: Control = null
	var start_c: Vector2 = screen.side_center(int(from["p"]))
	if not it.is_empty():
		w = it["widget"]
		holder = it["holder"]
		start_c = holder.get_global_rect().get_center()
	var tcol := _accent(w)
	var dir := target_c - start_c
	var reduced := UIStyle.reduce_motion
	var ctx := {"c": target_c, "col": tcol, "dmg": dmg, "pl": pl, "info": info, "plate_c": plate_c}
	ctx.merge(extra)
	if on_unit and not (extra.get("destroy_e", {}) as Dictionary).is_empty():
		# The board already shows the slot empty: the target stands as a ghost until the blow lands.
		ctx["ghost"] = _fx.hold_destroy_ghost(extra["destroy_e"], extra.get("prev_mv", {}))
	if w != null:
		_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	if reduced or w == null:
		var tr := _fx.new_tween()
		if w != null:
			w.fx_glow = Color(tcol, 0.8)
			tr.tween_property(w, "fx_glow", Color(tcol, 0.0), 0.15)
		tr.tween_callback(_impact.bind(ctx))
		if killing:
			tr.tween_interval(0.7)
			tr.tween_callback(_end_look.bind(int(info["winner"])))
		if w != null:
			tr.tween_callback(_fx.reset_widget.bind(w, holder))
		return
	holder.z_index = UiLayers.FX_CARD_FRONT
	var wind := -dir.normalized() * (28.0 if killing else 18.0)
	var lunge := dir * (UNIT_LUNGE if on_unit else (0.9 if killing else 0.86))
	var tw := _fx.new_tween()
	if killing:
		tw.tween_callback(_lethal_begin.bind(tw, ctx))
		tw.tween_property(w, "fx_offset", wind, UIStyle.dur(0.25)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(w, "scale", Vector2(1.12, 1.12), UIStyle.dur(0.25))
		tw.parallel().tween_property(w, "fx_glow", Color(tcol, 0.95), UIStyle.dur(0.25))
		tw.tween_callback(tw.set_speed_scale.bind(SLOW_LUNGE))
		tw.tween_property(w, "fx_offset", lunge, UIStyle.dur(0.3)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(w, "scale", Vector2(1.4, 1.4), UIStyle.dur(0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(_trail.bind(w, holder, tcol, 10, [-1]), 0.0, 1.0, UIStyle.dur(0.3))
		tw.tween_callback(_lethal_impact.bind(tw, ctx))
		tw.tween_interval(UIStyle.dur(0.45))
		tw.tween_property(w, "fx_offset", Vector2.ZERO, UIStyle.dur(0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.5))
		tw.parallel().tween_property(w, "fx_glow", Color(tcol, 0.0), UIStyle.dur(0.5))
	else:
		tw.tween_property(w, "fx_offset", wind, UIStyle.dur(0.16)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(w, "scale", Vector2(1.08, 1.08), UIStyle.dur(0.16))
		tw.parallel().tween_property(w, "fx_glow", Color(tcol, 0.85), UIStyle.dur(0.16))
		tw.tween_property(w, "fx_offset", lunge, UIStyle.dur(0.14)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(w, "scale", Vector2(1.25, 1.25), UIStyle.dur(0.14))
		tw.parallel().tween_method(_trail.bind(w, holder, tcol, 6, [-1]), 0.0, 1.0, UIStyle.dur(0.14))
		tw.tween_callback(_impact.bind(ctx))
		tw.tween_interval(UIStyle.dur(0.06))
		tw.tween_property(w, "fx_offset", Vector2.ZERO, UIStyle.dur(0.26)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.26))
		tw.parallel().tween_property(w, "fx_glow", Color(tcol, 0.0), UIStyle.dur(0.26))
	tw.tween_callback(_fx.reset_widget.bind(w, holder))


## Start of the lethal sequence: slow motion, a darkened table, a lock-on ring and the charge swell.
func _lethal_begin(tw: Tween, ctx: Dictionary) -> void:
	tw.set_speed_scale(SLOW_WIND)
	Sfx.play("charge", 0.0, 0.0)
	var area: Rect2 = _fx.screen.get_global_rect()
	var vig := _vignette(area.size, 0.82)
	vig.modulate.a = 0.0
	vig.position = _fx.fx_pos(area.position)
	vig.z_index = 12
	vig.z_as_relative = false
	_fx.add_node(vig)
	var tv := _fx.new_tween()
	tv.tween_property(vig, "modulate:a", 1.0, UIStyle.dur(0.5))
	tv.tween_interval(UIStyle.dur(1.3))
	tv.tween_property(vig, "modulate:a", 0.0, UIStyle.dur(0.9))
	tv.tween_callback(_fx.free_node.bind(vig))
	var ring := FxSigil.new()
	ring.kind = "arcane"
	ring.col = ctx["col"]
	ring.radius = 110.0
	ring.position = _fx.fx_pos(ctx["c"])
	_fx.add_node(ring)
	var tr := _fx.new_tween()
	tr.tween_property(ring, "t", 1.0, UIStyle.dur(1.6))
	tr.tween_callback(_fx.free_node.bind(ring))


## The lethal impact: a hit-stop freeze, then the big explosion.
func _lethal_impact(tw: Tween, ctx: Dictionary) -> void:
	tw.set_speed_scale(HIT_STOP_SPEED)
	_fx.screen.get_tree().create_timer(HIT_STOP, true, false, true).timeout.connect(func():
		if tw.is_valid():
			tw.set_speed_scale(1.0))
	_impact(ctx)
	var winner := int(ctx["info"]["winner"])
	var tl := _fx.new_tween()
	tl.tween_interval(UIStyle.dur(BLAST_TO_END + (UNIT_OVERFLOW if ctx.get("unit", false) else 0.0)) + HIT_STOP)
	tl.tween_callback(_end_look.bind(winner))


func _end_look(winner: int) -> void:
	_fx.start_game_end(winner)


## The landing of the hit (normal or lethal): flash, shockwave, sparks, shake, damage number, plate hit.
func _impact(ctx: Dictionary) -> void:
	var c: Vector2 = ctx["c"]
	var tcol: Color = ctx["col"]
	var pl: PlayerPlate = ctx["pl"]
	var killing := not (ctx["info"] as Dictionary).is_empty()
	var area: Rect2 = _fx.screen.get_global_rect()
	var reach := minf(area.size.x, area.size.y)
	if ctx.get("unit", false):
		_unit_impact(ctx, reach)
		return
	if is_instance_valid(pl):
		pl.pulse()
		_fx.shake(pl, 12.0 if killing else 9.0)
		if killing:
			pl.release_hp(false, true)   # D4: the killing blow shatters the Vial of Life
	if killing:
		Sfx.play("boom", 0.0, 0.0)
		Sfx.play("impact", 0.0, 0.0)
		_blast(FxBlast.Look.BLAST, c, tcol, reach * 0.3, 1.5)
		_fx.burst(FxBurst.Kind.SPARK, c, tcol.lightened(0.5), 36, reach * 0.42, 0.9)
		_fx.burst(FxBurst.Kind.EMBER, c, Color("ffd27a"), 40, reach * 0.34, 1.4)
		_fx.screen_flash(FLASH_WHITE, 0.68, 0.02, 0.07, c)
		_fx.camera_shake(24.0, 1.1)
		_damage_number(_number_pos(c), int(ctx["dmg"]), tcol, 132)
	else:
		Sfx.play("impact", 0.0, 0.03)
		_blast(FxBlast.Look.HIT, c, tcol, reach * 0.2, 0.6)
		_fx.burst(FxBurst.Kind.SPARK, c, tcol.lightened(0.5), 24, reach * 0.26, 0.5)
		_fx.burst(FxBurst.Kind.EMBER, c, Color("ffd27a"), 10, reach * 0.09, 0.7)
		_fx.screen_flash(FLASH_WHITE, 0.3, 0.01, 0.06, c)
		_fx.camera_shake(6.0, 0.3)
		_damage_number(_number_pos(c), int(ctx["dmg"]), tcol, 84)


## F12: the killing blow lands on the unit: its destruction, an explosion on the card, a white flash and
## a camera shake; UNIT_OVERFLOW later the excess damage slams into the loser's plate.
func _unit_impact(ctx: Dictionary, reach: float) -> void:
	var c: Vector2 = ctx["c"]
	var tcol: Color = ctx["col"]
	var de: Dictionary = ctx.get("destroy_e", {})
	var ghost = ctx.get("ghost", null)
	if ghost != null and is_instance_valid(ghost):
		_fx.free_node(ghost)
	if not de.is_empty():
		_fx.play_destroy(de, ctx.get("prev_mv", {}))
	Sfx.play("impact", 0.0, 0.0)
	_blast(FxBlast.Look.BLAST, c, tcol, reach * 0.22, 1.2)
	_fx.burst(FxBurst.Kind.SPARK, c, tcol.lightened(0.5), 30, reach * 0.3, 0.8)
	_fx.burst(FxBurst.Kind.EMBER, c, Color("ffd27a"), 26, reach * 0.22, 1.2)
	_fx.screen_flash(FLASH_WHITE, 0.6, 0.02, 0.07, c)
	_fx.camera_shake(16.0, 0.6)
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(UNIT_OVERFLOW))
	tw.tween_callback(_overflow.bind(ctx, reach))


## F12: the overflow of a game-winning attack on a unit reaching the loser's plate.
func _overflow(ctx: Dictionary, reach: float) -> void:
	var c: Vector2 = ctx["plate_c"]
	var tcol: Color = ctx["col"]
	var pl: PlayerPlate = ctx["pl"]
	if is_instance_valid(pl):
		pl.pulse()
		_fx.shake(pl, 12.0)
		pl.release_hp(false, true)   # D4: the overflow that ends the game shatters the vial
		# UI review F12: the struck plate reads above its own blast (the HP drop is the point).
		var z0 := pl.z_index
		pl.z_index = FxPlayer.STRUCK_PLATE_Z
		_fx.add_cleanup(func(): if is_instance_valid(pl): pl.z_index = z0)
		_fx.screen.get_tree().create_timer(UIStyle.dur(1.6)).timeout.connect(func(): if is_instance_valid(pl): pl.z_index = z0)
	Sfx.play("boom", 0.0, 0.0)
	_blast(FxBlast.Look.BLAST, c, tcol, reach * 0.26, 1.4)
	_fx.burst(FxBurst.Kind.SPARK, c, tcol.lightened(0.5), 30, reach * 0.36, 0.9)
	_fx.burst(FxBurst.Kind.EMBER, c, Color("ffd27a"), 34, reach * 0.3, 1.3)
	_fx.screen_flash(FLASH_WHITE, 0.62, 0.02, 0.07, c)
	_fx.camera_shake(22.0, 1.0)
	_damage_number(_number_pos(c), int(ctx["dmg"]), tcol, 132)


# ---------------------------------------------------------------- final blow from an effect

## Lethal damage that did not come from a direct attack: a smaller flourish on the losing plate.
func flourish(info: Dictionary) -> void:
	var loser := int(info["loser"])
	var pl: PlayerPlate = _fx.screen.plate_of(loser)
	var c: Vector2 = pl.get_global_rect().get_center()
	var tcol := Color("ff8a5e")
	var area: Rect2 = _fx.screen.get_global_rect()
	var reach := minf(area.size.x, area.size.y)
	pl.pulse()
	_fx.shake(pl, 12.0)
	pl.release_hp(false, true)   # D4: the final blow shatters the vial
	Sfx.play("boom", -5.0, 0.0)
	_blast(FxBlast.Look.FINAL, c, tcol, reach * 0.2, 0.95)
	_fx.burst(FxBurst.Kind.SPARK, c, tcol.lightened(0.5), 26, reach * 0.26, 0.7)
	_fx.screen_flash(FLASH_WHITE, 0.5, 0.03, 0.08, c)
	_fx.camera_shake(12.0, 0.6)
	_damage_number(_number_pos(c), int(info["d"]), tcol, 104)
	var np := _number_pos(c)
	_fx.float_text("FINAL BLOW", Color("ffe9b0"), np + Vector2(0, 78.0 if np.y > c.y else -78.0), 28, 14.0, 1.1)
	var tl := _fx.new_tween()
	tl.tween_interval(UIStyle.dur(0.8))
	tl.tween_callback(_end_look.bind(int(info["winner"])))


# ---------------------------------------------------------------- pieces

## The accent colour of the attacker: its Type colour (gold for typeless cards), brightened for glow.
func _accent(w: CardWidget) -> Color:
	var ty = null
	if w != null:
		ty = w.view.get("type", null)
	var s := String(ty) if ty != null else ""
	if s == "" or s == "Physical":
		return UIStyle.GOLD_HI if s == "" else UIStyle.type_color(s).lightened(0.3)
	return UIStyle.type_color(s).lightened(0.15)


## A FxBlast of `look` at a global point, animated over `life` s.
func _blast(look: FxBlast.Look, global_c: Vector2, col: Color, radius: float, life: float) -> void:
	if UIStyle.reduce_motion:
		return
	var b := FxBlast.new()
	b.look = look
	b.col = col
	b.radius = radius
	b.position = _fx.fx_pos(global_c)
	_fx.add_node(b)
	var tw := _fx.new_tween()
	tw.tween_property(b, "t", 1.0, UIStyle.dur(life))
	tw.tween_callback(_fx.free_node.bind(b))


## A glowing mote left behind by the lunging card for every `of`-th of its path.
func _trail(p: float, w: CardWidget, holder: Control, col: Color, steps: int, state: Array) -> void:
	if not is_instance_valid(w) or not is_instance_valid(holder):
		return
	var idx := int(p * float(steps))
	if int(state[0]) >= idx:
		return
	state[0] = idx
	var m := FxSigil.new()
	m.kind = "mote"
	m.col = col
	m.radius = 40.0 + 14.0 * p
	m.position = _fx.fx_pos(holder.get_global_rect().get_center() + w.fx_offset)
	_fx.add_node(m)
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "modulate:a", 0.0, UIStyle.dur(0.45))
	tw.tween_property(m, "scale", Vector2(0.4, 0.4), UIStyle.dur(0.45))
	tw.chain().tween_callback(_fx.free_node.bind(m))


## The big damage number for a hit on the plate at global `plate_c`, placed clear of the window edge (B5).
func big_number(plate_c: Vector2, dmg: int, col: Color, fs: int) -> void:
	_damage_number(_number_pos(plate_c), dmg, col, fs)


## Where a damage number goes for a plate at `c`: pushed toward the middle of the window so it never clips.
func _number_pos(c: Vector2) -> Vector2:
	var mid: Vector2 = _fx.screen.get_global_rect().get_center()
	return c + Vector2(130.0 if c.x < mid.x else -130.0, 90.0 if c.y < mid.y else -90.0)


## Big damage number with punch: slams in oversized, settles, then drifts up and fades.
func _damage_number(global_c: Vector2, dmg: int, col: Color, fs: int) -> void:
	if dmg <= 0:
		return
	var l := Label.new()
	l.text = "-%d" % dmg
	l.add_theme_font_override("font", UIStyle.font_display(700))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	l.add_theme_color_override("font_outline_color", col.darkened(0.35))
	l.add_theme_constant_override("outline_size", maxi(8, fs / 7))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(4, fs / 14))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := UIStyle.font_display(700).get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	l.size = Vector2(sz.x + 12.0, fs * 1.4)
	l.pivot_offset = l.size / 2.0
	var p0 := _fx.fx_pos(global_c) - l.size / 2.0
	l.position = p0
	_fx.add_text(l)   # H23: above the struck plate
	if UIStyle.reduce_motion:
		var tr := _fx.new_tween()
		tr.tween_interval(0.8)
		tr.tween_property(l, "modulate:a", 0.0, 0.3)
		tr.tween_callback(_fx.free_node.bind(l))
		return
	l.scale = Vector2(2.6, 2.6)
	l.rotation = -0.12
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, UIStyle.dur(0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "rotation", 0.0, UIStyle.dur(0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", p0.y - 54.0, UIStyle.dur(1.3)).set_delay(UIStyle.dur(0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, UIStyle.dur(0.35)).set_delay(UIStyle.dur(1.15))
	tw.chain().tween_callback(_fx.free_node.bind(l))


## A dark radial vignette sized to the window (transparent centre, dark edges).
func _vignette(sz: Vector2, strength: float) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.02, 0.0, 0.0, strength))
	g.add_point(0.45, Color(0.02, 0.0, 0.0, strength * 0.18))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = sz
	return tr
