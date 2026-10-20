class_name PreviewFacts
extends VBoxContainer
## The facts block under a card preview in the catalogue and the deck builder (design review #77,
## #80, WP-7): it fills the space under the stat boxes with what a deck-builder wants next.
##   - a Rules placeholder when the card has no rules text (a vanilla unit), so the Rules section
##     is always present: an italic dim line instead of an empty pane;
##   - "In your decks": how many copies the player's saved decks hold, across how many decks
##     (catalogue), or the "In this deck" copy gems (deck builder, CopyGems: one empty socket, or one gem per copy);
##   - the card's kind and cost line ("Basic Unit · 1 AP", "Fusion Unit · Fusion summon").
## Pure presentation; reads CardDB and DeckStore only.

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


## The copies gem row (deck builder; null without it).
func gems() -> CopyGems:
	return _gems


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


## Copies-in-deck gems (H27, owner 21 Oct: "show one empty, and fill it when one is in, and add more
## filled gems when more are added", never "+2"), in the AP gem look: ApGemRow's bronze sockets and
## faceted topaz. No copies: one empty socket waiting to be filled. N copies: N filled gems and no
## empty one. Nothing caps the copies of one card but the deck caps (DeckStore: 99 cards, 15 Extra),
## so past one row the gems shrink and wrap into up to ROWS rows inside the same ROW_H height: the
## row never grows and the details pane never has to scroll. A gem pops in when the count rises
## (static under reduce motion). Drawn only on a change (no per-frame work).
class CopyGems extends ApGemRow:
	## Most rows the gems wrap into, and the row's fixed height (one full-size AP socket).
	const ROWS := 3
	const ROW_H := SOCKET + 2.0
	## Smallest gem scale (1 = the AP gem's 20 px socket); 99 copies still fit a 240 px row at it.
	const MIN_K := 0.25
	## Copies shown.
	var count: int = 0
	var pop_at: int = -1
	var pop: float = 1.0:
		set(v):
			pop = v
			queue_redraw()
	var _tw: Tween

	func _init() -> void:
		name = "CopyGems"
		custom_minimum_size = Vector2(0, ROW_H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS   # for its tooltip

	func _ready() -> void:
		set_process(false)   # ApGemRow animates per frame; these gems only redraw on a change

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	## Sockets drawn for `n` copies: one empty socket at 0, else exactly `n` (all filled).
	static func sockets_for(n: int) -> int:
		return maxi(1, n)

	## Filled gems for `n` copies.
	static func filled_for_count(n: int) -> int:
		return maxi(0, n)

	## How `n` sockets fit `width` px: {"k": gem scale, "per_row", "rows"}. The largest scale (1.0
	## down to MIN_K) whose wrapped rows (at most ROWS) fit ROW_H.
	static func layout(n: int, width: float) -> Dictionary:
		var w := width if width > 1.0 else 240.0
		var k := 1.0
		while true:
			var per_row := maxi(1, floori((w - 2.0 + GAP * k) / ((SOCKET + GAP) * k)))
			var rows := ceili(float(maxi(1, n)) / float(per_row))
			if (rows <= ROWS and block_h(rows, k) <= ROW_H) or k <= MIN_K:
				return {"k": k, "per_row": per_row, "rows": rows}
			k = maxf(MIN_K, k - 0.05)
		return {}

	## Height (px) of `rows` rows of sockets at scale `k` (rows half a gap apart).
	static func block_h(rows: int, k: float) -> float:
		return float(rows) * SOCKET * k + float(rows - 1) * GAP * k * 0.5

	## Shows `n` copies; a rising count pops the newest gem in.
	func set_count(n: int) -> void:
		var rising := n > count
		count = maxi(0, n)
		pop_at = count - 1 if rising else -1
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if pop_at < 0 or UIStyle.reduce_motion or not is_inside_tree():
			pop = 1.0
			return
		pop = 0.0
		_tw = create_tween()
		_tw.tween_property(self, "pop", 1.0, UIStyle.dur(GAIN_T)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Centre (local px) of socket `i` of `n` in this row's current size.
	func gem_centre(i: int, n: int) -> Vector2:
		var l := layout(n, size.x)
		var k: float = l["k"]
		var per_row: int = l["per_row"]
		var top := (size.y - block_h(int(l["rows"]), k)) / 2.0
		@warning_ignore("integer_division")
		var row := i / per_row
		var col := i % per_row
		return Vector2(1.0 + SOCKET * k / 2.0 + float(col) * (SOCKET + GAP) * k,
			top + SOCKET * k / 2.0 + float(row) * (SOCKET + GAP * 0.5) * k)

	func _draw() -> void:
		var n := sockets_for(count)
		var k: float = layout(n, size.x)["k"]
		for i in n:
			var c := gem_centre(i, n)
			_draw_socket(c, k, false, true)
			if i < filled_for_count(count):
				var g := pop if i == pop_at else 1.0
				if g < 1.0:
					draw_arc(c, SOCKET * k * (0.5 + 0.45 * clampf(g, 0.0, 1.0)), 0.0, TAU, 28, Color(UIStyle.GOLD_HI, 0.75 * (1.0 - clampf(g, 0.0, 1.0))), 1.5, true)
				_draw_gem(c, GEM * k * 0.5 * clampf(g, 0.0, 1.2), 0.0, 1.0)
