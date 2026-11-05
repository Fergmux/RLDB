extends SceneTree
## Dev-only, windowed (perf 2026-11-05, design/perf-2026-11-05.md): renders one fixed sheet of card
## widgets (every kind, both orientations, statuses, preview, dim, selection, ready, empty zones, a
## dissolve material, an FX scale and a hover lift) on the table and saves it as a PNG, so the sheet
## from two versions of the card code can be compared pixel by pixel. Run NOT headless:
##   godot --path rldb --resolution 1600x1000 -s res://src/dev/card_face_parity_shots.gd -- <out.png>
## Compare two sheets with `-- --diff=<a.png>,<b.png>` (prints "PARITY diff=N px, worst=W").

const IDS := [36, 147, 45, 182, 185, 1, 12, 60, 101, 150]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--diff="):
			var p := a.trim_prefix("--diff=").split(",")
			_diff(p[0], p[1])
			quit()
			return
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.size = Vector2i(1600, 1000)
	_run.call_deferred(args[0] if args.size() > 0 else "user://card_parity.png")


func _view(id: int, zone: String) -> Dictionary:
	var v := MatchView.summary_view(Series.card_summary(id))
	v["zone"] = zone
	return v


func _card(parent: Control, v, kind: String, pos: Vector2, rotated: bool = false) -> CardWidget:
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind, "", rotated)
	parent.add_child(w)
	w.position = pos
	return w


func _run(out: String) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.09, 0.07)
	bg.size = Vector2(1600, 1000)
	root.add_child(bg)
	var host := Control.new()
	root.add_child(host)
	var x := 20.0
	for i in IDS.size():
		var id: int = IDS[i]
		if not CardDB.has(id):
			continue
		_card(host, _view(id, "hand"), "hand", Vector2(x, 20))
		_card(host, _view(id, "unit"), "board", Vector2(x, 220))
		_card(host, _view(id, "unit"), "board", Vector2(x, 360), true)
		x += 150.0
	# States: statuses and modified stats, preview, dims, selection, ready, order badge.
	var v := _view(36, "unit")
	v["statuses"] = {"burn": 2, "poison": 1, "retain": 1}
	v["atk"] = int(v.get("atk", 0)) + 3
	_card(host, v, "board", Vector2(20, 500))
	var p := _card(host, _view(36, "unit"), "board", Vector2(130, 500))
	p.set_preview("atk", 12, 4)
	_card(host, _view(147, "unit"), "board", Vector2(240, 500)).set_marks(false, false, true)
	_card(host, _view(147, "unit"), "board", Vector2(350, 500)).set_marks(false, false, false, true)
	_card(host, _view(45, "unit"), "board", Vector2(460, 500)).set_marks(true, true)
	_card(host, _view(45, "hand"), "hand", Vector2(570, 500)).set_ready(true)
	_card(host, _view(182, "hand"), "mini", Vector2(720, 500)).order_no = 2
	_card(host, _view(185, "hand"), "big", Vector2(840, 500))
	_card(host, {"hidden": true, "zone": "hand"}, "back", Vector2(1100, 500))
	var set_card := _view(150, "backrow")
	set_card["face_up"] = false
	_card(host, set_card, "trap", Vector2(1180, 500), true)
	# Empty zones: plain, dimmed, picked.
	var e1 := _card(host, null, "board", Vector2(1100, 640))
	e1.size = Vector2(128, 128)
	var e2 := _card(host, null, "trap", Vector2(1240, 640))
	e2.size = Vector2(128, 85)
	e2.set_marks(false, false, true)
	# A dissolve material (FX ghosts), an FX scale and a hover lift.
	var g := _card(host, _view(12, "unit"), "board", Vector2(20, 820))
	var mat := ShaderMaterial.new()
	mat.shader = load(FxCardEffects.DISSOLVE_SHADER)
	mat.set_shader_parameter("edge_color", Color(1, 0.6, 0.9))
	mat.set_shader_parameter("dissolve", 0.35)
	g.material = mat
	var sc := _card(host, _view(60, "hand"), "hand", Vector2(200, 780))
	sc.pivot_offset = sc.size / 2.0
	sc.scale = Vector2(1.18, 1.18)
	var lift := _card(host, _view(101, "hand"), "hand", Vector2(400, 780))
	lift.lift_k = 1.08
	UIStyle.reduce_motion = true   # the animated overlays hold still for the capture
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("PARITY saved %s" % out)
	quit()


func _diff(a_path: String, b_path: String) -> void:
	var a := Image.load_from_file(a_path)
	var b := Image.load_from_file(b_path)
	if a.get_size() != b.get_size():
		print("PARITY size mismatch %s vs %s" % [a.get_size(), b.get_size()])
		return
	var n := 0
	var worst := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := maxi(maxi(absi(ca.r8 - cb.r8), absi(ca.g8 - cb.g8)), absi(ca.b8 - cb.b8))
			if d > 0:
				n += 1
				worst = maxi(worst, d)
	print("PARITY diff=%d px, worst=%d" % [n, worst])
