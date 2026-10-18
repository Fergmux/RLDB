extends GdUnitTestSuite
## 2026-10-18 card redesign: card art found by id, statuses as icons over the art with an instant
## name tip, the square art window on every card kind, and the material surfaces (UiSurface).

const _UNIT := {"uid": 13, "id": 13, "name": "Chaos Witch", "category": "unit", "cost_kind": "ap", "cost": 3,
	"printed_cost": 3, "zone": "unit", "slot": 0, "face_up": true, "statuses": {"poison": 2, "eternal": 1}, "runes": 3,
	"text": "x", "race": "Mage", "type": "Dark", "atk": 24, "def": 28, "printed_atk": 24, "printed_def": 28}


func _widget(v: Dictionary, kind: String, rotated: bool = false) -> CardWidget:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind, "", rotated)
	host.add_child(w)
	w.position = Vector2(40, 60)
	return w


func _drawn(w: CardWidget) -> void:
	w.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame


# ---------------------------------------------------------------- art

func test_art_is_found_by_card_id() -> void:
	assert_str(CardArt.path_for(13)).is_equal("res://assets/art/cards/13.webp")
	assert_bool(CardArt.has_art(13)).is_true()
	assert_object(CardArt.texture_for({"id": 13})).is_not_null()


func test_every_card_in_the_database_has_art() -> void:
	CardDB.ensure_loaded()
	var missing := []
	for d in CardDB.all():
		if not CardArt.has_art(int(d["id"])):
			missing.append(int(d["id"]))
	assert_array(missing).override_failure_message("cards without art (run tools/godot/import_card_art.gd): %s" % str(missing)).is_empty()


func test_every_art_file_belongs_to_a_card() -> void:
	CardDB.ensure_loaded()
	var orphans := []
	for f in DirAccess.get_files_at(CardArt.ART_DIR):
		if f.ends_with(".webp") and CardDB.get_def(int(f.get_basename())).is_empty():
			orphans.append(f)
	assert_array(orphans).is_empty()


func test_a_card_without_art_keeps_the_placeholder() -> void:
	assert_object(CardArt.texture_for({"id": 999999})).is_null()
	assert_object(CardArt.texture_for({"name": "no id"})).is_null()


# ---------------------------------------------------------------- status icons

func test_entries_put_runes_first_then_the_status_order_with_names() -> void:
	var e := CardStatusIcons.entries(_UNIT)
	assert_array(e.map(func(x): return x["key"])).is_equal(["rune", "eternal", "poison"])
	assert_array(e.map(func(x): return x["label"])).is_equal(["Rune ×3", "Eternal ×1", "Poison ×2"])
	assert_array(e.map(func(x): return x["k"])).is_equal([CardStatusIcons.KIND_RUNE, CardStatusIcons.KIND_BUFF, CardStatusIcons.KIND_DEBUFF])


func test_a_backrow_card_shows_no_reveal_icon() -> void:
	var v := {"zone": "backrow", "statuses": {"reveal": 1, "burn": 1}, "runes": 0}
	assert_array(CardStatusIcons.entries(v).map(func(x): return x["key"])).is_equal(["burn"])


func test_every_status_has_an_icon() -> void:
	for s in CardDB.STATUS_ORDER + ["rune"]:
		assert_object(CardStatusIcons.texture(s)).override_failure_message("no icon for %s" % s).is_not_null()


func test_field_card_draws_its_icons_over_the_art() -> void:
	var w := _widget(_UNIT, "board")
	await _drawn(w)
	var hits := w.status_hits()
	assert_int(hits.size()).is_equal(3)
	var k := w.card_rect().size.x / 85.0
	var art := Rect2(w.card_rect().position + Vector2(3, 3) * k, Vector2(79, 79) * k)
	for h in hits:
		assert_bool(art.encloses((h["rect"] as Rect2).grow(-1.0))).override_failure_message("%s off the art" % h["label"]).is_true()


func test_tall_and_rotated_cards_draw_icons_too() -> void:
	for kind in ["hand", "mini", "big"]:
		var w := _widget(_UNIT, kind)
		await _drawn(w)
		assert_int(w.status_hits().size()).override_failure_message(kind).is_equal(3)
	var d := _widget(_UNIT, "board", true)
	await _drawn(d)
	assert_int(d.status_hits().size()).is_equal(3)
	for h in d.status_hits():
		assert_bool(d.card_rect().encloses(h["rect"])).is_true()


func test_too_many_statuses_collapse_into_a_plus_token_listing_the_rest() -> void:
	var v := _UNIT.duplicate(true)
	for s in CardDB.STATUS_ORDER:
		v["statuses"][s] = 1
	v["zone"] = "unit"
	var w := _widget(v, "board")
	await _drawn(w)
	var hits := w.status_hits()
	var total := CardStatusIcons.entries(v).size()
	var last: Dictionary = hits[hits.size() - 1]
	assert_int(hits.size()).is_less(total)
	assert_int(String(last["label"]).split("\n").size()).is_equal(total - hits.size() + 1)


func test_hovering_an_icon_names_it_at_once_and_holds_back_the_card_tooltip() -> void:
	var v := _UNIT.duplicate(true)
	v["zone"] = "hand"
	var w := _widget(v, "hand")
	await _drawn(w)
	var h: Dictionary = w.status_hits()[2]
	var at := (h["rect"] as Rect2).get_center()
	assert_dict(w.status_hit_at(at)).is_equal(h)
	assert_str(w._get_tooltip(at)).is_equal("")
	assert_str(w._get_tooltip(Vector2(2, 2))).is_equal(w.tooltip_text)
	var mv := InputEventMouseMotion.new()
	mv.position = at
	w._gui_input(mv)
	assert_str(StatusTip.shown_text()).is_equal("Poison ×2")
	mv.position = Vector2(2, 2)
	w._gui_input(mv)
	assert_str(StatusTip.shown_text()).is_equal("")


func test_the_tip_belongs_to_the_card_that_shows_it() -> void:
	var a := _widget(_UNIT, "board")
	var b := _widget(_UNIT, "board")
	StatusTip.show_for(a, "Burn ×1", Rect2(10, 10, 10, 10))
	StatusTip.hide_for(b)
	assert_str(StatusTip.shown_text()).is_equal("Burn ×1")
	StatusTip.hide_for(a)
	assert_str(StatusTip.shown_text()).is_equal("")


# ---------------------------------------------------------------- layout

func test_art_windows_are_square_on_every_kind() -> void:
	for g in [CardLayouts.FIELD, CardLayouts.TALL]:
		var a: Array = g["art"]
		assert_float(float(a[2])).is_equal(float(a[3]))


func test_tall_card_badges_sit_on_the_art_above_the_banner() -> void:
	var g := CardLayouts.TALL
	var art: Array = g["art"]
	var banner: Array = g["banner"]
	for key in ["atk", "def"]:
		var r: Array = g[key]
		assert_bool(float(r[1]) >= float(art[1]) and float(r[1]) + float(r[3]) <= float(banner[1]) + float(banner[3]) * 0.5).override_failure_message(key).is_true()
	assert_float(float(g["text"][1])).is_greater_equal(float(banner[1]) + float(banner[3]))


# ---------------------------------------------------------------- surfaces

func test_material_textures_exist() -> void:
	for n in [UiSurface.LEATHER, UiSurface.PEBBLE, UiSurface.WOOD, UiSurface.METAL]:
		assert_object(UiSurface.texture(n)).override_failure_message(n).is_not_null()


func test_tint_keeps_the_surface_colour_on_average() -> void:
	var c := Color(0.2, 0.1, 0.05)
	var t := UiSurface.tint(c, 0.4)
	assert_float(t.r * 0.5).is_equal_approx(c.r, 0.0001)
	assert_float(t.a).is_equal_approx(0.4, 0.0001)


func test_round_rect_points_stay_inside_the_rect() -> void:
	var r := Rect2(10, 20, 100, 40)
	for p in UiSurface.round_rect_points(r, 12.0):
		assert_bool(r.grow(0.01).has_point(p)).is_true()
	assert_int(UiSurface.round_rect_points(r, 0.0).size()).is_equal(4)


func test_surface_box_keeps_the_flat_box_margins_and_can_be_restyled() -> void:
	var f := UIStyle.flat(Color.BLACK, Color.WHITE, 1, 6)
	f.content_margin_left = 17
	var b := UiSurface.box(f, UiSurface.METAL, 0.5)
	assert_float(b.get_margin(SIDE_LEFT)).is_equal(17.0)
	assert_object(UiSurface.flat_of(b)).is_same(f)
	var r := UiSurface.restyled(b, func(d: StyleBoxFlat): d.border_color = Color.RED)
	assert_bool(r is UiSurface.SurfaceBox).is_true()
	assert_that(UiSurface.flat_of(r).border_color).is_equal(Color.RED)
	assert_that(f.border_color).is_equal(Color.WHITE)
