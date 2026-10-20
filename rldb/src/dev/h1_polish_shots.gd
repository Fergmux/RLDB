extends SceneTree
## Windowed evidence for the H1 polish pass (design/design-review-2026-10-20.md section 3):
## the WP-1 style foundation sheet (button families in every state, depth levels, F3 inset, F4
## chips, the selection brackets, the scroll area's fade masks and track, the spacing scale) and a
## reduce-motion pass. Run from rldb/ (not headless: it needs a real renderer):
##   godot --path . -s res://src/dev/h1_polish_shots.gd -- <out_dir> [1600x900] [wp1|all]

var out_dir: String = ""
var tag: String = ""
var which: String = "all"
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://h1_polish"
	var sz := Vector2i(1600, 900)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	if args.size() > 2:
		which = String(args[2])
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	DisplayServer.window_set_size(sz)
	root.theme = UIStyle.make_theme()
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	run.call_deferred()


func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


func _snap(name: String, wait: float = 0.5) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


func _clear() -> void:
	for c in root.get_children():
		if c is Control:
			c.queue_free()
	await process_frame


func _cap(parent: Control, text: String, pos: Vector2, size: int = 13, col: Color = UIStyle.MUTED) -> Label:
	var l := UIStyle.label(text, size, col)
	l.position = pos
	parent.add_child(l)
	return l


## Shows `b` frozen in `state` ("normal", "hover", "pressed", "focus", "disabled"): the state's box
## is copied into "normal" (a real hover needs the pointer), and the JuicyButton overlay follows.
func _freeze(b: Button, state: String) -> void:
	var jb := b as JuicyButton
	match state:
		"hover", "pressed":
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox(state))
			b.add_theme_color_override("font_color", b.get_theme_color("font_hover_color"))
			if jb != null:
				jb._hover = state == "hover"
				jb._down = state == "pressed"
				jb.pivot_offset = b.size / 2.0
				jb.scale = Vector2.ONE * (JuicyButton.HOVER_SCALE if state == "hover" else JuicyButton.PRESS_SCALE)
		"focus":
			jb.force_focus_ring = true
		"disabled":
			b.disabled = true
	b.queue_redraw()


func _family(f: String, text: String) -> Button:
	match f:
		"primary_button":
			return UIStyle.primary_button(text, 15)
		"danger_button":
			return UIStyle.danger_button(text, 15)
		"wine_button":
			return UIStyle.wine_button(text, 15)
	return UIStyle.secondary_button(text, 15)


func shots_wp1() -> void:
	await _clear()
	var bg := UIStyle.background(0.2)
	root.add_child(bg)
	var panel := OrnatePanel.new(14, 24)
	panel.position = Vector2(32, 32)
	panel.size = Vector2(1000, 836)
	bg.add_child(panel)
	var col := VBoxContainer.new()
	UIStyle.pad(col, "lg")
	panel.add_child(col)
	var head := UIStyle.label("WP-1 STYLE FOUNDATION: BUTTON FAMILIES (1.4.4)", 16, UIStyle.GOLD, false, true)
	col.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 6
	UIStyle.pad(grid, "md", "lg")
	col.add_child(grid)
	grid.add_child(Control.new())
	for s in ["Normal", "Hover", "Pressed", "Focus (keys)", "Disabled"]:
		grid.add_child(UIStyle.label(s, 13, UIStyle.MUTED))
	var focus_btn: Button = null
	for fam in [["Primary", "primary_button", "Start series"], ["Secondary", "secondary_button", "Keep playing"],
			["Danger", "danger_button", "Concede"], ["Wine (D13)", "wine_button", "Pass turn"]]:
		grid.add_child(UIStyle.label(fam[0], 14, UIStyle.TEXT))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var b: Button = _family(String(fam[1]), String(fam[2]))
			UIStyle.size_button(b, "standard")
			grid.add_child(b)
			if state == "focus" and focus_btn == null:
				focus_btn = b
			b.set_meta(&"freeze", state)
	col.add_child(UIStyle.label("Sizes: small 36 / standard 44 / hero 52 px; min width 120, 20 px text padding", 13, UIStyle.MUTED))
	var sizes := HBoxContainer.new()
	UIStyle.pad(sizes, "md")
	col.add_child(sizes)
	sizes.add_child(UIStyle.size_button(UIStyle.secondary_button("View deck", 14), "small"))
	sizes.add_child(UIStyle.size_button(UIStyle.secondary_button("Cancel"), "standard"))
	sizes.add_child(UIStyle.size_button(UIStyle.primary_button("Go to Battle Phase", 17), "hero"))
	col.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.5), true, 18))
	col.add_child(UIStyle.label("F3 INSET, F4 CHIPS, DEPTH LEVELS (1.3, 1.4.3)", 16, UIStyle.GOLD, false, true))
	var row := HBoxContainer.new()
	UIStyle.pad(row, "lg")
	col.add_child(row)
	var well := UIStyle.inset(UIStyle.PANEL_INK, 0.25)
	well.custom_minimum_size = Vector2(300, 96)
	var wl := UIStyle.label("Ben summons Basic Mage (Water).\nAna's turn begins: AP is set to 2.\nThe trap Mirror Force is set.", 14, UIStyle.TEXT, true)
	wl.add_theme_constant_override("line_spacing", 3)
	well.add_child(wl)
	row.add_child(well)
	var chips := HFlowContainer.new()
	chips.custom_minimum_size = Vector2(300, 0)
	chips.add_theme_constant_override("h_separation", UIStyle.sp("sm"))
	chips.add_theme_constant_override("v_separation", UIStyle.sp("sm"))
	for c in [["Attack stance", UIStyle.STATE_STEEL], ["Protected", UIStyle.GOOD], ["Water", UIStyle.type_color("Water")],
			["Fire", UIStyle.type_color("Fire")], ["Trap", UIStyle.CATEGORY_COLORS["trap"]], ["Setup", UIStyle.GOLD], ["Poisoned", UIStyle.STATUS_LINK]]:
		chips.add_child(UIStyle.chip(c[0], c[1], 13))
	row.add_child(chips)
	var depths := HBoxContainer.new()
	UIStyle.pad(depths, "lg")
	col.add_child(depths)
	for d in 5:
		var pc := PanelContainer.new()
		var sb := UIStyle.flat(UIStyle.PANEL, Color(UIStyle.BRONZE, 0.8), 1, 8)
		UIStyle.lift(sb, d)
		pc.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, UIStyle.PANEL_GRAIN))
		pc.custom_minimum_size = Vector2(150, 56)
		var dl := UIStyle.label(["0 Table", "1 Plate", "2 Raised", "3 Floating", "4 Modal"][d], 13, UIStyle.TEXT)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(dl)
		depths.add_child(pc)
	# Right column: selection brackets and a scroll area.
	var side := OrnatePanel.new(14, 24)
	side.position = Vector2(1064, 32)
	side.size = Vector2(504, 836)
	bg.add_child(side)
	var sc := VBoxContainer.new()
	UIStyle.pad(sc, "md")
	side.add_child(sc)
	sc.add_child(UIStyle.label("SELECTION (#29): GOLD FILIGREE", 16, UIStyle.GOLD, false, true))
	var sel := Brackets.new()
	sel.custom_minimum_size = Vector2(0, 200)
	sc.add_child(sel)
	sc.add_child(UIStyle.label("SCROLL AREA (#105): FADES + 8 PX TRACK", 16, UIStyle.GOLD, false, true))
	var sa := ScrollArea.new()
	sa.custom_minimum_size = Vector2(0, 430)
	sc.add_child(sa)
	var lines := VBoxContainer.new()
	UIStyle.pad(lines, "sm")
	for i in 30:
		var l := UIStyle.label("Credits line %d: Cinzel and Alegreya Sans (SIL OFL 1.1), card art, CC0 1.0 materials" % (i + 1), 14, UIStyle.TEXT, true)
		lines.add_child(l)
	sa.set_content(lines)
	await process_frame
	await process_frame
	for b in grid.get_children():
		if b is Button and b.has_meta(&"freeze"):
			_freeze(b, String(b.get_meta(&"freeze")))
	sa.scroll.scroll_vertical = 240
	await _snap("wp1_01_style_sheet", 0.8)
	# The real path: keyboard / code focus shows the ring, a click does not (no mouse is down here).
	var probe := UIStyle.secondary_button("Probe")
	probe.focus_mode = Control.FOCUS_ALL
	bg.add_child(probe)
	probe.position = Vector2(-400, -400)
	probe.grab_focus()
	_check("focus ring shown after grab_focus", (probe as JuicyButton).focus_ring_shown())
	_check("ring previews drawn on the focus column", focus_btn != null and (focus_btn as JuicyButton).focus_ring_shown())
	_check("scroll area shows both fades mid-list", sa._top.shown and sa._bot.shown)
	var bar := sa.scroll.get_v_scroll_bar()
	_check("scroll track is 8 px wide", is_equal_approx(bar.size.x, float(UIStyle.SCROLL_TRACK_W)))
	var img := root.get_texture().get_image()
	var crop := img.get_region(Rect2i(40, 40, 720, 330))
	crop.resize(1440, 660, Image.INTERPOLATE_NEAREST)
	crop.save_png(out_dir.path_join("wp1_02_buttons_zoom2x_%s.png" % tag))
	UIStyle.reduce_motion = true
	for b in grid.get_children():
		if b is JuicyButton:
			(b as JuicyButton).scale = Vector2.ONE
	await _snap("wp1_03_style_sheet_reduce_motion", 0.5)
	UIStyle.reduce_motion = false


## Card-sized slots with the selection brackets, the order badge and the magic preview for contrast.
class Brackets extends Control:
	func _draw() -> void:
		var w := 110.0
		var h := 154.0
		var y := (size.y - h) / 2.0
		for i in 3:
			var r := Rect2(24.0 + float(i) * (w + 46.0), y, w, h)
			var sb := UIStyle.flat(UIStyle.TABLE_INLAY, Color(UIStyle.BRONZE, 0.7), 1, 8)
			draw_style_box(sb, r)
			match i:
				0:
					CardOverlays._corner_brackets(self, r.grow(7.0), 9.0, UIStyle.SELECT.lightened(0.3), 2.4)
				1:
					CardOverlays._corner_brackets(self, r.grow(7.0), 9.0, UIStyle.SELECT.lightened(0.3), 2.4)
					var c := r.end - Vector2(6, h - 6)
					draw_circle(c, 11.0, UIStyle.SELECT.darkened(0.1), true, -1.0, true)
					draw_arc(c, 11.0, 0.0, TAU, 24, UIStyle.ON_GOLD, 1.5, true)
					draw_string(UIStyle.font_display(700), c + Vector2(-4, 5), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.ON_GOLD)
				2:
					var p := StyleBoxFlat.new()
					p.draw_center = false
					p.set_border_width_all(2)
					p.set_corner_radius_all(8)
					p.border_color = UIStyle.PREVIEW
					draw_style_box(p, r)
			draw_string(UIStyle.font_body(), Vector2(r.position.x, r.end.y + 18), ["selected", "ordered pick", "preview (blue)"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.MUTED)


func run() -> void:
	if which == "wp1" or which == "all":
		await shots_wp1()
	print("DONE fails=%d" % fails)
	quit(1 if fails else 0)
