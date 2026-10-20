extends SceneTree
## Windowed gallery of the release-batch polish components (WP-2 TitleText, WP-3 HpVial + ApGemRow),
## for retained screenshots. Run from rldb/ (not headless: it needs a real renderer):
##   godot --path . -s res://src/dev/polish_components_gallery.gd -- <out_dir> [1600x1000] [titles|vial|all]
## Shots: titles on dark and parchment grounds (before / after), the HP vial at full / mid / low /
## zero, mid-damage and mid-heal frames (frozen with an injected clock), the AP gems, a reduce-motion
## pass and a zoomed crop for edge crispness.

var out_dir: String = ""
var tag: String = ""
var which: String = "all"
var fails: int = 0
## Fake clock shared by every component on screen (seconds); frozen frames set it directly.
var now: float = 100.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://polish_gallery"
	var sz := Vector2i(1600, 1000)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	if args.size() > 2:
		which = String(args[2])
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	root.theme = UIStyle.make_theme()
	# The gallery shows the full-motion look whatever this machine's saved settings say.
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	run.call_deferred()


func _clock() -> float:
	return now


func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


func _snap(name: String, wait: float = 0.4) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


func _clear() -> void:
	for c in root.get_children():
		if c is Control:
			c.queue_free()
	await process_frame


## Parchment inset (the light ground): warm paper with pebble grain and a soft dark rim.
class Parchment extends Control:
	func _init() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var base := Color("cdb88e")
		draw_rect(r, base)
		UiSurface.draw_round(self, r, 0.0, UiSurface.PEBBLE, base, 0.55, 256.0)
		for i in 10:
			var g := float(i) * 3.0
			draw_rect(r.grow(-g), Color(0.25, 0.15, 0.05, 0.05), false, 3.0)


func _ground(rect: Rect2, parchment: bool) -> Control:
	var c: Control
	if parchment:
		c = Parchment.new()
	else:
		c = UIStyle.background(0.25, UIStyle.MENU_BACKGROUND)
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.clip_contents = true
	c.position = rect.position
	c.size = rect.size
	root.add_child(c)
	return c


func _caption(parent: Control, text: String, pos: Vector2, dark_ground: bool) -> void:
	var l := UIStyle.label(text, 13, UIStyle.MUTED if dark_ground else Color("3a2a14"))
	l.position = pos
	parent.add_child(l)


func _title(parent: Control, text: String, tier: int, pos: Vector2, size: int = 0) -> TitleText:
	var t := TitleText.make(text, tier, size)
	t.clock = _clock
	t.position = pos
	parent.add_child(t)
	t.size = t.get_combined_minimum_size()
	return t


func _plain(parent: Control, text: String, size: int, pos: Vector2, col: Color = UIStyle.GOLD) -> void:
	var l := UIStyle.title_label(text, size, col)
	l.position = pos
	parent.add_child(l)


func shots_titles() -> void:
	for parchment in [false, true]:
		await _clear()
		var g := _ground(Rect2(Vector2.ZERO, Vector2(root.size)), parchment)
		var dark: bool = not parchment
		var w := float(root.size.x)
		var col_x := w * 0.52
		_caption(g, "BEFORE (current plain Cinzel)", Vector2(40, 18), dark)
		_caption(g, "AFTER (TitleText tiers)", Vector2(col_x, 18), dark)
		_plain(g, "RLDB", 88, Vector2(40, 40))
		var hero := _title(g, "RLDB", TitleText.Tier.HERO, Vector2(col_x, 40))
		_plain(g, "DEFEAT", 80, Vector2(40, 170), UIStyle.BAD)
		_title(g, "DEFEAT", TitleText.Tier.HERO_DEFEAT, Vector2(col_x, 170), 80)
		_plain(g, "VICTORY", 64, Vector2(40, 290))
		_title(g, "VICTORY", TitleText.Tier.HERO, Vector2(col_x, 290), 64)
		_plain(g, "CHOOSE YOUR DECK", 36, Vector2(40, 400))
		_title(g, "CHOOSE YOUR DECK", TitleText.Tier.SCREEN, Vector2(col_x, 400))
		_plain(g, "Card Catalogue", 30, Vector2(40, 470))
		_title(g, "Card Catalogue", TitleText.Tier.SCREEN, Vector2(col_x, 470), 30)
		_plain(g, "Resume", 34, Vector2(40, 540), UIStyle.TEXT)
		_title(g, "Resume", TitleText.Tier.MENU, Vector2(col_x, 540))
		var hov := _title(g, "Play", TitleText.Tier.MENU, Vector2(col_x + 220, 540))
		hov.set_hovered(true, true)
		_caption(g, "hovered", Vector2(col_x + 220, 590), dark)
		_plain(g, "GAME LOG", 18, Vector2(40, 630))
		var sec := _title(g, "GAME LOG", TitleText.Tier.SECTION, Vector2(col_x, 630))
		sec.size = Vector2(300, sec.size.y)
		_plain(g, "CARD DETAILS", 16, Vector2(40, 690))
		var sec2 := _title(g, "Card Details", TitleText.Tier.SECTION, Vector2(col_x, 690), 16)
		sec2.uppercase = true
		sec2.size = Vector2(300, sec2.get_combined_minimum_size().y)
		# apply(): an existing Label restyled in place (wrapping prompt title, then a recolour).
		var l := UIStyle.label("Choose a stance for Bastion Wyrm, the Eternal Guardian", 17, UIStyle.TEXT, true, true)
		l.position = Vector2(col_x, 750)
		l.size = Vector2(300, 0)
		g.add_child(l)
		TitleText.apply(l, TitleText.Tier.SCREEN, 17)
		var l2 := UIStyle.label("Ben", 18, UIStyle.TEXT, false, true)
		l2.position = Vector2(col_x + 380, 750)
		g.add_child(l2)
		TitleText.apply(l2, TitleText.Tier.SECTION)
		l2.add_theme_color_override("font_color", UIStyle.GOLD_HI)
		_caption(g, "apply(Label): wrapped T2 / recoloured T3 name", Vector2(col_x, 850), dark)
		_plain(g, "Choose a stance for Bastion Wyrm, the Eternal Guardian", 17, Vector2(40, 750), UIStyle.TEXT)
		var name := "02_titles_parchment" if parchment else "01_titles_dark"
		await _snap(name)
		if not parchment:
			# A frame in the middle of the hero's sweep pass.
			now = 100.0 + TitleText.SWEEP_FIRST_DELAY + TitleText.SWEEP_DURATION * 0.5
			hero._process(0.0)
			_check("hero sweep is mid-pass", is_equal_approx(hero.current_sweep_phase(), 0.5))
			print("sweep uniforms: x=%s strength=%s" % [hero._mat.get_shader_parameter("sweep_x"), hero._mat.get_shader_parameter("sweep_strength")])
			await _snap("03_titles_sweep_mid")
			now = 100.0
	# Zoom: crop the real-size dark shot (nearest neighbour, 3x) so edge quality can be judged.
	var img := Image.load_from_file(out_dir.path_join("01_titles_dark_%s.png" % tag))
	if img != null:
		var w := float(root.size.x)
		var crop := img.get_region(Rect2i(int(w * 0.52) - 20, 20, 500, 300))
		crop.resize(1500, 900, Image.INTERPOLATE_NEAREST)
		crop.save_png(out_dir.path_join("04_titles_zoom3x_%s.png" % tag))
		# D3 acceptance: at 50% desaturation every title still separates from the ground.
		var grey := img.duplicate() as Image
		for y in grey.get_height():
			for x in grey.get_width():
				var c := grey.get_pixel(x, y)
				var l := c.get_luminance()
				grey.set_pixel(x, y, c.lerp(Color(l, l, l), 0.5))
		grey.save_png(out_dir.path_join("06_titles_dark_desat50_%s.png" % tag))
		var crop2 := img.get_region(Rect2i(int(w * 0.52) - 20, 610, 400, 120))
		crop2.resize(1600, 480, Image.INTERPOLATE_NEAREST)
		crop2.save_png(out_dir.path_join("05_section_zoom4x_%s.png" % tag))


## A clock cell: components read `cell.t`, so each one can be frozen at its own frame.
func _cell_clock(cell: Dictionary) -> Callable:
	return func() -> float: return float(cell["t"])


## A plate-like frame (the current PlayerPlate panel style) holding a name, a vial and the gems.
func _plate(parent: Control, pos: Vector2, title: String, caption: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiSurface.box(UIStyle.panel_style(Color(UIStyle.PANEL, 0.94), UIStyle.BRONZE, 10), UiSurface.LEATHER, UIStyle.PANEL_GRAIN))
	pc.position = pos
	pc.custom_minimum_size = Vector2(PlayerPlate.PLATE_W, 0)
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	var name := UIStyle.label(title, 19, UIStyle.TEXT, false, true)
	v.add_child(name)
	var tt := TitleText.apply(name, TitleText.Tier.SECTION, 18)
	tt.show_underline = false
	name.add_theme_color_override("font_color", UIStyle.TEXT)
	var cap := UIStyle.label(caption, 12, UIStyle.MUTED)
	cap.position = pos + Vector2(0, -20)
	parent.add_child(cap)
	return v


func _vial(box: VBoxContainer, hp: int, cell: Dictionary, p_max: int = 60) -> HpVial:
	var hv := HpVial.new()
	hv.clock = _cell_clock(cell)
	hv.is_local = true
	box.add_child(hv)
	# The plate integration hook: a low vial shifts the plate border to ember red.
	var pc := box.get_parent() as PanelContainer
	hv.low_hp_changed.connect(func(low: bool) -> void:
		var sb := UiSurface.restyled(pc.get_theme_stylebox("panel"), func(f: StyleBoxFlat) -> void:
			f.border_color = HpVial.LOW_PLATE_BORDER if low else UIStyle.BRONZE)
		pc.add_theme_stylebox_override("panel", sb))
	hv.set_value(hp, p_max, true)
	# Deterministic shader frame: the glint just past the number, the low-HP pulse at its peak.
	hv.freeze_shader_time(0.55)
	return hv


func _gems(box: VBoxContainer, ap: int, start: int, peak: int, cell: Dictionary) -> ApGemRow:
	var g := ApGemRow.new()
	g.clock = _cell_clock(cell)
	box.add_child(g)
	g.set_values(ap, start, peak, true)
	return g


func shots_vial() -> void:
	await _clear()
	var bg := UIStyle.background(0.15)
	root.add_child(bg)
	var col_w := 300.0
	var x0 := 40.0
	# Row 0: the current plate for comparison.
	var hdr := UIStyle.label("BEFORE: the current PlayerPlate (HpBar + ApGems)", 13, UIStyle.MUTED)
	hdr.position = Vector2(x0, 14)
	bg.add_child(hdr)
	var before_vals := [[60, 2, 2], [34, 1, 2], [12, 0, 2], [0, 0, 0]]
	for i in before_vals.size():
		var old := PlayerPlate.new()
		old.position = Vector2(x0 + col_w * i, 40)
		bg.add_child(old)
		var bv: Array = before_vals[i]
		old.update_from({"name": "Ben", "hp": bv[0], "ap": bv[1], "ap_start": bv[2], "ap_peak": bv[2]}, i == 0, true, "", "")
	var hdr2 := UIStyle.label("AFTER: HpVial + ApGemRow (states frozen with an injected clock)", 13, UIStyle.MUTED)
	hdr2.position = Vector2(x0, 168)
	bg.add_child(hdr2)
	var cells: Array[Dictionary] = []
	for i in 12:
		cells.append({"t": 100.0})
	# Row 1: steady states.
	var states := [["Full 60 / 60", 60, 2, 2, 2], ["Mid 34 / 60", 34, 1, 2, 2], ["Low 12 / 60 (pulse, crack)", 12, 3, 2, 4], ["Zero 0 / 60", 0, 0, 0, 0]]
	var vials: Array[HpVial] = []
	for i in states.size():
		var st: Array = states[i]
		var b := _plate(bg, Vector2(x0 + col_w * i, 220), "Ben", st[0])
		vials.append(_vial(b, st[1], cells[i]))
		_gems(b, st[2], st[3], st[4], cells[i])
	# Row 2: animation frames.
	var frames := ["Damage 60 -> 34, +0.20 s (amber hold)", "Damage drain, +0.62 s (embers)", "Heal 20 -> 44, +0.12 s (pour, shimmer)", "Critical 5 / 60 (motes)"]
	var anim: Array[HpVial] = []
	var gem_rows: Array[ApGemRow] = []
	for i in frames.size():
		var b := _plate(bg, Vector2(x0 + col_w * i, 400), "Ana", frames[i])
		var start_hp := [60, 60, 20, 5][i] as int
		anim.append(_vial(b, start_hp, cells[4 + i]))
		gem_rows.append(_gems(b, 2, 2, 2, cells[4 + i]))
	await process_frame
	anim[0].set_hp(34)
	anim[1].set_hp(34)
	anim[2].set_hp(44)
	# AP: a gem popping in (frame 0) and a gem being spent (frame 1).
	gem_rows[0].set_values(1, 2, 2, true)
	gem_rows[0].set_values(2, 2, 2)
	gem_rows[1].set_values(1, 2, 2)
	gem_rows[2].set_values(3, 2, 3)
	for k in 8:
		cells[4]["t"] = 100.0 + 0.2 * float(k + 1) / 8.0
		anim[0].step()
	gem_rows[0].step()
	for k in 16:
		cells[5]["t"] = 100.0 + 0.62 * float(k + 1) / 16.0
		anim[1].step()
	gem_rows[1].step()
	for k in 8:
		cells[6]["t"] = 100.0 + 0.12 * float(k + 1) / 8.0
		anim[2].step()
	for k in 40:
		cells[7]["t"] = 100.0 + 2.0 * float(k + 1) / 40.0
		anim[3].step()
	cells[4]["t"] = 100.0 + 0.13   # gem pop mid-overshoot (the vial was stepped to +0.2 already)
	gem_rows[0].step()
	cells[4]["t"] = 100.0 + 0.2
	cells[5]["t"] = 100.0 + 0.62
	gem_rows[1].step()
	_check("damage frame: amber trail held at the old value", is_equal_approx(anim[0].trail_top_at(), 60.0))
	_check("drain frame: trail between old and new", anim[1].trail_top_at() < 60.0 and anim[1].trail_top_at() > 34.0)
	_check("drain frame: embers alive", anim[1].particle_count() > 0)
	_check("heal frame: liquid pouring", anim[2].liquid_level() > 20.0 and anim[2].liquid_level() < 44.0)
	_check("low vial is low", vials[2].low() and not vials[1].low())
	_check("critical vial has motes", anim[3].particle_count() > 0)
	# Row 3: shatter, max-HP stretch, wide AP, idle AP.
	var extra := ["Lethal shatter, +0.35 s", "Max HP 60 -> 80 (stretch)", "AP 3/5 (gained above allowance)", "Before the first turn"]
	var ex: Array[HpVial] = []
	var exg: Array[ApGemRow] = []
	for i in extra.size():
		var b := _plate(bg, Vector2(x0 + col_w * i, 580), "Ben", extra[i])
		ex.append(_vial(b, [8, 60, 41, 60][i] as int, cells[8 + i]))
		exg.append(_gems(b, [0, 2, 3, 0][i] as int, [2, 2, 2, 0][i] as int, [2, 2, 5, 0][i] as int, cells[8 + i]))
	await process_frame
	ex[0].shatter()
	for k in 12:
		cells[8]["t"] = 100.0 + 0.35 * float(k + 1) / 12.0
		ex[0].step()
	ex[1].max_hp = 80
	ex[1].set_hp(72)
	for k in 6:
		cells[9]["t"] = 100.0 + 0.5 * float(k + 1) / 6.0
		ex[1].step()
	await _snap("10_hp_vial_states")
	var img := root.get_texture().get_image()
	var crop := img.get_region(Rect2i(30, 200, 620, 360))
	crop.resize(1860, 1080, Image.INTERPOLATE_NEAREST)
	crop.save_png(out_dir.path_join("11_hp_vial_zoom3x_%s.png" % tag))
	var crop2 := img.get_region(Rect2i(630, 380, 620, 190))
	crop2.resize(1860, 570, Image.INTERPOLATE_NEAREST)
	crop2.save_png(out_dir.path_join("12_hp_vial_heal_zoom3x_%s.png" % tag))
	# Reduce motion: the same steady states, static.
	UIStyle.reduce_motion = true
	for hv in vials:
		hv.set_hp(hv.hp, true)
	await _snap("13_hp_vial_reduce_motion")
	UIStyle.reduce_motion = false


func run() -> void:
	if which == "titles" or which == "all":
		await shots_titles()
	if which == "vial" or which == "all":
		await shots_vial()
	print("DONE fails=%d" % fails)
	quit(1 if fails else 0)
