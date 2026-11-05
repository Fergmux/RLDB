extends SceneTree
## Dev-only windowed evidence for the L batch FX items (design/owner-feedback-2026-11-05.md): L4 the
## animation queue, L8 status effects and badges, L17 card badge insets, L18 the duel hourglass.
## Run NOT headless (from rldb/):
##   godot --path . -s res://src/dev/l_fx_shots.gd -- --l-shots=<abs dir> --mode=<mode> [--size=1600x1000] [--calm]
## Modes:
##   cards   every card size (field unit / Power / Trap, hand, mini, big) with statuses, at native size;
##   badges  every status badge at 14..96 px on dark and on card art, with stack counts;
##   status  each of the 15 status applications (plus Rune and a blocked one) on a real board, as frames;
##   queue   two attacks sent back to back on a real board, as frames (the first must play out);
##   clock   the duel hourglass: still states and a flip, as frames;
##   board   a real board with statuses on field cards (context shot).

var out_dir := ""
var mode := ""
var tag := ""
var calm := false
var main: Node
var host: LocalHost
var m: MatchEngine

const UNITS := [1, 36, 110, 70, 162, 34]
const STATUSES := ["rune", "retain", "reveal", "eternal", "burn", "pierce", "cleanse", "paralyse", "medic",
	"curse", "poison", "infiltrate", "blind", "nimble", "debilitate"]


func _initialize() -> void:
	var size := Vector2i(1600, 1000)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--l-shots="):
			out_dir = a.split("=", true, 1)[1]
		elif a.begins_with("--mode="):
			mode = a.split("=")[1]
		elif a.begins_with("--size="):
			var p := a.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a == "--calm":
			calm = true
	tag = "%s%s" % [mode, "_calm" if calm else ""]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [tag, name]))


func _seq(name: String, n: int, step: float) -> void:
	for i in n:
		await _snap("%s_%02d" % [name, i])
		await _wait(step)


func _run() -> void:
	await _wait(0.3)
	if calm:
		UIStyle.reduce_motion = true
	match mode:
		"cards": await _mode_cards()
		"badges": await _mode_badges()
		"clock": await _mode_clock()
		_:
			await _start_game()
			if calm:
				UIStyle.reduce_motion = true   # main loads the saved settings
			call("_mode_" + mode)
			return
	print("L SHOTS DONE ", tag)
	quit()


func _done() -> void:
	print("L SHOTS DONE ", tag)
	quit()


# ---------------------------------------------------------------- standalone sheets

func _backdrop() -> Control:
	var bg := ColorRect.new()
	bg.color = Color("17130f")
	bg.size = root.size
	root.add_child(bg)
	return bg


func _caption(parent: Control, text: String, pos: Vector2, fs: int = 14) -> void:
	var l := UIStyle.label(text, fs, UIStyle.TEXT_DIM)
	l.position = pos
	parent.add_child(l)


## A visible card view from a real engine (statuses set directly).
func _view(id: int, zone: String, st: Dictionary, runes: int = 0, atk = null, def = null) -> Dictionary:
	var mm := TB.make()
	var uid: int
	if zone == "unit":
		uid = TB.unit(mm, 0, id, 0, "atk", atk, def)
	elif zone == "power":
		uid = TB.power(mm, 0, id, 0)
	else:
		uid = TB.card(mm, 0, id)
	mm.cards[uid]["st"] = st.duplicate()
	mm.cards[uid]["runes"] = runes
	return MatchView.card_view(mm, uid, 0)


func _mode_cards() -> void:
	var bg := _backdrop()
	var st := {"poison": 2, "burn": 1, "eternal": 1, "paralyse": 3}
	var x := 24.0
	var y := 40.0
	_caption(bg, "field unit (board 85x128), Power, Trap/Spell face up, hand 120x180, mini 90x135, big 224x336", Vector2(24, 8))
	var specs := [
		[UNITS[0], "unit", "board", st], [UNITS[1], "unit", "board", {"rune": 0, "cleanse": 1, "nimble": 2}],
		[UNITS[2], "unit", "board", {}], [88, "power", "power", {"curse": 1}],
		[UNITS[3], "hand", "hand", {"retain": 1}], [UNITS[4], "hand", "mini", {"medic": 2, "blind": 1}],
		[UNITS[5], "hand", "big", {"pierce": 1, "debilitate": 2, "infiltrate": 1, "reveal": 1}],
	]
	for sp in specs:
		var v := _view(int(sp[0]), String(sp[1]), sp[3], 2 if sp[0] == UNITS[1] else 0, 30 if sp[1] == "unit" else null, 12 if sp[1] == "unit" else null)
		var w := CardWidget.new()
		w.auto_hover = false
		w.setup(v, String(sp[2]))
		w.position = Vector2(x, y)
		bg.add_child(w)
		x += w.size.x + 22.0
	# A Defense (rotated) field unit, then the Fusion / Ritual / Arcane gems on field and tall cards.
	var dv := _view(UNITS[2], "unit", {"poison": 1}, 0, 18, 44)
	var dw := CardWidget.new()
	dw.auto_hover = false
	dw.setup(dv, "board", "", true)
	dw.position = Vector2(24, 420)
	bg.add_child(dw)
	x = 190.0
	for id in [56, 98, 170]:
		for kind in ["board", "hand"]:
			var ev := _view(id, "unit" if kind == "board" else "hand", {"eternal": 1} if kind == "board" else {}, 0, 40 if kind == "board" else null, 20 if kind == "board" else null)
			var ew := CardWidget.new()
			ew.auto_hover = false
			ew.setup(ev, kind)
			ew.position = Vector2(x, 420)
			bg.add_child(ew)
			x += ew.size.x + 18.0
	await _wait(0.8)
	await _snap("sheet")


func _mode_badges() -> void:
	var bg := _backdrop()
	_caption(bg, "status badges at 14 / 20 / 30 / 48 / 96 px (buff = round, debuff = square, Rune = hexagon), stacks 1 / 3", Vector2(24, 8))
	var sheet := BadgeSheet.new()
	sheet.size = root.size
	bg.add_child(sheet)
	await _wait(0.6)
	await _snap("sheet")


## Draws every status token in a grid (the shared CardStatusIcons.draw_token path).
class BadgeSheet extends Control:
	func _draw() -> void:
		var keys := ["rune"] + Array(CardDB.STATUS_ORDER)
		var sizes := [14.0, 20.0, 30.0, 48.0, 96.0]
		var y := 44.0
		for i in keys.size():
			var key: String = keys[i]
			var k := CardStatusIcons.KIND_RUNE if key == "rune" else (CardStatusIcons.KIND_BUFF if CardDB.is_buff(key) else CardStatusIcons.KIND_DEBUFF)
			var cx := 30.0 + float(i % 8) * 195.0
			var cy := y + float(i / 8) * 440.0
			draw_string(UIStyle.font_bold(), Vector2(cx, cy + 12), key.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.TEXT)
			var yy := cy + 28.0
			for s in sizes:
				var r: float = s / 2.0
				CardStatusIcons.draw_token(self, Vector2(cx + r, yy + r), r, key, 1, k, true)
				if s <= 48.0:
					CardStatusIcons.draw_token(self, Vector2(cx + 110.0 + r, yy + r), r, key, 3, k, true)
				yy += s + 10.0


func _mode_clock() -> void:
	var bg := _backdrop()
	var now := [0]
	var clocks := []
	# Two plaques on their own clocks (each view advances its clock's glass): native size, and 5x.
	for i in 2:
		var clk := DuelClock.new()
		clk.now_ms = func() -> int: return now[0]
		clk.observe({"match": {"turn": 1}})
		clocks.append(clk)
		var v := DuelClockView.new()
		v.set_clock(clk)
		v.position = Vector2(60, 40) if i == 0 else Vector2(60, 140)
		v.scale = Vector2.ONE if i == 0 else Vector2(5, 5)
		bg.add_child(v)
	# Frames across a minute of running time.
	for f in [0, 15, 30, 45, 59]:
		now[0] = f * 1000
		await _wait(0.35)
		await _snap("t%02ds" % f)
	# The top has run dry: after a short hold the glass turns over by itself.
	now[0] = 61600
	await _seq("flip", 16, 0.06)
	now[0] = 75000
	await _wait(0.4)
	await _snap("after_flip_14s")
	# A new turn with less than half on top turns it over again.
	now[0] = 100000
	await _wait(0.3)
	for c in clocks:
		(c as DuelClock).observe({"match": {"turn": 2}})
	await _seq("turnflip", 8, 0.12)
	# Paused (network): dimmed, no stream.
	for c in clocks:
		(c as DuelClock).observe({"match": {"turn": 2}, "net": {"paused": true}})
	await _wait(0.3)
	await _snap("paused")
	_done()


# ---------------------------------------------------------------- real board modes

func _start_game() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(0.5)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	main.screen._coin_shown[String(main.screen.view.get("save_id", "local"))] = true
	for n in main.screen.get_children():
		if n is CoinFlip:
			n.queue_free()
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})


func _show(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _mode_board() -> void:
	var a := m.active
	var o := 1 - a
	var u := [TB.unit(m, a, 1, 0), TB.unit(m, a, 110, 1), TB.unit(m, a, 36, 2, "def"), TB.unit(m, o, 70, 0), TB.unit(m, o, 162, 1)]
	m.cards[u[0]]["st"] = {"poison": 2, "eternal": 1}
	m.cards[u[1]]["st"] = {"burn": 1, "nimble": 1, "pierce": 2}
	m.cards[u[2]]["st"] = {"paralyse": 1}
	m.cards[u[3]]["st"] = {"curse": 1, "blind": 1}
	m.cards[u[4]]["st"] = {"medic": 3, "cleanse": 1}
	m.cards[u[4]]["runes"] = 2
	host.broadcast()
	_show(a)
	await _wait(1.0)
	main.screen.skip_effects()
	await _wait(0.5)
	await _snap("board")
	_done()


## Each status application on a unit of the active player's board, a few frames each.
func _mode_status() -> void:
	var a := m.active
	var slots := [0, 1, 2, 3, 4, 5]
	var uids := []
	for i in slots.size():
		uids.append(TB.unit(m, a, UNITS[i], slots[i]))
	host.broadcast()
	_show(a)
	await _wait(1.0)
	main.screen.skip_effects()
	await _wait(0.4)
	var gs: GameScreen = main.screen
	var list := STATUSES.duplicate()
	list.append("blocked")
	for i in list.size():
		var s: String = list[i]
		var slot: int = slots[i % slots.size()]
		var at := {"p": a, "zone": "unit", "slot": slot}
		var ev := {"k": "status", "at": at, "s": s, "n": 1}
		if s == "blocked":
			ev = {"k": "status_blocked", "at": at, "status": "cleanse", "s": "poison"}
		gs.fx.play([ev], gs.mv)
		await _seq(s, 6, 0.12)
		await _wait(0.5)
	_done()


## Two attacks sent back to back: the first lunge must play to the end before the second starts.
func _mode_queue() -> void:
	var a := m.active
	var o := 1 - a
	var a1 := TB.unit(m, a, 1, 0, "atk", 30, 30)
	var a2 := TB.unit(m, a, 110, 1, "atk", 30, 30)
	var d1 := TB.unit(m, o, 70, 0, "def", 5, 35)
	var d2 := TB.unit(m, o, 162, 1, "def", 5, 35)
	TB.to_battle(m)
	host.broadcast()
	_show(a)
	await _wait(1.0)
	main.screen.skip_effects()
	await _wait(0.4)
	var legacy := "--legacy" in OS.get_cmdline_user_args()
	if legacy:
		FxPlayer.sequence_views = false   # the pre-L4 path: every view rendered at once...
	print("QUEUE attack1 ", TB.attack(m, a1, d1))
	host.broadcast()
	await _wait(0.12)
	if legacy:
		main.screen.fx.finish_all()   # ...and the click on the next attacker skipped the running effects
	print("QUEUE attack2 ", TB.attack(m, a2, d2))
	host.broadcast()
	await _seq("double", 18, 0.05)
	_done()
