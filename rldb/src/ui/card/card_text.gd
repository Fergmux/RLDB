class_name CardText
extends RefCounted
## Card rules text as shown to the player: the printed card-face text and the hover tooltip.

## Default tooltip wrap width in characters.
const TOOLTIP_WIDTH := 58


## Hover tooltip: the name, then the card text wrapped to a comfortable reading width.
static func tooltip_for(v: Dictionary, width: int = TOOLTIP_WIDTH) -> String:
	var out := PackedStringArray([String(v.get("name", ""))])
	for para in card_text(v).split("\n"):
		var line := ""
		for word in para.split(" ", false):
			if line != "" and line.length() + 1 + word.length() > width:
				out.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		if line != "":
			out.append(line)
	return "\n".join(out)


## Rules text as printed on the card face: timing captions kept ("On Summon: …") except the
## "On Field:" one, which is implied for a card on the field (user feedback 2026-10-16).
static func card_text(v: Dictionary) -> String:
	var parts: Array = v.get("text_parts", [])
	if parts.is_empty():
		return String(v.get("text", "")).replace("On Field: ", "")
	var lines := []
	for p in parts:
		var k := String(p.get("k", ""))
		lines.append(String(p.get("t", "")) if k == "On Field" or k == "" else "%s: %s" % [k, p.get("t", "")])
	return "\n".join(lines)
