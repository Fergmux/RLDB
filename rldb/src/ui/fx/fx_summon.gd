class_name FxSummon
extends FxPart
## Fusion / Ritual / Arcane summon set pieces (D8, owner feedback 2026-10-20). Each one is a staged
## sequence of about 1.7-1.9 s with its own look and sound, keeping the F03-17 themes:
##   anticipation: the board dims under a vignette, the materials are drawn in (Fusion: they spiral into
##                 a vortex that twists the board; Ritual: a rune circle inscribes itself and the runes are
##                 drawn out of the tributed units as they burn away; Arcane: the spent materials rise as
##                 spectral shards and assemble into a crystalline lattice) while a charge gathers;
##   climax:       a flash, a refracting shockwave, a camera shake, light rays and particles (Ritual: a
##                 pillar of light; Arcane: the lattice bursts; Fusion: the core implodes and explodes);
##   resolution:   the card drops into its slot with a squash-and-stretch slam, dust and a fading glow.
## Reduced motion plays a calm variant (no shake, distortion, particles or flight: fades and glows).
##
## Presentation only. Everything is created through FxPlayer, so a click (finish_all) snaps it away and
## the board shows its real state. FxPlayer.play() schedules it and holds the rest of the batch for
## length_for(kind), so the events after the summon (its triggers, a trap) wait for the landing.

## Seconds of each set piece and of its climax (before UIStyle.dur).
const LEN := {"fusion": 1.7, "ritual": 1.9, "arcane": 1.75}
const CLIMAX := {"fusion": 0.78, "ritual": 0.88, "arcane": 0.82}
## Seconds of the calm (reduced motion) variant.
const CALM_LEN := 0.75
## The card falls this long after the climax and lands (the slam) at climax + DROP_DELAY + DROP_TIME.
const DROP_DELAY := 0.04
const DROP_TIME := 0.16
## Sounds: the anticipation layer, the climax hit and the landing slam.
const SOUND_CHARGE := {"fusion": "fusion_vortex", "ritual": "ritual_choir", "arcane": "arcane_shimmer"}
const SOUND_CLIMAX := {"fusion": "fusion_impact", "ritual": "ritual_impact", "arcane": "arcane_impact"}
const SOUND_SLAM := "card_slam"
const DUST := Color("d8c7a0")
## Set-piece colours per kind, [main, accent], keeping the category themes: Fusion royal blue and violet,
## Ritual violet with gold light, Arcane spectral silver-cyan (the Arcane category grey would read flat).
const PALETTE := {
	"fusion": [Color("4f7dff"), Color("a46bff")],
	"ritual": [Color("a35cff"), Color("ffcf6b")],
	"arcane": [Color("46b4ff"), Color("bfe6ff")],
}


## The main colour of the set piece of `kind`.
static func color_of(kind: String) -> Color:
	return (PALETTE.get(kind, PALETTE["fusion"]) as Array)[0]


## The accent colour of the set piece of `kind`.
static func accent_of(kind: String) -> Color:
	return (PALETTE.get(kind, PALETTE["fusion"]) as Array)[1]


## Seconds the set piece of `kind` holds the rest of its batch (reduced motion: the calm variant).
static func length_for(kind: String) -> float:
	if UIStyle.reduce_motion:
		return CALM_LEN
	return float(LEN.get(kind, 1.7))


## Seconds from the start to the slam of the landing card.
static func land_time(kind: String) -> float:
	return float(CLIMAX.get(kind, 0.8)) + DROP_DELAY + DROP_TIME


## Plays the set piece of `kind` for the unit special-summoned into player `p`'s unit `slot`.
## `mats` are the material events of the summon (FxPileEffects.material shapes), `summon_e` the summon
## event (its `id` draws a ghost when the unit has already left the field again), `prev_mv` the view
## before the batch.
func play(kind: String, p: int, slot: int, mats: Array, summon_e: Dictionary, prev_mv: Dictionary) -> void:
	var screen: Control = _fx.screen
	var it: Dictionary = screen.fx_slot_item(p, "unit", slot)
	if it.is_empty():
		return
	var rect: Rect2 = screen.fx_slot_global_rect(p, "unit", slot)
	var centre := rect.get_center()
	var col := color_of(kind)
	var target := _landing_target(it, p, slot, summon_e)
	var reduced := UIStyle.reduce_motion
	if reduced:
		_calm(kind, mats, target, centre, col, prev_mv)
		return
	var life := float(LEN.get(kind, 1.7))
	var climax := float(CLIMAX.get(kind, 0.8))
	var win: Rect2 = screen.get_global_rect()
	var reach := clampf(minf(win.size.x, win.size.y) * 0.22, 140.0, 250.0)
	Sfx.play(String(SOUND_CHARGE[kind]), -2.0, 0.0)
	_fx.vignette(0.78, 0.28, climax + 0.15, 0.6)
	# The drawn magic: on the table, under the card in flight.
	var art := FxSummonArt.new()
	art.kind = kind
	art.col = col
	art.col2 = accent_of(kind)
	art.radius = reach
	art.life = life
	art.climax = climax
	art.position = _fx.fx_pos(centre)
	art.z_as_relative = false
	art.z_index = FxPlayer.DISTORT_Z + 2
	var srcs := PackedVector2Array()
	for m in mats:
		srcs.append(_mat_origin(m, p) - centre)
	art.sources = srcs
	_fx.add_node(art)
	var ta := _fx.new_tween()
	ta.tween_property(art, "t", 1.0, UIStyle.dur(life))
	ta.tween_callback(_fx.free_node.bind(art))
	# The materials.
	var i := 0
	for m in mats:
		match kind:
			"fusion": _spiral_in(m, p, centre, col, climax - 0.08, float(i) * 0.05, prev_mv)
			"ritual": _burn_away(m, p, col, climax, float(i) * 0.06, prev_mv)
			_: _shatter_up(m, p, col, float(i) * 0.05, prev_mv)
		i += 1
	if kind == "fusion":
		# The vortex twists the board around the slot while it winds up, then lets go at the climax.
		var sw := _fx.new_tween()
		sw.tween_interval(UIStyle.dur(0.1))
		sw.tween_callback(func(): _fx.distort(centre, reach * 1.6, climax - 0.1, 0.0, 2.6))
	# Climax and landing.
	var tc := _fx.new_tween()
	tc.tween_interval(UIStyle.dur(climax))
	tc.tween_callback(_climax.bind(kind, centre, col, reach))
	_land(target, centre, rect, col, reach, climax)


## The widget the summoned card lands as: the real slot widget, or (B5) a ghost of the summoned card when
## the unit already left the field in this batch; the ghost then waits for its destruction.
func _landing_target(it: Dictionary, p: int, slot: int, summon_e: Dictionary) -> Dictionary:
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	if w.visible:
		_fx.unhide(w)
		w.modulate.a = 0.0
		_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
		return {"w": w, "holder": holder, "ghost": false}
	var g := _fx.summon_ghost(p, slot, summon_e)
	if g == null:
		return {}
	g.modulate.a = 0.0
	return {"w": g, "holder": null, "ghost": true}


## Global point a material comes from: its board slot, else the pile / hand it left.
func _mat_origin(m: Dictionary, p: int) -> Vector2:
	var at = m.get("at", {})
	if at is Dictionary and not (at as Dictionary).is_empty():
		var sr: Rect2 = _fx.screen.fx_slot_global_rect(int(at["p"]), String(at["zone"]), int(at["slot"]))
		if sr.size != Vector2.ZERO:
			return sr.get_center()
	var from := String(m.get("from", "spent"))
	return _fx.screen.hand_anchor(p) if from == "hand" else _fx.screen.pile_anchor(p, from)


## A material's card ghost (identity rule of FxPileEffects.ghost_view), placed centred on `at_g`.
func _mat_ghost(m: Dictionary, prev_mv: Dictionary, at_g: Vector2) -> CardWidget:
	var g := CardWidget.new()
	g.show_tooltip = false
	g.auto_hover = false
	g.setup(_fx.pile_view(m, prev_mv), "board")
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.pivot_offset = g.size / 2.0
	g.position = _fx.fx_pos(at_g - g.size / 2.0)
	_fx.add_node(g)
	return g


## The mote that carries a consumed material on to the pile it really went to (Spent or Exhaust).
func _to_pile(m: Dictionary, p: int, from_g: Vector2, col: Color) -> void:
	var dest := String(m.get("to", "spent"))
	var pile_g: Vector2 = _fx.screen.pile_anchor(p, dest)
	var mc := FxPileEffects.VOID if dest == "exhaust" else col
	var mo := FxSigil.new()
	mo.kind = "mote"
	mo.col = mc
	mo.radius = 10.0
	mo.position = _fx.fx_pos(from_g)
	_fx.add_node(mo)
	var mt := _fx.new_tween()
	mt.tween_property(mo, "position", _fx.fx_pos(pile_g), UIStyle.dur(0.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mt.tween_callback(func():
		_fx.burst(FxBurst.Kind.SPARK, pile_g, mc.lightened(0.25), 8, 30.0, 0.3)
		_fx.free_node(mo))


## Fusion: the material lifts, glows, then spirals into the vortex (shrinking, spinning) and is consumed.
func _spiral_in(m: Dictionary, p: int, centre: Vector2, col: Color, secs: float, delay: float, prev_mv: Dictionary) -> void:
	var origin := _mat_origin(m, p)
	var g := _mat_ghost(m, prev_mv, origin)
	g.fx_glow = Color(col, 0.0)
	var arm := origin - centre
	var turns := 1.15 + 0.2 * float(int(delay * 100.0) % 3)
	var path := func(k: float) -> void:
		if not is_instance_valid(g):
			return
		var e := FxSummonArt._in(k, 1.35)
		var ang := e * TAU * turns
		var rad := arm.rotated(ang) * (1.0 - e)
		var pos := centre + Vector2(rad.x, rad.y * (0.62 + 0.38 * (1.0 - e)))
		g.position = _fx.fx_pos(pos - g.size / 2.0)
		var sc := lerpf(1.05, 0.2, e)
		g.scale = Vector2(sc, sc)
		g.rotation = e * 5.5
		g.modulate.a = 1.0 - _sq(clampf((k - 0.8) / 0.2, 0.0, 1.0))
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(delay))
	tw.tween_property(g, "fx_glow", Color(col, 0.95), UIStyle.dur(0.12))
	tw.parallel().tween_property(g, "scale", Vector2(1.08, 1.08), UIStyle.dur(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(path, 0.0, 1.0, UIStyle.dur(maxf(secs - delay - 0.12, 0.2)))
	tw.tween_callback(func():
		_fx.burst(FxBurst.Kind.SPARK, centre, col.lightened(0.4), 10, 46.0, 0.3)
		_to_pile(m, p, centre, col)
		_fx.free_node(g))


## Ritual: the tributed card stands, trembles and burns away in the kind colour while its runes are drawn
## out into the circle (FxSummonArt draws them flying from this card).
func _burn_away(m: Dictionary, p: int, col: Color, climax: float, delay: float, prev_mv: Dictionary) -> void:
	var origin := _mat_origin(m, p)
	var from_hand := String(m.get("from", "")) == "hand"
	var g := _mat_ghost(m, prev_mv, origin)
	var base := g.position
	g.fx_glow = Color(col, 0.0)
	var mat := FxPileEffects.burn_material(g, accent_of("ritual"), Color(0.12, 0.03, 0.18), Color(1.0, 0.97, 0.9))
	FxPileEffects.burn_step(0.0, g, mat)
	var lift := Vector2(0, -60.0 if from_hand else -14.0)
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(delay))
	tw.tween_property(g, "fx_glow", Color(col, 1.0), UIStyle.dur(0.15))
	tw.parallel().tween_property(g, "position", base + lift, UIStyle.dur(0.3)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(k: float):
		if is_instance_valid(g):
			g.rotation = sin(k * TAU * 5.0) * 0.035 * (1.0 - k), 0.0, 1.0, UIStyle.dur(0.4))
	tw.tween_method(FxPileEffects.burn_step.bind(g, mat), 0.0, 1.0, UIStyle.dur(maxf(climax - delay - 0.4, 0.25))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(g, "scale", Vector2(0.92, 0.92), UIStyle.dur(maxf(climax - delay - 0.4, 0.25)))
	tw.tween_callback(func():
		_fx.burst(FxBurst.Kind.EMBER, origin + lift, col.lightened(0.2), 14, 60.0, 0.6)
		_to_pile(m, p, origin + lift, col)
		_fx.free_node(g))


## Arcane: the spent card rises spectral and pale from its pile and shatters into shards (FxSummonArt
## flies the shards on into the lattice).
func _shatter_up(m: Dictionary, p: int, col: Color, delay: float, prev_mv: Dictionary) -> void:
	var origin := _mat_origin(m, p)
	var g := _mat_ghost(m, prev_mv, origin)
	var base := g.position
	g.scale = Vector2(0.55, 0.55)
	g.modulate = Color(0.75, 0.95, 1.0, 0.0)
	g.fx_glow = Color(col, 0.9)
	var mat := ShaderMaterial.new()
	mat.shader = load(FxCardEffects.DISSOLVE_SHADER)
	mat.set_shader_parameter("edge_color", col.lightened(0.45))
	g.material = mat
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(delay))
	tw.tween_property(g, "modulate:a", 0.85, UIStyle.dur(0.1))
	tw.parallel().tween_property(g, "position", base + Vector2(0, -50.0), UIStyle.dur(0.22)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "scale", Vector2(0.75, 0.75), UIStyle.dur(0.22))
	tw.tween_callback(func(): _fx.burst(FxBurst.Kind.SPARK, origin + Vector2(0, -50.0), col.lightened(0.5), 12, 50.0, 0.3))
	tw.tween_method(func(v: float): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, UIStyle.dur(0.2))
	tw.tween_callback(func():
		_to_pile(m, p, origin + Vector2(0, -50.0), col)
		_fx.free_node(g))


## The climax: flash, refracting shockwave, light rays, particles and a camera shake, per kind.
func _climax(kind: String, centre: Vector2, col: Color, reach: float) -> void:
	Sfx.play(String(SOUND_CLIMAX[kind]), 0.0, 0.0)
	var acc := accent_of(kind)
	_fx.screen_flash(col.lerp(Color.WHITE, 0.35), 0.34, 0.02, 0.25, centre)
	_fx.distort(centre, reach * 2.8, 0.8, 30.0, 0.0, Color(acc, 0.14))
	_fx.camera_shake(13.0, 0.5)
	# Each climax has its own blast: Fusion's rings and streaks, Ritual's rays, Arcane's sharp final burst.
	var b := FxBlast.new()
	b.look = {"fusion": FxBlast.Look.HIT, "ritual": FxBlast.Look.BLAST, "arcane": FxBlast.Look.FINAL}.get(kind, FxBlast.Look.HIT)
	b.col = col if kind != "ritual" else acc
	b.radius = reach * {"fusion": 0.85, "ritual": 0.55, "arcane": 0.6}.get(kind, 0.7)
	b.position = _fx.fx_pos(centre)
	_fx.add_node(b)
	var tb := _fx.new_tween()
	tb.tween_property(b, "t", 1.0, UIStyle.dur(1.05))
	tb.tween_callback(_fx.free_node.bind(b))
	_fx.burst(FxBurst.Kind.SPARK, centre, acc.lightened(0.2), 32, reach * 1.1, 0.7)
	match kind:
		"ritual":
			_fx.burst(FxBurst.Kind.EMBER, centre, acc, 36, reach * 0.9, 1.2)
			var ring := FxRuneRing.new()
			ring.col = col
			ring.radius = reach * 1.2
			ring.position = _fx.fx_pos(centre)
			_fx.add_node(ring)
			var rt := _fx.new_tween()
			rt.tween_property(ring, "t", 1.0, UIStyle.dur(0.8))
			rt.tween_callback(_fx.free_node.bind(ring))
		"arcane":
			_fx.burst(FxBurst.Kind.SPARK, centre, Color(0.85, 0.97, 1.0), 24, reach * 1.7, 0.55)
			var sg := FxSigil.new()
			sg.kind = "arcane"
			sg.col = col
			sg.radius = reach * 1.1
			sg.position = _fx.fx_pos(centre)
			_fx.add_node(sg)
			var st := _fx.new_tween()
			st.tween_property(sg, "t", 1.0, UIStyle.dur(0.75))
			st.tween_callback(_fx.free_node.bind(sg))
		_:
			_fx.burst(FxBurst.Kind.EMBER, centre, acc.lightened(0.2), 28, reach * 0.8, 1.0)
			var sw := FxSigil.new()
			sw.kind = "fusion"
			sw.col = acc
			sw.radius = reach * 1.3
			sw.position = _fx.fx_pos(centre)
			_fx.add_node(sw)
			var ss := _fx.new_tween()
			ss.tween_property(sw, "t", 1.0, UIStyle.dur(0.6))
			ss.tween_callback(_fx.free_node.bind(sw))


## The resolution: the card appears at the climax high above its slot, falls, slams down with a
## squash-and-stretch, dust and a small shake, and its glow fades.
func _land(target: Dictionary, centre: Vector2, rect: Rect2, col: Color, reach: float, climax: float) -> void:
	if target.is_empty():
		return
	var w: CardWidget = target["w"]
	var holder = target["holder"]
	w.pivot_offset = w.size / 2.0
	if holder != null:
		(holder as Control).z_index = UiLayers.FX_CARD_FRONT
	var high := Vector2(0, -reach * 0.85)
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(climax))
	tw.tween_callback(func():
		if not is_instance_valid(w):
			return
		w.fx_offset = high
		w.scale = Vector2(1.5, 1.5)
		w.fx_flash = 1.0
		w.fx_glow = Color(col, 1.0))
	tw.tween_property(w, "modulate:a", 1.0, UIStyle.dur(0.05))
	tw.tween_interval(UIStyle.dur(DROP_DELAY))
	tw.tween_property(w, "fx_offset", Vector2.ZERO, UIStyle.dur(DROP_TIME)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(w, "scale", Vector2(1.05, 1.05), UIStyle.dur(DROP_TIME)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(w, "fx_flash", 0.35, UIStyle.dur(DROP_TIME))
	tw.tween_callback(func():
		Sfx.play(SOUND_SLAM, 0.0, 0.03)
		_fx.burst(FxBurst.Kind.DUST, Vector2(centre.x, rect.end.y - 4.0), DUST, 16, rect.size.x * 0.95, 0.55)
		_fx.burst(FxBurst.Kind.DUST, centre, DUST.lightened(0.2), 10, rect.size.x * 0.7, 0.45)
		_fx.burst(FxBurst.Kind.SPARK, centre, col.lightened(0.45), 14, rect.size.length() * 0.7, 0.4)
		_fx.camera_shake(6.0, 0.25))
	# Squash on impact, stretch on the rebound, settle.
	tw.tween_property(w, "scale", Vector2(1.16, 0.82), UIStyle.dur(0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2(0.94, 1.07), UIStyle.dur(0.09)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(w, "fx_flash", 0.0, UIStyle.dur(0.22))
	tw.parallel().tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if not bool(target["ghost"]):
		tw.tween_callback(_fx.reset_widget.bind(w, holder))


## Reduced motion: the materials fade where they are, a soft glow of the kind colour fills the slot and
## the card fades in under it. No flight, shake, flash beyond 0.3, distortion or particles.
func _calm(kind: String, mats: Array, target: Dictionary, centre: Vector2, col: Color, prev_mv: Dictionary) -> void:
	Sfx.play(String(SOUND_CLIMAX[kind]), -3.0, 0.0)
	for m in mats:
		var g := _mat_ghost(m, prev_mv, _mat_origin(m, int(m.get("p", 0))))
		g.fx_glow = Color(col, 0.8)
		var tg := _fx.new_tween()
		tg.tween_property(g, "modulate:a", 0.0, CALM_LEN * 0.5)
		tg.tween_callback(_fx.free_node.bind(g))
	var sg := FxSigil.new()
	sg.kind = "mote"
	sg.col = col
	sg.radius = 70.0
	sg.position = _fx.fx_pos(centre)
	sg.modulate.a = 0.0
	_fx.add_node(sg)
	var ts := _fx.new_tween()
	ts.tween_property(sg, "modulate:a", 0.6, CALM_LEN * 0.35)
	ts.tween_property(sg, "modulate:a", 0.0, CALM_LEN * 0.5)
	ts.tween_callback(_fx.free_node.bind(sg))
	if target.is_empty():
		return
	var w: CardWidget = target["w"]
	w.fx_glow = Color(col, 0.9)
	var tw := _fx.new_tween()
	tw.tween_interval(CALM_LEN * 0.3)
	tw.tween_property(w, "modulate:a", 1.0, CALM_LEN * 0.3)
	tw.tween_property(w, "fx_glow", Color(col, 0.0), CALM_LEN * 0.4)
	if not bool(target["ghost"]):
		tw.tween_callback(_fx.reset_widget.bind(w, target["holder"]))


static func _sq(x: float) -> float:
	return x * x
