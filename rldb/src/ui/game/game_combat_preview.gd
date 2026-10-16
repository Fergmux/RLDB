class_name GameCombatPreview
extends RefCounted
## F02-12 combat preview. While I choose an attack target, the target under the pointer shows
## the values the battle would compare (type advantage applied by the authority) on both cards,
## a verdict-coloured arrow and an outcome line in the banner. Presentation only: nothing is
## sent or changed.

var gs: GameScreen
## Widgets currently showing a preview.
var ws: Array = []
## Full outcome line ("" while nothing is previewed).
var text: String = ""
## Target name shown in the banner while previewing.
var target: String = ""
## "good", "bad", "neutral" or "".
var verdict: String = ""
var _opt: int = -2   # option whose preview is shown


func _init(screen: GameScreen) -> void:
	gs = screen


## Drops the current preview and forgets which option it was for.
func reset() -> void:
	_opt = -2
	clear()


## Follows the pointer over attack targets (called every frame).
func update() -> void:
	var pd := gs.pending()
	var opt := -2
	if not pd.is_empty() and pd.get("mine", false) and pd.get("kind", "") == "attack_target" and not gs.overlays.overlay.visible:
		opt = gs.targeting.option_under_pointer()
	if opt == _opt:
		return
	clear()
	_opt = opt
	var o := {}
	for oo in pd.get("options", []):
		if oo["i"] == opt:
			o = oo
	var pv: Dictionary = o.get("preview", {})
	if pv.is_empty():
		gs.prompt.update_banner_sub()
		return
	var src := gs.selection.item_for_uid(gs.targeting.source_uid())
	var src_name := ""
	if not src.is_empty():
		var aw: CardWidget = src["w"]
		src_name = String(aw.view.get("name", ""))
		aw.set_preview("atk", int(pv["av"]), int(pv.get("bonus", 0)) if pv.get("adv", "") == "attacker" else 0)
		ws.append(aw)
	var tgt_name := "your opponent"
	if o.has("ref"):
		var tit: Dictionary = gs.fx_slot_item(o["ref"]["p"], o["ref"]["zone"], o["ref"]["slot"])
		if not tit.is_empty():
			var tw: CardWidget = tit["widget"]
			tgt_name = String(tw.view.get("name", "the target"))
			tw.set_preview("atk" if pv.get("defending_atk", true) else "def", int(pv["dv"]), int(pv.get("bonus", 0)) if pv.get("adv", "") == "defender" else 0)
			ws.append(tw)
	verdict = String(pv.get("verdict", "neutral"))
	text = preview_text(pv, src_name, tgt_name)
	target = "Direct attack" if not o.has("ref") else tgt_name
	gs.prompt.update_banner_sub()


## Restores every previewed widget and clears the outcome.
func clear() -> void:
	for w in ws:
		if is_instance_valid(w):
			(w as CardWidget).clear_preview()
	ws.clear()
	text = ""
	target = ""
	verdict = ""


## One-line outcome for a battle preview (also used by tests).
static func preview_text(pv: Dictionary, a_name: String, t_name: String) -> String:
	var lead: String = {"good": "Favourable", "bad": "Unfavourable", "neutral": "Even"}.get(pv.get("verdict", "neutral"), "Even")
	var parts := []
	if pv.get("outcome", "") == "direct":
		parts.append("%s: direct attack, %s loses %d HP" % [lead, t_name, int(pv.get("dmg_opp", 0))])
	else:
		var adv := ""
		if pv.get("adv", "") == "attacker":
			adv = " (+%d type advantage)" % int(pv["bonus"])
		var dadv := ""
		if pv.get("adv", "") == "defender":
			dadv = " (+%d type advantage)" % int(pv["bonus"])
		parts.append("%s: %s %d%s vs %s %s %d%s" % [lead, a_name, int(pv["av"]), adv, t_name,
			"ATK" if pv.get("defending_atk", true) else "DEF", int(pv["dv"]), dadv])
		var res := []
		match String(pv.get("outcome", "")):
			"win": res.append("%s destroyed" % t_name if pv.get("t_dies", false) else "%s survives" % t_name)
			"loss": res.append("%s destroyed" % a_name if pv.get("a_dies", false) else "%s survives" % a_name)
			"trade":
				if pv.get("a_dies", false) and pv.get("t_dies", false):
					res.append("both destroyed")
				else:
					res.append("%s destroyed" % (a_name if pv.get("a_dies", false) else t_name) if (pv.get("a_dies", false) or pv.get("t_dies", false)) else "neither destroyed")
			"stalemate": res.append("no damage, nothing destroyed")
		if int(pv.get("dmg_opp", 0)) > 0:
			res.append("opponent loses %d HP" % int(pv["dmg_opp"]))
		if int(pv.get("dmg_you", 0)) > 0:
			res.append("you lose %d HP" % int(pv["dmg_you"]))
		parts.append(", ".join(res))
	for n in pv.get("notes", []):
		if not String(n).begins_with("type advantage"):
			parts.append(String(n))
	if pv.get("hidden_risk", false):
		parts[0] = parts[0].replace(lead + ":", lead + " (face-down cards may change this):")
	return " · ".join(parts)
