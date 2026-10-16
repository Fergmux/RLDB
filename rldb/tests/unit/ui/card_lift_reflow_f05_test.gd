extends GdUnitTestSuite
## F05-03: a lifted card keeps its resting text layout (line breaks, font sizes, relative positions)
## at every step of the lift, and is drawn scaled with its text rasterised at the lifted size.

const _LONG := "Apply 1 Eternal and 3 Cleanse to this Unit. At the start of your turn: Apply 1 Eternal to this Unit. Once per turn: you can Exhaust this Unit, your opponent loses 10 HP x the amount of Eternal on this Unit. On Destroy: increase this card's cost by 1 AP."
const _UNIT := {"uid": 7, "id": 7, "name": "Neva the Divine Mother", "category": "unit", "cost_kind": "ap", "cost": 4,
	"printed_cost": 4, "zone": "hand", "face_up": true, "statuses": {}, "runes": 0, "text": _LONG,
	"race": "God", "type": "", "atk": 16, "def": 30, "printed_atk": 16, "printed_def": 30}
const _SPELL := {"uid": 8, "id": 8, "name": "Shimmer Serum", "category": "spell", "cost_kind": "ap", "cost": 0,
	"printed_cost": 0, "zone": "hand", "face_up": true, "statuses": {}, "runes": 0, "text": _LONG}
## Steps of a hover lift, including the TRANS_BACK overshoot and the 1.05 draft / reward lift.
const _STEPS := [1.0, 1.013, 1.05, 1.1, 1.137, 1.2, 1.25, 1.28]


func _widget(v: Dictionary, kind: String) -> CardWidget:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var w := CardWidget.new()
	w.auto_hover = false
	w.setup(v, kind)
	host.add_child(w)
	w.position = Vector2(40, 60)
	w.set_text_tracing(true)
	return w


func _trace_at(w: CardWidget, k: float) -> Array:
	w.lift_k = k
	w.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	return w.text_trace()


func _assert_layout_kept(v: Dictionary, kind: String) -> void:
	var w := _widget(v, kind)
	var rest: Array = await _trace_at(w, 1.0)
	assert_int(rest.size()).is_greater(3)
	for k in _STEPS:
		var t: Array = await _trace_at(w, k)
		assert_str(var_to_str(t)).override_failure_message("text layout at lift %.3f differs from rest" % k).is_equal(var_to_str(rest))


func test_hand_unit_text_layout_is_identical_at_every_lift_step() -> void:
	await _assert_layout_kept(_UNIT, "hand")


func test_hand_spell_text_layout_is_identical_at_every_lift_step() -> void:
	await _assert_layout_kept(_SPELL, "hand")


func test_board_unit_text_layout_is_identical_at_every_lift_step() -> void:
	var v := _UNIT.duplicate()
	v["zone"] = "unit"
	v["stance"] = "atk"
	await _assert_layout_kept(v, "board")


func test_rules_paragraph_keeps_its_line_breaks_when_lifted() -> void:
	var w := _widget(_SPELL, "hand")
	var rest: Array = await _trace_at(w, 1.0)
	var lifted: Array = await _trace_at(w, 1.25)
	var paras_rest := rest.filter(func(e): return e[0] == "para")
	var paras_lift := lifted.filter(func(e): return e[0] == "para")
	assert_int(paras_rest.size()).is_equal(1)
	assert_int((paras_rest[0][3] as Array).size()).is_greater(3)   # several wrapped lines
	assert_array(paras_lift[0][3]).is_equal(paras_rest[0][3])


## The mechanism: never `scale` (blurred, F04-05); the face is drawn under a draw scale of lift_k and
## the text is rasterised for it (oversampling = viewport oversampling x lift).
func test_lift_draws_scaled_with_text_rasterised_at_lifted_size() -> void:
	var w := _widget(_UNIT, "hand")
	await _trace_at(w, 1.25)
	assert_vector(w.scale).is_equal(Vector2.ONE)
	var ds := w.last_draw_scale()
	assert_float(ds[0]).is_equal_approx(1.25, 0.0001)
	assert_float(ds[1]).is_equal_approx(w.get_viewport().get_oversampling() * 1.25, 0.0001)
	await _trace_at(w, 1.0)
	ds = w.last_draw_scale()
	assert_float(ds[0]).is_equal(1.0)
	assert_float(ds[1]).is_equal(0.0)   # at rest: the viewport's own oversampling, exactly as before


## An FX `scale` pulse on the card also rasterises its text for the on-screen size.
func test_scaled_card_text_follows_its_on_screen_scale() -> void:
	var w := _widget(_UNIT, "hand")
	w.scale = Vector2(1.5, 1.5)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(w.last_draw_scale()[1]).is_equal_approx(w.get_viewport().get_oversampling() * 1.5, 0.0001)


## The lift size is not rounded, so it animates without whole-pixel steps.
func test_lift_size_is_smooth_not_pixel_stepped() -> void:
	var w := _widget(_UNIT, "hand")
	w.lift_k = 1.013
	assert_float(w.size.x).is_equal_approx(120.0 * 1.013, 0.0001)
	assert_float(w.position.x + w.size.x / 2.0).is_equal_approx(100.0, 0.0001)
