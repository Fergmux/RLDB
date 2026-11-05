extends GdUnitTestSuite
## L31 (owner, 5 Nov): "add some other card back options to fill in the customisation panel
## section". Six new backs join the Violet Sigil (still the default) in Options > Customisation >
## Card back. The choice is saved in the user settings (the TEST file in automated runs), an unknown
## id falls back to the default, and CardBack draws the chosen back on every face-down card, pile
## and deck on this screen. It is a local display choice: nothing reaches the network.

## A file of this suite's own (never the player's settings, never the shared TEST file).
const FILE := "user://test_ui_card_back_suite.cfg"
## The backs L31 adds, in picker order after the default.
const NEW_BACKS := ["wyrm", "grove", "tide", "runes", "sun", "stars"]
## Back sizes drawn by the smoke test: opponent's mini hand card, field card, pile, picker showcase.
const SIZES := [Vector2(40, 60), Vector2(60, 90), Vector2(85, 128), Vector2(188, 282)]


## Draws one back with CardBack.draw_art and records that the draw ran to its end.
class BackProbe extends Control:
	var back_id := ""
	var finished := false

	func _draw() -> void:
		finished = false
		CardBack.draw_art(self, Rect2(Vector2.ZERO, size), size.x / 90.0, back_id)
		finished = true


func before_test() -> void:
	_wipe()
	Customisation.path_override = FILE
	Customisation.reset_cache()


func after_test() -> void:
	_wipe()
	Customisation.path_override = ""
	Customisation.reset_cache()
	UIStyle.reduce_motion = false


func _wipe() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))


# ---------------------------------------------------------------- the store

func test_new_profile_uses_the_violet_sigil() -> void:
	# Arrange: no settings file. Act / Assert
	assert_str(Customisation.DEFAULT_CARD_BACK).is_equal("violet")
	assert_str(Customisation.card_back_id()).is_equal("violet")
	assert_bool(CardBack.is_painted()).is_false()


func test_six_new_backs_follow_the_default_with_names_and_blurbs() -> void:
	# Arrange / Act
	var ids := []
	for b in Customisation.CARD_BACKS:
		ids.append(String(b["id"]))
		# Assert: a display name, a short tile name, a blurb and a look of its own.
		assert_str(String(b["name"])).is_not_empty()
		assert_str(String(b["short"])).is_not_empty()
		assert_str(String(b["blurb"])).is_not_empty()
		assert_bool(CardBack.STYLES.has(String(b["id"]))).is_true()
	assert_array(ids).is_equal(["violet"] + NEW_BACKS)


func test_painted_backs_have_their_art_on_disk() -> void:
	for id in NEW_BACKS:
		# Arrange / Act
		var tex := CardBack.texture(id)
		# Assert: a portrait painting of about 512 x 768.
		assert_object(tex).is_not_null()
		assert_bool(CardBack.is_painted(id)).is_true()
		assert_float(tex.get_size().x / tex.get_size().y).is_equal_approx(2.0 / 3.0, 0.01)
		assert_float(tex.get_size().y).is_greater_equal(512.0)


func test_picked_back_is_saved_and_read_back() -> void:
	# Arrange
	var ok := Customisation.set_card_back("tide")
	# Act: a fresh read from the file.
	Customisation.reset_cache()
	# Assert
	assert_bool(ok).is_true()
	assert_str(Customisation.card_back_id()).is_equal("tide")
	assert_str(String(Customisation.card_back()["name"])).is_equal("Abyssal Tide")


func test_unknown_back_is_refused() -> void:
	# Arrange
	Customisation.set_card_back("grove")
	# Act
	var ok := Customisation.set_card_back("hologram")
	# Assert: refused, and the choice is unchanged.
	assert_bool(ok).is_false()
	assert_str(Customisation.card_back_id()).is_equal("grove")


func test_unknown_saved_back_falls_back_to_the_default() -> void:
	# Arrange: a file naming a back this version does not have (e.g. removed later).
	var cf := ConfigFile.new()
	cf.set_value(Customisation.SECTION, "card_back", "retired_back")
	cf.save(FILE)
	Customisation.reset_cache()
	# Act
	var id := Customisation.card_back_id()
	# Assert: the default, drawn with the default look.
	assert_str(id).is_equal("violet")
	assert_str(String(Customisation.card_back("retired_back")["id"])).is_equal("violet")
	assert_that(CardBack.style("retired_back")).is_equal(CardBack.STYLES["violet"])


func test_saving_the_back_keeps_the_table_and_other_sections() -> void:
	# Arrange
	Customisation.set_table("parquet")
	var cf := ConfigFile.new()
	cf.load(FILE)
	cf.set_value("ui", "reduce_motion", true)
	cf.save(FILE)
	# Act
	Customisation.set_card_back("sun")
	# Assert
	var back := ConfigFile.new()
	back.load(FILE)
	assert_str(String(back.get_value(Customisation.SECTION, "card_back", ""))).is_equal("sun")
	assert_str(String(back.get_value(Customisation.SECTION, "table", ""))).is_equal("parquet")
	assert_bool(bool(back.get_value("ui", "reduce_motion", false))).is_true()


func test_automated_runs_save_the_back_in_the_test_file() -> void:
	# Arrange: the automatic choice (no override), as in every GdUnit / -s / shots run.
	Customisation.path_override = ""
	# Act
	var p := Customisation.settings_path()
	# Assert: never the player's settings.
	assert_str(p).is_equal(Customisation.TEST_PATH)
	assert_str(p).is_not_equal(Customisation.SETTINGS_PATH)


# ---------------------------------------------------------------- drawing

func test_card_back_draws_the_chosen_back() -> void:
	# Arrange
	Customisation.set_card_back("wyrm")
	# Act
	var st := CardBack.style()
	# Assert: the chosen back's frame colours and painting (piles read the same colours).
	assert_that(st).is_equal(CardBack.STYLES["wyrm"])
	assert_that(CardBack.body_color()).is_equal(CardBack.STYLES["wyrm"]["body"])
	assert_that(CardBack.border_color()).is_equal(CardBack.STYLES["wyrm"]["border"])
	assert_object(CardBack.texture()).is_same(CardBack.texture("wyrm"))


func test_painted_back_textures_are_loaded_once() -> void:
	# Arrange / Act
	var a := CardBack.texture("runes")
	var b := CardBack.texture("runes")
	# Assert: one shared texture, and none for the procedural back.
	assert_object(a).is_same(b)
	assert_object(CardBack.texture("violet")).is_null()


func test_painting_is_cropped_to_the_card_never_stretched() -> void:
	# Arrange: the 512 x 768 painting in a field card's inner rect (narrower than 2:3).
	var tex := Vector2(512, 768)
	var dst := Vector2(75, 118)
	# Act
	var reg := CardBack.cover_region(tex, dst)
	# Assert: the same aspect as the card, centred, inside the texture.
	assert_float(reg.size.x / reg.size.y).is_equal_approx(dst.x / dst.y, 0.001)
	assert_float(reg.position.x + reg.size.x / 2.0).is_equal_approx(256.0, 0.01)
	assert_bool(Rect2(Vector2.ZERO, tex).encloses(reg)).is_true()


func test_every_back_draws_at_small_and_large_sizes() -> void:
	for b in Customisation.CARD_BACKS:
		for sz in SIZES:
			# Arrange
			var probe: BackProbe = auto_free(BackProbe.new())
			probe.back_id = String(b["id"])
			probe.size = sz
			add_child(probe)
			# Act
			probe.queue_redraw()
			await await_idle_frame()
			# Assert: the draw ran to its end.
			assert_bool(probe.finished).override_failure_message("%s at %s" % [b["id"], sz]).is_true()
			remove_child(probe)


func test_face_down_widgets_and_piles_draw_each_back() -> void:
	UIStyle.reduce_motion = true
	for b in Customisation.CARD_BACKS:
		# Arrange: the opponent's hand card, a face-down field card and a deck pile.
		Customisation.set_card_back(String(b["id"]))
		var hand: CardWidget = auto_free(CardWidget.new())
		hand.setup({"hidden": true, "zone": "hand"}, "mini")
		hand.size = Vector2(60, 90)
		var pile: PileStack = auto_free(PileStack.new())
		pile.size = Vector2(80, 120)
		pile.set_pile(14, false)
		add_child(hand)
		add_child(pile)
		# Act
		hand.queue_redraw()
		pile.queue_redraw()
		await await_idle_frame()
		# Assert: both still alive and visible after drawing this back.
		assert_bool(is_instance_valid(hand) and hand.is_visible_in_tree()).is_true()
		assert_that(CardBack.body_color()).is_equal(CardBack.STYLES[String(b["id"])]["body"])
		remove_child(hand)
		remove_child(pile)


# ---------------------------------------------------------------- the picker

func test_picker_marks_the_back_in_use() -> void:
	# Arrange
	Customisation.set_card_back("stars")
	# Act
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new("card_back"))
	# Assert: one tile per back, only the one in use marked, and it is in the showcase.
	assert_int(cp.back_tiles.size()).is_equal(Customisation.CARD_BACKS.size())
	for id in cp.back_tiles:
		assert_bool((cp.back_tiles[id] as CustomisationPanel.BackTile).chosen).is_equal(id == "stars")
	assert_str(cp.back_preview.back_id).is_equal("stars")
	assert_bool(cp.back_preview.chosen).is_true()
	assert_str((cp.find_child("CardBackName", true, false) as Label).text).is_equal("Arcane Starfield")


func test_picking_a_back_tile_saves_it_and_moves_the_mark() -> void:
	# Arrange
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new("card_back"))
	var picked := []
	cp.card_back_picked.connect(func(id): picked.append(id))
	# Act
	(cp.back_tiles["grove"] as Button).pressed.emit()
	# Assert: saved (a fresh read agrees), marked, shown and announced.
	Customisation.reset_cache()
	assert_str(Customisation.card_back_id()).is_equal("grove")
	assert_array(picked).is_equal(["grove"])
	assert_bool((cp.back_tiles["grove"] as CustomisationPanel.BackTile).chosen).is_true()
	assert_bool((cp.back_tiles["violet"] as CustomisationPanel.BackTile).chosen).is_false()
	assert_str(cp.back_preview.back_id).is_equal("grove")


func test_picking_the_back_in_use_changes_nothing() -> void:
	# Arrange
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new("card_back"))
	var picked := []
	cp.card_back_picked.connect(func(id): picked.append(id))
	# Act
	cp.pick_card_back("violet")
	# Assert
	assert_array(picked).is_empty()
	assert_str(Customisation.card_back_id()).is_equal("violet")


func test_hovering_a_tile_previews_it_then_shows_the_back_in_use_again() -> void:
	# Arrange
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new("card_back"))
	var in_use := cp.find_child("InUse", true, false) as Control
	var preview := cp.find_child("Preview", true, false) as Control
	# Act: the pointer enters the Crimson Wyrm tile.
	(cp.back_tiles["wyrm"] as Control).mouse_entered.emit()
	# Assert: previewed, not chosen.
	assert_str(cp.back_preview.back_id).is_equal("wyrm")
	assert_bool(cp.back_preview.chosen).is_false()
	assert_bool(preview.visible).is_true()
	assert_bool(in_use.visible).is_false()
	assert_str(Customisation.card_back_id()).is_equal("violet")
	# Act: it leaves.
	(cp.back_tiles["wyrm"] as Control).mouse_exited.emit()
	# Assert: the back in use again.
	assert_str(cp.back_preview.back_id).is_equal("violet")
	assert_bool(in_use.visible).is_true()
	assert_bool(preview.visible).is_false()


func test_back_tiles_click_with_the_customise_cue() -> void:
	# Arrange
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new("card_back"))
	for id in cp.back_tiles:
		# Act
		var cue := Sfx.button_sound(cp.back_tiles[id] as Button)
		# Assert
		assert_str(cue).is_equal("customise_select")
