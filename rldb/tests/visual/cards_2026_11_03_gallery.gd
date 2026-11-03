extends SceneTree
## Visual evidence for the 3 November 2026 main-deck card changes
## (design/card-database-update-2026-11-03.md): the new Trap Do Not Open Box and changed cards,
## drawn by the real CardWidget from MatchView.card_view of real match instances. Run WINDOWED:
##   godot --path rldb -s res://tests/visual/cards_2026_11_03_gallery.gd -- <output dir>
## Writes cards_big.jpg (the 224x336 inspector size) and cards_hand.jpg (hand size plus a board
## with a Dragon Rider put in Defense stance behind its Dragon).

const IDS := [191, 12, 21, 135, 45, 67]

var _out_dir := "user://cards_2026_11_03"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1500, 820)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _shoot("cards_big", _page_big)
	await _shoot("cards_hand", _page_hand)
	print("cards_2026_11_03_gallery: done -> ", _out_dir)
	quit(0)


func _shoot(name: String, builder: Callable) -> void:
	var bg := ColorRect.new()
	bg.color = Color("2a211a")
	bg.size = Vector2(root.size)
	root.add_child(bg)
	builder.call(bg)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_jpg("%s/%s.jpg" % [_out_dir, name], 0.88)
	print("cards_2026_11_03_gallery: ", name, " ", err)
	bg.queue_free()
	await process_frame


func _caption(parent: Control, text: String, pos: Vector2) -> void:
	var l := UIStyle.label(text, 13, UIStyle.MUTED)
	l.position = pos
	parent.add_child(l)


func _card(parent: Control, v: Dictionary, kind: String, pos: Vector2, rot := false) -> void:
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind, "", rot)
	w.position = pos
	parent.add_child(w)


## card_view of a fresh instance of `id` owned by seat 0, seen by seat 0, in `zone`.
func _view(m: MatchEngine, id: int, zone: String = "hand") -> Dictionary:
	var uid := TB.card(m, 0, id, zone)
	return MatchView.card_view(m, uid, 0)


func _page_big(p: Control) -> void:
	var m := TB.make()
	_caption(p, "3 Nov 2026: Do Not Open Box (new), Tag Team - X, Shen, Dragon Rider, Magic Cylinder, Void Basilisk", Vector2(16, 8))
	for i in IDS.size():
		_card(p, _view(m, IDS[i]), "big", Vector2(16 + i * 244, 36))


func _page_hand(p: Control) -> void:
	var m := TB.make()
	_caption(p, "hand size", Vector2(16, 8))
	for i in IDS.size():
		_card(p, _view(m, IDS[i]), "hand", Vector2(16 + i * 130, 32))
	# A Dragon Rider summoned behind a Dragon is put in Defense stance; the Dragon shows +14 ATK.
	var dragon := TB.unit(m, 0, 2, 0)
	var rider := TB.summon(m, 0, 135, 3)
	_caption(p, "board: Dragon Rider behind a Basic Dragon (Rider forced to Defense, Dragon 22 ATK)", Vector2(16, 236))
	_card(p, MatchView.card_view(m, dragon, 0), "board", Vector2(16, 262))
	_card(p, MatchView.card_view(m, rider, 0), "board", Vector2(16, 400), m.cards[rider]["stance"] == "def")
