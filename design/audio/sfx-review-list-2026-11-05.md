# Sound effects for review (L1, 5 Nov 2026)

All 108 cues were generated with ElevenLabs (`eleven_text_to_sound_v2`) and replace every earlier sound. 59 replace existing cues; 49 are new (marked NEW). Files: `rldb/assets/audio/sfx/<cue>.wav`. Alternate takes: `production/audio-staging/` (not in git). How each take was chosen: `design/audio/sfx-design-2026-11-05.md`.

**Listen to these first** (least confident): ritual_choir, fusion_vortex, hp_low_heartbeat, boom, card_play, card_set, toggle_on, toggle_off, slider_tick, ap_gain, charge, victory_big, game_start, victory, defeat.

**Unused for now:** timer_tick and timer_warning (there is no turn time limit to warn about).

**UI: clicks, hovers, toggles and panels**
- `ui_hover`: Pointer enters a button or menu item (rate-limited, jittered).
- `card_hover`: Pointer enters a card (hand, draft, rewards, catalogue).
- `select`: Generic selection: a card, a chat open, an inspect, a list row.
- `click_primary`: Gold (primary) button or menu item press.
- `click_secondary`: Brown (secondary) button press.
- `back`: Back / Close / Cancel / Leave buttons and Esc.
- `confirm`: Confirming a choice (end turn, prompt OK, selection done).
- `cancel`: Backing out of a selection or targeting.
- `deny`: Illegal action (no AP, invalid target, deck limit).
- `tab`: Tab switch.
- `toggle_on`: Check box / switch turned on.
- `toggle_off`: Check box / switch turned off.
- `slider_tick` (NEW): Volume slider step / drag end.
- `panel_open`: Modal / panel opens.
- `panel_close`: Modal / panel closes.
- `customise_select` (NEW): Picking a cosmetic / table / card back option (L28).
- `deck_add`: Card added to a deck in the deck builder.
- `deck_remove`: Card removed from a deck.
- `ap_gain`: Action Points gained (AP gem lights).
- `ap_loss`: Action Points spent / lost.
- `reward_pick`: A reward is taken.
- `draft_pick` (NEW): A draft card is picked (L26).
- `sacrifice_mode_on` (NEW): Sacrifice mode armed (L5).
- `sacrifice_mode_off` (NEW): Sacrifice mode cancelled (L5).
- `target_arm` (NEW): Targeting arrow appears (L7).
- `target_lock` (NEW): Target chosen (L7).

**Notices and flow**
- `chat`: Chat message while the chat box is closed.
- `chat_pop`: New chat message preview bubble pops out.
- `step_done`: Tutorial step completed.
- `turn`: A new turn begins.
- `phase`: Phase change.
- `notice`: Generic notice (prompt shown, coin result, tutorial).
- `prompt_alert` (NEW): Your response is needed (L16 prompts).
- `opponent_responding` (NEW): The opponent is responding (L16 notice).
- `timer_tick` (NEW): Low-time tick (L18).
- `timer_warning` (NEW): Time almost out (L18).
- `series_point` (NEW): A series point is won (L3).
- `reward_reveal`: Rewards panel opens.

**Card movement**
- `zone_pick` (NEW): Choosing a board zone (where to place a card).
- `card_draw`: Each card drawn (also pile browser deal, deck select).
- `card_play`: A card is played face up to a zone.
- `card_set`: A card is set face down (backrow). Same for every card: hides identity.
- `card_discard` (NEW): Card discarded to the Spent pile.
- `card_return` (NEW): Card returned to hand.
- `card_shuffle` (NEW): Deck shuffled at game start.
- `card_flip` (NEW): Face-down card revealed (identical for every card).
- `stance_attack` (NEW): Unit switched to Attack stance.
- `stance_defense` (NEW): Unit switched to Defense stance.
- `hourglass_flip` (NEW): Duel hourglass flips (L18).
- `coin_flip` (NEW): First-player coin flip (spin 1.7 s, then landing).
- `draft_reveal` (NEW): Draft cards revealed (L26).

**Combat**
- `card_slam`: Set-piece summon: the card lands on the table.
- `attack`: Attack declared: the attacker lunges.
- `impact`: Attack lands on a unit; killing-blow hits; coin landing.
- `damage`: Player HP loss.
- `block` (NEW): Attack into a Defense-stance unit.
- `miss` (NEW): Attack misses (Blind / Nimble dodge).
- `destroy`: Unit destroyed (sent to Spent).
- `exhaust`: Card exhausted (removed from the game).
- `sacrifice`: Unit sacrificed for a cost.
- `boom`: Killing blow / Serpent finisher explosion.
- `hp_low_heartbeat`: Low HP: one heartbeat every 2.2 s on the local turn.

**Statuses and effects**
- `heal`: Player HP gained.
- `buff`: Generic buff status applied (fallback).
- `debuff`: Generic debuff status applied (fallback).
- `status_rune` (NEW): Rune counter placed.
- `status_retain` (NEW): Retain (not discarded at end of turn).
- `status_reveal` (NEW): Reveal (card is face up).
- `status_eternal` (NEW): Eternal (prevents the next destruction).
- `status_burn` (NEW): Burn applied.
- `status_pierce` (NEW): Pierce (excess damage goes through).
- `status_cleanse` (NEW): Cleanse (removes / blocks debuffs).
- `status_paralyse` (NEW): Paralyse (cannot attack, move or change stance).
- `status_medic` (NEW): Medic (heals its controller each turn).
- `status_curse` (NEW): Curse (removes / blocks buffs).
- `status_poison` (NEW): Poison applied.
- `status_infiltrate` (NEW): Infiltrate (may attack protected units).
- `status_blind` (NEW): Blind (attack target chosen at random).
- `status_nimble` (NEW): Nimble (moves to an adjacent zone).
- `status_debilitate` (NEW): Debilitate (effects suppressed).
- `status_blocked` (NEW): Cleanse / Curse stack stops an application.
- `status_expire` (NEW): A status wears off.
- `burn_tick` (NEW): Burn damage tick.
- `poison_tick` (NEW): Poison damage tick.
- `fuse`: Short fusion cue (legacy fallback).
- `ritual`: Short ritual cue (legacy fallback).
- `arcane`: Short arcane cue (legacy fallback).
- `copy_form` (NEW): Shapeshifter Loak / Mimic copies a Unit's form (L11).
- `control_steal` (NEW): Hypnotise / control change (L9).
- `control_return` (NEW): Control returns to the owner (L9).

**Set pieces**
- `charge`: Killing-blow wind-up (slow motion), crests into the boom.
- `summon`: Normal unit summon.
- `fusion_vortex`: Fusion build-up; crests at the climax (0.78 s).
- `fusion_impact`: Fusion climax (flash, shockwave).
- `ritual_choir`: Ritual build-up; crests at the climax (0.88 s).
- `ritual_impact`: Ritual climax.
- `arcane_shimmer`: Arcane build-up; crests at the climax (0.82 s).
- `arcane_impact`: Arcane climax: mystical bloom, not a hit (owner H28).
- `spell_cast`: Spell spotlight: the card lands centre-screen (HOLD 1.85 s).
- `trap_spring`: Trap spotlight: a trap springs (darker than the Spell).
- `serpent_coil`: Divine Serpents rise and coil.
- `serpent_strike`: The serpent strikes the plate.
- `evolve_charge` (NEW): Evolve build-up (L23).
- `evolve_burst` (NEW): Evolve transformation burst (L23).

**Stingers**
- `game_start` (NEW): A game begins (after the shuffle / coin flip).
- `victory`: Game won.
- `victory_big`: Series won.
- `defeat`: Game lost.
