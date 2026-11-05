class_name CustomisationPanel
extends VBoxContainer
## Options > Customisation (owner feedback 5 Nov, L28): the player's cosmetic choices in folder-tab
## sub-sections that can grow later.
##   Table      the four tables as framed thumbnails (2 x 2) with their names. Hover lifts and
##              lights a tile; the chosen one has a gold rim, a gold glow and a tick medallion.
##              Picking saves at once (Customisation) and plays "customise_select"; the board
##              uses it from the next game.
##   Card back  the card back in use, drawn by CardBack itself, and a note that more are coming.
## Presentation only: it reads and writes Customisation and nothing else.
##
##     panel.body.add_child(CustomisationPanel.new())

## Emitted after the player picks a table (its id).
signal table_picked(id: String)

## Sub-section keys, in tab order.
const SECTIONS := [["table", "Table"], ["card_back", "Card back"]]
## Tile thumbnail size (the art's 2967:2156 aspect) and the gaps of the 2 x 2 grid.
const THUMB := Vector2(256, 186)
const GRID_GAP := Vector2(16, 14)
## Card back preview size (the card's 5:7 portrait), the width of its description column, and the
## empty "coming soon" sockets beside it.
const BACK_SIZE := Vector2(180, 252)
const BACK_INFO_W := 300.0
const SOCKETS := 3
const SOCKET_SIZE := Vector2(64, 90)

## The open sub-section's key.
var section: String = "table"
## The folder tabs over the sub-sections.
var tabs: FolderTabs
## The table tiles by table id.
var tiles: Dictionary = {}

var _pages: Dictionary = {}


func _init(open_section: String = "table") -> void:
	name = "CustomisationPanel"
	add_theme_constant_override("separation", 0)
	tabs = FolderTabs.new()
	tabs.name = "Sections"
	tabs.tab_height = 40.0
	tabs.font_size = 16
	tabs.left_margin = 18.0
	tabs.set_pane_margins(UIStyle.sp("lg"), UIStyle.sp("lg"), UIStyle.sp("lg"), UIStyle.sp("lg"))
	for s in SECTIONS:
		tabs.add_tab(String(s[0]), String(s[1]), {"min_width": 120.0})
	add_child(tabs)
	var stack := Control.new()   # both pages overlap; the taller one sets the height
	stack.name = "Pages"
	tabs.pane.add_child(stack)
	_pages["table"] = _table_page()
	_pages["card_back"] = _card_back_page()
	for k in _pages:
		var page: Control = _pages[k]
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(page)
	stack.custom_minimum_size = _pages_min_size()
	tabs.tab_selected.connect(show_section)
	show_section(open_section)


## The two pages' common minimum size (the larger of each).
func _pages_min_size() -> Vector2:
	var m := Vector2.ZERO
	for k in _pages:
		var c: Vector2 = (_pages[k] as Control).get_combined_minimum_size()
		m = Vector2(maxf(m.x, c.x), maxf(m.y, c.y))
	return m


## Opens sub-section `key` ("table" or "card_back").
func show_section(key: String) -> void:
	if not _pages.has(key):
		return
	section = key
	tabs.select(key, false)
	for k in _pages:
		(_pages[k] as Control).visible = k == key


# ---------------------------------------------------------------- Table

func _table_page() -> Control:
	var v := VBoxContainer.new()
	v.name = "TablePage"
	v.add_theme_constant_override("separation", UIStyle.sp("md"))
	var note := UIStyle.label("The table your games are played on. A new choice applies from your next game.", 14, UIStyle.MUTED, true)
	note.name = "TableNote"
	note.add_theme_constant_override("line_spacing", 3)
	v.add_child(note)
	var grid := GridContainer.new()
	grid.name = "TablePicker"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(GRID_GAP.x))
	grid.add_theme_constant_override("v_separation", int(GRID_GAP.y))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var current := Customisation.table_id()
	for t in Customisation.TABLES:
		var id := String(t["id"])
		var tile := TableTile.new(t, id == current)
		tile.name = "Tile_" + id
		tile.pressed.connect(func(): pick_table(id))
		grid.add_child(tile)
		tiles[id] = tile
	v.add_child(grid)
	v.add_child(_gap(UIStyle.sp("xs")))
	return v


## Chooses table `id` (saved at once), marks its tile and emits `table_picked`. A pick of the
## table already chosen changes nothing.
func pick_table(id: String) -> void:
	if id == Customisation.table_id() or not Customisation.set_table(id):
		return
	for k in tiles:
		(tiles[k] as TableTile).chosen = k == id
	table_picked.emit(id)


## One table of the picker: the thumbnail with rounded corners in a bevelled frame, the table's
## name in Cinzel and a one-line description. Hover lights the rim gold, brightens the art and lifts
## the tile 3 px; the chosen tile keeps a bright gold rim, a gold glow and a tick medallion. The
## click is the "customise_select" cue (Sfx's button hook).
class TableTile extends Button:
	const RADIUS := 7.0
	const RIM := 1.5
	const RIM_CHOSEN := 2.5
	const LIFT := 3.0
	const CAPTION_GAP := 10.0
	const NAME_PX := 17
	const BLURB_PX := 13
	const MEDAL_R := 13.0

	## The table entry (Customisation.TABLES).
	var entry: Dictionary
	## True for the table in use.
	var chosen := false:
		set(v):
			chosen = v
			_style_caption()
			queue_redraw()
	## Hover amount 0..1 (eased).
	var hover := 0.0:
		set(v):
			hover = v
			_style_caption()
			queue_redraw()
	var _thumb: Texture2D
	var _name: Label
	var _blurb: Label

	func _init(e: Dictionary, is_chosen: bool) -> void:
		entry = e
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_meta(Sfx.BUTTON_META, "customise_select")
		tooltip_text = ""
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_thumb = load(String(e.get("thumb", e["path"]))) as Texture2D
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 1)
		col.position = Vector2(0, THUMB.y + CAPTION_GAP)
		col.size = Vector2(THUMB.x, 0)
		add_child(col)
		_name = UIStyle.label(String(e["name"]), NAME_PX, UIStyle.TEXT, false, true)
		_name.name = "Name"
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_name)
		_blurb = UIStyle.label(String(e.get("blurb", "")), BLURB_PX, UIStyle.MUTED)
		_blurb.name = "Blurb"
		_blurb.add_theme_font_override("font", UIStyle.font_italic())
		_blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_blurb.custom_minimum_size.x = THUMB.x
		col.add_child(_blurb)
		# The caption's height from the font metrics (the labels have no theme before entering the tree).
		var cap_h := UIStyle.font_display(600).get_height(NAME_PX) + 1.0 + UIStyle.font_italic().get_height(BLURB_PX)
		custom_minimum_size = Vector2(THUMB.x, ceilf(THUMB.y + CAPTION_GAP + cap_h + LIFT))
		chosen = is_chosen
		mouse_entered.connect(func(): _ease_hover(1.0))
		mouse_exited.connect(func(): _ease_hover(0.0))

	func _style_caption() -> void:
		if _name == null:
			return
		_name.add_theme_color_override("font_color", UIStyle.GOLD_HI if chosen else UIStyle.TEXT.lerp(UIStyle.GOLD_HI, hover))

	func _ease_hover(to: float) -> void:
		var tw := UIStyle.restart_tween(self, &"hover_tw")
		if UIStyle.reduce_motion:
			hover = to
			tw.kill()
			return
		UIStyle.tween_token(tw, self, "hover", to, "hover" if to > hover else "hover_out")

	## The thumbnail rect (lifted by the hover, never under reduce motion).
	func thumb_rect() -> Rect2:
		var lift := 0.0 if UIStyle.reduce_motion else LIFT * hover
		return Rect2(Vector2(0, LIFT - lift), THUMB)

	func _draw() -> void:
		var r := thumb_rect()
		var gold_k := maxf(hover, 1.0 if chosen else 0.0)
		# Soft shadow under the tile (deeper while lifted) and the chosen / hover glow.
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0)
		sh.set_corner_radius_all(int(RADIUS))
		sh.shadow_color = Color(0, 0, 0, 0.55 + 0.1 * hover)
		sh.shadow_size = int(8 + 6 * hover)
		sh.shadow_offset = Vector2(0, 3 + 3 * hover)
		draw_style_box(sh, r)
		if gold_k > 0.0:
			var glow := StyleBoxFlat.new()
			glow.bg_color = Color(0, 0, 0, 0)
			glow.set_corner_radius_all(int(RADIUS))
			glow.shadow_color = Color(UIStyle.GOLD_HI, (0.42 if chosen else 0.0) + 0.26 * hover)
			glow.shadow_size = 12 if chosen else 8
			draw_style_box(glow, r)
		# The art, clipped to the rounded rect (a textured polygon).
		if _thumb != null:
			var pts := _rounded(r, RADIUS)
			var uvs := PackedVector2Array()
			for p in pts:
				uvs.append((p - r.position) / r.size)
			var tint := Color(1, 1, 1).lerp(Color(1.1, 1.08, 1.04), hover)
			if not chosen:
				tint = tint * Color(0.86, 0.86, 0.86) + Color(0.14, 0.14, 0.14, 0) * hover
			var cols := PackedColorArray()
			cols.resize(pts.size())
			cols.fill(tint)
			draw_polygon(pts, cols, uvs, _thumb)
		# Inner bevel: a dark line inside the rim and a faint top light.
		var inner := StyleBoxFlat.new()
		inner.draw_center = false
		inner.set_corner_radius_all(int(RADIUS - 1.0))
		inner.set_border_width_all(1)
		inner.border_color = Color(0, 0, 0, 0.55)
		draw_style_box(inner, r.grow(-RIM))
		# Rim: bronze at rest, gold on hover, bright gold and thicker when chosen.
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_corner_radius_all(int(RADIUS))
		var w := RIM_CHOSEN if chosen else RIM
		rim.set_border_width_all(ceili(w))
		rim.border_color = UIStyle.GOLD_HI if chosen else UIStyle.BRONZE.lightened(0.15).lerp(UIStyle.GOLD, hover)
		rim.anti_aliasing = true
		draw_style_box(rim, r)
		if chosen:
			_draw_medal(r.position + Vector2(r.size.x - MEDAL_R - 8.0, MEDAL_R + 8.0))

	## A gold tick medallion (drawn, no glyph): dark well, gold ring, gold tick.
	func _draw_medal(c: Vector2) -> void:
		draw_circle(c + Vector2(0, 1.5), MEDAL_R + 2.0, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_circle(c, MEDAL_R, Color("2a1a08"), true, -1.0, true)
		draw_circle(c, MEDAL_R - 1.0, UIStyle.GOLD, false, 2.0, true)
		draw_circle(c, MEDAL_R - 3.5, Color(UIStyle.GOLD, 0.18), true, -1.0, true)
		var a := c + Vector2(-5.5, 0.5)
		var m := c + Vector2(-1.5, 4.5)
		var b := c + Vector2(6.0, -4.5)
		draw_polyline(PackedVector2Array([a, m, b]), UIStyle.GOLD_HI, 2.6, true)

	static func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var corners := [
			[r.position + Vector2(r.size.x - rad, rad), -PI / 2.0],
			[r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],
			[r.position + Vector2(rad, r.size.y - rad), PI / 2.0],
			[r.position + Vector2(rad, rad), PI],
		]
		for c in corners:
			for i in 7:
				var ang: float = float(c[1]) + float(i) / 6.0 * PI / 2.0
				pts.append((c[0] as Vector2) + Vector2(cos(ang), sin(ang)) * rad)
		return pts


# ---------------------------------------------------------------- Card back

func _card_back_page() -> Control:
	# The showcase is centred in the page (the Table page sets the common height).
	var page := CenterContainer.new()
	page.name = "CardBackPage"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIStyle.sp("xxl"))
	page.add_child(row)
	var prev := CardBackPreview.new(BACK_SIZE, true)
	prev.name = "CardBackPreview"
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prev)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = BACK_INFO_W
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", UIStyle.sp("sm"))
	row.add_child(info)
	var back: Dictionary = Customisation.CARD_BACKS[0]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIStyle.sp("md"))
	var nm := UIStyle.label(String(back["name"]), 22, UIStyle.GOLD_HI, false, true)
	nm.name = "CardBackName"
	head.add_child(nm)
	var chip := UIStyle.chip("In use", UIStyle.GOLD, 12)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)
	info.add_child(head)
	var d := UIStyle.label(String(back["blurb"]) + ", on every face-down card, pile and deck in your games.", 15, UIStyle.TEXT, true)
	d.add_theme_constant_override("line_spacing", 4)
	info.add_child(d)
	info.add_child(_gap(UIStyle.sp("xs")))
	info.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.4), true, 8.0))
	info.add_child(_gap(UIStyle.sp("xs")))
	var sh := UIStyle.label("COLLECTION", 13, UIStyle.GOLD)
	info.add_child(sh)
	TitleText.apply(sh, TitleText.Tier.SECTION, 13)
	# Empty sockets where the next backs will sit: engraved card-shaped wells with a faint sigil.
	var sockets := HBoxContainer.new()
	sockets.name = "Sockets"
	sockets.add_theme_constant_override("separation", UIStyle.sp("md"))
	for i in SOCKETS:
		sockets.add_child(CardBackPreview.new(SOCKET_SIZE, false))
	info.add_child(sockets)
	var soon := UIStyle.label("More card backs are coming soon.", 14, UIStyle.MUTED, true)
	soon.name = "ComingSoon"
	soon.add_theme_font_override("font", UIStyle.font_italic())
	info.add_child(soon)
	return page


static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = h
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## A card back of the picker: the back in use, drawn by CardBack itself (the same art as every
## face-down card) with a gold rim, a soft gold glow and a tick medallion; or, with `filled` off, an
## empty socket for a back still to come (an engraved card-shaped well and a faint diamond).
class CardBackPreview extends Control:
	const RADIUS := 9
	var filled := true

	func _init(sz: Vector2 = BACK_SIZE, p_filled: bool = true) -> void:
		custom_minimum_size = sz
		filled = p_filled
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := maxi(4, roundi(RADIUS * size.x / BACK_SIZE.x))
		if not filled:
			var well := StyleBoxFlat.new()
			well.bg_color = Color(0, 0, 0, 0.35)
			well.set_corner_radius_all(rad)
			well.set_border_width_all(1)
			well.border_color = Color(UIStyle.BRONZE, 0.55)
			draw_style_box(well, r)
			draw_line(r.position + Vector2(rad, 1.5), Vector2(r.end.x - rad, r.position.y + 1.5), Color(0, 0, 0, 0.5), 1.0)
			var c := r.get_center()
			var k := size.x * 0.13
			var dia := PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, 0), c + Vector2(0, k), c + Vector2(-k, 0), c + Vector2(0, -k)])
			draw_polyline(dia, Color(UIStyle.GOLD, 0.28), 1.2, true)
			return
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0, 0, 0, 0)
		glow.set_corner_radius_all(rad)
		glow.shadow_color = Color(UIStyle.GOLD_HI, 0.38)
		glow.shadow_size = 12
		draw_style_box(glow, r)
		var b := StyleBoxFlat.new()
		b.bg_color = CardBack.BODY
		b.border_color = CardBack.BORDER
		b.set_border_width_all(3)
		b.set_corner_radius_all(rad)
		b.shadow_color = Color(0, 0, 0, 0.5)
		b.shadow_size = 8
		b.shadow_offset = Vector2(0, 4)
		draw_style_box(b, r)
		CardBack.draw_art(self, r, r.size.x / 90.0)
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_corner_radius_all(rad + 2)
		rim.set_border_width_all(2)
		rim.border_color = Color(UIStyle.GOLD_HI, 0.95)
		draw_style_box(rim, r.grow(3.0))
		# The "in use" tick medallion, as on the chosen table.
		var mc := Vector2(r.end.x - 4.0, r.position.y + 4.0)
		draw_circle(mc + Vector2(0, 1.5), 15.0, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_circle(mc, 13.0, Color("2a1a08"), true, -1.0, true)
		draw_circle(mc, 12.0, UIStyle.GOLD, false, 2.0, true)
		draw_circle(mc, 9.5, Color(UIStyle.GOLD, 0.18), true, -1.0, true)
		draw_polyline(PackedVector2Array([mc + Vector2(-5.5, 0.5), mc + Vector2(-1.5, 4.5), mc + Vector2(6.0, -4.5)]), UIStyle.GOLD_HI, 2.6, true)
