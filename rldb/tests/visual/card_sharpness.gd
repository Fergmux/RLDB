extends SceneTree
## Dev screenshot tool for card text sharpness (F04-05). Run WINDOWED, like the game
## (canvas_items stretch, 1600x1000 base, expand):
##   godot --path rldb -s res://tests/visual/card_sharpness.gd -- <output dir> <width> <height> <tag>
## Writes <tag>_gallery.png (every category at rest and lifted, every kind, the inspector size)
## and <tag>_board.png (a board-like layout with a lifted hand card).

var _out := "user://card_sharpness"
var _tag := "shot"
var _uid := 500
var _force_scale := false
var _want := Vector2i(1600, 900)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var w := 1600
	var h := 900
	if args.size() > 0:
		_out = args[0]
	if args.size() > 2:
		w = int(args[1])
		h = int(args[2])
	if args.size() > 3:
		_tag = args[3]
	_force_scale = args.size() > 4 and args[4] == "scale"
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1600, 1000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_want = Vector2i(w, h)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = _want
	root.position = Vector2i(0, 0)
	for i in 6:
		await process_frame
	print("window ", root.size, " final transform ", root.get_final_transform())
	await _shoot("gallery", _page_gallery)
	await _shoot("board", _page_board)
	quit(0)


func _shoot(name: String, builder: Callable) -> void:
	var bg := ColorRect.new()
	bg.color = Color("2a211a")
	bg.size = Vector2(1600, 1000)
	root.add_child(bg)
	builder.call(bg)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	print("shot ", name, " ", img.get_size(), " err ", img.save_png("%s/%s_%s.png" % [_out, _tag, name]))
	bg.queue_free()
	await process_frame


func _def(pred: Callable) -> Dictionary:
	for d in CardDB.all():
		if pred.call(d):
			return d
	return {}


func _view(d: Dictionary, zone: String, opts: Dictionary = {}) -> Dictionary:
	_uid += 1
	var v := {
		"uid": _uid, "id": d["id"], "name": d["name"], "category": d["category"],
		"cost_kind": d["cost_kind"], "cost_text": str(d["cost"]), "cost": d["cost"], "printed_cost": d["cost"],
		"zone": zone, "slot": 0, "owner": 0, "ctl": 0, "face_up": true, "statuses": {}, "runes": 0,
		"text": _text(d), "support": "full", "art": d["art"], "keywords": d["keywords"],
	}
	if CardDB.is_unit_category(d["category"]):
		v["race"] = d["race"]
		v["type"] = d["type"]
		v["printed_atk"] = d["atk"]
		v["printed_def"] = d["def"]
		v["atk"] = d["atk"]
		v["def"] = d["def"]
		if zone == "unit":
			v["stance"] = "atk"
	for k in opts:
		v[k] = opts[k]
	return v


func _text(d: Dictionary) -> String:
	var parts := []
	for k in ["on_summon", "on_field", "condition", "description"]:
		if String(d.get(k, "")) != "":
			parts.append(String(d[k]))
	return " ".join(parts)


func _cat(c: String) -> Dictionary:
	return _def(func(d): return d["category"] == c)


func _card(p: Control, v, kind: String, pos: Vector2, sc := 1.0, rot := false) -> CardWidget:
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind, "", rot)
	w.position = pos
	if sc != 1.0:
		if "lift_k" in w and not _force_scale:
			w.lift_k = sc   # the real-size hover lift (F04-05 fix)
		else:
			w.scale = Vector2(sc, sc)   # the old scale-based lift (before)
	p.add_child(w)
	return w


func _page_gallery(p: Control) -> void:
	var cats := ["basic_unit", "unit", "fusion", "ritual", "arcane", "spell", "trap", "power"]
	# Row 1: hand kind per category at rest. Row 2: the same, lifted (scale 1.25).
	for i in cats.size():
		var d := _cat(cats[i])
		_card(p, _view(d, "hand"), "hand", Vector2(10 + i * 130, 10))
		_card(p, _view(d, "hand"), "hand", Vector2(10 + i * 130, 200), 1.25)
	_card(p, _view(_cat("unit"), "unit"), "board", Vector2(10, 440))
	_card(p, _view(_cat("basic_unit"), "unit"), "board", Vector2(105, 440))
	_card(p, _view(_cat("unit"), "unit"), "board", Vector2(215, 440), 1.08)
	_card(p, _view(_cat("spell"), "hand"), "mini", Vector2(320, 440))
	_card(p, _view(_cat("unit"), "hand"), "big", Vector2(430, 440))
	_card(p, _view(_cat("power"), "power"), "power", Vector2(680, 440))
	_card(p, _view(_cat("trap"), "backrow"), "trap", Vector2(780, 440))
	_card(p, _view(_cat("spell"), "hand"), "big", Vector2(880, 440))
	var w := _card(p, _view(_cat("unit"), "hand"), "big", Vector2(1130, 440))
	GameUi.resize_card(w, Vector2(300, 450))


func _page_board(p: Control) -> void:
	for i in 5:
		_card(p, _view(_cat("unit"), "hand"), "hand", Vector2(300 + i * 100, 780), 1.0)
	_card(p, _view(_cat("unit"), "hand"), "hand", Vector2(420, 700), 1.25)
	for i in 3:
		_card(p, _view(_cat("unit"), "unit"), "board", Vector2(300 + i * 140, 300))
	_card(p, _view(_cat("spell"), "hand"), "big", Vector2(40, 300))
