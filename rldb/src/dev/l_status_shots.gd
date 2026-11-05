extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for L8 (design/owner-feedback-2026-11-05.md): the status
## application effects (FxStatus), the Cleanse / Curse ward flash, the redesigned status badges at
## field, hand and inspector sizes, and field cards carrying several statuses. Launched through its
## boot script, NOT headless:
##   godot --path rldb -s res://src/dev/l_status_shots_boot.gd -- <absolute dir> [before] --l-status-shots
## Writes JPG screenshots (q88, at most 1600 px wide) and `l_status_report.json`, then quits.

const TB_WATER := 1
const TB_FIRE := 110
const TB_EARTH := 120
## Seconds after an application is broadcast when its effect is at its peak (FxStatus.PEAK_AT plus a
## frame or two for the view to arrive).
const PEAK := FxStatus.PEAK_AT + 0.04

## True: only the shots of the "before" pair (board, field close-ups, badge sheet, one old effect).
var before := false
var _sfx_seen: Array = []


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only: the player's audio settings file is never written
	await _frames(5)
	main._privacy = false
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	_stage()
	host.broadcast()
	_view_seat(a)
	await _wait(4.2)          # past the coin flip and the deal
	await _steps()
	_finish()


func _stage() -> void:
	a = m.active
	o = 1 - a
	uids["u0"] = _put(a, TB_WATER, 0, "atk")
	uids["u1"] = _put(a, TB_FIRE, 1, "atk")
	uids["u2"] = _put(a, TB_EARTH, 2, "def")
	uids["u3"] = _put(a, 13, 3, "atk")
	uids["t0"] = _put(o, TB_FIRE, 0, "atk")
	uids["t1"] = _put(o, TB_WATER, 1, "atk")
	uids["t2"] = _put(o, TB_EARTH, 2, "atk")
	uids["t3"] = _put(o, 13, 3, "atk")
	var st0: Dictionary = m.cards[uids["u0"]]["st"]
	st0["poison"] = 3
	st0["burn"] = 2
	st0["paralyse"] = 1
	var st1: Dictionary = m.cards[uids["u1"]]["st"]
	st1["eternal"] = 1
	st1["cleanse"] = 2
	st1["medic"] = 1
	m.cards[uids["u1"]]["runes"] = 2
	var st2: Dictionary = m.cards[uids["u2"]]["st"]
	st2["curse"] = 1
	st2["blind"] = 1
	st2["debilitate"] = 2
	var st3: Dictionary = m.cards[uids["u3"]]["st"]
	for s in ["nimble", "pierce", "infiltrate", "reveal", "retain"]:
		st3[s] = 1
	st3["nimble"] = 4
	m.players[a]["ap"] = 6
	m.add_log("[dev] Board arranged for the L8 status evidence run.")


func _steps() -> void:
	await _move(Vector2(1300, 60))
	await _shot("board_statuses" + ("_before" if before else "_after"))
	await _closeups("field_cards" + ("_before" if before else "_after"))
	await _badge_sheet("badge_sheet" + ("_before" if before else ""))
	await _badge_sheet("badge_zoom" + ("_before" if before else ""), true)
	await _inspect_shot("inspect_statuses" + ("_before" if before else "_after"))
	if before:
		var crop := await _apply_and_grab(uids["t0"], ["poison"], PEAK)
		await _show_sheet("effect_before_poison", [[crop, "Poison (before)"]], 1)
		return
	await _effects_sheet()
	await _blocked_sheet()
	await _stack_strip()
	await _ticks_sheet()
	await _control_strip()


# ---------------------------------------------------------------- shots

## Field cards u0..u3 enlarged x2.5 side by side.
func _closeups(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var tiles := []
	for k in ["u0", "u1", "u2", "u3"]:
		var slot := int(m.cards[uids[k]]["slot"])
		var r := _slot_rect(a, "unit", slot).grow(6)
		tiles.append([_crop(img, r, 2.5), ""])
	await _show_sheet(name, tiles, 4)


## The inspector's big card for u3 (many statuses) and u0.
func _inspect_shot(name: String) -> void:
	var w := _w_slot(a, "unit", int(m.cards[uids["u0"]]["slot"]))
	await _rclick(w.get_global_rect().get_center())
	await _wait(0.6)
	await _shot(name)
	CardInspector.close_topmost()
	await _wait(0.4)
	await _move(Vector2(1300, 60))


func _rclick(pos: Vector2) -> void:
	await _move(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_RIGHT
		ev.pressed = pressed
		get_viewport().push_input(ev, true)
		await _frames(1)
	await _frames(3)


## Every status token at the on-screen field, hand and inspector sizes (measured from the widgets on
## screen at 1600x1000), plus 2x inspector size, with stack counts.
func _badge_sheet(name: String, zoom: bool = false) -> void:
	var fw := _w_slot(a, "unit", 0)
	var k_field := fw.card_rect().size.x / 85.0
	var field_px := float(CardLayouts.FIELD["icons"][3]) * k_field
	var tall := float(CardLayouts.TALL["icons_unit"][3])
	var hand_px := tall * (gs.hand.items.values()[0]["widget"] as CardWidget).card_rect().size.x / 120.0 if not gs.hand.items.is_empty() else tall
	var big_px := tall * 224.0 / 120.0 * 1.25
	var sheet := BadgeSheet.new()
	sheet.sizes = [field_px, hand_px, big_px, big_px * 2.0]
	sheet.zoom = zoom
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 200
	get_tree().root.add_child(layer)
	layer.add_child(sheet)
	await _wait(0.3)
	_check("badge sheet sizes %s" % str(sheet.sizes), field_px > 8.0)
	await _shot(name)
	layer.queue_free()
	await _frames(2)


## Applies `statuses` (one stack each, one batch) to `uid`, broadcasts, waits `at` seconds and
## returns a crop around the unit (an ImageTexture).
func _apply_and_grab(uid: int, statuses: Array, at: float, blocked_by: String = "") -> ImageTexture:
	await _settle()
	m.cards[uid]["st"].clear()
	m.cards[uid]["runes"] = 0
	if blocked_by != "":
		m.cards[uid]["st"][blocked_by] = 1
	host.broadcast()
	await _wait(0.25)
	await _settle()
	var batch := {}
	for s in statuses:
		m.apply_status(uid, s, 1, batch)
	host.broadcast()
	await _wait(at)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var r := _slot_rect(int(m.cards[uid]["ctl"]), "unit", int(m.cards[uid]["slot"]))
	return _crop(img, r.grow_individual(r.size.x * 0.45, r.size.y * 0.38, r.size.x * 0.45, r.size.y * 0.2), 1.6)


func _settle() -> void:
	var g := 0
	while gs.fx.busy() and g < 200:
		await _frames(1)
		g += 1


func _effects_sheet() -> void:
	var tiles := []
	var order := ["poison", "burn", "paralyse", "curse", "blind", "debilitate", "reveal",
		"eternal", "cleanse", "medic", "nimble", "pierce", "infiltrate", "retain", "rune"]
	for s in order:
		var tex := await _apply_and_grab(uids["t1"], [s], PEAK)
		tiles.append([tex, s.capitalize()])
		_check("L8 %s schedules status_%s" % [s, s], _planned("sfx:status_" + s))
		_check("L8 %s plays its look" % s, _planned("status:" + s))
	await _show_sheet("effects_peak_sheet", tiles, 5)


func _blocked_sheet() -> void:
	var tiles := []
	tiles.append([await _apply_and_grab(uids["t1"], ["poison"], 0.30, "cleanse"), "Poison stopped by Cleanse"])
	_check("L8 status_blocked flash and sound (cleanse)", _planned("status_blocked") and _planned("sfx:status_blocked"))
	tiles.append([await _apply_and_grab(uids["t1"], ["eternal"], 0.30, "curse"), "Eternal stopped by Curse"])
	await _show_sheet("blocked_ward_flash", tiles, 2)


## Three statuses applied at once: frames through the stagger.
func _stack_strip() -> void:
	await _settle()
	var uid: int = uids["t2"]
	m.cards[uid]["st"].clear()
	host.broadcast()
	await _wait(0.3)
	await _settle()
	var batch := {}
	for s in ["poison", "burn", "curse"]:
		m.apply_status(uid, s, 1, batch)
	host.broadcast()
	var tiles := []
	var t0 := Time.get_ticks_msec()
	for at in [0.3, 0.7, 1.1, 1.5, 2.1]:
		while Time.get_ticks_msec() - t0 < int(at * 1000.0):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var r := _slot_rect(o, "unit", int(m.cards[uid]["slot"]))
		tiles.append([_crop(img, r.grow_individual(r.size.x * 0.45, r.size.y * 0.38, r.size.x * 0.45, r.size.y * 0.2), 1.6), "%.1f s" % at])
	await _show_sheet("stacked_three_statuses", tiles, 5)


## Ticks (Poison, Burn, Medic) and a status wearing off, at their peaks.
func _ticks_sheet() -> void:
	var tiles := []
	for s in ["poison", "burn", "medic"]:
		await _settle()
		var uid: int = uids["t1"]
		m.cards[uid]["st"].clear()
		host.broadcast()
		await _wait(0.3)
		await _settle()
		m.add_log("[dev] %s tick" % s)
		m.status_fx(uid, "status_tick", s, 2)
		host.broadcast()
		await _wait(FxStatus.TICK_LENGTH * 0.4)
		tiles.append([_grab(uid), "%s tick" % s.capitalize()])
		_check("L8 %s tick look" % s, _planned("status_tick"))
	await _settle()
	var u2: int = uids["t1"]
	m.cards[u2]["st"]["paralyse"] = 1
	host.broadcast()
	await _wait(0.3)
	await _settle()
	m.add_log("[dev] Paralyse wears off")
	m.decrement_status(u2, "paralyse")
	host.broadcast()
	await _wait(FxStatus.EXPIRE_LENGTH * 0.4)
	tiles.append([_grab(u2), "Paralyse wears off"])
	_check("L8 expire look and sound", _planned("status_expire") and _planned("sfx:status_expire"))
	await _show_sheet("ticks_and_expire", tiles, 4)


## Hypnotise (L9): a unit taken across the board and sent home, frames through each glide.
func _control_strip() -> void:
	await _settle()
	var u: int = uids["t3"]
	var tiles := []
	for back in [false, true]:
		var from := m.fx_pos(u)
		var prev: int = m.cards[u]["ctl"]
		var to_p: int = o if back else a
		var to_slot: int = 3 if back else 5
		m.players[prev]["units"][m.cards[u]["slot"]] = -1
		m.cards[u]["ctl"] = to_p
		m.cards[u]["slot"] = to_slot
		m.players[to_p]["units"][to_slot] = u
		m.add_log("[dev] Hypnotise %s" % ("ends" if back else "takes the unit"))
		m.add_fx({"k": "control", "from": from, "to": m.fx_pos(u), "p": to_p, "id": int(m.cards[u]["id"]), "back": back})
		host.broadcast()
		var t0 := Time.get_ticks_msec()
		for at in [0.12, 0.34, 0.55, 0.95]:
			while Time.get_ticks_msec() - t0 < int(at * 1000.0):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var r := Rect2(Vector2(380, 120), Vector2(560, 700))
			tiles.append([_crop(img, r, 1.0), "%s %.2f s" % ["return" if back else "take", at]])
		_check("L9 control %s glides" % ("return" if back else "take"), _planned("control") and _planned("sfx:control_"))
		await _wait(0.6)
		await _settle()
	await _show_sheet("hypnotise_glide", tiles, 4)


func _grab(uid: int) -> ImageTexture:
	var img := get_viewport().get_texture().get_image()
	var r := _slot_rect(int(m.cards[uid]["ctl"]), "unit", int(m.cards[uid]["slot"]))
	return _crop(img, r.grow_individual(r.size.x * 0.45, r.size.y * 0.38, r.size.x * 0.45, r.size.y * 0.2), 1.6)


func _planned(prefix: String) -> bool:
	return gs.fx.last_plan.any(func(x): return String(x["tag"]).begins_with(prefix))


# ---------------------------------------------------------------- sheet helpers

func _crop(img: Image, r: Rect2, k: float) -> ImageTexture:
	var ri := Rect2i(r.position.floor(), r.size.ceil()).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(ri)
	c.resize(int(ri.size.x * k), int(ri.size.y * k), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(c)


## Shows `tiles` ([texture, caption]) in a grid of `cols` over the screen and shoots it.
func _show_sheet(name: String, tiles: Array, cols: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	get_tree().root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("17130f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.position = Vector2(12, 12)
	layer.add_child(grid)
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var rows := ceili(float(tiles.size()) / float(cols))
	var cell := Vector2((vp.x - 24.0 - 10.0 * (cols - 1)) / cols, (vp.y - 24.0 - 6.0 * (rows - 1)) / rows - 22.0)
	for t in tiles:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var tr := TextureRect.new()
		tr.texture = t[0]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = cell
		v.add_child(tr)
		if String(t[1]) != "":
			var l := UIStyle.label(String(t[1]), 16, UIStyle.GOLD_HI)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
		grid.add_child(v)
	await _wait(0.2)
	await _shot(name)
	layer.queue_free()
	await _frames(2)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("l_status_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("L STATUS DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()


## Every status token at several pixel sizes: one column per status, one row per size.
class BadgeSheet extends Control:
	var sizes: Array = []
	## True: every badge at 150 px in two rows (detail check), with a 3-stack count.
	var zoom := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("17130f"))
		if zoom:
			_draw_zoom()
			return
		# A strip of card-art-like warm light behind the right half, to judge contrast on bright art.
		draw_rect(Rect2(Vector2(0, size.y * 0.62), Vector2(size.x, size.y * 0.38)), Color("6f5a3e"))
		var keys := ["rune"] + CardDB.STATUS_ORDER
		var col_w := (size.x - 40.0) / float(keys.size())
		var font := UIStyle.font_bold()
		var y := 30.0
		for i in keys.size():
			var k := String(keys[i])
			var x := 20.0 + col_w * (i + 0.5)
			var nm := k.capitalize()
			var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(x - tw / 2.0, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.GOLD_HI)
		var kinds := {}
		for k in keys:
			kinds[k] = CardStatusIcons.KIND_RUNE if k == "rune" else (CardStatusIcons.KIND_BUFF if CardDB.is_buff(k) else CardStatusIcons.KIND_DEBUFF)
		var row_y := [80.0, 140.0, 225.0, 380.0]
		for j in sizes.size():
			var px: float = sizes[j]
			for i in keys.size():
				var k := String(keys[i])
				var x := 20.0 + col_w * (i + 0.5)
				CardStatusIcons.draw_token(self, Vector2(x, row_y[j]), px / 2.0, k, 3 if j % 2 == 1 else (2 if k == "rune" else 1), int(kinds[k]), true)
		# The same tokens over the warm strip at field and inspector size.
		for i in keys.size():
			var k := String(keys[i])
			var x := 20.0 + col_w * (i + 0.5)
			CardStatusIcons.draw_token(self, Vector2(x, size.y * 0.70), float(sizes[0]) / 2.0, k, 1, int(kinds[k]), true)
			CardStatusIcons.draw_token(self, Vector2(x, size.y * 0.84), float(sizes[2]) / 2.0, k, 12 if i % 3 == 0 else 1, int(kinds[k]), true)
		var lab := ["field %.0f px" % sizes[0], "hand %.0f px (x3)" % sizes[1], "inspect %.0f px" % sizes[2], "%.0f px (x3)" % sizes[3]]
		for j in sizes.size():
			draw_string(font, Vector2(4, row_y[j] - float(sizes[j]) / 2.0 - 6.0), lab[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))

	func _draw_zoom() -> void:
		var keys := ["rune"] + CardDB.STATUS_ORDER
		var font := UIStyle.font_bold()
		for i in keys.size():
			var k := String(keys[i])
			var kind := CardStatusIcons.KIND_RUNE if k == "rune" else (CardStatusIcons.KIND_BUFF if CardDB.is_buff(k) else CardStatusIcons.KIND_DEBUFF)
			var c := Vector2(110.0 + 196.0 * (i % 8), 150.0 + 330.0 * (i / 8))
			CardStatusIcons.draw_token(self, c, 75.0, k, 3, kind, true)
			var nm := k.capitalize()
			var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(font, Vector2(c.x - tw / 2.0, c.y + 112.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.GOLD_HI)
