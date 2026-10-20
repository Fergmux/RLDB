extends SceneTree
## Development-only evidence driver for the board items of the 21 Oct 2026 owner batch (H4 pile count on
## the back's circle, H15 pile name plates, H18 empty pile count, H13 zone marks, H23 damage numbers over
## the struck plate). Run windowed from rldb/:
##   godot --path . -s res://src/dev/h_board_shots.gd -- --no-steam --out=<abs dir> [--size=1600x900]
##       [--lethal=unit|direct] [--view=winner|loser] [--calm]
## Stages one board through the real engine and LocalHost, then saves JPG (q88) frames: the board at rest,
## 2x crops of both pile columns (full and empty piles), the empty zones, a normal direct hit and a burst of
## frames through the killing blow, viewed by the attacker (`winner`) or by the seat that loses (`loser`).

var main: Node
var host: LocalHost
var m: MatchEngine
var gs: GameScreen
var out_dir := ""
var tag := ""
var calm := false
var lethal := "unit"
var view := "winner"
var a := 0
var o := 1
var uids := {}
var want := Vector2i(1600, 900)


func _initialize() -> void:
	var size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.split("=", true, 1)[1]
		elif arg.begins_with("--size="):
			var p := arg.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--lethal="):
			lethal = arg.split("=")[1]
		elif arg.begins_with("--view="):
			view = arg.split("=")[1]
		elif arg == "--calm":
			calm = true
	want = size
	tag = "%s_%s%s" % [lethal, view, "_calm" if calm else ""]
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
	UIStyle.reduce_motion = calm
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(want)
	await _wait(0.4)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(0.5)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	gs = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	_stage()
	_show(a)
	await _wait(1.2)
	await _states()
	print("H BOARD DONE ", tag)
	quit()


func _stage() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	a = m.active
	o = 1 - a
	uids["hitter"] = TB.unit(m, a, 110, 0, "atk", 10)
	uids["killer"] = TB.unit(m, a, 1, 1, "atk", 12)
	TB.card(m, a, 1, "spent")
	TB.card(m, a, 110, "spent")
	TB.card(m, a, 172, "extra")
	TB.set_card(m, a, 49, 0)   # an own face-down set card: its name plate is the pile plates' model (H15)
	# The opponent's Draw pile runs dry (its cards go to Exhaust): an empty pile beside full ones.
	var od: Array = m.players[o]["draw"]
	for uid in od.duplicate():
		od.erase(uid)
		m.cards[uid]["zone"] = "exhaust"
		m.players[o]["exhaust"].append(uid)
	if lethal == "unit":
		uids["guard"] = TB.unit(m, o, 110, 0, "atk", 3)
	m.players[o]["hp"] = 30
	host.broadcast()


func _states() -> void:
	_move(_neutral())
	await _wait(0.8)
	await _snap("01_board_rest")
	await _snap_crop("02_piles_mine", _piles_rect(1), 2.0)
	await _snap_crop("03_piles_opponent", _piles_rect(0), 2.0)
	await _snap_crop("04_zones_mine", _zones_rect(a), 1.6)
	await _snap_crop("05_zones_opponent", _zones_rect(o), 1.6)
	m.submit(a, {"t": "next_phase"})
	host.broadcast()
	await _wait(0.8)
	# A normal (non-lethal) direct hit on the opponent's plate (the unit run has a guard in the way).
	if lethal != "unit":
		await _attack(uids["hitter"], -1, "06_hit", 8, 0.12)
		await _wait(1.0)
	m.players[o]["hp"] = 4
	host.broadcast()
	await _wait(0.6)
	await _attack(uids["killer"], int(uids.get("guard", -1)), "07_lethal", 22, 0.14)
	await _wait(2.0)
	await _snap("08_game_end")


## Declares an attack and saves `frames` shots `step` s apart (the loser plate's area also as a 2x crop).
func _attack(uid: int, target: int, name: String, frames: int, step: float) -> void:
	# The loser's view: hand the screen to the defender first (hot-seat hands it back to the acting seat
	# afterwards, but a killing blow holds the screen through the game-end look).
	if view == "loser":
		_show(o)
		await _wait(0.5)
	m.submit(a, {"t": "attack", "uid": uid})
	if target >= 0 and m.pending.get("kind", "") == "attack_target":
		m.submit(a, {"t": "choose", "id": m.pending["id"], "values": [target]})
	host.broadcast()
	_auto_answer()
	var plate_r: Rect2 = (gs.plate_of(o) as Control).get_global_rect()
	var crop := Rect2(plate_r.get_center() - Vector2(330, 190), Vector2(660, 380))
	for i in frames:
		await _wait(step)
		await _snap_crop("%s_%02d" % [name, i], crop, 1.4)


# ---------------------------------------------------------------- helpers

func _piles_rect(side: int) -> Rect2:
	var r := Rect2()
	var first := true
	for z in ["draw", "extra", "spent", "exhaust"]:
		var pr: Rect2 = (gs.board.piles[side][z] as Control).get_global_rect()
		r = pr if first else r.merge(pr)
		first = false
	return r.grow(14.0)


func _zones_rect(p: int) -> Rect2:
	var r := Rect2()
	var first := true
	for z in ["unit", "backrow", "power"]:
		for s in gs.board.ZONE_SLOTS[z]:
			var zr: Rect2 = gs.board.slot_global_rect(p, z, s)
			r = zr if first else r.merge(zr)
			first = false
	return r.grow(10.0)


## A pointer rest over bare table: nothing hovers.
func _neutral() -> Vector2:
	return gs.get_global_transform() * Vector2(gs.board._ux - 320.0, gs.board._y0 + 520.0)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _show(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join("%s_%s.jpg" % [name, tag]), 0.88)
	print("shot ", name)


## Saves global rect `r` of the window scaled by `k` (capped at 1600 px wide).
func _snap_crop(name: String, r: Rect2, k: float) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var vis := Rect2i(Vector2i.ZERO, img.get_size())
	# Global canvas rect -> window pixels (the canvas_items stretch scales the 1600x1000 base).
	var ri := Rect2i(root.get_final_transform() * r).intersection(vis)
	if ri.size.x <= 0 or ri.size.y <= 0:
		return
	var c := img.get_region(ri)
	var w := mini(1600, int(ri.size.x * k))
	c.resize(w, int(ri.size.y * float(w) / ri.size.x), Image.INTERPOLATE_LANCZOS)
	c.save_jpg(out_dir.path_join("%s_%s.jpg" % [name, tag]), 0.88)
	print("shot ", name)


func _move(pos: Vector2) -> void:
	root.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(4, 0)
	root.push_input(ev, true)


func _auto_answer() -> void:
	var guard := 0
	while not m.pending.is_empty() and guard < 12:
		guard += 1
		var pd := m.pending
		var pick := 0
		for i in (pd.get("options", []) as Array).size():
			if String(pd["options"][i].get("label", "")).contains("Skip"):
				pick = i
		host.handle(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": [pick]})
		host.broadcast()
