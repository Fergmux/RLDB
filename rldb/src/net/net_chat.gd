class_name NetChat
extends RefCounted
## A1 in-game chat rules, shared by the host (the authority that relays) and every client (which
## checks before sending, so a player is told at once). Chat is peer-to-peer only: it never reaches
## telemetry, statistics, saves or any log on disk.
##
## Text is cleaned to plain text: BBCode-style tags are removed, control characters and runs of
## whitespace become one space, and the result is capped at MAX_LEN characters. The chat box also
## renders text with RichTextLabel.add_text (never parsed), so markup cannot be injected even if a
## modified host relayed it.

## Longest message, in characters (after cleaning).
const MAX_LEN := 200
## Longest sender name shown in chat (Steam persona names are up to 32 characters).
const MAX_NAME := 24
## Rate limit: at most BURST messages in any WINDOW_MS, and never two within MIN_GAP_MS.
const BURST := 5
const WINDOW_MS := 8000
const MIN_GAP_MS := 300
## Messages kept in the chat history of a session (memory only).
const HISTORY := 120
## Player-facing refusal when a sender is rate limited.
const SLOW_DOWN := "You are sending messages too quickly. Wait a moment."

static var _tag_re: RegEx


## `text` as one line of plain chat text (tags and control characters removed, capped), or "".
static func sanitize(text: String) -> String:
	if _tag_re == null:
		_tag_re = RegEx.create_from_string("\\[[^\\[\\]]{0,64}\\]")
	var s := text
	# Remove tag-like spans repeatedly so nested tricks ("[[b]b]") cannot rebuild a tag.
	for i in 4:
		var t := _tag_re.sub(s, "", true)
		if t == s:
			break
		s = t
	s = s.replace("[", "(").replace("]", ")")
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		out += " " if (c < 32 or c == 127 or (c >= 0x200B and c <= 0x200F) or c == 0x2028 or c == 0x2029) else ch
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges()
	if out.length() > MAX_LEN:
		out = out.substr(0, MAX_LEN).strip_edges()
	return out


## A sender name cleaned like a message, capped at MAX_NAME; "Player" when nothing is left.
static func clean_name(n: String) -> String:
	var s := sanitize(n)
	if s.length() > MAX_NAME:
		s = s.substr(0, MAX_NAME).strip_edges()
	return s if s != "" else "Player"


## Per-sender sliding-window rate limit (host side, keyed by peer; the client keeps its own).
class Guard:
	extends RefCounted
	var _sent: Dictionary = {}   # key -> Array of msec stamps inside the window

	## True (and records the message) when `key` may send at time `now_ms`.
	func allow(key: Variant, now_ms: int) -> bool:
		var times: Array = _sent.get(key, [])
		times = times.filter(func(t): return now_ms - int(t) < NetChat.WINDOW_MS)
		if not times.is_empty() and now_ms - int(times[-1]) < NetChat.MIN_GAP_MS:
			_sent[key] = times
			return false
		if times.size() >= NetChat.BURST:
			_sent[key] = times
			return false
		times.append(now_ms)
		_sent[key] = times
		return true

	## Forgets `key` (a sender left).
	func forget(key: Variant) -> void:
		_sent.erase(key)
