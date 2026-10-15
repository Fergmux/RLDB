# Match Board Screen Spec

Status: Draft v1, 2026-10-15. Implements I-01 (layout), I-02 (hover actions), UI half of I-03. Visual tokens: `design/art/art-bible.md`. Geometry reference: `design/references/field-layout.png`. Code-built Controls (no .tscn); this spec gives proportions, not node paths.

## 1. Window and scaling

Base 1600x1000, `canvas_items` stretch, `expand` aspect (already set in `project.godot`). Supported: 1600x1000, 1280x800 (x0.8), 1920x1080 (x1.08, extra width on the sides, extra height absorbed by the table margin). All numbers below are base pixels; compute positions from one `u` (unit-zone side) so the board is resolution independent. Wider-than-16:10 windows add table space left/right; the sidebar stays 360 base wide and the board is centred in the remaining area.

## 2. Screen regions (1600x1000 base)

```
+-------------------------------------------------+-----------+
| top strip (44): scene title / connection / menu |  SIDEBAR  |
+-------------------------------------------------+  360 w    |
|                    BOARD (~740 h)               |  turn bar |
|                                                 |  prompt   |
|                                                 |  details  |
+-------------------------------------------------+  log      |
| HAND STRIP (190)                                |           |
+-------------------------------------------------+-----------+
```

Board area: x 0-1240, y 44-810. Hand strip: x 0-1240, y 810-1000 (cards may rise above the strip on hover). Sidebar: x 1240-1600 full height, 8px outer padding.

## 3. Board grid (I-01)

Constants: `u` = 128 (unit zone, square), `g` = 8 (gap), `mid` = 16 (gap at the centre line).
- Unit zone: u x u (128x128). 3 columns, pitch u+g = 136, unit block width 3u+2g = 400.
- Trap/set-Spell zone: width u, height 2u/3 (128x85), 3:2 landscape, one per unit column, x aligned exactly to the unit columns.
- Power zone: width 2u/3 (85), height u (128), 2:3 portrait. 2x2 block: width 2*85+g = 178, height 2u+g = 264, i.e. equal to the two unit rows of that player (rows 1-2 top, rows 3-4 bottom).
- Gap between Power block and unit block: 24.

Vertical stack (top to bottom), total = 2*85 + 4*128 + 5*g(between rows, excluding centre) ... computed: opp Trap 85, g, opp back row 128, g, opp front row 128, **mid 16**, local front row 128, g, local back row 128, g, local Trap 85 = 85+8+128+8+128+16+128+8+128+8+85 = 730. Centre it in board area height 766 (18px margin top/bottom).

Rows by name: top Trap row (opp), opp Back, opp Front, local Front, local Back, bottom Trap row (local). Opponent's Back row is the one nearest their Trap row (top), exactly as the reference.

Horizontal: the unit block is centred in the board area at x = (1240-400)/2 = 420..820. Opponent Power block sits LEFT of it at x = 420-24-178 = 218..396, y aligned to the opp's two unit rows (top of opp Back to bottom of opp Front). Local Power block sits RIGHT at x = 844..1022, y aligned to the local two unit rows. Power slot order: row-major, Power 1 top-left. For the opponent, order is mirrored from the opponent's viewpoint (Power 1 is at the far/outer corner), rendered from local perspective so no client ever shows its own Powers on the left.

Perspective: always local player at bottom/right. Never derive position from player index; derive from `local_seat` vs `seat`.

Zone plate sizes are fixed; a card fills its plate completely (board card size = zone size). Unit card = 128x128 compact frame; Power card = 85x128 portrait mini frame (name plate + cost gem + art, shields shrink to 26px); Trap card = 128x85 landscape frame (art left half, name right, cost gem; face-down shows the back sideways-neutral emblem).

Empty corners are used: **top-right** (x 840-1230, y 52-300) = opponent info plate; **bottom-left** (x 10-400, y 540-800) = local info plate. Remaining empty space is table.

## 4. Player info plates

Plate (panel style, ~290x110): name in Cinzel 20 (with turn marker gold triangle when active), HP bar-with-number (Cinzel 28; bar `#8a2f26` to `#c0453a`; number turns `hl_danger` below 25%), AP as amber round gems (filled/empty, max shown 6 then number), and pile chips in a row: Hand, Deck, Spent, Exhaust, Extra Deck (icon + count, 9px Alegreya Bold). Opponent pile chips are counts only. Clicking a pile chip (Spent/Exhaust/Extra Deck of local; public piles of opponent) opens a modal list; this is inspection only. Plates never overlap zones; at 1280x800 they keep their position proportionally.

## 5. Hand

Local hand: strip at the bottom, cards 128x180, fanned. Spacing: even layout, overlap = max(0, (n*128 - 1000)/(n-1)); at most 8 fully visible without overlap in 1000px width. Cards slightly curved (rotation +/-2 degrees, y +/- 6) only when n >= 5 and reduced-motion off. Opponent hand: row of card backs at mini scale 64x90 under the top strip, top-left (x 10-200, y 50-140), overlapped, count badge. Hand cards that are not currently playable are dimmed to 0.75 modulate but stay hoverable and inspectable.

## 6. Sidebar (x 1240-1600)

Top to bottom:
1. **Turn bar** (96): "Turn 2 · Ben" Cinzel 18; phase pips (Draw, Main 1, Battle, Main 2, End) with current highlighted gold; **primary phase button** ("Go to Battle Phase", "End Turn"; gold, 44 high) and a secondary menu/concede button. Disabled/hidden when it is not local priority (see states). This is the only place turn-flow buttons live.
2. **Prompt panel** (variable 70-200): always present; text of current instruction or choice ("Choose a target for The Sweeper"), choice buttons/list, Cancel. Gold border pulses when a decision is required. Never rendered over the board; prompts needing zone picks use board highlights plus a one-line banner here.
3. **Card details** (flex, ~300): inspection only. Shows the Big card (240x336, scaled to fit) plus full rules text, live modifiers, status explanations, owner/zone, and legality notes ("Cannot attack: summoned this turn"). Contains **no action buttons**. Populated by hover (after 250ms) or by click-to-pin (click on any visible card pins it until another card or the empty table is clicked; hold Alt/long-press to peek).
4. **Game log** (flex, ~260): scrollable, newest at bottom, auto-scroll unless the user scrolled up; text 13 Alegreya; turn headers in Cinzel gold.

Top strip (44): left `You are Ben · Series 0-0 (best of 3)`, centre connection indicator, right Menu button. Toasts appear under the top strip, centred on the board.

## 7. Hover actions on the card (I-02)

Applies to hand cards, own field cards, and any card with a legal action. Actions never appear in the details panel.

**Content**: a vertical stack of buttons ("Summon", "Set", "Cast", "Attack", "Switch Stance", "Activate"...), only the currently legal ones, derived from engine legality (phase, turn, AP, targets, response/pending-choice lock). **Illegal actions are not shown.** If a card has no legal action, no stack appears (the card still lifts and details show). Exception: an action that is normally expected but blocked for a teachable reason (e.g. not enough AP) may show as a single greyed button labelled with the reason, non-clickable, `text_disabled`, so the player learns why; never styled like an enabled button.

**Placement**:
- Anchored over the **art window** (centre of the card's upper 55%); buttons 28 high, width = card width - 16, 6px gap, centred vertically in the art window.
- Never cover the bottom 38px (ATK/DEF shields, status chips), the cost gem (top-left 28x28), or the stance tab. If more than 2 buttons do not fit the art window (board cards: window ~64 high), overflow stack extends above the card (opening upward for bottom-row cards, downward for top-row) inside the hover region; they still must not enter the bottom reserved band.
- Hand cards scale 1.25 and lift; buttons sit on the enlarged art window, so their on-screen height is larger and 3-4 buttons fit.
- Button text Alegreya Bold 13; primary action first, gold border; icons optional.
- Neighbouring cards: the hovered card goes to the top of z-order and its buttons are part of it, so overlapping hand neighbours cannot steal clicks.

**Hover stability (grace region)**:
- Hover region = card rect expanded by 10px on all sides, unioned with the button stack rect. Pointer leaving the region starts a 150ms close timer; re-entering cancels it. Hand: expanded region also covers the lifted card's full height so the pointer can travel from the original position to the lifted card.
- Hover target switches to another card only after pointer enters that card's own rect (not the grace margin) and the old stack is not under the pointer.
- Buttons use `mouse_filter = STOP`; the card body uses `PASS`; clicking a button never triggers a card click/select. A click on the card body (not on a button) pins details and does nothing else.
- Hover is cancelled and the stack hidden instantly while a drag-less modal/prompt/target-pick is active, or when the response lock is on.

**Action flow**: click button -> if it needs a target/zone/material, the card enters `selected`, the stack closes, legal targets highlight, prompt panel states the instruction, Esc/right-click/Cancel returns to idle. Otherwise the action is sent immediately and the stack closes. Buttons target the card instance id captured at show time; if state changes (card moves, phase ends) before click, the stack is rebuilt/removed on the next state update and a stale click is ignored.

**Non-mouse fallback**: Tab/arrow keys move a focus ring across cards; Enter opens the same stack; number keys 1-4 pick actions; Esc closes. Touch: first tap = hover (shows stack and details), second tap on a button acts.

**Response lock**: while the opponent's response is pending (or our own prompt must be resolved), all action stacks are suppressed except those the pending prompt explicitly offers (e.g. a response Trap/Spell appears on that card with "Activate"). The turn bar button disables with a "Waiting for opponent" label.

**Hidden info**: opponent hand/face-down cards never show action stacks and details show only what is public. Own face-down cards show front details to the owner only.

## 8. Interaction states

| State | Visual | Input |
|---|---|---|
| Idle | normal frame; zones plain | hover available |
| Hover | lift, `hl_hover` glow, action stack (if any) | click body pins details |
| Selected | `hl_select` ring, lifted 4px, stack hidden | Esc/right-click cancels |
| Legal target | `hl_target` pulsing ring on every valid card/zone; invalid zones dim to 0.6 | click to confirm; invalid ignored with a small shake + `hl_danger` flash on prompt |
| Pending choice | board dims 0.55 except choosable items; prompt panel gold pulse and choice list | only prompt choices are active; details still inspectable |
| Waiting for opponent | board not dimmed but non-interactive for actions; turn bar shows "Opponent is acting..." with animated dots (static when reduced motion); inspect and log still work | hover shows details only |
| Opponent turn | opponent underglow; local actions suppressed except offered responses | inspect only |
| Paused / disconnected | full-screen dim 0.6 with centred panel ("Opponent disconnected, waiting 0:42" or Menu) | only menu/reconnect controls |
| Game over | banner (Victory/Defeat, Cinzel 56) over dim; board frozen; buttons for next game/series/menu | inspect, log |

## 9. Feedback, text and accessibility

- Phase banner and turn-change motion per art bible; prompt text always mirrored in the log.
- Minimum interactive target 28x28 base px; hover buttons >= 28 high. Minimum text 9 base px for chips, 11 for body. Verify legibility of ATK/DEF at 1280x800 screenshots.
- No info by colour alone (shape, arrow, text).
- `reduce_motion` and `fast animations` options in Menu (see art bible section 6).

## 10. Verification (screenshots to retain in `production/qa/evidence/`)

1. 1600x1000, 1280x800, 1920x1080: board matches reference geometry (6 aligned unit zones/side, traps beneath/above, power blocks right local/left opponent; unit square, power 2:3, trap 3:2; no overlap/clipping).
2. Both networked clients: each sees own units at bottom, own Powers on the right.
3. Hover on a hand card and a field card: stack on card, ATK/DEF/chips unobscured, pointer moves onto buttons without flicker, click acts on the right instance; no action buttons in details panel.
4. Illegal actions absent while: wrong phase, opponent's turn, response pending, insufficient AP.
5. Each state in section 8 captured once; before/after comparison against `2026-10-15-final/02_board.png`.
