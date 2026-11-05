class_name EvolvePreview
extends PanelContainer
## L23 (owner feedback 2026-11-05): the card inspector's "Evolves into" section. For a card with an
## Evolve section it shows the card it evolves into: a live card preview (click it to inspect that
## card in its own inspector, so Spawn -> Larva -> Siphonophore can be walked), its name, kind line and
## rules, and the whole evolution chain with this card highlighted. Hidden for any other card.
## Display only: it reads CardDB definitions and never touches game state.

## Emitted when the preview is clicked: the definition view of the next card and the preview's
## global rect (the new inspector's card flies out of it).
signal open_requested(view: Dictionary, from: Rect2)

## Text sizes (px) of the caption, the name, the kind / rules lines and the chain.
const CAPTION_PX := 15
const NAME_PX := 21
const BODY_PX := 15
const CHAIN_PX := 14
## The preview card's size (2:3) and its hover lift.
const CARD := Vector2(104, 156)
const HOVER_SCALE := 1.06

## The id shown (the card the inspected one evolves into), -1 when hidden.
var next_id: int = -1
var _card: CardWidget
var _name: Label
var _kind: Label
var _rules: Label
var _chain: RichTextLabel


func _init() -> void:
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := CardDetailsPanel.block_style(EvolveGlyph.COLOR, 0.85, UIStyle.CONTENT_FLOOR)
	sb.bg_color = Color(0.075, 0.05, 0.085, 0.92)       # a faint violet ink under the blossom colour
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(EvolveGlyph.COLOR, 0.5)
	sb.border_width_left = CardDetailsPanel.BLOCK_BAR_W
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(EvolveGlyph.new(18.0))
	var cap := UIStyle.label("EVOLVES INTO", CAPTION_PX, EvolveGlyph.COLOR)
	cap.add_theme_font_override("font", UIStyle.font_bold())
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var holder := Control.new()
	holder.custom_minimum_size = CARD * HOVER_SCALE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	_card = CardWidget.new()
	_card.auto_hover = false
	_card.show_tooltip = false
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_card.tooltip_text = ""
	holder.add_child(_card)
	_card.pressed.connect(func(_w): _open())
	_card.mouse_entered.connect(_hover.bind(true))
	_card.mouse_exited.connect(_hover.bind(false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name = UIStyle.label("", NAME_PX, UIStyle.GOLD_HI, true, true)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name)
	_kind = UIStyle.label("", BODY_PX - 1, UIStyle.MUTED, true)
	_kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_kind)
	_rules = UIStyle.label("", BODY_PX, UIStyle.TEXT, true)
	_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules.custom_minimum_size.x = 40.0
	col.add_child(_rules)
	var hint := UIStyle.label("Click the card to inspect it.", BODY_PX - 2, UIStyle.TEXT_DIM, true)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint)
	_chain = RichTextLabel.new()
	_chain.bbcode_enabled = true
	_chain.fit_content = true
	_chain.scroll_active = false
	_chain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain.add_theme_font_override("normal_font", UIStyle.font_body())
	_chain.add_theme_font_override("bold_font", UIStyle.font_bold())
	_chain.add_theme_font_size_override("normal_font_size", CHAIN_PX)
	_chain.add_theme_font_size_override("bold_font_size", CHAIN_PX)
	_chain.add_theme_color_override("default_color", UIStyle.TEXT_DIM)
	v.add_child(_chain)


## Shows the section for inspected card view `c`; hides it (and returns false) when the card does
## not evolve.
func show_for(c: Dictionary) -> bool:
	var id := int(c.get("id", -1)) if c.get("id") != null else -1
	next_id = CardDB.evolves_into(id) if id >= 0 else -1
	visible = next_id != -1
	if not visible:
		return false
	var nv := MatchView.def_view(next_id)
	_card.setup(nv, "mini")
	GameUi.resize_card(_card, CARD)
	_card.position = (CARD * HOVER_SCALE - CARD) / 2.0
	_name.text = String(nv["name"])
	_kind.text = StatusHelp.tip_kind_line(nv)
	_rules.text = CardText.card_text(nv)
	_chain.text = chain_text(id)
	return true


## The evolution chain of card `id` as BBCode: every form from the base card on, joined by arrows,
## with `id` itself bold in the Evolve colour ("Symbiote Spawn > [b]Symbiote Larva[/b] > ...").
static func chain_text(id: int) -> String:
	var parts := []
	var cur := CardDB.evolution_base(id)
	var guard := 0
	while cur != -1 and guard < 8:
		var nm := String(CardDB.get_def(cur)["name"])
		parts.append("[b][color=#%s]%s[/color][/b]" % [EvolveGlyph.COLOR.to_html(false), nm] if cur == id else nm)
		cur = CardDB.evolves_into(cur)
		guard += 1
	return ("[color=#%s]  ›  [/color]" % EvolveGlyph.DEEP.lightened(0.35).to_html(false)).join(parts)


## The preview card (tests and dev drivers).
func preview_card() -> CardWidget:
	return _card


func _open() -> void:
	if next_id == -1:
		return
	Sfx.play("select")
	open_requested.emit(MatchView.def_view(next_id), _card.get_global_rect())


func _hover(on: bool) -> void:
	if not is_instance_valid(_card):
		return
	var tw := _card.create_tween()
	tw.set_parallel(true)
	var glow := Color(EvolveGlyph.COLOR, 0.85 if on else 0.0)
	tw.tween_property(_card, "fx_glow", glow, UIStyle.motion("hover"))
	if not UIStyle.reduce_motion:
		tw.tween_property(_card, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), UIStyle.motion("hover")) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
