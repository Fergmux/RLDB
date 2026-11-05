class_name CustomisationPanel
extends VBoxContainer
## Options > Customisation (owner feedback 5 Nov, L28): the player's cosmetic choices in folder-tab
## sub-sections that can grow later.
##   Table      the four tables as framed thumbnails (2 x 2) with their names. Hover lifts and
##              lights a tile; the chosen one has a gold rim, a gold glow and a tick medallion.
##              Picking saves at once (Customisation) and plays "customise_select"; the board
##              uses it from the next game.
##   Card back  (L31) a showcase: the back in use drawn large by CardBack itself (the art every
##              face-down card shows) beside its name, an "In use" chip and its blurb; under it the
##              collection, one framed tile per back with its short name, in the table tiles'
##              style (hover lift and gold rim; the back in use has a gold rim, a glow and a tick).
##              Hovering a tile previews that back in the showcase ("Preview"); clicking picks it,
##              saves it at once and plays "customise_select". It applies to every face-down card
##              on this screen from the next redraw.
## Presentation only: it reads and writes Customisation and nothing else.
##
##     panel.body.add_child(CustomisationPanel.new())

## Emitted after the player picks a table (its id).
signal table_picked(id: String)
## Emitted after the player picks a card back (its id).
signal card_back_picked(id: String)

## Sub-section keys, in tab order.
const SECTIONS := [["table", "Table"], ["card_back", "Card back"]]
## Tile thumbnail size (the art's 2967:2156 aspect) and the gaps of the 2 x 2 grid.
const THUMB := Vector2(256, 186)
const GRID_GAP := Vector2(16, 14)
## Card back showcase size (the card's 2:3 portrait) and the width of its description column; the
## collection tiles' back size and the gap between tiles.
const BACK_SIZE := Vector2(188, 282)
const BACK_INFO_W := 290.0
const TILE_BACK := Vector2(62, 93)
const TILE_GAP := 12

## The open sub-section's key.
var section: String = "table"
## The folder tabs over the sub-sections.
var tabs: FolderTabs
## The table tiles by table id.
var tiles: Dictionary = {}
## The card back tiles by back id, and the showcase's large back.
var back_tiles: Dictionary = {}
var back_preview: CardBackPreview

var _pages: Dictionary = {}
var _back_name: Label
var _back_blurb: Label
var _chip_in_use: Control
var _chip_preview: Control


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
	var page := VBoxContainer.new()
	page.name = "CardBackPage"
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", UIStyle.sp("md"))
	# The showcase: the back in use (or the hovered one) drawn large, its name, state and blurb.
	var hero := HBoxContainer.new()
	hero.name = "Showcase"
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", UIStyle.sp("xxl"))
	page.add_child(hero)
	back_preview = CardBackPreview.new(BACK_SIZE)
	back_preview.name = "CardBackPreview"
	back_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(back_preview)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = BACK_INFO_W
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", UIStyle.sp("sm"))
	hero.add_child(info)
	_back_name = UIStyle.label("", 23, UIStyle.GOLD_HI, false, true)
	_back_name.name = "CardBackName"
	info.add_child(_back_name)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", UIStyle.sp("sm"))
	_chip_in_use = UIStyle.chip("In use", UIStyle.GOLD, 12)
	_chip_in_use.name = "InUse"
	chips.add_child(_chip_in_use)
	_chip_preview = UIStyle.chip("Preview", UIStyle.MUTED, 12)
	_chip_preview.name = "Preview"
	chips.add_child(_chip_preview)
	info.add_child(chips)
	_back_blurb = UIStyle.label("", 15, UIStyle.TEXT, true)
	_back_blurb.name = "CardBackBlurb"
	_back_blurb.add_theme_constant_override("line_spacing", 4)
	info.add_child(_back_blurb)
	info.add_child(_gap(UIStyle.sp("xs")))
	info.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.4), true, 8.0))
	info.add_child(_gap(UIStyle.sp("xs")))
	var scope := UIStyle.label("Shown on every face-down card, pile and deck on your screen, yours and your opponent's alike.", 13, UIStyle.MUTED, true)
	scope.name = "CardBackScope"
	scope.add_theme_font_override("font", UIStyle.font_italic())
	scope.add_theme_constant_override("line_spacing", 3)
	info.add_child(scope)
	# The collection: one framed tile per back, in Customisation order.
	var sh := UIStyle.label("COLLECTION", 13, UIStyle.GOLD)
	page.add_child(sh)
	TitleText.apply(sh, TitleText.Tier.SECTION, 13)
	var row := HBoxContainer.new()
	row.name = "CardBackPicker"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", TILE_GAP)
	var current := Customisation.card_back_id()
	for b in Customisation.CARD_BACKS:
		var id := String(b["id"])
		var tile := BackTile.new(b, id == current)
		tile.name = "Back_" + id
		tile.pressed.connect(func(): pick_card_back(id))
		tile.mouse_entered.connect(func(): show_back(id))
		tile.mouse_exited.connect(func(): show_back(""))
		row.add_child(tile)
		back_tiles[id] = tile
	page.add_child(row)
	show_back("")
	return page


## Chooses card back `id` (saved at once), marks its tile, shows it in the showcase and emits
## `card_back_picked`. A pick of the back already in use changes nothing.
func pick_card_back(id: String) -> void:
	if id == Customisation.card_back_id() or not Customisation.set_card_back(id):
		return
	for k in back_tiles:
		(back_tiles[k] as BackTile).chosen = k == id
	show_back(id)
	card_back_picked.emit(id)


## Shows back `id` in the showcase ("" = the back in use): its art, name and blurb, and "In use"
## or "Preview" (a hovered back that is not chosen).
func show_back(id: String) -> void:
	var current := Customisation.card_back_id()
	var shown := id if Customisation.has_card_back(id) else current
	var entry := Customisation.card_back(shown)
	back_preview.back_id = shown
	back_preview.chosen = shown == current
	_back_name.text = String(entry["name"])
	_back_blurb.text = String(entry["blurb"]) + "."
	_chip_in_use.visible = shown == current
	_chip_preview.visible = shown != current


static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = h
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## Draws the framed card back `id` filling `r` on `ci`: the body and border of that back, its art
## (CardBack, the same drawing as every face-down card) and a corner radius of `rad` px.
static func draw_framed_back(ci: CanvasItem, r: Rect2, id: String, rad: int, border_w: int) -> void:
	var b := StyleBoxFlat.new()
	b.bg_color = CardBack.body_color(id)
	b.border_color = CardBack.border_color(id)
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(rad)
	b.anti_aliasing = true
	ci.draw_style_box(b, r)
	CardBack.draw_art(ci, r, r.size.x / 90.0, id)


## A gold tick medallion (drawn, no glyph) of radius `mr` at `c`: dark well, gold ring, gold tick.
static func draw_tick_medal(ci: CanvasItem, c: Vector2, mr: float) -> void:
	var k := mr / 13.0
	ci.draw_circle(c + Vector2(0, 1.5 * k), mr + 2.0 * k, Color(0, 0, 0, 0.45), true, -1.0, true)
	ci.draw_circle(c, mr, Color("2a1a08"), true, -1.0, true)
	ci.draw_circle(c, mr - 1.0 * k, UIStyle.GOLD, false, maxf(1.4, 2.0 * k), true)
	ci.draw_circle(c, mr - 3.5 * k, Color(UIStyle.GOLD, 0.18), true, -1.0, true)
	var a := c + Vector2(-5.5, 0.5) * k
	var m := c + Vector2(-1.5, 4.5) * k
	var b := c + Vector2(6.0, -4.5) * k
	ci.draw_polyline(PackedVector2Array([a, m, b]), UIStyle.GOLD_HI, maxf(1.8, 2.6 * k), true)


## The showcase's large card back: back `back_id` drawn by CardBack (the art every face-down card
## shows) under a soft drop shadow. The back in use has a bright gold rim, a gold glow and the tick
## medallion; a hovered back being previewed has a quieter bronze-gold rim and no tick.
class CardBackPreview extends Control:
	const RADIUS := 10
	## The back drawn (a CARD_BACKS id).
	var back_id := Customisation.DEFAULT_CARD_BACK:
		set(v):
			back_id = v
			queue_redraw()
	## True when the back drawn is the one in use.
	var chosen := true:
		set(v):
			chosen = v
			queue_redraw()

	func _init(sz: Vector2 = BACK_SIZE) -> void:
		custom_minimum_size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := maxi(4, roundi(RADIUS * size.x / BACK_SIZE.x))
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0)
		sh.set_corner_radius_all(rad)
		sh.shadow_color = Color(0, 0, 0, 0.6)
		sh.shadow_size = 14
		sh.shadow_offset = Vector2(0, 6)
		draw_style_box(sh, r)
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0, 0, 0, 0)
		glow.set_corner_radius_all(rad)
		glow.shadow_color = Color(UIStyle.GOLD_HI, 0.36 if chosen else 0.14)
		glow.shadow_size = 14
		draw_style_box(glow, r)
		CustomisationPanel.draw_framed_back(self, r, back_id, rad, 3)
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_corner_radius_all(rad + 2)
		rim.set_border_width_all(2)
		rim.border_color = Color(UIStyle.GOLD_HI, 0.95) if chosen else Color(UIStyle.GOLD, 0.55)
		rim.anti_aliasing = true
		draw_style_box(rim, r.grow(3.0))
		if chosen:
			CustomisationPanel.draw_tick_medal(self, Vector2(r.end.x - 4.0, r.position.y + 4.0), 13.0)


## One back of the collection: the back drawn small in its own frame, with its short name under it.
## As the table tiles: hover lifts the tile 3 px and lights its rim gold; the back in use keeps a
## bright gold rim, a gold glow and a small tick medallion. The click is the "customise_select" cue
## (Sfx's button hook).
class BackTile extends Button:
	const RADIUS := 6.0
	const LIFT := 3.0
	const CAPTION_GAP := 7.0
	const NAME_PX := 13
	const MEDAL_R := 9.0

	## The back entry (Customisation.CARD_BACKS).
	var entry: Dictionary
	## True for the back in use.
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
	var _name: Label

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
		_name = UIStyle.label(String(e.get("short", e["name"])), NAME_PX, UIStyle.TEXT, false, true)
		_name.name = "Name"
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.position = Vector2(-8.0, LIFT + TILE_BACK.y + CAPTION_GAP)
		_name.size = Vector2(TILE_BACK.x + 16.0, 0)
		add_child(_name)
		var cap_h := UIStyle.font_display(600).get_height(NAME_PX)
		custom_minimum_size = Vector2(TILE_BACK.x, ceilf(LIFT + TILE_BACK.y + CAPTION_GAP + cap_h))
		chosen = is_chosen
		mouse_entered.connect(func(): _ease_hover(1.0))
		mouse_exited.connect(func(): _ease_hover(0.0))

	func _style_caption() -> void:
		if _name == null:
			return
		_name.add_theme_color_override("font_color", UIStyle.GOLD_HI if chosen else UIStyle.MUTED.lerp(UIStyle.GOLD_HI, hover))

	func _ease_hover(to: float) -> void:
		var tw := UIStyle.restart_tween(self, &"hover_tw")
		if UIStyle.reduce_motion:
			hover = to
			tw.kill()
			return
		UIStyle.tween_token(tw, self, "hover", to, "hover" if to > hover else "hover_out")

	## The back's rect (lifted by the hover, never under reduce motion).
	func back_rect() -> Rect2:
		var lift := 0.0 if UIStyle.reduce_motion else LIFT * hover
		return Rect2(Vector2(0, LIFT - lift), TILE_BACK)

	func _draw() -> void:
		var r := back_rect()
		var rad := int(RADIUS)
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0)
		sh.set_corner_radius_all(rad)
		sh.shadow_color = Color(0, 0, 0, 0.55 + 0.1 * hover)
		sh.shadow_size = int(6 + 5 * hover)
		sh.shadow_offset = Vector2(0, 3 + 2 * hover)
		draw_style_box(sh, r)
		var gold_k := maxf(hover, 1.0 if chosen else 0.0)
		if gold_k > 0.0:
			var glow := StyleBoxFlat.new()
			glow.bg_color = Color(0, 0, 0, 0)
			glow.set_corner_radius_all(rad)
			glow.shadow_color = Color(UIStyle.GOLD_HI, (0.42 if chosen else 0.0) + 0.24 * hover)
			glow.shadow_size = 10 if chosen else 7
			draw_style_box(glow, r)
		CustomisationPanel.draw_framed_back(self, r, String(entry["id"]), rad, 2)
		if not chosen:
			# A resting tile is a shade quieter than the back in use; hover lifts the veil.
			var veil := StyleBoxFlat.new()
			veil.bg_color = Color(0, 0, 0, 0.16 * (1.0 - hover))
			veil.set_corner_radius_all(rad)
			draw_style_box(veil, r)
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_corner_radius_all(rad + 1)
		rim.set_border_width_all(2 if chosen else 1)
		rim.border_color = UIStyle.GOLD_HI if chosen else UIStyle.BRONZE.lightened(0.15).lerp(UIStyle.GOLD, hover)
		rim.anti_aliasing = true
		draw_style_box(rim, r.grow(2.0))
		if chosen:
			CustomisationPanel.draw_tick_medal(self, Vector2(r.end.x - 3.0, r.position.y + 3.0), MEDAL_R)
