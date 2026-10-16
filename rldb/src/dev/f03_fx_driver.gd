extends SceneTree
## Development-only visual driver for the F03 effects package (badges, ready glow, destroy / exhaust,
## special summons, game end). Run windowed:
##   godot --path rldb -s res://src/dev/f03_fx_driver.gd -- --no-steam --fx-shots=<abs dir> --mode=<mode> [--size=1600x900]
## Modes: ready, destroy, exhaust, fusion, ritual, arcane, win, lose, series. It stages a board through the
## real engine, drives commands through LocalHost and saves frame sequences of the running animation.

var main: Node
var host: LocalHost
var m: MatchEngine
var out_dir := ""
var mode := ""
var tag := ""


func _initialize() -> void:
	var size := Vector2i(1600, 900)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fx-shots="):
			out_dir = a.split("=", true, 1)[1]
		elif a.begins_with("--mode="):
			mode = a.split("=")[1]
		elif a.begins_with("--size="):
			var p := a.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	tag = "%s_%dx%d" % [mode, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	_run.call_deferred()


func _run() -> void:
	await _wait(0.3)
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
	# Skip the coin flip of game 1.
	main.screen._coin_shown[String(main.screen.view.get("save_id", "local"))] = true
	for n in main.screen.get_children():
		if n is CoinFlip:
			n.queue_free()
	call("_mode_" + mode)


# ---------------------------------------------------------------- helpers

func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _show(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [tag, name]))


## Saves `n` frames `step` seconds apart, named name_00 ...
func _seq(name: String, n: int, step: float) -> void:
	for i in n:
		await _snap("%s_%02d" % [name, i])
		await _wait(step)


func _done() -> void:
	print("FX DONE ", tag)
	quit()


func _turn2() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})


func _fresh_view(p: int) -> void:
	host.broadcast()
	_show(p)


# ---------------------------------------------------------------- modes

func _mode_ready() -> void:
	_turn2()
	var a := m.active
	var o := 1 - a
	TB.unit(m, a, 1, 0)
	TB.unit(m, a, 110, 1)
	TB.unit(m, a, 36, 4)
	TB.unit(m, a, 34, 2, "def")
	TB.unit(m, o, 70, 0, "def")
	TB.unit(m, o, 162, 2)
	TB.card(m, a, 1)
	TB.card(m, a, 36)
	TB.card(m, a, 101)
	TB.power(m, a, 54, 0)
	TB.card(m, a, 172, "extra")
	TB.card(m, a, 1, "spent")
	TB.card(m, a, 110, "spent")
	var big := TB.unit(m, o, 36, 4, "atk", 126, 130)
	m.players[a]["ap"] = 6
	_fresh_view(a)
	await _wait(0.6)
	await _seq("ready", 8, 0.22)
	_done()
