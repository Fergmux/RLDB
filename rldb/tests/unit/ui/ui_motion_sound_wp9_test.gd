extends GdUnitTestSuite
## H1 WP-9 motion and sound pass (design review #23, #32, #52, #62, #63, #76, #85, #87, #90, #95,
## #104): the card hover cue and its shared limiter, the new cues, the reward reveal, the tile
## lifts, the stats count-up, the tutorial step chime, the inspector fly and the table dust.
## Nothing here writes a settings file, a deck or a statistics record.

const NEW_CUES := ["card_hover", "reward_reveal", "reward_pick", "step_done"]
const VIEW := {"uid": 1, "id": 1, "name": "Test Spell", "category": "spell", "cost_kind": "ap", "cost": 1,
	"printed_cost": 1, "zone": "hand", "face_up": true, "statuses": {}, "runes": 0, "text": "Do a thing."}

var _rm: bool


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	UIStyle.reduce_motion = false
	Sfx._reset_hover()
	Sfx._reset_ui()


func after_test() -> void:
	UIStyle.reduce_motion = _rm
	Sfx._reset_hover()
	Sfx._reset_ui()


# ---------------------------------------------------------------- sounds

func test_new_cues_are_registered_and_have_files() -> void:
	for n in NEW_CUES:
		assert_bool(Sfx.NAMES.has(n)).override_failure_message("%s not registered" % n).is_true()
		assert_bool(ResourceLoader.exists(Sfx.DIR + n + ".wav")).override_failure_message("%s.wav missing" % n).is_true()


func test_card_hover_shares_the_hover_limiter() -> void:
	# Arrange: a button hover just played.
	assert_bool(Sfx.hover_at(10000)).is_true()
	# Act: a card hover inside the window, then one after it.
	var early := Sfx.hover_at(10000 + Sfx.HOVER_MIN_MS - 1, Sfx.CARD_HOVER_SFX)
	var late := Sfx.hover_at(10000 + Sfx.HOVER_MIN_MS, Sfx.CARD_HOVER_SFX)
	# Assert: one limiter for every hover cue, and the card variant is recorded by name.
	assert_bool(early).is_false()
	assert_bool(late).is_true()
	assert_array(Sfx.debug_hover).is_equal(["ui_hover", "card_hover"])


func test_hover_cues_never_take_the_ui_click_slot() -> void:
	# A hover is not an action sound: it neither records nor blocks a click of the same frame.
	Sfx.hover_card()
	Sfx.play("click_primary")
	assert_array(Sfx.debug_ui).is_equal(["click_primary"])


func test_reward_reveal_outranks_the_modal_open_cue() -> void:
	# The rewards modal opens (panel_open) and reveals (reward_reveal) in one frame: one sound.
	var f := Engine.get_process_frames()
	Sfx._ui_frame = f
	Sfx._ui_prio = int(Sfx.UI_PRIORITY["panel_open"])
	assert_int(Sfx.ui_decide("reward_reveal", f)).is_equal(Sfx.REPLACE)
	Sfx._ui_prio = int(Sfx.UI_PRIORITY["reward_reveal"])
	assert_int(Sfx.ui_decide("panel_open", f)).is_equal(Sfx.DROP)


func test_reward_pick_is_a_coalesced_ui_sound() -> void:
	var b: Button = auto_free(UIStyle.primary_button("Remove card"))
	b.set_meta(Sfx.BUTTON_META, "reward_pick")
	assert_str(Sfx.button_sound(b)).is_equal("reward_pick")
	assert_bool(Sfx.UI_PRIORITY.has("reward_pick")).is_true()


func test_card_widget_hover_sound_is_opt_in() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	assert_bool(w.hover_sound).is_false()


# ---------------------------------------------------------------- tiles (#52, #62)

func test_deck_tile_rests_flat_and_lifts_in_whole_pixels() -> void:
	var t: DeckTile = auto_free(DeckTile.new({"title": "Embers", "main": [], "extra": []}))
	assert_float(t.lift_px()).is_equal(0.0)
	t._lift = 1.0
	assert_float(t.lift_px()).is_equal(DeckTile.LIFT_PX)
	t._lift = 0.5
	assert_float(fmod(t.lift_px(), 1.0)).is_equal(0.0)


func test_deck_tile_lift_moves_frame_and_content_together() -> void:
	var t: DeckTile = auto_free(DeckTile.new({"title": "Embers", "main": [], "extra": []}))
	t._lift = 1.0
	t._apply_rim()
	var sb := t.get_theme_stylebox("panel") as StyleBoxFlat
	assert_float(sb.expand_margin_top).is_equal(DeckTile.LIFT_PX)
	assert_float(sb.expand_margin_bottom).is_equal(-DeckTile.LIFT_PX)
	# The content keeps its total padding (no reflow), shifted up by the lift.
	assert_float(sb.content_margin_top + sb.content_margin_bottom).is_equal(DeckTile.PAD_V * 2.0)
	assert_float(sb.content_margin_top).is_equal(DeckTile.PAD_V - DeckTile.LIFT_PX)


func test_choice_tile_lift_is_zero_at_rest() -> void:
	var t: ChoiceTile = auto_free(ChoiceTile.new("Add a card", "Pick a type", UIStyle.GOOD, "add"))
	assert_float(t.lift_px()).is_equal(0.0)
	t._lift = 1.0
	assert_float(t.lift_px()).is_equal(ChoiceTile.LIFT_PX)


func test_choice_tile_caption_is_muted() -> void:
	var t: ChoiceTile = auto_free(ChoiceTile.new("Add a card", "Pick a type", UIStyle.GOOD, "add"))
	var labels := t.find_children("*", "Label", true, false)
	var cap: Label = labels[labels.size() - 1]
	assert_bool(cap.get_theme_color("font_color").is_equal_approx(UIStyle.MUTED)).is_true()


# ---------------------------------------------------------------- rewards reveal (#63)

func test_pick_pips_pop_in_and_settle() -> void:
	var p: PickPips = auto_free(PickPips.new())
	p.left = 3
	p.total = 3
	add_child(p)
	p.pop_in(0.0, 0.0)
	assert_bool(p.popping()).is_true()
	await await_millis(int((UIStyle.motion("panel_in") + 0.15) * 1000.0))
	assert_bool(p.popping()).is_false()


func test_pick_pips_are_static_under_reduce_motion() -> void:
	UIStyle.reduce_motion = true
	var p: PickPips = auto_free(PickPips.new())
	p.left = 2
	p.total = 2
	add_child(p)
	p.pop_in()
	assert_bool(p.popping()).is_false()


# ---------------------------------------------------------------- statistics (#95)

func test_count_text_scales_every_number() -> void:
	assert_str(StatsDialog.count_text("58%", 0.5)).is_equal("29%")
	assert_str(StatsDialog.count_text("6 - 4", 0.0)).is_equal("0 - 0")
	assert_str(StatsDialog.count_text("2 of 3", 1.0)).is_equal("2 of 3")
	assert_str(StatsDialog.count_text("14 turns", 0.5)).is_equal("7 turns")


func test_names_and_times_do_not_count() -> void:
	assert_bool(StatsDialog.counts_up("Basic Mage (Water)")).is_false()
	assert_bool(StatsDialog.counts_up("12:40")).is_false()
	assert_str(StatsDialog.count_text("Ember Deck 2", 0.0)).is_equal("Ember Deck 2")


func test_stats_rows_count_up_from_zero_on_open() -> void:
	var facts := [{"label": "Duels played", "value": "12", "detail": ""}, {"label": "Win rate", "value": "50%", "detail": ""}]
	var d: StatsDialog = auto_free(StatsDialog.open(self, facts))
	var vals := d.find_children("Value", "Label", true, false)
	assert_str((vals[0] as Label).text).is_equal("0")
	await await_millis(int((UIStyle.motion("count") + UIStyle.motion("stagger") * 2.0 + 0.2) * 1000.0))
	assert_str((vals[0] as Label).text).is_equal("12")
	assert_str((vals[1] as Label).text).is_equal("50%")
	# The headline fact wears its gem.
	assert_int(d.find_children("Gem", "", true, false).size()).is_equal(1)


func test_stats_show_final_values_under_reduce_motion() -> void:
	UIStyle.reduce_motion = true
	var facts := [{"label": "Duels played", "value": "12", "detail": ""}]
	var d: StatsDialog = auto_free(StatsDialog.open(self, facts))
	var vals := d.find_children("Value", "Label", true, false)
	assert_str((vals[0] as Label).text).is_equal("12")


# ---------------------------------------------------------------- tutorial step chime

func test_step_done_only_after_a_do_step_moves_on() -> void:
	assert_bool(TutorialOverlay.step_done_due(0, 3, true, 0, 4, false)).is_true()
	assert_bool(TutorialOverlay.step_done_due(0, 3, false, 0, 4, false)).is_false()   # a read step: the Next click is its sound
	assert_bool(TutorialOverlay.step_done_due(0, 3, true, 0, 4, true)).is_false()    # the lesson celebration plays instead
	assert_bool(TutorialOverlay.step_done_due(0, 3, true, 1, 0, false)).is_false()   # a new lesson
	assert_bool(TutorialOverlay.step_done_due(0, 3, true, 0, 3, false)).is_false()   # a refresh of the same step


# ---------------------------------------------------------------- inspector (#87)

func test_inspector_counts_closed_at_once_and_frees_after_its_motion() -> void:
	var host: Control = auto_free(Control.new())
	host.size = Vector2(1600, 900)
	add_child(host)
	var ins := CardInspector.open(host, VIEW, Callable(), Rect2(100, 700, 80, 120))
	assert_object(ins).is_not_null()
	await await_idle_frame()
	ins.close()
	assert_int(CardInspector.open_count()).is_equal(0)
	assert_bool(is_instance_valid(ins) and not ins.is_queued_for_deletion()).is_true()
	await await_millis(int((UIStyle.motion("card_move") + 0.2) * 1000.0))
	assert_bool(is_instance_valid(ins)).is_false()


# ---------------------------------------------------------------- table dust (#23)

func test_table_dust_is_sparse_round_and_deterministic() -> void:
	var a: AmbientMotes = auto_free(AmbientMotes.dust())
	var b: AmbientMotes = auto_free(AmbientMotes.dust())
	assert_int(a.count()).is_equal(10)
	for m in a._motes:
		assert_bool(m["petal"]).is_false()
		assert_float(float(m["size"])).is_less_equal(AmbientMotes.DUST["size"].y)
	assert_that(a._motes).is_equal(b._motes)


func test_menu_motes_keep_their_petals() -> void:
	var m: AmbientMotes = auto_free(AmbientMotes.new(4, [AmbientMotes.PETAL, AmbientMotes.GOLD]))
	assert_bool(m._motes[0]["petal"]).is_true()
	assert_bool(m._motes[1]["petal"]).is_false()
