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
    175: "Arcane overpayment", 93: "Fusion Ceremony", 82: "Fusion Ceremony", 151: "Fusion distinctness",
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
    69: "2026-11-03: when tributed (Field, undebilitated) for a Fusion or Ritual summon, that unit gets 1 Cleanse as it lands (was 2 Pierce); Arcane exhausting does not count. The On Summon Cleanse on an adjacent unit is optional.",
    15: "2026-11-03: when tributed (Field, undebilitated) for a Fusion or Ritual summon, that unit gets 1 Pierce as it lands (the Magentric hook).",
    77: "2026-11-03: when tributed (Field, undebilitated) for a Fusion or Ritual summon, that unit gets 1 Infiltrate as it lands.",
    12: "2026-11-03: the revive costs 1 AP and takes only a unit with 20 ATK or less (printed ATK in Spent).",
    21: "2026-11-03: each unit the opponent summons while Shen is on the Field (any kind of summon) permanently loses 10 ATK; suppressed while Shen is Debilitated.",
    37: "2026-11-03: +8 ATK while it is Protecting a unit (the front unit with a unit behind it); it was +10 while Protected.",
    45: "2026-11-03 (replaces C-03): an attack declared by an opponent's unit in this Trap's column, whatever its target, a direct attack included. Column i faces column i.",
    47: "2026-11-03: the Magic Cylinder trigger (the attacker's column, direct attacks included); costs 1.",
    68: "2026-11-03: Fusion Summon first (Seppuku is never a material and keeps its zone until the Fusion unit lands), then Seppuku is destroyed; Eternal saving it does not undo the summon.",
    87: "2026-11-03: destroys any card the opponent has on the Field (Unit, Spell/Trap, Power).",
    135: "2026-11-03: while protected by a Dragon it is put in Defense stance and cannot change to Attack (by command or effect); that Dragon gains +14 ATK.",
    191: "2026-11-03: offered in the ordinary Trap window (Trap Prompts apply) when the opponent's effect destroys it while set on its owner's Field (set before this turn). Summons any unit from its owner's Draw (shown to them only) into a free zone of its column; not offered without one or without a unit in Draw. Like every Trap, it responds on the opponent's turn only.",
    177: "2026-10-17: optional On Destroy recovery from your own Exhaust, current ordinary cost 1 or lower (Extra Deck cards never qualify).",
    20: "Copies every Buff stack present on other units on the Field.",
    36: "Revival uses the delayed-AP (-1) as the cost; revives only if Dante is still in Spent. 2026-10-17: the manual effect targets any unit; +1 ATK per Burn on Dante.",
    42: "Fills free zones in Hand-then-Draw order, Attack stance; no player choice of which basics.",
    48: "F03-19: the trap owner chooses any opposing unit (no highest-ATK rule).",
    72: "Moves only if the other zone in its column is empty.",
    94: "Material 1 must have a Type; material 2 must share it. Stats are a snapshot of the materials.",
    101: "\"sent from the Field to Spent\" also applies after resolving from Hand (it is exhausted).",
    103: "If you control no units the reduction is 0.",
    154: "Only explicit gain/loss ops reverse (ATK/DEF, AP, costs, auras); stat setting/copying and multipliers are not. 2026-10-18: Damage and Healing are never reversed.",
    163: "Destroying your own cards counts as destruction by effect (may trigger your own traps/effects).",
    164: "Applies only when the attacked target is a unit; the owner picks the adjacent unit.",
    180: "Needs a free zone on your side; the unit returns to its owner at end of turn (to Spent if their board is full).",
    13: "2026-10-18: Dark by default. The Type change is one-shot: the Witch and every Mage on the Field (both sides) take the chosen Type and keep it after the Witch leaves; later Mages are unaffected.",
    19: "Copies current ATK/DEF and Race once (snapshot).",
    95: "Copies current ATK/DEF and Type once (snapshot).",
    176: "2026-10-18: sums current ATK and DEF of the other Water units on the Field when summoned (snapshot).",
    67: "Spent materials are exhausted. 2026-11-03: Fusion Summon first (Void Basilisk is never a material and keeps its zone until the Fusion unit lands), then it is exhausted if it is still on the Field.",
    85: "\"activates an Effect\" = Spell cast/activation, manual ability use or Power play (On Summon triggers excluded, P-24).",
    140: "2026-10-18: no negation. Destroys the activated card (on the Field, or a Spell resolving), whose effect still resolves; not offered when that card already left the Field. Field -> Spent raises its cost by 1 for the game.",
    9: "2026-10-18 On Destroy: every unit in its column (both sides) with current cost 1 or lower; Extra Deck units have no ordinary cost.",
    10: "2026-10-18: the search is optional; On Destroy hits every Spell/Trap in its column, both sides, revealed or not.",
    49: "2026-10-18: any summon by the opponent (no 2-cost minimum).",
    88: "2026-10-18: +6 per copy on the base +6 (one = 12, two = 18), replacing P-19's 12 per copy.",
    169: "2026-10-18: a start-of-turn trigger per copy after the normal draw.",
    178: "2026-11-03: -1 AP (was -2) to your units while only the opponent controls a unit (non-stacking, like Magical Council).",
    182: "2026-10-18: the target unit's cost rises by 1 for the rest of the game (kept off the Field); the Spell's own cost no longer rises. 2026-11-03: +10 ATK this turn (was +20).",
    184: "Any destroyed Spell/Trap, either side, while it is the responder's window (opponent's turn). Puts a Power from your own Spent into a free Power zone at no cost; Marked by the Abyss obeys its 0-cost-deck limit.",
    185: "Search is optional; the -1 AP lasts this turn. The ability destroys any Power; +1 AP only when it was yours.",
    186: "The On Summon Fusion is optional and only offered when a Fusion Summon is possible; the Retain is optional, on sacrifice or tribute (undebilitated).",
    187: "Either player's Spell activation (cast or set Spell flipped); the Rune is optional, on any unit.",
    188: "On Summon copies the Debuffs of every other unit (a copied Debilitate suppresses its own ability). The ability doubles its Debuffs, then applies the doubled stacks to an opponent's unit (Cleanse there can prevent each).",
    149: "Zero-cost check uses printed ordinary costs of all cards you own in this game, Extra Deck included.",
    146: "2026-11-03: three Basic Unit materials. On Summon an optional search of any card from Draw (-1 AP this turn). Once per turn a Basic Unit from Draw into a free zone of yours adjacent to it. +8 ATK/DEF per adjacent Basic Unit of yours.",
    56: "2026-11-03 material \"Unit with 20 or more ATK or DEF\": current ATK or current DEF of 20 or more (also 57, 58, 61, 93, 143, 147).",
    57: "2026-11-03: no On Summon; a second once-per-turn ability gives one unit (either side) 1 Infiltrate and 1 Nimble.",
    58: "2026-11-03: the ability discards a card (Hand to Spent), then draws; it needs a card in Hand.",
    61: "2026-11-03: optional 8 Medic On Summon on one of your adjacent units; the ability discards a unit card from Hand for +1 AP.",
    63: "2026-11-03: the Reveal is optional (asked only with a Spell/Trap on the Field); once per turn the Freaky Funday switch; On Destroy its controller exhausts a card of their choice from their own Spent (not itself), mandatory while there is one.",
    65: "2026-11-03: optional Rune On Summon; On Destroy its controller destroys a unit with a Rune on either side, mandatory while one exists.",
    143: "2026-11-03: On Summon 2 Blind to the opponent's units; the second ability is the Freaky Funday switch.",
    147: "2026-11-03 ruling: an opponent's unit that can attack it (Infiltrate counts) cannot attack other units; direct attacks are not restricted.",
    151: "2026-11-03: ?/? = combined current ATK/DEF of the units tributed for its Fusion Summon (as Mirrorflesh); 0/0 when summoned another way.",
    170: "2026-11-03: the On Summon discard is offered only while the opponent has more cards on the Field.",
    173: "2026-11-03: destroyed undebilitated, it goes to Exhaust (as Flying Sandworm) after paralysing every unit.",
    176: "2026-10-18: sums current ATK and DEF of the other Water units on the Field when summoned (snapshot). 2026-11-03: \"Adjacent Units cannot declare an Attack\" is Zorath's lock (its controller's adjacent units); once per turn a Water unit from Spent into its column.",
    183: "2026-11-03: the start-of-turn Damage became a once-per-turn 6 Poison on a unit in its column.",
    189: "New 2026-11-03. The Race change is one-shot (as Chaos Witch's Type): itself, then all of its controller's units, from every Race of the pool. Opponent's units of its current Race cannot attack while it is on the Field (undebilitated).",
    190: "New 2026-11-03, owner ruling \"Both at turn start\": at its controller's turn start, Protecting a unit = their Traps cost -1 AP, Protected by a unit = their Traps on the Field cannot be Destroyed, each until the start of their next turn.",
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
