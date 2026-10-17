"""Import regressions for the 2026-10-17 card database migration.

Run from the repo root:  python -I -m unittest discover -s tools/tests -v
"""
import json
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import import_cards as ic  # noqa: E402

# The twenty IDs whose `condition` cell is the editorial literal `temp` in the 2026-10-17 export.
TEMP_IDS = {6, 9, 15, 25, 30, 32, 34, 35, 36, 37, 39, 69, 72, 76, 78, 100, 162, 156, 62, 63}


class ImportRegressionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = ic.build()
        cls.by_id = {c["id"]: c for c in cls.data["cards"]}

    def test_reads_the_dated_source_with_the_pinned_hash(self):
        path = os.path.join(ic.SRC, ic.CARD_SOURCE)
        self.assertEqual(ic.sha256(path), ic.CARD_SOURCE_SHA256)
        self.assertNotEqual(ic.CARD_SOURCE, ic.BASELINE_SOURCE)
        for c in self.data["cards"]:
            self.assertEqual(c["source"]["file"], ic.CARD_SOURCE)

    def test_temp_conditions_are_stripped_and_kept_as_provenance(self):
        for cid in TEMP_IDS:
            c = self.by_id[cid]
            self.assertEqual(c["condition"], "", cid)
            self.assertEqual(c["source"]["raw"]["condition"], "temp", cid)
            for key in ("on_summon", "on_field", "on_destruction", "description"):
                self.assertNotIn("temp", c[key].lower().split(), (cid, key))
        stripped = {c["id"] for c in self.data["cards"] if c.get("source", {}).get("raw", {}).get("condition") == "temp"}
        self.assertEqual(stripped, TEMP_IDS)

    def test_populated_summon_fields_are_not_duplicated(self):
        self.assertEqual(self.by_id[63]["on_summon"], "Apply Reveal to all Spells and Traps.")
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
        self.assertEqual(len(ids), 183)
        self.assertEqual(len(set(ids)), 183)
        self.assertEqual(set(ids), set(range(1, 184)))

    def test_renamed_ids_follow_the_new_source_by_id(self):
        expect = {6: "Tag Team - L", 7: "Tag Team - B", 8: "Tag Team - S", 9: "Tag Team - F", 10: "Tag Team - W",
                  11: "Tag Team - J", 12: "Tag Team - X", 155: "Symbiote Spawn", 156: "Symbiote Larva",
                  157: "Symbiote Siphonophore"}
        for cid, name in expect.items():
            self.assertEqual(self.by_id[cid]["name"], name, cid)
        self.assertEqual(self.by_id[157]["source"]["raw"]["name"], "Symbiote Siphonophore ")
        names = [c["name"] for c in self.data["cards"] if c["category"] != "basic_unit"]
        self.assertEqual(len(names), len(set(names)), "a rename created a duplicate display name")

    def test_typed_special_values(self):
        self.assertEqual((self.by_id[95]["cost_kind"], self.by_id[95]["cost"]), ("ritual", 2))   # Mimic 2R
        self.assertEqual((self.by_id[183]["cost"], self.by_id[183]["atk"], self.by_id[183]["def"]), (3, 12, 20))
        self.assertEqual((self.by_id[65]["atk"], self.by_id[65]["def"]), (40, 28))
        self.assertIsNone(self.by_id[96]["cost"])          # Roma ?R
        self.assertIsNone(self.by_id[95]["atk"])           # Mimic ?/?
        self.assertEqual(self.by_id[177]["type"], "")      # The Illusionist: typeless
        self.assertEqual(self.by_id[177]["atk"], 30)
        self.assertEqual(self.by_id[177]["art"]["type_icon"], "Card/types/unknown.png")
        self.assertEqual((self.by_id[9]["cost"], self.by_id[9]["def"]), (2, 22))

    def test_confirmed_corrections_survive(self):
        self.assertIn("Choose an opponent's Unit", self.by_id[48]["on_summon"])
        self.assertNotIn("highest", self.by_id[48]["description"])
        self.assertIn("one of your units in this Column", self.by_id[45]["condition"])
        self.assertIn("additional", self.by_id[169]["on_field"])
        self.assertEqual(self.by_id[1]["name"].find("("), -1)
        for cid in range(170, 178):
            self.assertEqual(self.by_id[cid]["condition"], ic.ARCANE_REQUIREMENT)
        # Obsolete overrides dropped: the export now carries the confirmed wording.
        self.assertEqual(self.by_id[90]["on_field"], "Once per turn: you can Apply 1 Paralyse to a Unit.")
        self.assertEqual(self.by_id[183]["on_field"], "At the start of your turn: your opponent loses -6 HP.")

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


if __name__ == "__main__":
    unittest.main()
