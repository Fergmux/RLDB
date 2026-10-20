class_name PreviewFacts
extends VBoxContainer
## The facts block under a card preview in the catalogue and the deck builder (design review #77,
## #80, WP-7): it fills the space under the stat boxes with what a deck-builder wants next.
##   - a Rules placeholder when the card has no rules text (a vanilla unit), so the Rules section
##     is always present: an italic dim line instead of an empty pane;
##   - "In your decks": how many copies the player's saved decks hold, across how many decks
##     (catalogue), or the "Copies in this deck" gem sockets (deck builder, CopyGems);
##   - the card's kind and cost line ("Basic Unit · 1 AP", "Fusion Unit · Fusion summon").
## Pure presentation; reads CardDB and DeckStore only.

## Sockets shown in the copies row (more copies show "+N" after them).
const SOCKETS := 3

var _rules: Control
var _usage: Label
var _kind: Label
var _gems: CopyGems


## `with_gems` adds the deck builder's copies row; otherwise the saved-deck usage line is shown.
func _init(with_gems: bool = false) -> void:
	name = "PreviewFacts"
	add_theme_constant_override("separation", UIStyle.sp("sm"))
	_rules = VBoxContainer.new()
	_rules.name = "RulesPlaceholder"
	_rules.add_theme_constant_override("separation", UIStyle.sp("xs"))
	add_child(_rules)
	_rules.add_child(section("Rules"))
	var none := UIStyle.label("No rules text. This card fights with its stats alone.", 14, UIStyle.TEXT_DIM, true)
	none.add_theme_font_override("font", UIStyle.font_italic())
	_rules.add_child(none)
	add_child(section("In your decks" if not with_gems else "In this deck"))
	if with_gems:
		_gems = CopyGems.new()
		add_child(_gems)
	else:
		_usage = UIStyle.label("", 14, UIStyle.MUTED, true)
		_usage.name = "Usage"
		add_child(_usage)
	_kind = UIStyle.label("", 13, UIStyle.TEXT_DIM, true)
	_kind.name = "Kind"
	add_child(_kind)


## A SECTION-tier header (TitleText) at 14 px with its engraved underline.
static func section(text: String) -> Label:
	var l := UIStyle.label(text.to_upper(), 14, UIStyle.GOLD)
	TitleText.apply(l, TitleText.Tier.SECTION, 14)
	return l


## Shows the facts of card `id`; `has_rules` hides the Rules placeholder (the details panel shows
## the rules), `copies` is the count in the working deck (deck builder).
func show_card(id: int, has_rules: bool, copies: int = 0) -> void:
	_rules.visible = not has_rules
	if _usage != null:
		_usage.text = usage_text(id, DeckStore.list())
	if _gems != null:
		_gems.set_count(copies)
	_kind.text = kind_text(CardDB.get_def(id) if CardDB.has(id) else {})


## Copies of the card shown in this deck now (deck builder; -1 without the gem row).
func copies_shown() -> int:
	return _gems.count if _gems != null else -1


## "In your decks" line for card `id` over saved decks `decks` ([{name, cards}]).
static func usage_text(id: int, decks: Array) -> String:
	var copies := 0
	var in_decks := 0
	for d in decks:
		var n := 0
		for c in d.get("cards", []):
			if int(c) == id:
				n += 1
		if n > 0:
			in_decks += 1
			copies += n
	if in_decks == 0:
		return "Not in any of your saved decks yet." if not decks.is_empty() else "You have no saved decks yet."
	return "×%d across %d saved deck%s." % [copies, in_decks, "" if in_decks == 1 else "s"]


## The kind and cost line of card def `d` ("Basic Unit · 1 AP").
static func kind_text(d: Dictionary) -> String:
	if d.is_empty():
		return ""
	var kind := String(UIStyle.CATEGORY_NAMES.get(d.get("category", ""), "Card"))
	var ck := String(d.get("cost_kind", ""))
	var cost := ""
	match ck:
		"ap":
			cost = "%d AP" % int(d["cost"]) if d.get("cost") != null else "X AP"
		"fusion", "ritual", "arcane":
			cost = "%s summon" % ck.capitalize()
	return kind + ("  ·  " + cost if cost != "" else "")


## Copies-in-deck gem sockets: SOCKETS bronze sockets that fill with gold gems as copies are added
## ("+N" after them beyond SOCKETS). A gem pops in when the count rises (static under reduce motion).
class CopyGems extends HBoxContainer:
	var count: int = 0
	var _row: PreviewFacts.GemRow
	var _more: Label

	func _init() -> void:
		name = "CopyGems"
		add_theme_constant_override("separation", UIStyle.sp("sm"))
		_row = PreviewFacts.GemRow.new()
		add_child(_row)
		_more = UIStyle.label("", 14, UIStyle.GOLD_HI)
		_more.add_theme_font_override("font", UIStyle.font_display(700))
		_more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_more)

	## Shows `n` copies.
	func set_count(n: int) -> void:
		var rising := n > count
		count = n
		_row.filled = mini(n, PreviewFacts.SOCKETS)
		_more.text = "+%d" % (n - PreviewFacts.SOCKETS) if n > PreviewFacts.SOCKETS else ""
		_row.pop_at = mini(n, PreviewFacts.SOCKETS) - 1 if rising else -1
		_row.restart()


class GemRow extends Control:
	const GEM := 18.0
	const GAP := 8.0
	var filled: int = 0
	var pop_at: int = -1
	var pop: float = 1.0:
		set(v):
			pop = v
			queue_redraw()
	var _tw: Tween

	func _init() -> void:
		custom_minimum_size = Vector2(PreviewFacts.SOCKETS * GEM + (PreviewFacts.SOCKETS - 1) * GAP, GEM + 4.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func restart() -> void:
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if pop_at < 0 or UIStyle.reduce_motion or not is_inside_tree():
			pop = 1.0
			return
		pop = 0.0
		_tw = create_tween()
		_tw.tween_property(self, "pop", 1.0, UIStyle.dur(0.26)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		for i in PreviewFacts.SOCKETS:
			var c := Vector2(GEM / 2.0 + i * (GEM + GAP), size.y / 2.0)
			var r := GEM / 2.0
			_diamond(c, r + 1.5, Color(0, 0, 0, 0.6))
			_diamond(c, r, Color(UIStyle.BRONZE, 0.9))
			_diamond(c, r - 2.0, UIStyle.PANEL_INK)
			if i < filled:
				var k := pop if i == pop_at else 1.0
				var gr := (r - 2.5) * k
				_diamond(c, gr + 3.0 * k, Color(UIStyle.GOLD_HI, 0.18 * k))
				_diamond(c, gr, UIStyle.GOLD)
				_diamond(c + Vector2(0, -gr * 0.25), gr * 0.6, UIStyle.GOLD_HI)
				_diamond(c + Vector2(-gr * 0.3, -gr * 0.35), gr * 0.18, Color(1, 1, 1, 0.8))

	func _diamond(c: Vector2, r: float, col: Color) -> void:
		if r <= 0.0:
			return
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)
