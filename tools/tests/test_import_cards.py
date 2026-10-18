"""Import regressions for the card database migrations (2026-10-17, 2026-10-18).

Run from the repo root:  python -I -m unittest discover -s tools/tests -v
"""
import json
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import import_cards as ic  # noqa: E402

# The twenty IDs whose `condition` cell is the editorial literal `temp` (2026-10-17 and 2026-10-18).
# The first 18 October export: still the old layout (temp cells, ambiguous Arcane wording).
FIRST_18 = "RLDB Master - Card Database (2026-10-18).csv"
TEMP_IDS = {6, 9, 15, 25, 30, 32, 34, 35, 36, 37, 39, 69, 72, 76, 78, 100, 162, 156, 62, 63}


class ImportRegressionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = ic.build()
        cls.by_id = {c["id"]: c for c in cls.data["cards"]}

    def test_reads_the_dated_source_with_the_pinned_hash(self):
        path = os.path.join(ic.SRC, ic.CARD_SOURCE)
        self.assertEqual(ic.sha256(path), ic.CARD_SOURCE_SHA256)
        self.assertNotIn(ic.CARD_SOURCE, ic.PREVIOUS_SOURCES)
        for old in ic.PREVIOUS_SOURCES:
            self.assertTrue(os.path.exists(os.path.join(ic.SRC, old)), old)
        for c in self.data["cards"]:
            self.assertEqual(c["source"]["file"], ic.CARD_SOURCE)

    def test_temp_conditions_are_stripped_and_kept_as_provenance(self):
        # The standardised export dropped the editorial `temp` cells; an export that still carries
        # them (the 2026-10-17 / first 2026-10-18 layout) is stripped with provenance kept.
        for c in self.data["cards"]:
            self.assertNotEqual(c["condition"].strip().lower(), "temp", c["id"])
        old = {c["id"]: c for c in ic.build(os.path.join(ic.SRC, FIRST_18))["cards"]}
        for cid in TEMP_IDS:
            self.assertEqual(old[cid]["condition"], "", cid)
            self.assertEqual(old[cid]["source"]["raw"]["condition"], "temp", cid)

    def test_populated_summon_fields_are_not_duplicated(self):
        self.assertEqual(self.by_id[63]["on_summon"], "Apply Reveal to all Spells/Traps.")
        self.assertEqual(self.by_id[63]["condition"], "")
        self.assertEqual(self.by_id[97]["on_summon"], "Apply 3 Cleanse to this Unit.")
        self.assertEqual(self.by_id[97]["condition"], "")
        self.assertEqual(self.by_id[97]["description"].count("Apply 3 Cleanse"), 1)
        self.assertEqual(self.by_id[63]["description"].count("Apply Reveal"), 1)

    def test_legacy_condition_move_still_handles_an_empty_summon_cell(self):
        # A source that still stores the effect in `condition` (the old layout) is moved once.
        import csv, tempfile
        src = os.path.join(ic.SRC, ic.CARD_SOURCE)
        with open(src, encoding="utf-8-sig", newline="") as fh:
            rows = list(csv.DictReader(fh))
        for r in rows:
            if r["id"] == "97":
                r["condition"], r["On Summon/Play"] = "Apply 3 Cleanse to this Unit.", ""
        tmp = tempfile.NamedTemporaryFile("w", delete=False, suffix=".csv", encoding="utf-8", newline="")
        try:
            w = csv.DictWriter(tmp, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
            tmp.close()
            c = {x["id"]: x for x in ic.build(tmp.name)["cards"]}[97]
        finally:
            os.unlink(tmp.name)
        self.assertEqual(c["on_summon"], "Apply 3 Cleanse to this Unit.")
        self.assertEqual(c["condition"], "")

    def test_unique_stable_ids(self):
        ids = [c["id"] for c in self.data["cards"]]
        self.assertEqual(len(ids), 188)
        self.assertEqual(len(set(ids)), 188)
        self.assertEqual(set(ids), set(range(1, 189)))

    def test_new_cards_of_2026_10_18(self):
        expect = {184: ("Counter Transmutation", "trap"), 185: ("Drako, Councillor of The Order", "arcane"),
                  186: ("Bronze Salaman", "ritual"), 187: ("Fence of the Marked Claw", "arcane"),
                  188: ("Necro, the Loathsome", "fusion")}
        for cid, (name, cat) in expect.items():
            self.assertEqual((self.by_id[cid]["name"], self.by_id[cid]["category"]), (name, cat), cid)
        self.assertEqual(self.by_id[184]["condition"], "If a Spell/Trap is Destroyed:")   # "Sell/Trap" typo
        self.assertEqual((self.by_id[186]["cost_kind"], self.by_id[186]["cost"]), ("ritual", 1))
        self.assertEqual((self.by_id[185]["cost"], self.by_id[187]["cost"]), (3, 1))
        self.assertIsNone(self.by_id[188]["cost"])

    def test_light_and_dark_replace_heavenly_and_necrotic(self):
        types = {c["type"] for c in self.data["cards"]}
        self.assertNotIn("Heavenly", types)
        self.assertNotIn("Necrotic", types)
        self.assertEqual(self.by_id[13]["type"], "Dark")          # Chaos Witch is no longer typeless
        self.assertEqual(self.by_id[13]["art"]["type_icon"], "Card/types/dark.png")
        self.assertEqual(self.by_id[105]["type"], "Light")
        self.assertEqual(self.by_id[61]["condition"], "Warrior Unit + Light Unit")

    def test_extra_deck_descriptions_leave_out_the_summon_requirement(self):
        for c in self.data["cards"]:
            if c["category"] in ("fusion", "ritual", "arcane") and c["condition"]:
                self.assertNotIn(c["condition"], c["description"], c["id"])

    def test_renamed_ids_follow_the_new_source_by_id(self):
        expect = {6: "Tag Team - L", 7: "Tag Team - B", 8: "Tag Team - S", 9: "Tag Team - F", 10: "Tag Team - W",
                  11: "Tag Team - J", 12: "Tag Team - X", 155: "Symbiote Spawn", 156: "Symbiote Larva",
                  157: "Symbiote Siphonophore"}
        for cid, name in expect.items():
            self.assertEqual(self.by_id[cid]["name"], name, cid)
        self.assertEqual(self.by_id[157]["name"], "Symbiote Siphonophore")
        for cid, name in {68: "Seppuku", 73: "Man's Best Friend", 49: "Trap Hole", 166: "Saboteurs' Guild",
                          179: "Tyrant's Lantern", 96: "Roma, Exile of The Order"}.items():
            self.assertEqual(self.by_id[cid]["name"], name, cid)
        names = [c["name"] for c in self.data["cards"] if c["category"] != "basic_unit"]
        self.assertEqual(len(names), len(set(names)), "a rename created a duplicate display name")

    def test_typed_special_values(self):
        self.assertEqual((self.by_id[95]["cost_kind"], self.by_id[95]["cost"]), ("ritual", 2))   # Mimic 2R
        self.assertEqual((self.by_id[183]["cost"], self.by_id[183]["atk"], self.by_id[183]["def"]), (3, 12, 20))
        self.assertEqual((self.by_id[175]["atk"], self.by_id[174]["atk"], self.by_id[174]["def"]), (26, 8, 18))
        self.assertIsNone(self.by_id[176]["def"])          # Tritu ?/? since 2026-10-18
        self.assertEqual((self.by_id[65]["atk"], self.by_id[65]["def"]), (40, 28))
        self.assertIsNone(self.by_id[96]["cost"])          # Roma ?R
        self.assertIsNone(self.by_id[95]["atk"])           # Mimic ?/?
        self.assertEqual(self.by_id[177]["type"], "")      # The Illusionist: typeless
        self.assertEqual(self.by_id[177]["atk"], 30)
        self.assertEqual(self.by_id[177]["art"]["type_icon"], "Card/types/unknown.png")
        self.assertEqual((self.by_id[9]["cost"], self.by_id[9]["def"]), (2, 22))

    def test_confirmed_corrections_survive(self):
        self.assertIn("Choose one of your opponent's Units", self.by_id[48]["on_summon"])
        self.assertNotIn("highest", self.by_id[48]["description"])
        self.assertIn("one of your Units in this Column", self.by_id[45]["condition"])
        self.assertEqual(self.by_id[1]["name"].find("("), -1)
        for cid in list(range(170, 178)) + [185, 187]:
            self.assertEqual(self.by_id[cid]["condition"], "Exhaust Units from Spent whose combined Cost equals this Unit's Cost.")
        old = {c["id"]: c for c in ic.build(os.path.join(ic.SRC, FIRST_18))["cards"]}
        self.assertEqual(old[170]["condition"], ic.ARCANE_REQUIREMENT)   # the ambiguous wording is still replaced
        # Obsolete overrides dropped: the export now carries the confirmed wording.
        self.assertEqual(self.by_id[169]["on_field"], "At the start of your turn: draw a card.")
        self.assertNotIn("raw", self.by_id[169]["source"])
        self.assertEqual(self.by_id[90]["on_field"], "Once per turn: you can apply 1 Paralyse to a Unit.")
        self.assertEqual(self.by_id[183]["on_field"], "At the start of your turn: your opponent takes -6 HP Damage.")

    def test_standardised_export_needs_no_typo_corrections(self):
        for cid in (12, 40, 73, 102, 141, 162, 184, 186, 187, 188):
            self.assertNotIn("raw", self.by_id[cid]["source"], cid)
        self.assertIn("Unit's", self.by_id[102]["on_field"])
        self.assertEqual(sorted(ic.TEXT_CORRECTIONS), [45, 47, 48, 147])
        self.assertIn("and can attack this Unit: that Unit must attack this Unit", self.by_id[147]["on_field"])

    def test_no_orphan_card_or_note(self):
        self.assertEqual(self.data["unassigned_source_notes"], [])
        for c in self.data["cards"]:
            self.assertNotIn("If your HP is lower than your opponents, double this Units ATK", c["description"])

    def test_deterministic_and_committed_output_current(self):
        a = ic.serialise(ic.build())
        b = ic.serialise(ic.build())
        self.assertEqual(a, b)
        with open(os.path.join(ic.OUT, "cards.json"), encoding="utf-8", newline="") as f:
            self.assertEqual(f.read(), a, "rldb/data/cards.json is stale; run tools/import_cards.py")
        json.loads(a)


class AdoptTest(unittest.TestCase):
    """--adopt: what it reports and what it refuses. The success path writes to the repository,
    so it is exercised by hand (design/card-database-update-2026-10-18.md), not here."""

    @classmethod
    def setUpClass(cls):
        cls.cards = ic.build()["cards"]

    def _changed(self, cid, **kw):
        out = [dict(c) for c in self.cards]
        for c in out:
            if c["id"] == cid:
                c.update(kw)
        return out

    def test_identical_data_reports_nothing(self):
        self.assertEqual(ic.report(self.cards, self.cards), [])

    def test_stat_change_is_listed_and_text_change_is_flagged(self):
        lines = ic.report(self.cards, self._changed(175, atk=30, on_field="Something new."))
        self.assertTrue(any(l.startswith("stat  175") and "atk 26 -> 30" in l for l in lines), lines)
        self.assertTrue(any(l.startswith("TEXT  175") and "check whether the behaviour changed" in l for l in lines), lines)

    def test_new_and_removed_ids_are_reported(self):
        extra = self.cards + [dict(self.cards[0], id=999, name="New Card")]
        self.assertTrue(any("NEW card 999" in l for l in ic.report(self.cards, extra)))
        fewer = [c for c in self.cards if c["id"] != 1]
        self.assertTrue(any(l.startswith("REMOVED") for l in ic.report(self.cards, fewer)))

    def test_adopting_the_active_source_does_nothing(self):
        before = open(ic.ACTIVE, encoding="utf-8").read()
        self.assertEqual(ic.adopt(os.path.join(ic.SRC, ic.CARD_SOURCE)), 0)
        self.assertEqual(open(ic.ACTIVE, encoding="utf-8").read(), before)


if __name__ == "__main__":
    unittest.main()
