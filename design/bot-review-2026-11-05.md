# Bot review and rework (L27, 2026-11-05)

Owner request (L27): "Improve the bot: give it a few more things to reach toward, e.g. higher attack on the field
and other smarter logic around positioning, stance and attack targets. I want it to be smarter and play better.
Please do a review and improve it as much as you can."

Code: `rldb/src/ai/bot_brain.gd` (decisions), `bot_forecast.gd` (new battle model), `bot_cards.gd` (new card
ratings), `bot_stance.gd` (stance breakdown, now used for debug text), `bot_player.gd` (pacing, thread).
Measured with `rldb/tests/perf/bot_arena.gd` against a frozen copy of the old brain in
`rldb/tests/perf/bot_baseline/` (test-only, never exported).

## 1. How the old bot decided

- **One move at a time, one move deep.** For every legal command it played the move on a copy of the match,
  resolved its own choices inside the move (one more level deep), and scored the result. It made the best
  move if it beat the current position by 1.0; otherwise it moved on to the next phase.
- **Position score.** The score was HP difference x 1.2, plus for each unit 6 + 0.45 ATK + 0.35 DEF, statuses
  +-1.5, Runes, plus a stance value from `BotStance`. The stance value was the best single attack the unit could
  make, weighted by HP lead, and capped at 30. Opposing units counted as threats at 0.7. Then Powers 6 each,
  set cards 3 each, Hand cards 0.5 each and AP 0.6 each, all held constant through the turn.
- **Choices inside effects** (targets, zones, Trap responses) were scored the same way. Multi-selects (materials,
  costs) were picked at random until a legal set was found.
- **Series.** Draft picks were random. The reward type was random, and the added card had the highest ATK+DEF
  (cost ignored). It never removed a card. It always chose to go first after a loss.

## 2. Weaknesses found

1. **No idea of the opponent's reply.** Each opposing unit's threat was valued on its own, capped, and not tied to
   what the opponent could actually do next turn. The arena log shows the result. On turn 2 the old bot faced a
   14-ATK unit and played a Power and a set card instead of a unit. It then took 40 direct damage on turn 3
   (direct attacks are only legal into an empty board). It also summoned units into unprotected back-row zones.
2. **It could foresee hidden information.** The look-ahead ran on a full copy of the match, so it knew:
   - the real random number generator state, so it foresaw Blind targets, random discards and random picks;
   - its own draw order, for draw effects;
   - the identities of the opponent's hidden cards.

   The human's Trap responses were always "Skip" in the look-ahead, so face-down Traps were not acted on. But the
   rest was a real, if small, information leak.
3. **Wasted AP and cards.** Unspent AP and Hand cards kept their value in the Recovery Phase. Both are lost at end
   of turn, so the bot often ended turns with AP left when a play was worth less than the margin.
4. **Linear HP.** It had no notion of danger at low HP, and no notion of lethal beyond an attack that wins on the
   spot. A two-attack kill (break the guard, then hit the exposed unit or the empty board) was only found if each
   step scored well alone.
5. **Attack order and targets** were greedy on the immediate result. It did not value removing a protector to
   expose the unit behind, or clearing the last unit so the remaining attackers hit directly.
6. **Stance** was valued per unit from its best attack. Stance is locked after the Setup Phase, so it also
   decides how the unit stands through the opponent's turn. That was only weakly modelled.
7. **Random multi-selects:** materials and costs were chosen at random.
8. **Random series choices** (draft, reward type). It ignored AP cost when adding cards, never thinned the deck,
   and always went first after a loss. The arena shows the second player wins most bot games, because the first
   player has no Battle Phase on turn 1.

## 3. What the new bot does

- **Fair information.** It thinks on `BotBrain.belief(m)`, a copy holding only what its seat may see
  (`MatchView.can_see`):
  - every hidden card becomes an effectless placeholder;
  - its own Draw is reshuffled;
  - the copy's random generator is reseeded from the bot's own seed;
  - the opponent's Trap prompts are off in the look-ahead.

  It is still deterministic for a seed.
- **Forecast-based evaluation** (`BotForecast`). After each candidate move, a light model of the battle rules plays
  out, greedily:
  - the rest of the mover's Battle Phase;
  - the opponent's best reply next turn (any unit may attack, since stance is free in their Setup Phase), plus one
    virtual 8/8 unit for what they will summon from four fresh cards;
  - the bot's follow-up turn (weighted 0.35).

  The board those battles leave is then scored:
  - HP on a danger curve (the last HP count more; a forecast kill is worth 120);
  - units (presence, ATK, DEF, statuses, Runes, effects);
  - Powers and set cards;
  - AP and Hand cards, but only while they can still be used this turn.

  This one model drives every decision below:
  - **Lethal:** the bot pushes for a forecast kill and plays around the opponent's.
  - **Trades:** a losing attack is never forecast as worth making.
  - **Attack order:** it breaks the protector first (the model credits part of the exposed unit), and clears the
    last unit when the attackers still to come can strike directly.
  - **Stance:** Defense when the reply would punish Attack; Attack when it is safe or the damage is worth it.
  - **Positioning:** the zone choice is scored with the forecast, so a valuable or fragile unit goes behind a
    front unit, and a guard goes in front.
  - **Higher ATK on the Field:** unit ATK counts in material, and the follow-up turn rewards attack potential.
  - **No wasted AP:** Recovery Phase AP and Hand cards are worth nothing unless spent.
- **Two-step plans** in the Setup and Recovery Phases. The best five first moves are tried with their best
  follow-up, which finds plays like sacrifice then summon, or a buff then a flip.
- **Placement.** A back-row unit with nothing in front of it costs a little (it is as exposed as a front unit and
  wastes a protected zone). The first real bot game showed a lone unit parked in the back row; it now goes in
  front.
- **Moving on is scored after the phase change.** The Battle Phase baseline is the position after leaving it, so
  an attack the forecast expects is only credited once it is made (B6 stays fixed).
- **Multi-selects:** small selections try every combination; large ones rank options (give up cheap own cards,
  hit valuable opposing ones).
- **Any prompt kind is answered.** Every option is tried, the best legal one is taken, and the fallback is a legal
  default. An option labelled "Evolve" is always taken (L23: the bot always evolves).
- **Series:**
  - Draft and add-card picks use `BotCards.rating` (stats per AP cost plus effect, with Extra Deck cards
    discounted).
  - "Remove a card" rewards thin weak cards while the main deck is over 12.
  - It mostly adds Units.
  - After a loss it still chooses to go first. Between two new bots the first player wins about 58%, and this bot
    does better going first.
- **Speed.** One decision is capped: past 600 look-ahead copies, every further choice uses quick rules (a zone
  behind a guard, the best battle preview). Before this cap, one decision took 2.8 s.

## 4. Results

Harness: `rldb/tests/perf/bot_arena.gd`, run as
`godot --headless --path rldb -s res://tests/perf/bot_arena.gd -- --pairs=60 --seed=S`.
- Each deck pairing (Structure decks, plus 25% random drafts) is played 4 times. The new bot plays each deck,
  once going first and once going second.
- The old bot is the frozen pre-L27 copy. It still thinks on the full match: it knows the RNG state and its own
  draw order, so it is if anything stronger than a fair player.

| Run (240 games each) | New bot wins | As first player | As second player | Mean game length |
|---|---|---|---|---|
| Old vs old (seed 1, 120 games) | 45.8% (A) | 43.3% | 48.3% | 9.2 turns |
| First rework (seed 1, 120 games) | 63.3% | 63.3% | 63.3% | 9.1 turns |
| Final, seed 7 (not used for tuning) | 64.6% | 75.0% | 54.2% | 8.8 turns |
| Final, seed 8 (not used for tuning) | 67.1% | 75.8% | 58.3% | 9.0 turns |
| Final settings, seeds 5 and 6 (tuning seeds) | 69.0% | 75.0% | 62.9% | 9.5 turns |

Decision time (headless, per command, final settings):
- new bot: mean about 26 ms, median 8 ms, 95th percentile 105-111 ms, worst 416 ms;
- old bot: mean 28 ms, median 11 ms, 95th percentile 109 ms, worst 612 ms.

In the game the bot thinks on a worker thread and waits 0.9-1.3 s per move anyway.

Smoke runs:
- 12 full best-of-3 bot-vs-bot series (Structure and draft decks, rewards and first-player stages): all
  finished, 31 games, 0 refused commands.
- No stall or refused command in any of the about 3,000 arena games.
- The windowed bot driver passes: no refused command, moves at least 1.1 s apart. Screenshots:
  `production/qa/evidence/2026-11-05-l-batch/bot/`.

Tuning sweeps (240 games each). These settings moved the result by less than the noise (about +-3%):
- the follow-up weight;
- HP danger;
- the lethal bonus;
- the move margin;
- the value of Powers, set cards, Hand cards and AP;
- unit presence and DEF weights;
- jitter.

Three settings mattered:
- the opponent's expected summon (none 59%, 8/8 62%, 10/10 64%);
- the width of the two-step search (0: 59%, 3: 62%, 5: 67-69%);
- ATK weight 0.6 (+1-2%).

## 5. Remaining weaknesses

- **Going second is the weak spot.** The bot wins about 56-63% as second player against about 75% as first. With
  two new bots the first player wins about 58%. As second player, the first-turn tempo of a stronger opposing
  deck often decides the game before positioning matters.
- **Opposing face-down cards are blind spots.** The bot never knows an opposing Trap and does not play around
  them, so an attack into Mirror Force or Magic Cylinder is taken at face value. It also values its own set cards
  at a flat 3, whatever they are.
- **The forecast is a battle model only.** It does not see the opponent's next-turn Spells, buffs or removal, or
  on-destroy effects (for example Hydra's revive or Thunderclap's Paralyse). The engine look-ahead covers only
  the bot's own moves.
- **Series choices use a rough card rating** (stats per cost plus an effect bonus), not real card strength.
  Deck choice is still random among Structure decks.
