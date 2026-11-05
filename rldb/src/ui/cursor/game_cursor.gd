class_name GameCursor
extends RefCounted
## L22: the game screen's cursor modes (CursorSkin), worked out every frame from what the board is
## doing. Read-only: it never sends anything and never changes game state.
##
##   aiming a target / zone / card choice (GameTargeting.aiming)
##     over a legal option ............ target_lock (the reticle closed, lit)
##     over a card that is not one .... target_no   (the reticle barred)
##     elsewhere on the play field .... target      (the open reticle)
##   sacrifice mode (GameSacrificeMode, L5)
##     over a unit a click sacrifices . knife_hot   (the dagger glowing ember)
##     over any other card ............ deny        (the barred arrow)
##     elsewhere on the play field .... knife
##
## Over a button (outside a legal option), the sidebar, a menu or modal, or while the game is
## ending, no mode shows: buttons keep the gauntlet and panels the arrow. The mode is cleared when
## the screen leaves the tree or is hidden, so it never follows the player out of the game.

## Modes this component sets (one at a time).
const OWN_MODES := [&"target", &"target_lock", &"target_no", &"knife", &"knife_hot", &"deny"]

## The host screen.
var gs: GameScreen
## The mode this component has set (&"" = none).
var mode: StringName = &""


func _init(screen: GameScreen) -> void:
	gs = screen
	screen.tree_exiting.connect(func(): set_mode(&""))
	screen.visibility_changed.connect(func():
		if not screen.is_visible_in_tree():
			set_mode(&""))


## Works out and applies the mode for this frame (GameScreen._process calls it).
func update() -> void:
	if gs.sacrifice != null and not gs.sacrifice.changed.is_connected(_on_sacrifice_changed):
		gs.sacrifice.changed.connect(_on_sacrifice_changed)
	set_mode(want_mode())


## The mode the board asks for now (&"" for none).
func want_mode() -> StringName:
	if not gs.is_visible_in_tree() or gs.mv.is_empty() or gs.game_ending() or int(gs.mv.get("winner", -1)) != -1:
		return &""
	if gs.hover_blocked():
		return &""
	var m := gs.get_global_mouse_position()
	var aiming := gs.targeting != null and gs.targeting.aiming()
	if aiming and gs.targeting.aiming_at_target():
		return &"target_lock"     # also a legal option's own button in the prompt banner
	if not in_play_area(m) or over_button():
		return &""
	if aiming:
		return &"target_no" if card_under(m) != -1 else &"target"
	if gs.sacrifice != null and gs.sacrifice.is_active():
		var uid := card_under(m)
		if uid == -1:
			return &"knife"
		return &"knife_hot" if gs.sacrifice.would_sacrifice(uid) else &"deny"
	return &""


## Replaces this component's mode with `want` (&"" clears it).
func set_mode(want: StringName) -> void:
	if want == mode:
		return
	if mode != &"":
		CursorSkin.clear_mode(mode)
	mode = want
	if want != &"":
		CursorSkin.set_mode(want)


## True when global point `m` is on the play field (not the sidebar).
func in_play_area(m: Vector2) -> bool:
	if gs.play_area.size == Vector2.ZERO:
		return true
	var local := gs.get_global_transform().affine_inverse() * m
	return gs.play_area.has_point(local)


## True while the pointer is over a button (it keeps its own pointer).
func over_button() -> bool:
	var vp := gs.get_viewport()
	if vp == null:
		return false
	var h: Control = vp.gui_get_hovered_control()
	var depth := 0
	while h != null and depth < 3:
		if h is BaseButton:
			return true
		h = h.get_parent() as Control
		depth += 1
	return false


## The uid of the face-up card (hand or field) under global point `m`, or -1.
func card_under(m: Vector2) -> int:
	var it: Dictionary = gs.hover.items_under(m, "")
	return int(it.get("uid", -1)) if not it.is_empty() else -1


func _on_sacrifice_changed(_on: bool) -> void:
	set_mode(want_mode())
