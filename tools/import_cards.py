"""Import the RLDB source CSVs into rldb/data/*.json.

Applies only the confirmed corrections from rules/06-OPEN-DECISIONS-AND-CORRECTIONS.md.
Run from the repo root:  python -I tools/import_cards.py
The output is deterministic so it can be committed and re-generated.
"""
import csv
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "rules", "sources")
OUT = os.path.join(ROOT, "rldb", "data")

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

# Confirmed corrections (file 06): misplaced On Summon effects stored in the condition column.
CONDITION_TO_SUMMON = {"63", "97"}


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


def main():
    rows = list(csv.DictReader(open(os.path.join(SRC, "RLDB Master - Card Database.csv"), encoding="utf-8", newline="")))
    cards = []
    notes = []
    for row in rows:
        name = row["name"].strip()
        if not name:
            if any(v.strip() for k, v in row.items() if k != "index"):
                notes.append({"source_index": row["index"], "text": " ".join(v.strip() for v in row.values() if v and v.strip() and v != row["index"])})
            continue
        category = CATEGORY_KEYS[row["category"].strip()]
        cost_kind, cost = parse_cost(category, row["cost"])
        condition = row["condition"].strip()
        on_summon = row["On Summon/Play"].strip()
        if row["id"].strip() in CONDITION_TO_SUMMON:
            on_summon = (condition + " " + on_summon).strip()
            condition = ""
        cards.append({
            "id": int(row["id"]),
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
            "material": row["material"].strip(),
            "description": row["description"].strip(),
            "art": {"image": row["image"].strip(), "card_img": row["card_img"].strip(), "type_icon": row["type_icon"].strip()},
            "source": {"sheet": row["sheet"].strip(), "index": int(row["index"])},
        })
    ids = [c["id"] for c in cards]
    assert len(cards) == 183, len(cards)
    assert len(set(ids)) == len(ids), "duplicate ids"
    cards.sort(key=lambda c: c["source"]["index"])

    statuses = []
    for row in csv.DictReader(open(os.path.join(SRC, "RLDB Master - status.csv"), encoding="utf-8", newline="")):
        statuses.append({"id": row["id"], "name": row["name"], "source_class": row["type"], "source_text": row["description"]})

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "cards.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"cards": cards, "unassigned_source_notes": notes}, f, ensure_ascii=False, indent=1)
    with open(os.path.join(OUT, "status_source.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(statuses, f, ensure_ascii=False, indent=1)
    print("cards:", len(cards), "notes:", len(notes), "statuses:", len(statuses))


if __name__ == "__main__":
    sys.exit(main())
