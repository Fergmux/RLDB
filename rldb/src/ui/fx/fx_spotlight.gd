class_name FxSpotlight
extends FxPart
## Spell/Trap spotlight: a big centred view of a card that was cast or activated (fx event
## "spotlight"). Spotlights run one at a time from their own queue, never overlapping and never
## compressed by FxPlayer.play()'s 3 s batch rule.

## How long a spotlight occupies the screen (fly-in + hold + exit, before UIStyle.dur scaling);
## later effects of the same batch start once it has gone (reduced motion: ~1.24 s).
const HOLD := 1.85
## Spotlights waiting behind the one on screen; the oldest is dropped beyond this.
const MAX_QUEUED := 4
## K1 (owner feedback 2026-10-23): the cue of each presentation, played once as the card lands in the
## centre (its glint): an arcane cast for a Spell (cast from the hand or a set Spell activated), a snap
## and reveal for a Trap. In the mix they sit over the board sounds and under the set-piece climaxes
## (tools/gen_sfx.py PEAK); the calm (reduced motion) variant plays the cue as the card fades in, a
## little softer, like the calm set pieces. Nothing else in the batch sounds while the card is shown
## (FxPlayer holds the rest until it has gone).
const SOUND_SPELL := "spell_cast"
const SOUND_TRAP := "trap_spring"
const CALM_DB := -3.0

## Plays a sound (name, volume dB); tests swap it to count the cues.
var play_sfx: Callable = func(n: String, db: float) -> void: Sfx.play(n, db, 0.0)

var _queue: Array = []
var _active: bool = false


## The cue of the spotlight for fx event `e`: SOUND_TRAP for a Trap, else SOUND_SPELL.
static func sound_for(e: Dictionary) -> String:
	return SOUND_TRAP if String(e.get("how", "cast")) == "trap" else SOUND_SPELL


## True while a spotlight is on screen (or about to be).
func is_active() -> bool:
	return _active


## Drops the queue and forgets the running spotlight (its nodes and tween are freed by FxPlayer).
func reset() -> void:
	_queue.clear()
	_active = false


## Queues the spotlight for fx event `e` and starts it at once when none is running.
func enqueue(e: Dictionary) -> void:
	if _queue.size() >= MAX_QUEUED:
		_queue.pop_front()
	_queue.append(e)
	if not _active:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_active = false
		return
	_active = true
	_show(_queue.pop_front())


func _caption(e: Dictionary) -> String:
	match String(e.get("how", "cast")):
		"activate": return "Spell activated"
		"trap": return "Trap activated"
	var p := int(e.get("p", -1))
	var players: Array = _fx.screen.mv.get("players", [])
	if p >= 0 and p < players.size() and players[p] is Dictionary and String(players[p].get("name", "")) != "":
		return "%s casts" % String(players[p]["name"])
	return "Spell cast"


## Flies a big card from its origin (hand for a cast, else its slot) to the centre of the board over a
## soft dark backdrop, holds ~1 s with a caption pill above it, then shrinks and fades. Click-through;
## everything is removed by finish_all().
func _show(e: Dictionary) -> void:
	var screen: Control = _fx.screen
	var layer: Control = screen.banner_layer if screen.banner_layer != null else screen.fx_layer
	var inv := layer.get_global_transform().affine_inverse()
	var area: Rect2 = screen.board_global_rect()
	var centre := inv * area.get_center()
	var p := int(e.get("p", 0))
	var origin_g: Vector2 = screen.hand_anchor(p)
	if e.get("at") is Dictionary:
		var at: Dictionary = e["at"]
		var sr: Rect2 = screen.fx_slot_global_rect(int(at.get("p", p)), String(at.get("zone", "backrow")), int(at.get("slot", 0)))
		if sr.size != Vector2.ZERO:
			origin_g = sr.get_center()
	var origin := inv * origin_g
	var v: Dictionary = MatchView.summary_view(Series.card_summary(int(e["id"])))
	var accent: Color = UIStyle.CATEGORY_COLORS.get(String(v.get("category", "spell")), UIStyle.GOLD)
	var bd := _make_backdrop(centre, area)
	_fx.add_node(bd, layer)
	# The card.
	var c := CardWidget.new()
	c.show_tooltip = false
	c.auto_hover = false
	c.setup(v, "big")
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.pivot_offset = c.size / 2.0
	c.z_index = UiLayers.SPOTLIGHT_CARD
	_fx.add_node(c, layer)
	var home := centre - c.size / 2.0
	# Caption pill above the card.
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _pill_style(0.94, accent.lightened(0.15), 16, 18, 3))
	var cap := _title_label(_caption(e), 20, UIStyle.TEXT, 4)
	pill.add_child(cap)
	TitleText.apply(cap, TitleText.Tier.HERO, 20)   # D3: "TRAP ACTIVATED" and the other FX banners are T1
	_fx.add_node(pill, layer)
	pill.size = pill.get_combined_minimum_size()
	pill.pivot_offset = pill.size / 2.0
	pill.position = Vector2(centre.x - pill.size.x / 2.0, home.y - pill.size.y - 12.0)
	pill.modulate.a = 0.0
	pill.z_index = UiLayers.SPOTLIGHT_PILL
	var done := func():
		_fx.free_node(bd)
		_fx.free_node(c)
		_fx.free_node(pill)
		_next()
	var snd := sound_for(e)
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		play_sfx.call(snd, CALM_DB)
		c.position = home
		c.modulate.a = 0.0
		tw.set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, 0.12)
		tw.tween_property(bd, "modulate:a", 1.0, 0.12)
		tw.tween_property(pill, "modulate:a", 1.0, 0.12)
		tw.chain().tween_interval(1.0)
		tw.chain().tween_property(c, "modulate:a", 0.0, 0.12)
		tw.parallel().tween_property(bd, "modulate:a", 0.0, 0.12)
		tw.parallel().tween_property(pill, "modulate:a", 0.0, 0.12)
		tw.chain().tween_callback(done)
		return
	c.position = origin - c.size / 2.0
	c.scale = Vector2(0.32, 0.32)
	c.rotation = deg_to_rad(-10.0 if origin.x < centre.x else 10.0)
	c.modulate.a = 0.0
	pill.scale = Vector2(0.7, 0.7)
	# Fly in.
	tw.set_parallel(true)
	tw.tween_property(bd, "modulate:a", 1.0, UIStyle.dur(0.22))
	tw.tween_property(c, "modulate:a", 1.0, UIStyle.dur(0.1))
	tw.tween_property(c, "position", home, UIStyle.dur(0.34)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, UIStyle.dur(0.34)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", 0.0, UIStyle.dur(0.34)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Arrival: glint, accent glow, sparks; the caption pops in.
	tw.chain().tween_callback(func():
		play_sfx.call(snd, 0.0)
		_fx.burst(FxBurst.Kind.SPARK, area.get_center(), accent.lightened(0.4), 12, 170.0, 0.45)
		c.fx_flash = 0.5
		c.fx_glow = Color(accent.lightened(0.2), 0.9))
	tw.parallel().tween_property(c, "fx_flash", 0.0, UIStyle.dur(0.25))
	tw.parallel().tween_property(c, "fx_glow", Color(accent.lightened(0.2), 0.35), UIStyle.dur(0.4))
	tw.parallel().tween_property(pill, "modulate:a", 1.0, UIStyle.dur(0.14))
	tw.parallel().tween_property(pill, "scale", Vector2.ONE, UIStyle.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold ~1 s with a slow breath so it never sits static.
	tw.chain().tween_property(c, "scale", Vector2(1.03, 1.03), UIStyle.dur(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(c, "scale", Vector2.ONE, UIStyle.dur(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Out: shrink, drop slightly and fade.
	tw.chain().tween_property(c, "scale", Vector2(0.6, 0.6), UIStyle.dur(0.24)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "modulate:a", 0.0, UIStyle.dur(0.24))
	tw.parallel().tween_property(c, "position:y", home.y + 24.0, UIStyle.dur(0.24)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(bd, "modulate:a", 0.0, UIStyle.dur(0.24))
	tw.parallel().tween_property(pill, "modulate:a", 0.0, UIStyle.dur(0.16))
	tw.chain().tween_callback(done)
