class_name CardListScreen
extends Control
## "Card list" screen of the Decks menu: every card in the database as a big card widget, with
## a header counting the cards by implementation support status. Emits `closed` on Back.

signal closed

const MARGIN := 16
const GRID_GAP := 6


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := UIStyle.full_rect_margin(MARGIN)
	add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UIStyle.label("All %d cards · support: %s" % [CardDB.all().size(), str(support_counts())], 18, UIStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back := UIStyle.button("Back", 14)
	back.pressed.connect(closed.emit)
	head.add_child(back)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", GRID_GAP)
	flow.add_theme_constant_override("v_separation", GRID_GAP)
	sc.add_child(flow)
	for d in CardDB.all():
		flow.add_child(CardWidget.new().setup(MatchView.summary_view(Series.card_summary(d["id"])), "big"))


## Number of cards per CardScripts support status ("full", "partial", ...).
static func support_counts() -> Dictionary:
	var counts := {}
	for d in CardDB.all():
		var s := CardScripts.support_status(d["id"])
		counts[s] = counts.get(s, 0) + 1
	return counts
