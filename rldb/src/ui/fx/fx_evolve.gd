class_name FxEvolve
extends FxPart
## L23 (owner feedback 2026-11-05): the Evolve set piece, and L11's copied-art shimmer.
##
## Evolve ("evolve" fx {at, from, to}), about 2.3 s, in the Evolve colours (EvolveGlyph: the orchid
## pink of the Symbiote blossoms over indigo):
##   anticipation: the board dims; luminous silk threads wind around the old card from its foot to its
##                 crown into a glowing chrysalis while light motes are drawn in; a heartbeat of light
##                 pulses inside it, faster and brighter, and the card trembles (evolve_charge);
##   climax:       a flash, a refracting shockwave and a small shake: the chrysalis bursts into petals
##                 and shards with a bloom ring and light rays, while the old card burns away in a pink
##                 dissolve to reveal the new one (the art morph) (evolve_burst);
##   settle:       the new card eases down from a slight lift with a fading glow, "Evolved" rises above
##                 it and a few sparkles drift up.
## Reduced motion: a calm crossfade from the old card to the new one with a glow, and the two sounds.
##
## Copy form ("copy_form" fx {at, id, art}), about 0.9 s: a silver-violet shimmer sweeps across Loak /
## Mimic while its own art dissolves into the copied unit's (copy_form). Reduced motion: a crossfade.
##
## FxPlayer calls prepare() as soon as the batch arrives (the board already shows the new card): a still
## ghost of the card as it was covers the slot until the effect plays, so the new look never flashes
## early. Everything is created through FxPlayer, so finish_all() snaps it to the final state.

## Seconds of the evolve set piece, its climax, and the calm variant.
const LEN := 2.3
const CLIMAX := 1.2
const CALM_LEN := 0.7
## Seconds of the copy-form shimmer (and of its calm variant) and how long it holds the batch.
const COPY_LEN := 0.9
const COPY_CALM := 0.35
const COPY_HOLD := 0.55
## Edge colour of the copied-art dissolve and the shimmer band.
const COPY_EDGE := Color("c9b6ff")
const DISSOLVE_SHADER := "res://assets/shaders/dissolve.gdshader"


## Seconds an evolve holds the rest of its batch.
static func length_for() -> float:
	return CALM_LEN if UIStyle.reduce_motion else LEN


## Seconds a copy-form shimmer holds the rest of its batch.
static func copy_hold() -> float:
	return COPY_CALM if UIStyle.reduce_motion else COPY_HOLD


## Called when the batch arrives: covers the slot of `e` (an "evolve" or "copy_form" event) with a
## still ghost of the card as it looked before (from `prev_mv`), and hides the real card under it.
## Returns {"ghost", "w", "holder"} for play(), or {} when there is nothing to show.
func prepare(e: Dictionary, prev_mv: Dictionary) -> Dictionary:
	var at: Dictionary = e.get("at", {})
	if at.is_empty():
		return {}
	var it: Dictionary = _fx.screen.fx_slot_item(int(at["p"]), "unit", int(at["slot"]))
	if it.is_empty():
		return {}
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	if not w.visible:
		return {}
	# The slot's card in the view before this batch (statuses and all), or the bare card by its id.
	var before_id := int(e.get("from", e.get("id", -1)))
	if not CardDB.has(before_id):
		return {}
	var view: Dictionary = _fx.pile_view({"at": at, "id": before_id}, prev_mv).duplicate()
	if String(e.get("k", "")) == "copy_form":
		view.erase("art_id")              # its own art, before it took the copied one
	var g := CardWidget.new()
	g.show_tooltip = false
	g.auto_hover = false
	g.setup(view, "board", "", bool(w.rotated))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.pivot_offset = g.size / 2.0
	g.z_as_relative = false
	g.z_index = UiLayers.FX_CARD
	var rect := w.get_global_rect()
	g.position = _fx.fx_pos(rect.get_center()) - g.size / 2.0
	_fx.add_node(g)
	w.modulate.a = 0.0
	_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	return {"ghost": g, "w": w, "holder": holder}


## Plays the effect of event `e` on the slot covered by prepare()'s `prep`.
func play(e: Dictionary, prep: Dictionary) -> void:
	if prep.is_empty() or not is_instance_valid(prep.get("ghost")) or not is_instance_valid(prep.get("w")):
		return
	if String(e.get("k", "")) == "copy_form":
		_copy_form(prep)
	else:
		_evolve(e, prep)


# ---------------------------------------------------------------- evolve

func _evolve(e: Dictionary, prep: Dictionary) -> void:
	var g: CardWidget = prep["ghost"]
	var w: CardWidget = prep["w"]
	var holder: Control = prep["holder"]
	var rect := w.get_global_rect()
	var centre := rect.get_center()
	Sfx.play("evolve_charge", -1.0, 0.0)
	if UIStyle.reduce_motion:
		_calm_swap(g, w, holder, CALM_LEN, EvolveGlyph.COLOR, "evolve_burst")
		return
	var climax := CLIMAX
	var life := LEN
	_fx.vignette(0.7, 0.3, climax - 0.1, 0.65, Color(0.03, 0.0, 0.05))
	holder.z_index = UiLayers.FX_CARD
	# The chrysalis: one art node behind the card (aura, inward motes, the back threads) and one in front
	# (the front threads, the burst), both driven by the same progress.
	var half := rect.size / 2.0
	var arts := []
	for front in [false, true]:
		var art := Art.new()
		art.front = front
		art.half = half
		art.life = life
		art.climax = climax
		art.position = _fx.fx_pos(centre)
		art.z_as_relative = false
		art.z_index = UiLayers.FX_CARD_FRONT if front else UiLayers.FX_CARD - 1
		_fx.add_node(art)
		arts.append(art)
		var ta := _fx.new_tween()
		ta.tween_property(art, "t", 1.0, UIStyle.dur(life))
		ta.tween_callback(_fx.free_node.bind(art))
	# The old card: a heartbeat glow and a tremble that grow towards the climax.
	var home := g.position
	var beat := func(s: float) -> void:
		if not is_instance_valid(g):
			return
		var k := s / climax
		var pulse := Art.heartbeat(s, climax)
		g.fx_glow = Color(EvolveGlyph.COLOR.lerp(EvolveGlyph.LIGHT, pulse * 0.6), 0.25 + 0.65 * pulse)
		g.fx_flash = 0.35 * pulse * k
		var amp := 2.6 * k * k
		g.position = home + Vector2(sin(s * 71.0) * amp, cos(s * 53.0) * amp * 0.6)
		g.scale = Vector2.ONE * (1.0 + 0.05 * k)
	var tg := _fx.new_tween()
	tg.tween_method(beat, 0.0, climax, UIStyle.dur(climax))
	# The morph: the old card burns away in pink while the new one rises through the flash.
	var mat := ShaderMaterial.new()
	mat.shader = load(DISSOLVE_SHADER)
	mat.set_shader_parameter("edge_color", EvolveGlyph.LIGHT)
	mat.set_shader_parameter("edge_width", 0.14)
	var morph_at := climax - 0.12
	var tm := _fx.new_tween()
	tm.tween_interval(UIStyle.dur(morph_at))
	tm.tween_callback(func() -> void:
		if is_instance_valid(g):
			g.material = mat)
	tm.tween_method(func(v: float) -> void: mat.set_shader_parameter("dissolve", v), 0.0, 1.0, UIStyle.dur(0.42)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tm.tween_callback(_fx.free_node.bind(g))
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(climax - 0.06))
	tw.tween_callback(func() -> void:
		if not is_instance_valid(w):
			return
		_fx.unhide(w)
		w.scale = Vector2(1.16, 1.16)
		w.fx_glow = Color(EvolveGlyph.LIGHT, 1.0)
		w.fx_flash = 0.85)
	tw.tween_property(w, "modulate:a", 1.0, UIStyle.dur(0.2))
	tw.parallel().tween_property(w, "fx_flash", 0.0, UIStyle.dur(0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2(0.97, 0.97), UIStyle.dur(0.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.26)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(w, "fx_glow", Color(EvolveGlyph.COLOR, 0.0), UIStyle.dur(0.75)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_fx.reset_widget.bind(w, holder))
	# The climax beats around the card.
	var tc := _fx.new_tween()
	tc.tween_interval(UIStyle.dur(climax))
	tc.tween_callback(func() -> void:
		Sfx.play("evolve_burst", 0.0, 0.0)
		_fx.screen_flash(EvolveGlyph.COLOR, 0.32, 0.04, 0.5, centre)
		_fx.distort(centre, maxf(half.x, half.y) * 5.0, 0.7, 26.0, 0.0, Color(EvolveGlyph.LIGHT, 0.5))
		_fx.camera_shake(5.0, 0.32)
		_fx.burst(FxBurst.Kind.SPARK, centre, EvolveGlyph.LIGHT, 14, maxf(half.x, half.y) * 2.6, 0.5)
		_fx.burst(FxBurst.Kind.EMBER, centre, EvolveGlyph.COLOR, 12, maxf(half.x, half.y) * 2.0, 0.9))
	tc.tween_interval(UIStyle.dur(0.18))
	tc.tween_callback(func() -> void:
		_fx.float_text("Evolved", EvolveGlyph.COLOR, centre - Vector2(0, half.y + 16.0), 22, 30.0, 1.1))


## Reduced motion: the old card fades out over the new one with a glow (no movement), sound `snd`
## halfway.
func _calm_swap(g: CardWidget, w: CardWidget, holder: Control, length: float, col: Color, snd: String) -> void:
	_fx.unhide(w)
	w.modulate.a = 1.0
	w.fx_glow = Color(col, 0.85)
	var tw := _fx.new_tween()
	tw.tween_property(g, "modulate:a", 0.0, length * 0.5)
	if snd != "":
		tw.tween_callback(Sfx.play.bind(snd, 0.0, 0.0))
	tw.tween_callback(_fx.free_node.bind(g))
	tw.tween_property(w, "fx_glow", Color(col, 0.0), length * 0.5)
	tw.tween_callback(_fx.reset_widget.bind(w, holder))


# ---------------------------------------------------------------- copy form (L11)

func _copy_form(prep: Dictionary) -> void:
	var g: CardWidget = prep["ghost"]
	var w: CardWidget = prep["w"]
	var holder: Control = prep["holder"]
	Sfx.play("copy_form", 0.0, 0.0)
	if UIStyle.reduce_motion:
		_calm_swap(g, w, holder, COPY_CALM, COPY_EDGE, "")
		return
	var rect := w.get_global_rect()
	# The copied form shows under the old one at once; the old one dissolves along the shimmer.
	_fx.unhide(w)
	w.modulate.a = 1.0
	var mat := ShaderMaterial.new()
	mat.shader = load(DISSOLVE_SHADER)
	mat.set_shader_parameter("edge_color", COPY_EDGE)
	mat.set_shader_parameter("edge_width", 0.12)
	g.material = mat
	var sh := Shimmer.new()
	sh.half = rect.size / 2.0
	sh.position = _fx.fx_pos(rect.get_center())
	sh.z_as_relative = false
	sh.z_index = UiLayers.FX_CARD_FRONT
	_fx.add_node(sh)
	var ts := _fx.new_tween()
	ts.tween_property(sh, "t", 1.0, UIStyle.dur(COPY_LEN))
	ts.tween_callback(_fx.free_node.bind(sh))
	var tg := _fx.new_tween()
	tg.tween_method(func(v: float) -> void: mat.set_shader_parameter("dissolve", v), 0.0, 1.0, UIStyle.dur(COPY_LEN * 0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tg.tween_callback(_fx.free_node.bind(g))
	w.fx_glow = Color(COPY_EDGE, 0.0)
	var tw := _fx.new_tween()
	tw.tween_property(w, "fx_glow", Color(COPY_EDGE, 0.8), UIStyle.dur(COPY_LEN * 0.4))
	tw.tween_property(w, "fx_glow", Color(COPY_EDGE, 0.0), UIStyle.dur(COPY_LEN * 0.6))
	tw.tween_callback(_fx.reset_widget.bind(w, holder))
	_fx.burst(FxBurst.Kind.SPARK, rect.get_center(), COPY_EDGE, 10, maxf(rect.size.x, rect.size.y) * 0.9, 0.45)


# ---------------------------------------------------------------- drawing

## A stable pseudo-random value in [0, 1) for item `i`, channel `k` (redraws at any `t` agree).
static func h(i: int, k: int) -> float:
	var v := sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
	return v - floorf(v)


static func _out(x: float, p: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), p)


## The chrysalis and its burst, centred on the node position and driven by one progress value `t`
## (0 -> 1 over `life` seconds; the climax at `climax`). Two of them play together: the back one
## (`front` false: the aura, the motes drawn in, the threads behind the card) under the card and the
## front one (the threads before it, the inner light, the burst) over it. Additive, click-through.
class Art extends Control:
	var front := false
	## Half the card's on-screen size.
	var half := Vector2(42, 64)
	var life := 2.3
	var climax := 1.2
	var t := 0.0: set = _set_t

	const THREADS := 11
	const THREAD_STEPS := 30
	const MOTES := 34
	const SHARDS := 26
	const RAYS := 10
	const SPARKLES := 16

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(4, 4)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _set_t(v: float) -> void:
		t = v
		queue_redraw()

	## The chrysalis heartbeat at `s` seconds (0..1): sharp pulses closer together and stronger towards
	## the climax over a rising base glow.
	static func heartbeat(s: float, climax_s: float) -> float:
		var k := s / maxf(climax_s, 0.001)
		var out := 0.0
		for p in [0.2, 0.48, 0.7, 0.85, 0.95]:
			var d: float = k - float(p)
			if d >= 0.0:
				out = maxf(out, exp(-d * 16.0) * (0.4 + 0.6 * float(p)))
		return clampf(out + 0.25 * k * k, 0.0, 1.0)

	func _draw() -> void:
		var s := t * life
		if s < climax:
			_chrysalis(s)
		else:
			_burst((s - climax) / maxf(life - climax, 0.001))

	func _ellipse(rx: float, ry: float, n: int = 40) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * float(i) / float(n)
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		return pts

	func _chrysalis(s: float) -> void:
		var k := s / climax
		var pulse := heartbeat(s, climax)
		var grow := FxEvolve._out(k * 2.2, 2.0)
		var big := maxf(half.x, half.y)
		if not front:
			# The cocoon's glow: soft ellipses from indigo at the rim to blossom pink inside.
			for j in 6:
				var sc := 1.0 + float(j) * 0.13 + pulse * 0.08
				var col := EvolveGlyph.COLOR.lerp(EvolveGlyph.DEEP, float(j) / 5.0)
				draw_colored_polygon(_ellipse(half.x * 1.32 * sc, half.y * 1.2 * sc), Color(col, (0.11 - float(j) * 0.014) * grow * (0.7 + 0.6 * pulse)))
			# Motes of light drawn in towards the chrysalis.
			for i in MOTES:
				var a := TAU * FxEvolve.h(i, 1)
				var q := fmod(s * (0.7 + FxEvolve.h(i, 2) * 0.9) + FxEvolve.h(i, 3), 1.0)
				var r := lerpf(big * (2.2 + FxEvolve.h(i, 4) * 1.2), big * 0.45, pow(q, 1.4))
				var p := Vector2(cos(a), sin(a) * 0.92) * r
				var al := sin(q * PI) * minf(1.0, k * 3.0)
				var col2 := EvolveGlyph.LIGHT if i % 3 == 0 else EvolveGlyph.COLOR
				draw_circle(p, 1.3 + FxEvolve.h(i, 5) * 1.6, Color(col2, 0.85 * al), true, -1.0, true)
				draw_line(p, p * (1.0 + 0.12 * q), Color(col2, 0.35 * al), 1.2, true)
		_threads(s, k, pulse)
		if front:
			# The light inside the chrysalis, shining through the card on each heartbeat.
			var core := big * (0.35 + 0.55 * pulse)
			for j in 4:
				draw_circle(Vector2.ZERO, core * (1.0 - float(j) * 0.22), Color(EvolveGlyph.LIGHT if j > 1 else EvolveGlyph.COLOR, 0.07 * pulse * (0.4 + k)), true, -1.0, true)
			if k > 0.82:
				var w := (k - 0.82) / 0.18
				draw_colored_polygon(_ellipse(half.x * 1.1, half.y * 1.05), Color(EvolveGlyph.LIGHT, 0.32 * w * w))

	## The silk threads: helices wound from the card's foot to its crown, the front half of each turn
	## drawn by the front node (brighter), the back half by the back node.
	func _threads(s: float, k: float, pulse: float) -> void:
		var wrap := FxEvolve._out(s / (climax * 0.8), 2.2)
		var breathe := 1.0 + 0.045 * pulse
		for i in THREADS:
			var phase := TAU * float(i) / float(THREADS) + FxEvolve.h(i, 6) * 0.6
			var turns := 1.35 + FxEvolve.h(i, 7) * 0.7
			var sgn := 1.0 if i % 2 == 0 else -1.0
			var start := FxEvolve.h(i, 8) * 0.18          # threads start at slightly different times
			var w := clampf((wrap - start) / maxf(1.0 - start, 0.01), 0.0, 1.0)
			if w <= 0.0:
				continue
			var n := maxi(2, int(ceil(float(THREAD_STEPS) * w)))
			var prev := Vector2.ZERO
			var prev_d := 0.0
			for j in n + 1:
				var u := w * float(j) / float(n)
				var y := half.y * 1.16 * (1.0 - 2.0 * u)
				var env := sqrt(maxf(0.0, 1.0 - pow(y / (half.y * 1.28), 2.0)))
				var ang := phase + sgn * u * turns * TAU
				var p := Vector2(half.x * 1.3 * env * sin(ang) * breathe, y)
				var d := cos(ang)
				if j > 0 and ((d + prev_d) >= 0.0) == front:
					var dd := absf((d + prev_d) * 0.5)
					var col := EvolveGlyph.COLOR.lerp(EvolveGlyph.LIGHT, 0.25 + 0.5 * dd) if front else EvolveGlyph.DEEP.lerp(EvolveGlyph.COLOR, 0.45)
					var al := (0.5 + 0.45 * dd) if front else 0.3
					al *= 0.75 + 0.25 * pulse
					draw_line(prev, p, Color(col, al), (1.1 + 1.3 * dd) if front else 1.1, true)
				prev = p
				prev_d = d
			# The growing end of a thread is a bright bead.
			if w < 1.0 and (prev_d >= 0.0) == front:
				draw_circle(prev, 2.2, Color(EvolveGlyph.LIGHT, 0.9), true, -1.0, true)

	func _burst(b: float) -> void:
		var big := maxf(half.x, half.y)
		var fade := pow(1.0 - b, 1.4)
		if not front:
			for j in 4:
				var sc := 1.1 + float(j) * 0.18 + b * 0.9
				draw_colored_polygon(_ellipse(half.x * 1.3 * sc, half.y * 1.2 * sc), Color(EvolveGlyph.COLOR.lerp(EvolveGlyph.DEEP, float(j) / 3.0), 0.12 * fade * fade))
			return
		# Bloom rings.
		var r1 := big * (0.6 + 3.1 * FxEvolve._out(b, 3.0))
		draw_arc(Vector2.ZERO, r1, 0.0, TAU, 72, Color(EvolveGlyph.COLOR, 0.8 * fade), 2.0 + 7.0 * (1.0 - b), true)
		var r2 := big * (0.4 + 2.0 * FxEvolve._out(b, 4.0))
		draw_arc(Vector2.ZERO, r2, 0.0, TAU, 64, Color(EvolveGlyph.LIGHT, 0.7 * fade * fade), 1.5 + 4.0 * (1.0 - b), true)
		# Light rays.
		var rise := clampf(b / 0.06, 0.0, 1.0)
		for i in RAYS:
			var a := TAU * float(i) / float(RAYS) + FxEvolve.h(i, 9) * 0.4
			var dir := Vector2.from_angle(a)
			var nrm := Vector2(-dir.y, dir.x)
			var ln := big * (1.3 + 2.3 * FxEvolve._out(b, 2.0)) * (0.55 + 0.45 * FxEvolve.h(i, 10))
			var wd := big * 0.09 * (1.0 - b * 0.6)
			var al := 0.55 * fade * fade * rise
			draw_polygon(PackedVector2Array([nrm * wd, dir * ln, -nrm * wd]),
				PackedColorArray([Color(EvolveGlyph.LIGHT, al), Color(EvolveGlyph.COLOR, 0.0), Color(EvolveGlyph.LIGHT, al)]))
		# The chrysalis bursting into petals and shards.
		for i in SHARDS:
			var a := TAU * FxEvolve.h(i, 11)
			var dir := Vector2.from_angle(a)
			var p0 := Vector2(cos(a) * half.x * 1.25, sin(a) * half.y * 1.15)
			var pos := p0 + dir * big * (1.2 + 1.8 * FxEvolve.h(i, 12)) * FxEvolve._out(b, 2.2) + Vector2(0, 26.0 * b * b)
			var rot := a + (FxEvolve.h(i, 13) - 0.5) * 9.0 * b
			var sz := (4.0 + 6.0 * FxEvolve.h(i, 14)) * (1.0 - 0.45 * b)
			var d2 := Vector2.from_angle(rot)
			var col: Color = [EvolveGlyph.COLOR, EvolveGlyph.LIGHT, EvolveGlyph.DEEP.lightened(0.35)][i % 3]
			draw_colored_polygon(EvolveGlyph.petal(pos - d2 * sz, pos + d2 * sz, sz * 0.4, 0.15), Color(col, 0.9 * fade))
		# Sparkles drifting up as it settles.
		if b > 0.12:
			var q := (b - 0.12) / 0.88
			for i in SPARKLES:
				var x := (FxEvolve.h(i, 15) - 0.5) * half.x * 2.6
				var y := half.y * 0.5 - FxEvolve._out(q, 2.0) * half.y * (1.6 + 1.2 * FxEvolve.h(i, 16))
				var al := sin(q * PI) * 0.9
				var sz := 2.0 + 2.5 * FxEvolve.h(i, 17)
				var c := Vector2(x, y)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -sz), c + Vector2(sz * 0.3, 0), c + Vector2(0, sz), c + Vector2(-sz * 0.3, 0)]), Color(EvolveGlyph.LIGHT, al))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-sz, 0), c + Vector2(0, -sz * 0.3), c + Vector2(sz, 0), c + Vector2(0, sz * 0.3)]), Color(EvolveGlyph.LIGHT, al))


## L11: the shimmer of a copied form: a bright diagonal band sweeping across the card (clipped to it)
## with a few glints riding it. Additive, click-through, driven by `t` (0 -> 1).
class Shimmer extends Control:
	var half := Vector2(42, 64)
	var t := 0.0: set = _set_t

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(4, 4)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _set_t(v: float) -> void:
		t = v
		queue_redraw()

	func _draw() -> void:
		var card := PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
		var diag := half.x + half.y
		var c := lerpf(-diag * 1.3, diag * 1.3, FxEvolve._out(t, 1.6))   # the band's centre (x + y = c)
		var hw := diag * 0.32
		var a := 0.75 * sin(clampf(t, 0.0, 1.0) * PI)
		for side in [-1.0, 1.0]:
			var lo: float = c if side > 0.0 else c - hw
			var hi: float = c + hw if side > 0.0 else c
			var band := PackedVector2Array([Vector2(lo + half.y, -half.y), Vector2(hi + half.y, -half.y), Vector2(hi - half.y, half.y), Vector2(lo - half.y, half.y)])
			for piece in Geometry2D.intersect_polygons(band, card):
				var cols := PackedColorArray()
				for p in piece:
					var k := clampf(1.0 - absf(p.x + p.y - c) / maxf(0.001, hw), 0.0, 1.0)
					cols.append(Color(FxEvolve.COPY_EDGE.lerp(Color.WHITE, k * 0.5), a * k * k))
				draw_polygon(piece, cols)
		for i in 5:
			var u := FxEvolve.h(i, 21) * 2.0 - 1.0
			var p := Vector2(c * 0.5 + u * half.x * 0.6, c * 0.5 - u * half.x * 0.6)
			if absf(p.x) < half.x and absf(p.y) < half.y:
				var sz := 3.0 + 3.0 * FxEvolve.h(i, 22)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz), p + Vector2(sz * 0.3, 0), p + Vector2(0, sz), p + Vector2(-sz * 0.3, 0)]), Color(1, 1, 1, a))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-sz, 0), p + Vector2(0, -sz * 0.3), p + Vector2(sz, 0), p + Vector2(0, sz * 0.3)]), Color(1, 1, 1, a))
