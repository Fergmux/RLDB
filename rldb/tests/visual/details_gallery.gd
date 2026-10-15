extends SceneTree
## Visual gallery for CardDetailsPanel and the PlayerPlate AP slots (F02-06 / F02-08).
## Run WINDOWED (needs a renderer):
##   godot --path rldb -s res://tests/visual/details_gallery.gd -- <out dir>
## Writes one PNG per case at the real sidebar size (340 px wide, 470 px tall scroll region)
## plus ap_slots.png, and prints each panel's natural height (>470 means it scrolls).

const SIDEBAR_W := 340
const REGION_H := 470

var out_dir := "user://details_gallery"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.theme = UIStyle.make_theme()
	root.size = Vector2i(SIDEBAR_W + 40, REGION_H + 70)
	_run.call_deferred()


func _longest_text_id() -> int:
	var best := -1
	var best_len := -1
	for d in CardDB.all():
		var n := 0
		for k in ["condition", "on_summon", "on_field", "on_destruction"]:
			n += String(d[k]).length()
		if n > best_len:
			best_len = n
			best = int(d["id"])
	return best


func _cases() -> Array:
	var out := []
	var m := TB.make()
	# Typical unit on the field with a modifier and a status.
	var u1 := TB.unit(m, 0, 14, 0)
	m.cards[u1]["st"]["retain"] = 1
	out.append(["unit_typical", MatchView.card_view(m, u1, 0), ["Cannot attack: it is not your Battle Phase."]])
	# Busy unit: several statuses, runes, modifiers (aura), ability.
	var m2 := TB.make()
	var u2 := TB.unit(m2, 0, 23, 1, "def", 31, 20)
	m2.cards[u2]["st"].merge({"burn": 4, "retain": 2, "paralyse": 1, "pierce": 1, "curse": 1})
	m2.cards[u2]["runes"] = 2
	m2.cards[u2]["summoned_turn"] = m2.turn
	m2.cards[u2]["attacked_turn"] = m2.turn
	TB.unit(m2, 1, 1, 0)
	out.append(["unit_busy", MatchView.card_view(m2, u2, 0), ["Cannot attack: this unit is Paralysed."]])
	var m2b := TB.make()
	var u2b := TB.unit(m2b, 0, 20, 0)
	TB.unit(m2b, 1, 1, 0)
	TB.unit(m2b, 1, 1, 1)
	TB.unit(m2b, 1, 1, 2)
	out.append(["unit_aura_modifiers", MatchView.card_view(m2b, u2b, 0), []])
	var m3 := TB.make()
	var lid := _longest_text_id()
	var ul := TB.card(m3, 0, lid, "hand")
	out.append(["longest_text_id%d" % lid, MatchView.card_view(m3, ul, 0), []])
	var m3b := TB.make()
	var ul2 := TB.card(m3b, 0, 12, "hand")
	out.append(["unit_ability_cost", MatchView.card_view(m3b, ul2, 0), []])
	var specs := [["spell", 182, "hand"], ["trap", 45, "backrow"], ["power", 149, "hand"],
		["fusion", 141, "extra"], ["ritual", 63, "extra"], ["arcane", 176, "extra"]]
	for sp in specs:
		var mm := TB.make()
		var uid: int
		if sp[2] == "backrow":
			uid = TB.set_card(mm, 0, sp[1], 0)
		else:
			uid = TB.card(mm, 0, sp[1], sp[2])
		out.append([sp[0], MatchView.card_view(mm, uid, 0), []])
	out.append(["empty", {}, []])
	return out


func _run() -> void:
	var bg := ColorRect.new()
	bg.color = UIStyle.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var title := UIStyle.label("", 13, UIStyle.MUTED)
	title.position = Vector2(20, 4)
	root.add_child(title)
	var sc := ScrollContainer.new()
	sc.position = Vector2(20, 30)
	sc.size = Vector2(SIDEBAR_W, REGION_H)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var panel := CardDetailsPanel.new()
	sc.add_child(panel)
	var frame := Panel.new()   # outline of the 340x470 region
	frame.position = sc.position - Vector2(1, 1)
	frame.size = sc.size + Vector2(2, 2)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.flat(Color.TRANSPARENT, Color(UIStyle.BAD, 0.6), 1, 0)
	frame.add_theme_stylebox_override("panel", sb)
	root.add_child(frame)
	var report := []
	for c in _cases():
		panel.show_card(c[1], c[2])
		title.text = "%s  (region %dx%d)" % [c[0], SIDEBAR_W, REGION_H]
		await process_frame
		await process_frame
		await process_frame
		var h := int(panel.get_combined_minimum_size().y)
		report.append("%s: natural height %d px (%s)" % [c[0], h, "fits" if h <= REGION_H else "SCROLLS"])
		root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, c[0]])
	for r in report:
		print(r)
	sc.queue_free()
	frame.queue_free()
	title.queue_free()
	await _plates(bg)
	quit()


func _plates(_bg: Control) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(10, 10)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	var cases := [
		["start 2 ap 2", 2, 2, 2], ["start 2 ap 1 (spent 1)", 1, 2, 2], ["start 2 ap 0 (spent 2)", 0, 2, 2],
		["start 3 ap 3 (Marked)", 3, 3, 3], ["start 2 peak 4 ap 3", 3, 2, 4], ["before first turn", 0, 0, 0],
		["start 2 peak 14 ap 9", 9, 2, 14], ["start 2 peak 25 ap 25", 25, 2, 25],
	]
	for cs in cases:
		var plate := PlayerPlate.new()
		box.add_child(plate)
		plate.update_from({"name": cs[0], "hp": 60, "ap": cs[1], "ap_start": cs[2], "ap_peak": cs[3],
			"counts": {"hand": 5, "draw": 20, "spent": 2, "exhaust": 0, "extra": 3}}, false, true, "", "")
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	box.add_theme_constant_override("separation", 2)
	await process_frame
	await process_frame
	img = root.get_texture().get_image()
	img.get_region(Rect2i(0, 0, 330, 640)).save_png("%s/ap_slots_all.png" % out_dir)
	var crop := img.get_region(Rect2i(0, 270, 340, 330))
	crop.resize(1020, 990, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/ap_slots.png" % out_dir)
	print("plates saved")
