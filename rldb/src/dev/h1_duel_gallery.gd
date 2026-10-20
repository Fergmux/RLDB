extends SceneTree
## Windowed gallery of the H1 duel-side pieces (release batch 20 Oct 2026, WP-2 / WP-6) at a frozen
## moment each, for retained screenshots. Run from rldb/ (not headless: it needs a real renderer):
##   godot --path . -s res://src/dev/h1_duel_gallery.gd -- <out_dir> [1600x900] [coin|board|all]
## Shots: the coin flip's landed result (both seats' crests) and its reduce-motion state.

var out_dir: String = ""
var tag: String = ""
var which: String = "all"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://h1_duel_gallery"
	var sz := Vector2i(1600, 900)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	if args.size() > 2:
		which = String(args[2])
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	root.theme = UIStyle.make_theme()
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	run.call_deferred()


func _snap(name: String, wait: float = 0.4) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))
	print("shot ", name)


func _clear() -> void:
	for c in root.get_children():
		if c is Control:
			c.queue_free()
	await process_frame


func _table() -> Control:
	var bg := UIStyle.background(0.32)
	root.add_child(bg)
	return bg


func run() -> void:
	if which in ["coin", "all"]:
		await _coin_shots()
	quit(0)


## The coin lands on the first player's face; the T1 result title punches in above the veil.
func _coin_shots() -> void:
	for c in [["Ben", "Ana", false, 1, "coin_moon_opponent_first"], ["Ana", "Ben", true, 0, "coin_sun_you_first"]]:
		await _clear()
		_table()
		var coin := CoinFlip.new()
		coin.size = Vector2(root.size)
		root.add_child(coin)
		coin.play(String(c[0]), String(c[1]), bool(c[2]), int(c[3]))
		await _snap(String(c[4]) + "_landing", CoinFlip.SPIN_TIME + 0.12)
		await _snap(String(c[4]) + "_settled", 0.5)
	await _clear()
	UIStyle.reduce_motion = true
	_table()
	var calm := CoinFlip.new()
	calm.size = Vector2(root.size)
	root.add_child(calm)
	calm.play("Ben", "Ana", false, 1)
	await _snap("coin_reduce_motion", 0.3)
	UIStyle.reduce_motion = false
