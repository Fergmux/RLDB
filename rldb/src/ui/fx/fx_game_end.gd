class_name FxGameEnd
extends FxPart
## Victory / defeat presentation when a game ends (F03-13), shown over the whole window (F04-04: the
## veil, rays and text cover the sidebar too) before the
## result modal. It is presentation only: the game is already over and the modal (held back through
## FxPlayer.game_end_hold) appears as soon as this finishes or any click skips it.
##
## Four looks: game win (gold light rays and sparks), series win (bigger, longer, more bursts),
## game loss (red-black darkening, a heavy title drop, falling ash) and series loss (darker, longer).

const WIN := Color("f2c14e")
const LOSE := Color("e8605a")
## Seconds each look lasts before the modal (before UIStyle.dur scaling).
const LEN_GAME_WIN := 2.3
const LEN_SERIES_WIN := 3.4
const LEN_GAME_LOSS := 2.1
const LEN_SERIES_LOSS := 3.0

var _active := false
## A2: the winner's name when a spectator watches (neutral wording, the winning look); "" otherwise.
var _spectating_winner := ""


## True while the presentation is on screen.
func is_active() -> bool:
	return _active


## Forgets the running presentation (its nodes and tween are freed by FxPlayer).
func reset() -> void:
	_active = false


## The rect the presentation covers: the whole screen node (field, sidebar and hand), in global coordinates.
static func veil_rect(screen: Control) -> Rect2:
	return screen.get_global_rect()


## Global rect the presentation centres on: the play field, or the whole screen without one.
static func field_rect(screen: Control) -> Rect2:
	if screen.has_method("board_global_rect"):
		var r: Rect2 = screen.board_global_rect()
		if r.size.x > 1.0 and r.size.y > 1.0:
			return r
	return veil_rect(screen)


## The seconds the look for this outcome lasts.
static func length_for(won: bool, series: bool) -> float:
	if won:
		return LEN_SERIES_WIN if series else LEN_GAME_WIN
	return LEN_SERIES_LOSS if series else LEN_GAME_LOSS


## Plays the presentation for the seat being shown: `winner` is the winning seat index.
func start(winner: int) -> void:
	var screen: Control = _fx.screen
	var spectating: bool = bool(screen.call("is_spectator")) if screen.has_method("is_spectator") else false
	var won: bool = winner == screen.me() or spectating
	_spectating_winner = String(screen.view.get("names", ["", ""])[clampi(winner, 0, 1)]) if spectating else ""
	var view: Dictionary = screen.view
	var series: bool = String(view.get("stage", "")) == "over"
	_active = true
	var life := length_for(won, series)
	var layer: Control = screen.banner_layer if screen.banner_layer != null else screen.fx_layer
	var area: Rect2 = veil_rect(screen)
	var inv := layer.get_global_transform().affine_inverse()
	var top_left: Vector2 = inv * area.position
	var col := WIN if won else LOSE
	Sfx.play(("victory_big" if series else "victory") if won else "defeat", 0.0, 0.0)
	# Root veil covering the play area (click-through; a click skips through FxPlayer.finish_all).
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = top_left
	root.size = area.size
	root.clip_contents = true
	root.z_index = UiLayers.GAME_END   # above the sidebar, the hand and every board overlay
	_fx.add_node(root, layer)
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.size = area.size
	dim.color = Color(0.09, 0.06, 0.0, 0.5) if won else Color(0.07, 0.0, 0.0, 0.66)
	dim.modulate.a = 0.0
	root.add_child(dim)
	# Owner feedback 2026-10-18: the veil covers the screen, but the title, rays and bursts centre
	# on the play field (not the screen with the sidebar).
	var field: Rect2 = field_rect(screen)
	var centre: Vector2 = field.get_center() - area.position
	var reduced := UIStyle.reduce_motion
	var fx_node := FxSigil.new()
	fx_node.kind = "rays" if won else "ash"
	fx_node.col = WIN if won else Color("a89a96")
	fx_node.radius = (area.size.length() * (0.75 if series else 0.55)) if won else area.size.x * 0.45
	fx_node.position = centre if won else Vector2(centre.x, centre.y)
	root.add_child(fx_node)
	var band := _band(Vector2(field.size.x, area.size.y), won, col)
	root.add_child(band)
	var title := _title(won, series, col)
	root.add_child(title)
	var sub := _sub_label(won, series, view, col)
	root.add_child(sub)
	title.reset_size()
	sub.reset_size()
	title.position = Vector2(centre.x - title.size.x / 2.0, centre.y - title.size.y / 2.0 - 12.0)
	sub.position = Vector2(centre.x - sub.size.x / 2.0, title.position.y + title.size.y + 6.0)
	title.pivot_offset = title.size / 2.0
	title.modulate.a = 0.0
	sub.modulate.a = 0.0
	band.position = Vector2(field.position.x - area.position.x, title.position.y - 34.0)
	band.size.y = title.size.y + sub.size.y + 80.0
	band.modulate.a = 0.0
	var home := title.position
	var tw := _fx.new_tween()
	if reduced:
		tw.set_parallel(true)
		tw.tween_property(dim, "modulate:a", 1.0, 0.15)
		tw.tween_property(band, "modulate:a", 1.0, 0.15)
		tw.tween_property(title, "modulate:a", 1.0, 0.15)
		tw.tween_property(sub, "modulate:a", 1.0, 0.15)
		tw.chain().tween_interval(minf(life, 1.4))
		tw.chain().tween_property(root, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(_finish.bind(root))
		return
	var d := func(x: float) -> float: return UIStyle.dur(x)
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, d.call(0.35))
	tw.tween_property(band, "modulate:a", 1.0, d.call(0.5)).set_delay(d.call(0.1))
	tw.tween_property(fx_node, "t", 1.0, d.call(life))
	tw.tween_property(sub, "modulate:a", 1.0, d.call(0.3)).set_delay(d.call(0.45))
	if won:
		title.scale = Vector2(0.3, 0.3)
		tw.tween_property(title, "modulate:a", 1.0, d.call(0.12))
		tw.tween_property(title, "scale", Vector2.ONE, d.call(0.55)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var burst_at := field.get_center()
		var bursts: Array = [[0.15, burst_at, 28, 260.0]]
		if series:
			bursts.append([0.55, burst_at + Vector2(-field.size.x * 0.28, field.size.y * 0.12), 22, 200.0])
			bursts.append([0.75, burst_at + Vector2(field.size.x * 0.28, field.size.y * 0.12), 22, 200.0])
			bursts.append([1.25, burst_at + Vector2(0, -field.size.y * 0.2), 30, 300.0])
		for b in bursts:
			tw.tween_callback(func(): _fx.burst(FxBurst.Kind.SPARK, b[1], WIN.lightened(0.25), b[2], b[3], 0.8)).set_delay(d.call(b[0]))
		tw.tween_callback(func(): screen.plate_of(winner).pulse()).set_delay(d.call(0.2))
		# A slow breath while it holds.
		tw.tween_property(title, "scale", Vector2(1.04, 1.04), d.call(0.8)).set_delay(d.call(0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		title.position = home + Vector2(0, -area.size.y * 0.25)
		tw.tween_property(title, "modulate:a", 1.0, d.call(0.2))
		tw.tween_property(title, "position", home, d.call(0.5)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): _fx.shake(root, 9.0)).set_delay(d.call(0.42))
		tw.tween_callback(func(): screen.plate_of(screen.me()).pulse()).set_delay(d.call(0.45))
		# The title sinks slowly while it holds.
		tw.tween_property(title, "position:y", home.y + 16.0, d.call(life - 0.7)).set_delay(d.call(0.7)).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(root, "modulate:a", 0.0, d.call(0.3))
	tw.chain().tween_callback(_finish.bind(root))


func _finish(root: Control) -> void:
	_active = false
	_fx.free_node(root)
	_fx.release_game_end_hold()


## Soft horizontal band behind the title and score line: dark in the middle, fading to nothing at both
## edges, with thin accent lines top and bottom, so the text reads over any board.
func _band(sz: Vector2, won: bool, col: Color) -> Control:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.0))
	g.add_point(0.5, Color(0.03, 0.02, 0.01, 0.62) if won else Color(0.03, 0.0, 0.0, 0.7))
	var tr := TextureRect.new()
	tr.texture = _hgrad(g, 4)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(sz.x, 200.0)
	for edge in 2:
		var lg := Gradient.new()
		lg.set_color(0, Color(col, 0.0))
		lg.set_color(1, Color(col, 0.0))
		lg.add_point(0.5, Color(col.lightened(0.2), 0.85))
		var line := TextureRect.new()
		line.texture = _hgrad(lg, 2)
		line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.stretch_mode = TextureRect.STRETCH_SCALE
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size = Vector2(sz.x * 0.8, 2.0)
		line.position = Vector2(sz.x * 0.1, 0.0)
		tr.add_child(line)
		tr.resized.connect(func(): line.position.y = 0.0 if edge == 0 else tr.size.y - 2.0)
	return tr


func _hgrad(g: Gradient, h: int) -> GradientTexture2D:
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = h
	return gt


func _title(won: bool, series: bool, col: Color) -> Label:
	var text := ("SERIES VICTORY" if series else "VICTORY") if won else ("SERIES LOST" if series else "DEFEAT")
	var fs := (104 if series else 88) if won else (80 if series else 72)
	if _spectating_winner != "":
		text = "%s WINS" % _spectating_winner.to_upper()
		fs = 84 if series else 72
	var l := UIStyle.label(text, fs, col.lightened(0.15) if won else col, false, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# D3: the T1 hero treatment (metal gradient, outline, two shadows, glow, sweep); the ember
	# palette for a defeat. A spectator's "X WINS" is the gold hero.
	var hero := won or _spectating_winner != ""
	TitleText.apply(l, TitleText.Tier.HERO if hero else TitleText.Tier.HERO_DEFEAT, fs)
	return l


func _sub_label(won: bool, series: bool, view: Dictionary, col: Color) -> Label:
	var scores: Array = view.get("scores", [0, 0])
	var me: int = int(view.get("you", 0))
	var text := ""
	if _spectating_winner != "":
		var hi := maxi(int(scores[0]), int(scores[1]))
		var lo := mini(int(scores[0]), int(scores[1]))
		text = ("Series won %d - %d" % [hi, lo]) if series else ("Game %d   ·   score %d - %d" % [int(view.get("game_no", 1)), scores[0], scores[1]])
	elif series:
		text = "You win the series %d - %d" % [scores[me], scores[1 - me]] if won else "Your opponent wins the series %d - %d" % [scores[1 - me], scores[me]]
	else:
		text = "You win game %d   ·   score %d - %d" % [int(view.get("game_no", 1)), scores[me], scores[1 - me]] if won else "You lose game %d   ·   score %d - %d" % [int(view.get("game_no", 1)), scores[me], scores[1 - me]]
	var l := UIStyle.label(text, 24, UIStyle.TEXT, false, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleText.apply(l, TitleText.Tier.MENU, 24)   # ivory with the T2 outline and shadows
	return l
