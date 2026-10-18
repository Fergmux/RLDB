"""Import the RLDB source CSVs into rldb/data/*.json.

The active card source is pinned (file name and SHA-256) in rules/sources/active-card-source.json;
earlier snapshots listed there are comparison history only and are never read. No CSV is modified.
Change log: design/card-database-update-2026-10-18.md.

Applies only confirmed corrections (rules/06, design/decision-register-answers.md, playtest
feedback 03-06, the 2026-10-18 owner rulings) and records every raw cell the importer changed under
`source.raw`, so the export stays auditable.

Run from the repo root:
  python -I tools/import_cards.py                    regenerate rldb/data/cards.json
  python -I tools/import_cards.py --check            exit 1 if the JSON is stale
  python -I tools/import_cards.py --adopt <csv>      take a new export from the sheet: validate it,
                                                     keep a dated copy in rules/sources, pin it,
                                                     regenerate, and report what changed
The output is deterministic so it can be committed and re-generated.

What the CSV drives: names, stats, costs, Types, Races, categories, keywords and every card text the
player reads. What it does not: card behaviour, which is scripted per card ID in
rldb/src/core/card_scripts.gd. --adopt flags effect-text changes and new IDs for that reason.
"""
import csv
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "rules", "sources")
OUT = os.path.join(ROOT, "rldb", "data")

ACTIVE = os.path.join(SRC, "active-card-source.json")


def _active():
    with open(ACTIVE, encoding="utf-8") as fh:
        return json.load(fh)


CARD_SOURCE = _active()["file"]
CARD_SOURCE_SHA256 = _active()["sha256"]
PREVIOUS_SOURCES = _active()["previous"]     # audit history only; never imported
STATUS_SOURCE = "RLDB Master - status.csv"
# Card behaviour is keyed by stable ID, so no ID may disappear (saved decks and series refer to them).
MIN_CARDS = 188

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

# Corrections audited per ID against the standardised 2026-10-18 export. Field -> text.
# User-confirmed rule rewordings (the raw text still carries the old rule):
#   45/47 (C-03): Magic Cylinder / Damage Conversion trigger only on an attack on a unit in
#         this column (raw text still says "declares an Attack in this Column").
#   48 (F03-19): Overextend's controller chooses the target; raw text still says highest ATK.
#   147 (owner, 2026-10-18): Demented Apparition forces any attacker that can attack it, so an
#         Infiltrate attacker is forced even while it is Protected (raw text: "is Unprotected").
# Dropped as obsolete (the standardised export fixed them): the possessive and typo fixes on 12,
# 40, 73, 102, 141, 162, 184, 186, 187 and 188, and earlier 169, 90 and 183.
TEXT_CORRECTIONS = {
    45: {"condition": "If your opponent declares an Attack on one of your Units in this Column:"},
    47: {"condition": "If your opponent declares an Attack on one of your Units in this Column:"},
    48: {"on_summon": "Choose one of your opponent's Units, it Permanently loses -20 ATK."},
    147: {"on_field": "At the start of your turn: your opponent's Units lose -8 DEF. If your opponent's Unit attacks and can attack this Unit: that Unit must attack this Unit."},
}

# F03-04: Arcane material is an exact payment. The standardised export states it itself ("whose
# combined Cost equals this Unit's Cost"); only the older ambiguous wording ("Cost equivilant to
# Arcane") is still replaced, in both condition and material.
ARCANE_REQUIREMENT = "Exhaust Units from your Spent whose costs total exactly its Arcane cost"
AMBIGUOUS_ARCANE = "equivilant"

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
                if AMBIGUOUS_ARCANE in c[key].lower() or not c[key]:
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
    assert len(cards) >= MIN_CARDS, len(cards)
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


NL = "\n"
STAT_FIELDS = ("name", "category", "race", "type", "cost_kind", "cost", "atk", "def", "keywords")
TEXT_FIELDS = ("condition", "on_summon", "on_field", "on_destruction", "material")


def report(old_cards, new_cards):
    """Lines describing what an adopted export changes, for the person running --adopt."""
    old = {c["id"]: c for c in old_cards}
    new = {c["id"]: c for c in new_cards}
    lines = []
    gone = sorted(set(old) - set(new))
    if gone:
        lines.append("REMOVED IDs (not allowed): %s" % gone)
    for i in sorted(set(new) - set(old)):
        lines.append("NEW card %d %s: needs its behaviour scripted in card_scripts.gd" % (i, new[i]["name"]))
    for i in sorted(set(new) & set(old)):
        a, b = old[i], new[i]
        for k in STAT_FIELDS:
            if a[k] != b[k]:
                lines.append("stat  %d %s: %s %s -> %s" % (i, b["name"], k, a[k], b[k]))
        for k in TEXT_FIELDS:
            if a[k] != b[k]:
                lines.append("TEXT  %d %s: %s changed -- check whether the behaviour changed too" % (i, b["name"], k))
    return lines


def adopt(path):
    """Validates a new export, keeps a dated copy in rules/sources, pins it and regenerates."""
    import datetime
    import shutil
    digest = sha256(path)
    if digest == CARD_SOURCE_SHA256:
        print("This export is already the active source; nothing to do.")
        return 0
    try:
        data = build(path)
    except Exception as e:      # malformed export: nothing is copied or pinned
        print("export rejected: %r" % (e,))
        return 2
    lines = report(build()["cards"], data["cards"])
    if any(l.startswith("REMOVED") for l in lines):
        print(NL.join(lines))
        return 2
    stem = "RLDB Master - Card Database (%s" % datetime.date.today().isoformat()
    name, n = stem + ").csv", 0
    while os.path.exists(os.path.join(SRC, name)):
        n += 1
        name = "%s%s).csv" % (stem, chr(ord("a") + n))
    shutil.copyfile(path, os.path.join(SRC, name))
    data = build(os.path.join(SRC, name))     # provenance names the kept copy, not the download
    act = _active()
    pinned = {"file": name, "sha256": digest, "previous": [act["file"]] + act["previous"]}
    with open(ACTIVE, "w", encoding="utf-8", newline=NL) as fh:
        fh.write(json.dumps(pinned, indent=1) + NL)
    with open(os.path.join(OUT, "cards.json"), "w", encoding="utf-8", newline=NL) as f:
        f.write(serialise(data))
    print("adopted %s as rules/sources/%s (%s); cards: %d" % (os.path.basename(path), name, digest[:12], len(data["cards"])))
    print(NL.join(lines) if lines else "No card data changed.")
    print("Next: run the test suite (tests that pin a changed stat will say so) and commit.")
    return 0


def main(argv):
    if "--adopt" in argv:
        i = argv.index("--adopt")
        if i + 1 >= len(argv):
            print("usage: python -I tools/import_cards.py --adopt <exported csv>")
            return 2
        return adopt(argv[i + 1])
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
