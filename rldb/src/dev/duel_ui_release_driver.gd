extends "res://src/dev/f02_driver.gd"
## Development-only screenshot driver for the 20 Oct 2026 duel-UI batch (D1, D2, D7, D9..D12, D14, D15).
##   godot --path rldb -- --duelui-shots=<absolute dir>
## Reuses the F02 staging and pointer helpers; each step writes a numbered screenshot into the directory.

var _long_card: int = 0


func _steps() -> void:
	_stage_extra()
	await _wait(0.4)
	await _shot("00_board")
	await _d10_empty_zone_crop()
	await _d1_scroll_cue()
	await _d12_status_words()
	await _d9_target_preview()
	await _d14_inspect()
	await _d15_pile_list()
	await _d2_summon_shrink()
	await _d11_trap_response()
	await _d7_game_over_log()


func _stage_extra() -> void:
	var best := 0
	var best_len := 0
	for c in CardDB.all():
		if CardDB.is_unit_category(String(c["category"])) and String(c["category"]) != "basic_unit":
			var n := String(MatchView.def_view(int(c["id"])).get("text", "")).length()
			if n > best_len:
				best_len = n
				best = int(c["id"])
	_long_card = _new(a, best, "hand")
	uids["spent_spell"] = _new(a, 182, "spent")
	host.broadcast()


## D10: the empty unit zone with its sword glyph, cropped and magnified.
func _d10_empty_zone_crop() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var r := _zone_rect(a, "unit", 2)
	var crop := img.get_region(Rect2i(r.position - Vector2(6, 6), r.size + Vector2(12, 12)))
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_LANCZOS)
	crop.save_png(out_dir.path_join("d10_empty_unit_zone_x4.png"))


## D1: details of a long card, scrolled to the top (cue visible), then to the bottom (cue gone).
func _d1_scroll_cue() -> void:
	# A unit under six statuses: the details panel really overflows.
	for st in ["poison", "burn", "paralyse", "curse", "medic", "nimble"]:
		m.apply_status(uids["pierce"], st, 2)
	host.broadcast()
	await _wait(0.4)
	gs.details.details_view.custom_minimum_size = Vector2(0, 900)    # forced overflow so the panel scrolls
	await _click(_slot_rect(a, "unit", 4).get_center())    # J4: the details follow a click
	await _move(Vector2(700, 520))
	await _wait(0.6)
	await _shot("d1_cue_top")
	gs.details.details_scroll.scroll_vertical = 100000
	await _wait(0.12)
	await _shot("d1_cue_fading")
	await _wait(0.6)
	await _shot("d1_cue_bottom")
	gs.details.details_scroll.scroll_vertical = 0
	await _wait(0.6)
	await _shot("d1_cue_back_at_top")
	gs.details.details_view.custom_minimum_size = Vector2.ZERO
	gs.selection.deselect()
	await _move(Vector2(700, 520))
	await _wait(0.4)


## D12: highlighted status words in the details panel, on a card, in the log; and the tooltip.
func _d12_status_words() -> void:
	await _click(_slot_rect(a, "unit", 4).get_center())    # J4: the details follow a click
	await _move(Vector2(700, 520))
	await _wait(0.6)
	await _shot("d12_details_status_word")
	var lbl := _find_label(gs.details.details_view, "Pierce")
	if lbl != null:
		var i := lbl.text.find("Pierce")
		var r := lbl.get_character_bounds(i + 2)
		await _move(lbl.get_global_transform_with_canvas() * r.get_center())
		await _wait(0.5)
		await _shot("d12_status_tooltip")
	# Pointer on the big card text of a hovered hand card.
	gs.selection.deselect()
	await _move(_hand_rect(uids["h_anduras"]).get_center())
	await _wait(0.6)
	await _shot("d12_hand_card_text")


## D9: select the Pierce unit and hover its effect button.
func _d9_target_preview() -> void:
	await _click(_slot_rect(a, "unit", 4).get_center())
	await _wait(0.5)
	await _shot("d9_before_hover")
	if gs.action_row.stack != null:
		for b in gs.action_row.stack.get_children():
			if (b as Button).text == "Apply Pierce":
				await _move((b as Control).get_global_rect().get_center())
				await _wait(0.5)
				await _shot("d9_hover_preview")
				break
	await _move(Vector2(700, 520))
	await _wait(0.4)
	await _shot("d9_after_leave")
	await _key(KEY_ESCAPE)
	gs.selection.deselect()
	await _wait(0.3)


## D14: inspect a Spell (no stats section), a Trap and a unit.
func _d14_inspect() -> void:
	gs.hover.clear()
	for id in [182, 46, 1]:
		var d := CardDB.get_def(id)
		var v := MatchView.summary_view({"id": id, "name": d["name"], "category": d["category"], "cost_text": CardDB.cost_label(d),
			"race": "", "type": "", "atk": null, "def": null, "text": "", "support": "full"}) if id != 1 else MatchView.def_view(id)
		if id != 1:
			v = MatchView.def_view(id)
			v.erase("race")
			v["race"] = ""
			v["type"] = ""
		CardInspector.open(gs, v)
		await _wait(0.5)
		await _shot("d14_inspect_%d" % id)
		CardInspector.close_all()
		await _wait(0.2)


## D15: the Spent pile list, a row hovered (tooltip) and the right-click inspector.
func _d15_pile_list() -> void:
	gs.details.show_pile("spent")
	await _wait(0.4)
	var row := gs.details.pile_row(uids["spent0"])
	if row != null:
		await _move(row.get_global_rect().get_center())
		await _wait(1.4)
		await _shot("d15_pile_row_tooltip")
	gs.details.close_pile()
	await _wait(0.3)
	await _move(Vector2(700, 520))


## D2: choose Summon on a hand card; it should shrink straight away so the trap zones stay visible.
func _d2_summon_shrink() -> void:
	await _click(_hand_rect(uids["h_water"]).get_center())
	await _wait(0.4)
	await _shot("d2_selected_row")
	await _click_row("Summon")
	await _wait(0.1)
	await _shot("d2_just_after_choice")
	await _move(_hand_rect(uids["h_water"]).get_center())
	await _wait(0.5)
	await _shot("d2_zone_choice_pointer_on_card")
	await _click(_zone_rect(a, "unit", 3).get_center())
	await _wait(0.8)


## D11: a Trap response for the seat holding the set Trap: the pane shows it face up with its effect tooltip.
func _d11_trap_response() -> void:
	m.submit(m.active, {"t": "next_phase"})
	await _wait(0.3)
	m.submit(m.active, {"t": "attack", "uid": uids["fire"]})
	if m.pending.get("kind", "") == "attack_target":
		var opts: Array = m.pending["options"]
		for i in opts.size():
			if String(opts[i]["label"]).contains("Basic Mage"):
				host.handle(a, {"t": "choose", "id": m.pending["id"], "indices": [i]})
				break
	host.broadcast()
	_view_seat(o)
	await _wait(0.8)
	await _shot("d11_trap_response_pane")
	for w in _all_card_widgets(gs.prompt.ctx_banner):
		if bool(w.view.get("face_up", true)) == false:
			_check("D11 no face-down card in the pane", false, str(w.view.get("name", "")))
	var resp := _all_card_widgets(gs.prompt.respond_col)
	if not resp.is_empty():
		await _move((resp[0] as Control).get_global_rect().get_center())
		await _wait(1.4)
		await _shot("d11_pane_card_tooltip")
	_view_seat(a)
	await _wait(0.3)


## D7: end the game; the log's last entry reads "<player> Wins".
func _d7_game_over_log() -> void:
	await _move(Vector2(700, 520))
	m.end_game(a, "%s reached 0 HP" % m.pname(o))
	host.broadcast()
	await _wait(0.5)
	await _shot("d7_game_over_log")


# ---------------------------------------------------------------- helpers

func _find_label(n: Node, needle: String) -> Label:
	if n is Label and (n as Label).text.contains(needle) and (n as Label).is_visible_in_tree():
		return n
	for c in n.get_children():
		var f := _find_label(c, needle)
		if f != null:
			return f
	return null


func _all_card_widgets(n: Node) -> Array:
	var out := []
	if n is CardWidget:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_card_widgets(c))
	return out
