class_name TelemetryOutbox
extends RefCounted
## Durable local queue of telemetry submissions (docs/telemetry/README.md, "Outbox").
##
## One JSON file per item in `dir`, written atomically (temp file, then rename), so a crash leaves
## either the old or the new version, never half a file. Items survive restarts with their
## original ids and timestamps; an item is deleted only after the server acknowledged it (or it
## was a duplicate). Bounded by `max_items` and `max_bytes`; when over budget items are evicted in
## this order, oldest first within each step:
##   1. low-priority ready items (sessions, profiles),
##   2. the per-event detail of completed game reports (counters, opportunities and the result
##      are kept; the report is marked `events_dropped`),
##   3. medium-priority ready items (drafts, rewards),
##   4. high-priority ready items (game reports, series results), and only then open items.
## Permanently refused items move to `dir`/quarantine with a short redacted diagnostic, capped at
## `quarantine_max` (oldest dropped). Item shape:
##   {id, kind, priority, state: "ready" | "open", created_at, updated_at, attempts, fields, body}

const PRIORITY := {"game": 3, "gclient": 3, "series": 3, "draft": 2, "reward": 2, "session": 1, "profile": 1}

var dir: String
var max_items: int
var max_bytes: int
var quarantine_max: int
## id -> item (bodies kept in memory; the queue is small and bounded).
var items: Dictionary = {}
## Counters for the developer tool and tests.
var stats := {"evicted": 0, "detail_dropped": 0, "quarantined": 0, "write_errors": 0}


func _init(p_dir: String, p_max_items: int = 400, p_max_bytes: int = 8388608, p_quarantine_max: int = 25) -> void:
	dir = p_dir
	max_items = p_max_items
	max_bytes = p_max_bytes
	quarantine_max = p_quarantine_max


## Loads every stored item; stray temp files from an interrupted write are removed, unreadable
## files are moved to quarantine.
func load_all() -> void:
	items.clear()
	DirAccess.make_dir_recursive_absolute(dir)
	var da := DirAccess.open(dir)
	if da == null:
		return
	for fn in da.get_files():
		var path := dir.path_join(fn)
		if fn.ends_with(".tmp"):
			DirAccess.remove_absolute(path)
			continue
		if fn.ends_with(".json.bak"):
			var orig := path.trim_suffix(".bak")
			if FileAccess.file_exists(orig):
				DirAccess.remove_absolute(path)
			else:
				DirAccess.rename_absolute(path, orig)
	da = DirAccess.open(dir)
	for fn in da.get_files():
		var path := dir.path_join(fn)
		if not fn.ends_with(".json"):
			continue
		var it = JSON.parse_string(FileAccess.get_file_as_string(path))
		if it is Dictionary and it.has("id") and it.has("fields") and String(it["id"]) + ".json" == fn:
			it["priority"] = int(it.get("priority", 1))
			it["attempts"] = int(it.get("attempts", 0))
			items[String(it["id"])] = it
		else:
			_quarantine_file(path, fn, "unreadable outbox file")


## Stores (or replaces) an item durably. Returns false when the disk write failed.
func put(item: Dictionary) -> bool:
	var it := item.duplicate(true)
	it["priority"] = int(it.get("priority", PRIORITY.get(String(it.get("kind", "")), 1)))
	it["attempts"] = int(it.get("attempts", 0))
	if not it.has("state"):
		it["state"] = "ready"
	if not _write(it):
		stats["write_errors"] += 1
		return false
	items[String(it["id"])] = it
	enforce_budget()
	return true


func has(id: String) -> bool:
	return items.has(id)


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


## Number of items (ready + open).
func size() -> int:
	return items.size()


## Bytes currently used on disk (approximate: serialized item sizes).
func bytes_used() -> int:
	var n := 0
	for id in items:
		n += _size_of(items[id])
	return n


## The next item to upload: highest priority, then oldest; never an open item.
func next_ready() -> Dictionary:
	var best: Dictionary = {}
	for id in items:
		var it: Dictionary = items[id]
		if it["state"] != "ready":
			continue
		if best.is_empty() or it["priority"] > best["priority"] or (it["priority"] == best["priority"] and int(it["created_at"]) < int(best["created_at"])):
			best = it
	return best


## Records a failed attempt (kept for diagnostics; the uploader owns the backoff).
func note_attempt(id: String) -> void:
	if items.has(id):
		items[id]["attempts"] += 1
		_write(items[id])


## The server accepted (or already had) the item: forget it.
func ack(id: String) -> void:
	if items.has(id):
		items.erase(id)
		DirAccess.remove_absolute(dir.path_join(id + ".json"))


## Moves a permanently refused item to quarantine with a redacted diagnostic.
func quarantine(id: String, diagnostic: String) -> void:
	if not items.has(id):
		return
	var it: Dictionary = items[id]
	items.erase(id)
	var qdir := dir.path_join("quarantine")
	DirAccess.make_dir_recursive_absolute(qdir)
	var q := {"id": id, "kind": it.get("kind", ""), "created_at": it.get("created_at", 0),
		"quarantined_at": int(Time.get_unix_time_from_system() * 1000.0),
		"diagnostic": TelemetryOutbox.redact(diagnostic), "item": it}
	_atomic_write(qdir.path_join(id + ".json"), JSON.stringify(q))
	DirAccess.remove_absolute(dir.path_join(id + ".json"))
	stats["quarantined"] += 1
	_trim_quarantine()


## Quarantined entries (developer tool): [{id, kind, diagnostic, quarantined_at}].
func quarantined() -> Array:
	var out := []
	var qdir := dir.path_join("quarantine")
	var da := DirAccess.open(qdir)
	if da == null:
		return out
	for fn in da.get_files():
		if fn.ends_with(".json"):
			var q = JSON.parse_string(FileAccess.get_file_as_string(qdir.path_join(fn)))
			if q is Dictionary:
				out.append({"id": q.get("id", fn), "kind": q.get("kind", ""), "diagnostic": q.get("diagnostic", ""), "quarantined_at": q.get("quarantined_at", 0)})
	return out


## Deletes every queued (not yet uploaded) item and the quarantine: used when the player turns
## sharing off, and by the developer tool.
func clear_all() -> void:
	for id in items.keys():
		DirAccess.remove_absolute(dir.path_join(String(id) + ".json"))
	items.clear()
	var qdir := dir.path_join("quarantine")
	var da := DirAccess.open(qdir)
	if da != null:
		for fn in da.get_files():
			DirAccess.remove_absolute(qdir.path_join(fn))


## Applies the disk budget (see the class comment for the eviction order).
func enforce_budget() -> void:
	var guard := 0
	while (items.size() > max_items or bytes_used() > max_bytes) and guard < 10000:
		guard += 1
		if _evict_ready(1):
			continue
		if _drop_detail():
			continue
		if _evict_ready(2):
			continue
		if _evict_ready(3):
			continue
		if not _evict_any():
			break


func _evict_ready(priority: int) -> bool:
	var victim := ""
	var oldest := 0
	for id in items:
		var it: Dictionary = items[id]
		if it["state"] == "ready" and it["priority"] == priority and (victim == "" or int(it["created_at"]) < oldest):
			victim = id
			oldest = int(it["created_at"])
	if victim == "":
		return false
	ack(victim)
	stats["evicted"] += 1
	return true


## Drops the event list from the oldest game report that still has one.
func _drop_detail() -> bool:
	var victim := ""
	var oldest := 0
	for id in items:
		var it: Dictionary = items[id]
		if it.get("kind", "") == "game" and it["state"] == "ready" and not it.get("detail_dropped", false) and (victim == "" or int(it["created_at"]) < oldest):
			victim = id
			oldest = int(it["created_at"])
	if victim == "":
		return false
	var it: Dictionary = items[victim]
	var body = JSON.parse_string(String(it.get("body", "")))
	it["detail_dropped"] = true
	if body is Dictionary:
		var n: int = (body.get("events", []) as Array).size()
		body["events"] = []
		var comp: Dictionary = body.get("completeness", {})
		comp["events_dropped"] = n
		comp["events"] = false
		body["completeness"] = comp
		it["body"] = JSON.stringify(body)
	_write(it)
	stats["detail_dropped"] += 1
	return true


func _evict_any() -> bool:
	var victim := ""
	var oldest := 0
	for id in items:
		var it: Dictionary = items[id]
		if victim == "" or int(it["created_at"]) < oldest:
			victim = id
			oldest = int(it["created_at"])
	if victim == "":
		return false
	ack(victim)
	stats["evicted"] += 1
	return true


func _size_of(it: Dictionary) -> int:
	return String(it.get("body", "")).length() + 512


func _write(it: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	return _atomic_write(dir.path_join(String(it["id"]) + ".json"), JSON.stringify(it))


## Writes `text` to `path` through a temp file and a rename.
static func _atomic_write(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# Windows cannot rename onto an existing file: keep the old version as .bak until the new
	# one is in place (load_all() restores a .bak whose .json is missing).
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var ok := DirAccess.rename_absolute(tmp, path) == OK
	if ok and FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	return ok


func _quarantine_file(path: String, fn: String, why: String) -> void:
	var qdir := dir.path_join("quarantine")
	DirAccess.make_dir_recursive_absolute(qdir)
	_atomic_write(qdir.path_join(fn), JSON.stringify({"id": fn.get_basename(), "diagnostic": why,
		"quarantined_at": int(Time.get_unix_time_from_system() * 1000.0)}))
	DirAccess.remove_absolute(path)
	stats["quarantined"] += 1
	_trim_quarantine()


func _trim_quarantine() -> void:
	var qdir := dir.path_join("quarantine")
	var da := DirAccess.open(qdir)
	if da == null:
		return
	var files := Array(da.get_files()).filter(func(f): return f.ends_with(".json"))
	if files.size() <= quarantine_max:
		return
	var dated := []
	for fn in files:
		dated.append([FileAccess.get_modified_time(qdir.path_join(fn)), fn])
	dated.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i in dated.size() - quarantine_max:
		DirAccess.remove_absolute(qdir.path_join(dated[i][1]))


## Bounded, token-free diagnostic text: long base64/hex runs (tokens, keys) are masked.
static func redact(text: String, max_len: int = 300) -> String:
	var re := RegEx.create_from_string("[A-Za-z0-9_\\-\\.]{32,}")
	var out := re.sub(text, "<redacted>", true)
	return out.substr(0, max_len)
