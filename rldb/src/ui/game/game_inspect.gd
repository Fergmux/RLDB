class_name GameInspect
extends RefCounted
## Read-only inspection on the match screen (F03-01 / F03-02): right-click on a visible card opens
## the large CardInspector; right-click on one of my piles opens the near-full-screen PileBrowser.
## Nothing here selects, targets, plays or cancels anything, and nothing is sent to the game.
## Only what the redacted view already shows me can be opened: hidden/face-down cards are refused,
## and the opponent's piles (the view carries counts only) have no browser.

## Hint beside the title of every browser except Draw.
const BROWSE_HINT := "Right-click a card to read it."
const DRAW_HINT := "Shown in a random order; the real order is unchanged. Right-click a card to read it."

## The host screen this component works on.
var gs: GameScreen
## The open pile browser (null / freed when none).
var browser: PileBrowser
## Zone of the open pile browser ("" when none).
var browser_zone: String = ""


func _init(screen: GameScreen) -> void:
	gs = screen


## Hooks right-click on my own pile stacks (call after the board has been built). Left-click stays
## with the pile stack's own handler (the sidebar pile list).
func build() -> void:
	var mine: Dictionary = gs.board.piles[1]
	for zone in mine.keys():
		var ps: PileStack = mine[zone]
		var z: String = zone
		ps.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				ps.accept_event()
				open_pile(z))


## True while an inspector or a pile browser is open (the board then takes no hover or keys).
func is_open() -> bool:
	return CardInspector.open_count() > 0 or _browser_alive()


func _browser_alive() -> bool:
	return browser != null and is_instance_valid(browser) and not browser.is_queued_for_deletion()


## Opens the inspector for a card widget's card. False when that card is not inspectable (an empty
## zone, or a hidden/face-down card).
func inspect_widget(w: CardWidget) -> bool:
	return inspect_card(w.view, w.get_global_rect() if w.is_inside_tree() else Rect2())


## Opens the inspector for a visible card view. False when it is not inspectable. `from` (global
## rect) is where the card is on screen: it flies from there into the inspector (#87).
func inspect_card(c: Dictionary, from: Rect2 = Rect2()) -> bool:
	if not CardInspector.is_inspectable(c):
		return false
	gs.hover.clear()
	var parent: Node = browser if _browser_alive() else gs
	return CardInspector.open(parent, c, Callable(), from) != null


## Opens the browser for one of MY piles ("draw", "spent", "exhaust", "extra"). False when there is
## no match, or the zone is not browsable (the opponent's piles are never listed).
func open_pile(zone: String) -> bool:
	if gs.mv.is_empty() or gs.view.get("stage", "") != "game" or not zone in GameDetails.PILE_NAMES:
		return false
	if gs.fx != null:
		gs.fx.finish_all()
	gs.hover.clear()
	CardInspector.close_all()
	if _browser_alive():
		browser.close()
	browser_zone = zone
	var ps: PileStack = gs.board.piles[1].get(zone)
	var from := ps.get_global_rect().get_center() if ps != null and ps.is_inside_tree() else Vector2.INF
	browser = PileBrowser.open(gs, GameDetails.PILE_NAMES[zone], _pile_cards(zone), DRAW_HINT if zone == "draw" else BROWSE_HINT, Callable(), from)
	Sfx.play("select")
	return true


## Cards of my pile `zone` as the view lists them (Draw: the display order, not the real one).
func _pile_cards(zone: String) -> Array:
	var key := "draw_inspect" if zone == "draw" else zone
	return gs.pv(gs.me()).get(key, [])


## Esc: closes the topmost inspector, else the browser. True when something closed.
func close_top() -> bool:
	if CardInspector.close_topmost():
		return true
	if _browser_alive():
		browser.close()
		browser = null
		browser_zone = ""
		return true
	return false


## Closes everything (a new seat attached: nothing of the previous seat may stay on screen).
func close_all() -> void:
	CardInspector.close_all()
	if _browser_alive():
		browser.close()
	browser = null
	browser_zone = ""


## After every new view: an open inspector shows the card's current state or closes when the card is
## no longer visible; an open browser lists the pile's current contents (scroll position kept).
func refresh() -> void:
	if _browser_alive() and (gs.mv.is_empty() or gs.view.get("stage", "") != "game"):
		close_all()
		return
	if _browser_alive():
		browser.set_cards(_pile_cards(browser_zone))
	elif browser != null:
		browser = null
		browser_zone = ""
	if CardInspector.open_count() > 0:
		CardInspector.refresh_open(func(uid: int) -> Dictionary: return gs.details.find_card(uid))
