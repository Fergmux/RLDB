extends SceneTree
## Dev-only windowed evidence for final review #11 (design/review-final-2026-11-05.md): the series
## scoreboard (SeriesScoreboard) in a top strip over the table, for best of 3 / 5 / 7 at the start, mid
## series and over, with short and long names. Saves the whole window and a 2x crop of the plaques at
## physical pixels, so the "BEST OF n" caption and the game dots can be judged at the real window
## size (1280x800 draws the 1600x1000 layout at 0.8x). Run NOT headless:
##   godot --path rldb -s res://src/dev/scoreboard_shots.gd -- <absolute output dir> [WxH]

var out_dir: String = ""
var win := Vector2i(1600, 1000)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://scoreboard_shots"
	if args.size() > 1 and String(args[1]).contains("x"):
		var p := String(args[1]).split("x")
		win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win)
	root.size = win
	run.call_deferred()


func _model(best: int, names: Array, results: Array, me: int = 0) -> Dictionary:
	var sc := [0, 0]
	for r in results:
		sc[int(r)] += 1
	var need := best / 2 + 1
	var winner := -1
	if sc[0] >= need or sc[1] >= need:
		winner = 0 if sc[0] > sc[1] else 1
	var over := winner != -1
	return {"best_of": best, "need": need, "names": names, "scores": sc, "results": results, "turns": [],
		"forfeit": [], "current": -1 if over else mini(results.size(), best - 1), "over": over, "winner": winner,
		"leader": -1 if sc[0] == sc[1] else (0 if sc[0] > sc[1] else 1), "me": me, "stage": "game", "playing": true}


func run() -> void:
	await process_frame
	var logical := root.get_visible_rect().size
	var bg := UIStyle.table_background()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var models := [
		_model(3, ["Ana", "Ben"], []),
		_model(3, ["Ana", "Ben"], [0]),
		_model(5, ["Maximiliana Thornwood", "Bartholomew Ashgrave"], [1, 0, 1]),
		_model(5, ["Ana", "Ben"], [0, 0, 1, 0]),
		_model(7, ["Ana", "Bartholomew Ashgrave"], [1, 1, 0, 1]),
		_model(3, ["Ana", "Ben"], [1, 1]),
	]
	var strips: Array[Control] = []
	var w := logical.x - 360.0   # the board's width beside the sidebar
	for i in models.size():
		var strip := ColorRect.new()
		strip.color = Color(0, 0, 0, 0.0)
		strip.position = Vector2(0, 30 + i * 70)
		strip.size = Vector2(w, GameScreen.TOP_H)
		root.add_child(strip)
		var guide := ColorRect.new()   # the strip's bounds, a faint line top and bottom
		guide.color = Color(1, 1, 1, 0.12)
		guide.position = Vector2(0, GameScreen.TOP_H)
		guide.size = Vector2(w, 1)
		strip.add_child(guide)
		var sb := SeriesScoreboard.new()
		sb.clock = func() -> float: return 0.6
		strip.add_child(sb)
		sb.visible = true
		sb.show_model(models[i], "k%d" % i)
		strips.append(strip)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var tag := "%dx%d" % [win.x, win.y]
	var full := img.duplicate() as Image
	if full.get_width() > 1600:
		full.resize(1600, int(full.get_height() * 1600.0 / full.get_width()), Image.INTERPOLATE_LANCZOS)
	full.save_jpg(out_dir.path_join("scoreboard_window_%s.jpg" % tag), 0.88)
	# A crop of the plaques at physical pixels, enlarged 2x (nearest) to judge the small type.
	var k := float(img.get_width()) / logical.x
	var sb0 := (strips[0].get_child(1) as Control)
	var widest := 0.0
	for s in strips:
		widest = maxf(widest, (s.get_child(1) as Control).size.x)
	var x0 := int(((w - widest) / 2.0 - 30.0) * k)
	var y0 := int(20.0 * k)
	var cw := int((widest + 60.0) * k)
	var ch := int((models.size() * 70.0 + 10.0) * k)
	var crop := img.get_region(Rect2i(maxi(0, x0), y0, mini(cw, img.get_width() - maxi(0, x0)), mini(ch, img.get_height() - y0)))
	var zoom := 2 if crop.get_width() * 2 <= 1600 else 1
	crop.resize(crop.get_width() * zoom, crop.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	if crop.get_width() > 1600:
		crop.resize(1600, int(crop.get_height() * 1600.0 / crop.get_width()), Image.INTERPOLATE_LANCZOS)
	crop.save_jpg(out_dir.path_join("scoreboard_crop_%s.jpg" % tag), 0.92)
	print("PASS  scoreboard shots at %s (logical %s, plaque %s)" % [tag, logical, sb0.size])
	quit(0)
