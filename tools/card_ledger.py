"""Generate docs/card-support-ledger.md from the card data and the test suite.

A card counts as TESTED when a test function named test_cNNN_... exists, or when a
rules test is listed in RULES_TESTS below. Scripted-but-untested cards are listed
explicitly so they are never mistaken for verified behaviour.
Run from the repo root:  python -I tools/card_ledger.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "rldb", "tests")
SCRIPTS = os.path.join(ROOT, "rldb", "src", "core", "card_scripts.gd")

# Cards exercised by scenario tests in tests/unit/rules (file 05 acceptance checks).
RULES_TESTS = {
    45: "Magic Cylinder response/lethal", 46: "Mirror Force", 51: "trap ordering", 14: "ordered HP loss",
    18: "Narzyl/Crevasse order", 100: "Narzyl/Crevasse order", 64: "Necrovast Exhaust->Draw",
    174: "Cliff sacrifice/tribute", 150: "Mumen sacrifice", 96: "Roma 3 Runes", 98: "Ritual tribute",
    175: "Arcane overpayment", 93: "Polymerization", 82: "Polymerization", 151: "Fusion distinctness",
    154: "Sneaky Snunday checks", 182: "Snunday/Shimmer", 41: "Snunday/Delayed Gratification",
    158: "Snunday/Divine Serpent", 159: "Snunday aura", 160: "Divine Serpent", 162: "Diggie direct attack",
    34: "Debilitate aura", 21: "persistent cost", 83: "set Spell", 88: "Elemental Mastery",
    180: "Hypnotise", 101: "hidden-pile selection", 55: "hidden choice payload",
}

# Interpretations made where the card text leaves room (see design/decision-register.md).
NOTES = {
    7: "2026-10-17: Spell search (its Cleanse was removed); the -1 AP lasts this turn only.",
    11: "2026-10-17: same-Type search; a typeless partner matches nothing.",
    25: "2026-10-17: destroys every unprotected Basic Unit on both sides; mandatory.",
    69: "2026-10-17: when tributed (Field, undebilitated) for a Fusion or Ritual summon, that unit gets 2 Pierce as it lands; Arcane exhausting does not count.",
    177: "2026-10-17: optional On Destroy recovery from your own Exhaust, current ordinary cost 1 or lower (Extra Deck cards never qualify).",
    20: "Copies every Buff stack present on other units on the Field.",
    36: "Revival uses the delayed-AP (-1) as the cost; revives only if Dante is still in Spent. 2026-10-17: the manual effect targets any unit; +1 ATK per Burn on Dante.",
    42: "Fills free zones in Hand-then-Draw order, Attack stance; no player choice of which basics.",
    48: "F03-19: the trap owner chooses any opposing unit (no highest-ATK rule).",
    72: "Moves only if the other zone in its column is empty.",
    94: "Material 1 must have a Type; material 2 must share it. Stats are a snapshot of the materials.",
    101: "\"sent from the Field to Spent\" also applies after resolving from Hand (it is exhausted).",
    103: "If you control no units the reduction is 0.",
    154: "Only explicit gain/loss ops reverse; stat setting/copying, multipliers and status-driven HP are not reversed (open cases).",
    163: "Destroying your own cards counts as destruction by effect (may trigger your own traps/effects).",
    164: "Applies only when the attacked target is a unit; the owner picks the adjacent unit.",
    180: "Needs a free zone on your side; the unit returns to its owner at end of turn (to Spent if their board is full).",
    13: "2026-10-17: the Witch's own Type changes; every Mage on both sides has the Witch's Type while it remains. A typeless Witch imposes nothing.",
    19: "Copies current ATK/DEF and Race once (snapshot).",
    95: "Copies current ATK/DEF and Type once (snapshot).",
    176: "Sums current ATK of other Water units on the Field when summoned (snapshot).",
    67: "Spent materials are exhausted.",
    85: "\"activates an Effect\" = Spell cast/activation, manual ability use or Power play (On Summon triggers excluded, P-24).",
    140: "Same activation definition as Energy Capture; the negated card goes to Spent.",
    149: "Zero-cost check uses printed ordinary costs of all cards you own in this game, Extra Deck included.",
    146: "Medic applies to Basic Units on both sides.",
}


def main():
    cards = json.load(open(os.path.join(ROOT, "rldb", "data", "cards.json"), encoding="utf-8"))["cards"]
    tested = {}
    for dirpath, _, files in os.walk(TESTS):
        for f in files:
            if not f.endswith(".gd"):
                continue
            text = open(os.path.join(dirpath, f), encoding="utf-8").read()
            for m in re.finditer(r"func (test_c(\d{3})_\w+)", text):
                tested.setdefault(int(m.group(2)), []).append(m.group(1))
    script_text = open(SCRIPTS, encoding="utf-8").read()
    scripted = {int(x) for x in re.findall(r"t\[(\d+)\]\s*=", script_text)}
    rows = []
    counts = {"tested": 0, "scripted, untested": 0, "no effect (basic)": 0, "unimplemented": 0}
    for c in sorted(cards, key=lambda c: (c["category"], c["id"])):
        cid = c["id"]
        if c["category"] == "basic_unit":
            status = "no effect (basic)"
            evidence = "combat/turn tests"
        elif cid in tested or cid in RULES_TESTS:
            status = "tested"
            evidence = ", ".join(tested.get(cid, [])[:2]) or ("rules: " + RULES_TESTS[cid])
        elif cid in scripted:
            status = "scripted, untested"
            evidence = ""
        else:
            status = "unimplemented"
            evidence = ""
        counts[status] += 1
        rows.append("| %d | %s | %s | %s | %s | %s |" % (cid, c["name"], c["category"], status, evidence, NOTES.get(cid, "")))
    out = [
        "# Card support ledger",
        "",
        "Generated by `tools/card_ledger.py` from `rldb/data/cards.json`, `card_scripts.gd` and the test suite.",
        "",
        "**Totals:** " + ", ".join("%s: %d" % kv for kv in counts.items()) + " (of %d cards)." % len(cards),
        "",
        "- *tested*: at least one behaviour test exercises the card through the real engine (usually its main clause; secondary clauses of multi-clause cards may be untested).",
        "- *scripted, untested*: behaviour is implemented but no dedicated test yet — treat as unverified.",
        "- Notes record interpretations of ambiguous text; they are proposals, not confirmed rules.",
        "",
        "| ID | Name | Category | Status | Evidence | Interpretation notes |",
        "| --- | --- | --- | --- | --- | --- |",
    ] + rows
    path = os.path.join(ROOT, "docs", "card-support-ledger.md")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(counts)
    print("untested:", [r.split(" | ")[1] for r in rows if "scripted, untested" in r])


if __name__ == "__main__":
    main()
