class_name FxSerpent
extends FxPart
## The Divine Serpents' strike (B5, owner feedback 2026-10-20). When a Serpent's On Summon finds two
## adjacent Serpents, the opponent takes 30 damage and every Serpent is destroyed. The batch carries the
## summon, the damage and the destructions together; instead of three plain destructions and a small HP
## number, the Serpents rise from their slots, coil together into one spirit serpent (the cards are
## consumed into it, their slots crack and their remains drop to Spent), the serpent rears back and
## strikes the opponent's HP plate: a big water blast, a shockwave, a camera shake and the damage number,
## with the HP bar held at its old value until the blow lands.
##
## Presentation only: the board already shows the final state. Everything goes through FxPlayer, so a
## click (finish_all) snaps it away, restores the plate and leaves the real board.

## Prefix of the card names that make the strike.
const NAME_PREFIX := "Divine Serpent"
## Seconds of the set piece and of its phases (before UIStyle.dur): the cards rise, merge into the coil,
## the serpent rears, strikes and lands, then the spray settles.
const LEN := 2.15
const FORM_AT := 0.35
const REAR_AT := 0.95
const STRIKE_AT := 1.3
const IMPACT_AT := 1.48
## Seconds of the calm (reduced motion) variant.
const CALM_LEN := 0.9
## Water colours of the spirit.
const WATER := Color("5fd4ff")
const DEEP := Color("0b3d66")


## Seconds the set piece holds the rest of its batch.
static func length_for() -> float:
	return CALM_LEN if UIStyle.reduce_motion else LEN


## The Serpent strike in `events`, or {}: an HP loss of one player directly followed by the destruction of
## at least two of the other player's units named "Divine Serpent ...". {hp: index, d: damage dealt,
## opp: the damaged player, p: the Serpents' controller, destroys: [indices]}. `name_of(id) -> String`
## names a card id (the card database by default; tests may pass their own).
static func detect(events: Array, name_of: Callable = Callable()) -> Dictionary:
	var namer := name_of if name_of.is_valid() else func(id: int) -> String: return String(Series.card_summary(id).get("name", ""))
	for i in events.size():
		var e: Dictionary = events[i]
		if String(e.get("k", "")) != "hp" or int(e.get("d", 0)) >= 0:
			continue
		var opp := int(e.get("p", -1))
		var dl: Array = []
		for j in range(i + 1, events.size()):
			var d: Dictionary = events[j]
			if String(d.get("k", "")) != "destroy":
				break
			var at: Dictionary = d.get("at", {})
			if int(at.get("p", -1)) != 1 - opp or String(at.get("zone", "")) != "unit" or not d.has("id"):
				break
			if not String(namer.call(int(d["id"]))).begins_with(NAME_PREFIX):
				break
			dl.append(j)
		if dl.size() >= 2:
			return {"hp": i, "d": -int(e["d"]), "opp": opp, "p": 1 - opp, "destroys": dl}
	return {}


## Holds the struck plate's HP bar at its value before the strike from the moment the batch arrives (the
## board renders the final HP at once); the impact or a click releases it. FxPlayer.play() calls it.
func prepare(info: Dictionary) -> void:
	var pl: PlayerPlate = _fx.screen.plate_of(int(info["opp"]))
	if is_instance_valid(pl) and not pl.hp_held():
		_hold_hp(pl, int(info["d"]))


## Plays the strike `info` (from detect()) of `events`. `lethal` is the killing-blow info when this
## damage ends the game ({} otherwise): the victory / defeat look then starts after the impact.
func play(info: Dictionary, events: Array, prev_mv: Dictionary, lethal: Dictionary = {}) -> void:
	var screen: Control = _fx.screen
	var p := int(info["p"])
	var opp := int(info["opp"])
	var pl: PlayerPlate = screen.plate_of(opp)
	var plate_c: Vector2 = pl.get_global_rect().get_center()
	var reduced := UIStyle.reduce_motion
	if not pl.hp_held():
		_hold_hp(pl, int(info["d"]))
	# The Serpent cards: each one's ghost stands in its slot (the slot itself is already empty).
	var ghosts: Array = []
	var slots: Array = []
	for j in info["destroys"]:
		var de: Dictionary = events[j]
		var at: Dictionary = de["at"]
		var key := FxPlayer.transient_key(int(at["p"]), "unit", int(at["slot"]))
		var g: CardWidget = _fx.take_transient(key)
		if g == null:
			g = _fx.destroy_ghost(de, prev_mv)
		if g == null:
			continue
		g.modulate.a = 1.0
		ghosts.append(g)
		slots.append(screen.fx_slot_global_rect(int(at["p"]), "unit", int(at["slot"])).get_center())
	if reduced:
		_calm(ghosts, pl, int(info["d"]), lethal)
		return
	var centroid := Vector2.ZERO
	for c in slots:
		centroid += c
	centroid = centroid / float(maxi(slots.size(), 1)) if not slots.is_empty() else screen.side_center(p)
	var board: Rect2 = screen.board_global_rect()
	var coil := centroid.lerp(board.get_center(), 0.45) + Vector2(0, -20.0)
	var win: Rect2 = screen.get_global_rect()
	var reach := clampf(minf(win.size.x, win.size.y) * 0.17, 100.0, 180.0)
	Sfx.play("serpent_coil", 0.0, 0.0)
	_fx.vignette(0.85, 0.3, IMPACT_AT, 0.6, Color(0.0, 0.02, 0.05))
	var glow := FxSerpentArt.new()
	glow.glow_only = true
	var art := FxSerpentArt.new()
	art.col = WATER
	art.rim = DEEP
	art.radius = reach
	art.target = plate_c - coil
	art.life = LEN
	art.form_at = FORM_AT
	art.rear_at = REAR_AT
	art.strike_at = STRIKE_AT
	art.impact_at = IMPACT_AT
	art.position = _fx.fx_pos(coil)
	for prop in ["col", "rim", "radius", "target", "life", "form_at", "rear_at", "strike_at", "impact_at", "position"]:
		glow.set(prop, art.get(prop))
	_fx.add_node(glow)
	_fx.add_node(art)
	var ta := _fx.new_tween()
	ta.set_parallel(true)
	ta.tween_property(art, "t", 1.0, UIStyle.dur(LEN))
	ta.tween_property(glow, "t", 1.0, UIStyle.dur(LEN))
	ta.chain().tween_callback(func():
		_fx.free_node(art)
		_fx.free_node(glow))
	for i in ghosts.size():
		_rise_and_merge(ghosts[i], slots[i], coil, float(i) * 0.06, p)
	var ti := _fx.new_tween()
	ti.tween_interval(UIStyle.dur(STRIKE_AT - 0.05))
	ti.tween_callback(func(): Sfx.play("serpent_strike", 0.0, 0.0))
	ti.tween_interval(UIStyle.dur(IMPACT_AT - STRIKE_AT + 0.05))
	ti.tween_callback(_impact.bind(pl, plate_c, int(info["d"]), reach, lethal))


## One Serpent card: glows and lifts out of its slot (a water ring at its foot), then spirals up into the
## coil, shrinking and dissolving into the forming serpent, while its slot cracks and its remains fall to Spent.
func _rise_and_merge(g: CardWidget, slot_c: Vector2, coil: Vector2, delay: float, p: int) -> void:
	g.pivot_offset = g.size / 2.0
	g.fx_glow = Color(WATER, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = load(FxCardEffects.DISSOLVE_SHADER)
	mat.set_shader_parameter("edge_color", WATER.lightened(0.3))
	g.material = mat
	var ring := FxRuneRing.new()
	ring.col = WATER
	ring.radius = g.size.length() * 0.45
	ring.position = _fx.fx_pos(slot_c)
	_fx.add_node(ring)
	var rt := _fx.new_tween()
	rt.tween_interval(UIStyle.dur(delay))
	rt.tween_property(ring, "t", 1.0, UIStyle.dur(0.6))
	rt.tween_callback(_fx.free_node.bind(ring))
	var lift := slot_c + Vector2(0, -26.0)
	var start_ang := (slot_c - coil).angle()
	var dist := slot_c.distance_to(coil)
	var path := func(k: float) -> void:
		if not is_instance_valid(g):
			return
		var e := FxSummonArt._in(k, 1.5)
		var ang := start_ang + e * TAU * 0.9
		var pos := coil + Vector2(cos(ang), sin(ang) * 0.55) * dist * (1.0 - e)
		pos = pos.lerp(lift, (1.0 - k) * (1.0 - k) * 0.6)
		g.position = _fx.fx_pos(pos - g.size / 2.0)
		var sc := lerpf(1.1, 0.3, e)
		g.scale = Vector2(sc, sc)
		g.rotation = e * 3.2
		mat.set_shader_parameter("dissolve", clampf((k - 0.25) / 0.75, 0.0, 1.0))
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(delay))
	tw.tween_property(g, "fx_glow", Color(WATER, 1.0), UIStyle.dur(0.18))
	tw.parallel().tween_property(g, "position", _fx.fx_pos(lift - g.size / 2.0), UIStyle.dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "scale", Vector2(1.1, 1.1), UIStyle.dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		# The slot it left: cracks, embers and the remains dropping to the Spent pile (the destruction).
		Sfx.play("destroy", -4.0, 0.06)
		var cr := FxSigil.new()
		cr.kind = "crack"
		cr.col = WATER
		cr.radius = g.size.length() * 0.5
		cr.position = _fx.fx_pos(slot_c)
		_fx.add_node(cr)
		var ct := _fx.new_tween()
		ct.tween_property(cr, "t", 1.0, UIStyle.dur(0.5))
		ct.tween_callback(_fx.free_node.bind(cr))
		_fx.burst(FxBurst.Kind.EMBER, slot_c, WATER.lightened(0.3), 12, 56.0, 0.6)
		var pile: Vector2 = _fx.screen.pile_anchor(p, "spent")
		var mo := FxSigil.new()
		mo.kind = "mote"
		mo.col = WATER
		mo.radius = 9.0
		mo.position = _fx.fx_pos(slot_c)
		_fx.add_node(mo)
		var mt := _fx.new_tween()
		mt.tween_property(mo, "position", _fx.fx_pos(pile), UIStyle.dur(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mt.tween_callback(func():
			_fx.burst(FxBurst.Kind.SPARK, pile, WATER.lightened(0.3), 8, 30.0, 0.3)
			_fx.free_node(mo)))
	tw.tween_method(path, 0.0, 1.0, UIStyle.dur(REAR_AT - FORM_AT))
	tw.tween_callback(func():
		_fx.burst(FxBurst.Kind.SPARK, coil, WATER.lightened(0.5), 10, 50.0, 0.35)
		_fx.free_node(g))


## The serpent lands on the plate: water blast, sparks, flash, shockwave, shake, the HP bar drops and the
## big damage number slams in.
func _impact(pl: PlayerPlate, c: Vector2, dmg: int, reach: float, lethal: Dictionary) -> void:
	Sfx.play("boom", -4.0, 0.0)
	Sfx.play("damage", 0.0, 0.0)
	_release_hp(pl, false, not lethal.is_empty())   # a killing strike shatters the vial
	if is_instance_valid(pl):
		pl.pulse()
		_fx.shake(pl, 12.0)
		var z0 := pl.z_index
		pl.z_index = UiLayers.FX + 1   # the struck plate reads above its own blast (UI review F12)
		_fx.add_cleanup(func(): if is_instance_valid(pl): pl.z_index = z0)
		var zt := _fx.new_tween()
		zt.tween_interval(UIStyle.dur(1.2))
		zt.tween_callback(func(): if is_instance_valid(pl): pl.z_index = z0)
	var b := FxBlast.new()
	b.look = FxBlast.Look.BLAST
	b.col = WATER
	b.radius = reach * 1.6
	b.position = _fx.fx_pos(c)
	_fx.add_node(b)
	var tb := _fx.new_tween()
	tb.tween_property(b, "t", 1.0, UIStyle.dur(1.25))
	tb.tween_callback(_fx.free_node.bind(b))
	_fx.burst(FxBurst.Kind.SPARK, c, WATER.lightened(0.5), 34, reach * 2.6, 0.8)
	_fx.burst(FxBurst.Kind.EMBER, c, Color(0.85, 0.97, 1.0), 30, reach * 2.0, 1.1)
	_fx.screen_flash(Color(0.88, 0.97, 1.0), 0.58, 0.02, 0.1, c)
	_fx.distort(c, reach * 3.6, 0.7, 26.0, 0.0, Color(WATER, 0.12))
	_fx.camera_shake(20.0, 0.8)
	_fx.damage_number(c, dmg, WATER, 120)
	if not lethal.is_empty():
		var tl := _fx.new_tween()
		tl.tween_interval(UIStyle.dur(0.9))
		tl.tween_callback(func(): _fx.start_game_end(int(lethal["winner"])))


## Reduced motion: the Serpent ghosts glow and fade where they stand, then the plate takes the damage.
func _calm(ghosts: Array, pl: PlayerPlate, dmg: int, lethal: Dictionary) -> void:
	for g in ghosts:
		var cw: CardWidget = g
		cw.fx_glow = Color(WATER, 0.9)
		var tg := _fx.new_tween()
		tg.tween_interval(0.25)
		tg.tween_property(cw, "modulate:a", 0.0, 0.35)
		tg.tween_callback(_fx.free_node.bind(cw))
	var tw := _fx.new_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func():
		Sfx.play("damage", 0.0, 0.0)
		_release_hp(pl, false, not lethal.is_empty())
		_fx.damage_number(pl.get_global_rect().get_center(), dmg, WATER, 96)
		if not lethal.is_empty():
			_fx.start_game_end(int(lethal["winner"])))


## Holds the plate's HP vial at the value before the strike (the board already shows the result); a
## click (finish_all) or the impact releases it to the real value (PlayerPlate.hold_hp).
func _hold_hp(pl: PlayerPlate, dmg: int) -> void:
	if not is_instance_valid(pl) or pl.hp_held():
		return
	pl.hold_hp(pl.hp_bar.hp + dmg)
	_fx.add_cleanup(_release_hp.bind(pl, true))


## Releases the hold: the vial's damage trail runs from the held value, or it snaps (`snap`, a click);
## `shatter` breaks the glass when the strike is the killing blow.
func _release_hp(pl: PlayerPlate, snap: bool = false, shatter: bool = false) -> void:
	if not is_instance_valid(pl):
		return
	pl.release_hp(snap, shatter)
