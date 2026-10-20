class_name FxPileEffects
extends FxPart
## Card-movement effects between zones and piles: destruction (crack, burn, drop toward Spent),
## Exhaust (card shown front and centre, then pulled into the Exhaust pile in a void colour), the
## sacrifice (D6), the B5 transient summon ghost and a lone special-summon material (one whose summon
## failed; the Fusion / Ritual / Arcane set pieces themselves live in FxSummon). Presentation only: every effect
## is an overlay on the already-final board and is removed by FxPlayer.finish_all().
##
## Identity rule: a card is drawn face up only when the event carries `id` (core strips it for seats
## that may not see the card) or the card was face up on the board; otherwise an anonymous card back.

## Colours of the outcomes (proposed; art direction may retune): burn for destruction, cold violet
## for Exhaust. Special-summon colours come from the existing card-category palette.
const BURN := Color("ff8a3a")
const VOID := Color("a47bff")
const KIND_ACCENT := {"fusion": "fusion", "ritual": "ritual", "arcane": "arcane"}
const BURN_SHADER := "res://assets/shaders/canvas_fx_burn.gdshader"

## Seconds the Exhaust card holds front and centre.
const EXHAUST_HOLD := 0.6


## Colour of a special-summon kind ("fusion" | "ritual" | "arcane"), lightened to read on the wood board.
static func kind_color(kind: String) -> Color:
	var c: Color = UIStyle.CATEGORY_COLORS.get(String(KIND_ACCENT.get(kind, "unit")), UIStyle.GOLD)
	return c.lightened(0.45) if c.get_luminance() < 0.3 else c.lightened(0.2)


## The card view an event may show: the previous board card (public), else the card from the event
## `id` (only present for authorised seats), else an anonymous back. Never reads hidden state.
func ghost_view(e: Dictionary, prev_mv: Dictionary) -> Dictionary:
	var at = e.get("at", {})
	if at is Dictionary and not (at as Dictionary).is_empty() and not prev_mv.is_empty():
		var zone := String(at["zone"])
		if Zones.KEY.has(zone):
			var arr: Array = prev_mv["players"][int(at["p"])][Zones.KEY[zone]]
			var slot := int(at["slot"])
			# The previous card of the slot, unless the event names another one (summoned in between).
			if slot < arr.size() and arr[slot] is Dictionary and (not e.has("id") or int(arr[slot].get("id", -1)) == int(e["id"])):
				return arr[slot]
	if e.has("id"):
		return MatchView.summary_view(Series.card_summary(int(e["id"])))
	return {"hidden": true}


## B5: a ghost of the unit summoned by `summon_e` (its public `id`) standing in player `p`'s unit `slot`
## and registered as transient, for a unit that already left the field again in this batch. It arrives
## like a summon when `arrive` is true. Returns null when the event does not name the card.
func summon_ghost(p: int, slot: int, summon_e: Dictionary, arrive: bool = false) -> CardWidget:
	if not summon_e.has("id"):
		return null
	var view := MatchView.summary_view(Series.card_summary(int(summon_e["id"])))
	view["stance"] = String(summon_e.get("stance", "atk"))
	var rect: Rect2 = _fx.screen.fx_slot_global_rect(p, "unit", slot)
	var g := _ghost(view, "board", String(view["stance"]) == "def")
	g.position = _fx.fx_pos(rect.get_center() - g.size / 2.0)
	_fx.add_node(g)
	_fx.hold_transient(FxPlayer.transient_key(p, "unit", slot), g)
	if arrive and not UIStyle.reduce_motion:
		var home := g.position
		g.position = _fx.fx_pos(_fx.screen.hand_anchor(p) - g.size / 2.0)
		g.scale = Vector2(1.18, 1.18)
		g.modulate.a = 0.0
		var tw := _fx.new_tween()
		tw.set_parallel(true)
		tw.tween_property(g, "modulate:a", 1.0, UIStyle.dur(0.08))
		tw.tween_property(g, "position", home, UIStyle.dur(0.24)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "scale", Vector2.ONE, UIStyle.dur(0.24)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func():
			_fx.burst(FxBurst.Kind.DUST, Vector2(rect.get_center().x, rect.end.y - 6.0), FxCardEffects.DUST_COLOR, 8, 50.0, 0.4)
			if is_instance_valid(g):
				g.fx_glow = Color(UIStyle.GOLD_HI, 0.8))
		tw.chain().tween_property(g, "scale", Vector2(1.08, 0.92), UIStyle.dur(0.05))
		tw.chain().tween_property(g, "scale", Vector2.ONE, UIStyle.dur(0.1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(g, "fx_glow", Color(UIStyle.GOLD_HI, 0.0), UIStyle.dur(0.3))
	return g


## A still ghost of the card `e` destroys (the F12 hold ghost), or null when it may not be shown.
func destroy_ghost(e: Dictionary, prev_mv: Dictionary) -> CardWidget:
	return hold_ghost(e, prev_mv)


## Anonymous-or-identified card widget used by every ghost: click-through, no hover, no tooltip.
func _ghost(view: Dictionary, kind: String, rotated: bool = false) -> CardWidget:
	var g := CardWidget.new()
	g.show_tooltip = false
	g.auto_hover = false
	g.setup(view, kind, "", rotated)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.pivot_offset = g.size / 2.0
	return g


## The burn material (canvas_fx_burn) on ghost `g`: white-hot edge, `ember` glow and `char` ahead of it.
## Drive it with burn_step(progress, g, mat), which also follows the card as it moves.
static func burn_material(g: CardWidget, ember: Color, char_col: Color, hot: Color = Color(1.0, 0.95, 0.75)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(BURN_SHADER)
	mat.set_shader_parameter("ember_color", ember)
	mat.set_shader_parameter("char_color", char_col)
	mat.set_shader_parameter("hot_color", hot)
	g.material = mat
	return mat


## Sets the burn progress of `mat` on `g` and its card rect in viewport pixels (for the rising front).
static func burn_step(v: float, g: CardWidget, mat: ShaderMaterial) -> void:
	if not is_instance_valid(g):
		return
	var xf := g.get_viewport().get_final_transform() * g.get_global_transform_with_canvas()
	var r := xf * Rect2(Vector2.ZERO, g.size)
	mat.set_shader_parameter("rect_px", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	mat.set_shader_parameter("progress", v)


func _dissolve(g: CardWidget, edge: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(FxCardEffects.DISSOLVE_SHADER)
	mat.set_shader_parameter("edge_color", edge)
	g.material = mat
	return mat


## Where a card in `from` (a pile name or "hand") of player `p` is drawn from / to.
func _origin(p: int, from: String) -> Vector2:
	if from == "hand":
		return _fx.screen.hand_anchor(p)
	return _fx.screen.pile_anchor(p, from)


func _sigil(kind: String, col: Color, radius: float, global_centre: Vector2, life: float) -> FxSigil:
	var s := FxSigil.new()
	s.kind = kind
	s.col = col
	s.radius = radius
	s.position = _fx.fx_pos(global_centre)
	_fx.add_node(s)
	var tw := _fx.new_tween()
	tw.tween_property(s, "t", 1.0, UIStyle.dur(life))
	tw.tween_callback(_fx.free_node.bind(s))
	return s


func _shake_pos(k: float, g: Control, base: Vector2, amp: float) -> void:
	if is_instance_valid(g):
		g.position = base + Vector2(amp * sin(k * TAU * 4.0) * (1.0 - k), 0.0)


# ---------------------------------------------------------------- destruction

## A field card is destroyed (`e.dest` = "spent" | "exhaust"): it cracks and flashes, then burns away
## while dropping toward the pile it ended in (embers for Spent, the void colour for Exhaust).
func destroy(e: Dictionary, prev_mv: Dictionary) -> void:
	var at: Dictionary = e.get("at", {})
	if at.is_empty():
		return
	var p := int(at["p"])
	var zone := String(at["zone"])
	var slot := int(at["slot"])
	var dest := String(e.get("dest", "spent"))
	var col := VOID if dest == "exhaust" else BURN
	var rect: Rect2 = _fx.screen.fx_slot_global_rect(p, zone, slot)
	_fx.burst(FxBurst.Kind.EMBER, rect.get_center(), col, 8, 50.0, 0.5)
	# B5: a card summoned earlier in this batch stands as a held ghost: it is the one destroyed now.
	var held := _fx.take_transient(FxPlayer.transient_key(p, zone, slot))
	var view := ghost_view(e, prev_mv)
	if held != null:
		view = held.view
		_fx.free_node(held)
	if view.has("hidden") and view.size() == 1 and zone != "backrow":
		return
	var rot: bool = zone == "backrow" or (zone == "unit" and String(view.get("stance", "atk")) == "def")
	var g := _ghost(view, Zones.KIND[zone], rot)
	var rest := rect.get_center()
	g.position = _fx.fx_pos(rest - g.size / 2.0)
	_fx.add_node(g)
	var base := g.position
	var to_local := _fx.fx_pos(_origin(int(view.get("owner", p)), dest) - g.size / 2.0)
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		tw.tween_property(g, "modulate:a", 0.0, 0.2)
		tw.tween_callback(_fx.free_node.bind(g))
		return
	_sigil("crack", col, rect.size.length() * 0.5, rest, 0.4)
	g.fx_flash = 0.9
	tw.tween_property(g, "fx_flash", 0.0, UIStyle.dur(0.2))
	tw.parallel().tween_method(_shake_pos.bind(g, base, 7.0), 0.0, 1.0, UIStyle.dur(0.22))
	tw.chain().tween_callback(func(): _fx.burst(FxBurst.Kind.EMBER, rest, col, 14, 70.0, 0.6))
	var mat := _dissolve(g, col)
	tw.tween_method(func(v: float): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, UIStyle.dur(0.55))
	tw.parallel().tween_property(g, "position", base.lerp(to_local, 0.85), UIStyle.dur(0.55)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(g, "scale", Vector2(0.5, 0.5), UIStyle.dur(0.55)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_fx.burst(FxBurst.Kind.EMBER, _origin(int(view.get("owner", p)), dest), col, 6, 30.0, 0.4)
		_fx.free_node(g))


## F12: a still ghost of the card destroyed by `e`, standing in its slot until the killing blow lands
## (the board already shows the slot empty). Returns it (null when hidden or unknown); free it with
## FxPlayer.free_node, normally right before destroy(e) plays at the impact.
func hold_ghost(e: Dictionary, prev_mv: Dictionary) -> CardWidget:
	var at: Dictionary = e.get("at", {})
	if at.is_empty():
		return null
	var zone := String(at["zone"])
	var view := ghost_view(e, prev_mv)
	if view.has("hidden") and view.size() == 1 and zone != "backrow":
		return null
	var rect: Rect2 = _fx.screen.fx_slot_global_rect(int(at["p"]), zone, int(at["slot"]))
	var rot: bool = zone == "backrow" or (zone == "unit" and String(view.get("stance", "atk")) == "def")
	var g := _ghost(view, Zones.KIND[zone], rot)
	g.position = _fx.fx_pos(rect.get_center() - g.size / 2.0)
	_fx.add_node(g)
	return g


# ---------------------------------------------------------------- sacrifice (D6)

## Seconds from the start of a sacrifice to its embers reaching the AP gems (the AP gain plays then).
const SACRIFICE_TO_AP := 0.85
## Seconds the card is offered up (glow, lift, tremble) before it burns and its embers leave.
const SACRIFICE_OFFER := 0.22
## Ember colour of a sacrifice: the AP amber, hotter.
const SACRIFICE_EMBER := Color("ffb347")
const SACRIFICE_EMBERS := 16


## A unit is sacrificed (event `e`: p, at, id, stance, dest): it is consumed instead of vanishing. The
## card glows and trembles, burns away from its edges (dissolve with an amber ember edge) while it sinks a
## little, and a stream of embers drifts from it into its controller's AP gems, where they flare.
func sacrifice(e: Dictionary, prev_mv: Dictionary) -> void:
	var at: Dictionary = e.get("at", {})
	if at.is_empty():
		return
	var p := int(at["p"])
	var slot := int(at["slot"])
	var rect: Rect2 = _fx.screen.fx_slot_global_rect(p, "unit", slot)
	var view := ghost_view(e, prev_mv)
	var g := _ghost(view, "board", String(e.get("stance", view.get("stance", "atk"))) == "def")
	var c := rect.get_center()
	g.position = _fx.fx_pos(c - g.size / 2.0)
	_fx.add_node(g)
	var pl: PlayerPlate = _fx.screen.plate_of(int(e.get("p", p)))
	var gems: Vector2 = pl.ap_gems.get_global_rect().get_center() + Vector2(-40.0, 0.0)
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		g.fx_glow = Color(SACRIFICE_EMBER, 0.8)
		tw.tween_property(g, "modulate:a", 0.0, 0.4)
		tw.tween_callback(_fx.free_node.bind(g))
		return
	var base := g.position
	var mat := burn_material(g, SACRIFICE_EMBER, Color(0.16, 0.06, 0.02))
	burn_step(0.0, g, mat)
	g.fx_glow = Color(SACRIFICE_EMBER, 0.0)
	# Offered up: a warm glow, a lift and a tremble.
	tw.tween_property(g, "fx_glow", Color(SACRIFICE_EMBER, 1.0), UIStyle.dur(0.14))
	tw.parallel().tween_property(g, "position", base + Vector2(0, -10.0), UIStyle.dur(0.18)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_tremble.bind(g), 0.0, 1.0, UIStyle.dur(SACRIFICE_OFFER))
	tw.tween_callback(func():
		_fx.burst(FxBurst.Kind.EMBER, c, SACRIFICE_EMBER, 22, 80.0, 0.9)
		_fx.burst(FxBurst.Kind.SPARK, c, SACRIFICE_EMBER.lightened(0.3), 10, 56.0, 0.35)
		_embers_to(c, gems, rect.size.x * 0.6))
	# Consumed: the fire climbs the card from its foot while it sinks and shrinks a little; embers keep rising.
	tw.tween_method(burn_step.bind(g, mat), 0.0, 1.0, UIStyle.dur(0.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(g, "position", base + Vector2(0, 6.0), UIStyle.dur(0.6))
	tw.parallel().tween_property(g, "scale", Vector2(0.92, 0.92), UIStyle.dur(0.6))
	tw.parallel().tween_property(g, "fx_glow", Color(SACRIFICE_EMBER, 0.35), UIStyle.dur(0.6))
	tw.parallel().tween_callback(func(): _fx.burst(FxBurst.Kind.EMBER, c + Vector2(0, -rect.size.y * 0.2), Color("ffd27a"), 14, 70.0, 0.9)).set_delay(UIStyle.dur(0.25))
	tw.tween_callback(func():
		_fx.burst(FxBurst.Kind.DUST, Vector2(c.x, rect.end.y - 6.0), Color("8a7a66"), 8, 46.0, 0.45)
		_fx.free_node(g))


func _tremble(k: float, g: Control) -> void:
	if is_instance_valid(g):
		g.rotation = sin(k * TAU * 4.0) * 0.04 * (1.0 - k)


## A stream of embers drifting on curved paths from `from_g` into `to_g` (global), arriving about
## SACRIFICE_TO_AP after the start of the sacrifice, each with a small flare where it lands.
func _embers_to(from_g: Vector2, to_g: Vector2, spread: float) -> void:
	for i in SACRIFICE_EMBERS:
		var m := FxSigil.new()
		m.kind = "mote"
		m.col = SACRIFICE_EMBER if i % 3 else Color("ffd27a")
		m.radius = 6.0 + 5.0 * FxBlast.rnd(i, 71.0)
		var start := from_g + Vector2((FxBlast.rnd(i, 72.0) - 0.5) * spread, (FxBlast.rnd(i, 73.0) - 0.5) * spread * 0.8)
		var a := _fx.fx_pos(start)
		var b := _fx.fx_pos(to_g)
		var ctrl := a.lerp(b, 0.5) + Vector2((FxBlast.rnd(i, 74.0) - 0.5) * 160.0, -60.0 - 70.0 * FxBlast.rnd(i, 75.0))
		m.position = a
		m.modulate.a = 0.0
		_fx.add_node(m)
		var tw := _fx.new_tween()
		# The embers leave after the offering (SACRIFICE_OFFER) and all land by SACRIFICE_TO_AP.
		tw.tween_interval(UIStyle.dur(0.02 * float(i)))
		tw.tween_method(_ember_fly.bind(m, a, ctrl, b), 0.0, 1.0, UIStyle.dur(maxf(SACRIFICE_TO_AP - SACRIFICE_OFFER - 0.02 * float(i), 0.2)))
		tw.tween_callback(func():
			_fx.burst(FxBurst.Kind.SPARK, to_g, SACRIFICE_EMBER.lightened(0.3), 5, 18.0, 0.25)
			_fx.free_node(m))


func _ember_fly(k: float, m: Control, a: Vector2, ctrl: Vector2, b: Vector2) -> void:
	if is_instance_valid(m):
		var e2 := ease(k, -1.8)
		m.position = a.lerp(ctrl, e2).lerp(ctrl.lerp(b, e2), e2)
		m.modulate.a = minf(1.0, k * 5.0) * (1.0 - 0.4 * k)


# ---------------------------------------------------------------- exhaust

## A card is exhausted (Exhaust event `e`): it flies to the middle of the board, holds with an
## "Exhausted" caption (named only when the seat may see it), then is pulled into the Exhaust pile.
func exhaust(e: Dictionary, prev_mv: Dictionary) -> void:
	var screen: Control = _fx.screen
	var p := int(e.get("p", 0))
	var layer: Control = screen.banner_layer if screen.banner_layer != null else screen.fx_layer
	var inv := layer.get_global_transform().affine_inverse()
	var area: Rect2 = screen.board_global_rect()
	var centre := inv * area.get_center()
	var view := ghost_view(e, prev_mv)
	var known: bool = not view.has("hidden")
	var from := String(e.get("from", "spent"))
	var origin_g := _origin(p, from)
	var at = e.get("at", {})
	if at is Dictionary and not (at as Dictionary).is_empty():
		var sr: Rect2 = screen.fx_slot_global_rect(int(at["p"]), String(at["zone"]), int(at["slot"]))
		if sr.size != Vector2.ZERO:
			origin_g = sr.get_center()
	var origin := inv * origin_g
	var dest := inv * _origin(p, "exhaust")
	var c := _ghost(view, "big")
	c.z_index = UiLayers.SPOTLIGHT_CARD
	_fx.add_node(c, layer)
	var home := centre - c.size / 2.0
	var bd := _make_backdrop(centre, area)
	_fx.add_node(bd, layer)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _pill_style(0.94, VOID, 16, 18, 3))
	var who := String(view.get("name", "")) if known else ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title_label("EXHAUSTED", 18, VOID.lightened(0.35), 4))
	var sub := UIStyle.label(("%s  ·  %s to Exhaust" % [who, from.capitalize()]) if known else ("A card from %s" % from.capitalize()), 14, UIStyle.TEXT)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sub)
	pill.add_child(row)
	_fx.add_node(pill, layer)
	pill.size = pill.get_combined_minimum_size()
	pill.position = Vector2(centre.x - pill.size.x / 2.0, home.y - pill.size.y - 12.0)
	pill.modulate.a = 0.0
	pill.z_index = UiLayers.SPOTLIGHT_PILL
	bd.modulate.a = 0.0
	var mat := _dissolve(c, VOID)
	var done := func():
		_fx.free_node(bd)
		_fx.free_node(c)
		_fx.free_node(pill)
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		c.position = home
		c.modulate.a = 0.0
		tw.set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, 0.12)
		tw.tween_property(bd, "modulate:a", 1.0, 0.12)
		tw.tween_property(pill, "modulate:a", 1.0, 0.12)
		tw.chain().tween_interval(0.8)
		tw.chain().tween_property(c, "modulate:a", 0.0, 0.15)
		tw.parallel().tween_property(bd, "modulate:a", 0.0, 0.15)
		tw.parallel().tween_property(pill, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(done)
		return
	c.position = origin - c.size / 2.0
	c.scale = Vector2(0.3, 0.3)
	c.modulate.a = 0.0
	tw.set_parallel(true)
	tw.tween_property(bd, "modulate:a", 1.0, UIStyle.dur(0.2))
	tw.tween_property(c, "modulate:a", 1.0, UIStyle.dur(0.1))
	tw.tween_property(c, "position", home, UIStyle.dur(0.32)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, UIStyle.dur(0.32)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		c.fx_glow = Color(VOID, 0.85)
		_fx.burst(FxBurst.Kind.SPARK, area.get_center(), VOID.lightened(0.3), 10, 150.0, 0.45))
	tw.parallel().tween_property(pill, "modulate:a", 1.0, UIStyle.dur(0.14))
	tw.parallel().tween_property(c, "fx_glow", Color(VOID, 0.35), UIStyle.dur(0.4))
	tw.chain().tween_interval(UIStyle.dur(EXHAUST_HOLD))
	# The void takes it: ring collapses at the card while it dissolves and slides into the pile.
	tw.chain().tween_callback(func():
		var sg := FxSigil.new()
		sg.kind = "void"
		sg.col = VOID
		sg.radius = 130.0
		sg.position = centre
		_fx.add_node(sg, layer)
		sg.z_index = UiLayers.SPOTLIGHT_PILL
		var st := _fx.new_tween()
		st.tween_property(sg, "t", 1.0, UIStyle.dur(0.55))
		st.tween_callback(_fx.free_node.bind(sg)))
	tw.tween_method(func(v: float): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, UIStyle.dur(0.55))
	tw.parallel().tween_property(c, "position", dest - c.size / 2.0, UIStyle.dur(0.55)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "scale", Vector2(0.18, 0.18), UIStyle.dur(0.55)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "rotation", deg_to_rad(28.0), UIStyle.dur(0.55))
	tw.parallel().tween_property(bd, "modulate:a", 0.0, UIStyle.dur(0.45))
	tw.parallel().tween_property(pill, "modulate:a", 0.0, UIStyle.dur(0.25))
	tw.chain().tween_callback(func():
		_fx.burst(FxBurst.Kind.SPARK, _origin(p, "exhaust"), VOID.lightened(0.3), 8, 40.0, 0.35)
		done.call())


# ---------------------------------------------------------------- special summons

## One material of a Fusion / Ritual / Arcane summon (event `e`): its card is drawn from where it was
## to the summon slot (`gather`, global), flashes there as it is consumed, and a mote carries it on to
## the pile it really went to (Spent for Fusion / Ritual field materials, Exhaust otherwise).
func material(e: Dictionary, prev_mv: Dictionary, gather: Vector2) -> void:
	var p := int(e.get("p", 0))
	var kind := String(e.get("kind", "fusion"))
	var col := kind_color(kind)
	var dest := String(e.get("to", "spent"))
	var view := ghost_view(e, prev_mv)
	var from := String(e.get("from", "spent"))
	var origin_g := _origin(p, from)
	var at = e.get("at", {})
	if at is Dictionary and not (at as Dictionary).is_empty():
		var sr: Rect2 = _fx.screen.fx_slot_global_rect(int(at["p"]), String(at["zone"]), int(at["slot"]))
		if sr.size != Vector2.ZERO:
			origin_g = sr.get_center()
	var pile_g := _origin(p, dest)
	var g := _ghost(view, "board")
	_fx.add_node(g)
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		g.position = _fx.fx_pos(gather - g.size / 2.0)
		tw.tween_property(g, "modulate:a", 0.0, 0.25)
		tw.tween_callback(_fx.free_node.bind(g))
		return
	g.position = _fx.fx_pos(origin_g - g.size / 2.0)
	g.fx_glow = Color(col, 0.0)
	var target := _fx.fx_pos(gather - g.size / 2.0)
	_fx.burst(FxBurst.Kind.SPARK, origin_g, col, 8, 40.0, 0.3)
	tw.tween_property(g, "fx_glow", Color(col, 0.9), UIStyle.dur(0.12))
	tw.tween_property(g, "position", target, UIStyle.dur(0.4)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(g, "scale", Vector2(0.45, 0.45), UIStyle.dur(0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(g, "rotation", deg_to_rad(randf_range(-18.0, 18.0)), UIStyle.dur(0.4))
	tw.chain().tween_callback(func():
		_fx.burst(FxBurst.Kind.SPARK, gather, col.lightened(0.3), 10, 50.0, 0.3)
		g.fx_flash = 0.8)
	tw.tween_property(g, "modulate:a", 0.0, UIStyle.dur(0.12))
	tw.tween_callback(_fx.free_node.bind(g))
	# The mote that carries the material on to its pile.
	tw.tween_callback(func():
		var m := FxSigil.new()
		m.kind = "mote"
		m.col = VOID if dest == "exhaust" else col
		m.radius = 11.0
		m.position = _fx.fx_pos(gather)
		_fx.add_node(m)
		var mt := _fx.new_tween()
		mt.tween_property(m, "position", _fx.fx_pos(pile_g), UIStyle.dur(0.34)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mt.tween_callback(func():
			_fx.burst(FxBurst.Kind.SPARK, pile_g, (VOID if dest == "exhaust" else col).lightened(0.25), 8, 34.0, 0.3)
			_fx.free_node(m)))
