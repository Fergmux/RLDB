extends SceneTree
## Dev screenshot gallery for CardWidget / TypeIcons (F02-03/11/12/14/15). Run WINDOWED:
##   godot --path rldb -s res://tests/visual/card_gallery.gd -- <output dir>
## Writes one PNG per page (kinds, field, icons, states, details) built from real CardDB cards.

var _out_dir := "user://card_gallery"
var _page: Control
var _uid := 100


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("user://") else _out_dir)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1500, 900)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _shoot("kinds", _page_kinds, 1.0)
	await _shoot("kinds_x2", _page_kinds, 2.0, Vector2(1500, 900) / 2.0)
	await _shoot("field", _page_field, 1.0)
	await _shoot("field_x2", _page_field, 2.0, Vector2(1500, 900) / 2.0)
	await _shoot("icons", _page_icons, 1.0)
	await _shoot("states", _page_states, 1.0)
	await _shoot("states_x2", _page_states, 2.0, Vector2(1500, 900) / 2.0)
	await _shoot("rotated_states", _page_rotated_states, 1.0)
	print("card_gallery: done -> ", _out_dir)
	quit(0)


func _shoot(name: String, builder: Callable, scale: float, area: Vector2 = Vector2(1500, 900)) -> void:
	if _page != null:
		_page.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("2a211a")
	bg.size = Vector2(1500, 900)
	root.add_child(bg)
	_page = Control.new()
	_page.scale = Vector2(scale, scale)
	_page.size = area
	bg.add_child(_page)
	builder.call(_page)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png("%s/%s.png" % [_out_dir, name])
	print("card_gallery: ", name, " ", err)
	bg.queue_free()
	_page = null
	await process_frame


# ---------------------------------------------------------------- data helpers

func _def(pred: Callable) -> Dictionary:
	for d in CardDB.all():
		if pred.call(d):
			return d
	return {}


func _text(d: Dictionary) -> String:
	var parts := []
	for k in ["on_summon", "on_field", "condition", "description"]:
		if String(d.get(k, "")) != "":
			parts.append(String(d[k]))
	return " ".join(parts)


## A view shaped like MatchView.card_view for a real card definition.
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
			v["protected"] = false
			v["attacked"] = false
	for k in opts:
		v[k] = opts[k]
	return v


func _unit(type := "Water", cat := "unit") -> Dictionary:
	return _def(func(d): return d["category"] == cat and d["type"] == type)


func _cat(cat: String) -> Dictionary:
	return _def(func(d): return d["category"] == cat)


# ---------------------------------------------------------------- layout helpers

func _caption(parent: Control, text: String, pos: Vector2) -> void:
	var l := UIStyle.label(text, 12, UIStyle.MUTED)
	l.position = pos
	parent.add_child(l)


func _card(parent: Control, v, kind: String, pos: Vector2, rot := false, label := "") -> CardWidget:
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind, label, rot)
	w.position = pos
	parent.add_child(w)
	return w


## A card inside a square/landscape slot background like the board does.
func _slot(parent: Control, v, kind: String, pos: Vector2, slot_size: Vector2, rot := false, bg_kind := "board") -> CardWidget:
	var bg := CardWidget.new()
	bg.auto_hover = false
	bg.setup({}, bg_kind)
	bg.custom_minimum_size = slot_size
	bg.size = slot_size
	bg.position = pos
	parent.add_child(bg)
	var cw := CardWidget.new()
	cw.auto_hover = false
	cw.setup(v, kind, "", rot)
	cw.position = pos + (slot_size - cw.size) / 2.0
	parent.add_child(cw)
	return cw


# ---------------------------------------------------------------- pages

func _page_kinds(p: Control) -> void:
	var u := _unit("Fire", "unit")
	var fus := _cat("fusion")
	var spell := _cat("spell")
	_caption(p, "hand 120x180", Vector2(10, 4))
	_card(p, _view(u, "hand"), "hand", Vector2(10, 24))
	_card(p, _view(fus, "hand"), "hand", Vector2(140, 24))
	_card(p, _view(spell, "hand"), "hand", Vector2(270, 24))
	_caption(p, "mini 90x135", Vector2(410, 4))
	_card(p, _view(u, "hand"), "mini", Vector2(410, 24))
	_card(p, _view(spell, "hand"), "mini", Vector2(510, 24))
	_caption(p, "big 224x336", Vector2(640, 4))
	_card(p, _view(u, "hand", {"statuses": {"pierce": 1, "burn": 2}}), "big", Vector2(640, 24))
	_card(p, _view(spell, "hand"), "big", Vector2(880, 24))
	_caption(p, "board / power / trap (85x128)", Vector2(10, 230))
	var bu := _view(_unit("Lightning", "unit"), "unit")
	_card(p, bu, "board", Vector2(10, 250))
	_card(p, _view(_unit("Dark", "basic_unit"), "unit", {"atk": 12, "statuses": {"burn": 1}}), "board", Vector2(105, 250))
	_card(p, _view(_cat("power"), "power"), "power", Vector2(200, 250))
	_card(p, _view(_cat("trap"), "backrow"), "trap", Vector2(295, 250))
	_card(p, _view(_cat("trap"), "backrow", {"face_up": false}), "trap", Vector2(390, 250))
	_caption(p, "back 60x90 + hidden board", Vector2(10, 395))
	_card(p, {"hidden": true, "zone": "hand"}, "back", Vector2(10, 415))
	_card(p, {"hidden": true, "zone": "backrow"}, "board", Vector2(90, 415))
	_card(p, {"hidden": true, "zone": "backrow"}, "trap", Vector2(190, 415), true)
	_caption(p, "trap rotated (128x85)", Vector2(335, 395))
	_card(p, _view(_cat("trap"), "backrow", {"face_up": false}), "trap", Vector2(335, 415), true)
	_card(p, _view(_cat("trap"), "backrow"), "trap", Vector2(480, 415), true)


func _page_field(p: Control) -> void:
	_caption(p, "unit slots 128x128 (ATK upright / DEF rotated / empty); trap zones 128x85; power 85x128", Vector2(10, 4))
	var types := CardDB.ELEMENTS
	for i in 3:
		var d := _unit(types[i], "unit")
		_slot(p, _view(d, "unit"), "board", Vector2(10 + i * 138, 28), Vector2(128, 128))
		_slot(p, _view(d, "unit", {"stance": "def", "protected": i == 1, "attacked": i == 2}), "board", Vector2(10 + i * 138, 166), Vector2(128, 128), true)
	var bug := _unit("Earth", "basic_unit")
	_slot(p, _view(bug, "unit", {"atk": 15, "def": 4, "attacked": true, "protected": true}), "board", Vector2(10, 304), Vector2(128, 128))
	_slot(p, _view(bug, "unit", {"atk": 100, "def": 120, "printed_atk": 8, "printed_def": 8}), "board", Vector2(148, 304), Vector2(128, 128))
	_slot(p, _view(bug, "unit", {"atk": 1, "def": 2, "printed_atk": 8, "printed_def": 8, "stance": "def"}), "board", Vector2(286, 304), Vector2(128, 128), true)
	var e := CardWidget.new()
	e.auto_hover = false
	e.setup({}, "board", "Unit")
	e.show_label = true
	e.custom_minimum_size = Vector2(128, 128)
	e.size = Vector2(128, 128)
	e.position = Vector2(10, 442)
	p.add_child(e)
	var et := CardWidget.new()
	et.setup({}, "trap", "Trap")
	et.size = Vector2(128, 85)
	et.position = Vector2(440, 28)
	p.add_child(et)
	_slot(p, _view(_cat("trap"), "backrow", {"face_up": false}), "trap", Vector2(440, 123), Vector2(128, 85), true, "trap")
	_slot(p, _view(_cat("trap"), "backrow"), "trap", Vector2(440, 218), Vector2(128, 85), true, "trap")
	_slot(p, {"hidden": true, "zone": "backrow"}, "trap", Vector2(440, 313), Vector2(128, 85), true, "trap")
	var ep := CardWidget.new()
	ep.setup({}, "power", "Power")
	ep.size = Vector2(85, 128)
	ep.position = Vector2(590, 28)
	p.add_child(ep)
	_slot(p, _view(_cat("power"), "power"), "power", Vector2(590, 166), Vector2(85, 128), false, "power")
	# Safety net: a card in a non-2:3 rect is letterboxed, never stretched.
	_caption(p, "letterbox safety net (card in 128x128 / 85x85 rects)", Vector2(440, 420))
	var lb := _card(p, _view(_unit("Water", "unit"), "unit"), "board", Vector2(440, 442))
	lb.size = Vector2(128, 128)
	var lb2 := _card(p, _view(_unit("Water", "unit"), "unit", {"stance": "def"}), "board", Vector2(590, 442), true)
	lb2.size = Vector2(128, 128)


func _page_icons(p: Control) -> void:
	_caption(p, "TypeIcons.draw_icon, radius 44", Vector2(10, 4))
	var all := CardDB.ELEMENTS.duplicate()
	all.append("")
	for i in all.size():
		var host := Control.new()
		host.position = Vector2(10 + i * 110, 28)
		host.size = Vector2(100, 100)
		var t: String = all[i]
		host.draw.connect(func():
			host.draw_rect(Rect2(Vector2.ZERO, host.size), Color("1d1a18"))
			TypeIcons.draw_icon(host, t, host.size / 2.0, 44.0))
		p.add_child(host)
		_caption(p, t if t != "" else "(typeless)", Vector2(10 + i * 110 + 20, 132))
	_caption(p, "radius 14 / 9 / 6 on dark and on art-like colours", Vector2(10, 170))
	for i in all.size():
		var t2: String = all[i]
		var host2 := Control.new()
		host2.position = Vector2(10 + i * 110, 192)
		host2.size = Vector2(100, 40)
		host2.draw.connect(func():
			host2.draw_rect(Rect2(Vector2.ZERO, host2.size), Color("3a3028"))
			TypeIcons.draw_icon(host2, t2, Vector2(20, 20), 14.0)
			TypeIcons.draw_icon(host2, t2, Vector2(52, 20), 9.0)
			TypeIcons.draw_icon(host2, t2, Vector2(76, 20), 6.0))
		p.add_child(host2)
		var b := TypeIcons.TypeBadge.new(t2)
		b.position = Vector2(10 + i * 110 + 78, 240)
		p.add_child(b)
	_caption(p, "units of each type (hand size) - pip on art + Race · Type line", Vector2(10, 280))
	for i in all.size():
		var d: Dictionary = _unit(all[i], "unit")
		if d.is_empty():
			d = _unit(all[i], "basic_unit")
		if d.is_empty():
			continue
		_card(p, _view(d, "hand"), "hand", Vector2(10 + i * 128, 304))


func _page_states(p: Control) -> void:
	var d := _unit("Water", "unit")
	var names := ["normal", "hover", "selected", "target", "ready", "ready+sel", "ready+hover", "order 2", "order 12"]
	for i in names.size():
		_caption(p, names[i], Vector2(14 + i * 100, 4))
		var w := _card(p, _view(d, "unit"), "board", Vector2(14 + i * 100, 26))
		match i:
			1: w.hovered = true
			2: w.set_marks(false, true)
			3: w.set_marks(true, false)
			4: w.set_ready(true)
			5:
				w.set_ready(true)
				w.set_marks(false, true)
			6:
				w.set_ready(true)
				w.hovered = true
			7: w.order_no = 2
			8: w.order_no = 12
	# Previews
	_caption(p, "preview: atk +6 / atk -6 / def +3 / atk 120 / def -2 / no bonus", Vector2(14, 175))
	var cfgs := [["atk", 14, 6], ["atk", 2, -6], ["def", 11, 3], ["atk", 120, 12], ["def", 6, -2], ["atk", 8, 0]]
	for i in cfgs.size():
		var w := _card(p, _view(d, "unit"), "board", Vector2(14 + i * 100, 200))
		w.set_preview(cfgs[i][0], cfgs[i][1], cfgs[i][2])
	# 3 digit + buffed/debuffed
	_caption(p, "3-digit/?: board, hand, mini, big", Vector2(14, 350))
	var big_unit := _view(d, "unit", {"atk": 100, "def": 120, "printed_atk": 8, "printed_def": 8})
	_card(p, big_unit, "board", Vector2(14, 374))
	_card(p, _view(d, "hand", {"atk": 100, "def": 120}), "hand", Vector2(114, 374))
	_card(p, _view(d, "hand", {"atk": 100, "def": 120}), "mini", Vector2(244, 374))
	_card(p, _view(d, "hand", {"atk": 100, "def": 120}), "big", Vector2(344, 374))
	_card(p, _view(d, "unit", {"atk": null, "def": null}), "board", Vector2(584, 374))
	_card(p, _view(d, "unit", {"atk": 3, "def": 14, "statuses": {"burn": 1, "poison": 2, "paralyse": 1, "blind": 1, "nimble": 1}, "runes": 2}), "board", Vector2(684, 374))
	_card(p, _view(d, "unit", {"statuses": {"pierce": 1, "retain": 1}, "runes": 1}), "board", Vector2(784, 374))
	var pv_hand := _card(p, _view(d, "hand"), "hand", Vector2(884, 374))
	pv_hand.set_preview("atk", 14, 6)
	var pv_big := _card(p, _view(d, "hand"), "big", Vector2(1020, 374))
	pv_big.set_preview("def", 3, -5)
	pv_big.set_ready(true)
	pv_big.order_no = 3
	var mn := _card(p, _view(d, "hand"), "mini", Vector2(1270, 374))
	mn.set_marks(false, true)
	mn.order_no = 2
	var mn2 := _card(p, _view(d, "hand"), "mini", Vector2(1370, 374))
	mn2.order_no = 1


func _page_rotated_states(p: Control) -> void:
	var d := _unit("Fire", "unit")
	var names := ["def", "hover", "selected", "target", "ready", "ready+sel", "preview def -3", "preview atk", "order 1"]
	for i in names.size():
		var x := 14 + (i % 4) * 190
		var y := 26 + (i / 4) * 130
		_caption(p, names[i], Vector2(x, y - 20))
		var w := _card(p, _view(d, "unit", {"stance": "def"}), "board", Vector2(x, y), true)
		match i:
			1: w.hovered = true
			2: w.set_marks(false, true)
			3: w.set_marks(true, false)
			4: w.set_ready(true)
			5:
				w.set_ready(true)
				w.set_marks(false, true)
			6: w.set_preview("def", 5, -3)
			7: w.set_preview("atk", 120, 9)
			8: w.order_no = 1
	var bk := _card(p, _view(_cat("trap"), "backrow", {"face_up": false}), "trap", Vector2(14, 450), true)
	bk.set_ready(true)
	_card(p, {"hidden": true, "zone": "backrow"}, "trap", Vector2(204, 450), true).set_marks(true, false)
