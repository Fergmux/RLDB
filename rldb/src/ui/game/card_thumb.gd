class_name CardThumb
extends Control
## Signature-card art strip for deck tiles: the card's art (cover-cropped; or the kind-coloured
## radial placeholder with its glyph), a Type pip, a kind-coloured top bar and the name on a dark band.
## Hover lifts the rim to gold. Draws from the same card summary dictionaries as the card widget.

const BAND_H := 17.0
## Name size on the band and the size it may shrink to before it is condensed (H19).
const NAME_FS := 11.0
const NAME_FS_MIN := 9.0

var card: Dictionary = {}
var _hover := 0.0


func _init(c: Dictionary = {}) -> void:
	card = c
	custom_minimum_size = Vector2(70, 66)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_HELP
	tooltip_text = "%s (%s)\n%s" % [c.get("name", ""), UIStyle.CATEGORY_NAMES.get(c.get("category", ""), ""), c.get("text", "")]
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_entered.connect(func(): set_process(true))
	set_process(false)


func _process(delta: float) -> void:
	var want := 1.0 if get_global_rect().has_point(get_global_mouse_position()) and is_visible_in_tree() else 0.0
	_hover = move_toward(_hover, want, delta * 9.0)
	queue_redraw()
	if _hover == want and want == 0.0:
		set_process(false)


func _draw() -> void:
	var cat: String = String(card.get("category", "unit"))
	var kind_col: Color = UIStyle.CATEGORY_COLORS.get(cat, UIStyle.BRONZE)
	var is_unit: bool = card.get("atk") != null and card.get("race") != null
	var base: Color = UIStyle.type_color(card.get("type", "")) if is_unit else kind_col
	var r := Rect2(Vector2.ZERO, size)
	var art := Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2))
	var tex := CardArt.texture_for(card)
	if tex != null:
		# Cover-crop the square art, biased a little upward (faces sit in the upper half).
		var ts := tex.get_size()
		var src := Rect2(Vector2.ZERO, ts)
		if art.size.x / art.size.y > ts.x / ts.y:
			src.size.y = ts.x * art.size.y / art.size.x
			src.position.y = (ts.y - src.size.y) * 0.4
		else:
			src.size.x = ts.y * art.size.x / art.size.y
			src.position.x = (ts.x - src.size.x) * 0.5
		draw_texture_rect_region(tex, art, src, Color(1, 1, 1).lerp(Color(1.12, 1.12, 1.12), _hover))
	else:
		draw_texture_rect(CardArt._radial_tex(base), art, false)
		CardArt.draw_glyph(self, CardArt._glyph_kind(card), art.get_center() + Vector2(0, -BAND_H / 2.0 + 1.0), minf(art.size.x, art.size.y - BAND_H) * 0.32, Color(1, 1, 1, 0.22 + 0.12 * _hover))
	# Kind-coloured crown and name band.
	draw_rect(Rect2(art.position, Vector2(art.size.x, 3)), kind_col.lightened(0.15))
	var band := Rect2(art.position.x, art.end.y - BAND_H, art.size.x, BAND_H)
	Ornate.vgradient(self, Rect2(band.position.x, band.position.y - 8, band.size.x, 8), Color(0, 0, 0, 0), Color(0.03, 0.025, 0.02, 0.75))
	draw_rect(band, Color(0.03, 0.025, 0.02, 0.88))
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(kind_col, 0.8), 1.0)
	var font := UIStyle.font_bold()
	# H19: the whole name on one line, shrunk then condensed to fit (never ellipsised).
	var nm := String(card.get("name", ""))
	var maxw := band.size.x - 8.0
	var fit := CardTextLayout.fit_name_line(nm, maxw, NAME_FS, NAME_FS_MIN, font, 1.0)
	var fs := int(fit[0])
	var xk := float(fit[1])
	var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * xk
	var base_y := band.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	draw_set_transform(Vector2((size.x - tw) / 2.0, 0.0), 0.0, Vector2(xk, 1.0))
	draw_string(font, Vector2(0.0, base_y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.TEXT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_unit and String(card.get("type", "")) != "":
		TypeIcons.draw_pip(self, String(card["type"]), Vector2(14, 20), 8.0)
	# Rim: bronze, gold when hovered.
	draw_rect(r, UIStyle.BRONZE.lerp(UIStyle.GOLD_HI, _hover), false, 1.5 + _hover * 0.5)
