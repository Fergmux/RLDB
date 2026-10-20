class_name FxResourceEffects
extends FxPart
## Effects on player resources and card flow: HP / AP change floaters on the player plates, the
## opponent's draw (card backs flying hand-ward) and the end-of-turn discard to the Spent pile.
## D6 (owner feedback 2026-10-20): every HP / AP change also gets a small flourish on the display that
## changed: a heal sends green motes up the HP bar under a light sweep, damage throws red sparks off it,
## an AP gain sparkles amber over the gems and an AP loss lets a dim puff fall from them. Their sounds
## (heal / damage / ap_gain / ap_loss) are scheduled once per event by FxPlayer (Sfx.for_fx).

## Most opponent card backs drawn for one draw event.
const MAX_DRAW_GHOSTS := 5
## Most opponent card backs flown to the Spent pile for one discard event.
const MAX_DISCARD_GHOSTS := 6
## Flourish colours.
const HEAL_COL := Color("7ee08a")
const HURT_COL := Color("ff6b5e")
const AP_LOSS_COL := Color("8f7f9e")


## HP change `d` for player `p`: a floating number, a plate pulse and, for damage, a shake. `quiet` drops
## the number (a direct attack already showed the damage as its own big number).
func hp(p: int, d: int, quiet: bool = false) -> void:
	if d == 0:
		return
	var pl: PlayerPlate = _fx.screen.plate_of(p)
	var heal := d > 0
	if not quiet:
		_fx.float_text(("+%d" % d) if heal else ("%d" % d), UIStyle.GOOD if heal else Color("ff6b5e"), pl.hp_anchor(), 28, 22.0, 0.7)
	pl.pulse()
	if not heal:
		_fx.shake(pl, 5.0)
	_hp_flourish(pl, heal, absi(d))


## AP change `d` for player `p`: a floating "+N AP" / "-N AP" over the plate.
func ap(p: int, d: int) -> void:
	if d == 0:
		return
	var pl: PlayerPlate = _fx.screen.plate_of(p)
	_fx.float_text(("%+d AP" % d), UIStyle.COST_COLORS["ap"] if d > 0 else AP_LOSS_COL.lightened(0.3), pl.ap_anchor(), 17, 22.0, 0.7, true, false)
	_ap_flourish(pl, d > 0)


## HP flourish on `pl`'s bar: a heal sends green motes up from it under a bright sweep running along
## the bar; damage throws red sparks off the end of the fill. Bigger changes throw more.
func _hp_flourish(pl: PlayerPlate, heal: bool, amount: int) -> void:
	var r := pl.hp_bar.get_global_rect()
	var n := clampi(6 + amount / 2, 6, 18)
	if heal:
		_fx.burst(FxBurst.Kind.EMBER, Vector2(r.position.x + r.size.x * 0.5, r.position.y + 4.0), HEAL_COL, n, r.size.x * 0.55, 0.8)
		_sweep(r, HEAL_COL)
	else:
		var frac := clampf(float(pl.hp_bar.hp) / float(maxi(1, pl.hp_bar.max_hp)), 0.0, 1.0)
		var edge := Vector2(r.position.x + r.size.x * frac, r.get_center().y)
		_fx.burst(FxBurst.Kind.SPARK, edge, HURT_COL.lightened(0.2), n, 40.0 + float(amount), 0.4)
		_fx.burst(FxBurst.Kind.EMBER, edge, Color("ffb08a"), maxi(4, n / 2), 36.0, 0.55)


## AP flourish on `pl`'s gems: a gain sparkles amber over them, a loss lets a dim puff fall from them.
func _ap_flourish(pl: PlayerPlate, gain: bool) -> void:
	var r := pl.ap_gems.get_global_rect()
	var c := Vector2(r.position.x + minf(r.size.x * 0.35, 80.0), r.get_center().y)
	if gain:
		_fx.burst(FxBurst.Kind.SPARK, c, UIStyle.COST_COLORS["ap"].lightened(0.35), 12, 34.0, 0.4)
		_fx.burst(FxBurst.Kind.EMBER, c, UIStyle.GOLD_HI, 6, 30.0, 0.6)
		_sweep(r, UIStyle.COST_COLORS["ap"])
	else:
		_fx.burst(FxBurst.Kind.DUST, c + Vector2(0, 6.0), AP_LOSS_COL, 8, 30.0, 0.5)


## A soft additive light band sweeping left to right across the global rect `r` (skipped under reduced motion).
func _sweep(r: Rect2, col: Color) -> void:
	if UIStyle.reduce_motion:
		return
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.5, Color(col.lightened(0.5), 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	var band := TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	band.material = mat
	# Clipped to the display it crosses, so the light never spills past the bar.
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.position = _fx.fx_pos(r.position)
	clip.size = r.size
	_fx.add_node(clip)
	var w := maxf(r.size.y * 2.4, 36.0)
	band.size = Vector2(w, r.size.y)
	band.position = Vector2(-w, 0.0)
	clip.add_child(band)
	var tw := _fx.new_tween()
	tw.tween_property(band, "position:x", r.size.x, UIStyle.dur(0.42)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_fx.free_node.bind(clip))


## Opponent `p` draws `n` cards: card backs fly from their Draw pile to their hand.
func draw_opp(p: int, n: int) -> void:
	if UIStyle.reduce_motion:
		return
	var from: Vector2 = _fx.screen.pile_anchor(p, "draw")
	var to: Vector2 = _fx.screen.hand_anchor(p)
	for i in mini(n, MAX_DRAW_GHOSTS):
		var g := CardWidget.new().setup(_hidden_hand_view(), "back")
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.auto_hover = false
		g.modulate.a = 0.0
		g.scale = Vector2(0.6, 0.6)
		g.position = _fx.fx_pos(from) - g.size / 2.0
		_fx.add_node(g)
		var dest := _fx.fx_pos(to) - g.size / 2.0
		var tw := _fx.new_tween()
		tw.tween_interval(UIStyle.dur(0.07) * i)
		tw.set_parallel(false)
		tw.tween_property(g, "modulate:a", 1.0, UIStyle.dur(0.05))
		tw.set_parallel(true)
		tw.tween_property(g, "position", dest, UIStyle.dur(0.28)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "scale", Vector2.ONE, UIStyle.dur(0.28))
		tw.tween_property(g, "modulate:a", 0.0, UIStyle.dur(0.08)).set_delay(UIStyle.dur(0.22))
		tw.chain().tween_callback(_fx.free_node.bind(g))


## End of turn: the cards left in hand fly to the Spent pile (your own cards face up, the
## opponent's as backs from their hand). The ghosts are independent of finish_all(): a hot-seat
## seat switch right after the turn ends does not cut them off, and their destination follows the
## owner's Spent pile wherever it is drawn now.
func discard(p: int, n: int) -> void:
	if UIStyle.reduce_motion:
		return
	var screen: Control = _fx.screen
	var ghosts := []
	if p == screen.me():
		for g in screen.gone_hand_cards():
			ghosts.append([g["c"], g["v"]])
	else:
		for i in mini(n, MAX_DISCARD_GHOSTS):
			ghosts.append([screen.hand_anchor(p) + Vector2(float(i) * 14.0 - 35.0, 0), _hidden_hand_view()])
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
		w.position = _fx.fx_pos(from) - w.size / 2.0
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
			w.position = _fx.fx_pos(from.lerp(to, e2)) - w.size / 2.0
			w.scale = Vector2.ONE.lerp(Vector2(0.55, 0.55), e2)
			w.rotation = rot * e2
			w.modulate.a = 1.0 if k < 0.82 else clampf((1.0 - k) / 0.18, 0.0, 1.0)
		var tw: Tween = screen.create_tween()
		tw.tween_interval(UIStyle.dur(0.06) * i)
		tw.tween_method(fly, 0.0, 1.0, UIStyle.dur(0.45))
		tw.tween_callback(w.queue_free)
		i += 1


## Fresh face-down view for the opponent's ghost cards (CardWidget keeps the dictionary it is given).
func _hidden_hand_view() -> Dictionary:
	return {"hidden": true, "zone": "hand"}
