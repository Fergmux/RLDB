extends SceneTree
## Dev-only windowed evidence for final review #13 (design/review-final-2026-11-05.md): the rules
## text of the longest-text cards against the card's bottom rim, at every size that shows it: the
## 150 px Extra Deck offer card (Raging Inferno was the reported one), the 210 px hover, the 224 px
## inspector card, the 120 px hand card, and field Powers / Traps at 85 px. Run NOT headless:
##   godot --path rldb -s res://src/dev/card_text_fit_shots.gd -- <absolute output dir>
## Saves card_text_fit_a.jpg / _b.jpg (q88) and a 2x crop of the offer cards' text wells.

var out_dir: String = ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://card_text_fit_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.size = Vector2i(1600, 1000)
	run.call_deferred()


## The ids of the cards with the longest rules text (after `first`), `n` in all.
func _longest(first: Array, n: int) -> Array:
	var all := []
	for d in CardDB.all():
		var t := CardText.card_text(MatchView.def_view(int(d["id"])))
		all.append([t.length(), int(d["id"])])
	all.sort_custom(func(a, b): return a[0] > b[0])
	var out := first.duplicate()
	for e in all:
		if out.size() >= n:
			break
		if not out.has(e[1]):
			out.append(e[1])
	return out


func _row(ids: Array, kind: String, sz: Vector2, y: float) -> float:
	var x := 20.0
	for id in ids:
		var w := CardWidget.new().setup(MatchView.def_view(int(id)), kind)
		w.auto_hover = false
		root.add_child(w)
		GameUi.resize_card(w, sz)
		w.position = Vector2(x, y)
		x += sz.x + 14.0
	return y + sz.y + 18.0


func run() -> void:
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.09, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var ids := _longest([98], 7)
	var y := 16.0
	y = _row(ids, "mini", Vector2(150, 225), y)
	y = _row(ids, "hand", Vector2(120, 180), y)
	y = _row(_longest([], 12).slice(0, 12), "power", Vector2(85, 128), y)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_jpg(out_dir.path_join("card_text_fit_a.jpg"), 0.88)
	# 2x crop of the lower halves of the first four 150 px offer cards (the reported size).
	var crop := img.get_region(Rect2i(10, 16 + 110, 4 * 164 + 10, 225 - 110 + 12))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	crop.save_jpg(out_dir.path_join("card_text_fit_offer_crop_2x.jpg"), 0.9)
	for c in root.get_children():
		if c is CardWidget:
			c.queue_free()
	await process_frame
	y = 16.0
	y = _row(ids.slice(0, 6), "mini", Vector2(210, 315), y)
	y = _row(ids.slice(0, 6), "big", Vector2(224, 336), y)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out_dir.path_join("card_text_fit_b.jpg"), 0.88)
	print("PASS  card text fit shots: %s" % str(ids))
	quit(0)
