class_name FxResourceEffects
extends FxPart
## Effects on player resources and card flow: HP / AP change floaters on the player plates, the
## opponent's draw (card backs flying hand-ward) and the end-of-turn discard to the Spent pile.

## Most opponent card backs drawn for one draw event.
const MAX_DRAW_GHOSTS := 5
## Most opponent card backs flown to the Spent pile for one discard event.
const MAX_DISCARD_GHOSTS := 6


## HP change `d` for player `p`: a floating number, a plate pulse and, for damage, a shake.
func hp(p: int, d: int) -> void:
	if d == 0:
		return
	var pl: PlayerPlate = _fx.screen.plate_of(p)
	var heal := d > 0
	_fx.float_text(("+%d" % d) if heal else ("%d" % d), UIStyle.GOOD if heal else Color("ff6b5e"), pl.hp_anchor(), 28, 22.0, 0.7)
	pl.pulse()
	if not heal:
		_fx.shake(pl, 5.0)


## AP change `d` for player `p`: a floating "+N AP" / "-N AP" over the plate.
func ap(p: int, d: int) -> void:
	if d == 0:
		return
	var pl: PlayerPlate = _fx.screen.plate_of(p)
	_fx.float_text(("%+d AP" % d), UIStyle.COST_COLORS["ap"], pl.ap_anchor(), 17, 22.0, 0.7, true, false)


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
