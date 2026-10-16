extends SceneTree
## Dev capture tool for F05-03 (hover lift without text reflow). Run WINDOWED, like the game
## (canvas_items stretch, 1600x1000 base, expand); it quits itself:
##   godot --path rldb -s res://tests/visual/card_lift_reflow.gd -- <output dir> <tag>
## For each window size (1600x900, then 3840x2160) it writes <tag>_<w>_seq.png (the same cards at
## lift 1.00 .. 1.25 side by side: the frames of a hover lift) and <tag>_<w>_crop.png (the hand card
## at rest and at 1.25, cropped and zoomed with nearest filtering). Then it prints the FPS of a full
## board plus hand at 1600x900 with no hover, and while hover lifts cycle through the cards.

const KS := [1.0, 1.05, 1.1, 1.15, 1.2, 1.25]
const COL := 165.0

var _out := "user://card_lift_reflow"
var _tag := "shot"
var _uid := 700


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_tag = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1600, 1000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.mode = Window.MODE_WINDOWED
	for want in [Vector2i(1600, 900), Vector2i(3840, 2160)]:
		root.size = want
		root.position = Vector2i(0, 0)
		for i in 8:
			await process_frame
		print("window ", root.size, " final ", root.get_final_transform(), " vp oversampling ", root.get_oversampling())
		await _shoot_seq(want.x)
	root.size = Vector2i(1600, 900)
	for i in 8:
		await process_frame
	await _bench()
	quit(0)


func _def(pred: Callable) -> Dictionary:
	for d in CardDB.all():
		if pred.call(d):
			return d
	return {}


## The unit / spell with the longest rules text (the most line breaks to keep).
func _longest(cats: Array) -> Dictionary:
	var best := {}
	for d in CardDB.all():
		if d["category"] in cats and (best.is_empty() or _text(d).length() > _text(best).length()):
			best = d
	return best


func _view(d: Dictionary, zone: String) -> Dictionary:
	_uid += 1
	var v := {
		"uid": _uid, "id": d["id"], "name": d["name"], "category": d["category"],
		"cost_kind": d["cost_kind"], "cost_text": str(d["cost"]), "cost": d["cost"], "printed_cost": d["cost"],
		"zone": zone, "slot": 0, "owner": 0, "ctl": 0, "face_up": true, "statuses": {}, "runes": 0,
		"text": _text(d), "support": "full", "art": d["art"], "keywords": d["keywords"],
	}
	if CardDB.is_unit_category(d["category"]):
		for k in ["race", "type"]:
			v[k] = d[k]
		v["printed_atk"] = d["atk"]
		v["printed_def"] = d["def"]
		v["atk"] = d["atk"]
		v["def"] = d["def"]
		if zone == "unit":
			v["stance"] = "atk"
	return v


func _text(d: Dictionary) -> String:
	var parts := []
	for k in ["on_summon", "on_field", "condition", "description"]:
		if String(d.get(k, "")) != "":
			parts.append(String(d[k]))
	return " ".join(parts)


## A card resting at `pos` (top-left), lifted to `k` about its centre like a hover.
func _card(p: Control, v: Dictionary, kind: String, pos: Vector2, k: float) -> CardWidget:
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind)
	p.add_child(w)
	w.position = pos
	w.lift_k = k
	return w


func _backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color("2a211a")
	bg.size = Vector2(1600, 1000)
	root.add_child(bg)
	return bg


func _shoot_seq(wid: int) -> void:
	var bg := _backdrop()
	var unit := _longest(["unit", "fusion", "ritual"])
	var spell := _longest(["spell"])
	var board := _longest(["unit"])
	var draft := _longest(["arcane", "trap", "spell"])
	for i in KS.size():
		var x := 30.0 + i * COL
		_card(bg, _view(unit, "hand"), "hand", Vector2(x + 15, 30), KS[i])
		_card(bg, _view(spell, "hand"), "hand", Vector2(x + 15, 290), KS[i])
		_card(bg, _view(board, "unit"), "board", Vector2(x + 33, 550), KS[i])
	# Draft-sized card (the F05-03 report: the draft offer lifts by 1.05).
	_card(bg, _view(draft, "hand"), "hand", Vector2(1060, 30), 1.0)
	_card(bg, _view(draft, "hand"), "hand", Vector2(1220, 30), 1.05)
	_card(bg, _view(unit, "hand"), "big", Vector2(1060, 290), 1.0)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	print("seq ", wid, " ", img.get_size(), " err ", img.save_png("%s/%s_%d_seq.png" % [_out, _tag, wid]))
	# Crop: the hand unit at rest (column 0) and at 1.25 (column 5), in physical pixels, zoomed.
	var xf := root.get_final_transform()
	var crops: Array[Image] = []
	for i in [0, 5]:
		var k: float = KS[i]
		var c := Vector2(30.0 + i * COL + 15 + 60, 30 + 90)
		var half := Vector2(60, 90) * k + Vector2(4, 4)
		var r0 := xf * (c - half)
		var r1 := xf * (c + half)
		var rect := Rect2i(Vector2i(r0.floor()), Vector2i((r1 - r0).ceil()))
		var sub := img.get_region(rect)
		var zoom := 3 if wid < 2000 else 2
		sub.resize(sub.get_width() * zoom, sub.get_height() * zoom, Image.INTERPOLATE_NEAREST)
		crops.append(sub)
	var out := Image.create(crops[0].get_width() + crops[1].get_width() + 20, maxi(crops[0].get_height(), crops[1].get_height()), false, crops[0].get_format())
	out.fill(Color("2a211a"))
	out.blit_rect(crops[0], Rect2i(Vector2i.ZERO, crops[0].get_size()), Vector2i.ZERO)
	out.blit_rect(crops[1], Rect2i(Vector2i.ZERO, crops[1].get_size()), Vector2i(crops[0].get_width() + 20, 0))
	print("crop ", wid, " err ", out.save_png("%s/%s_%d_crop.png" % [_out, _tag, wid]))
	bg.queue_free()
	await process_frame


## A full board (5 + 5 units, 2 + 2 backrow, 2 powers) plus a 7-card hand; hover lifts cycle.
func _bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var bg := _backdrop()
	var units := []
	for d in CardDB.all():
		if d["category"] == "unit" and units.size() < 12:
			units.append(d)
	var cards: Array[CardWidget] = []
	for side in 2:
		for i in 5:
			cards.append(_card(bg, _view(units[i + side * 5], "unit"), "board", Vector2(420 + i * 140, 120 + side * 330), 1.0))
		for i in 2:
			cards.append(_card(bg, _view(_longest(["trap"]), "backrow"), "trap", Vector2(470 + i * 160, 270 + side * 330 - side * 200), 1.0))
		cards.append(_card(bg, _view(_longest(["power"]), "power"), "power", Vector2(260, 120 + side * 330), 1.0))
	var hand: Array[CardWidget] = []
	for i in 7:
		hand.append(_card(bg, _view(units[i % units.size()] if i % 2 == 0 else _longest(["spell"]), "hand"), "hand", Vector2(380 + i * 110, 780), 1.0))
	for i in 30:
		await process_frame
	print("bench idle  ", _measure_line(await _measure(2.0, [])))
	var hov: Array[CardWidget] = []
	hov.append_array(hand)
	hov.append_array(cards)
	print("bench hover ", _measure_line(await _measure(4.0, hov)))
	bg.queue_free()


func _measure(secs: float, hov: Array[CardWidget]) -> Array:
	var t0 := Time.get_ticks_usec()
	var last := t0
	var frames := 0
	var worst := 0
	var next_hover := 0.0
	var idx := 0
	var prev: CardWidget = null
	while Time.get_ticks_usec() - t0 < int(secs * 1e6):
		if not hov.is_empty() and (Time.get_ticks_usec() - t0) / 1e6 >= next_hover:
			next_hover += 0.15
			if prev != null:
				prev.create_tween().tween_property(prev, "lift_k", 1.0, 0.09)
			prev = hov[idx % hov.size()]
			idx += 1
			var tw := prev.create_tween().set_parallel(true)
			tw.tween_property(prev, "lift_offset", Vector2(0, -30), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(prev, "lift_k", 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.chain().tween_property(prev, "lift_offset", Vector2.ZERO, 0.02)
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		frames += 1
	return [frames, Time.get_ticks_usec() - t0, worst]


func _measure_line(m: Array) -> String:
	return "frames %d in %.2fs = %.1f fps, worst frame %.2f ms" % [m[0], m[1] / 1e6, m[0] / (m[1] / 1e6), m[2] / 1000.0]
