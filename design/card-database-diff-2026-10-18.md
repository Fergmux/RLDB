# Card database CSV differences — 18 October 2026

Exhaustive cell-by-cell comparison, matched by stable `id`, of
`rules/sources/RLDB Master - Card Database (2026-10-17).csv` (old) and
`rules/sources/RLDB Master - Card Database (2026-10-18).csv` (new, SHA-256 `85bb97c947df5459ea68d0246a05a3cac643dbab975c6c1e9bbe8b007e73c5bc`).
Both parsed as UTF-8 CSV; cells compared exactly. What each change means for the game is in
`design/card-database-update-2026-10-18.md`.

- Identified cards: 183 old, 188 new. Added IDs: 184, 185, 186, 187, 188. Removed IDs: none.
- Cards with at least one changed cell: 160 (including 25 basic units whose only change is the dropped Type suffix, already dropped in game).


### Added 184 {'index': '129', 'id': '184', 'sheet': 'trap', 'name': 'Counter Transmutation', 'category': 'Trap', 'cost': '1', 'condition': 'If a Sell/Trap is Destroyed:', 'On Summon/Play': 'Play a Power from Spent.', 'description': 'If a Sell/Trap is Destroyed: Play a Power from Spent.'}

### Added 188 {'index': '163', 'id': '188', 'sheet': 'fusion', 'name': 'Necro, the Loathsome', 'category': 'Fusion Unit', 'race': 'Mage', 'type': 'Dark', 'atk': '32', 'def': '0', 'keywords': 'Debilitate', 'condition': 'Mage Unit + Debuffed Unit', 'On Summon/Play': 'Apply all Debuffs on all Units to this Unit.', 'On Field': 'Once per turn: you can double the Debuffs on this Unit, apply the same Debuffs to an opponents Unit.', 'description': 'On Summon: Apply all Debuffs on all Units to this Unit. Once per turn: you can double the Debuffs on this Unit, apply the same Debuffs to an opponents Unit.', 'image': '187.png', 'card_img': '163.png', 'type_icon': 'Card/types/dark.png', 'material': 'Mage Unit + Debuffed Unit'}

### Added 186 {'index': '167', 'id': '186', 'sheet': 'ritual', 'name': 'Bronze Salaman', 'category': 'Ritual Unit', 'race': 'Dragon', 'type': 'Light', 'cost': '1R', 'atk': '20', 'def': '20', 'keywords': 'Reveal', 'On Summon/Play': 'You can Fusion Summon using Units from your Field as Tribute.', 'On Field': 'If this Unit is Sacrificed or Tributed, you can apply 1 Retain to a card in your Hand.', 'description': 'On Summon: You can Fusion Summon using Units from your Field as Tribute. If this Unit is Sacrificed or Tributed, you can apply 1 Retain to a card in your Hand.', 'image': '185.png', 'card_img': '167.png', 'type_icon': 'Card/types/light.png'}

### Added 187 {'index': '178', 'id': '187', 'sheet': 'arcane', 'name': 'Fence of the Marked Claw', 'category': 'Arcane Unit', 'race': 'Warrior', 'type': 'Fire', 'cost': '1A', 'atk': '6', 'def': '14', 'keywords': 'Rune', 'condition': 'Exhaust Units from Spent with Cost equivilant to Arcane.', 'On Summon/Play': 'You can add a Monster Unit from Draw to Hand, that Unit costs -1 AP this turn.', 'On Field': 'If a Spell is activated, you can Apply 1 Rune to a Unit.', 'description': 'On Summon: You can add a Monster Unit from Draw to Hand, that Unit costs -1 AP this turn. If a Spell is activated, you can Apply 1 Rune to a Unit.', 'image': '184.png', 'card_img': '178.png', 'type_icon': 'Card/types/fire.png', 'material': 'Exhaust Units from Spent with Cost equivilant to Arcane.'}

### Added 185 {'index': '181', 'id': '185', 'sheet': 'arcane', 'name': 'Drako, Councillor of The Order', 'category': 'Arcane Unit', 'race': 'Dragon', 'type': 'Physical', 'cost': '3A', 'atk': '24', 'def': '16', 'condition': 'Exhaust Units from Spent with cost equivilant to Arcane.', 'On Summon/Play': 'You can add a Power from Draw or Spent to Hand, that Power costs -1 AP this turn.', 'On Field': 'Once per turn: you can Destroy a Power, if it is your Power, gain +1 AP.', 'description': 'On Summon: you can add a Power from Draw or Spent to Hand, that Power costs -1 AP this turn. Once per turn: you can Destroy a Power, if it is your Power, gain +1 AP.', 'image': '186.png', 'card_img': '183.png', 'type_icon': 'Card/types/physical.png', 'material': 'Exhaust Units from Spent with cost equivilant to Arcane.'}

### 1 Basic Mage
- `name`
  - old: `Basic Mage (Water)`
  - new: `Basic Mage`

### 2 Basic Dragon
- `name`
  - old: `Basic Dragon (Water)`
  - new: `Basic Dragon`

### 3 Basic Warrior
- `name`
  - old: `Basic Warrior (Water)`
  - new: `Basic Warrior`

### 4 Basic Beast
- `name`
  - old: `Basic Beast (Water)`
  - new: `Basic Beast`

### 5 Basic Monster
- `name`
  - old: `Basic Monster (Water)`
  - new: `Basic Monster`

### 105 Basic Mage
- `name`
  - old: `Basic Mage (Heavenly)`
  - new: `Basic Mage`
- `type`
  - old: `Heavenly`
  - new: `Light`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 106 Basic Dragon
- `name`
  - old: `Basic Dragon (Heavenly)`
  - new: `Basic Dragon`
- `type`
  - old: `Heavenly`
  - new: `Light`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 107 Basic Warrior
- `name`
  - old: `Basic Warrior (Heavenly)`
  - new: `Basic Warrior`
- `type`
  - old: `Heavenly`
  - new: `Light`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 108 Basic Beast
- `name`
  - old: `Basic Beast (Heavenly)`
  - new: `Basic Beast`
- `type`
  - old: `Heavenly`
  - new: `Light`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 109 Basic Monster
- `name`
  - old: `Basic Monster (Heavenly)`
  - new: `Basic Monster`
- `type`
  - old: `Heavenly`
  - new: `Light`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 110 Basic Mage
- `name`
  - old: `Basic Mage (Fire)`
  - new: `Basic Mage`

### 111 Basic Dragon
- `name`
  - old: `Basic Dragon (Fire)`
  - new: `Basic Dragon`

### 112 Basic Warrior
- `name`
  - old: `Basic Warrior (Fire)`
  - new: `Basic Warrior`

### 113 Basic Beast
- `name`
  - old: `Basic Beast (Fire)`
  - new: `Basic Beast`

### 114 Basic Monster
- `name`
  - old: `Basic Monster (Fire)`
  - new: `Basic Monster`

### 115 Basic Mage
- `name`
  - old: `Basic Mage (Physical)`
  - new: `Basic Mage`

### 116 Basic Dragon
- `name`
  - old: `Basic Dragon (Physical)`
  - new: `Basic Dragon`

### 117 Basic Warrior
- `name`
  - old: `Basic Warrior (Physical)`
  - new: `Basic Warrior`

### 118 Basic Beast
- `name`
  - old: `Basic Beast (Physical)`
  - new: `Basic Beast`

### 119 Basic Monster
- `name`
  - old: `Basic Monster (Physical)`
  - new: `Basic Monster`

### 120 Basic Mage
- `name`
  - old: `Basic Mage (Earth)`
  - new: `Basic Mage`

### 121 Basic Dragon
- `name`
  - old: `Basic Dragon (Earth)`
  - new: `Basic Dragon`

### 122 Basic Warrior
- `name`
  - old: `Basic Warrior (Earth)`
  - new: `Basic Warrior`

### 123 Basic Beast
- `name`
  - old: `Basic Beast (Earth)`
  - new: `Basic Beast`

### 124 Basic Monster
- `name`
  - old: `Basic Monster (Earth)`
  - new: `Basic Monster`

### 125 Basic Mage
- `name`
  - old: `Basic Mage (Necrotic)`
  - new: `Basic Mage`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 126 Basic Dragon
- `name`
  - old: `Basic Dragon (Necrotic)`
  - new: `Basic Dragon`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 127 Basic Warrior
- `name`
  - old: `Basic Warrior (Necrotic)`
  - new: `Basic Warrior`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 128 Basic Beast
- `name`
  - old: `Basic Beast (Necrotic)`
  - new: `Basic Beast`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 129 Basic Monster
- `name`
  - old: `Basic Monster (Necrotic)`
  - new: `Basic Monster`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 130 Basic Mage
- `name`
  - old: `Basic Mage (Lightning)`
  - new: `Basic Mage`

### 131 Basic Dragon
- `name`
  - old: `Basic Dragon (Lightning)`
  - new: `Basic Dragon`

### 132 Basic Warrior
- `name`
  - old: `Basic Warrior (Lightning)`
  - new: `Basic Warrior`

### 133 Basic Beast
- `name`
  - old: `Basic Beast (Lightning)`
  - new: `Basic Beast`

### 134 Basic Monster
- `name`
  - old: `Basic Monster (Lightning)`
  - new: `Basic Monster`

### 6 Tag Team - L
- `On Summon/Play`
  - old: `If you control another Unit in this Column, you can add a Trap from Draw to Hand, that Trap costs -1 AP this turn.`
  - new: `If you Control another Unit in this Column, you can add a Trap from Draw to Hand, until the end of this turn: that Trap costs -1 AP.`
- `description`
  - old: `On Summon: If you control another Unit in this Column, you can add a Trap from Draw to Hand, that Trap costs -1 AP this turn.`
  - new: `On Summon: If you Control another Unit in this Column, you can add a Trap from Draw to Hand, until the end of this turn: that Trap costs -1 AP.`

### 7 Tag Team - B
- `On Summon/Play`
  - old: `If you control another Unit in this Column, you can add a Spell from Draw to Hand, that Spell costs -1 AP this turn.`
  - new: `If you Control another Unit in this Column, you can add a Spell from Draw to Hand, until the end of this turn: that Spell costs -1 AP.`
- `description`
  - old: `On Summon: If you control another Unit in this Column, you can add a Spell from Draw to Hand, that Spell costs -1 AP this turn.`
  - new: `On Summon: If you Control another Unit in this Column, you can add a Spell from Draw to Hand, until the end of this turn: that Spell costs -1 AP.`

### 8 Tag Team - S
- `On Summon/Play`
  - old: `If you have another Unit in this Column, you can Fusion Summon using Unit's from your Field as Tribute.`
  - new: `If you Control another Unit in this Column, you can Fusion Summon using Units you Control as Tribute.`
- `description`
  - old: `On Summon: If you have another Unit in this Column, you can Fusion Summon using Unit's from your Field as Tribute.`
  - new: `On Summon: If you Control another Unit in this Column, you can Fusion Summon using Units you Control as Tribute.`

### 9 Tag Team - F
- `On Summon/Play`
  - old: `If you have another Unit in this Column, you can add a Unit with the same Cost as that Unit from Draw to Hand, that Unit costs -1 AP this turn.`
  - new: `If you Control another Unit in this Column, you can add a Unit with the same cost as that Unit from Draw to Hand, until the end of this turn: that Unit costs -1 AP.`
- `On Destruction`
  - old: `""`
  - new: `Destroy all 1 Cost or lower Units in this Column.`
- `description`
  - old: `On Summon: If you have another Unit in this Column, you can add a Unit with the same Cost as that Unit from Draw to Hand, that Unit costs -1 AP this turn.`
  - new: `On Summon: If you Control another Unit in this Column, you can add a Unit with the same cost as that Unit from Draw to Hand, until the end of this turn: that Unit costs -1 AP. On Destroy: Destroy all 1 Cost or lower Units in this Column.`

### 10 Tag Team - W
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Summon/Play`
  - old: `If you have another Unit in this Column, add a Unit with the same Race as that Unit from Draw to Hand, that Unit costs -1 AP this turn.`
  - new: `If you Control another Unit in this Column, you can add a Unit with the same Race as that Unit from Draw to Hand, until the end of this turn: that Unit costs -1 AP.`
- `On Destruction`
  - old: `Destroy all facedown cards in this Column.`
  - new: `Destroy all Spell/Trap cards in this Column.`
- `description`
  - old: `On Summon: If you have another Unit in this Column, add a Unit with the same Race as that Unit from Draw to Hand, that Unit costs -1 AP this turn. On Destroy: Destroy all facedown cards in this Column.`
  - new: `On Summon: If you Control another Unit in this Column, you can add a Unit with the same Race as that Unit from Draw to Hand, until the end of this turn: that Unit costs -1 AP. On Destroy: Destroy all Spell/Trap cards in this Column.`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 11 Tag Team - J
- `keywords`
  - old: `Reveal`
  - new: `""`
- `On Summon/Play`
  - old: `If you have another Unit in this Column, you can add a Unit with the same Type as that Unit from Draw to Hand, that Unit costs -1 AP this turn.`
  - new: `If you Control another Unit in this Column, you can add a Unit with the same Type as that Unit from Draw to Hand, until the end of this turn: that Unit costs -1 AP.`
- `On Destruction`
  - old: `Destroy all card with Reveal in this Column.`
  - new: `Destroy a Power.`
- `description`
  - old: `On Summon: If you have another Unit in this Column, you can add a Unit with the same Type as that Unit from Draw to Hand, that Unit costs -1 AP this turn. On Destroy: Destroy all card with Reveal in this Column.`
  - new: `On Summon: If you Control another Unit in this Column, you can add a Unit with the same Type as that Unit from Draw to Hand, until the end of this turn: that Unit costs -1 AP. On Destroy: Destroy a Power.`

### 12 Tag Team - X
- `type`
  - old: `Heavenly`
  - new: `Light`
- `On Summon/Play`
  - old: `If you have another Unit in this Column, you can draw a card and gain +1 AP.`
  - new: `If you Control another Unit in this Column, you can draw a card and gain +1 AP.`
- `On Field`
  - old: `You can lose -2 AP, Summon a Unit from your Spent in this Unit's Column.`
  - new: `You can lose -2 AP, Summon a Unit from your Spent in this Units Column.`
- `description`
  - old: `On Summon: If you have another Unit in this Column, you can draw a card and gain +1 AP. You can lose -2 AP, Summon a Unit from your Spent in this Unit's Column.`
  - new: `On Summon: If you Control another Unit in this Column, you can draw a card and gain +1 AP. You can lose -2 AP, Summon a Unit from your Spent in this Units Column.`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 13 Chaos Witch
- `type`
  - old: `?`
  - new: `Dark`
- `On Field`
  - old: `Once per turn: this Unit's Type can become any Type (except for ?). All Mage Unit's become this Unit's Type.`
  - new: `Once per turn: this Unit's Type can become any Type, all Mage Units become this Unit's Type.`
- `description`
  - old: `Once per turn: this Unit's Type can become any Type (except for ?). All Mage Unit's become this Unit's Type. On Destroy: You can change an opponent's Unit to a Type of your choosing.`
  - new: `Once per turn: this Unit's Type can become any Type, all Mage Units become this Unit's Type. On Destroy: You can change an opponent's Unit to a Type of your choosing.`
- `type_icon`
  - old: `Card/types/unknown.png`
  - new: `Card/types/dark.png`

### 14 Avatar of the Flame Spirit
- `On Summon/Play`
  - old: `You can Apply 1 Rune to a Unit.`
  - new: `You can apply 1 Rune to a Unit.`
- `On Field`
  - old: `Once per turn: you can Apply 6 Burn to a Unit.`
  - new: `Once per turn: you can apply 6 Burn to a Unit.`
- `On Destruction`
  - old: `You lose -6 HP and then your opponent loses -6 HP.`
  - new: `You take -6 HP Damage, your opponent takes -6 HP Damage.`
- `description`
  - old: `On Summon: You can Apply 1 Rune to a Unit. Once per turn: you can Apply 6 Burn to a Unit. On Destroy: You lose -6 HP and then your opponent loses -6 HP.`
  - new: `On Summon: You can apply 1 Rune to a Unit. Once per turn: you can apply 6 Burn to a Unit. On Destroy: You take -6 HP Damage, your opponent takes -6 HP Damage.`

### 15 Da Mage
- `On Field`
  - old: `Once per turn: you can Apply 1 Pierce to a Unit.`
  - new: `Once per turn: you can apply 1 Pierce to a Unit.`
- `On Destruction`
  - old: `You can Apply 1 Eternal to a Mage Unit in this Column.`
  - new: `You can apply 1 Eternal to a Mage Unit in this Column.`
- `description`
  - old: `Once per turn: you can Apply 1 Pierce to a Unit. On Destroy: You can Apply 1 Eternal to a Mage Unit in this Column.`
  - new: `Once per turn: you can apply 1 Pierce to a Unit. On Destroy: You can apply 1 Eternal to a Mage Unit in this Column.`

### 20 Spirit Bomb
- `type`
  - old: `Heavenly`
  - new: `Light`
- `On Summon/Play`
  - old: `Apply every Buff on the Field to this Unit.`
  - new: `Apply all Buffs on all Units to this Unit.`
- `On Field`
  - old: `This Unit gains +4 ATK/DEF x the number of your opponent's Unit's.`
  - new: `This Unit gains +4 ATK/DEF x the number of your opponent's Units.`
- `On Destruction`
  - old: `You can Apply 1 Pierce to a Unit.`
  - new: `You can apply 1 Pierce to a Unit.`
- `description`
  - old: `On Summon: Apply every Buff on the Field to this Unit. This Unit gains +4 ATK/DEF x the number of your opponent's Unit's. On Destroy: You can Apply 1 Pierce to a Unit.`
  - new: `On Summon: Apply all Buffs on all Units to this Unit. This Unit gains +4 ATK/DEF x the number of your opponent's Units. On Destroy: You can apply 1 Pierce to a Unit.`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 21 Shen the World Dragon
- `On Field`
  - old: `While this Unit is on the field: this Unit gains +10 ATK/DEF x the number of cards in your Exhaust.`
  - new: `This Unit gains +10 ATK/DEF x the number of cards in your Exhaust.`
- `On Destruction`
  - old: `Increase this Unit's cost + 1AP.`
  - new: `This Unit Permanently costs +1AP.`
- `description`
  - old: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. While this Unit is on the field: this Unit gains +10 ATK/DEF x the number of cards in your Exhaust. On Destroy: Increase this Unit's cost + 1AP.`
  - new: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. This Unit gains +10 ATK/DEF x the number of cards in your Exhaust. On Destroy: This Unit Permanently costs +1AP.`

### 22 Zorath, Deity of the End
- `On Field`
  - old: `While this Unit is on the Field: Adjacent Unit's on the Field cannot declare an Attack.`
  - new: `Adjacent Units cannot declare an Attack.`
- `On Destruction`
  - old: `Increase this Unit's cost + 1AP.`
  - new: `This Unit Permanently costs +1AP.`
- `description`
  - old: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. While this Unit is on the Field: Adjacent Unit's on the Field cannot declare an Attack. On Destroy: Increase this Unit's cost + 1AP.`
  - new: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. Adjacent Units cannot declare an Attack. On Destroy: This Unit Permanently costs +1AP.`

### 23 Auric the Divine Father
- `On Field`
  - old: `Once per turn: you can lose -10 HP, either this Unit gains +10 ATK or Destroy a facedown card.`
  - new: `Once per turn: you can take -10 HP Damage, either this Unit Permanently gains +10 ATK or Destroy a Spell/Trap card.`
- `On Destruction`
  - old: `Increase this Unit's cost + 1AP.`
  - new: `This Unit Permanently costs +1AP.`
- `description`
  - old: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. Once per turn: you can lose -10 HP, either this Unit gains +10 ATK or Destroy a facedown card. On Destroy: Increase this Unit's cost + 1AP.`
  - new: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. Once per turn: you can take -10 HP Damage, either this Unit Permanently gains +10 ATK or Destroy a Spell/Trap card. On Destroy: This Unit Permanently costs +1AP.`

### 161 Neva the Divine Mother
- `On Field`
  - old: `At the start of your turn: Apply 1 Eternal to this Unit. Once per turn: you can Exhaust this Unit, your opponent loses -10 HP x amount of Eternal on this Unit.`
  - new: `At the start of your turn: apply 1 Eternal to this Unit. Once per turn: you can Exhaust this Unit, your opponent takes -10 HP Damage x amount of Eternal on this Unit.`
- `On Destruction`
  - old: `Increase this Unit's cost + 1AP.`
  - new: `This Unit Permanently costs +1AP.`
- `description`
  - old: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. At the start of your turn: Apply 1 Eternal to this Unit. Once per turn: you can Exhaust this Unit, your opponent loses -10 HP x amount of Eternal on this Unit. On Destroy: Increase this Unit's cost + 1AP.`
  - new: `On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. At the start of your turn: apply 1 Eternal to this Unit. Once per turn: you can Exhaust this Unit, your opponent takes -10 HP Damage x amount of Eternal on this Unit. On Destroy: This Unit Permanently costs +1AP.`

### 25 Stormcaller Harbinger
- `On Summon/Play`
  - old: `Destroy all Unprotected Basic Unit's.`
  - new: `Destroy all Unprotected Basic Units.`
- `description`
  - old: `On Summon: Destroy all Unprotected Basic Unit's.`
  - new: `On Summon: Destroy all Unprotected Basic Units.`

### 26 Brinekeeper Summoner
- `On Summon/Play`
  - old: `If you control another Unit in this Column, add a 0 Cost card from Draw to Hand.`
  - new: `If you Control another Unit in this Column, add a 0 Cost card from Draw to Hand.`
- `On Destruction`
  - old: `Destroy your facedown cards.`
  - new: `Destroy your Spell/Trap cards.`
- `description`
  - old: `On Summon: If you control another Unit in this Column, add a 0 Cost card from Draw to Hand. On Destroy: Destroy your facedown cards.`
  - new: `On Summon: If you Control another Unit in this Column, add a 0 Cost card from Draw to Hand. On Destroy: Destroy your Spell/Trap cards.`

### 28 Guardian of the Forest
- `type`
  - old: `Heavenly`
  - new: `Light`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 29 The Sweeper
- `On Summon/Play`
  - old: `You can Apply Reveal to a Spell or Trap in this Column.`
  - new: `You can apply Reveal to a Spell/Trap in this Column.`
- `On Field`
  - old: `Once per turn: you can spend -1 AP, Destroy a Trap with Reveal.`
  - new: `Once per turn: you can lose -1 AP, Destroy a Trap with Reveal.`
- `description`
  - old: `On Summon: You can Apply Reveal to a Spell or Trap in this Column. Once per turn: you can spend -1 AP, Destroy a Trap with Reveal.`
  - new: `On Summon: You can apply Reveal to a Spell/Trap in this Column. Once per turn: you can lose -1 AP, Destroy a Trap with Reveal.`

### 30 Accio the Hermit
- `On Summon/Play`
  - old: `You can send a Unit from Draw to Spent, Apply 1 Retain to a Unit in your Hand`
  - new: `You can send a Unit from Draw to Spent, apply 1 Retain to a Unit in your Hand`
- `description`
  - old: `On Summon: You can send a Unit from Draw to Spent, Apply 1 Retain to a Unit in your Hand On Destroy: You can move a Unit from Spent to Draw.`
  - new: `On Summon: You can send a Unit from Draw to Spent, apply 1 Retain to a Unit in your Hand On Destroy: You can move a Unit from Spent to Draw.`

### 31 Cosmic Dragon
- `type`
  - old: `Heavenly`
  - new: `Light`
- `On Destruction`
  - old: `You can Apply 3 Medic to a Unit.`
  - new: `You can apply 3 Medic to a Unit.`
- `description`
  - old: `On Summon: Apply 1 Pierce to this Unit. On Destroy: You can Apply 3 Medic to a Unit.`
  - new: `On Summon: Apply 1 Pierce to this Unit. On Destroy: You can apply 3 Medic to a Unit.`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 32 Frost Wyvern
- `On Field`
  - old: `Once per turn: you can Apply 1 Paralyse and 4 Burn to a Unit in this Column.`
  - new: `Once per turn: you can apply 1 Paralyse and 4 Burn to a Unit in this Column.`
- `description`
  - old: `On Summon: Destroy a Power. Once per turn: you can Apply 1 Paralyse and 4 Burn to a Unit in this Column.`
  - new: `On Summon: Destroy a Power. Once per turn: you can apply 1 Paralyse and 4 Burn to a Unit in this Column.`

### 33 Fledgling Drake
- `On Field`
  - old: `Once per turn: you can Apply 4 Burn to a Unit in this Column.`
  - new: `Once per turn: you can apply 4 Burn to a Unit in this Column.`
- `description`
  - old: `Once per turn: you can Apply 4 Burn to a Unit in this Column.`
  - new: `Once per turn: you can apply 4 Burn to a Unit in this Column.`

### 34 Dragon of the Cave
- `On Field`
  - old: `While this Unit is on the Field, Adjacent Unit's gain +6 DEF.`
  - new: `Adjacent Units gain +6 DEF.`
- `description`
  - old: `While this Unit is on the Field, Adjacent Unit's gain +6 DEF.`
  - new: `Adjacent Units gain +6 DEF.`

### 35 Enraged Komodo
- `On Field`
  - old: `Once per turn, you can Apply 1 Pierce to this Unit.`
  - new: `Once per turn, you can apply 1 Pierce to this Unit.`
- `description`
  - old: `Once per turn, you can Apply 1 Pierce to this Unit.`
  - new: `Once per turn, you can apply 1 Pierce to this Unit.`

### 36 Dante
- `On Summon/Play`
  - old: `Apply 6 Burn to all Unit's.`
  - new: `Apply 6 Burn to all Units.`
- `On Field`
  - old: `Once per turn: you can Apply 1 Cleanse or 10 Burn to a Unit. This Unit gains +1 ATK x the total number of Burn this Unit has.`
  - new: `Once per turn: you can apply 1 Cleanse or 10 Burn to a Unit. This Unit gains +1 ATK x the total number of Burn this Unit has.`
- `description`
  - old: `On Summon: Apply 6 Burn to all Unit's. Once per turn: you can Apply 1 Cleanse or 10 Burn to a Unit. This Unit gains +1 ATK x the total number of Burn this Unit has. On Destroy: You can lose -1 AP next turn: at the start of your next turn, Summon this Unit from your Spent to the Zone this Unit was originally in.`
  - new: `On Summon: Apply 6 Burn to all Units. Once per turn: you can apply 1 Cleanse or 10 Burn to a Unit. This Unit gains +1 ATK x the total number of Burn this Unit has. On Destroy: You can lose -1 AP next turn: at the start of your next turn, Summon this Unit from your Spent to the Zone this Unit was originally in.`

### 38 The Lone Warrior
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Field`
  - old: `This Unit loses -6 ATK/DEF x the number of your Adjacent Unit's. This Unit cannot recieve Buffs or gain + ATK/DEF.`
  - new: `This Unit loses -6 ATK/DEF x the number of your Adjacent Units. This Unit cannot recieve Buffs or gain + ATK/DEF.`
- `description`
  - old: `On Summon: You can Destroy a card with Reveal. This Unit loses -6 ATK/DEF x the number of your Adjacent Unit's. This Unit cannot recieve Buffs or gain + ATK/DEF.`
  - new: `On Summon: You can Destroy a card with Reveal. This Unit loses -6 ATK/DEF x the number of your Adjacent Units. This Unit cannot recieve Buffs or gain + ATK/DEF.`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 39 Steadfast Soldier
- `On Field`
  - old: `This Unit cannot be Destroyed by battle with a Unit with 30 ATK or more.`
  - new: `This Unit cannot be Destroyed by Battle with a Unit with 30 ATK or more.`
- `description`
  - old: `This Unit cannot be Destroyed by battle with a Unit with 30 ATK or more.`
  - new: `This Unit cannot be Destroyed by Battle with a Unit with 30 ATK or more.`

### 67 Void Basilisk
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Summon/Play`
  - old: `You can Apply 2 Paralyse to a Unit in this Column.`
  - new: `You can apply 2 Paralyse to a Unit in this Column.`
- `On Field`
  - old: `You can Exhaust this Unit, Fusion Summon using Unit's from your Field and/or Spent as Tribute.`
  - new: `You can Exhaust this Unit, Fusion Summon using Units you Control / Units in your Spent as Tribute.`
- `description`
  - old: `On Summon: You can Apply 2 Paralyse to a Unit in this Column. You can Exhaust this Unit, Fusion Summon using Unit's from your Field and/or Spent as Tribute.`
  - new: `On Summon: You can apply 2 Paralyse to a Unit in this Column. You can Exhaust this Unit, Fusion Summon using Units you Control / Units in your Spent as Tribute.`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 68 Sepukku
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Field`
  - old: `You can Destroy this Unit, Fusion Summon using Unit's from your Field as Tribute.`
  - new: `You can Destroy this Unit, Fusion Summon using Units you Control as Tribute.`
- `description`
  - old: `You can Destroy this Unit, Fusion Summon using Unit's from your Field as Tribute.`
  - new: `You can Destroy this Unit, Fusion Summon using Units you Control as Tribute.`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 69 Magentric
- `On Field`
  - old: `You can Fusion Summon using Unit's from your Field as Tribute. If this Unit is Tributed, Apply 2 Pierce to the Fusion or Ritual Unit Summoned.`
  - new: `You can Fusion Summon using Units you Control as Tribute. If this Unit is Tributed, apply 2 Pierce to the Fusion or Ritual Unit Summoned.`
- `description`
  - old: `On Summon: Apply 2 Pierce to an Adjacent Unit. You can Fusion Summon using Unit's from your Field as Tribute. If this Unit is Tributed, Apply 2 Pierce to the Fusion or Ritual Unit Summoned.`
  - new: `On Summon: Apply 2 Pierce to an Adjacent Unit. You can Fusion Summon using Units you Control as Tribute. If this Unit is Tributed, apply 2 Pierce to the Fusion or Ritual Unit Summoned.`

### 40 Aleister the Invoker
- `On Field`
  - old: `You can spend -1 AP, Fusion Summon using Unit's from your Field as Tribute.`
  - new: `You can lose -1 AP, Fusion Summon using you Control as Tribute.`
- `description`
  - old: `You can spend -1 AP, Fusion Summon using Unit's from your Field as Tribute.`
  - new: `You can lose -1 AP, Fusion Summon using you Control as Tribute.`

### 71 Faerie Flight
- `type`
  - old: `Heavenly`
  - new: `Light`
- `On Field`
  - old: `Once per turn: you can Apply 1 Nimble to a Unit. If this Unit moves Zone, Apply 3 Medic to this Unit.`
  - new: `Once per turn: you can apply 1 Nimble to a Unit. If this Unit moves Zone, apply 3 Medic to this Unit.`
- `description`
  - old: `Once per turn: you can Apply 1 Nimble to a Unit. If this Unit moves Zone, Apply 3 Medic to this Unit.`
  - new: `Once per turn: you can apply 1 Nimble to a Unit. If this Unit moves Zone, apply 3 Medic to this Unit.`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 73 Mans Best Friend
- `On Field`
  - old: `If your Warrior Unit in this Unit's Column would be Destroyed, Apply 1 Eternal to that Unit, this Unit is Destroyed.`
  - new: `If your Warrior Unit in this Units Column would be Destroyed, apply 1 Eternal to that Unit, this Unit is Destroyed.`
- `description`
  - old: `On Summon: Add a Warrior from Draw to Hand. If your Warrior Unit in this Unit's Column would be Destroyed, Apply 1 Eternal to that Unit, this Unit is Destroyed.`
  - new: `On Summon: Add a Warrior from Draw to Hand. If your Warrior Unit in this Units Column would be Destroyed, apply 1 Eternal to that Unit, this Unit is Destroyed.`

### 74 Sparky
- `On Field`
  - old: `If this Unit is Sacrificed or Tributed, Apply 1 Infiltrate to a Unit.`
  - new: `If this Unit is Sacrificed or Tributed, apply 1 Infiltrate to a Unit.`
- `description`
  - old: `If this Unit is Sacrificed or Tributed, Apply 1 Infiltrate to a Unit.`
  - new: `If this Unit is Sacrificed or Tributed, apply 1 Infiltrate to a Unit.`

### 16 Edwin, Initiatus of The Order
- `type`
  - old: `Heavenly`
  - new: `Light`
- `On Field`
  - old: `If you Destroy an opponent's Unit, Apply 1 Rune to this Unit.`
  - new: `If you Destroy an opponent's Unit, apply 1 Rune to this Unit.`
- `description`
  - old: `If you Destroy an opponent's Unit, Apply 1 Rune to this Unit.`
  - new: `If you Destroy an opponent's Unit, apply 1 Rune to this Unit.`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 17 Accursed Zealot
- `On Field`
  - old: `At the start of your turn, Apply 1 Rune to this Unit.`
  - new: `At the start of your turn, apply 1 Rune to this Unit.`
- `description`
  - old: `At the start of your turn, Apply 1 Rune to this Unit.`
  - new: `At the start of your turn, apply 1 Rune to this Unit.`

### 18 Corrupted Narzyl
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Summon/Play`
  - old: `You can Apply 1 Paralyse to a Unit in this Column.`
  - new: `You can apply 1 Paralyse to a Unit in this Column.`
- `On Field`
  - old: `If this Unit Destroys an opponent's Unit by battle, Apply 1 Rune to this Unit.`
  - new: `If this Unit Destroys an opponent's Unit, apply 1 Rune to this Unit.`
- `description`
  - old: `On Summon: You can Apply 1 Paralyse to a Unit in this Column. If this Unit Destroys an opponent's Unit by battle, Apply 1 Rune to this Unit.`
  - new: `On Summon: You can apply 1 Paralyse to a Unit in this Column. If this Unit Destroys an opponent's Unit, apply 1 Rune to this Unit.`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 75 Travelwarden
- `On Field`
  - old: `If one of your Unit's moves Zone, Apply 1 Rune to this Unit.`
  - new: `If one of your Units moves Zone, apply 1 Rune to this Unit.`
- `description`
  - old: `If one of your Unit's moves Zone, Apply 1 Rune to this Unit.`
  - new: `If one of your Units moves Zone, apply 1 Rune to this Unit.`

### 76 Soul Devourer
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Field`
  - old: `If any Unit is Sacrificed, Apply 1 Rune to this Unit.`
  - new: `If a Unit is Sacrificed, apply 1 Rune to this Unit.`
- `description`
  - old: `If any Unit is Sacrificed, Apply 1 Rune to this Unit.`
  - new: `If a Unit is Sacrificed, apply 1 Rune to this Unit.`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 77 Radablast
- `On Field`
  - old: `If a Trap is activated, Apply 1 Rune to this Unit.`
  - new: `If a Trap is activated, apply 1 Rune to this Unit.`
- `description`
  - old: `If a Trap is activated, Apply 1 Rune to this Unit.`
  - new: `If a Trap is activated, apply 1 Rune to this Unit.`

### 78 Abraxus Terrormane
- `On Field`
  - old: `Once per turn: you can Apply 4 Poison to a Unit in this Column.`
  - new: `Once per turn: you can apply 4 Poison to a Unit in this Column.`
- `description`
  - old: `On Summon: Apply 1 Cleanse to this Unit. Once per turn: you can Apply 4 Poison to a Unit in this Column. On Destroy: You can add a Dragon Unit from your Spent to Hand.`
  - new: `On Summon: Apply 1 Cleanse to this Unit. Once per turn: you can apply 4 Poison to a Unit in this Column. On Destroy: You can add a Dragon Unit from your Spent to Hand.`

### 79 Akakaijū
- `On Field`
  - old: `Once per turn: you can Apply 1 Infiltrate to a Unit.`
  - new: `Once per turn: you can apply 1 Infiltrate to a Unit.`
- `On Destruction`
  - old: `You can Apply Reveal to a facedown card.`
  - new: `You can apply Reveal to a Spell/Trap card.`
- `description`
  - old: `On Summon: Destroy a Water Unit. Once per turn: you can Apply 1 Infiltrate to a Unit. On Destroy: You can Apply Reveal to a facedown card.`
  - new: `On Summon: Destroy a Water Unit. Once per turn: you can apply 1 Infiltrate to a Unit. On Destroy: You can apply Reveal to a Spell/Trap card.`

### 102 Waang, Bender of Elements
- `On Field`
  - old: `Once per turn: this Unit's Type can become one of Water, Fire, Earth or Lightning. Once per turn you can Apply 1 Curse to a Unit with the same Type.`
  - new: `Once per turn: this Units Type can become Water, Fire, Earth or Lightning. Once per turn you can apply 1 Curse to a Unit with the same Type.`
- `description`
  - old: `Once per turn: this Unit's Type can become one of Water, Fire, Earth or Lightning. Once per turn you can Apply 1 Curse to a Unit with the same Type.`
  - new: `Once per turn: this Units Type can become Water, Fire, Earth or Lightning. Once per turn you can apply 1 Curse to a Unit with the same Type.`

### 162 Diggie
- `On Field`
  - old: `This Unit can attack your opponent directly. If this Unit is Sacrificed, increase this Unit's cost +1 AP.`
  - new: `This Unit can attack your opponent directly. If this Unit is Sacrificed, increase this Units cost +1 AP.`
- `description`
  - old: `This Unit can attack your opponent directly. If this Unit is Sacrificed, increase this Unit's cost +1 AP. On Destroy: Apply 1 Blind to the Unit that Destroyed it.`
  - new: `This Unit can attack your opponent directly. If this Unit is Sacrificed, increase this Units cost +1 AP. On Destroy: Apply 1 Blind to the Unit that Destroyed it.`

### 155 Symbiote Spawn
- `type`
  - old: `Heavenly`
  - new: `Light`
- `On Field`
  - old: `If this Unit is Protected by a Unit: that Unit gains +10 ATK.`
  - new: `If this Unit is Protected by a Unit, that Unit gains +10 ATK.`
- `description`
  - old: `On Summon: Apply 1 Eternal to this Unit. If this Unit is Protected by a Unit: that Unit gains +10 ATK.`
  - new: `On Summon: Apply 1 Eternal to this Unit. If this Unit is Protected by a Unit, that Unit gains +10 ATK.`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 156 Symbiote Larva
- `type`
  - old: `Heavenly`
  - new: `Light`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 157 Symbiote Siphonophore 
- `type`
  - old: `Heavenly`
  - new: `Light`
- `On Field`
  - old: `If this Unit is Protected by a Unit, Adjacent Unit's gain +10 ATK. At the start of your turn: Draw a card.`
  - new: `If this Unit is Protected by a Unit, Adjacent Units gain +10 ATK. At the start of your turn: Draw a card.`
- `description`
  - old: `On Summon: Apply 1 Eternal to this Unit. If this Unit is Protected by a Unit, Adjacent Unit's gain +10 ATK. At the start of your turn: Draw a card.`
  - new: `On Summon: Apply 1 Eternal to this Unit. If this Unit is Protected by a Unit, Adjacent Units gain +10 ATK. At the start of your turn: Draw a card.`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`

### 158 Divine Serpent - Head
- `On Summon/Play`
  - old: `If you control 2 Adjacent 'Divine Serpent' Unit's: Damage your opponent -30 HP.`
  - new: `If you control 2 Adjacent 'Divine Serpent' Units, your opponent takes -30 HP Damage, Destroy your 'Divine Serpent' Units.`
- `On Field`
  - old: `Once per turn: you can Apply 1 Paralyse to a Unit in this Column.`
  - new: `Once per turn: you can apply 1 Paralyse to a Unit in this Column.`
- `description`
  - old: `On Summon: If you control 2 Adjacent 'Divine Serpent' Unit's: Damage your opponent -30 HP. Once per turn: you can Apply 1 Paralyse to a Unit in this Column.`
  - new: `On Summon: If you control 2 Adjacent 'Divine Serpent' Units, your opponent takes -30 HP Damage, Destroy your 'Divine Serpent' Units. Once per turn: you can apply 1 Paralyse to a Unit in this Column.`

### 159 Divine Serpent - Body
- `On Summon/Play`
  - old: `If you control 2 Adjacent 'Divine Serpent' Unit's: Damage your opponent -30 HP.`
  - new: `If you control 2 Adjacent 'Divine Serpent' Units, your opponent takes -30 HP Damage, Destroy your 'Divine Serpent' Units.`
- `On Field`
  - old: `While this Unit is on the Field: Adjacent Unit's gain +10 DEF.`
  - new: `Adjacent Units gain +10 DEF.`
- `description`
  - old: `On Summon: If you control 2 Adjacent 'Divine Serpent' Unit's: Damage your opponent -30 HP. While this Unit is on the Field: Adjacent Unit's gain +10 DEF.`
  - new: `On Summon: If you control 2 Adjacent 'Divine Serpent' Units, your opponent takes -30 HP Damage, Destroy your 'Divine Serpent' Units. Adjacent Units gain +10 DEF.`

### 160 Divine Serpent - Soul
- `On Summon/Play`
  - old: `If you control 2 Adjacent 'Divine Serpent' Unit's: Damage your opponent -30 HP.`
  - new: `If you control 2 Adjacent 'Divine Serpent' Units, your opponent takes -30 HP Damage, Destroy your 'Divine Serpent' Units.`
- `On Field`
  - old: `Once per turn: you can make your opponent's Unit's Permanently lose -4 ATK.`
  - new: `Once per turn: you can make your opponent's Units Permanently lose -4 ATK.`
- `description`
  - old: `On Summon: If you control 2 Adjacent 'Divine Serpent' Unit's: Damage your opponent -30 HP. Once per turn: you can make your opponent's Unit's Permanently lose -4 ATK.`
  - new: `On Summon: If you control 2 Adjacent 'Divine Serpent' Units, your opponent takes -30 HP Damage, Destroy your 'Divine Serpent' Units. Once per turn: you can make your opponent's Units Permanently lose -4 ATK.`

### 80 Wings of Aurenthor
- `On Summon/Play`
  - old: `Apply 1 Nimble to all Unit's.`
  - new: `Apply 1 Nimble to all Units.`
- `description`
  - old: `Apply 1 Nimble to all Unit's.`
  - new: `Apply 1 Nimble to all Units.`

### 81 Fog of War
- `On Summon/Play`
  - old: `Apply 1 Blind to all Unit's on the Field.`
  - new: `Apply 1 Blind to all Units.`
- `description`
  - old: `Apply 1 Blind to all Unit's on the Field.`
  - new: `Apply 1 Blind to all Units.`

### 82 Fusion Ceremony
- `name`
  - old: `Polymerization`
  - new: `Fusion Ceremony`
- `On Summon/Play`
  - old: `Fusion Summon a Unit using Unit's from your Field.`
  - new: `Fusion Summon a Unit using Units you Control.`
- `description`
  - old: `Fusion Summon a Unit using Unit's from your Field.`
  - new: `Fusion Summon a Unit using Units you Control.`

### 42 Ambush
- `On Summon/Play`
  - old: `Summon as many Basic Unit's as possible from your Hand and Draw.`
  - new: `Summon as many Basic Units as possible from your Hand and Draw.`
- `description`
  - old: `Summon as many Basic Unit's as possible from your Hand and Draw.`
  - new: `Summon as many Basic Units as possible from your Hand and Draw.`

### 43 Freaky Funday
- `On Summon/Play`
  - old: `Until the end of this turn, switch the ATK/DEF of all Unit's currently on the Field.`
  - new: `Until the end of this turn, switch the ATK/DEF of all Units currently on the Field.`
- `description`
  - old: `Until the end of this turn, switch the ATK/DEF of all Unit's currently on the Field.`
  - new: `Until the end of this turn, switch the ATK/DEF of all Units currently on the Field.`

### 154 Sneaky Snunday
- `On Summon/Play`
  - old: `Until the end of this turn, all gain and loss are reversed.`
  - new: `Until the end of this turn, all new and ongoing gains and losses are reversed.`
- `description`
  - old: `Until the end of this turn, all gain and loss are reversed.`
  - new: `Until the end of this turn, all new and ongoing gains and losses are reversed.`

### 104 Earthquake
- `On Summon/Play`
  - old: `Change Stance of your opponent's Unprotected Unit's.`
  - new: `Change Stance of your opponent's Unprotected Units.`
- `description`
  - old: `Change Stance of your opponent's Unprotected Unit's.`
  - new: `Change Stance of your opponent's Unprotected Units.`

### 136 Equaliser
- `On Summon/Play`
  - old: `Destroy all Unit's with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.`
  - new: `Destroy all Units with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.`
- `description`
  - old: `Destroy all Unit's with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.`
  - new: `Destroy all Units with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.`

### 182 Shimmer Serum
- `keywords`
  - old: `Blind`
  - new: `Infiltrate, Blind`
- `On Summon/Play`
  - old: `Apply 1 Blind to a Unit, that Unit gains +16 ATK until the end of this turn. If this card is Activated, increase this card costs +1 AP.`
  - new: `Apply 1 Blind and 1 Infiltrate to a Unit, until the end of this turn: that Unit gains +20 ATK. That Unit Permanently costs +1AP.`
- `description`
  - old: `Apply 1 Blind to a Unit, that Unit gains +16 ATK until the end of this turn. If this card is Activated, increase this card costs +1 AP.`
  - new: `Apply 1 Blind and 1 Infiltrate to a Unit, until the end of this turn: that Unit gains +20 ATK. That Unit Permanently costs +1AP.`

### 85 Energy Capture
- `condition`
  - old: `If your opponent Activates an Effect:`
  - new: `If your opponent activates an Effect:`
- `description`
  - old: `If your opponent Activates an Effect: Apply 1 Rune to a Unit.`
  - new: `If your opponent activates an Effect: Apply 1 Rune to a Unit.`

### 86 Get Well Soon
- `condition`
  - old: `If your opponent Destroys one of your Unit's:`
  - new: `If your opponent Destroys one of your Units:`
- `description`
  - old: `If your opponent Destroys one of your Unit's: Apply 4 Medic to a Unit.`
  - new: `If your opponent Destroys one of your Units: Apply 4 Medic to a Unit.`

### 45 Magic Cylinder
- `On Summon/Play`
  - old: `Your opponent's loses HP equal to the Attacking Unit's ATK. If this card is Activated, increase this card costs +1 AP.`
  - new: `Your opponent takes -HP Damage equal to the Attacking Unit's ATK. If this Trap is activated, This Trap Permanently costs +1AP.`
- `description`
  - old: `If your opponent declares an attack in this Column: Your opponent's loses HP equal to the Attacking Unit's ATK. If this card is Activated, increase this card costs +1 AP.`
  - new: `If your opponent declares an attack in this Column: Your opponent takes -HP Damage equal to the Attacking Unit's ATK. If this Trap is activated, This Trap Permanently costs +1AP.`

### 46 Mirror Force
- `condition`
  - old: `If an opponent's declares an attack (while they have 4 or more cards on the Field):`
  - new: `If an opponent's declares an attack (while they control 4 or more cards):`
- `On Summon/Play`
  - old: `Destroy all your opponent's Unit's in Attack Stance.`
  - new: `Destroy your opponent's Units in Attack Stance.`
- `description`
  - old: `If an opponent's declares an attack (while they have 4 or more cards on the Field): Destroy all your opponent's Unit's in Attack Stance.`
  - new: `If an opponent's declares an attack (while they control 4 or more cards): Destroy your opponent's Units in Attack Stance.`

### 47 Damage Conversion
- `On Summon/Play`
  - old: `You gain HP equal to the Attacking Unit's ATK. If this Trap is Activated, increase this card's cost +1 AP.`
  - new: `You Heal +HP equal to the Attacking Unit's ATK. If this Trap is activated, This Trap Permanently costs +1AP.`
- `description`
  - old: `If your opponent declares an attack in this Column: You gain HP equal to the Attacking Unit's ATK. If this Trap is Activated, increase this card's cost +1 AP.`
  - new: `If your opponent declares an attack in this Column: You Heal +HP equal to the Attacking Unit's ATK. If this Trap is activated, This Trap Permanently costs +1AP.`

### 48 Overextend
- `condition`
  - old: `If your opponent Summons a Unit (and now has 3 or more Unit's on the Field):`
  - new: `If your opponent Summons a Unit (and now controls 3 or more Units):`
- `On Summon/Play`
  - old: `Your opponent's Unit with the highest ATK loses -20 ATK.`
  - new: `Your opponent's Unit with the highest ATK Permanently loses -20 ATK.`
- `description`
  - old: `If your opponent Summons a Unit (and now has 3 or more Unit's on the Field): Your opponent's Unit with the highest ATK loses -20 ATK.`
  - new: `If your opponent Summons a Unit (and now controls 3 or more Units): Your opponent's Unit with the highest ATK Permanently loses -20 ATK.`

### 49 Trap hole
- `condition`
  - old: `If your opponent Summons a 2 Cost or higher Unit:`
  - new: `If your opponent Summons a Unit:`
- `description`
  - old: `If your opponent Summons a 2 Cost or higher Unit: Apply 3 Paralyse to that Unit.`
  - new: `If your opponent Summons a Unit: Apply 3 Paralyse to that Unit.`

### 51 Rushed Recklessly
- `On Summon/Play`
  - old: `Until the end of this turn: your Unit's in this Column gain +8 DEF.`
  - new: `Until the end of this turn: your Units in this Column gain +8 DEF.`
- `description`
  - old: `If your opponent declares an attack: Until the end of this turn: your Unit's in this Column gain +8 DEF.`
  - new: `If your opponent declares an attack: Until the end of this turn: your Units in this Column gain +8 DEF.`

### 140 Energy Dispel
- `On Summon/Play`
  - old: `Negate the activation and Destroy that card. If this Trap is sent from the Field to Spent, Exhaust this Trap.`
  - new: `Destroy that card. If this Trap is sent from Field to Spent, this Trap Permanently costs +1AP.`
- `description`
  - old: `If your opponent activates an Effect: Negate the activation and Destroy that card. If this Trap is sent from the Field to Spent, Exhaust this Trap.`
  - new: `If your opponent activates an Effect: Destroy that card. If this Trap is sent from Field to Spent, this Trap Permanently costs +1AP.`

### 153 Hot Stove
- `On Summon/Play`
  - old: `Destroy that Power and your opponent loses -4 HP.`
  - new: `Destroy that Power, your opponent takes -4 HP Damage.`
- `description`
  - old: `If your opponent activates a Power Effect: Destroy that Power and your opponent loses -4 HP.`
  - new: `If your opponent activates a Power Effect: Destroy that Power, your opponent takes -4 HP Damage.`

### 163 Plan B
- `On Summon/Play`
  - old: `Destroy any number of cards on your Field, gain +10 HP for each card Destroyed.`
  - new: `Destroy any number of cards you Control, Heal +10 HP for each card Destroyed.`
- `description`
  - old: `If your opponent activates an Effect or declares an Attack: Destroy any number of cards on your Field, gain +10 HP for each card Destroyed.`
  - new: `If your opponent activates an Effect or declares an Attack: Destroy any number of cards you Control, Heal +10 HP for each card Destroyed.`

### 88 Elemental Mastery
- `index`
  - old: `129`
  - new: `130`
- `On Field`
  - old: `Your Type Advantage is now +12 ATK / DEF.`
  - new: `Your Type Advantage gains +6 ATK / DEF.`
- `description`
  - old: `Your Type Advantage is now +12 ATK / DEF.`
  - new: `Your Type Advantage gains +6 ATK / DEF.`
- `card_img`
  - old: `129.png`
  - new: `130.png`

### 53 Power of Normal
- `index`
  - old: `130`
  - new: `131`
- `On Field`
  - old: `All your Basic Unit's gain +8 ATK.`
  - new: `Your Basic Units gain +8 ATK.`
- `description`
  - old: `All your Basic Unit's gain +8 ATK.`
  - new: `Your Basic Units gain +8 ATK.`
- `card_img`
  - old: `130.png`
  - new: `131.png`

### 54 Strength in Unity
- `index`
  - old: `131`
  - new: `132`
- `On Field`
  - old: `Unit's you control gain +4 ATK / DEF for each unique Race you have on the Field.`
  - new: `Units you control gain +4 ATK / DEF for each unique Race on Units you Control.`
- `description`
  - old: `Unit's you control gain +4 ATK / DEF for each unique Race you have on the Field.`
  - new: `Units you control gain +4 ATK / DEF for each unique Race on Units you Control.`
- `card_img`
  - old: `131.png`
  - new: `132.png`

### 89 Fusion Laboratory
- `index`
  - old: `132`
  - new: `133`
- `name`
  - old: `Nether Portal`
  - new: `Fusion Laboratory`
- `cost`
  - old: `2`
  - new: `1`
- `On Field`
  - old: `Once per turn: you can spend 1 AP to Fusion Summon using Unit's on your Field.`
  - new: `Once per turn: you can lose -1 AP to Fusion Summon using Units you Control.`
- `description`
  - old: `Once per turn: you can spend 1 AP to Fusion Summon using Unit's on your Field.`
  - new: `Once per turn: you can lose -1 AP to Fusion Summon using Units you Control.`
- `card_img`
  - old: `132.png`
  - new: `133.png`

### 55 Spy
- `index`
  - old: `133`
  - new: `134`
- `On Field`
  - old: `Once per turn: you can lose -2 HP, Apply Reveal to a facedown card.`
  - new: `Once per turn: you can take -2 HP Damage, apply Reveal to a Spell/Trap card.`
- `description`
  - old: `Once per turn: you can lose -2 HP, Apply Reveal to a facedown card.`
  - new: `Once per turn: you can take -2 HP Damage, apply Reveal to a Spell/Trap card.`
- `card_img`
  - old: `133.png`
  - new: `134.png`

### 90 Chains of Binding
- `index`
  - old: `134`
  - new: `135`
- `On Field`
  - old: `Once per turn: you can Apply 1 Paralyse to a Unit.`
  - new: `Once per turn: you can apply 1 Paralyse to a Unit.`
- `description`
  - old: `Once per turn: you can Apply 1 Paralyse to a Unit.`
  - new: `Once per turn: you can apply 1 Paralyse to a Unit.`
- `card_img`
  - old: `134.png`
  - new: `135.png`

### 91 Ritual Sanct
- `index`
  - old: `135`
  - new: `136`
- `On Field`
  - old: `At the start of your turn: you can Apply 1 Rune to a Unit.`
  - new: `At the start of your turn: you can apply 1 Rune to a Unit.`
- `description`
  - old: `At the start of your turn: you can Apply 1 Rune to a Unit.`
  - new: `At the start of your turn: you can apply 1 Rune to a Unit.`
- `card_img`
  - old: `135.png`
  - new: `136.png`

### 92 Preservation Jar
- `index`
  - old: `136`
  - new: `137`
- `On Field`
  - old: `Once per turn, you can Apply 1 Retain to a card in your Hand.`
  - new: `Once per turn, you can apply 1 Retain to a card in your Hand.`
- `description`
  - old: `Once per turn, you can Apply 1 Retain to a card in your Hand.`
  - new: `Once per turn, you can apply 1 Retain to a card in your Hand.`
- `card_img`
  - old: `136.png`
  - new: `137.png`

### 137 Unstable Fusions
- `index`
  - old: `137`
  - new: `138`
- `On Field`
  - old: `You can now use Unit's from your Hand as Tribute for a Fusion Summon. Exhaust Unit's used from your Hand.`
  - new: `You can Exhaust Units from your Hand as Tribute for a Fusion Summon.`
- `description`
  - old: `You can now use Unit's from your Hand as Tribute for a Fusion Summon. Exhaust Unit's used from your Hand.`
  - new: `You can Exhaust Units from your Hand as Tribute for a Fusion Summon.`
- `card_img`
  - old: `137.png`
  - new: `138.png`

### 148 Martyrdom
- `index`
  - old: `138`
  - new: `139`
- `On Field`
  - old: `Once per turn, you can Exhaust a Unit from your Field, Destroy a Unit.`
  - new: `Once per turn, you can Exhaust a Unit you Control, Destroy a Unit.`
- `description`
  - old: `Once per turn, you can Exhaust a Unit from your Field, Destroy a Unit.`
  - new: `Once per turn, you can Exhaust a Unit you Control, Destroy a Unit.`
- `card_img`
  - old: `138.png`
  - new: `139.png`

### 149 Marked by the Abyss
- `index`
  - old: `139`
  - new: `140`
- `On Field`
  - old: `You cannot Activate this Power if your Deck contains a 0 Cost card. While you have a card in your Exhaust: gain +1 AP.`
  - new: `You cannot activate this Power if your Deck contains a 0 Cost card. At the start of your turn: if you have 1 or more cards in your Exhaust, gain +1 AP.`
- `description`
  - old: `You cannot Activate this Power if your Deck contains a 0 Cost card. While you have a card in your Exhaust: gain +1 AP.`
  - new: `You cannot activate this Power if your Deck contains a 0 Cost card. At the start of your turn: if you have 1 or more cards in your Exhaust, gain +1 AP.`
- `card_img`
  - old: `139.png`
  - new: `140.png`

### 139 Magical Council
- `index`
  - old: `140`
  - new: `141`
- `On Field`
  - old: `Your Spells now cost -1 AP.`
  - new: `Your Spells cost -1 AP.`
- `description`
  - old: `Your Spells now cost -1 AP.`
  - new: `Your Spells cost -1 AP.`
- `card_img`
  - old: `140.png`
  - new: `141.png`

### 166 Saboteurs Guild
- `index`
  - old: `141`
  - new: `142`
- `On Field`
  - old: `Your Traps now cost -1 AP.`
  - new: `Your Traps cost -1 AP.`
- `description`
  - old: `Your Traps now cost -1 AP.`
  - new: `Your Traps cost -1 AP.`
- `card_img`
  - old: `141.png`
  - new: `142.png`

### 167 Shaman's Snunday Brew
- `index`
  - old: `142`
  - new: `143`
- `On Field`
  - old: `Once per turn: you can gain +4 HP or your opponent loses -4 HP.`
  - new: `Once per turn: you can Heal +4 HP or your opponent takes -4 HP Damage.`
- `description`
  - old: `Once per turn: you can gain +4 HP or your opponent loses -4 HP.`
  - new: `Once per turn: you can Heal +4 HP or your opponent takes -4 HP Damage.`
- `card_img`
  - old: `142.png`
  - new: `143.png`

### 168 Tactical Arrangements
- `index`
  - old: `143`
  - new: `144`
- `cost`
  - old: `2`
  - new: `1`
- `On Field`
  - old: `Once per turn: you can send a card from Hand to Spent, draw 1 card.`
  - new: `Once per turn: you can draw a card, discard a card.`
- `description`
  - old: `Once per turn: you can send a card from Hand to Spent, draw 1 card.`
  - new: `Once per turn: you can draw a card, discard a card.`
- `card_img`
  - old: `143.png`
  - new: `144.png`

### 169 Options
- `index`
  - old: `144`
  - new: `145`
- `On Field`
  - old: `You now draw 5 cards during your Draw Phase.`
  - new: `At the start of your turn: draw a card.`
- `description`
  - old: `You now draw 5 cards during your Draw Phase.`
  - new: `At the start of your turn: draw a card.`
- `card_img`
  - old: `144.png`
  - new: `145.png`

### 178 Reinforcements
- `index`
  - old: `145`
  - new: `146`
- `cost`
  - old: `3`
  - new: `2`
- `On Field`
  - old: `If only your opponent controls a Unit, your Unit's now cost -1 AP.`
  - new: `If only your opponent Controls a Unit, your Units cost -2 AP.`
- `description`
  - old: `If only your opponent controls a Unit, your Unit's now cost -1 AP.`
  - new: `If only your opponent Controls a Unit, your Units cost -2 AP.`
- `card_img`
  - old: `145.png`
  - new: `146.png`

### 179 Tyrants Lantern
- `index`
  - old: `146`
  - new: `147`
- `On Field`
  - old: `Your Fire Unit's gain + 12 ATK. If your Fire Unit is Destroyed, you lose -6 HP and then your opponent loses -6 HP.`
  - new: `Your Fire Units gain +12 ATK. If your Fire Unit is Destroyed, you take -6 HP Damage, your opponent takes -6 HP Damage.`
- `description`
  - old: `Your Fire Unit's gain + 12 ATK. If your Fire Unit is Destroyed, you lose -6 HP and then your opponent loses -6 HP.`
  - new: `Your Fire Units gain +12 ATK. If your Fire Unit is Destroyed, you take -6 HP Damage, your opponent takes -6 HP Damage.`
- `card_img`
  - old: `146.png`
  - new: `147.png`

### 44 Draw Virus
- `index`
  - old: `147`
  - new: `148`
- `cost`
  - old: `3`
  - new: `2`
- `card_img`
  - old: `147.png`
  - new: `148.png`

### 56 Razeon Storm
- `index`
  - old: `148`
  - new: `149`
- `On Summon/Play`
  - old: `Apply Reveal to all facedown cards.`
  - new: `Apply Reveal to all Spell/Trap cards.`
- `On Destruction`
  - old: `Apply 1 Paralyse to all Unit's.`
  - new: `Apply 1 Paralyse to all Units.`
- `description`
  - old: `On Summon: Apply Reveal to all facedown cards. On Destroy: Apply 1 Paralyse to all Unit's.`
  - new: `On Summon: Apply Reveal to all Spell/Trap cards. On Destroy: Apply 1 Paralyse to all Units.`
- `card_img`
  - old: `148.png`
  - new: `149.png`

### 57 Geolock Colossus
- `index`
  - old: `149`
  - new: `150`
- `On Summon/Play`
  - old: `You can Apply 1 Infiltrate and 1 Nimble to your Unit's.`
  - new: `You can apply 1 Infiltrate and 1 Nimble to your Units.`
- `On Field`
  - old: `Once per turn: You can Change Stance of your opponent's Unprotected Unit's.`
  - new: `Once per turn: you can Change Stance of your opponent's Unprotected Units.`
- `description`
  - old: `On Summon: You can Apply 1 Infiltrate and 1 Nimble to your Unit's. Once per turn: You can Change Stance of your opponent's Unprotected Unit's.`
  - new: `On Summon: You can apply 1 Infiltrate and 1 Nimble to your Units. Once per turn: you can Change Stance of your opponent's Unprotected Units.`
- `card_img`
  - old: `149.png`
  - new: `150.png`

### 58 Infernogate the Three-Fanged
- `index`
  - old: `150`
  - new: `151`
- `On Field`
  - old: `Once per turn: you can Apply 10 Burn to all Unit's.`
  - new: `Once per turn: you can apply 10 Burn to all Units.`
- `description`
  - old: `On Summon: You can Destroy a Power. Once per turn: you can Apply 10 Burn to all Unit's.`
  - new: `On Summon: You can Destroy a Power. Once per turn: you can apply 10 Burn to all Units.`
- `card_img`
  - old: `150.png`
  - new: `151.png`

### 59 Abysslord the Tidecaller
- `index`
  - old: `151`
  - new: `152`
- `On Summon/Play`
  - old: `You can Destroy a Spell or Trap.`
  - new: `You can Destroy a Spell/Trap.`
- `On Field`
  - old: `Once per turn: you can Apply 1 Paralyse to a Unit. Once per turn you can Apply 1 Infiltrate to a Unit.`
  - new: `Once per turn: you can apply 1 Paralyse to a Unit. Once per turn you can apply 1 Infiltrate to a Unit.`
- `description`
  - old: `On Summon: You can Destroy a Spell or Trap. Once per turn: you can Apply 1 Paralyse to a Unit. Once per turn you can Apply 1 Infiltrate to a Unit.`
  - new: `On Summon: You can Destroy a Spell/Trap. Once per turn: you can apply 1 Paralyse to a Unit. Once per turn you can apply 1 Infiltrate to a Unit.`
- `card_img`
  - old: `151.png`
  - new: `152.png`

### 60 Rotmaw Risen
- `index`
  - old: `152`
  - new: `153`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Field`
  - old: `Once per turn: you can Apply 3 Poison to a Unit.`
  - new: `Once per turn: you can apply 3 Poison to a Unit.`
- `description`
  - old: `On Summon: Apply 3 Debilitate to a Unit. Once per turn: you can Apply 3 Poison to a Unit.`
  - new: `On Summon: Apply 3 Debilitate to a Unit. Once per turn: you can apply 3 Poison to a Unit.`
- `card_img`
  - old: `152.png`
  - new: `153.png`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 61 Sanctified Blade
- `index`
  - old: `153`
  - new: `154`
- `type`
  - old: `Heavenly`
  - new: `Light`
- `condition`
  - old: `Warrior Unit + Heavenly Unit`
  - new: `Warrior Unit + Light Unit`
- `On Summon/Play`
  - old: `You can Summon a 1 Cost or lower Heavenly Unit from your Spent into this Column.`
  - new: `You can Summon a 1 Cost or lower Light Unit from your Spent into this Column.`
- `On Field`
  - old: `Once per turn: you can Apply 3 Medic to an Adjacent Unit.`
  - new: `Once per turn: you can apply 3 Medic to an Adjacent Unit.`
- `description`
  - old: `On Summon: You can Summon a 1 Cost or lower Heavenly Unit from your Spent into this Column. Once per turn: you can Apply 3 Medic to an Adjacent Unit.`
  - new: `On Summon: You can Summon a 1 Cost or lower Light Unit from your Spent into this Column. Once per turn: you can apply 3 Medic to an Adjacent Unit.`
- `card_img`
  - old: `153.png`
  - new: `154.png`
- `type_icon`
  - old: `Card/types/heavenly.png`
  - new: `Card/types/light.png`
- `material`
  - old: `Warrior Unit + Heavenly Unit`
  - new: `Warrior Unit + Light Unit`

### 93 Bastion Wyrm
- `index`
  - old: `154`
  - new: `155`
- `card_img`
  - old: `154.png`
  - new: `155.png`

### 94 Mirrorflesh Construct
- `index`
  - old: `155`
  - new: `156`
- `condition`
  - old: `2 Unit's with the same Type`
  - new: `2 Units with the same Type`
- `On Summon/Play`
  - old: `This Unit's ATK/DEF/Type becomes the combined ATK/DEF/Type of the Unit's Tributed.`
  - new: `This Unit's ATK/DEF/Type becomes the combined ATK/DEF/Type of the Units Tributed.`
- `description`
  - old: `On Summon: This Unit's ATK/DEF/Type becomes the combined ATK/DEF/Type of the Unit's Tributed. On Destroy: Destroy a Unit with the same Type as this Unit.`
  - new: `On Summon: This Unit's ATK/DEF/Type becomes the combined ATK/DEF/Type of the Units Tributed. On Destroy: Destroy a Unit with the same Type as this Unit.`
- `card_img`
  - old: `155.png`
  - new: `156.png`
- `material`
  - old: `2 Unit's with the same Type`
  - new: `2 Units with the same Type`

### 141 Bahatia
- `index`
  - old: `156`
  - new: `157`
- `condition`
  - old: `Necrotic Unit + Heavenly Unit`
  - new: `Dark Unit + Light Unit`
- `On Field`
  - old: `Once per turn: this Unit's Type can become one of Physical, Heavenly or Necrotic. Your opponent cannot summon Unit's with the same Type as this Unit.`
  - new: `Once per turn: this Unit's Type can become Physical, Light or Dark. your opponent cannot summon Units with the same Type as this Unit.`
- `description`
  - old: `Once per turn: this Unit's Type can become one of Physical, Heavenly or Necrotic. Your opponent cannot summon Unit's with the same Type as this Unit. On Destroy: You can make a Unit with the same Type as this Unit lose -30 ATK/DEF.`
  - new: `Once per turn: this Unit's Type can become Physical, Light or Dark. your opponent cannot summon Units with the same Type as this Unit. On Destroy: You can make a Unit with the same Type as this Unit lose -30 ATK/DEF.`
- `card_img`
  - old: `156.png`
  - new: `157.png`
- `material`
  - old: `Necrotic Unit + Heavenly Unit`
  - new: `Dark Unit + Light Unit`

### 142 Gojirun
- `index`
  - old: `157`
  - new: `158`
- `card_img`
  - old: `157.png`
  - new: `158.png`

### 143 Typhoon Simorgh
- `index`
  - old: `158`
  - new: `159`
- `On Field`
  - old: `Once per turn, you can Apply 1 Nimble to all your Unit's. Once per turn, you can Apply 1 Blind to all your opponent's Unit's.`
  - new: `Once per turn, you can apply 1 Nimble to your Units. Once per turn, you can apply 1 Blind to your opponent's Units.`
- `description`
  - old: `Once per turn, you can Apply 1 Nimble to all your Unit's. Once per turn, you can Apply 1 Blind to all your opponent's Unit's.`
  - new: `Once per turn, you can apply 1 Nimble to your Units. Once per turn, you can apply 1 Blind to your opponent's Units.`
- `card_img`
  - old: `158.png`
  - new: `159.png`

### 144 Stone Guardian
- `index`
  - old: `159`
  - new: `160`
- `On Summon/Play`
  - old: `You can Apply 1 Cleanse to a Unit.`
  - new: `You can apply 1 Cleanse to a Unit.`
- `On Field`
  - old: `This Unit cannot be Destroyed by battle with a Lightning Unit.`
  - new: `This Unit cannot be Destroyed by Battle with a Lightning Unit.`
- `description`
  - old: `On Summon: You can Apply 1 Cleanse to a Unit. This Unit cannot be Destroyed by battle with a Lightning Unit. On Destroy: You can add an Earth Unit from Spent or Draw to Hand.`
  - new: `On Summon: You can apply 1 Cleanse to a Unit. This Unit cannot be Destroyed by Battle with a Lightning Unit. On Destroy: You can add an Earth Unit from Spent or Draw to Hand.`
- `card_img`
  - old: `159.png`
  - new: `160.png`

### 145 Trigonam
- `index`
  - old: `160`
  - new: `161`
- `On Summon/Play`
  - old: `Apply 10 Burn to all Unit's.`
  - new: `Apply 10 Burn to all Units.`
- `On Field`
  - old: `Once per turn: you can spend -1 AP, gain +10 HP.`
  - new: `Once per turn: you can lose -1 AP, Heal +10 HP.`
- `description`
  - old: `On Summon: Apply 10 Burn to all Unit's. Once per turn: you can spend -1 AP, gain +10 HP.`
  - new: `On Summon: Apply 10 Burn to all Units. Once per turn: you can lose -1 AP, Heal +10 HP.`
- `card_img`
  - old: `160.png`
  - new: `161.png`

### 146 Akiramari
- `index`
  - old: `161`
  - new: `162`
- `On Summon/Play`
  - old: `Apply 5 Medic to all Basic Unit's.`
  - new: `Apply 5 Medic to all Basic Units.`
- `description`
  - old: `On Summon: Apply 5 Medic to all Basic Unit's. On Destroy: You can Summon a Basic Unit from your Spent or Draw to the Zone this Unit was originally in.`
  - new: `On Summon: Apply 5 Medic to all Basic Units. On Destroy: You can Summon a Basic Unit from your Spent or Draw to the Zone this Unit was originally in.`
- `card_img`
  - old: `161.png`
  - new: `162.png`

### 147 Demented Apparition
- `index`
  - old: `162`
  - new: `163`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `condition`
  - old: `Monster Unit + Necrotic Unit`
  - new: `Monster Unit + Dark Unit`
- `On Summon/Play`
  - old: `Apply 2 Paralyse to all your opponent's Unprotected Unit's.`
  - new: `Apply 2 Paralyse to your opponent's Unprotected Units.`
- `On Field`
  - old: `At the start of your turn: your opponent's Unit's lose -8 DEF. If your opponent's Unit attacks, then it must attack this Unit.`
  - new: `At the start of your turn: your opponent's Units lose -8 DEF. If your opponent's Unit attacks, then it must attack this Unit.`
- `On Destruction`
  - old: `Change Stance of all Unit's.`
  - new: `Change Stance of all Units.`
- `description`
  - old: `On Summon: Apply 2 Paralyse to all your opponent's Unprotected Unit's. At the start of your turn: your opponent's Unit's lose -8 DEF. If your opponent's Unit attacks, then it must attack this Unit. On Destroy: Change Stance of all Unit's.`
  - new: `On Summon: Apply 2 Paralyse to your opponent's Unprotected Units. At the start of your turn: your opponent's Units lose -8 DEF. If your opponent's Unit attacks, then it must attack this Unit. On Destroy: Change Stance of all Units.`
- `card_img`
  - old: `162.png`
  - new: `163.png`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`
- `material`
  - old: `Monster Unit + Necrotic Unit`
  - new: `Monster Unit + Dark Unit`

### 181 Solomon, the Tyrannical
- `On Field`
  - old: `Once per turn: While this Unit is Protecting a Unit: you can Exhaust that Unit, Apply 1 Eternal to this Unit and gain +1 AP.`
  - new: `Once per turn: While this Unit is Protecting a Unit: you can Exhaust that Unit, apply 1 Eternal to this Unit and gain +1 AP.`
- `On Destruction`
  - old: `You lose -12 HP.`
  - new: `You take -12 HP Damage.`
- `description`
  - old: `On Summon: Apply 2 Pierce to this Unit. Once per turn: While this Unit is Protecting a Unit: you can Exhaust that Unit, Apply 1 Eternal to this Unit and gain +1 AP. On Destroy: You lose -12 HP.`
  - new: `On Summon: Apply 2 Pierce to this Unit. Once per turn: While this Unit is Protecting a Unit: you can Exhaust that Unit, apply 1 Eternal to this Unit and gain +1 AP. On Destroy: You take -12 HP Damage.`

### 151 Ultimate Dragon
- `On Field`
  - old: `Once per turn: you can Apply 10 Burn or 4 Poison or 1 Curse to a Unit.`
  - new: `Once per turn: you can apply 10 Burn or 4 Poison or 1 Curse to a Unit.`
- `On Destruction`
  - old: `You can double all Debuffs on the Field.`
  - new: `You can double all Debuffs.`
- `description`
  - old: `Once per turn: you can Apply 10 Burn or 4 Poison or 1 Curse to a Unit. On Destroy: You can double all Debuffs on the Field.`
  - new: `Once per turn: you can apply 10 Burn or 4 Poison or 1 Curse to a Unit. On Destroy: You can double all Debuffs.`

### 98 Raging Inferno
- `On Field`
  - old: `Once per turn: you can Apply Reveal to a facedown card.`
  - new: `Once per turn: you can apply Reveal to a Spell/Trap.`
- `description`
  - old: `On Summon: Apply 8 Burn to this Unit. Once per turn: you can Apply Reveal to a facedown card. On Destroy: Apply 4 Burn to the Unit that Destroyed this Unit.`
  - new: `On Summon: Apply 8 Burn to this Unit. Once per turn: you can apply Reveal to a Spell/Trap. On Destroy: Apply 4 Burn to the Unit that Destroyed this Unit.`

### 62 Naturewrath Ascendant
- `index`
  - old: `168`
  - new: `167`
- `On Field`
  - old: `Once per turn: you can Apply 1 Debilitate to a Unit in this Column.`
  - new: `Once per turn: you can apply 1 Debilitate to a Unit in this Column.`
- `On Destruction`
  - old: `You can Apply 1 Curse to a Unit.`
  - new: `You can apply 1 Curse to a Unit.`
- `description`
  - old: `On Summon: Apply 1 Curse to this Unit. Once per turn: you can Apply 1 Debilitate to a Unit in this Column. On Destroy: You can Apply 1 Curse to a Unit.`
  - new: `On Summon: Apply 1 Curse to this Unit. Once per turn: you can apply 1 Debilitate to a Unit in this Column. On Destroy: You can apply 1 Curse to a Unit.`
- `card_img`
  - old: `168.png`
  - new: `167.png`

### 63 The Last Foundation
- `index`
  - old: `169`
  - new: `168`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Summon/Play`
  - old: `Apply Reveal to all Spells and Traps.`
  - new: `Apply Reveal to all Spells/Traps.`
- `On Field`
  - old: `At the end of your turn: Apply 1 Eternal to this Unit.`
  - new: `At the end of your turn: apply 1 Eternal to this Unit.`
- `description`
  - old: `On Summon: Apply Reveal to all Spells and Traps. At the end of your turn: Apply 1 Eternal to this Unit. On Destroy: Destroy your opponent's Unit with the lowest ATK.`
  - new: `On Summon: Apply Reveal to all Spells/Traps. At the end of your turn: apply 1 Eternal to this Unit. On Destroy: Destroy your opponent's Unit with the lowest ATK.`
- `card_img`
  - old: `169.png`
  - new: `168.png`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 64 Necrovast the Undying
- `index`
  - old: `170`
  - new: `169`
- `type`
  - old: `Necrotic`
  - new: `Dark`
- `On Field`
  - old: `While this Unit is on the Field: this Unit gains +6 ATK/DEF x the number of cards in your Exhaust.`
  - new: `This Unit gains +6 ATK/DEF x the number of cards in your Exhaust.`
- `description`
  - old: `While this Unit is on the Field: this Unit gains +6 ATK/DEF x the number of cards in your Exhaust. On Destroy: You can move a card from Exhaust to Draw.`
  - new: `This Unit gains +6 ATK/DEF x the number of cards in your Exhaust. On Destroy: You can move a card from Exhaust to Draw.`
- `card_img`
  - old: `170.png`
  - new: `169.png`
- `type_icon`
  - old: `Card/types/necrotic.png`
  - new: `Card/types/dark.png`

### 66 Nyxthral, Beyond Reason
- `index`
  - old: `171`
  - new: `170`
- `On Field`
  - old: `Once per turn: you can draw a card, send a card from Hand to Spent.`
  - new: `Once per turn: you can draw a card, discard a card.`
- `description`
  - old: `On Summon: Apply 1 Eternal to an Adjacent Unit. Once per turn: you can draw a card, send a card from Hand to Spent.`
  - new: `On Summon: Apply 1 Eternal to an Adjacent Unit. Once per turn: you can draw a card, discard a card.`
- `card_img`
  - old: `171.png`
  - new: `170.png`

### 95 Mimic
- `index`
  - old: `172`
  - new: `171`
- `On Destruction`
  - old: `Double all Debuffs on your opponent's Unit's.`
  - new: `Double all Debuffs on your opponent's Units.`
- `description`
  - old: `On Summon: Apply 2 Paralyse to an opponent's Unprotected Unit in this Column, this Unit's ATK/DEF/Type becomes the ATK/DEF/Type of that Unit. On Destroy: Double all Debuffs on your opponent's Unit's.`
  - new: `On Summon: Apply 2 Paralyse to an opponent's Unprotected Unit in this Column, this Unit's ATK/DEF/Type becomes the ATK/DEF/Type of that Unit. On Destroy: Double all Debuffs on your opponent's Units.`
- `card_img`
  - old: `172.png`
  - new: `171.png`

### 65 The Creeping Null
- `index`
  - old: `173`
  - new: `172`
- `On Summon/Play`
  - old: `Apply 1 Paralyse to your opponent's Unit's.`
  - new: `Apply 1 Paralyse to your opponent's Units.`
- `On Field`
  - old: `Once per turn: you can Apply 1 Debilitate to a Unit.`
  - new: `Once per turn: you can apply 1 Debilitate to a Unit.`
- `description`
  - old: `On Summon: Apply 1 Paralyse to your opponent's Unit's. Once per turn: you can Apply 1 Debilitate to a Unit.`
  - new: `On Summon: Apply 1 Paralyse to your opponent's Units. Once per turn: you can apply 1 Debilitate to a Unit.`
- `card_img`
  - old: `173.png`
  - new: `172.png`

### 97 The Legendary Swordsman
- `index`
  - old: `174`
  - new: `173`
- `On Field`
  - old: `Once per turn: you can Apply 1 Infiltrate to this Unit. While your HP is lower than your opponent's, this Unit gains +30 ATK.`
  - new: `Once per turn: you can apply 1 Infiltrate to this Unit. While your HP is lower than your opponent's, this Unit gains +30 ATK.`
- `On Destruction`
  - old: `You can Apply 2 Rune to a Warrior Unit.`
  - new: `You can apply 2 Rune to a Warrior Unit.`
- `description`
  - old: `On Summon: Apply 3 Cleanse to this Unit. Once per turn: you can Apply 1 Infiltrate to this Unit. While your HP is lower than your opponent's, this Unit gains +30 ATK. On Destroy: You can Apply 2 Rune to a Warrior Unit.`
  - new: `On Summon: Apply 3 Cleanse to this Unit. Once per turn: you can apply 1 Infiltrate to this Unit. While your HP is lower than your opponent's, this Unit gains +30 ATK. On Destroy: You can apply 2 Rune to a Warrior Unit.`
- `card_img`
  - old: `174.png`
  - new: `173.png`

### 183 Yamata, Spirit of the Flame
- `index`
  - old: `175`
  - new: `174`
- `On Field`
  - old: `At the start of your turn: your opponent loses -6 HP.`
  - new: `At the start of your turn: your opponent takes -6 HP Damage.`
- `description`
  - old: `On Summon: Apply 8 Eternal to this Unit. At the start of your turn: your opponent loses -6 HP. On Destroy: You can add a Power from Spent or Draw to Hand.`
  - new: `On Summon: Apply 8 Eternal to this Unit. At the start of your turn: your opponent takes -6 HP Damage. On Destroy: You can add a Power from Spent or Draw to Hand.`
- `card_img`
  - old: `175.png`
  - new: `174.png`

### 96 Roma, Exhile of The Order
- `index`
  - old: `176`
  - new: `175`
- `On Field`
  - old: `Once per turn: you can lose -10 HP, Destroy a Unit with ATK lower than this Unit's ATK.`
  - new: `Once per turn: you can take -10 HP Damage, Destroy a Unit with ATK lower than this Unit's ATK.`
- `description`
  - old: `On Summon: This Unit becomes +12 ATK/DEF x the amount of Runes used for it's Summon. Once per turn: you can lose -10 HP, Destroy a Unit with ATK lower than this Unit's ATK.`
  - new: `On Summon: This Unit becomes +12 ATK/DEF x the amount of Runes used for it's Summon. Once per turn: you can take -10 HP Damage, Destroy a Unit with ATK lower than this Unit's ATK.`
- `card_img`
  - old: `176.png`
  - new: `175.png`

### 170 Grandmother Kaya
- `index`
  - old: `177`
  - new: `176`
- `atk`
  - old: `16`
  - new: `4`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `On Summon/Play`
  - old: `You can send a card from Hand to Spent, gain +1 AP.`
  - new: `You can discard a card, gain +1 AP.`
- `On Destruction`
  - old: `You can lose -10 HP, add a card from Spent to Hand.`
  - new: `You can take -10 HP Damage, add a card from Spent to Hand.`
- `description`
  - old: `On Summon: You can send a card from Hand to Spent, gain +1 AP. On Destroy: You can lose -10 HP, add a card from Spent to Hand.`
  - new: `On Summon: You can discard a card, gain +1 AP. On Destroy: You can take -10 HP Damage, add a card from Spent to Hand.`
- `card_img`
  - old: `177.png`
  - new: `176.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`

### 171 Flying Sandworm
- `index`
  - old: `179`
  - new: `177`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `On Field`
  - old: `At the start of your turn: gain +6 ATK. While this Unit is on the Field: this Unit can attack your opponent directly.`
  - new: `At the start of your turn: gain +6 ATK. This Unit can attack your opponent directly.`
- `description`
  - old: `At the start of your turn: gain +6 ATK. While this Unit is on the Field: this Unit can attack your opponent directly. On Destroy: Exhaust this Unit.`
  - new: `At the start of your turn: gain +6 ATK. This Unit can attack your opponent directly. On Destroy: Exhaust this Unit.`
- `card_img`
  - old: `179.png`
  - new: `177.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`

### 172 Tyde, Councillor of The Order
- `index`
  - old: `180`
  - new: `178`
- `atk`
  - old: `24`
  - new: `18`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `card_img`
  - old: `180.png`
  - new: `178.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`

### 173 Thunderclap Dragon
- `index`
  - old: `181`
  - new: `179`
- `atk`
  - old: `22`
  - new: `20`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `On Summon/Play`
  - old: `Your opponent loses -4 HP x the amount of your opponent's Unit's.`
  - new: `Your opponent takes -4 HP Damage x the amount of your opponent's Units.`
- `On Destruction`
  - old: `Apply 1 Paralyse to all Unit's.`
  - new: `Apply 1 Paralyse to all Units.`
- `description`
  - old: `On Summon: Your opponent loses -4 HP x the amount of your opponent's Unit's. On Destroy: Apply 1 Paralyse to all Unit's.`
  - new: `On Summon: Your opponent takes -4 HP Damage x the amount of your opponent's Units. On Destroy: Apply 1 Paralyse to all Units.`
- `card_img`
  - old: `181.png`
  - new: `179.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`

### 174 Cliff the Flying Bison
- `index`
  - old: `182`
  - new: `180`
- `atk`
  - old: `16`
  - new: `8`
- `def`
  - old: `28`
  - new: `18`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `card_img`
  - old: `182.png`
  - new: `180.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`

### 175 Boom, Councillor of The Order
- `index`
  - old: `184`
  - new: `182`
- `atk`
  - old: `30`
  - new: `26`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `On Summon/Play`
  - old: `Change Stance of your opponent's Unit's.`
  - new: `Change Stance of your opponent's Units.`
- `On Field`
  - old: `Once per turn you can Apply 1 Debilitate to a Unit.`
  - new: `Once per turn: you can apply 1 Debilitate to a Unit.`
- `On Destruction`
  - old: `You can make your Unit's gain +10 DEF.`
  - new: `Your Units Permanently gain +10 DEF.`
- `description`
  - old: `On Summon: Change Stance of your opponent's Unit's. Once per turn you can Apply 1 Debilitate to a Unit. On Destroy: You can make your Unit's gain +10 DEF.`
  - new: `On Summon: Change Stance of your opponent's Units. Once per turn: you can apply 1 Debilitate to a Unit. On Destroy: Your Units Permanently gain +10 DEF.`
- `card_img`
  - old: `184.png`
  - new: `182.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`

### 176 Tritu, Heir to the Ocean Tribe
- `index`
  - old: `185`
  - new: `183`
- `def`
  - old: `18`
  - new: `?`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `On Summon/Play`
  - old: `This Unit's ATK becomes the combined ATK of all Water Unit's on the Field.`
  - new: `This Unit's ATK/DEF becomes the combined ATK/DEF of all Water Units on the Field.`
- `On Field`
  - old: `Once per turn: you can Apply 2 Medic to Adjacent Unit's.`
  - new: `Once per turn: you can apply 2 Medic to Adjacent Units.`
- `description`
  - old: `On Summon: This Unit's ATK becomes the combined ATK of all Water Unit's on the Field. Once per turn: you can Apply 2 Medic to Adjacent Unit's.`
  - new: `On Summon: This Unit's ATK/DEF becomes the combined ATK/DEF of all Water Units on the Field. Once per turn: you can apply 2 Medic to Adjacent Units.`
- `card_img`
  - old: `185.png`
  - new: `183.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`

### 177 The Illusionist
- `index`
  - old: `186`
  - new: `184`
- `condition`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
- `On Field`
  - old: `While it is your turn: this Unit gains + 30 ATK. This Unit's attacks do not inflict Damage.`
  - new: `If it is your turn, this Unit gains +30 ATK. This Unit's attacks do not inflict Damage.`
- `On Destruction`
  - old: `You can move a 1 cost or lower card from Exhaust to Draw.`
  - new: `You can move a 1 Cost or lower card from Exhaust to Draw.`
- `description`
  - old: `While it is your turn: this Unit gains + 30 ATK. This Unit's attacks do not inflict Damage. On Destroy: You can move a 1 cost or lower card from Exhaust to Draw.`
  - new: `If it is your turn, this Unit gains +30 ATK. This Unit's attacks do not inflict Damage. On Destroy: You can move a 1 Cost or lower card from Exhaust to Draw.`
- `card_img`
  - old: `186.png`
  - new: `184.png`
- `material`
  - old: `Exhaust Unit's from Spent with Cost equivilant to Arcane.`
  - new: `Exhaust Units from Spent with cost equivilant to Arcane.`
