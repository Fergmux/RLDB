# RLDB sound effects: the ElevenLabs set (L1, 5 Nov 2026)

The owner asked for this in `design/owner-feedback-2026-11-05.md`, item 1: "replace all sound effects ... use the
elevenlabs mcp ... fit the fantasy vibe and be reminiscent of the existing effects but better quality.
Summons/spells/effects etc. should have quite fancy long sound effects; buttons/card moves etc. should be quicker
and cleaner".

## The world

Every cue comes from one world: a medieval-fantasy tavern table with arcane magic.
- **Tactile layer:** cards are heavy paper on felt and oak. Buttons are brass, wood and leather. Panels are
  parchment and book covers.
- **Magic layer:** glass harmonics, crystal chimes, brass swells, temple gongs and fire.
- **Excluded:** voices, modern UI blips and sci-fi or synthetic timbres.

Each cue keeps the gesture of the procedural cue it replaces (`tools/gen_sfx.py`, now retired). For example, the
gold button is still a brass tick on a wooden knock, the Arcane climax still blooms out of glass and never hits
(owner, H28), and the Trap is still a snap with a dark brass sting.

## How the set was made

1. **Cue sheet.** `design/audio/sfx-cues.json` has one entry for each of the 108 names in `Sfx.NAMES`. Each entry
   gives the cue's tier, its context, a length window, the generation length, the prompt influence and one or
   two prompt variants.
2. **Generation.** Each prompt variant got 4 takes of `eleven_text_to_sound_v2`, 700 takes in all.
   - **Round 1** made 628 takes from 157 prompt variants.
   - **Round 2** made 72 more takes for 13 cues whose round-1 takes were all weak:
     - ui_hover and slider_tick: no single short tick;
     - tab and deck_remove: slow or sub-only;
     - customise_select, ap_gain and status_retain: 10 kHz glitter;
     - damage, status_curse, status_blind and ritual_choir: sub-only rumble that laptop speakers lose;
     - status_nimble and boom.

     The round-2 prompts are the later variants in the cue sheet. Each `takes.json` records the settings of
     every take.
   - UI cues were generated at 0.5 s with prompt influence 0.6-0.8, for tight adherence.
   - Set pieces were generated at 3-5 s with prompt influence 0.45, for richer results.
   - The takes are in `production/audio-staging/<cue>/` (gitignored). `index.md` there lists every take.
   - **Cost:** about 3,130 credits in all (round 1 about 2,890, round 2 about 244). Per take, cost scales with
     length: about 1.7 credits at 0.5 s, 8.3 at 2.5 s and 16.7 at 5 s.
   - The ElevenLabs flows are named "RLDB SFX L1 batch 1-5", "RLDB SFX L1 round 2" and "RLDB SFX L1 (Nov 2026)",
     the pilot.
3. **Analysis.** `tools/sfx_master.py analyse` measured every take:
   - trimmed length and lead-in;
   - attack (10% to 90% of the loudest 5 ms frame), crest time and the number of separate hits;
   - loudest 100 ms and 400 ms (K-weighted), sample peak and hard-clipped runs;
   - spectral centroid, the share of energy above 6 kHz and below 150 Hz;
   - stereo width, noise floor and DC.

   A score per tier marks down takes that miss the length window, start late for an action cue, hit more than
   once for a click, crest early for a riser or late for a climax, clip, hiss or are too bright for a repeated
   UI cue.
4. **Choice.** Review boards show every take's waveform over a log-frequency spectrogram, at one time scale per
   cue. The take was chosen from these boards and the scores. The reason is in the table below.
5. **Mastering.** `tools/sfx_master.py master` applies these steps:
   - a 4th-order high-pass, which removes DC and rumble (150 Hz for hovers, 25-40 Hz for the big pieces);
   - a fold to mono for UI, card and combat cues, which have no position on the table (status, set pieces and
     stingers stay stereo);
   - a trim of leading silence, with the onset kept within 0.5-1 ms for UI, and a trim of the tail at -42 to
     -60 dB under the peak;
   - for the three summon build-ups (and the killing-blow charge), alignment so the riser crests at the set
     piece's climax time (`FxSummon.CLIMAX`), then lets go in 70 ms, so the climax lands out of a breath (H29);
   - raised-cosine fades;
   - loudness set to the tier target;
   - a smooth look-ahead limiter to -1 dBTP, measured at 4x oversampling;
   - 44.1 kHz 16-bit WAV with TPDF dither. Godot imports it with QOA compression.

## Mix

Loudness is the loudest 100 ms of K-weighted power (LUFS). A mono file counts on both speakers, because Godot
plays it that way. The music tracks measure about -10.3 on this scale (about -15.5 LUFS integrated), on a bus at
the same default level as the SFX bus.

| Tier | Target | Old procedural set | Use |
|---|---|---|---|
| hover | -32 | -31 to -32 | button and card hover (also jittered and rate-limited in code) |
| ui_soft / tick_soft | -28 / -22 | | slider tick, clock tick |
| ui | -24 | -21 to -26 | clicks, back, tabs, toggles, panels |
| ui_major | -18 | -14 to -23 | confirm, deny, deck edits, AP, reward / draft pick |
| notice_soft / notice | -19 / -14.5 | -14 to -18 / -10 to -11 | chat, tutorial, rewards / turn, phase, alerts |
| card | -16 | -13 to -15 | draw, play, set, discard, flip, shuffle, stance |
| combat | -13.5 | -10 to -15 | attack, impact, block, damage, destroy, sacrifice |
| status | -15 | -9 to -13 | status applications, heal, buff, debuff, control |
| summon / build | -13.5 / -12.5 | -12.8 / -11 to -12 | normal summon / set-piece build-ups |
| spotlight | -12 | -12.4 to -13.4 | Spell / Trap spotlight (K1: between board and climaxes) |
| climax / big_hit | -10.5 / -10 | -10.5 / -8.7 | Fusion / Ritual / Arcane / Evolve / Serpent climaxes, killing blow |
| stinger | -12 | -11.7 to -12.3 | game start, victory, defeat |

`tools/tests/test_sfx_set.py` checks the following:
- every cue has a clean file: 44.1 kHz 16-bit WAV, sample peak at or under -1 dBFS, no DC, and a tail that fades
  to silence;
- every cue fits its length window;
- every action cue starts within 6 ms;
- the build-ups crest and let go;
- the Arcane climax blooms;
- the three climaxes are within 1.5 LU of each other;
- the spotlight sits between the board sounds and the climaxes;
- the mix keeps its order (hover < UI < cards < combat).

## Edited and layered cues

- **`fusion_impact`:** b3's immediate deep boom, layered with a1's shimmering chord bloom 2 dB under it. The
  boom lands on the flash and the chord blooms after it.
- **`card_slam`:** b2's woody slap, layered with a1's deep thump 2 dB under it.
- **`serpent_strike`:** the take's own whoosh (0-0.3 s) runs straight into its own splash. The splash is moved
  from 0.88 s to start at 0.09 s, so it peaks at about 0.25 s. The serpent reaches the plate at 0.23 s
  (FxSerpent IMPACT_AT - STRIKE_AT + 0.05).
- **The four risers** (`fusion_vortex`, `ritual_choir`, `arcane_shimmer`, `charge`): each is shaped by a rising
  gain so it crests at its `align` time (`FxSummon.CLIMAX` less a breath), then decays with a 45 ms time
  constant, as the old procedural build-ups did.

## Least confident (listen to these first)

Analysis can only measure a take; nobody has heard these. These are the cues where the brief or the takes left
the most doubt:
- **`ritual_choir` and `fusion_vortex`:** they are shaped risers, not natural ones, so the swell is imposed on
  the take.
- **`hp_low_heartbeat` and `boom`:** both are bass-heavy by nature. They suit headphones better than laptop
  speakers.
- **`card_play` and `card_set`:** both are very transient. The 6 dB limiter cap left them 1-2.5 dB under the
  card tier, so they may feel a touch quiet next to `card_draw`.
- **`toggle_on`, `toggle_off`, `slider_tick` and `ap_gain`:** small and bright by nature. They are low-passed,
  but they are still the cues most likely to feel thin.
- **`charge`:** its riser ends on the take's own end at 1.26 s, not on the boom. The killing-blow timing slows
  with the strike's slow motion.
- **`victory_big`:** four of its eight takes were cut off abruptly by the generator, and the take chosen decays
  naturally. **`game_start`**, **`victory`** and **`defeat`** are short generated musical phrases, which could
  clash in key with the music track that is playing.

## Cue table

Final column: length, channels and loudest-100 ms loudness after mastering.

<!-- TABLE -->
### UI: clicks, hovers, toggles and panels

| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |
|---|---|---|---|---|---|---|
| `ui_hover` | Pointer enters a button or menu item (rate-limited, jittered). | 0.04-0.12 s | 0.11 s, mono, -32.0 LUFS | Single tiny soft tap of a fingertip on a wooden table, very short, muted and quiet, close-mic, dry | c2.mp3 | Round 2 (round 1 gave 0.5 s whispers or bead trains): one soft fingertip tap, 0.10 s, 5 ms attack, warm (500 Hz); low-passed at 9 kHz. |
| `card_hover` | Pointer enters a card (hand, draft, rewards, catalogue). | 0.06-0.18 s | 0.18 s, mono, -32.0 LUFS | One thick playing card sliding a few centimetres across green felt, very soft and short, close-mic | b1.mp3 | Shortest clean paper slide (0.27 s, no second hit); a1-a4 drag on for 0.35-0.45 s. |
| `select` | Generic selection: a card, a chat open, an inspect, a list row. | 0.05-0.20 s | 0.10 s, mono, -24.0 LUFS | Single small crisp wooden tick, a game token tapped once on an oak table, light and clean, close-mic, dry | a3.mp3 | One warm wooden tick (centroid 1.9 kHz), instant onset, very low noise floor; b takes are thin 9-12 kHz pins. |
| `click_primary` | Gold (primary) button or menu item press. | 0.06-0.25 s | 0.09 s, mono, -24.0 LUFS | Single crisp click of a small brass button on a wooden box, short bright metallic tick with a soft wooden knock, close-mic, dry | a4.mp3 | Compact brass-on-wood click (90 ms, one hit, 1.9 kHz); brighter than click_secondary, not as sharp as b4 (6.5 kHz). |
| `click_secondary` | Brown (secondary) button press. | 0.05-0.20 s | 0.14 s, mono, -24.0 LUFS | Soft muted click of a leather-covered wooden button, dull warm knock, short and dry, close-mic | a4.mp3 | Single dull leather-and-wood knock (5 ms attack, 770 Hz), the darker partner of click_primary; others double-hit or ring. |
| `back` | Back / Close / Cancel / Leave buttons and Esc. | 0.10-0.35 s | 0.17 s, mono, -24.0 LUFS | Leather book cover closing softly, short muted thump with a light paper swish, close-mic, dry | a1.mp3 | One soft book-cover thump with a paper swish (0.18 s, dark); the b takes knock twice 200 ms apart, too slow for Back. |
| `confirm` | Confirming a choice (end turn, prompt OK, selection done). | 0.25-0.70 s | 0.70 s, mono, -18.0 LUFS | Bright positive confirmation chime, two ascending notes on a small brass bell struck with a soft mallet, warm, fantasy | a3.mp3 | Warm brass bell (1.9 kHz) with a clean decay; the glass b takes are 6-8 kHz and fatiguing for a cue heard every turn. |
| `cancel` | Backing out of a selection or targeting. | 0.12-0.40 s | 0.37 s, mono, -24.0 LUFS | Soft descending two-note chime on a muted wooden marimba, gentle and short | a4.mp3 | Muted marimba blip falling away (630 Hz), soft and short; the parchment b takes are sub-heavy. |
| `deny` | Illegal action (no AP, invalid target, deck limit). | 0.15-0.40 s | 0.32 s, mono, -18.0 LUFS | Dull short rattle of a locked iron padlock being tugged once, muted negative thud, close-mic | a2.mp3 | Dull padlock tug (640 Hz) with a little rattle: clearly 'no' without a harsh buzz; a1 is the same gesture but brighter. |
| `tab` | Tab switch. | 0.06-0.22 s | 0.11 s, mono, -24.0 LUFS | Short soft slap of a leather tab folding over, muted mid-range thud, single hit, close-mic, dry | d4.mp3 | Round 2: one soft leather-tab slap (0.19 s, instant); round 1 was sub-only thumps or 100-300 ms page turns. High-pass lowered to 60 Hz to keep its body. |
| `toggle_on` | Check box / switch turned on. | 0.05-0.20 s | 0.13 s, mono, -24.0 LUFS | Small brass latch clicking shut, two tiny crisp clicks rising in pitch, short, close-mic, dry | a1.mp3 | The latch: two tiny clicks in 0.13 s, exactly the old two-step latch; softened above 9 kHz. |
| `toggle_off` | Check box / switch turned off. | 0.05-0.20 s | 0.20 s, mono, -24.0 LUFS | Small brass latch clicking open, two tiny soft clicks falling in pitch, short, close-mic, dry | a4.mp3 | A single latch click opening (0.2 s); softened above 9 kHz to sit with toggle_on. |
| `slider_tick` | Volume slider step / drag end. | 0.03-0.12 s | 0.12 s, mono, -28.0 LUFS | Single tiny soft click of a small wooden bead, very short, one click only, close-mic, dry | b4.mp3 | Round 2: the shortest single bead click (0.16 s, instant), softened above 7 kHz so a drag of ticks never hisses. |
| `panel_open` | Modal / panel opens. | 0.20-0.60 s | 0.60 s, mono, -24.0 LUFS | Parchment scroll unrolling quickly with a soft papery swish and a faint magical shimmer, short | a3.mp3 | Parchment unrolling with a faint shimmer, trimmed to 0.6 s; the b takes are page flutters with 8 separate hits. |
| `panel_close` | Modal / panel closes. | 0.15-0.40 s | 0.15 s, mono, -24.0 LUFS | Old book closing gently, soft leather thump with a puff of air, short | b2.mp3 | Book closing: one soft thump (5 ms attack, 0.35 s), the natural end of panel_open. |
| `customise_select` | Picking a cosmetic / table / card back option (L28). | 0.15-0.50 s | 0.32 s, mono, -18.0 LUFS | Soft warm wooden token set into a velvet-lined tray with a gentle low chime, short and satisfying | b4.mp3 | Round 2: a warm token set in a tray with a low chime (3 kHz, instant, one event); round 1 was all 10 kHz sparkle. |
| `deck_add` | Card added to a deck in the deck builder. | 0.10-0.30 s | 0.30 s, mono, -18.0 LUFS | Single card tucked into a stack of cards, quick papery slide and soft tick, close-mic | b3.mp3 | Card tucked into the stack: quickest slide (45 ms) ending in a tick, 0.32 s. |
| `deck_remove` | Card removed from a deck. | 0.10-0.30 s | 0.26 s, mono, -18.0 LUFS | Single playing card quickly flicked off a stack, short sharp papery snap, close-mic, dry | c2.mp3 | Round 2: a quick card flick off the stack (50 ms rise, 0.26 s), the partner of deck_add; round 1 took 120-240 ms to arrive. |
| `ap_gain` | Action Points gained (AP gem lights). | 0.25-0.70 s | 0.70 s, mono, -18.0 LUFS | Warm mid-pitched two-note glass chime, a small amber gem lighting up, soft and pleasant, short | b2.mp3 | Round 2: a warm two-note amber chime (1.8 kHz); round 1 was 9-11 kHz glitter, too sharp for a cue heard every turn. |
| `ap_loss` | Action Points spent / lost. | 0.15-0.45 s | 0.28 s, mono, -18.0 LUFS | Dull short descending glass blip, a small crystal gem dimming, soft and short | a3.mp3 | Short dull crystal dimming (2 kHz, 0.28 s, instant). |
| `reward_pick` | A reward is taken. | 0.20-0.70 s | 0.70 s, mono, -18.0 LUFS | Precious gem placed into a metal socket, bright crystal ping with a brass click | a4.mp3 | Gem set in its socket: bright ping with a brass click, the least piercing of four. |
| `draft_pick` | A draft card is picked (L26). | 0.20-0.70 s | 0.70 s, mono, -18.0 LUFS | Card picked up from a table with a decisive paper snap and a soft magical chime | a3.mp3 | Decisive card snap plus a chime, 20 ms attack. |
| `sacrifice_mode_on` | Sacrifice mode armed (L5). | 0.25-0.80 s | 0.67 s, mono, -18.0 LUFS | Dark ritual flame igniting, low ominous whoosh with a soft ember crackle, short | a1.mp3 | Low ritual flame catching, instant (10 ms). |
| `sacrifice_mode_off` | Sacrifice mode cancelled (L5). | 0.20-0.60 s | 0.45 s, mono, -24.0 LUFS | Small dark flame snuffed out, soft short whoosh fading | a1.mp3 | Flame snuffed: the quickest (25 ms) of four soft whooshes. |
| `target_arm` | Targeting arrow appears (L7). | 0.20-0.70 s | 0.57 s, mono, -24.0 LUFS | Bow string drawn back slowly, tense creak of wood, aiming | a1.mp3 | Bow string drawn: creak starting at once, trimmed to 0.7 s. |
| `target_lock` | Target chosen (L7). | 0.15-0.50 s | 0.50 s, mono, -18.0 LUFS | Magical target lock, crisp bright click with a short shimmering ping | a2.mp3 | Crisp lock-on click with a short ping, 0.35 s. |

### Notices and flow

| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |
|---|---|---|---|---|---|---|
| `chat` | Chat message while the chat box is closed. | 0.30-0.80 s | 0.80 s, stereo, -19.0 LUFS | Two soft bright glass bell tings rising, gentle and quiet message notification | a1.mp3 | One clean glass bell (2 kHz) with a long soft decay: a gentle message chime under the game sounds. |
| `chat_pop` | New chat message preview bubble pops out. | 0.30-0.80 s | 0.60 s, stereo, -19.0 LUFS | Soft round water bubble pop followed by a tiny bright bell ting, friendly and light | a3.mp3 | Bubble pop then a bell ting (two events, the old pop-and-chime gesture), very clean floor (-64 dB). |
| `step_done` | Tutorial step completed. | 0.30-0.80 s | 0.55 s, stereo, -19.0 LUFS | Small bright magical chime, a short rising sparkle, gentle achievement ding | a1.mp3 | Small rising chime (3.2 kHz), instant, 0.55 s; a3/a4 are thinner sparkles. |
| `turn` | A new turn begins. | 0.80-2.00 s | 1.94 s, stereo, -14.5 LUFS | Soft heavy gong-like bronze bell, single warm strike with a gentle ringing tail | b4.mp3 | Bronze bell, instant, with no sub rumble (lf share 0) and a long warm ring. |
| `phase` | Phase change. | 0.30-0.90 s | 0.90 s, stereo, -14.5 LUFS | Soft airy magical whoosh with a gentle two-tone chime | a3.mp3 | Airy whoosh with a two-tone chime, quick (15 ms), very clean floor. |
| `notice` | Generic notice (prompt shown, coin result, tutorial). | 0.30-0.90 s | 0.90 s, stereo, -14.5 LUFS | Single clear bright bell ding, gentle attention chime, short ring | a3.mp3 | Clean single bell ding (2.1 kHz), the cleanest floor. |
| `prompt_alert` | Your response is needed (L16 prompts). | 0.30-0.90 s | 0.86 s, stereo, -14.5 LUFS | Two quick bright crystal bell notes, pleasant attention alert | a4.mp3 | Two quick crystal notes, pleasant, instant. |
| `opponent_responding` | The opponent is responding (L16 notice). | 0.50-1.50 s | 1.38 s, stereo, -19.0 LUFS | Soft mysterious low magical hum with a faint shimmering pulse, waiting | a2.mp3 | Soft pulsing low hum with no sub rumble: present but patient. |
| `timer_tick` | Low-time tick (L18). | 0.05-0.25 s | 0.22 s, mono, -22.0 LUFS | Single soft tick of an old wooden pendulum clock, short and dry, close-mic | a3.mp3 | One dry clock tick (1.7 kHz), no ring. |
| `timer_warning` | Time almost out (L18). | 0.60-1.50 s | 1.48 s, stereo, -14.5 LUFS | Low bronze bell tolling twice quickly, tense warning that time is running out | a1.mp3 | Bronze bell tolled with urgency (2 kHz), instant. |
| `series_point` | A series point is won (L3). | 0.60-1.50 s | 1.48 s, stereo, -14.5 LUFS | Heavy gold coin dropped on a stone table, bright ringing clink with a triumphant shimmer | a2.mp3 | Gold coin clink with a shimmer (5.7 kHz), two clean hits; the others rattle 7-10 times. |
| `reward_reveal` | Rewards panel opens. | 0.60-1.40 s | 1.00 s, stereo, -19.0 LUFS | Treasure chest opening with a magical sparkling shimmer and a rising chime | a4.mp3 | Chest opening into a sparkle, darkest (6.6 kHz) with the cleanest floor (-72 dB). |

### Card movement

| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |
|---|---|---|---|---|---|---|
| `zone_pick` | Choosing a board zone (where to place a card). | 0.10-0.35 s | 0.15 s, mono, -16.0 LUFS | Soft wooden game token placed onto a board square, short muted clack with a faint magical shimmer, close-mic | a4.mp3 | One soft token clack with a shimmer, 0.22 s, instant. |
| `card_draw` | Each card drawn (also pile browser deal, deck select). | 0.15-0.45 s | 0.45 s, mono, -16.0 LUFS | Single thick playing card slid off a deck with a quick paper snap and a faint magical sparkle | b3.mp3 | Quick swipe off the deck (70 ms rise, crest at 70 ms, 0.34 s) with the sparkle; the a takes swell for 200 ms. |
| `card_play` | A card is played face up to a zone. | 0.20-0.50 s | 0.20 s, mono, -17.0 LUFS | Playing card placed firmly face up on a wooden table, crisp paper snap and soft wooden tap, close-mic | a1.mp3 | Crisp paper snap and table tap in 0.2 s, one event; the b takes have 3 separate hits. |
| `card_set` | A card is set face down (backrow). Same for every card: hides identity. | 0.20-0.50 s | 0.14 s, mono, -18.4 LUFS | Playing card placed face down on a felt table, soft muted papery thud, gentle, close-mic | a1.mp3 | Soft muffled face-down thud (1 kHz, 0.32 s), the quiet cousin of card_play. |
| `card_discard` | Card discarded to the Spent pile. | 0.15-0.50 s | 0.24 s, mono, -16.1 LUFS | Card flicked away onto a stack, quick paper whip and soft landing | b1.mp3 | Card flicked onto a pile, 0.31 s, quick (35 ms). |
| `card_return` | Card returned to hand. | 0.15-0.50 s | 0.36 s, mono, -16.0 LUFS | Playing card swept back up from a table into a hand of cards, quick reverse papery swish, close-mic | a2.mp3 | Reverse swish back to the hand, shortest rise (150 ms) of the four. |
| `card_shuffle` | Deck shuffled at game start. | 0.60-1.50 s | 1.36 s, mono, -16.0 LUFS | Deck of playing cards riffle shuffled and bridged, crisp and quick, close-mic | a2.mp3 | Riffle shuffle that starts at once (40 ms) with an even, crisp riffle across 1.4 s. |
| `card_flip` | Face-down card revealed (identical for every card). | 0.15-0.50 s | 0.34 s, mono, -16.0 LUFS | Playing card flipped over on a table, quick crisp paper flip with a soft snap and a faint magical shimmer | a3.mp3 | Crisp flip with a shimmer, 45 ms attack, 0.34 s, one event (identical for every card). |
| `stance_attack` | Unit switched to Attack stance. | 0.20-0.60 s | 0.57 s, mono, -16.0 LUFS | Sword drawn quickly from a leather scabbard, short metallic ring, ready for battle | a1.mp3 | Blade drawn with a ring, quickest of the a takes; the b takes rise for 200 ms. |
| `stance_defense` | Unit switched to Defense stance. | 0.20-0.60 s | 0.33 s, mono, -16.0 LUFS | Heavy wooden shield raised and braced, solid thump of leather and wood with a soft metal clank | a4.mp3 | Shield braced: one solid knock (400 Hz) with a little clank, 0.37 s. |
| `hourglass_flip` | Duel hourglass flips (L18). | 0.50-1.50 s | 1.19 s, mono, -16.0 LUFS | Glass hourglass flipped over onto a wooden table, soft clunk followed by fine sand starting to trickle | a4.mp3 | Glass clunk then sand trickling, 1.3 s, instant. |
| `coin_flip` | First-player coin flip (spin 1.7 s, then landing). | 1.00-2.00 s | 2.00 s, mono, -16.0 LUFS | Gold coin flicked into the air with a bright metallic ping and spinning ring, then landing on a wooden table | a1.mp3 | Flick ping and spinning ring (1.1 s); the takes with a landing put it at 1.2 s, but the coin lands at 1.7 s (the landing keeps its own impact). |
| `draft_reveal` | Draft cards revealed (L26). | 0.50-1.20 s | 0.62 s, mono, -16.0 LUFS | Several playing cards fanned out quickly on a table with a magical shimmer, quick paper spread and sparkle | a3.mp3 | Cards fanned out with a shimmer, 0.75 s, fewest separate hits. |

### Combat

| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |
|---|---|---|---|---|---|---|
| `card_slam` | Set-piece summon: the card lands on the table. | 0.30-0.70 s | 0.44 s, mono, -13.5 LUFS | Heavy card slapped onto a wooden table, deep resonant thud and dusty impact | b2.mp3 | Layered: b2's woody slap (1.7 kHz, instant; reads on small speakers) over a1's deep table thump (the body the old slam had); either alone is too thin or too subby under the climax. |
| `attack` | Attack declared: the attacker lunges. | 0.25-0.80 s | 0.30 s, mono, -13.5 LUFS | Fast sword swing whoosh, sharp swish of a blade through the air, fantasy combat | a4.mp3 | Sword swing with the clearest high swish (1.3 kHz centroid) and a 50 ms rise; most takes are bassy whooshes. |
| `impact` | Attack lands on a unit; killing-blow hits; coin landing. | 0.20-0.70 s | 0.70 s, mono, -13.5 LUFS | Heavy weapon hit on armour, punchy crunchy impact, fantasy combat | b1.mp3 | Weapon on armour with mid-range crunch (550 Hz) and a very clean tail; the a takes are sub only. |
| `damage` | Player HP loss. | 0.30-0.90 s | 0.39 s, mono, -13.5 LUFS | Heavy punch impact with a crunchy crack and a solid mid-range thud, fantasy combat hit, no voice | c4.mp3 | Round 2: a punch with a crunchy crack that lands at once (crest 30 ms, 290 Hz body); round 1 was sub rumble (40-110 Hz) that small speakers lose. |
| `block` | Attack into a Defense-stance unit. | 0.30-0.90 s | 0.52 s, mono, -13.5 LUFS | Blade blocked by a steel shield, sharp clang and solid thump | b2.mp3 | Clang plus a solid thump in 0.52 s, instant; the a takes ring on for a full second. |
| `miss` | Attack misses (Blind / Nimble dodge). | 0.20-0.70 s | 0.32 s, mono, -13.5 LUFS | Sword whooshing through empty air, fast light swish that misses | a1.mp3 | Quick empty-air swish, 0.43 s, single. |
| `destroy` | Unit destroyed (sent to Spent). | 0.40-1.20 s | 0.96 s, mono, -13.5 LUFS | Stone and wood figurine shattering into pieces, crunchy break with crumbling debris, fantasy | a4.mp3 | Crunchy shatter with debris, instant (0 ms attack), 2 kHz, the old splinter gesture. |
| `exhaust` | Card exhausted (removed from the game). | 0.60-1.40 s | 1.09 s, mono, -13.5 LUFS | Dark magical void suction, a whoosh pulled downward into nothing ending in a dull hollow thud | a1.mp3 | Void pull: swells for 0.4 s then falls away into nothing (the old reversed swell), dark (540 Hz). |
| `sacrifice` | Unit sacrificed for a cost. | 0.60-1.40 s | 1.40 s, mono, -13.5 LUFS | Card burning away in a magical flame, quick ignition whoosh and fading crackle | b4.mp3 | Card catching fire: immediate ignition (20 ms) and crackle, the brightest (870 Hz) of a bass-heavy set. |
| `boom` | Killing blow / Serpent finisher explosion. | 1.20-2.50 s | 2.48 s, stereo, -10.2 LUFS | Massive fantasy magic blast, deep thunderous boom with debris and long rumble | b4.mp3 | The boom with the most crack and mid-range (220 Hz centroid; the a takes are clipped 45 Hz rumble); round 2's c takes were no brighter. |
| `hp_low_heartbeat` | Low HP: one heartbeat every 2.2 s on the local turn. | 0.40-0.90 s | 0.89 s, mono, -14.0 LUFS | Single slow deep heartbeat, lub-dub, warm muffled low thump, felt more than heard, no music | a3.mp3 | Clear lub-dub (two beats) with a warm body; played 12 dB down in code. |

### Statuses and effects

| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |
|---|---|---|---|---|---|---|
| `heal` | Player HP gained. | 0.60-1.50 s | 1.26 s, stereo, -15.0 LUFS | Soothing healing spell, soft rising harp-like sparkle and warm magical glow | b1.mp3 | Warm harp-like rise (1.5 kHz) with an immediate start; the a takes are 10 kHz glitter. |
| `buff` | Generic buff status applied (fallback). | 0.40-1.00 s | 0.84 s, stereo, -15.0 LUFS | Magical power-up, bright rising shimmer with a warm brass resonance, short fantasy buff spell | a4.mp3 | Bright brassy shimmer up, instant, 0.87 s. |
| `debuff` | Generic debuff status applied (fallback). | 0.40-1.00 s | 0.92 s, stereo, -15.0 LUFS | Dark magical hex, a descending warped tone with a sinister whoosh, short fantasy debuff spell | a3.mp3 | Descending warped hex tone, 25 ms attack, 0.92 s. |
| `status_rune` | Rune counter placed. | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Ancient rune glyph glowing to life, a deep resonant stone hum with a bright mystical chime | a2.mp3 | Stone hum with a chime, immediate (10 ms), 550 Hz body: a glyph waking. |
| `status_retain` | Retain (not discarded at end of turn). | 0.60-1.60 s | 1.37 s, stereo, -15.0 LUFS | Warm golden magical seal locking in place, a soft metallic latch click and a gentle low resonant chime | b1.mp3 | Round 2: a golden seal latching with a resonant chime (6 kHz, fuller); round 1 was all 11 kHz chain jingle. |
| `status_reveal` | Reveal (card is face up). | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Mystical eye opening, airy shimmering whoosh revealing something hidden, with a bright sparkle | a4.mp3 | Airy reveal shimmer with the cleanest floor (-61 dB) and the darkest top of the four. |
| `status_eternal` | Eternal (prevents the next destruction). | 0.80-1.80 s | 1.76 s, stereo, -15.0 LUFS | Holy divine protection aura, radiant shimmering glass harmonics and a bright crystal bell, heavenly, no voice | a1.mp3 | Full radiant shimmer with slow harmonic movement (holy, 4.7 kHz), instant. |
| `status_burn` | Burn applied. | 0.60-1.60 s | 1.35 s, stereo, -15.0 LUFS | Burst of fire igniting, quick whoosh into crackling flames | a2.mp3 | Ignition whoosh right on the onset (10 ms) into crackling flames. |
| `status_pierce` | Pierce (excess damage goes through). | 0.50-1.40 s | 1.20 s, stereo, -15.0 LUFS | Steel spear tip piercing through armour, sharp metallic scrape and stab with a bright ring | a4.mp3 | Metal stab and scrape with a ring, quickest (35 ms) and cleanest (-76 dB floor). |
| `status_cleanse` | Cleanse (removes / blocks debuffs). | 0.60-1.60 s | 1.08 s, stereo, -15.0 LUFS | Purifying water magic, a clear gentle splash with sparkling cleansing chimes | a3.mp3 | Clear water splash with chimes, crest at 90 ms. |
| `status_paralyse` | Paralyse (cannot attack, move or change stance). | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Crackling electric shock zap, sharp static lightning buzz that freezes in place | a4.mp3 | Electric zap that starts on the frame (10 ms) and buzzes; the others take 150-350 ms to arrive. |
| `status_medic` | Medic (heals its controller each turn). | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Soft holy healing aura, a warm gentle bell and a soothing shimmering hum | a3.mp3 | Warm bell and hum (720 Hz) with the cleanest floor (-62 dB). |
| `status_curse` | Curse (removes / blocks buffs). | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Dark curse spell, a sinister descending dissonant chime with a hollow ghostly whoosh, eerie, no voice | b3.mp3 | Round 2: a sinister falling dissonant chime with a ghostly whoosh (630 Hz, unclipped); round 1 was clipped 90 Hz rumble. |
| `status_poison` | Poison applied. | 0.60-1.60 s | 1.08 s, stereo, -15.0 LUFS | Thick green poison bubbling and squelching, wet gurgling bubbles with a sickly hiss | a1.mp3 | Tight cluster of wet bubbles then a hiss, instantly recognisable. |
| `status_infiltrate` | Infiltrate (may attack protected units). | 0.50-1.40 s | 0.65 s, stereo, -15.0 LUFS | Sneaky shadow magic, a quick dark whoosh slipping past, stealthy and soft | a4.mp3 | Soft dark slip-past whoosh with the most mid content (260 Hz) of four bass whooshes. |
| `status_blind` | Blind (attack target chosen at random). | 0.60-1.60 s | 1.29 s, stereo, -15.0 LUFS | Thick magical smoke bursting out in a soft puff, muffled hissing whoosh fading away, mid-range | b3.mp3 | Round 2: a smoke puff that bursts at once (25 ms) with a muffled hiss; round 1 was clipped sub. |
| `status_nimble` | Nimble (moves to an adjacent zone). | 0.50-1.40 s | 0.87 s, stereo, -15.0 LUFS | Quick light double whoosh of a nimble dodge, airy cloth swish with a tiny bright chime | b4.mp3 | Round 2: a quick airy dodge swish with a little chime (1.9 kHz, 55 ms). |
| `status_debilitate` | Debilitate (effects suppressed). | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Magic draining away, a weakening downward wilting tone with a soft deflating whoosh | a4.mp3 | Falling, wilting harmonic tone (visible downward glide), instant. |
| `status_blocked` | Cleanse / Curse stack stops an application. | 0.40-1.00 s | 1.00 s, stereo, -15.0 LUFS | Magical barrier deflecting a spell, a glassy shield ping with a dull bounce | a4.mp3 | Dull glassy deflection ping, instant, 0.66 s. |
| `status_expire` | A status wears off. | 0.50-1.20 s | 1.20 s, stereo, -18.0 LUFS | Magical aura fading away, a soft dissolving shimmer descending into silence | a4.mp3 | Descending dissolving shimmer, darkest and smoothest of four. |
| `burn_tick` | Burn damage tick. | 0.25-0.70 s | 0.60 s, mono, -17.0 LUFS | Short burst of flame crackle, a quick fiery sizzle | a1.mp3 | Short flame crackle, instant (10 ms), 0.62 s. |
| `poison_tick` | Poison damage tick. | 0.25-0.70 s | 0.70 s, mono, -17.0 LUFS | Short wet sickly poison bubble pop with a small hiss | a1.mp3 | Sickly bubble pop and hiss, instant. |
| `fuse` | Short fusion cue (legacy fallback). | 0.80-1.50 s | 1.48 s, stereo, -15.0 LUFS | Two magical energies merging, rising shimmer converging into a bright ringing strike | a4.mp3 | Legacy cue: rising converging shimmer (3.2 kHz), cleanest tail. |
| `ritual` | Short ritual cue (legacy fallback). | 0.80-1.50 s | 1.48 s, stereo, -15.0 LUFS | Low pulsing dark ritual drone ending with a deep drum strike | a1.mp3 | Legacy cue: pulsing dark drone into a drum strike, cleanest floor. |
| `arcane` | Short arcane cue (legacy fallback). | 0.80-1.50 s | 1.48 s, stereo, -15.0 LUFS | Glassy ascending magical chime arpeggio, sparkling and bright | a4.mp3 | Legacy cue: glassy chime run, 2.4 kHz. |
| `copy_form` | Shapeshifter Loak / Mimic copies a Unit's form (L11). | 0.60-1.60 s | 1.12 s, stereo, -15.0 LUFS | Shapeshifting magic, a wobbling liquid morph whoosh with a shimmering mirror-like tone | a1.mp3 | Wobbling liquid morph with a mirror tone (2.8 kHz), clearest of four. |
| `control_steal` | Hypnotise / control change (L9). | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Hypnotic mind control spell, a warbling dark swirling tone pulling inward | a2.mp3 | Warbling dark swirl drawing in, the only take without stray hits. |
| `control_return` | Control returns to the owner (L9). | 0.60-1.60 s | 1.48 s, stereo, -15.0 LUFS | Mind control spell breaking, a swirling tone unwinding with a release whoosh and a soft chime | a3.mp3 | Unwinding swirl with a release chime (4.2 kHz): the bright counterpart of control_steal. |

### Set pieces

| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |
|---|---|---|---|---|---|---|
| `charge` | Killing-blow wind-up (slow motion), crests into the boom. | 1.10-1.60 s | 1.26 s, stereo, -12.5 LUFS | Rising magical energy swell building tension, whooshing riser growing louder and higher, stopping at its peak | a2.mp3 | A true riser (its crest at 0.98 s, 1.9 kHz): shaped to crest at 1.3 s and let go into the boom. |
| `summon` | Normal unit summon. | 0.80-2.00 s | 1.79 s, stereo, -13.5 LUFS | Magical summoning, a short rising shimmer that lands with a deep warm impact and sparkling dust | b3.mp3 | Shimmer that lands at once (crest 70 ms, 3 kHz) and rings out: fancy but on the card's arrival; the a takes swell for 200-450 ms. |
| `fusion_vortex` | Fusion build-up; crests at the climax (0.78 s). | 0.80-1.10 s | 0.97 s, stereo, -12.5 LUFS | Swirling magical vortex building up, two energies spiralling together, rising whooshing riser growing louder | a3.mp3 | Swirling riser with an audible rising sweep (2.4 kHz); shaped to crest at 0.72 s and let go before the climax. |
| `fusion_impact` | Fusion climax (flash, shockwave). | 2.00-4.00 s | 4.00 s, stereo, -10.7 LUFS | Epic fantasy fusion explosion, deep soft boom and a glorious ringing magical chord with sparkles, long reverb tail | b3.mp3 | Layered: b3's immediate deep boom (lands on the flash) under a1's shimmering chord bloom (crest 0.5 s): the forge, then the glory. |
| `ritual_choir` | Ritual build-up; crests at the climax (0.88 s). | 0.90-1.20 s | 1.05 s, stereo, -12.5 LUFS | Ominous low brass and timpani crescendo rising quickly to a peak, dark ceremony | d3.mp3 | Round 2: low brass and timpani crescendo (500 Hz body; round 1 was sub-only drone), shaped to crest at 0.8 s and let go before the gong. |
| `ritual_impact` | Ritual climax. | 2.00-4.00 s | 3.33 s, stereo, -10.5 LUFS | Huge temple gong struck in a dark stone hall, deep ominous resonant boom with a long dark tail | a4.mp3 | Temple gong: immediate, one strike, the most mid-range body (lf share 0.49) with a long dark tail. |
| `arcane_shimmer` | Arcane build-up; crests at the climax (0.82 s). | 0.80-1.10 s | 1.01 s, stereo, -12.5 LUFS | Crystalline magical shimmer building up, glassy sparkling grains rising in pitch and swelling | a2.mp3 | A genuine glass riser (crest 1.36 s); its last 0.76 s before the crest, shaped and released before the climax. |
| `arcane_impact` | Arcane climax: mystical bloom, not a hit (owner H28). | 2.00-4.00 s | 3.25 s, stereo, -10.5 LUFS | Mystical arcane spell resolving into light, a soft blooming glass harmonica chord with sparkling shimmer and airy reverb, no hard hit | a4.mp3 | Blooms in over 185 ms (H28: no hit), crest 0.31 s on the flash, glassy 6 kHz shimmer with a long airy tail. |
| `spell_cast` | Spell spotlight: the card lands centre-screen (HOLD 1.85 s). | 1.20-2.60 s | 2.56 s, stereo, -12.0 LUFS | Magic spell cast, a quick sparkling swoosh blooming into a radiant chime and glittering tail | b1.mp3 | Swoosh that blooms within 110 ms (K1: swells, lands with the card) into a radiant tail; brighter than the Trap. |
| `trap_spring` | Trap spotlight: a trap springs (darker than the Spell). | 1.00-2.40 s | 2.40 s, stereo, -12.0 LUFS | Mechanical trap triggered, quick metal snap and heavy clank followed by a dark low brass sting | b2.mp3 | Snap on the landing, then a dark low sting at 0.94 s (K1: snap plus menace), darker (990 Hz) than the Spell. |
| `serpent_coil` | Divine Serpents rise and coil. | 1.20-2.00 s | 1.76 s, stereo, -12.5 LUFS | Giant serpent rising and coiling, long menacing hiss with scales sliding and a watery swirl | a2.mp3 | Long menacing hiss and scales, swelling to 0.35 s. |
| `serpent_strike` | The serpent strikes the plate. | 1.00-2.00 s | 1.21 s, stereo, -10.5 LUFS | Giant water serpent striking, fast whoosh followed by a heavy watery splash crash and deep thud | a3.mp3 | Edited: the take's whoosh (0-0.3 s) runs straight into its splash, moved from 0.9 s to land at 0.23 s, when the strike hits the plate (FxSerpent IMPACT_AT - STRIKE_AT). |
| `evolve_charge` | Evolve build-up (L23). | 1.00-2.00 s | 1.78 s, stereo, -12.5 LUFS | Creature transformation energy building, organic magical crackling and a rising shimmering hum swelling to a peak | a2.mp3 | Organic crackling rise cresting at 0.72 s, 1.8 kHz; the clearest build of four. |
| `evolve_burst` | Evolve transformation burst (L23). | 1.60-3.50 s | 2.76 s, stereo, -10.5 LUFS | Magical transformation burst, a bright explosive shimmering whoosh with a deep resonant bloom, creature evolving | a3.mp3 | Balanced burst (2.2 kHz, some low end) that blooms to 0.53 s and rings for 2.7 s. |

### Stingers

| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |
|---|---|---|---|---|---|---|
| `game_start` | A game begins (after the shuffle / coin flip). | 1.50-3.00 s | 3.00 s, stereo, -12.0 LUFS | Short medieval fanfare of brass horns with a war drum, heroic call to battle, fantasy | a2.mp3 | Horn fanfare over war-drum hits (two hits in the first 0.3 s), 3 s, the call to battle. |
| `victory` | Game won. | 1.50-3.00 s | 2.30 s, stereo, -12.0 LUFS | Bright victorious fantasy fanfare with horns and bells, short and joyful | b1.mp3 | Bright joyful fanfare that starts at once (70 ms) and resolves in 2.3 s. |
| `victory_big` | Series won. | 2.50-5.00 s | 4.17 s, stereo, -12.0 LUFS | Epic medieval victory fanfare with trumpets, choir-like strings and drums, celebratory finale, no voice | b4.mp3 | Grand fanfare that decays naturally over 4.3 s; a1-a4 cut off abruptly (generation artefact). |
| `defeat` | Game lost. | 1.50-3.00 s | 3.00 s, stereo, -12.0 LUFS | Sad descending medieval horn phrase, somber defeat, fading, fantasy | a2.mp3 | Somber descending horn phrase, quick start, 2.7 s, no sub rumble. |
