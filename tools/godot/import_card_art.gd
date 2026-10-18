extends SceneTree
## Imports accepted card art into the game: every "<id> - <name>.png" in the source folder becomes
## rldb/assets/art/cards/<id>.webp, resized to ART_PX square (Lanczos) and saved as lossy WebP.
## The card id is the only link between an image and its card (CardArt.path_for), so renaming a
## card never breaks its art. Ids missing from the card database, duplicate ids and non-square
## sources are reported and fail the run; cards without art are listed (they keep the placeholder).
##
## Run from the repo root (headless is fine):
##   godot --headless --path rldb -s ../tools/godot/import_card_art.gd -- "<source folder>" [--force]
## Without --force an existing .webp newer than its source is kept. Then run
##   godot --headless --path rldb --import
## so Godot generates the .import files (mipmaps on, see rldb/assets/art/cards/*.import).

## Edge length (px) of the imported square art: sharp on the 4K inspector card, ~85 KB a file.
const ART_PX := 768
## Lossy WebP quality (0..1).
const QUALITY := 0.9
const DEST := "res://assets/art/cards/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <source folder> [--force]")
		quit(2)
		return
	var src: String = args[0]
	var force := "--force" in args
	var ids := {}
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))["cards"]:
		ids[int(c["id"])] = String(c["name"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	var dir := DirAccess.open(src)
	if dir == null:
		printerr("cannot open ", src)
		quit(2)
		return
	var seen := {}
	var errors := 0
	var written := 0
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not String(f).to_lower().ends_with(".png"):
			continue
		var head := String(f).split(" - ", false, 1)[0].strip_edges()
		if not head.is_valid_int():
			printerr("no card id at the start of: ", f)
			errors += 1
			continue
		var id := int(head)
		if not ids.has(id):
			printerr("card id %d is not in the card database: %s" % [id, f])
			errors += 1
			continue
		if seen.has(id):
			printerr("two images for card %d: %s and %s" % [id, seen[id], f])
			errors += 1
			continue
		seen[id] = f
		var in_path := src.path_join(f)
		var out_path := ProjectSettings.globalize_path(DEST + "%d.webp" % id)
		if not force and FileAccess.file_exists(out_path) and FileAccess.get_modified_time(out_path) >= FileAccess.get_modified_time(in_path):
			continue
		var img := Image.load_from_file(in_path)
		if img == null or img.is_empty():
			printerr("cannot read ", f)
			errors += 1
			continue
		if img.get_width() != img.get_height():
			printerr("art must be square (%dx%d): %s" % [img.get_width(), img.get_height(), f])
			errors += 1
			continue
		img.convert(Image.FORMAT_RGB8)   # card art is opaque
		img.resize(ART_PX, ART_PX, Image.INTERPOLATE_LANCZOS)
		if img.save_webp(out_path, true, QUALITY) != OK:
			printerr("cannot write ", out_path)
			errors += 1
			continue
		written += 1
	var missing := []
	for id in ids:
		if not seen.has(id):
			missing.append(id)
	missing.sort()
	print("card art: %d images, %d written, %d cards without art %s, %d errors" % [seen.size(), written, missing.size(), str(missing) if not missing.is_empty() else "", errors])
	quit(1 if errors else 0)
