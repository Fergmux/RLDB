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
import re
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
#   46 (owner, 2026-10-20, confirmed 2026-11-03): the sheet says "Controls 4 or more Units"; Mirror
#         Force counts cards.
# Owner rulings of 2026-11-03 on the JB Edit export (design/card-database-update-2026-11-03.md):
#   45/47: Magic Cylinder / Damage Conversion read "If your opponent's Unit in this Column declares an
#         Attack:" (the attacker's column; a direct attack counts). Supersedes the C-03 wording.
#   48: Overextend reads "One of your opponent's Units Permanently loses -20 ATK." (controller chooses).
#   147: Demented Apparition's lure reads "Your opponent's Units cannot attack other Units if they can
#         attack this Unit." (supersedes the 2026-10-18 "must attack this Unit" wording).
#   Typos the owner asked to fix: 21 "you opponent summons" -> "your opponent Summons"; 146 "summon" ->
#         "Summon"; 135 and 170 a capital just after a colon (house style is lowercase there).
TEXT_CORRECTIONS = {
    21: {"on_field": "This Unit gains +10 ATK/DEF for each card in Exhaust. If your opponent Summons a Unit, then that Unit Permanently loses -10 ATK."},
    45: {"condition": "If your opponent's Unit in this Column declares an Attack:"},
    46: {"condition": "If your opponent Controls 4 or more cards and declares an Attack:"},
    47: {"condition": "If your opponent's Unit in this Column declares an Attack:"},
    48: {"on_summon": "One of your opponent's Units Permanently loses -20 ATK."},
    135: {"on_field": "If this Unit is Protected by a Dragon Unit: this Unit cannot be in Attack Stance, then that Dragon Unit gains +14 ATK."},
    146: {"on_field": "Once per turn: you can Summon a Basic Unit from Draw to an Adjacent Zone. This Unit gains +8 ATK/DEF for each of your Adjacent Basic Units."},
    147: {"on_field": "At the start of your turn: your opponent's Units lose -8 DEF. Your opponent's Units cannot attack other Units if they can attack this Unit."},
    170: {"on_summon": "If your opponent Controls more cards: you can discard a card to gain +1 AP."},
}

# Owner rulings of 2026-11-03: the new cards drop the sheet's working suffix "inspired", and Damage
# Conversion costs 1 (the sheet says 0).
NAME_CORRECTIONS = {189: "Owlbear Druid", 190: "Snow Tiger Paladin"}
COST_CORRECTIONS = {47: "1"}

# From the 2026-11-03 export the sheet no longer carries the art columns (image, card_img, type_icon)
# or `material`. Art references come from the newest earlier pinned export that has them (by ID; a new
# card has none until its art arrives); an Extra Deck card's material is its `condition` cell, which
# every export has kept identical to `material`.
ART_COLUMNS = ("image", "card_img", "type_icon")

# F03-04: Arcane material is an exact payment. The standardised export states it itself ("whose
# combined Cost equals this Unit's Cost"); only the older ambiguous wording ("Cost equivilant to
# Arcane") is still replaced, in both condition and material.
ARCANE_REQUIREMENT = "Exhaust Units from your Spent whose costs total exactly its Arcane cost"
AMBIGUOUS_ARCANE = "equivilant"

# F03-09: basic-unit display names drop the redundant "(Type)" suffix; Type stays in `type`.
BASIC_TYPE_SUFFIX = " ("

# L23 (owner feedback 2026-11-05): the Evolve mechanic. A card with `evolves_into` carries its own
# Evolve section (`evolve`, shown apart from the rules texts, like a Fusion's Material) and, at the
# start of its controller's turn, may be replaced by that card for the rest of the game. The evolved
# forms are evolution-only: never drafted, offered or deck-built (CardDB.is_collectible). Not a sheet
# column yet, so the chain is declared here. Every card gets both fields ("" / null when none).
EVOLVE_TEXT = "At the start of your turn you can Evolve this Unit."
EVOLUTIONS = {155: 156, 156: 157}    # Symbiote Spawn -> Symbiote Larva -> Symbiote Siphonophore


# 2026-10-20 export: a find-and-replace left some rules texts starting "change the Stance". A text
# (or a section after its "On Summon:" / "On Play:" / "On Destroy:" label) starts with a capital.
SECTION_START = re.compile(r"(^|(?:On Summon|On Play|On Destroy): )([a-z])")


def sentence_case(text):
    return SECTION_START.sub(lambda m: m.group(1) + m.group(2).upper(), text)


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


def _art_fallback():
    """ID -> art cells from the newest earlier pinned export that has the art columns."""
    for name in PREVIOUS_SOURCES:
        p = os.path.join(SRC, name)
        if not os.path.exists(p):
            continue
        with open(p, encoding="utf-8-sig", newline="") as fh:
            rows = list(csv.DictReader(fh))
        if rows and all(c in rows[0] for c in ART_COLUMNS):
            return {int(r["id"]): r for r in rows if r["id"].strip()}
    return {}


def build(card_csv=None):
    """Returns {"cards": [...], "unassigned_source_notes": [...]} from the card CSV."""
    path = card_csv or os.path.join(SRC, CARD_SOURCE)
    with open(path, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    art_rows = None if rows and all(c in rows[0] for c in ART_COLUMNS) else _art_fallback()
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
        cost_cell = row["cost"]
        if cid in COST_CORRECTIONS and cost_cell.strip() != COST_CORRECTIONS[cid]:
            raw["cost"] = cost_cell
            cost_cell = COST_CORRECTIONS[cid]
        cost_kind, cost = parse_cost(category, cost_cell)
        condition = row["condition"].strip()
        on_summon = row["On Summon/Play"].strip()
        if "material" in row:
            material = row["material"].strip()
        else:
            material = condition if category in ("fusion", "arcane") else ""
        description = row["description"].strip()
        if art_rows is None:
            art = {k: row[k].strip() for k in ART_COLUMNS}
        else:
            ar = art_rows.get(cid, {})
            art = {k: ar.get(k, "").strip() for k in ART_COLUMNS}
        if condition.lower() in EDITORIAL_CONDITIONS:
            raw["condition"] = row["condition"]
            condition = ""
        if cid in LEGACY_CONDITION_TO_SUMMON and condition and not on_summon:
            raw["condition"] = row["condition"]
            raw["On Summon/Play"] = row["On Summon/Play"]
            on_summon, condition = condition, ""
        if category == "basic_unit" and name.endswith(")") and BASIC_TYPE_SUFFIX in name:
            name = name[:name.rindex(BASIC_TYPE_SUFFIX)]
        name = NAME_CORRECTIONS.get(cid, name)
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
            "evolve": EVOLVE_TEXT if cid in EVOLUTIONS else "",
            "evolves_into": EVOLUTIONS.get(cid),
            "description": description,
            "art": {"image": art["image"], "card_img": art["card_img"], "type_icon": art["type_icon"]},
            # A new card can arrive without a sheet index (2026-11-03): null, sorted after the rest.
            "source": {"file": os.path.basename(path), "sheet": row["sheet"].strip(),
                       "index": int(row["index"]) if row["index"].strip() else None},
        }
        # The 2026-11-03 export leaves `description` empty: it is rebuilt from the rules texts.
        rebuild = "On Summon/Play" in raw or not description
        if category == "arcane":
            for key, col in (("condition", "condition"), ("material", "material")):
                if AMBIGUOUS_ARCANE in c[key].lower() or not c[key]:
                    raw[col] = row[col]
                    c[key] = ARCANE_REQUIREMENT
        for field, col in (("condition", "condition"), ("on_summon", "On Summon/Play"), ("on_field", "On Field"),
                           ("on_destruction", "On Destruction"), ("description", "description")):
            fixed = sentence_case(c[field])
            if fixed != c[field]:
                raw[col] = row[col]
                c[field] = fixed
        for field, text in TEXT_CORRECTIONS.get(cid, {}).items():
            col = {"on_summon": "On Summon/Play", "on_field": "On Field", "on_destruction": "On Destruction"}.get(field, field)
            if c[field] != text:
                raw[col] = row[col]
                c[field] = text
                rebuild = True
        if rebuild:
            if row["description"].strip():
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
    by_id = {c["id"]: c for c in cards}
    for base, nxt in EVOLUTIONS.items():
        assert base in by_id and nxt in by_id and nxt != base, (base, nxt)
        assert {by_id[base]["category"], by_id[nxt]["category"]} <= {"basic_unit", "unit"}, (base, nxt)
    cards.sort(key=lambda c: (c["source"]["index"] is None, c["source"]["index"] or 0, c["id"]))
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
