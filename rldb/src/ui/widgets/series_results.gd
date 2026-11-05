class_name SeriesResults
extends Control
## L26 (owner, 5 Nov): the series results in full: both players with their wins as faceted gems in
## their seat colour around a gilded Best-of coin, "first to n wins", then one medallion per game of
## the series (the winner's gem, name and turns; the game being played or next breathing; games the
## series no longer needs dimmed) and, once it is decided, the series winner under a laurel. Shown in
## the View lobby list, as the hover card of the top strip's SeriesScoreboard, and (its game rows) in
## the sidebar between games. Display only: everything comes from the series view.
##
##     var r := SeriesResults.new().setup(SeriesResults.model(view, me))

## Width of the card and the heights of its bands (px).
const W := 352.0
const HEAD_H := 76.0
const CAPTION_Y := 92.0
const RULE_Y := 104.0
const STRIP_Y := 132.0
const H := 196.0
## The coin, the player gems and the game medallions (radius, px).
const COIN_R := 30.0
const GEM_R := 9.0
const GEM_STEP := 22.0
const GAME_R := 15.0
## The colour of each seat (the lobby list and chat use the same, GameChat.SEAT_COLORS).
const SEAT_COLORS := [Color("f0b75e"), Color("79c2f2")]

## The series shown (SeriesResults.model).
var m: Dictionary = {}
## Seconds clock (tests and frozen shots inject one).
var clock: Callable = func() -> float: return float(Time.get_ticks_msec()) / 1000.0
var _breath: Control


## The series of `view` as seen by seat `me` (my side drawn on the left):
## {best_of, need, names, scores, results (winner seat per finished game), turns, forfeit (per game),
##  current (index of the game being played or next, -1 once decided), over, winner (seat or -1),
##  leader (seat ahead, -1 when level), me, stage, playing (a game is in progress)}.
static func model(view: Dictionary, me: int) -> Dictionary:
	var best := maxi(1, int(view.get("best_of", 3)))
	var need := best / 2 + 1
	var hist: Array = view.get("history", [])
	var res := []
	var turns := []
	var forfeits := []
	for h in hist:
		res.append(int(h.get("winner", 0)))
		turns.append(int(h.get("turns", 0)))
		forfeits.append(bool(h.get("forfeit", false)))
	var sc: Array = view.get("scores", [0, 0])
	var scores := [int(sc[0]) if sc.size() > 0 else 0, int(sc[1]) if sc.size() > 1 else 0]
	var stage := String(view.get("stage", ""))
	var forfeit_by := int(view.get("forfeit_by", -1))
	var winner := -1
	if forfeit_by in [0, 1]:
		winner = 1 - forfeit_by
	elif scores[0] >= need or scores[1] >= need:
		winner = 0 if scores[0] > scores[1] else 1
	var over := stage == "over" or winner != -1
	var names: Array = view.get("names", ["Player 1", "Player 2"])
	return {"best_of": best, "need": need, "names": [String(names[0]) if names.size() > 0 else "", String(names[1]) if names.size() > 1 else ""],
		"scores": scores, "results": res, "turns": turns, "forfeit": forfeits,
		"current": -1 if over else mini(res.size(), best - 1), "over": over, "winner": winner,
		"leader": -1 if scores[0] == scores[1] else (0 if scores[0] > scores[1] else 1),
		"me": clampi(me, 0, 1), "stage": stage, "playing": stage == "game"}


## True when `view` is a series worth showing results for (more than one game, not a tutorial).
static func shows_for(view: Dictionary) -> bool:
	return not view.is_empty() and int(view.get("best_of", 1)) > 1 and String(view.get("mode", "")) != "tutorial" \
		and String(view.get("stage", "")) != ""


## Player-facing one-line summary ("Ana 2 – 1 Ben · Best of 3, first to 2").
static func summary(md: Dictionary) -> String:
	var me: int = md["me"]
	var line := "%s %d – %d %s" % [md["names"][me], md["scores"][me], md["scores"][1 - me], md["names"][1 - me]]
	if bool(md["over"]) and int(md["winner"]) != -1:
		return "%s · %s wins the series" % [line, md["names"][md["winner"]]]
	return "%s · Best of %d, first to %d" % [line, md["best_of"], md["need"]]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	_breath = Control.new()
	_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_breath.draw.connect(_draw_breath)
	add_child(_breath, false, Node.INTERNAL_MODE_FRONT)


## Shows series `md` (SeriesResults.model).
func setup(md: Dictionary) -> SeriesResults:
	m = md
	name = "SeriesResults"
	queue_redraw()
	_breath.queue_redraw()
	return self


func _process(_d: float) -> void:
	if not m.is_empty() and int(m["current"]) >= 0 and is_visible_in_tree() and not UIStyle.reduce_motion:
		_breath.queue_redraw()


## Centre of game medallion `i`.
func game_pos(i: int) -> Vector2:
	var n: int = m.get("best_of", 3)
	var slot := minf(84.0, size.x / float(n))
	var x0 := size.x / 2.0 - slot * float(n - 1) / 2.0
	return Vector2(x0 + slot * i, STRIP_Y)


## Width of one game slot (its labels are fitted to it).
func _slot_w() -> float:
	return minf(84.0, size.x / float(maxi(1, int(m.get("best_of", 3)))))


func _draw() -> void:
	if m.is_empty():
		return
	var me: int = m["me"]
	var cx := size.x / 2.0
	var coin_c := Vector2(cx, 38.0)
	# The laurel of the series winner around the coin; while undecided, a half laurel on the leader's side.
	var lead: int = int(m["winner"]) if bool(m["over"]) else int(m["leader"])
	if lead != -1:
		var side := -1.0 if lead == me else 1.0
		Laurel.draw_branch(self, coin_c, COIN_R + 7.0, side, Color(UIStyle.GOLD_HI, 0.95 if bool(m["over"]) else 0.7))
		if bool(m["over"]):
			Laurel.draw_branch(self, coin_c, COIN_R + 7.0, -side, Color(UIStyle.GOLD_HI, 0.95))
	CoinArt.draw_coin(self, coin_c, COIN_R, int(m["best_of"]))
	for k in 2:
		var seat: int = me if k == 0 else 1 - me
		_draw_side(seat, k == 0, coin_c)
	# Caption: the target, or the winner once decided.
	var f := UIStyle.font_display(600)
	if bool(m["over"]) and int(m["winner"]) != -1:
		var w: int = m["winner"]
		var txt := "%s WINS THE SERIES  %d – %d" % [String(m["names"][w]).to_upper(), m["scores"][w], m["scores"][1 - w]]
		Txt.centred(self, f, _fit(f, txt, size.x - 8.0, 13), Vector2(cx, CAPTION_Y), 13, UIStyle.GOLD_HI)
	else:
		Txt.centred(self, f, "FIRST TO %d WINS" % int(m["need"]), Vector2(cx, CAPTION_Y), 11, Color(UIStyle.GOLD, 0.8))
	# A fine gold rule with a diamond in the middle.
	var ry := RULE_Y
	draw_line(Vector2(18, ry), Vector2(cx - 8, ry), Color(UIStyle.GOLD, 0.35), 1.0, true)
	draw_line(Vector2(cx + 8, ry), Vector2(size.x - 18, ry), Color(UIStyle.GOLD, 0.35), 1.0, true)
	Ornate.diamond(self, Vector2(cx, ry), 3.5, Color(UIStyle.GOLD, 0.7))
	for i in int(m["best_of"]):
		_draw_game(i)


## One player's side of the head band: name, wins as gems (sockets for the wins still needed) and the
## score, mirrored for the right side.
func _draw_side(seat: int, left: bool, coin_c: Vector2) -> void:
	var col: Color = SEAT_COLORS[seat]
	var dir := -1.0 if left else 1.0
	var inner := coin_c.x + dir * (COIN_R + 14.0)
	var f := UIStyle.font_display(700)
	var fs := UIStyle.font_display(600)
	# The score, big, beside the coin.
	var score := str(int(m["scores"][seat]))
	var lead := int(m["leader"]) == seat or (bool(m["over"]) and int(m["winner"]) == seat)
	var sw := f.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var sx := inner - sw if left else inner
	draw_string(f, Vector2(sx, 50 + 2), score, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(sx, 50), score, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIStyle.GOLD_HI if lead else UIStyle.TEXT)
	var x_edge := inner + dir * (sw + 12.0)
	# Name over the gems, aligned away from the coin.
	var room := absf(x_edge - (6.0 if left else size.x - 6.0))
	var nm := _fit(fs, String(m["names"][seat]).to_upper(), room, 13)
	var nw := fs.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var nx := x_edge - nw if left else x_edge
	draw_string(fs, Vector2(nx, 29 + 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
	draw_string(fs, Vector2(nx, 29), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col.lightened(0.35))
	# Wins as gems, the nearest the coin first.
	var won: int = int(m["scores"][seat])
	for i in int(m["need"]):
		var gx := x_edge + dir * (GEM_R + GEM_STEP * i)
		var gp := Vector2(gx, 48.0)
		if i < won:
			PickPips.draw_gem(self, gp, GEM_R, col)
		else:
			PickPips.draw_socket(self, gp, GEM_R)


## Game medallion `i`: the winner's gem in a bronze ring, "GAME n", the winner and the turns; the
## current game an empty breathing socket ("NOW" / "NEXT"); a game no longer needed dimmed.
func _draw_game(i: int) -> void:
	var p := game_pos(i)
	var res: Array = m["results"]
	var f := UIStyle.font_display(600)
	var fb := UIStyle.font_bold()
	var slot := _slot_w() - 4.0
	draw_circle(p + Vector2(0, 2), GAME_R + 1.0, Color(0, 0, 0, 0.5), true, -1.0, true)
	draw_circle(p, GAME_R, Color("1d1712"), true, -1.0, true)
	draw_arc(p, GAME_R, 0.0, TAU, 40, UIStyle.BRONZE.lerp(UIStyle.GOLD, 0.35), 2.0, true)
	var faded := false
	var sub := ""
	var sub_col := UIStyle.MUTED
	var who := ""
	var who_col := UIStyle.TEXT_DIM
	if i < res.size():
		var w: int = res[i]
		PickPips.draw_gem(self, p, GAME_R - 5.0, SEAT_COLORS[w])
		who = String(m["names"][w])
		who_col = (SEAT_COLORS[w] as Color).lightened(0.3)
		var forfeit: bool = i < (m["forfeit"] as Array).size() and bool(m["forfeit"][i])
		sub = "forfeit" if forfeit else ("turn %d" % int(m["turns"][i]) if i < (m["turns"] as Array).size() and int(m["turns"][i]) > 0 else "")
	elif i == int(m["current"]):
		PickPips.draw_socket(self, p, GAME_R - 5.0)
		who = "Now" if bool(m["playing"]) else "Next"
		who_col = UIStyle.GOLD_HI
	else:
		PickPips.draw_socket(self, p, GAME_R - 5.0)
		faded = bool(m["over"])
		who = "—" if faded else ""
	var label_col := Color(UIStyle.GOLD, 0.45 if faded else 0.9)
	Txt.centred(self, f, "GAME %d" % (i + 1), Vector2(p.x, p.y + GAME_R + 16.0), 10, label_col)
	if who != "":
		Txt.centred(self, fb, _fit(fb, who, slot, 12), Vector2(p.x, p.y + GAME_R + 31.0), 12, Color(who_col, 0.5) if faded else who_col)
	if sub != "":
		Txt.centred(self, UIStyle.font_italic(), sub, Vector2(p.x, p.y + GAME_R + 45.0), 11, sub_col)


# The current game's breathing rings (their own canvas item: only they redraw each frame, H7).
func _draw_breath() -> void:
	if m.is_empty() or int(m["current"]) < 0:
		return
	var p := game_pos(int(m["current"]))
	var t := float(clock.call())
	var k := 0.75 if UIStyle.reduce_motion else UIStyle.breathe(t, 0.35)
	_breath.draw_arc(p, GAME_R + 3.5, 0.0, TAU, 40, Color(UIStyle.GOLD_HI, clampf(0.6 * k, 0.0, 1.0)), 2.0, true)
	_breath.draw_arc(p, GAME_R + 7.0, 0.0, TAU, 40, Color(UIStyle.GOLD, clampf(0.2 * k, 0.0, 1.0)), 3.0, true)


## `text` cut with an ellipsis to fit `w` px at `px`.
static func _fit(f: Font, text: String, w: float, px: int) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= w:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


## One finished game as a sidebar row (between games): its gem in the winner's colour, "Game n",
## the winner and the turns.
static func game_row(game_no: int, winner: int, winner_name: String, turns: int, forfeit: bool, mine: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "GameRow%d" % game_no
	row.add_theme_constant_override("separation", UIStyle.sp("sm"))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem := GemDot.new(SEAT_COLORS[clampi(winner, 0, 1)], 9.0)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gem)
	var g := UIStyle.label("Game %d" % game_no, 14, UIStyle.GOLD, false, true)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)
	var w := UIStyle.label(winner_name + (" (you)" if mine else ""), 14, (SEAT_COLORS[clampi(winner, 0, 1)] as Color).lightened(0.3))
	w.add_theme_font_override("font", UIStyle.font_bold())
	w.clip_text = true
	w.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(w)
	var t := UIStyle.label("forfeit" if forfeit else ("turn %d" % turns), 13, UIStyle.MUTED)
	t.add_theme_font_override("font", UIStyle.font_italic())
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return row


## A single faceted gem in a small control (sidebar rows).
class GemDot extends Control:
	var col: Color
	var r: float

	func _init(c: Color, radius: float) -> void:
		col = c
		r = radius
		custom_minimum_size = Vector2(radius * 2.0 + 6.0, radius * 2.0 + 4.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		PickPips.draw_gem(self, size / 2.0, r, col)


## Text helpers.
class Txt:
	## `text` centred on `at.x` with its baseline at `at.y`, over a 1 px dark shadow.
	static func centred(ci: CanvasItem, f: Font, text: String, at: Vector2, px: int, col: Color) -> void:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var p := Vector2(roundf(at.x - w / 2.0), at.y)
		ci.draw_string(f, p + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.8 * col.a))
		ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## The gilded Best-of coin (the SeriesMedallion's, at any radius): a soft gold halo, a gilded rim lit
## from the top left, a dark tooled field with an engraved ring and studs, "BEST OF" over the number.
class CoinArt:
	static func draw_coin(ci: CanvasItem, c: Vector2, r: float, best_of: int) -> void:
		var k := r / 62.0
		ci.draw_circle(c, r + 8.0 * k + 2.0, Color(UIStyle.GOLD, 0.07), true, -1.0, true)
		ci.draw_circle(c + Vector2(0, 2.0 + k), r, Color(0, 0, 0, 0.55), true, -1.0, true)
		ci.draw_circle(c, r, UIStyle.BRONZE, true, -1.0, true)
		for i in 24:
			var a0 := TAU * float(i) / 24.0
			var lit := 0.5 + 0.5 * cos(a0 + PI * 0.75)
			ci.draw_arc(c, r - maxf(1.5, 2.5 * k), a0, a0 + TAU / 24.0 + 0.02, 4, UIStyle.BRONZE.lerp(UIStyle.GOLD_HI, lit), maxf(2.5, 5.0 * k), true)
		ci.draw_arc(c, r, 0.0, TAU, 48, Color("1a1006"), 1.0, true)
		var field := r - maxf(3.5, 6.0 * k)
		ci.draw_circle(c, field, Color("1d1712"), true, -1.0, true)
		ci.draw_circle(c + Vector2(0, -field * 0.35), field * 0.6, Color(1, 0.9, 0.6, 0.035), true, -1.0, true)
		ci.draw_arc(c, field - maxf(3.0, 8.0 * k), 0.0, TAU, 48, Color(0, 0, 0, 0.6), 1.2, true)
		ci.draw_arc(c + Vector2(0, 1), field - maxf(3.0, 8.0 * k), 0.0, TAU, 48, Color(UIStyle.GOLD, 0.3), 1.0, true)
		for i in 8:
			var a := TAU * float(i) / 8.0 - PI / 2.0
			ci.draw_circle(c + Vector2(cos(a), sin(a)) * (field - maxf(1.8, 3.5 * k)), maxf(0.9, 1.6 * k), Color(UIStyle.GOLD_HI, 0.7), true, -1.0, true)
		var small := UIStyle.font_display(600)
		var big := UIStyle.font_display(700)
		var spx := maxi(7, int(roundf(12.0 * k * 1.15)))
		var bpx := maxi(14, int(roundf(44.0 * k)))
		Txt.centred(ci, small, "BEST OF", c + Vector2(0, -r * 0.24), spx, Color(UIStyle.GOLD, 0.9))
		Txt.centred(ci, big, str(best_of), c + Vector2(0, r * 0.5), bpx, UIStyle.GOLD_HI)


## A laurel branch: leaves along half an ellipse around `c` (radii `rx`, `ry`) on the left (`side`
## -1) or the right (+1), from the foot up the side, the leaves shrinking toward the tip.
class Laurel:
	static func draw_branch(ci: CanvasItem, c: Vector2, r: float, side: float, col: Color, leaves: int = 7) -> void:
		draw_half(ci, c, r, r, side, col, leaves)

	static func draw_half(ci: CanvasItem, c: Vector2, rx: float, ry: float, side: float, col: Color, leaves: int = 7) -> void:
		# Angles measured from straight down (PI / 2); the side's x sign is applied to cos.
		var a0 := 0.32
		var a1 := PI * 0.86
		var at := func(a: float) -> Vector2: return c + Vector2(side * sin(a) * rx, cos(a) * ry)
		var pts := PackedVector2Array()
		for i in 13:
			pts.append(at.call(lerpf(a0, a1, float(i) / 12.0)))
		var stem := maxf(1.0, 1.4 * minf(rx, ry) / 37.0 + 0.4)
		ci.draw_polyline(pts, Color(col.darkened(0.35), col.a), stem, true)
		var scale := minf(rx, ry) / 37.0
		for i in leaves:
			var t := (float(i) + 0.6) / float(leaves)
			var a := lerpf(a0, a1, t)
			var p: Vector2 = at.call(a)
			var ahead: Vector2 = at.call(a + 0.05)
			var tangent := (ahead - p).normalized()
			var normal := (p - c).normalized()
			var ln := lerpf(5.5, 3.2, t) * maxf(scale, 0.55)
			for s in [-1.0, 1.0]:
				var dir: Vector2 = (tangent * 0.8 + normal * 0.75 * s).normalized()
				var tip: Vector2 = p + dir * ln * 1.6
				var mid: Vector2 = p + dir * ln * 0.8
				var perp := Vector2(-dir.y, dir.x) * ln * 0.42
				ci.draw_colored_polygon(PackedVector2Array([p, mid + perp, tip, mid - perp]), col)
