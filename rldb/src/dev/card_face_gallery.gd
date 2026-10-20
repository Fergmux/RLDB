extends SceneTree
## Dev-only windowed gallery of every card face kind (21 Oct owner batch, H10 / H12 / H14 / H16 / H17 /
## H19 / H20 / H21): field units, Defense, field Power / Trap, own set card, back, the tall hand / mini
## / big layouts of every category, the 64x96 left-pane subject card with long rules text, and a
## selected card inside a row of zones (the brackets must draw over the next zone). Writes JPGs.
## Run NOT headless:
##   godot --path rldb -s res://src/dev/card_face_gallery.gd -- <absolute output dir>

const BG := Color("17130f")
var out_dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://card_face_gallery"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.size = Vector2i(1600, 1000)
	run.call_deferred()


func _view(id: int, zone: String = "unit") -> Dictionary:
	var v := MatchView.summary_view(Series.card_summary(id))
	v["uid"] = 5000 + id
	v["zone"] = zone
	return v


func _page(zoom: float = 1.0) -> Control:
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(1600, 1000)
	root.add_child(bg)
	var c := Control.new()
	c.scale = Vector2(zoom, zoom)
	bg.add_child(c)
	return c


func _card(parent: Control, v: Dictionary, kind: String, pos: Vector2, rot: bool = false, sz: Vector2 = Vector2.ZERO) -> CardWidget:
	var w := CardWidget.new().setup(v, kind, "", rot)
	w.auto_hover = false
	parent.add_child(w)
	if sz != Vector2.ZERO:
		GameUi.resize_card(w, sz)
	w.position = pos
	return w


func _shot(name: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)


func _clear() -> void:
	for ch in root.get_children():
		if ch is ColorRect:
			ch.queue_free()
	await process_frame


func _field_row(p: Control, y: float) -> void:
	var x := 16.0
	for id in [1, 36, 99, 147, 97, 185]:
		var v := _view(id)
		if id == 36:
			v["statuses"] = {"burn": 2, "pierce": 1}
			v["atk"] = int(v["atk"]) + 4
		_card(p, v, "board", Vector2(x, y))
		x += 97.0
	var dv := _view(176)
	dv["stance"] = "def"
	_card(p, dv, "board", Vector2(x, y + 21), true)
	x += 140.0
	_card(p, _view(149, "power"), "power", Vector2(x, y))
	x += 97.0
	_card(p, _view(167, "power"), "power", Vector2(x, y))
	x += 97.0
	var tv := _view(45, "backrow")
	tv["face_up"] = true
	_card(p, tv, "trap", Vector2(x, y + 21), true)
	x += 140.0
	var sv := _view(165, "backrow")
	sv["face_up"] = false
	_card(p, sv, "trap", Vector2(x, y + 21), true)
	x += 140.0
	_card(p, {"hidden": true, "uid": 1}, "board", Vector2(x, y))


func _tall_row(p: Control, y: float, kind: String, ids: Array, step: float) -> void:
	var x := 16.0
	for id in ids:
		_card(p, _view(int(id), "hand"), kind, Vector2(x, y))
		x += step


func run() -> void:
	await process_frame
	# 1: actual sizes.
	var p := _page()
	_field_row(p, 16)
	_tall_row(p, 176, "hand", [36, 147, 97, 185, 182, 165, 149, 1, 99, 58], 132.0)
	_card(p, _view(185, "hand"), "big", Vector2(16, 380))
	_card(p, _view(182, "hand"), "big", Vector2(252, 380))
	_tall_row(p, 380, "mini", [], 0.0)
	var x := 500.0
	for id in [147, 36, 45, 182, 187, 97]:
		_card(p, _view(id, "hand"), "mini", Vector2(x, 380), false, Vector2(64, 96))
		x += 76.0
	x = 500.0
	for id in [99, 58, 149, 1]:
		_card(p, _view(id, "hand"), "mini", Vector2(x, 490))
		x += 102.0
	# H12: a selected card inside the first of three zones; the zones after it are drawn later.
	var zx := 960.0
	var zones: Array = []
	for i in 3:
		var z := CardWidget.new().setup(null, "board")
		z.position = Vector2(zx + i * 134.0, 400)
		z.size = Vector2(128, 128)
		p.add_child(z)
		zones.append(z)
	var holder := Control.new()
	holder.position = Vector2(21, 0)
	(zones[1] as Control).add_child(holder)
	var sel := CardWidget.new().setup(_view(36), "board")
	holder.add_child(sel)
	sel.set_marks(false, true)
	var hand_sel := _card(p, _view(147, "hand"), "hand", Vector2(1380, 400))
	hand_sel.set_marks(false, true)
	await _shot("gallery_actual")
	await _clear()
	# 2: the field row and the hand row at 2x, to judge the details.
	var z2 := _page(2.0)
	_field_row(z2, 8)
	await _shot("gallery_field_2x")
	await _clear()
	var z3 := _page(2.0)
	_tall_row(z3, 8, "hand", [36, 147, 97, 185, 182, 165], 128.0)
	for i in 6:
		_card(z3, _view([45, 147, 36, 182, 187, 97][i], "hand"), "mini", Vector2(16 + i * 74.0, 200), false, Vector2(64, 96))
	await _shot("gallery_tall_2x")
	await _clear()
	var z4 := _page(1.0)
	_card(z4, _view(185, "hand"), "big", Vector2(16, 16), false, Vector2(448, 672))
	_card(z4, _view(147, "hand"), "big", Vector2(480, 16), false, Vector2(448, 672))
	var bigsel := _card(z4, _view(45, "hand"), "big", Vector2(980, 40))
	bigsel.set_marks(false, true)
	await _shot("gallery_big")
	print("CARD FACE GALLERY DONE")
	quit(0)
