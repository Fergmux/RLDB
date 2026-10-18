"""Import the RLDB source CSVs into rldb/data/*.json.

Active card source (card database update 2026-10-18, design/card-database-update-2026-10-18.md):
    rules/sources/RLDB Master - Card Database (2026-10-18).csv   (SHA-256 85bb97c9...8e73c5bc)
The 2026-10-17 snapshot and the undated `RLDB Master - Card Database.csv` are kept as comparison
history only and are never read here. No CSV is modified.

Applies only confirmed corrections (rules/06, design/decision-register-answers.md, playtest
feedback 03-06) and records every raw cell the importer changed under `source.raw`, so the
export stays auditable.

Run from the repo root:  python -I tools/import_cards.py          (regenerate)
                         python -I tools/import_cards.py --check  (exit 1 if the JSON is stale)
The output is deterministic so it can be committed and re-generated.
"""
import csv
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "rules", "sources")
OUT = os.path.join(ROOT, "rldb", "data")

CARD_SOURCE = "RLDB Master - Card Database (2026-10-18).csv"
CARD_SOURCE_SHA256 = "85bb97c947df5459ea68d0246a05a3cac643dbab975c6c1e9bbe8b007e73c5bc"
PREVIOUS_SOURCES = ["RLDB Master - Card Database (2026-10-17).csv",   # audit history only; never imported
                    "RLDB Master - Card Database.csv"]
STATUS_SOURCE = "RLDB Master - status.csv"
EXPECTED_CARDS = 188

CATEGORY_KEYS = {
    "Basic Unit": "basic_unit",
    "Unit": "unit",
    "Spell": "spell",
    "Trap": "trap",
    "Power": "power",
    "Fusion Unit": "fusion",
    "Ritual Unit": "ritual",
    "Arcane Unit": "arcane",
}

# The 2026-10-17 and 2026-10-18 exports carry a literal `temp` in twenty `condition` cells. It is editorial
# spreadsheet metadata, not a trigger (decisions.md): stripped here, kept in source.raw.
EDITORIAL_CONDITIONS = {"temp"}

# Legacy correction (file 06): IDs 63 and 97 once stored their On Summon effect in the
# `condition` column. The move is now source-aware: it happens only when the On Summon cell is
# empty and the condition is real effect text. The 2026-10-17 export populates both properly.
LEGACY_CONDITION_TO_SUMMON = {63, 97}

# Corrections audited per ID against the 2026-10-18 export. Field -> text.
# User-confirmed rule rewordings (the raw text still carries the old rule):
#   45/47 (C-03): Magic Cylinder / Damage Conversion trigger only on an attack on a unit in
#         this column (raw text still says "declares an attack in this Column").
#   48 (F03-19): Overextend's controller chooses the target; raw text still says highest ATK.
# Typos, and the export's own new house style on new rows it missed (2026-10-18 list: "Units you
# Control" for "Units from your Field", lower-case "apply" mid-sentence):
#   12/73/102/162: possessives the export's "Unit's" -> "Units" replacement broke.
#   40: "using you Control" lost its "Units". 141: sentence-initial "Your". 184: "Sell/Trap".
#   186: "Units from your Field". 187: "Apply". 188: "opponents Unit".
# Arcane councillors (172, 185, 187) keep the export's "that Unit costs -1 AP this turn".
# Dropped as obsolete (the export now carries the confirmed wording): 169 Options ("At the start
# of your turn: draw a card"), 48's condition, 90 Chains of Binding, 183 Yamata.
TEXT_CORRECTIONS = {
    12: {"on_field": "You can lose -2 AP, Summon a Unit from your Spent in this Unit's Column."},
    40: {"on_field": "You can lose -1 AP, Fusion Summon using Units you Control as Tribute."},
    45: {"condition": "If your opponent declares an attack on one of your Units in this Column:"},
    47: {"condition": "If your opponent declares an attack on one of your Units in this Column:"},
    48: {"on_summon": "Choose one of your opponent's Units, it Permanently loses -20 ATK."},
    73: {"on_field": "If your Warrior Unit in this Unit's Column would be Destroyed, apply 1 Eternal to that Unit, this Unit is Destroyed."},
    102: {"on_field": "Once per turn: this Unit's Type can become Water, Fire, Earth or Lightning. Once per turn you can apply 1 Curse to a Unit with the same Type."},
    141: {"on_field": "Once per turn: this Unit's Type can become Physical, Light or Dark. Your opponent cannot summon Units with the same Type as this Unit."},
    162: {"on_field": "This Unit can attack your opponent directly. If this Unit is Sacrificed, increase this Unit's cost +1 AP."},
    184: {"condition": "If a Spell/Trap is Destroyed:"},
    186: {"on_summon": "You can Fusion Summon using Units you Control as Tribute."},
    187: {"on_field": "If a Spell is activated, you can apply 1 Rune to a Unit."},
    188: {"on_field": "Once per turn: you can double the Debuffs on this Unit, apply the same Debuffs to an opponent's Unit."},
}

# F03-04: Arcane material is an exact payment. The export's requirement text ("Cost
# equivilant to Arcane") is replaced by the confirmed wording in both condition and material.
ARCANE_REQUIREMENT = "Exhaust Units from your Spent whose costs total exactly its Arcane cost"

# F03-09: basic-unit display names drop the redundant "(Type)" suffix; Type stays in `type`.
BASIC_TYPE_SUFFIX = " ("


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def nullable_type(value):
    """`?` Race/Type means none (a defined value), encoded as an empty string."""
    value = value.strip()
    return "" if value == "?" else value


def parse_stat(value):
    """`?` ATK/DEF is effect-determined: encoded as null, never as zero."""
    value = value.strip()
    if value in ("", "?"):
        return None
    return int(value)


def parse_cost(category, raw):
    raw = raw.strip()
    if category == "fusion":
        return "fusion", None
    if category == "ritual":
        # "?R" (Roma) = uses all runes on the material, minimum one.
        return "ritual", (None if raw.startswith("?") else int(raw[:-1]))
    if category == "arcane":
        return "arcane", int(raw[:-1])
    return "ap", int(raw)


def describe(c):
    """Full display text rebuilt from the structured fields. Like the export's own descriptions, an
    Extra Deck card's summon requirement (materials, Arcane payment) is not part of it."""
    unit = c["category"] in ("basic_unit", "unit", "fusion", "ritual", "arcane")
    parts = []
    if c["condition"] and c["category"] not in ("fusion", "ritual", "arcane"):
        parts.append(c["condition"])
    for label, key in (("On Summon: " if unit else "", "on_summon"), ("", "on_field"), ("On Destroy: ", "on_destruction")):
        if c[key]:
            parts.append(label + c[key])
    return " ".join(parts)


def build(card_csv=None):
    """Returns {"cards": [...], "unassigned_source_notes": [...]} from the card CSV."""
    path = card_csv or os.path.join(SRC, CARD_SOURCE)
    with open(path, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    cards = []
    for row in rows:
        raw_name = row["name"]
        name = raw_name.strip()
        if not name:
            # Unidentified rows (blank, or an unassigned effect) are not cards. The 2026-10-17
            # and 2026-10-18 exports have none; an orphan effect is never attached to a card or shown in play.
            continue
        cid = int(row["id"])
        raw = {}
        category = CATEGORY_KEYS[row["category"].strip()]
        cost_kind, cost = parse_cost(category, row["cost"])
        condition = row["condition"].strip()
        on_summon = row["On Summon/Play"].strip()
        material = row["material"].strip()
        description = row["description"].strip()
        if condition.lower() in EDITORIAL_CONDITIONS:
            raw["condition"] = row["condition"]
            condition = ""
        if cid in LEGACY_CONDITION_TO_SUMMON and condition and not on_summon:
            raw["condition"] = row["condition"]
            raw["On Summon/Play"] = row["On Summon/Play"]
            on_summon, condition = condition, ""
        if category == "basic_unit" and name.endswith(")") and BASIC_TYPE_SUFFIX in name:
            name = name[:name.rindex(BASIC_TYPE_SUFFIX)]
        if name != raw_name:
            raw["name"] = raw_name
        c = {
            "id": cid,
            "name": name,
            "category": category,
            "race": nullable_type(row["race"]),
            "type": nullable_type(row["type"]),
            "cost_kind": cost_kind,
            "cost": cost,
            "atk": parse_stat(row["atk"]) if category not in ("spell", "trap", "power") else None,
            "def": parse_stat(row["def"]) if category not in ("spell", "trap", "power") else None,
            "keywords": [k.strip().lower() for k in row["keywords"].split(",") if k.strip()],
            "condition": condition,
            "on_summon": on_summon,
            "on_field": row["On Field"].strip(),
            "on_destruction": row["On Destruction"].strip(),
            "material": material,
            "description": description,
            "art": {"image": row["image"].strip(), "card_img": row["card_img"].strip(), "type_icon": row["type_icon"].strip()},
            "source": {"file": os.path.basename(path), "sheet": row["sheet"].strip(), "index": int(row["index"])},
        }
        rebuild = "On Summon/Play" in raw
        if category == "arcane":
            for key, col in (("condition", "condition"), ("material", "material")):
                if c[key] != ARCANE_REQUIREMENT:
                    raw[col] = row[col]
                    c[key] = ARCANE_REQUIREMENT
        for field, text in TEXT_CORRECTIONS.get(cid, {}).items():
            col = {"on_summon": "On Summon/Play", "on_field": "On Field", "on_destruction": "On Destruction"}.get(field, field)
            if c[field] != text:
                raw[col] = row[col]
                c[field] = text
                rebuild = True
        if rebuild:
            raw["description"] = row["description"]
            c["description"] = describe(c)
        if raw:
            c["source"]["raw"] = dict(sorted(raw.items()))
        cards.append(c)
    ids = [c["id"] for c in cards]
    assert len(cards) == EXPECTED_CARDS, len(cards)
    assert len(set(ids)) == len(ids), "duplicate ids"
    for c in cards:
        assert "temp" not in (c["condition"] + c["on_summon"]).lower().split(), c["id"]
    cards.sort(key=lambda c: (c["source"]["index"], c["id"]))
    return {"cards": cards, "unassigned_source_notes": []}


def build_statuses():
    path = os.path.join(SRC, STATUS_SOURCE)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return [{"id": r["id"], "name": r["name"], "source_class": r["type"], "source_text": r["description"]} for r in csv.DictReader(fh)]


def serialise(data):
    return json.dumps(data, ensure_ascii=False, indent=1)


def main(argv):
    path = os.path.join(SRC, CARD_SOURCE)
    digest = sha256(path)
    if digest != CARD_SOURCE_SHA256:
        print("card source hash mismatch: %s (expected %s)" % (digest, CARD_SOURCE_SHA256))
        return 2
    data = build(path)
    text = serialise(data)
    out_cards = os.path.join(OUT, "cards.json")
    if "--check" in argv:
        with open(out_cards, encoding="utf-8", newline="") as f:
            same = f.read() == text
        print("cards.json up to date" if same else "cards.json is stale: run tools/import_cards.py")
        return 0 if same else 1
    os.makedirs(OUT, exist_ok=True)
    with open(out_cards, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    statuses = build_statuses()
    if statuses is not None:   # the status CSV is unchanged by this batch; keep the JSON if absent
        with open(os.path.join(OUT, "status_source.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(statuses, f, ensure_ascii=False, indent=1)
    print("source:", CARD_SOURCE, digest[:12], "cards:", len(data["cards"]),
          "notes:", len(data["unassigned_source_notes"]), "statuses:", "unchanged" if statuses is None else len(statuses))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
