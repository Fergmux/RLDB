class_name StatsDialog
extends Control
## The player's statistics (Decks > Statistics): a house plate over a dimmed screen listing a few
## facts from PlayerStats (record, streaks, favourite cards and decks, game times). The plate's
## corner says where they come from ("Synced" with the Steam account, or "This computer"), and a
## small sync line under the list shows the cloud state (StatsSync.describe()) with a status dot:
## gold when synced, a slow amber pulse while syncing or waiting, dim when local only.
## The list refreshes in place when a cloud copy merges in while the dialog is open.
## Clicking the dim, Close or Esc closes it.

const PANEL_W := 560.0
## The list scrolls inside the plate above this share of the window height.
const LIST_MAX_SHARE := 0.6
const ROW_H := 42.0
## The sync line's size (design review #94: 12 px or more, MUTED).
const FOOT_FONT := 13

## The SCREEN-tier headline (D3).
var headline: TitleText


## Opens the dialog as a full-rect child of `parent` and returns it. `facts` (empty) means the
## stored record (PlayerStats.facts()).
static func open(parent: Node, facts: Array = []) -> StatsDialog:
	var d := StatsDialog.new()
	d._fixed = not facts.is_empty()
	d._build(facts if not facts.is_empty() else PlayerStats.facts())
	parent.add_child(d)
	d._panel.appear()
	d.headline.play_sweep()
	Telemetry.refresh_stats()
	return d


## Closes the dialog with the panel_close cue (design review #106).
func close() -> void:
	if not is_queued_for_deletion():
		Sfx.play("panel_close")
		queue_free()


var _panel: HousePanel
## Facts passed in by the caller (tests, shots): never replaced by the stored record.
var _fixed := false
var _list_holder: VBoxContainer
var _sync_dot: SyncDot
var _sync_label: Label
var _seen_rev := -1
var _seen_state := ""
var _poll := 0.0


## Where the facts come from, for the plate's corner: "Synced" or "This computer".
static func source_label(state: String) -> String:
	return "Synced" if state in ["synced", "syncing"] else "This computer"


## The sync line under the list: "<label> · <detail>".
static func sync_text(info: Dictionary) -> String:
	return String(info["label"]) + ((" · " + String(info["detail"])) if String(info.get("detail", "")) != "" else "")


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.5:
		return
	_poll = 0.0
	var info := StatsSync.describe()
	if String(info["state"]) + sync_text(info) != _seen_state:
		_apply_sync(info)
	if not _fixed and PlayerStats.revision != _seen_rev:
		_seen_rev = PlayerStats.revision
		_fill(PlayerStats.facts())


func _apply_sync(info: Dictionary) -> void:
	_seen_state = String(info["state"]) + sync_text(info)
	_sync_label.text = sync_text(info)
	_sync_label.add_theme_color_override("font_color", UIStyle.MUTED if info["state"] == "synced" else Color(UIStyle.MUTED, 0.85))
	_sync_dot.state = String(info["state"])
	_sync_dot.queue_redraw()
	_panel.set_tag(source_label(String(info["state"])))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		Sfx.play("back")
		close()
		get_viewport().set_input_as_handled()


func _build(facts: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = UiLayers.CONFIRM_DIALOG
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, ConfirmDialog.DIM_ALPHA)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close())
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var info := StatsSync.describe()
	_panel = HousePanel.new("Statistics", source_label(String(info["state"])), Vector2(28, 24), UIStyle.sp("md"))
	_panel.arm = 18.0
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	cc.add_child(_panel)
	var v := _panel.body
	headline = TitleText.apply(_panel.add_headline("Your statistics", 26, true, 12.0), TitleText.Tier.SCREEN, 26)
	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 0)
	v.add_child(_list_holder)
	_seen_rev = PlayerStats.revision
	_fill(facts)
	# Sync line: a status dot and where the record lives.
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 8)
	foot.tooltip_text = "Your statistics are saved on this computer. With Steam running and statistics sharing on, they are also kept with your Steam account (as a one-way code, never your Steam ID) and appear on any computer you play on."
	foot.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(foot)
	_sync_dot = SyncDot.new()
	foot.add_child(_sync_dot)
	_sync_label = UIStyle.label("", FOOT_FONT, UIStyle.MUTED)
	_sync_label.mouse_filter = Control.MOUSE_FILTER_PASS
	foot.add_child(_sync_label)
	_apply_sync(info)
	# Close is a secondary everywhere (design review #89): 44 px, 160 wide.
	var close_btn := UIStyle.size_button(UIStyle.secondary_button("Close", 15), "standard")
	close_btn.name = "Close"
	close_btn.custom_minimum_size.x = 160
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	v.add_child(close_btn)


## (Re)builds the fact list (or the empty-state line) inside the plate.
func _fill(facts: Array) -> void:
	for c in _list_holder.get_children():
		_list_holder.remove_child(c)
		c.queue_free()
	if facts.is_empty():
		# Illustrated empty state (design review #96): an engraved trophy, a title and the sentence.
		var e := EngravedIcon.empty_state("trophy", "No duels yet", "Finish a duel and your record, favourite cards and best streaks will appear here.", "", Callable(), PANEL_W - 96.0)
		e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list_holder.add_child(e)
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	for i in facts.size():
		list.add_child(_row(facts[i], i % 2 == 1))
	var max_h := maxf(260.0, parent_height() * LIST_MAX_SHARE)
	if facts.size() * ROW_H > max_h:
		var sa := ScrollArea.new()
		sa.custom_minimum_size = Vector2(0, max_h)
		sa.set_content(list)
		_list_holder.add_child(sa)
	else:
		_list_holder.add_child(list)


## Height available to the dialog (the window, before it is in the tree).
func parent_height() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_visible_rect().size.y if tree != null and tree.root != null else 900.0


## One fact: label (and its detail underneath) on the left, the value in gold on the right.
func _row(f: Dictionary, shaded: bool) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035) if shaded else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(6)
	UIStyle.pad(sb, "md", "xs")
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	pc.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	left.add_child(UIStyle.label(String(f["label"]), 15, UIStyle.TEXT))
	if String(f.get("detail", "")) != "":
		var d := UIStyle.label(String(f["detail"]), 12, UIStyle.TEXT_DIM)
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.custom_minimum_size = Vector2(120, 0)
		left.add_child(d)
	var val := UIStyle.label(String(f["value"]), 17, UIStyle.GOLD_HI)
	val.add_theme_font_override("font", UIStyle.font_bold())
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(val)
	return pc



## The sync status dot: a gold gem with a soft halo when synced, a slow amber pulse while syncing
## or waiting to sync (steady under reduce motion), a dim bronze ring when local only.
class SyncDot extends Control:
	var state := "local"
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(14, 14)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if state in ["syncing", "pending"] and not UIStyle.reduce_motion:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		match state:
			"synced":
				draw_circle(c, 6.5, Color(UIStyle.GOLD_HI, 0.16))
				draw_circle(c, 4.0, UIStyle.GOLD)
				draw_circle(c + Vector2(-1.1, -1.2), 1.4, Color(1, 1, 1, 0.55))
			"syncing", "pending":
				var k := 0.5 + 0.5 * sin(_t * 3.2) if not UIStyle.reduce_motion else 0.7
				draw_circle(c, 6.5, Color("e9a14a", 0.10 + 0.14 * k))
				draw_circle(c, 3.6, Color("e9a14a", 0.65 + 0.35 * k))
			"error":
				draw_arc(c, 4.0, 0, TAU, 20, Color(UIStyle.BAD, 0.7), 1.4, true)
			_:
				draw_arc(c, 4.0, 0, TAU, 20, Color(UIStyle.BRONZE.lightened(0.2), 0.9), 1.4, true)
