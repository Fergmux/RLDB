class_name FxPileEffects
extends FxPart
## Card-movement effects between zones and piles: destruction (crack, burn, drop toward Spent),
## Exhaust (card shown front and centre, then pulled into the Exhaust pile in a void colour) and the
## Fusion / Ritual / Arcane special-summon sequence (materials drawn to the summon, then sent to Spent
## or Exhaust, and the unit arriving with a type-specific flourish). Presentation only: every effect
## is an overlay on the already-final board and is removed by FxPlayer.finish_all().
##
## Identity rule: a card is drawn face up only when the event carries `id` (core strips it for seats
## that may not see the card) or the card was face up on the board; otherwise an anonymous card back.

## Colours of the outcomes (proposed; art direction may retune): burn for destruction, cold violet
## for Exhaust. Special-summon colours come from the existing card-category palette.
const BURN := Color("ff8a3a")
const VOID := Color("a47bff")
const KIND_ACCENT := {"fusion": "fusion", "ritual": "ritual", "arcane": "arcane"}
const KIND_SOUND := {"fusion": "fuse", "ritual": "ritual", "arcane": "arcane"}

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
			if slot < arr.size() and arr[slot] is Dictionary:
				return arr[slot]
	if e.has("id"):
		return MatchView.summary_view(Series.card_summary(int(e["id"])))
	return {"hidden": true}


## Anonymous-or-identified card widget used by every ghost: click-through, no hover, no tooltip.
func _ghost(view: Dictionary, kind: String, rotated: bool = false) -> CardWidget:
	var g := CardWidget.new()
	g.show_tooltip = false
	g.auto_hover = false
	g.setup(view, kind, "", rotated)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.pivot_offset = g.size / 2.0
	return g


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
	var view := ghost_view(e, prev_mv)
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


## The special-summoned unit arrives in its slot from the Extra pile with a flourish of its kind:
## Fusion swirl, Ritual light column with rune rings, Arcane hexagram sigil.
func arrive_special(p: int, slot: int, kind: String) -> void:
	var it: Dictionary = _fx.screen.fx_slot_item(p, "unit", slot)
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	var holder: Control = it["holder"]
	_fx.unhide(w)
	var rect: Rect2 = holder.get_global_rect()
	var col := kind_color(kind)
	_fx.add_cleanup(_fx.reset_widget.bind(w, holder))
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		w.modulate.a = 0.0
		w.fx_glow = Color(col, 0.8)
		tw.tween_property(w, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(w, "fx_glow", Color(col, 0.0), 0.3)
		tw.tween_callback(_fx.reset_widget.bind(w, holder))
		return
	var centre := rect.get_center()
	var reach := rect.size.length() * 0.7
	_sigil(kind, col, reach, centre, 0.9 if kind != "arcane" else 1.0)
	if kind == "ritual":
		var ring := FxRuneRing.new()
		ring.col = col
		ring.radius = reach
		ring.position = _fx.fx_pos(centre)
		_fx.add_node(ring)
		var rt := _fx.new_tween()
		rt.tween_property(ring, "t", 1.0, UIStyle.dur(0.8))
		rt.tween_callback(_fx.free_node.bind(ring))
	w.position = _origin(p, "extra") - centre
	w.scale = Vector2(0.4, 0.4)
	w.modulate.a = 0.0
	holder.z_index = UiLayers.FX_CARD
	var wait := UIStyle.dur(0.25)
	tw.set_parallel(true)
	tw.tween_property(w, "modulate:a", 1.0, UIStyle.dur(0.12)).set_delay(wait)
	tw.tween_property(w, "position", Vector2.ZERO, UIStyle.dur(0.4)).set_delay(wait).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.4)).set_delay(wait).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		_fx.burst(FxBurst.Kind.SPARK, centre, col.lightened(0.3), 16, reach, 0.5)
		w.fx_flash = 0.7
		w.fx_glow = Color(col, 0.95))
	tw.tween_property(w, "fx_flash", 0.0, UIStyle.dur(0.25))
	tw.parallel().tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(0.55))
	tw.chain().tween_callback(_fx.reset_widget.bind(w, holder))
