class_name MainMenu
extends Control
## The main menu screen: title column on a darkened band at the left with a tree of MenuItem
## levels (sub-levels slide in), and the chosen leaf's panel (play vs bot, hot-seat, LAN, Steam,
## resume, settings) centred on screen. Edits the shared SessionOptions; everything that leaves
## the menu is a signal handled by Main.

## Emitted when a game against the bot is chosen.
signal bot_requested
## Emitted when a hot-seat game is chosen.
signal hotseat_requested
## Emitted to host a LAN game on a port.
signal lan_host_requested(port: int)
## Emitted to join a LAN game.
signal lan_join_requested(host: String, port: int)
## Emitted to host a Steam lobby.
signal steam_host_requested
## Emitted to browse Steam lobbies.
signal steam_browse_requested
## Emitted to resume a saved series.
signal resume_requested(id: String, mode: String)
## Emitted to delete a saved series.
signal delete_save_requested(id: String)
## Emitted to open the deck builder.
signal deck_builder_requested
## Emitted to open the card list.
signal card_list_requested
## Emitted to start the guided tutorial at lesson `lesson` (F03-15).
signal tutorial_requested(lesson: int)

## Menu tree: level -> items [label, target]. A target starting with "@" opens a sub-level;
## anything else is a leaf shown in the centre (or an action).
const MENU := {
	"root": [["Resume", "resume"], ["Play", "@play"], ["Decks", "@decks"], ["Settings", "settings"], ["Quit", "quit"]],
	"play": [["Tutorial", "tutorial"], ["Play online", "@online"], ["Play local", "@local"]],
	"online": [["Host game", "host_online"], ["Join game", "join_online"]],
	"local": [["Play vs Bot", "bot"], ["Hot-seat", "hotseat"], ["Host LAN", "host_lan"], ["Join LAN", "join_lan"]],
	"decks": [["Deck builder", "builder"], ["Card list", "cards"]],
}
## Top item of the root level for a profile that has not played yet (F04-09); opens lesson 1.
const PLAY_TUTORIAL_ITEM := ["Play tutorial", "play_tutorial"]
const BAND_W := 520.0
const BAND_FADE_W := 160.0
const BAND_COLOR := Color(0.02, 0.018, 0.025)
const BACKGROUND_DIM := 0.05
const ROOT_ITEM_SIZE := 34
const SUB_ITEM_SIZE := 30
const BACK_ITEM_SIZE := 22
## Slide-in of a menu level: per-item delay, start offset, fade and slide durations.
const SLIDE_STAGGER := 0.045
const SLIDE_FROM := -60.0
const SLIDE_FADE_TIME := 0.22
const SLIDE_TIME := 0.32
const CENTER_FADE_TIME := 0.25
const CENTER_PANEL_W := 560.0

## Steam status line at the bottom of the menu column (Main writes errors here too).
var status_label: Label

var _options: SessionOptions
## True while building a panel that carries the series pickers (its Start checks the draft counts).
var _series_panel_active := false
## Emitted when the deck mode or draft counts change, so the Start button can enable / disable itself.
signal series_options_changed
var _menu_path: Array = ["root"]
var _menu_list: VBoxContainer
var _menu_center: CenterContainer
var _menu_leaf: String = ""


func _init(options: SessionOptions) -> void:
	_options = options
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	add_child(UIStyle.background(BACKGROUND_DIM, UIStyle.MENU_BACKGROUND))
	add_child(_band())
	# Menu column (left-aligned, user feedback).
	var col := VBoxContainer.new()
	col.anchor_bottom = 1.0
	col.offset_left = 56.0
	col.offset_right = BAND_W - 60.0
	col.offset_top = 80.0
	col.offset_bottom = -40.0
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var title := UIStyle.title_label("RLDB", 88, UIStyle.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)
	var sub := UIStyle.title_label("A TWO-PLAYER ROGUELIKE DECK BATTLER", 14, UIStyle.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(sub)
	col.add_child(_gap(54))
	col.add_child(_gap(24))
	_menu_list = VBoxContainer.new()
	_menu_list.add_theme_constant_override("separation", 2)
	col.add_child(_menu_list)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	status_label = UIStyle.label(SteamBridge.describe(), 13, UIStyle.TEXT_DIM, true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(status_label)
	# Content panels sit in the centre of the whole screen.
	_menu_center = CenterContainer.new()
	_menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_center)
	_build_menu_level(false)


## Darkened band on the left, fading out toward the right edge.
func _band() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(BAND_COLOR, 0.9))
	g.set_color(1, Color(BAND_COLOR, 0.0))
	g.add_point(0.68, Color(BAND_COLOR, 0.78))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	var band := TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_bottom = 1.0
	band.offset_right = BAND_W + BAND_FADE_W
	return band


static func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


## Builds the items of the current menu level; `animate` slides them in one after another.
func _build_menu_level(animate: bool = true) -> void:
	for ch in _menu_list.get_children():
		_menu_list.remove_child(ch)
		ch.queue_free()
	var level: String = _menu_path[-1]
	var items: Array = MENU[level].duplicate()
	if level == "root" and SeriesStore.list().is_empty():
		items = items.filter(func(it): return it[1] != "resume")
	if level == "root" and not PlayerProgress.has_played():
		# F04-09: a profile that has not played yet is offered the tutorial at the top of the menu.
		items.push_front(PLAY_TUTORIAL_ITEM)
	var i := 0
	for it in items:
		var mi := MenuItem.new(it[0], ROOT_ITEM_SIZE if level == "root" else SUB_ITEM_SIZE)
		mi.active = it[1] == _menu_leaf
		var target: String = it[1]
		mi.pressed.connect(func(): pick(target))
		_menu_list.add_child(mi)
		_slide_in(mi, i, animate)
		i += 1
	if level != "root":
		var back := MenuItem.new("Back", BACK_ITEM_SIZE, true)
		back.pressed.connect(back_out)
		_menu_list.add_child(back)
		_slide_in(back, i, animate)


func _slide_in(mi: MenuItem, i: int, animate: bool) -> void:
	if not animate or UIStyle.reduce_motion:
		return
	mi.modulate.a = 0.0
	mi.slide = SLIDE_FROM
	var tw := mi.create_tween()
	tw.tween_interval(SLIDE_STAGGER * i)
	tw.set_parallel(true)
	tw.tween_property(mi, "modulate:a", 1.0, SLIDE_FADE_TIME)
	tw.tween_property(mi, "slide", 0.0, SLIDE_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Chooses menu target `target`: "@level" opens a sub-level, "quit"/"builder"/"cards" act, any
## other target shows its leaf panel in the centre.
func pick(target: String) -> void:
	Sfx.play("confirm")
	if target.begins_with("@"):
		_menu_path.append(target.substr(1))
		_menu_leaf = ""
		_set_center(null)
		_build_menu_level()
		return
	match target:
		"quit":
			get_tree().quit()
		"builder":
			deck_builder_requested.emit()
		"cards":
			card_list_requested.emit()
		"play_tutorial":
			tutorial_requested.emit(0)
		_:
			_menu_leaf = target
			for mi in _menu_list.get_children():
				if mi is MenuItem:
					(mi as MenuItem).active = false
			_build_menu_level(false)
			_set_center(_leaf_panel(target))


## Goes up one menu level (the "Back" item).
func back_out() -> void:
	Sfx.play("cancel")
	if _menu_path.size() > 1:
		_menu_path.pop_back()
	_menu_leaf = ""
	_set_center(null)
	_build_menu_level()


## Esc: closes the shown leaf panel, else goes up one level (nothing at the root).
func step_back() -> void:
	if _menu_leaf != "":
		_menu_leaf = ""
		_set_center(null)
		_build_menu_level(false)
	elif _menu_path.size() > 1:
		back_out()


## Shows `panel` in the centre area with a short fade (or clears it when null).
func _set_center(panel: Control) -> void:
	for ch in _menu_center.get_children():
		_menu_center.remove_child(ch)
		ch.queue_free()
	if panel == null:
		return
	_menu_center.add_child(panel)
	if UIStyle.reduce_motion:
		return
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, CENTER_FADE_TIME).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- leaf panels

## A dark panel for centre content: returns [panel, content VBox].
static func _center_panel(title: String, note: String = "") -> Array:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.035, 0.03, 0.04, 0.9), Color(UIStyle.GOLD, 0.5), 1, 12)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 30)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 24)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(CENTER_PANEL_W, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UIStyle.title_label(title, 30, UIStyle.GOLD))
	if note != "":
		v.add_child(UIStyle.label(note, 15, UIStyle.TEXT_DIM, true))
	return [p, v]


static func _labelled(v: VBoxContainer, text: String, ctl: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UIStyle.label(text, 17, UIStyle.TEXT)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	row.add_child(ctl)
	v.add_child(row)


func _start_button(v: VBoxContainer, text: String, fn: Callable) -> void:
	var b := UIStyle.primary_button(text, 19)
	b.custom_minimum_size = Vector2(0, 52)
	var guarded := _series_panel_active
	if guarded:
		var upd := func(): b.disabled = not _series_start_ok()
		series_options_changed.connect(upd)
		b.tree_exiting.connect(func(): series_options_changed.disconnect(upd))
		upd.call()
	b.pressed.connect(func():
		# F03-10: an unusable draft composition is explained by the pickers and blocks the start.
		var so: Dictionary = _options.series
		if guarded and not _series_start_ok():
			return
		fn.call())
	v.add_child(b)


## False while Draft is chosen with an unusable composition (F03-10).
func _series_start_ok() -> bool:
	var so: Dictionary = _options.series
	return not (so.get("deck_mode", "") == "draft" and Series.validate_draft_quota(so.get("draft_quota", Series.default_draft_quota())) != "")


static func _check_box(text: String, on: bool, toggled: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = on
	cb.toggled.connect(toggled)
	return cb


## Best-of / deck mode pickers shared by every "start a series" panel.
func _series_options(v: VBoxContainer) -> void:
	var opts := _options.series
	var bo := OptionButton.new()
	for n in SessionOptions.BEST_OF_CHOICES:
		bo.add_item(str(n), n)
	bo.select(SessionOptions.BEST_OF_CHOICES.find(opts["best_of"]))
	bo.item_selected.connect(func(i): opts["best_of"] = bo.get_item_id(i))
	_labelled(v, "Best of", bo)
	var dm := OptionButton.new()
	dm.add_item("Starter decks")
	dm.add_item("Draft")
	dm.select(0 if opts["deck_mode"] == "starter" else 1)
	_labelled(v, "Decks", dm)
	# F03-10: draft composition, shown while Draft is chosen. In online/LAN games the host's
	# counts are the series config both seats use.
	var dq := _draft_quota_box(opts)
	dq.visible = opts["deck_mode"] == "draft"
	v.add_child(dq)
	dm.item_selected.connect(func(i):
		opts["deck_mode"] = "starter" if i == 0 else "draft"
		dq.visible = i == 1
		series_options_changed.emit())
	_series_panel_active = true


## Per-category draft count steppers (defaults from mode_config.json), the pick total and why
## the composition cannot be used, if it cannot (F03-10). Edits opts["draft_quota"] in place.
func _draft_quota_box(opts: Dictionary) -> VBoxContainer:
	if not (opts.get("draft_quota", null) is Dictionary):
		opts["draft_quota"] = Series.default_draft_quota()
	var q: Dictionary = opts["draft_quota"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(UIStyle.label("Draft picks per category", 15, UIStyle.MUTED))
	var total_l := UIStyle.label("", 14, UIStyle.MUTED)
	var warn := UIStyle.label("", 14, Color("ff6b5e"))
	var refresh := func():
		var e := Series.validate_draft_quota(q)
		warn.text = e
		warn.visible = e != ""
		var n := 0
		for c in Series.DRAFT_CATEGORIES:
			n += int(q.get(c, 0))
		total_l.text = "%d picks in total" % n
		series_options_changed.emit()
	for cat in Series.DRAFT_CATEGORIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l := UIStyle.label(String(Series.DRAFT_LABELS[cat]), 15, UIStyle.TEXT)
		name_l.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_l)
		var minus := UIStyle.button("-", 15)
		minus.custom_minimum_size = Vector2(36, 30)
		var val := UIStyle.label(str(int(q.get(cat, 0))), 16, UIStyle.TEXT)
		val.custom_minimum_size = Vector2(40, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := UIStyle.button("+", 15)
		plus.custom_minimum_size = Vector2(36, 30)
		var c2: String = cat
		minus.pressed.connect(func():
			q[c2] = maxi(int(q.get(c2, 0)) - 1, 0)
			val.text = str(q[c2])
			refresh.call())
		plus.pressed.connect(func():
			q[c2] = mini(int(q.get(c2, 0)) + 1, Series.DRAFT_MAX_PER_CATEGORY)
			val.text = str(q[c2])
			refresh.call())
		row.add_child(minus)
		row.add_child(val)
		row.add_child(plus)
		box.add_child(row)
	box.add_child(total_l)
	box.add_child(warn)
	refresh.call()
	return box


func _privacy_box(text: String) -> CheckBox:
	return _check_box(text, _options.privacy, func(on): _options.privacy = on)


## Centre content for a leaf of the menu tree (null for an unknown target).
func _leaf_panel(target: String) -> Control:
	var pv: Array
	_series_panel_active = false
	match target:
		"bot":
			pv = _center_panel("Play vs Bot", "A series against the computer. The bot picks a random starter deck.")
			_series_options(pv[1])
			_start_button(pv[1], "Start series", bot_requested.emit)
		"hotseat":
			pv = _center_panel("Hot-seat", "Two players take turns on this screen.")
			_series_options(pv[1])
			pv[1].add_child(_privacy_box("Privacy screen between turns"))
			_start_button(pv[1], "Start series", hotseat_requested.emit)
		"host_lan":
			pv = _center_panel("Host LAN", "Your friend joins with your computer's local IP address and this port.")
			_series_options(pv[1])
			var port := LineEdit.new()
			port.text = _options.lan_addr.split(":")[-1]
			port.custom_minimum_size = Vector2(160, 0)
			_labelled(pv[1], "Port", port)
			_start_button(pv[1], "Host series", func(): lan_host_requested.emit(int(port.text)))
		"join_lan":
			pv = _center_panel("Join LAN", "Enter the host's address and port (for example 192.168.1.20:24680).")
			var addr := LineEdit.new()
			addr.text = _options.lan_addr
			addr.custom_minimum_size = Vector2(260, 0)
			_labelled(pv[1], "Address", addr)
			_start_button(pv[1], "Join", func():
				_options.lan_addr = addr.text
				var hp := addr.text.split(":")
				lan_join_requested.emit(hp[0], int(hp[1]) if hp.size() > 1 else SessionOptions.DEFAULT_LAN_PORT))
		"host_online":
			pv = _center_panel("Host game", "Creates a Steam lobby and opens the invite dialog.")
			_series_options(pv[1])
			var pub := _check_box("List my lobby publicly", _options.series.get("public_lobby", false),
					func(on): _options.series["public_lobby"] = on)
			pub.tooltip_text = "Off: friends-only, joined by invite. On: also visible under Join game."
			pv[1].add_child(pub)
			pv[1].add_child(UIStyle.label(SteamBridge.describe(), 14, UIStyle.TEXT_DIM, true))
			_start_button(pv[1], "Host and invite", steam_host_requested.emit)
		"join_online":
			pv = _center_panel("Join game", "Accept a friend's invite in the Steam overlay, or browse public lobbies.")
			pv[1].add_child(UIStyle.label(SteamBridge.describe(), 14, UIStyle.TEXT_DIM, true))
			_start_button(pv[1], "Browse public lobbies", steam_browse_requested.emit)
		"tutorial":
			pv = _center_panel("Tutorial", "Guided lessons on a prepared board against a scripted Rival. Nothing is saved.")
			TutorialMenu.add_lessons(pv[1], tutorial_requested.emit)
		"resume":
			pv = _center_panel("Resume", "Pick up a series where you left it.")
			SavedSeriesList.add_to(pv[1], SeriesStore.list(), resume_requested.emit, delete_save_requested.emit)
		"settings":
			pv = _center_panel("Settings")
			pv[1].add_child(UIStyle.display_controls(16))
			pv[1].add_child(GameMenu.audio_controls(16))
			pv[1].add_child(_check_box("Reduced motion (no travel, shake or particles)", UIStyle.reduce_motion,
					func(on): UIStyle.set_reduce_motion(on)))
			pv[1].add_child(_check_box("Fast animations (half duration)", UIStyle.fast_anim,
					func(on): UIStyle.set_fast_anim(on)))
			pv[1].add_child(_privacy_box("Privacy screen between turns (hot-seat)"))
		_:
			return null
	return pv[0]
