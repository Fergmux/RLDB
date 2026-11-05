class_name PageHeader
extends VBoxContainer
## Page header bar of the full-page screens (design review #73, D3/D5): a SCREEN-tier title
## (TitleText, 36 px, one sweep when the page opens) with the house divider 12 px under it, and the
## Back button (a standard 44 px secondary "‹ Back") vertically centred on the title at the right.
## Shared by the card catalogue and the deck builder; the page keeps UIStyle.SAFE_PAGE around it.
##
##     var head := PageHeader.new("Card Catalogue")
##     head.back_pressed.connect(_on_back)
##     root.add_child(head)

## The Back button was pressed.
signal back_pressed

## Title size (px at 1600x900).
const TITLE_SIZE := 36
## Back button width.
const BACK_W := 132.0

## The title (TitleText, SCREEN tier).
var title: TitleText
## The Back button.
var back: Button
## The divider under the title row.
var rule: Ornate.Rule


func _init(text: String) -> void:
	name = "PageHeader"
	add_theme_constant_override("separation", UIStyle.sp("md"))
	var row := HBoxContainer.new()
	row.name = "Row"
	UIStyle.pad(row, "lg")
	add_child(row)
	title = TitleText.make(text.to_upper(), TitleText.Tier.SCREEN, TITLE_SIZE)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	back = UIStyle.size_button(UIStyle.secondary_button("‹  Back", 16), "standard")
	back.name = "Back"
	back.custom_minimum_size.x = BACK_W
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.tooltip_text = "Back to the main menu"
	back.pressed.connect(back_pressed.emit)
	row.add_child(back)
	rule = Ornate.Rule.new(Color(UIStyle.GOLD, 0.6), true, 12.0)
	rule.name = "Rule"
	add_child(rule)


func _ready() -> void:
	title.play_sweep()
