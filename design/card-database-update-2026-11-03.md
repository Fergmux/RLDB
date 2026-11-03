# Card database update, 3 Nov 2026 ("RLDB Master - JB Edit" export)

Source: the owner's `RLDB Master - JB Edit.csv`, adopted as
`rules/sources/RLDB Master - Card Database (2026-11-03).csv` (pinned in `active-card-source.json`).
Compared against the 20 Oct export. 103 existing cards change, and there are 3 new cards (IDs 189-191).

The owner asked for every change to be implemented, with the sheet's wording copied verbatim
except for fixing wrong capitals at the start of a sentence. Capitalised keywords stay capitalised.

## Owner answers (3 Nov)
- **Earlier rulings vs the sheet wording:**
  - Magic Cylinder (45) and Damage Conversion (47) read "If your opponent's Unit in this Column declares an Attack:". The trigger is now the **attacker's** column, and a direct attack counts. This replaces C-03 ("an Attack on one of your Units in this Column").
  - Damage Conversion costs **1**, not the sheet's 0.
  - Overextend (48) reads "One of your opponent's Units Permanently loses -20 ATK." The controller keeps choosing the target (F03-19).
  - Mirror Force (46) counts **cards**, not Units: "If your opponent Controls 4 or more cards and declares an Attack:".
  - Demented Apparition (147) reads "Your opponent's Units cannot attack other Units if they can attack this Unit." This replaces "that Unit must attack this Unit".
- **Snow Tiger Paladin (190):** "Both at turn start". At the start of its controller's turn, both conditions are checked:
  - If it is Protecting a Unit, that player's Traps cost -1 AP until the start of their next turn.
  - If it is Protected by a Unit, that player's Traps cannot be Destroyed until the start of their next turn.
- **New card names:** drop the working suffix "inspired". They are "Owlbear Druid" (189) and "Snow Tiger Paladin" (190).
- **Typos to fix:**
  - Shen (21): "you opponent summons" becomes "your opponent Summons".
  - Akiramari (146): "summon" becomes "Summon".
  - Dragon Rider (135) and Grandmother Kaya (170): the capital just after a colon becomes lowercase, as on every other card.

All of the above live in `tools/import_cards.py` (`TEXT_CORRECTIONS`, `NAME_CORRECTIONS`,
`COST_CORRECTIONS`), and each raw cell is recorded in `source.raw`.

## Importer changes for the new export layout
- The export has no `image`, `card_img`, `type_icon` or `material` columns.
  - Art references come from the newest earlier pinned export that has them, matched by ID. The new cards have none; they show the placeholder until the owner's art arrives.
  - An Extra Deck card's `material` is its `condition` cell. Every earlier export kept the two identical.
- The `description` column is empty, so the description is rebuilt from the rules texts.
- The new cards have no sheet `index`. It is stored as null and they sort last.
- The `keywords` column is now empty on every card. Nothing in the game reads it (it only passes through `match_view`).
- The two trailing unnamed columns hold spreadsheet working numbers (for example "-2,-2"). They are not card data and are ignored.

## Stat-only changes (data, no script work)
Each entry is ID name: old → new.

**ATK/DEF changes**
- 6 Tag Team - L: ATK 16→8
- 8 Tag Team - S: DEF 8→6
- 9 Tag Team - F: 16/22→10/16
- 10 Tag Team - W: 24/8→16/2
- 11 Tag Team - J: 20/16→8/14
- 12 Tag Team - X: 18/36→16/24
- 13 Chaos Witch: 24/28→18/22
- 14 Avatar of the Flame Spirit: 18/20→16/12
- 16 Edwin: 6/2→8/4
- 17 Accursed Zealot: 8/10→10/12
- 18 Corrupted Narzyl: 10/0→16/2
- 20 Spirit Bomb: 20/20→18/24
- 21 Shen: 30/30→0/0
- 22 Zorath: 58/58→46/46
- 24 Chidori Monk: 14/12→16/14
- 25 Stormcaller: 12/8→14/10
- 26 Brinekeeper: 14/10→16/12
- 27 Hydra: 24/14→20/6
- 28 Guardian of the Forest: ATK 14→12
- 29 The Sweeper: 8/4→10/6
- 30 Accio: 6/12→8/14
- 31 Cosmic Dragon: 32/24→24/16
- 32 Frost Wyvern: 22/22→18/8
- 33 Fledgling Drake: 4/8→6/6
- 34 Dragon of the Cave: 4/16→6/18
- 35 Enraged Komodo: 12/4→14/6
- 36 Dante: 28/24→24/10
- 37 Solomon, the Captain: 26/20→20/14
- 38 The Lone Warrior: 30/18→24/16
- 39 Steadfast Soldier: 14/8→16/10
- 40 Aleister: 8/8→10/10
- 57 Geolock: 22/50→20/46
- 58 Infernogate: 40/32→42/28
- 59 Abysslord: 32/40→26/34
- 60 Rotmaw: 36/32→26/30
- 61 Sanctified Blade: 42/28→38/40
- 62 Naturewrath: 36/24→30/6
- 64 Necrovast: DEF 22→12
- 65 Creeping Null: 40/28→36/12
- 66 Nyxthral: 28/34→18/28
- 67 Void Basilisk: 8/6→10/8
- 68 Seppuku: 10/4→12/6
- 69 Magentric: 20/20→16/16
- 70 Krakeshin: 14/28→12/26
- 71 Faerie Flight: 4/16→6/18
- 72 Myth Wukong: 20/20→16/16
- 75 Travelwarden: 16/26→10/24
- 76 Soul Devourer: 22/38→4/30
- 77 Radablast: 22/20→12/18
- 78 Abraxus: 24/40→8/28
- 79 Akakaijū: 34/12→26/4
- 97 Legendary Swordsman: 26/44→30/30
- 98 Raging Inferno: 26/12→20/8
- 102 Waang: 20/18→14/16
- 141 Bahatia: 30/34→24/26
- 142 Gojirun: 38/24→26/20
- 145 Trigonam: 48/16→36/12
- 146 Akiramari: 8/44→24/24
- 147 Demented Apparition: 34/10→20/42
- 150 Mumen's Bounty: ATK 0→4
- 158 Serpent Head: 4/4→6/6
- 159 Serpent Body: 8/8→10/10
- 162 Diggie: DEF 0→2
- 171 Flying Sandworm: DEF 10→6
- 173 Thunderclap: DEF 14→4
- 174 Cliff: DEF 18→20
- 175 Boom: ATK 26→20
- 181 Solomon, the Tyrannical: 38/20→30/24
- 183 Yamata: 12/20→10/18
- 186 Bronze Salaman: 20/20→16/16
- 187 Fence: 6/14→8/12
- 188 Necro: 32/0→0/30

**Cost changes**
- 15 Da Mage: 1→2 (with 10/4→16/10)
- 63 The Last Foundation: 2R→3R (with 8/22→12/28)
- 170 Kaya: 1A→2A
- 171 Sandworm: 1A→2A
- 172 Tyde: 2A→3A
- 173 Thunderclap: 2A→3A
- 174 Cliff: 2A→3A
- 175 Boom: 3A→4A
- 176 Tritu: 3A→4A
- 177 Illusionist: 4A→5A
- 185 Drako: 3A→4A
- 187 Fence: 1A→2A

**Type and Race changes**
- 135 Dragon Rider: Type Lightning→Physical
- 144 Stone Guardian: Race Warrior→Monster, 38/38→28/28

**Formula change**
- 151 Ultimate Dragon: 56/44→?/? (now effect-determined)

## Wording-only changes (same behaviour; card text updates from the data)
- 14 Avatar: "take -6 HP Damage, then your opponent must take -6 HP Damage."
- 43 Freaky Funday: the clause order changed.
- 45 Magic Cylinder: "must take".
- 153 Hot Stove: "must take".
- 158-160 Divine Serpents: "must take".
- 161 Neva: "must take".
- 179 Tyrant's Lantern: the subject was dropped.
- 181 Solomon, the Tyrannical: "take -12 HP Damage."
- 48 Overextend: owner wording.

Check any prompt strings in `card_scripts.gd` that quote these.

## Behaviour changes (script work)
### Main deck: Units, Spells, Traps, Powers (agent A)
- **12 Tag Team - X:** the ability is now "Lose 1 AP: Summon a Unit with 20 ATK or less from Spent in this Column" (was 2 AP, any Unit).
- **15 Da Mage:** adds "If this Unit is Tributed: apply 1 Pierce to the Fusion or Ritual Unit Summoned." Magentric's old Tributed hook is the precedent.
- **21 Shen:** adds "If your opponent Summons a Unit, then that Unit Permanently loses -10 ATK." It triggers on every summon by the opponent while Shen is on the Field.
- **23 Auric:** take -8 HP, then either +8 ATK permanently or Destroy a Spell/Trap (was 10/10).
- **31 Cosmic Dragon:** On Destroy, 6 Medic (was 3).
- **37 Solomon, the Captain:** "If this Unit is Protecting a Unit: this Unit gains +8 ATK." It used to be "Protected by", +10.
- **45 Magic Cylinder / 47 Damage Conversion:** the trigger is now an attack declared by an opponent's Unit in this Column (the attacker's column), whatever its target, including a direct attack. Damage Conversion's cost is 1.
- **67 Void Basilisk:** "You can Fusion Summon using Units you Control and/or Spent as Tribute, then Exhaust this Unit."
- **68 Seppuku:** "...then Destroy this Unit."
- **69 Magentric:** On Summon, "You can apply 1 Cleanse to an Adjacent Unit". When Tributed, it applies 1 Cleanse to the Fusion/Ritual Summoned (was 2 Pierce).
- **70 Krakeshin:** +6 ATK permanently on a Zone move (was +8).
- **72 Myth Wukong:** +16 DEF in the Front Row, +16 ATK in the Back Row (was 20).
- **76 Soul Devourer:** new On Summon, "You can apply 10 Poison to a Unit in this Column."
- **77 Radablast:** adds "If this Unit is Tributed: apply 1 Infiltrate to the Fusion or Ritual Unit Summoned."
- **84 Assassinate:** 20 DEF or less (was 30).
- **87 Shared Fate:** "Destroy an opponent's card" (was Unit). Any card the opponent has on the Field.
- **135 Dragon Rider:** "If this Unit is Protected by a Dragon Unit: this Unit cannot be in Attack Stance, then that Dragon Unit gains +14 ATK."
- **155-157 Symbiotes:** +6 ATK (was +10).
- **165 Saviour Appears: Defcon 1:** 20 ATK in both the condition and the summon (was 24).
- **178 Reinforcements:** -1 AP (was -2).
- **179 Tyrant's Lantern:** +8 ATK (was +12).
- **180 Hypnotise:** 16 ATK or less (was 20).
- **182 Shimmer Serum:** +10 ATK (was +20). Under Sneaky Snunday the rules/06 note's "-16" becomes -10.
- **191 Do Not Open Box (new Trap, 2 AP):** "If your opponent Destroys this Trap: Summon a Unit from Draw in this Column."

### Extra Deck: Fusion, Ritual, Arcane (agent B)
**New materials**
- 56 Razeon: "Unit with 20 or more ATK or DEF + Lightning Unit"
- 57 Geolock: "... + Earth Unit"
- 58 Infernogate: "... + Fire Unit"
- 61 Sanctified Blade: "... + Light Unit"
- 93 Bastion Wyrm: "... + Physical Unit"
- 143 Typhoon Simorgh: "... + Water Unit"
- 147 Demented Apparition: "... + Dark Unit"
- 146 Akiramari: "Basic Unit + Basic Unit + Basic Unit" (three materials)
- 188 Necro: "Monster Unit + Dark Unit"

**Effects**
- **57 Geolock:** the On Summon is gone. Adds "Once per turn: you can apply 1 Infiltrate and 1 Nimble to a Unit."
- **58 Infernogate:** the ability is now "Once per turn: you can discard a card to draw a card" (was 10 Burn to all).
- **61 Sanctified Blade:** On Summon, "You can apply 8 Medic to an Adjacent Unit." Ability: "Once per turn: you can discard a Unit to gain +1 AP."
- **63 The Last Foundation:**
  - On Summon is now optional ("You can apply Reveal to all Spells/Traps").
  - Adds "Once per turn: you can switch the ATK/DEF of all Units currently on the Field until the end of this turn" (as Freaky Funday).
  - On Destroy: "Exhaust a card from Spent."
- **64 Necrovast:** +4 per card in Exhaust (was 6).
- **65 The Creeping Null:** On Summon, "You can apply 1 Rune to a Unit". On Destroy, "Destroy a Unit with Rune applied."
- **96 Roma:** +10 per Rune (was 12).
- **97 Legendary Swordsman:** +20 ATK when behind on HP (was 30).
- **141 Bahatia:** On Destroy, -12 ATK/DEF (was 30).
- **143 Typhoon Simorgh:**
  - On Summon, "apply 2 Blind to your opponent's Units."
  - The second ability is now the Freaky Funday switch (was 1 Blind to opponent's Units).
- **146 Akiramari:**
  - On Summon, "You can add a card from Draw to Hand, until the end of this turn: that card costs -1 AP."
  - "Once per turn: you can Summon a Basic Unit from Draw to an Adjacent Zone."
  - Aura: "+8 ATK/DEF for each of your Adjacent Basic Units."
  - On Destroy is unchanged. The old 5-Medic On Summon is gone.
- **147 Demented Apparition:** the lure is now "cannot attack other Units if they can attack this Unit".
- **151 Ultimate Dragon:** ?/?. On Summon, "This Unit's ATK/DEF become the combined ATK/DEF of the Units Tributed for its Fusion Summon" (as Mirrorflesh 94).
- **170 Grandmother Kaya:** "If your opponent Controls more cards: you can discard a card to gain +1 AP."
- **173 Thunderclap:** On Destroy, "apply 1 Paralyse to all Units, then Exhaust this Unit."
- **174 Cliff:** +1 AP when Sacrificed/Tributed (was +2).
- **176 Tritu:** "Once per turn: you can Summon a Water Unit from Spent in this Column. Adjacent Units cannot declare an Attack." Zorath (22) is the precedent; the old Medic is gone.
- **177 Illusionist:** +20 ATK on its turn (was 30).
- **183 Yamata:** "Once per turn: you can apply 6 Poison to a Unit in this Column." It replaces the start-of-turn 6 damage.
- **189 Owlbear Druid (new Fusion):** Mage / Physical, 34/24, Beast Unit + Physical Unit.
  - "Once per turn: you can change this Unit's Race to any Race, then change the Race of all your Units to this Unit's Race."
  - "Your opponent's Units with the same Race as this Unit cannot attack."
- **190 Snow Tiger Paladin (new Fusion):** Warrior / Light, 18/40, Beast Unit + Light Unit.
  - On Summon: "You can Summon a 2 Cost or lower Unit from Draw in this Column."
  - On Field: the owner ruling above.

## Decisions for review
- Columns face each other directly, so Magic Cylinder and Damage Conversion check whether the attacker is in the Trap's column.
- Void Basilisk and Seppuku (owner, 3 Nov): each can be one of its own Fusion materials. If it is, its "then Exhaust/Destroy this Unit" does not happen. When it is not a material, it stays on the Field until the Fusion lands, so on a full board one of the Tributes has to come from the Field.
- Dragon Rider is moved to Defence as soon as a Dragon protects it, and stance changes to Attack are refused. Owner, 3 Nov: when it is Summoned behind a Dragon it is never offered Attack Stance; it enters in Defence without a stance prompt.
- Do Not Open Box responds only on the opponent's turn, like every Trap, and must have been Set before that turn.
- Shen's -10 is an ordinary permanent loss, so Sneaky Snunday and Freaky Funday affect it.
- Soul Devourer can target itself, like every "a Unit in this Column" choice.
- The Last Foundation cannot Exhaust itself with its On Destroy.
- A Debilitated Thunderclap goes to Spent, not Exhaust.
- Kaya and Snow Tiger don't trigger at all when their condition fails.
- The Last Foundation asks about its Reveal only when a Spell/Trap is on the Field.
- When Snow Tiger protects a face-down Trap, the opponent can infer that the card is a Trap. That comes with the card text.
- The bot's stance scoring skips Units that are locked from attacking (Zorath, Tritu, Owlbear, Dragon Rider).
- Ultimate Dragon shows ?/? off the Field, and 0/0 if it is Summoned without a Fusion.
- Speed override (owner, 3 Nov): no full suite was run. About 50 older tests that pin the previous numbers still fail and need updating later. Every new card test passes, and so do the tutorial and bot tests.
