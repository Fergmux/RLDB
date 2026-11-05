class_name MainMenu
extends Control
## The main menu screen: title column on a darkened band at the left with a tree of MenuItem
## levels (sub-levels slide in), and the chosen leaf's panel (play vs bot, hot-seat, LAN, Steam,
## resume, the Options sections) centred on screen. Edits the shared SessionOptions; everything
## that leaves the menu is a signal handled by Main.
##
## L28 (owner, 5 Nov): the top-level "Settings" became "Options", a sub-level whose items are its
## sections (Settings, Customisation, Credits; more can be added to MENU["options"]). Opening it
## shows its first section at once, and a section's Close leaves Options.

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
	"root": [["Resume", "resume"], ["Play", "@play"], ["Decks", "@decks"], ["Options", "@options"], ["Quit", "quit"]],
	"play": [["Tutorial", "tutorial"], ["Play online", "@online"], ["Play local", "@local"]],
	"online": [["Host game", "host_online"], ["Join game", "join_online"]],
	"local": [["Play vs Bot", "bot"], ["Hot-seat", "hotseat"], ["Host LAN", "host_lan"], ["Join LAN", "join_lan"]],
	"decks": [["Deck builder", "builder"], ["Card list", "cards"], ["Statistics", "stats"]],
	"options": [["Settings", "settings"], ["Customisation", "customisation"], ["Credits", "credits"]],
}
## The section a sub-level opens with (L28: Options lands on Settings, like the old Settings item).
## In these levels a section's Close (and Esc) leaves the level instead of leaving it empty.
const LEVEL_OPENS := {"options": "settings"}
## Top item of the root level for a profile that has not played yet (F04-09); opens lesson 1.
const PLAY_TUTORIAL_ITEM := ["Play tutorial", "play_tutorial"]
## Third-party asset credits shown under Credits, and the height of their scroll area.
const CREDITS_PATH := "res://data/credits.json"
const CREDITS_H := 430.0
## Final review (2026-11-05): every Options leaf (Settings, Customisation, Credits) is at least this
## tall, so switching between them never makes the panel jump (Credits was 150 px shorter and
## re-centred). Settings and Customisation already reach it; the Credits scroll grows to fill.
const OPTIONS_MIN_H := 788.0
## Space above each credits section heading (review #8).
const CREDITS_HEAD_GAP := 20
## Final review #12: the credits body size, colour and leading (px between wrapped lines), and the
## space between two paragraphs of a section (it was 13-14 px muted text, set solid).
const CREDITS_PX := 16
const CREDITS_COLOR := Color("ddd3bf")
const CREDITS_LEADING := 5
const CREDITS_LINE_GAP := 4
const BAND_W := 520.0
const BAND_FADE_W := 160.0
const BAND_COLOR := Color(0.02, 0.018, 0.025)
const BACKGROUND_DIM := 0.05
const ROOT_ITEM_SIZE := 34
const SUB_ITEM_SIZE := 30
## The sub-level "Back" item: 15% smaller than its siblings (review #4, not 30%), 16 px above it.
const BACK_ITEM_SIZE := 26
const BACK_GAP := 16
## Hero logo and subtitle (D3, review #1 / #2), and the width of the divider under them.
const LOGO_SIZE := 88
const SUBTITLE_SIZE := 14
## Logo baseline to the subtitle's cap tops (review #2).
const SUBTITLE_GAP := 16.0
const LOGO_RULE_W := 300.0
## Ambient motes and the light shaft in the arch (fractions of the screen). J2 (owner, 22 Oct):
## the painting itself never moves. Its old 40 s "Ken Burns" scale drift (1.000 -> 1.006 about the
## centre) made it jump by single pixels now and then: with snap_controls_to_pixels on, Godot
## rounds a Control's canvas translation to whole pixels, and a centred scale moves that
## translation by -pivot * (scale - 1). The motes and the shaft carry the ambient life instead.
const MOTE_COUNT := 26
const SHAFT_RECT := Rect2(0.4, 0.0, 0.22, 0.86)
## Centre panels: padding (24 px modal padding, 28 px clear of the filigree corners) and the
## Settings panel's Close button row.
const CENTER_PAD := Vector2(28, 24)
## Header strip tags of each leaf (review #7): [section on the left, context on the right].
const LEAF_TAGS := {
	"bot": ["Play · local", "Against the bot"], "hotseat": ["Play · local", "This screen"],
	"host_lan": ["Play · local", "LAN"], "join_lan": ["Play · local", "LAN"],
	"host_online": ["Play · online", "Steam"], "join_online": ["Play · online", "Steam"],
	"tutorial": ["Play", "Guided lessons"], "resume": ["Play", "Saved series"],
	"settings": ["Options", "This device"], "customisation": ["Options", "Table and cards"],
	"credits": ["Options", "v%s"],
}
## Width of the Options section panels (one width for all, so switching sections never jumps).
const OPTIONS_PANEL_W := 640.0
## The Options sections (their panels share OPTIONS_PANEL_W).
const OPTIONS_LEAVES := ["settings", "customisation", "credits"]

## The menu backdrop (static, J2), its ambient motes and the hero logo.
var backdrop: Control
var motes: AmbientMotes
var logo: TitleText
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
	backdrop = UIStyle.background(BACKGROUND_DIM, UIStyle.MENU_BACKGROUND)
	backdrop.name = "Backdrop"
	add_child(backdrop)
	# Ambient life (design review #6): drifting petals and gold motes, a light shaft in the arch.
	motes = AmbientMotes.new(MOTE_COUNT, [AmbientMotes.PETAL, AmbientMotes.GOLD])
	motes.name = "AmbientMotes"
	motes.shaft = SHAFT_RECT
	add_child(motes)
	add_child(_band())
	# Menu column (left-aligned, user feedback). Its foot keeps the 24 px safe margin (review #5).
	var col := VBoxContainer.new()
	col.anchor_bottom = 1.0
	col.offset_left = 56.0
	col.offset_right = BAND_W - 60.0
	col.offset_top = 72.0
	col.offset_bottom = -UIStyle.SAFE_HUD
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	# Hero logo (D3, review #1): the T1 gold metal title with its glow and a sweep every 6 s.
	logo = TitleText.make("RLDB", TitleText.Tier.HERO, LOGO_SIZE)
	logo.name = "Logo"
	col.add_child(logo)
	# Subtitle (review #2): Cinzel 600, +2 px tracking, MUTED with a hard shadow, its cap tops
	# SUBTITLE_GAP below the logo's baseline (measured from the fonts, not from the line boxes:
	# the logo's descender room alone is deeper than the gap). The margin may be negative.
	var sub_m := MarginContainer.new()
	sub_m.name = "SubtitleRow"
	sub_m.add_theme_constant_override("margin_top", roundi(subtitle_offset()))
	col.add_child(sub_m)
	var sub := UIStyle.label("A TWO-PLAYER ROGUELIKE DECK BATTLER", SUBTITLE_SIZE, UIStyle.MUTED)
	sub.name = "Subtitle"
	sub.add_theme_font_override("font", _subtitle_font())
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("shadow_offset_x", 0)
	sub.add_theme_constant_override("shadow_offset_y", 1)
	sub.add_theme_constant_override("shadow_outline_size", 2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_m.add_child(sub)
	col.add_child(_gap(UIStyle.sp("lg")))
	# The house divider under the title block.
	var rule := Ornate.Rule.new(Color(UIStyle.GOLD, 0.55), true, 12.0)
	rule.custom_minimum_size.x = LOGO_RULE_W
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(rule)
	col.add_child(_gap(UIStyle.sp("xxxl")))
	_menu_list = VBoxContainer.new()
	_menu_list.add_theme_constant_override("separation", 2)
	col.add_child(_menu_list)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	col.add_child(identity_block())
	# Notices from Main (a failed Steam action, an unreadable save) appear under the identity lines.
	status_label = UIStyle.label("", 13, UIStyle.BAD.lightened(0.15), true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(status_label)
	# Content panels sit in the centre of the whole screen.
	_menu_center = CenterContainer.new()
	_menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_center)
	_build_menu_level(false)


static var _sub_font: FontVariation


## Space (px) between the logo's line box and the subtitle's that puts the subtitle's cap tops
## SUBTITLE_GAP below the logo's baseline: minus the logo's descent and the subtitle's room above
## its caps. Negative when the descent is deeper than the gap.
static func subtitle_offset() -> float:
	var lf := TitleText.tier_font(TitleText.Tier.HERO)
	var sf := _subtitle_font()
	var above_caps := sf.get_ascent(SUBTITLE_SIZE) - TitleText.cap_height(UIStyle.font_display(600), SUBTITLE_SIZE)
	return SUBTITLE_GAP - lf.get_descent(LOGO_SIZE) - above_caps


## Cinzel 600 with +2 px tracking (the menu subtitle).
static func _subtitle_font() -> FontVariation:
	if _sub_font == null:
		_sub_font = FontVariation.new()
		_sub_font.base_font = UIStyle.font_display(600)
		_sub_font.spacing_glyph = 2
	return _sub_font


## F1 (owner feedback 20 Oct): the status lines at the foot of the menu column. "Logged in as
## <Persona>" (the name in gold Cinzel) when Steam is up, or why Steam is unavailable, then
## "Build version <application/config/version>". The persona is read live, never stored.
static func identity_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "IdentityBlock"
	box.add_theme_constant_override("separation", 3)
	var rule := Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), true, 12.0)
	rule.custom_minimum_size.x = 260.0
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(rule)
	var shadow := func(l: Label) -> void:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 2)
	if SteamBridge.available():
		var row := HBoxContainer.new()
		row.name = "LoggedIn"
		row.add_theme_constant_override("separation", 7)
		var pre := UIStyle.label("Logged in as", 16, UIStyle.MUTED)
		pre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		shadow.call(pre)
		row.add_child(pre)
		var nm := UIStyle.label(SteamBridge.persona(), 19, UIStyle.GOLD_HI, false, true)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02, 0.9))
		nm.add_theme_constant_override("outline_size", 3)
		shadow.call(nm)
		row.add_child(nm)
		box.add_child(row)
	else:
		var msg := UIStyle.label(SteamBridge.describe(), 13, UIStyle.MUTED, true)
		msg.name = "SteamState"
		shadow.call(msg)
		box.add_child(msg)
	# Review #5: the status lines read at 12-13 px in MUTED (about 7:1), not dim small print.
	var ver := UIStyle.label("Build version %s" % SteamBridge.build_version(), 12, UIStyle.MUTED, false, true)
	ver.name = "BuildVersion"
	shadow.call(ver)
	box.add_child(ver)
	return box


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
		_menu_list.add_child(_gap(BACK_GAP))
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


## Chooses menu target `target`: "@level" opens a sub-level, "quit"/"builder"/"cards"/"stats" act, any
## other target shows its leaf panel in the centre.
func pick(target: String) -> void:
	# F25: the menu item's own click is the sound (MenuItem through Sfx.install_button_sounds).
	if target.begins_with("@"):
		var level := target.substr(1)
		_menu_path.append(level)
		_menu_leaf = String(LEVEL_OPENS.get(level, ""))
		_set_center(null if _menu_leaf == "" else _leaf_panel(_menu_leaf))
		_build_menu_level()
		return
	match target:
		"quit":
			get_tree().quit()
		"builder":
			deck_builder_requested.emit()
		"cards":
			card_list_requested.emit()
		"stats":
			StatsDialog.open(self)
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
	Sfx.play("back")   # F22: Back item and Esc; coalesced with the item's own click
	if _menu_path.size() > 1:
		_menu_path.pop_back()
	_menu_leaf = ""
	_set_center(null)
	_build_menu_level()


## Esc: closes the shown leaf panel, else goes up one level (nothing at the root). In a level that
## opens with a section (Options), closing its section leaves the level too.
func step_back() -> void:
	if _menu_leaf != "" and LEVEL_OPENS.has(String(_menu_path[-1])):
		back_out()
	elif _menu_leaf != "":
		Sfx.play("back")   # F22
		_menu_leaf = ""
		_set_center(null)
		_build_menu_level(false)
	elif _menu_path.size() > 1:
		back_out()


## Shows `panel` in the centre area (or clears it when null). The panel opens with the house
## motion (HousePanel.appear: pop, gold flare and the panel_open cue) and its title sweeps once;
## the panel it replaces leaves with `panel_out` (UIStyle.tween_out), and clearing the centre plays
## panel_close (design review #106).
func _set_center(panel: Control) -> void:
	var had := false
	for ch in _menu_center.get_children():
		had = true
		_retire(ch as Control)
	if panel == null:
		if had:
			Sfx.play("panel_close")
		return
	_menu_center.add_child(panel)
	if panel is HousePanel:
		(panel as HousePanel).appear()
	var tt: TitleText = panel.get_meta(&"headline") if panel.has_meta(&"headline") else null
	if tt != null:
		tt.play_sweep()


## Takes `old` out of the centre container and lets it fade out where it stood (freed after).
func _retire(old: Control) -> void:
	if old == null:
		return
	var at := old.global_position
	_menu_center.remove_child(old)
	if UIStyle.reduce_motion or not is_inside_tree():
		old.queue_free()
		return
	add_child(old)
	old.global_position = at
	old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in old.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.tween_out(old, true)


# ---------------------------------------------------------------- leaf panels

## A house plate for centre content: returns [panel, content VBox]. The header strip carries the
## leaf's section on the left and its context on the right (`tag`, review #7); the title is a
## SCREEN-tier TitleText (D3) that sweeps once when the panel opens (its "headline" meta).
static func _center_panel(title: String, note: String = "", section: String = "", tag: String = "", width: float = CENTER_PANEL_W) -> Array:
	var p := HousePanel.new(section if section != "" else title, tag, CENTER_PAD, UIStyle.sp("md"))
	p.arm = 18.0
	p.custom_minimum_size = Vector2(width, 0)
	var v := p.body
	var t := UIStyle.label(title, 30, UIStyle.GOLD_HI)
	t.name = "Headline"
	v.add_child(t)
	p.set_meta(&"headline", TitleText.apply(t, TitleText.Tier.SCREEN, 30))
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.55), true, 10.0))
	if note != "":
		var n := UIStyle.label(note, 15, UIStyle.MUTED, true)
		n.name = "Note"
		n.add_theme_constant_override("line_spacing", 4)
		v.add_child(n)
	return [p, v]


## The [section, context] header tags of leaf `target` (review #7); the credits carry the version.
static func leaf_tags(target: String) -> Array:
	var t: Array = LEAF_TAGS.get(target, ["Main menu", ""])
	var ctx := String(t[1])
	if ctx.contains("%s"):
		ctx = ctx % SteamBridge.build_version()
	return [String(t[0]), ctx]


## _center_panel with the leaf's header tags.
static func _leaf(target: String, title: String, note: String = "") -> Array:
	var tags := leaf_tags(target)
	var w := OPTIONS_PANEL_W if target in OPTIONS_LEAVES else CENTER_PANEL_W
	return _center_panel(title, note, tags[0], tags[1], w)


## Opens a credits link (tests swap it out so no browser opens).
static var link_opener: Callable = default_link_opener


## Opens web address `url` in the player's browser.
static func default_link_opener(url: String) -> void:
	OS.shell_open(url)


## Third-party asset credits and licences from data/credits.json, in a ScrollArea (design review
## #8): 24 px fade masks while more lies above or below, 12 px between the text and the track,
## SECTION headings with 20 px above and 8 px below, body lines at line height 1.35.
static func credits_view() -> Control:
	var sa := ScrollArea.new()
	sa.name = "Credits"
	sa.custom_minimum_size = Vector2(0, CREDITS_H)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UIStyle.sp("xs"))
	sa.set_content(v)
	var data = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	var first := true
	for sec in (data.get("sections", []) if data is Dictionary else []):
		if not first:
			v.add_child(_gap(CREDITS_HEAD_GAP - UIStyle.sp("xs")))
		first = false
		var h := UIStyle.label(String(sec.get("title", "")).to_upper(), 15, UIStyle.GOLD)
		v.add_child(h)
		TitleText.apply(h, TitleText.Tier.SECTION, 15)
		v.add_child(_gap(UIStyle.sp("sm") - UIStyle.sp("xs")))
		for line in sec.get("lines", []):
			v.add_child(credit_line(String(line)))
			v.add_child(_gap(CREDITS_LINE_GAP))
	v.add_child(_gap(UIStyle.sp("xl")))   # the last line can scroll clear of the bottom fade
	return sa


## Final review #12: one credits paragraph at a comfortable reading size (CREDITS_PX, in the body
## text colour). Its [url=https://...]label[/url] links show their short label in gold (underlined),
## the address as the tooltip while hovered, and open it on a click (link_opener) with the select cue.
## A raw address is never printed, so nothing wraps mid-path.
static func credit_line(line: String) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.set_meta("credit_line", true)
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.add_theme_font_override("normal_font", UIStyle.font_body())
	rt.add_theme_font_override("bold_font", UIStyle.font_bold())
	rt.add_theme_font_size_override("normal_font_size", CREDITS_PX)
	rt.add_theme_font_size_override("bold_font_size", CREDITS_PX)
	rt.add_theme_color_override("default_color", CREDITS_COLOR)
	rt.add_theme_constant_override("line_separation", CREDITS_LEADING)
	var gold := UIStyle.GOLD_HI.to_html(false)
	var link := RegEx.create_from_string("\\[url=([^\\]]+)\\](.*?)\\[/url\\]")
	rt.text = link.sub(line, "[url=$1][color=#%s]$2[/color][/url]" % gold, true)
	rt.meta_hover_started.connect(func(meta: Variant) -> void:
		rt.tooltip_text = String(meta)
		rt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND)
	rt.meta_hover_ended.connect(func(_meta: Variant) -> void:
		rt.tooltip_text = ""
		rt.mouse_default_cursor_shape = Control.CURSOR_ARROW)
	rt.meta_clicked.connect(func(meta: Variant) -> void:
		var url := String(meta)
		if url.begins_with("https://"):
			Sfx.play("select")
			link_opener.call(url))
	return rt


## A form row in the settings grid (review #9): a 160 px label column, 12 px, the control, at the
## 44 px row pitch. Dropdowns get the house style at 200x32.
static func _labelled(v: VBoxContainer, text: String, ctl: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = SettingsForm.ROW_H
	row.add_theme_constant_override("separation", SettingsForm.COL_GAP)
	var l := UIStyle.label(text, SettingsForm.FONT, UIStyle.TEXT)
	l.custom_minimum_size = Vector2(SettingsForm.LABEL_W, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ctl is OptionButton:
		ctl.custom_minimum_size = SettingsForm.DROPDOWN
		ctl.focus_mode = Control.FOCUS_NONE
		SettingsForm.style_dropdown(ctl as OptionButton)
	elif ctl is LineEdit:
		CardBrowser.style_edit(ctl as LineEdit)
		ctl.custom_minimum_size.y = SettingsForm.DROPDOWN.y + 4.0
	row.add_child(ctl)
	v.add_child(row)


func _start_button(v: VBoxContainer, text: String, fn: Callable) -> void:
	var b := UIStyle.primary_button(text, 19)
	b.custom_minimum_size = Vector2(0, 52)
	var guarded := _series_panel_active
	if guarded:
		var upd := func(): b.disabled = not _series_start_ok()
		series_options_changed.connect(upd)
		# A retired panel leaves the tree twice (it fades out where it stood): disconnect once.
		b.tree_exiting.connect(func(): if series_options_changed.is_connected(upd): series_options_changed.disconnect(upd))
		upd.call()
	b.pressed.connect(func():
		if guarded and not _series_start_ok():
			return
		fn.call())
	v.add_child(b)


## True when the series pickers allow a start. J26: the draft composition is fixed, so every
## choice of the pickers can start (kept as the Start button's guard for future pickers).
func _series_start_ok() -> bool:
	return true


## A house toggle row (SettingsForm.HouseCheck: bevelled box, drawn tick, row hover).
static func _check_box(text: String, on: bool, toggled: Callable) -> CheckBox:
	var cb := SettingsForm.HouseCheck.new(text, on)
	cb.custom_minimum_size.y = 40
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
	dm.add_item("Custom decks")
	dm.add_item("Draft")
	dm.select(0 if opts["deck_mode"] == "starter" else 1)
	_labelled(v, "Decks", dm)
	# J26 (owner, 22 Oct): the composition is fixed; while Draft is chosen a short note says what
	# each player drafts. A stale count from before J26 is dropped, so it is never sent.
	opts.erase("draft_quota")
	var dq := _draft_summary_box()
	dq.visible = opts["deck_mode"] == "draft"
	v.add_child(dq)
	dm.item_selected.connect(func(i):
		opts["deck_mode"] = "starter" if i == 0 else "draft"
		dq.visible = i == 1
		series_options_changed.emit())
	_series_panel_active = true


## J26: what a draft gives each player (the fixed composition from mode_config.json and the basic
## units), as a read-only note under the Decks picker: a section title, one chip per category in its
## kind colour and a line about the basic unit.
func _draft_summary_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "DraftSummary"
	box.add_theme_constant_override("separation", UIStyle.sp("sm"))
	box.add_child(_gap(UIStyle.sp("xs")))
	var dh := UIStyle.label("EACH PLAYER DRAFTS", 14, UIStyle.GOLD)
	box.add_child(dh)
	TitleText.apply(dh, TitleText.Tier.SECTION, 14)
	var q := Series.default_draft_quota()
	var chips := HFlowContainer.new()
	chips.name = "DraftCounts"
	chips.add_theme_constant_override("h_separation", UIStyle.sp("sm"))
	chips.add_theme_constant_override("v_separation", UIStyle.sp("sm"))
	for cat in Series.DRAFT_CATEGORIES:
		var n := int(q.get(cat, 0))
		if n <= 0:
			continue
		var col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.BRONZE)
		var chip := UIStyle.chip("%d %s" % [n, String(Series.DRAFT_LABELS[cat])], col, 15)
		chip.custom_minimum_size.y = 28.0
		chip.name = "Count_%s" % cat
		chips.add_child(chip)
	box.add_child(chips)
	var copies := int(Series.load_mode_config()["draft"].get("basic_copies", 3))
	var note := UIStyle.label("Plus %d copies of a basic unit each player chooses. Draft the categories in any order." % copies, 13, UIStyle.MUTED, true)
	note.custom_minimum_size = Vector2(300, 0)
	box.add_child(note)
	box.add_child(_gap(UIStyle.sp("xs")))
	return box


## A secondary "Close" at the bottom right of a centre panel (review #11): 44 px, 12 px above it
## from the content (the body's separation), the panel padding below.
func _close_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "CloseRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	var b := UIStyle.size_button(UIStyle.secondary_button("Close", 15), "standard")
	b.name = "Close"
	b.custom_minimum_size.x = 140
	b.pressed.connect(step_back)
	row.add_child(b)
	return row


## The Play vs Bot note: who chooses the bot's deck (J24).
static func bot_note(player_picks: bool) -> String:
	if player_picks:
		return "A series against the computer. After choosing your deck, you choose the bot's."
	return "A series against the computer. The bot picks a random Structure deck, or drafts its own."


## J24: the "Choose the bot's deck" toggle of Play vs Bot, shown while Custom decks is chosen (a
## draft has no deck to choose) and remembered for this viewer (SessionOptions).
func _bot_deck_box(v: VBoxContainer) -> CheckBox:
	var note: Label = v.get_node_or_null("Note")
	var cb := SettingsForm.HouseCheck.new("Choose the bot's deck", _options.choose_bot_deck)
	cb.custom_minimum_size.y = 40
	var sync := func():
		if not is_instance_valid(cb):
			return
		cb.visible = String(_options.series.get("deck_mode", "starter")) == "starter"
		if note != null and is_instance_valid(note):
			note.text = bot_note(_options.bot_deck_pick(_options.series))
	cb.toggled.connect(func(on: bool):
		_options.set_choose_bot_deck(on)
		sync.call())
	cb.name = "ChooseBotDeck"
	cb.tooltip_text = "After you choose your deck, a second deck screen lets you pick the deck the bot plays.\nOff: the bot plays a random Structure deck."
	v.add_child(cb)
	series_options_changed.connect(sync)
	# A retired panel leaves the tree twice (it fades out where it stood): disconnect once.
	cb.tree_exiting.connect(func(): if series_options_changed.is_connected(sync): series_options_changed.disconnect(sync))
	sync.call()
	return cb


func _privacy_box(text: String) -> CheckBox:
	return _check_box(text, _options.privacy, func(on): _options.privacy = on)


## Centre content for a leaf of the menu tree (null for an unknown target).
func _leaf_panel(target: String) -> Control:
	var pv: Array
	_series_panel_active = false
	match target:
		"bot":
			pv = _leaf(target, "Play vs Bot", bot_note(_options.bot_deck_pick(_options.series)))
			_series_options(pv[1])
			_bot_deck_box(pv[1])
			_start_button(pv[1], "Start series", bot_requested.emit)
		"hotseat":
			pv = _leaf(target, "Hot-seat", "Two players take turns on this screen.")
			_series_options(pv[1])
			pv[1].add_child(_privacy_box("Privacy screen between turns"))
			_start_button(pv[1], "Start series", hotseat_requested.emit)
		"host_lan":
			pv = _leaf(target, "Host LAN", "Your friend joins with your computer's local IP address and this port.")
			_series_options(pv[1])
			var port := LineEdit.new()
			port.text = _options.lan_addr.split(":")[-1]
			port.custom_minimum_size = Vector2(160, 0)
			_labelled(pv[1], "Port", port)
			_start_button(pv[1], "Host series", func(): lan_host_requested.emit(int(port.text)))
		"join_lan":
			pv = _leaf(target, "Join LAN", "Enter the host's address and port (for example 192.168.1.20:24680).")
			var addr := LineEdit.new()
			addr.text = _options.lan_addr
			addr.custom_minimum_size = Vector2(260, 0)
			_labelled(pv[1], "Address", addr)
			_start_button(pv[1], "Join", func():
				_options.lan_addr = addr.text
				var hp := addr.text.split(":")
				lan_join_requested.emit(hp[0], int(hp[1]) if hp.size() > 1 else SessionOptions.DEFAULT_LAN_PORT))
		"host_online":
			pv = _leaf(target, "Host game", "Creates a Steam lobby. Invite a friend from the next screen.")
			_series_options(pv[1])
			var pub := _check_box("List my lobby publicly", _options.series.get("public_lobby", false),
					func(on): _options.series["public_lobby"] = on)
			pub.tooltip_text = "Off: friends-only, joined by invite. On: also visible under Join game."
			pv[1].add_child(pub)
			pv[1].add_child(UIStyle.label(SteamBridge.describe(), 14, UIStyle.TEXT_DIM, true))
			_start_button(pv[1], "Host", steam_host_requested.emit)
		"join_online":
			pv = _leaf(target, "Join game", "Accept a friend's invite in the Steam overlay, or browse public lobbies.")
			pv[1].add_child(UIStyle.label(SteamBridge.describe(), 14, UIStyle.TEXT_DIM, true))
			_start_button(pv[1], "Browse public lobbies", steam_browse_requested.emit)
		"tutorial":
			pv = _leaf(target, "Tutorial", "Guided lessons on a prepared board against a scripted Rival. Nothing is saved.")
			TutorialMenu.add_lessons(pv[1], tutorial_requested.emit)
		"resume":
			pv = _leaf(target, "Resume", "Pick up a series where you left it.")
			SavedSeriesList.add_to(pv[1], SeriesStore.list(), resume_requested.emit, delete_save_requested.emit)
		"settings":
			pv = _leaf(target, "Settings")
			# The shared settings form (review #9-#11): the same builder as the in-game settings,
			# centred in the Options width (L28).
			var form := SettingsForm.new(Callable(), [{"key": "privacy", "text": "Privacy screen between turns (hot-seat)",
					"on": _options.privacy, "toggled": func(on): _options.privacy = on}])
			form.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			pv[1].add_child(form)
			pv[1].add_child(_close_row())
		"customisation":
			pv = _leaf(target, "Customisation")
			pv[1].add_child(CustomisationPanel.new())
			pv[1].add_child(_close_row())
		"credits":
			pv = _leaf(target, "Credits")
			var cv := credits_view()
			cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
			pv[1].add_child(cv)
			pv[1].add_child(_close_row())
		_:
			return null
	if target in OPTIONS_LEAVES:
		(pv[0] as Control).custom_minimum_size.y = OPTIONS_MIN_H
		(pv[1] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	return pv[0]
