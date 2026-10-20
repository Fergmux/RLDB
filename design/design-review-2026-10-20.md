# Design review, 20 October 2026 (item H1)

Author: art-director agent. Scope: every screen of the current build (before the release batch),
judged against the owner's brief: "nothing flat or plain, sound, animation and texture everywhere it
fits, everything must breathe". Owner call-outs D3 (title depth), D4 (fancier HP bar) and D5 (margins)
are specified in full here.

Screenshots reviewed: `production/qa/evidence/2026-10-20-release-batch/review-before/` (folders
`cards`, `catalogue`, `deckbuilder`, `f02`, `flow`, `inspect`, `modals`, `series`, `stats`,
`tutorial`). Paths in the findings table are relative to that folder. Most shots are 1600x900 or
1600x1000; the `cards`, `catalogue`, `deckbuilder`, `inspect` and `stats` shots were captured at
3840x2160 and read at a 2000 px preview, so the pixel values given for those are converted back to
1600x900 layout px.

Items already owned by other agents (A1, A2, B*, C*, D1, D2, D6-D15, E*, F*) are not specified
again. Where I saw a separate problem on the same screen, the row is marked **adjacent** and names
the owning item so the two changes don't collide.

---

## 1. Visual direction summary

### 1.1 What already works (keep it)

- **The two backdrops.** The forest-arch menu painting and the octagonal wooden duel table are
  strong, painterly and on-genre. They are the quality bar every overlay must match.
- **Card art and card frames.** The art is consistent in style. The cost coin, the element badge and
  the ATK diamond / DEF shield badges read well at every size from 1600 px.
- **OrnatePanel modals** (series rewards, deck choice, concede, lesson complete). The gold frame,
  corner filigree, header strip ("SERIES · REWARDS ... BEST OF 3") and the diamond divider are a good
  house frame. The rest of the app should be brought *up* to these, not the reverse.
- **Gold primary button** (`UIStyle.primary_button`): metal grain, sheen, a lifted shadow and a
  warm hover glow. A good base.
- **Card details sidebar**: the effect blocks with a coloured left rule (On Summon green, Once per
  turn gold, On Destruction red, Condition blue) are clear and attractive.
- **The pick gems** on the rewards screen (faceted gold hexagons with empty sockets) are exactly the
  "jewel and metal" language the rest of the HUD should use.
- Motion that already exists: HP number tween with a damage ghost (`PlayerPlate.HpBar`), the coin
  flip, "TRAP ACTIVATED" banner, fly-in card on trap activation, pile counters.

### 1.2 What drags it down (the pattern behind most findings)

1. **Two quality tiers.** The modals are ornate, but the persistent HUD (player plates, Menu button,
   log, prompt pane, phase pills, tooltips, settings controls, catalogue page header) is built from
   `UIStyle.flat()` boxes: a dark fill, a 1 px bronze line and a 6 px radius. Next to the painted table
   these read as debug UI.
2. **Flat type.** Every Cinzel heading ("RLDB", "CHOOSE YOUR DECK", "DEFEAT", "CARD CATALOGUE",
   panel headers) is a single flat fill with no shadow, outline or gradient. Against the busy
   backdrops it loses edge definition and looks pasted on (D3).
3. **No spacing system.** Paddings run from 2 px (catalogue title to page edge, Close button to
   frame) to 40 px in neighbouring elements. Panels have content touching scrollbars, frame edges and
   screen edges (D5).
4. **Dead space with no texture.** The Card Details panel is 60-70% empty in most board shots. The
   same goes for the Series sidebar, the catalogue's selected-card panel, the inspector's right column
   and the hot-seat privacy screen (pure #0a0a0a).
5. **Silent UI.** There are no hover sounds, no modal open/close sounds, no tab or toggle sounds, and
   no ambient motion on idle screens (no breathing glow, no motes, no shimmer).
6. **Mixed accent language.** Selection uses a *blue* corner bracket (`UIStyle.SELECT` #63b3ff) in a
   gold-and-bronze world. The danger actions (Concede, Delete) use the same gold primary style as the
   safe ones.

### 1.3 The unifying fantasy language

**"An arcane duelling table in a candle-lit hall."** Everything the player touches is a crafted
object on or above the table: gilded bronze frames, dark tooled leather, parchment insets and cut
gems. Light comes from **above-left, warm** (candle/lantern, #ffd9a0). Magic adds a **cool rim**
(#7fe6ff, the existing `PREVIEW` colour) only on interactive or magical states.

| Layer | Material | Use |
|---|---|---|
| Table | painted wood (existing backdrop) | the duel board, never covered by flat fills |
| Frames | gilded bronze: `BRONZE` #7a5a30 base, `GOLD` #d4a64a edges, `GOLD_HI` #f0cf7a top bevel | every panel border, plate border, divider |
| Surfaces | tooled leather: `PANEL` #1f1c1a + `UiSurface` leather grain at 0.55 | panel bodies |
| Insets | dark ink well: `PANEL_INK` #12100f with an inner shadow | text wells, log, input fields, stat boxes |
| Accents | cut gems (ruby HP, topaz AP, sapphire runes, emerald good) | resource displays, counters, pips |
| Magic | glow + motes, additive blend | hover, valid targets, summons, rewards |

**Depth rule:** every element sits on one of four depth levels and gets that level's shadow, so the
whole UI has a consistent light source.

| Depth | Examples | Drop shadow (offset, blur, colour) |
|---|---|---|
| 0 Table | board, zones | none (zones get an *inner* shadow, 0 2 6 #000 40%) |
| 1 Plate | player plates, pile chips, sidebar panels | 0 3 px, 8 px, #000 50% |
| 2 Raised | buttons, cards on the field, tabs | 0 4 px, 10 px, #000 55% |
| 3 Floating | hovered card, tooltips, prompt pane | 0 10 px, 24 px, #000 60% + 1 px #f0cf7a 15% top rim |
| 4 Modal | OrnatePanel dialogs | 0 16 px, 40 px, #000 70% + gold outer glow 12 px #d4a64a 35% |

**Motion rule ("breathing"):** nothing important is perfectly still. Idle highlights pulse on a
2.4 s sine loop at ±8% brightness. Gold frames on the active plate and on modal frames carry a slow
specular sweep every 6 s. Reduce-motion turns all loops off and keeps one static state.

### 1.4 Global style rules

#### 1.4.1 Title text treatment (D3, applies app-wide)

Three tiers. All use Cinzel (`UIStyle.font_title()` / `font_display(600-700)`). Implement once as
`UIStyle.title_label(text, size, tier)` plus a small `TitleText` Control that draws the layers (a
Label cannot draw a gradient fill). Use the label path only where a gradient isn't needed.

| Tier | Where | Size @1600x900 | Fill | Outline | Shadow | Glow / extra |
|---|---|---|---|---|---|---|
| **T1 Hero** | "RLDB" logo, VICTORY / DEFEAT, "YOU GO FIRST", "LESSON COMPLETE", "TUTORIAL COMPLETE" | 64-96 px (logo 88) | vertical gradient #fff1c4 (top) → #f0cf7a (45%) → #b8862e (55%, hard step for a "metal horizon") → #e2b75a (bottom). DEFEAT: #ffd0c4 → #e8605a → #8e2a22 → #c4473d | 2 px #2a1a08 | layer 1: offset (0, 3), blur 0, #000 85% (hard bevel); layer 2: offset (0, 8), blur 18, #000 60% | outer glow 14 px #d4a64a 30% (DEFEAT: #e8605a 30%); a specular sweep (a 30° white band, 18% alpha, additive) crosses the word every 6 s, 0.9 s per pass |
| **T2 Screen title** | "CHOOSE YOUR DECK", "CARD CATALOGUE", "DECK BUILDER", "SETTINGS", "CREDITS", modal titles, "GAME 1 COMPLETE - REWARDS", "PASS TO ANA", prompt pane title | 30-40 px | gradient #f6dc96 → #d4a64a → #a97c34 (top to bottom) | 1 px #1a1208 | offset (0, 2), blur 0, #000 80% + offset (0, 4), blur 8, #000 50% | none; a 1-shot sweep when the panel opens |
| **T3 Section header** | "GAME LOG", "CARD DETAILS", "SERIES", "ALL CARDS", "PREVIEW", "YOUR DECK", "STATUSES", "RULES", "GAME HISTORY" | 16-20 px, letter-spacing +1.5 px | flat `GOLD` #d4a64a | none | offset (0, 1), blur 0, #000 90% | a 1 px engraved underline (gold 45%) with a 1 px #000 50% line below it |

Menu items ("RESUME", "PLAY"...) are T2-sized but use an *ivory* fill: #ece4d2 with a 1 px #000 70%
outline and the T2 shadow. On hover they shift to the T2 gold gradient and get the glow.

Implementation: Godot 4.6 `Label` supports `font_outline_color`, `outline_size`, `font_shadow_color`,
`shadow_offset_x/y` and `shadow_outline_size` (use a soft shadow via shadow outline). Two shadow
layers and the gradient need a custom draw: `draw_string` into the Control with a `CanvasItem`
material using a 1D `GradientTexture2D` sampled on `UV.y` (technical-artist owns the shader).

#### 1.4.2 Spacing scale (D5)

One 4 px base unit. **No hand-written margins outside this table.** Add `UIStyle.SPACE` (dictionary)
and `UIStyle.pad(box, token)`.

| Token | px @1600x900 | Use |
|---|---|---|
| `xs` | 4 | icon to label, chip inner vertical |
| `sm` | 8 | inside chips/pills, between related lines, button text vertical |
| `md` | 12 | between controls in a row, list-row padding, button text horizontal (min 16) |
| `lg` | 16 | panel inner padding (sidebar panels), between groups inside a panel |
| `xl` | 24 | modal inner padding, between sections of a modal, screen edge to page title |
| `xxl` | 32 | screen edge for full screens (catalogue, deck builder), modal to its buttons row |
| `xxxl` | 48 | hero title breathing room, modal top padding above a T1 title |

Fixed rules:
- **Screen safe margin:** 24 px on all sides for HUD elements (Menu button, player plates,
  sidebar); 32 px for full-page screens (catalogue, deck builder title and Back).
- **Panel inner padding:** 16 px (sidebar), 24 px (modals). Content never sits closer than 12 px to
  a frame line, a scrollbar or a filigree corner (OrnatePanel corners are about 20 px, so
  modal content keeps 28 px from the corners).
- **Scrollbars:** 8 px track, inset 6 px from the frame, with 12 px between the content and the track.
- **Text to frame:** body text keeps ≥ 12 px from any border; titles keep ≥ 16 px.
- **Grid gutters:** card grids use equal horizontal and vertical gutters (16 px at catalogue scale).
- **Button rows:** 12 px between buttons, and the row keeps 24 px from the modal bottom edge.
- **Line height:** body 1.35, log 1.3, card text 1.2.

#### 1.4.3 Panel and frame hierarchy

| Level | Widget | Frame | Body | Header |
|---|---|---|---|---|
| **F1 Modal** | `OrnatePanel` | 3 px gilded bronze (outer 1 px #3a2a12, 1 px `GOLD`, 1 px `GOLD_HI` top only), filigree corners, outer glow (depth 4) | leather grain + 8% top-down warm gradient (#ffd9a0 at 6% to transparent) | strip 28 px with an embossed label left (T3 small, 12 px) and a context tag right |
| **F2 Sidebar / plate** | `HousePanel` | 2 px bronze bevel: 1 px `GOLD` 70% outer, 1 px #000 60% inner, corner rivets (4 px gold dots) | leather grain, vignette (edges 20% darker) | T3 header + engraved underline |
| **F3 Inset well** | new `InsetBox` style | 1 px #000 70% top/left, 1 px `GOLD` 12% bottom/right (engraved) | `PANEL_INK` + inner shadow 0 2 6 #000 60% | none |
| **F4 Chip / pill / tag** | chips, phase pills, stat tags | 1 px colour border at 70% + 1 px top highlight (#fff 10%) | colour at 22% over ink, 4 px vertical gradient | n/a |
| **F5 Tooltip** | `status_tip`, board hover tip | 1 px `GOLD` 60% + 4 px rounded corners, small 6 px pointer notch toward the source | parchment-dark (#1b1712) + leather grain 0.3 | card name in T3 gold, 15 px |

Rules: never nest two F1s. Never place an F3 directly on the table (it must sit inside F1/F2). Plain
`UIStyle.flat()` is reserved for internal pieces (bar sockets, separators) and must not be the
outer look of any visible box.

#### 1.4.4 Button states

Three families. All are JuicyButton; all get a hover sound and a press scale.

| State | Primary (gold) | Secondary (bronze-iron) | Danger (ember) |
|---|---|---|---|
| Normal | gold metal, 2 px bottom bevel `GOLD` darkened 35%, text `ON_GOLD` #1a1208, depth-2 shadow | dark iron #2b2724 → #1d1a18 gradient, 1 px `BRONZE` border, 1 px top highlight #fff 8%, text `TEXT` | #5a1c18 → #3a120f, 1 px #e8605a 70% border, text #ffd8d2 |
| Hover (120 ms in) | `GOLD_HI` fill, glow 9 px `GOLD_HI` 45%, scale 1.03, sheen sweep 350 ms | border `GOLD` 90%, text `GOLD_HI`, inner glow 6 px gold 20%, scale 1.03 | border #ff8a7a, glow 8 px #e8605a 40%, scale 1.03 |
| Pressed (60 ms) | darken 15%, offset +1 px y, shadow 2 px, scale 0.97 | the same | the same |
| Focus (keyboard) | 2 px `GOLD_HI` ring, 3 px outside the button, pulsing 2.4 s | the same | the same |
| Disabled | `PANEL` fill, 1 px #3a342c border, text `DISABLED` #918874 at 100% (not lower: it must stay readable), no shadow, no grain | the same | the same |
| Waiting / busy | secondary style + a moving 3-dot shimmer (`WaitingDots`) | | |

Sizes: height 36 px (small), 44 px (standard), 52 px (hero CTA such as "Go to Battle Phase", "Start
series"). Horizontal padding ≥ 20 px. Minimum width 120 px. Labels never wrap. If they don't fit,
the layout gives the button more width or the label is shortened.

Use: exactly one primary per view. **Destructive confirms (Concede, Delete deck, Quit to desktop,
Remove card) use Danger.** Cancel / Keep playing becomes Secondary and holds default focus.

#### 1.4.5 Motion vocabulary

All durations go through `UIStyle.dur()` (fast animations halve them). Reduce motion: travel and
scale are replaced by a 120 ms fade; loops stop.

| Token | Duration | Easing (Godot) | Use |
|---|---|---|---|
| `tick` | 80 ms | SINE / OUT | colour change on hover, checkbox tick |
| `hover` | 120 ms | QUAD / OUT | button/card hover scale and glow in; out at 180 ms |
| `press` | 60 ms down, 140 ms back | QUAD / OUT, back: BACK / OUT | button press |
| `panel_in` | 260 ms | BACK / OUT (overshoot 1.2) scale 0.94→1, alpha 0→1, y +12→0 | modals, prompt pane, tooltips (tooltips: 140 ms, no overshoot) |
| `panel_out` | 160 ms | QUAD / IN | modal close |
| `slide` | 320 ms | QUART / OUT | sidebar content swap, tab change (content cross-fades 180 ms) |
| `card_move` | 380 ms | CUBIC / IN_OUT along an arc (apex 40 px) | hand to field, field to pile |
| `impact` | 90 ms hit-stop + 220 ms shake (amplitude 6 px decaying) | ELASTIC / OUT on the receiving element | attack hit, big damage |
| `count` | 400 ms | QUART / OUT | numbers (HP, AP, counters, stats) count to the new value |
| `stagger` | 40 ms per item | n/a | lists, grids, reward tiles appearing |
| `breathe` | 2400 ms loop | SINE / IN_OUT | idle glows, active-turn plate, valid-target pulse |
| `sweep` | 900 ms every 6 s | SINE / IN_OUT | specular sweep on T1 titles, gilded frames, primary CTA when it is the expected action |
| `celebrate` | 1200 ms | BACK / OUT then SINE | victory, lesson complete, reward picked (with motes) |

Ambient: menu backdrop gets drifting petal/mote particles (~25 on screen, 8-14 s lifetime, 4-10 px,
alpha 0.4) and a 0.6% scale "Ken Burns" drift over 40 s. The duel table gets very sparse dust motes
in the light cone (~10).

#### 1.4.6 Sound vocabulary

Existing files cover clicks and gameplay well. The gaps are in UI feedback. New sounds go in
`tools/gen_sfx.py` (procedural), are registered in `Sfx`, and are kept at -18 to -24 LUFS short-term
so they sit under the music. Visual mood to match: warm wood, brass and soft magical shimmer, never
an electronic beep. (The audio-director owns the layers, mix and triggers. This table is the visual
event list that needs a cue.)

| Event | Existing | Proposed new cue (character) |
|---|---|---|
| Button / menu-item hover | none | `ui_hover`: a very soft wooden tick or brass brush, 40 ms, randomised pitch ±4%, max 1 per 60 ms |
| Primary click | `click_primary` | keep |
| Secondary click | `click_secondary` | keep |
| Back / Cancel / Close | `back` | keep |
| Modal open | none | `panel_open`: a parchment unfurl with a low brass shimmer, 250 ms |
| Modal close | none | `panel_close`: a soft reverse of the above, 160 ms |
| Tab switch | none | `tab`: a leather-flap thump, 90 ms |
| Checkbox / toggle | none | `toggle_on` / `toggle_off`: a latch click, two pitches |
| Slider drag | none | `slider_tick`: a tiny tick every 10% step |
| Tooltip appear | none | silent (it would be too frequent) |
| AP gem fill / spend | (D6 owns AP/HP sounds) | adjacent: gem chime on fill, a dull crack on spend |
| HP damage / heal | `damage` / `heal` | add `hp_low_heartbeat` for the low-HP loop (see D4) |
| Coin flip | none (reused?) | `coin_flip`: a metallic flick, spin whirr, and a land ring |
| Reward reveal / pick | `notice` | `reward_reveal` (rising chime) and `reward_pick` (gem set) |
| Turn banner "Your turn" | `turn` | keep |
| Deck-select tile hover | none | `ui_hover` |
| Search no results | none | silent |
| Toast / saved | none | `notice` (existing) at -6 dB |
| Tutorial step complete | none | `step_done`: a small bright chime |
| Error / off-script hint | `deny` | keep |

---

## 2. Findings

### 2.1 Owner call-out specs

#### D3: title depth (app-wide)

Apply the §1.4.1 tiers everywhere a Cinzel heading is drawn. The full inventory:

| Tier | Strings / places | Owner file |
|---|---|---|
| T1 | "RLDB" logo; VICTORY / DEFEAT; "BEN GOES FIRST" coin-flip banner; "TRAP ACTIVATED" and the other FX banners; "LESSON COMPLETE", "TUTORIAL COMPLETE"; the "YOUR TURN" banner | `menu/main_menu.gd`, `fx/fx_game_end.gd`, `fx/fx_banner.gd`, `fx/coin_flip.gd`, `tutorial/tutorial_overlay.gd` |
| T2 | "CHOOSE YOUR DECK", "DRAFT YOUR DECK", "NEXT GAME", "GAME 1 COMPLETE — REWARDS", "CARD CATALOGUE", "DECK BUILDER", "SETTINGS", "CREDITS", "YOUR STATISTICS", "TUTORIAL", "PASS TO ANA", "MATCH PAUSED", "CONCEDE THIS GAME?", "DELETE DECK", "INTERFACE SETTINGS", the prompt pane title, the inspector card name, the pile browser title "SPENT (8)", the main menu items (ivory variant) | `widgets/ornate_panel.gd` (`add_headline`), `widgets/house_panel.gd`, `menu/card_list_screen.gd`, `deck_builder.gd`, `game/prompt_plate.gd`, `inspect/card_inspector.gd`, `inspect/pile_browser.gd`, `menu/menu_item.gd` |
| T3 | Every panel header (GAME LOG, CARD DETAILS, SERIES, YOUR DRAFT, YOUR EXTRA DECK, ALL CARDS, SELECTED CARD, PREVIEW, YOUR DECK, MAIN DECK, EXTRA DECK, STATUSES, RULES, GAME HISTORY, WHAT YOU LEARNED), "TURN 1 · BEN", the player plate names | `widgets/house_panel.gd`, `game/game_sidebar.gd`, `board/player_plate.gd`, `game/game_reward_panels.gd`, `game/game_series_overlay.gd` |

Acceptance: at 1600x900, every heading over a busy backdrop (menu trees, table wood) keeps a
visible dark edge on all sides. A screenshot at 50% grey desaturation still separates title from
ground. Reduce motion removes the sweep only.

#### D4: HP bar ("Vial of Life")

Current (`board/player_plate.gd` `HpBar._draw`): a 26 px flat dark rounded rect with a flat red
fill (#a8372d), a 12% white top band, a pale damage ghost and the number drawn on top at 22 px.
It reads like a progress bar from a web form.

Target: an **enamelled ruby vial set in a gilded bronze bezel**, the HUD's centrepiece.

| Part | Spec |
|---|---|
| Size | 228 x 30 px inside the 252 px plate (height up from 26). The plate grows by 4 px. |
| Bezel (frame) | Outer: 1 px #1a1006. Then a 3 px gilded ring: a vertical gradient `GOLD_HI` #f0cf7a (top) → `GOLD` #d4a64a → `BRONZE` #7a5a30 (bottom), with `UiSurface.METAL` grain at 0.10. Inner: 1 px #000 80% (the lip). Radius 8 px outer / 5 px inner. End caps: a small faceted gem stud (6 px diamond, `GOLD_HI` with a white 1 px glint) at the left and right ends, overlapping the bezel by 2 px. |
| Well (empty part) | #140808 with an inner shadow (0 3 px 6 px #000 70%) and a faint scratched-glass texture (`UiSurface` leather grain at 0.15, tinted #3a1210). Reads as an empty glass tube. |
| Fill (liquid) | A 3-stop vertical gradient: #ff7a5c (top 0-20%, the meniscus highlight) → #c42a1f (core) → #6e0f0c (bottom). A scrolling noise texture (a 64x32 tileable Perlin, 18% alpha, additive) drifts left at 6 px/s so the liquid moves. The leading edge is a bright 2 px meniscus line (#ffb9a0 70%) with a soft 6 px glow. |
| Glass highlight | A 1 px white 35% line at y = 3 px across the full well (not just the fill) and a 40% → 0% white sheen in the top 35%. A specular glint (an 18 px soft white oval, 25% alpha) sweeps left→right every 7 s (`sweep`). |
| Segment ticks | Every 10 HP (for max 60: 5 ticks), a 1 px #000 35% line with a 1 px #fff 8% line beside it, drawn over the fill, so the amount reads at a glance. |
| Number | Cinzel 700, 22 px, centred-left at x = 10, `TEXT` with a 2 px #2a0806 outline and a 0 2 0 #000 80% shadow. "HP" is Alegreya Sans Bold 11 px at 70%. Keep the count tween (`count`, 400 ms QUART OUT). On the right end, inside the bar: "/ 60" in 11 px at 50% (it shows the scale; optional, hide under 40% width). |
| Damage trail | On damage: (1) a 90 ms white flash over the lost segment, (2) the lost segment turns *amber* #ffb08a and holds 350 ms, (3) it drains to the new value over 450 ms (QUAD IN_OUT), leaving 3-6 small ember particles that fall 12 px and fade (400 ms). The whole plate shakes: 4 px, 220 ms, decaying (skipped under reduce motion). The number punches to 1.18 scale and back (BACK OUT, 220 ms) and tints `BAD`. A hit of ≥ 10 HP adds a 120 ms red vignette pulse on that side of the screen (8% alpha). |
| Heal shimmer | The gained segment first appears as an emerald-gold glow (#8fffb0 at 55% over #6fd38a), then the red liquid "pours" into it over 500 ms (QUART OUT). A shimmer band (a 24 px wide diagonal white 40% gradient) runs along the new fill once (600 ms). Rising sparkle motes (5-8, green-gold, 600 ms) rise from the bar. The number tints `GOOD` and scales to 1.12. |
| Low-HP state (≤ 25% of max, i.e. ≤ 15 of 60) | The fill brightens to #e0402f, and a `breathe` pulse runs at 1.1 s (faster than normal) on the bezel's inner glow (#ff4a3a, 0 → 45%). A faint crack decal (a hairline SVG, 30% white) appears across the glass. The plate border shifts from bronze to #8e2a22. Sound: `hp_low_heartbeat`, once on entry, then every 2.2 s while it is the local player's turn, at -12 dB (the audio-director decides the mix). Reduce motion: a static red inner glow at 35%, no pulse. |
| Critical (≤ 10%) | Add ember motes drifting up from the fill (2 per second). |
| Overheal / max change | If max HP rises, the bezel stretches with a 300 ms tween; never rescale the fill instantly. |
| Lethal | Already owned by the lethal-blow FX; the vial should *shatter*: the glass cracks 150 ms, then the fill drains to 0 and 8-12 glass shards fall (this matches the existing lethal-blow quality bar). |

Implementation: replace `HpBar._draw` with layered draws plus one `ShaderMaterial` on the fill
rect (gradient, scroll noise, meniscus, ticks). The technical-artist writes `hp_vial.gdshader`;
UI programmer wires the uniforms `fill`, `ghost`, `heal_glow`, `low_hp`, `time`. Keep the public
`set_hp(v, snap)` API and its tests unchanged.

**AP gems (same pass, same plate):** match the vial. Each AP is a 16 px faceted topaz (a radial
gradient #fff1b0 → #f2b544 → #9a6416 with a 1 px dark outline and a white 2 px glint top-left), set
in a 20 px bronze socket. A spent gem becomes a dark, cracked socket (already in the policy) with a
1 px inner rim. Gaining a gem: it pops in (scale 0 → 1.15 → 1, 260 ms BACK OUT) with a chime. Spending:
it dims through amber to dark in 200 ms and emits a 3-particle puff. (Sounds are D6, adjacent.)

#### D5: margin audit

Every margin violation I measured is in the table below with the tag **[D5]**. The fix is always
"move to the §1.4.2 token named". After WP-1 lands, the UI programmer re-shoots every screen and
checks the 12 px content-to-frame floor with an overlay (`--debug-margins` draws a 12 px red inset
on each PanelContainer; a dev-only flag).

### 2.2 Findings table

Severity: **P1** blocks release quality, **P2** noticeable, **P3** polish. Pixel values are 1600x900
layout px (preview values from the 3840 shots converted at x0.8). File paths are relative to
`rldb/src/ui/` unless they start with `rldb/`.

| # | Screen | Screenshot | Problem | Sev | Fix | File(s) |
|---|---|---|---|---|---|---|
| 1 | Main menu | `cards/00b_credits_1600x1000.png`, `cards/00c_settings_surfaces_1600x1000.png` | **[D3]** "RLDB" logo is one flat gold fill (#d4a64a-ish), no outline, shadow or bevel; against the dark trees its left edge dissolves. It is the first impression and looks like a placeholder. | P1 | T1 hero treatment (§1.4.1) at 88 px: gradient fill, 2 px #2a1a08 outline, a two-layer shadow, a 14 px gold glow, a specular sweep every 6 s. Add a thin engraved rule plus a diamond under it (the house divider) at 24 px below. | `menu/main_menu.gd` |
| 2 | Main menu | same | Subtitle "A TWO-PLAYER ROGUELIKE DECK BATTLER" is about 11 px Cinzel in `TEXT_DIM` on dark foliage: the contrast is about 3:1 and it reads as small print. | P2 | 13 px Cinzel 600, letter-spacing +2 px, `MUTED` #c2b8a2, 1 px #000 80% shadow. Keep 16 px from the logo baseline. | `menu/main_menu.gd` |
| 3 | Main menu | same | Menu items are flat ivory Cinzel with no shadow; the hovered item only gets a diamond and an underline. No glow, no motion, no hover sound. | P1 | Ivory T2 variant at rest; on hover a gold gradient, a 10 px gold glow, slide right 6 px (120 ms QUAD OUT), the diamond fades and scales in, and `ui_hover` plays. Press: 0.97 scale and `click_primary`. | `menu/menu_item.gd` |
| 4 | Main menu | `stats/01_empty_1600x900.png` | Submenu "BACK" is about 70% of the size of the other items and much dimmer; it reads as disabled rather than as a navigation item. | P2 | Same size as the siblings minus 15% (not 30%), in `MUTED` with a "‹" glyph; the same hover treatment. Gap above it: 16 px (currently about 8). | `menu/main_menu.gd`, `menu/menu_item.gd` |
| 5 | Main menu | `cards/00b_credits...` | **Adjacent F1.** Besides the wording, the status line at the bottom left is 9-10 px `TEXT_DIM` at about 2.5:1 contrast and sits 24 px from the bottom, much closer than the 63 px left inset. | P3 | 12 px Alegreya, `MUTED`, inside a 24 px safe margin on both axes; put the build version in the right corner to balance. | `menu/main_menu.gd` |
| 6 | Main menu | all menu shots | The menu backdrop is a static image; nothing breathes. | P2 | Ambient: 20-30 drifting petal motes (pink #e8a0b0 and gold #f0cf7a, 4-10 px, 8-14 s, alpha 0.35-0.5), a 40 s Ken Burns drift (1.00 → 1.006 scale) and a soft light shaft in the arch (an additive gradient pulsing 4 s). Reduce motion: static. | `menu/main_menu.gd`, new `fx/fx_ambient_motes.gd` |
| 7 | Main menu modals | `cards/00b_credits...`, `cards/00c_settings...` | Every menu modal's header strip says "MAIN MENU", so the context tag adds no information. | P3 | Left tag = section ("OPTIONS", "ABOUT", "PLAY"), right tag = context ("THIS DEVICE", "v0.3.6"). | `menu/main_menu.gd` |
| 8 | Credits | `cards/00b_credits...` | **[D5]** The body text runs to about 4 px from the scrollbar (the "CC0 1.0" line wraps right at the track). Only about 6 px above each section heading. The last heading "ENGINE" is cut at the bottom edge with no fade. | P2 | 12 px gap to the scrollbar track, 20 px above each section heading, 8 px below. A 24 px bottom fade mask on the scroll area (`ScrollArea` fade). The section headings use T3. | `menu/main_menu.gd`, `widgets/scroll_area.gd` |
| 9 | Settings (menu) | `cards/00c_settings...` | Controls are visually uneven: the dropdowns are about 85 px wide and 22 px high; the sliders have a 2 px track and a tiny knob with no fill colour; the "Mute" checkboxes float 30 px right of the sliders and line up with nothing. Row pitch varies (36 / 36 / 47 / 47 px). | P2 | A 2-column form grid: a 160 px label column, a 280 px control column, a 12 px gap, a fixed 44 px row pitch. Dropdowns 200x32. Sliders: a 6 px inset track (F3), a gold fill to the knob, an 18 px gem knob with hover glow, and `slider_tick`. Mute becomes a speaker icon toggle (24 px) at the end of the slider row. | `ui_style.gd` (`display_controls`), `menu/main_menu.gd` |
| 10 | Settings (menu) | same | The statistics explanation is 10 px `TEXT_DIM` with tight leading; it is the most legally important text in the panel and the hardest to read. | P2 | 12 px, `MUTED`, line height 1.35, indented 32 px to align with the checkbox label, 8 px below its checkbox. | `ui_style.gd`, `menu/main_menu.gd` |
| 11 | Settings (menu) | same | The modal has no visible Close / Back button; the only way out is the left menu or Esc. Checkboxes are plain squares with a gold tick, no hover state. | P2 | A secondary "Close" at the bottom right (24 px inset). Checkboxes: a 20 px bronze-bevel box, the tick draws on (80 ms) with `toggle_on`/`toggle_off`, and the row highlights 6% gold on hover. | `menu/main_menu.gd`, `ui_style.gd` (`_check_icon`) |
| 12 | Settings (in game) | `modals/07_game_settings.png` | **[D5]** The Close control is a thin full-width bar about 18 px high with 10 px text, 6 px from the bottom frame and 4 px from the filigree corners. The 8 px statistics description text has lines almost touching. | P1 | A standard 44 px secondary button, 160 px wide, centred, 24 px from the bottom edge. The description follows #10. The modal gets the same form grid as #9 so the two settings screens match exactly (one shared builder). | `game/game_menu.gd`, `ui_style.gd` |
| 13 | Settings (in game) | same | The modal is pinned to the top right, overlapping the opponent plate and touching the Menu button (a 4 px gap). It isn't centred, so it reads as a dropdown that grew too large. | P2 | Centre it on the board area (x centre 620 at 1600 width), with the standard modal veil (#000 55%) and `panel_in`. | `game/game_menu.gd` |
| 14 | Game menu | `tutorial/018_ring_under_game_menu.png` | The four stacked buttons are all identical iron secondaries with a 7 px gap and a 10 px inset from the frame; "Concede game" and "Quit to desktop" look the same as "Settings". The frame top corners collide with the Menu button. | P2 | 12 px gaps, a 16 px inset, a divider before the destructive group; "Concede game" and "Quit to desktop" use the Danger style. Drop the panel 8 px below the Menu button with a 6 px pointer notch. Open with `panel_in` (140 ms, from the button) and `panel_open`. | `game/game_menu.gd` |
| 15 | Board HUD | `modals/06_game_menu.png`, `inspect/09_sidebar_pile_list.png` | The Menu button is a tiny (about 68x26) flat iron box, 6 px from the screen top, the weakest object on screen. | P2 | 40 px high, 96 px wide, a secondary style with a ☰ glyph plus "Menu", 16 px from the top edge, right-aligned 16 px left of the sidebar. **Adjacent A1** (the Chat button will sit next to it: use the same size and a 12 px gap). | `game/game_ui.gd`, `game_screen.gd` |
| 16 | Board HUD | `inspect/09...`, `series/prompt_02_type.png` | "OPPONENT HAND" is about 9 px dim Cinzel pinned 13 px from the top-left corner; it looks like a debug caption. | P2 | Remove the caption and let the card backs speak. If a label is wanted: a T3 15 px small plate under the fan, with a count chip ("5"). The fan sits 24 px from the edges. | `game/game_hand_view.gd`, `game/game_board_view.gd` |
| 17 | Player plates | `flow/*`, `modals/*`, `series/*` | **[D4]** The plates themselves are `UIStyle.flat` boxes: 1 px bronze, a 6 px radius, no texture, no depth. They are the most-looked-at HUD and the flattest. | P1 | An F2 HousePanel style: a 2 px gilded bevel, corner rivets, leather grain, depth-1 shadow. The active player's plate gets a gold rim `breathe` (2.4 s) and a 1 px `GOLD_HI` top sweep; the inactive plate's border drops to bronze 60%. | `board/player_plate.gd` |
| 18 | Player plates | same | The turn marker is a text "▶" glyph in front of the name; the name is flat Cinzel. | P2 | Replace with a 12 px gold gem marker (the same faceted language) that pulses with the plate rim. The name uses T3 at 18 px. | `board/player_plate.gd` |
| 19 | Player plates | `flow/*` | **[D4]** HP bar: see the D4 spec above. | P1 | Vial of Life spec. | `board/player_plate.gd`, new `assets/shaders/hp_vial.gdshader` |
| 20 | Player plates | `modals/06_game_menu.png` | The AP gems are flat yellow discs (about 12 px) with no facets; "AP 2/2" is gold Cinzel crowding the gems with a 6 px gap. | P2 | The topaz gem spec under D4; a 10 px gap to the label; the label in 13 px Alegreya Bold `MUTED`, numbers `GOLD_HI`. | `board/player_plate.gd` (`ApGems`) |
| 21 | Player plates | `tutorial/003_L1_s01_read.png` | Before the first turn the plate shows "AP 0" with no sockets, so the plate looks broken and lopsided. | P3 | Show two empty sockets (dark, not cracked) with "AP 0/2" in `TEXT_DIM`. | `board/player_plate.gd` |
| 22 | Board | all board shots | The empty zones are flat semi-transparent rectangles (brown, red for traps, blue for powers) laid over the painted wood; their glyphs (a cross, an eye, a diamond) are flat. They look like UI placeholders, not part of the table. | P1 | Make each zone an inlaid recess: an inner shadow (0 2 6 #000 50%), a 1 px darker rim and a 1 px `GOLD` 10% bottom-right highlight, the tint at 18% (down from about 35%) multiplied over the wood, not alpha-over. Glyphs are engraved (a 1 px dark top + 1 px light bottom offset) at 25% alpha. | `zones.gd`, `game/board_deco.gd`, `game/zone_ring.gd` |
| 23 | Board | same | Nothing on the table moves when idle. | P2 | Very sparse warm dust motes in a centre light cone (8-12, 10-16 s), and the valid zones/cards `breathe`. Reduce motion off. | new `fx/fx_ambient_motes.gd`, `game/board_deco.gd` |
| 24 | Pile chips | `inspect/09...`, `flow/*` | The "DRAW / EXTRA / SPENT / EXHAUST" labels are 9 px dark name plates; the "0" counters for empty piles are dull dark circles. Next to the full piles' card backs they look unfinished. | P2 | Labels 11 px Cinzel 600 on an F4 bronze plate (24 px high), centred under the pile with a 6 px gap. Empty piles show an engraved outline of a card back (dashed bronze 30%) with a centred count medallion (a 28 px bronze coin with an embossed number). Counts tween (`count`) and pulse when they change. | `board/pile_stack.gd`, `game/deck_crest.gd` |
| 25 | Field cards | `series/prompt_02_type.png` | The "ready" chevron badges (gold circle "^") sit on the top edge of each field card and overlap the zone above by about 8 px; on a busy board they become a row of noise. | P2 | Badge 18 px (from 22 px), moved inside the card's top border; idle `breathe` on its glow only. Hide it on the opponent's cards. | `card_widget.gd`, `card/card_overlays.gd` |
| 26 | Field cards | `series/prompt_02_type.png` | On the field the name plate drops to about 6-7 px ("GUARDIAN OF THE FOREST", "ALEISTER THE INVOKER" in two lines): unreadable. | P3 | Minimum 9 px; one line with ellipsis; the full name goes in the hover tooltip and details. | `card/card_text_layout.gd`, `card/card_layouts.gd` |
| 27 | Field cards | `tutorial/069_L5_s06_do.png` | Valid targets get a solid flat yellow rectangle and a hard 3 px border; the invalid cards are dimmed. The highlight is static and flat. | P2 | The valid target gets an outer glow 10 px `TARGET` 55% that `breathe`s (0.55 ↔ 0.85), a 2 px border with a moving dash shimmer (1.4 s loop) and a corner bracket in gold, not a full fill. **Adjacent D9** (the toned-down preview variant; share the code path). | `game/game_targeting.gd`, `card/card_overlays.gd` |
| 28 | Board | `tutorial/022_L2_offscript_hint.png` | The zone highlight for summoning is a flat yellow fill at about 45% that covers the wood completely, and the hovered zone gets a white square frame. | P2 | Fill 15% plus an inner glow 12 px `TARGET` 50%, a 2 px gold border, and the hovered zone lifts its glow to 80% with a rising mote. | `game/game_targeting.gd`, `zones.gd` |
| 29 | Selection | `catalogue/02_selected_1600x900.png`, `inspect/09...` | The selection bracket is *blue* (`SELECT` #63b3ff) corner brackets; it is the only cold accent in a gold world and reads as an editor gizmo. | P2 | Selection = `GOLD_HI` corner filigree brackets (an L with a small diamond), 2 px, with a soft 6 px glow; keep blue only for the *magic preview* (`PREVIEW`). Change `UIStyle.SELECT` to #f0cf7a and audit uses. | `ui_style.gd`, `card/card_overlays.gd`, `widgets/card_browser.gd` |
| 30 | Hand | `inspect/09...`, `modals/*` | **[D5]** The hand cards sit flush with the screen bottom (0-3 px); their rule text runs off the screen edge, so the text box is cropped mid-line. | P2 | Either show the whole card with 16 px clearance or crop cleanly *above the text box* (show the art, name and type line, and rely on hover to rise). Recommended: crop at the type line, with a 24 px gradient fade into a dark wood bottom rail. **Adjacent D2** (shrink on summon). | `game/game_hand_view.gd` |
| 31 | Hand | same | There is no hand tray; the cards float over the wood with no ground. | P3 | A subtle bottom rail: a 64 px tall dark-wood gradient (#000 0% → 45%) with a 1 px gold 15% top line, behind the hand. | `game/game_hand_view.gd`, `game/board_deco.gd` |
| 32 | Hand | general | Hover lift exists, but there is no hover sound and no lift shadow change. | P2 | On hover: rise 36 px and scale 1.12 (120 ms QUAD OUT), the shadow grows from depth 2 to depth 3, `ui_hover` (card variant: a paper slide). | `game/game_hand_view.gd`, `game/game_hover_controller.gd` |
| 33 | Prompt pane | `series/prompt_06_long_title.png` | The prompt title is 18 px Cinzel caps in a 170 px column: "CHOOSE A STANCE FOR BASTION WYRM, THE ETERNAL GUARDIAN OF THE OBSIDIAN CITADEL." takes 7 lines (about 190 px) and pushes the actions down. Caps at that length are hard to read. | P1 | The pane grows to 236 px wide (it has room: the board's left gutter is 20-215 px). Title: T2 at 17 px **sentence case**, with the card name in `GOLD_HI` on its own line: "Choose a stance for" / "Bastion Wyrm, the Eternal Guardian of the Obsidian Citadel". Auto-shrink to 14 px for more than 3 lines. | `game/prompt_plate.gd`, `game/game_prompt_banner.gd` |
| 34 | Prompt pane | `series/prompt_06_long_title.png` | Attack / Defense / Cancel are small iron secondaries (about 60x30) of the same weight; the answer buttons and the escape hatch aren't differentiated. | P2 | Answer buttons: full-width 44 px, with icons (sword / shield), Attack styled in an ember tint and Defense in a steel tint (F4 colour plates). Cancel: a text-only link button, 13 px, underlined on hover, 16 px below. | `game/prompt_plate.gd` |
| 35 | Prompt pane | `tutorial/104_L7_arcane_picker.png` | "Confirm" in the disabled state is a near-invisible ghost (#2a2623 on #1f1c1a); the player can't find it. The pick pips (3 hollow circles) are flat. | P2 | Disabled per §1.4.4 (still clearly a button, readable label). Pips: use the rewards' gold hex gems (empty socket → filled gem with a pop and chime). | `game/prompt_plate.gd`, `game/pick_pips.gd` |
| 36 | Prompt pane | `tutorial/022...`, `series/prompt_02_type.png` | The card preview inside the pane is a small thumbnail plus a 2-line text with "No rules text" in italic; the box has 4 px padding. | P3 | 12 px padding; hide "No rules text" (just show name and type); thumbnail hover opens the details. | `game/prompt_plate.gd` |
| 37 | Prompt pane | `series/prompt_02_type.png` | The type buttons look good (coloured plates with icons) but they have no hover lift or sound, and the 8 px gaps are tight. | P3 | 10 px gaps; hover per §1.4.4 with the type colour as the glow. | `game/prompt_plate.gd` |
| 38 | Waiting plate | `series/prompt_07_waiting.png` | "BEN IS RESPONDING..." is a flat pill laid over the board's centre line; it covers Diggie's ATK/DEF badges, and the "..." is static text. | P2 | Move it to the top of the opponent half (y about 160) or dock it to the opponent plate. An F5 tooltip frame, an hourglass glyph that rotates, and `WaitingDots` animating. Fade in after 250 ms (don't flash on fast replies). | `widgets/wait_plate.gd`, `widgets/waiting_dots.gd` |
| 39 | Turn panel | all board shots | "TURN 1 · BEN" is flat Cinzel. The phase pills (Setup / Battle / Recovery) are three separate flat capsules with no sense of sequence. | P2 | Phase track: three linked gem-capsules joined by a 2 px engraved line; done phases get a small ✓ and dim to 60%, the current one is gold with a `breathe` glow, the next one is bronze. Phase change: the light travels along the line (320 ms) with `phase`. | `game/phase_pips.gd`, `game/game_sidebar.gd` |
| 40 | Turn panel | `tutorial/003...`, `tutorial/022...` | When no action is available, the CTA slot shows "Go to Recovery" on a dark plate (disabled) or "CHOOSE A TARGET" in Cinzel caps inside a button frame, so a status message and a button share one look. | P2 | Status messages are not buttons: show them as an F3 inset with 14 px italic `MUTED` text and an animated arrow toward the prompt pane; keep the CTA style only for clickable actions. | `game/game_action_row.gd`, `game/game_sidebar.gd` |
| 41 | Turn panel | `modals/06...` | The main CTA "Go to Recovery" is correct as the primary, but it doesn't signal "this is what to do next" when the player has nothing left to do. | P3 | When no legal actions remain, the CTA runs the `sweep` sheen every 3 s and the border `breathe`s. | `game/game_action_row.gd` |
| 42 | Card Details panel | `flow/*`, `tutorial/003...`, `modals/*` | In the default state, 85% of the panel (about 470x480 px) is empty leather with one line of dim hint text. It is the largest dead area of the whole HUD. | P1 | The empty state becomes an illustrated placeholder: an engraved card-back outline (a 140x196 bronze line art at 25%) centred, with "Hover a card to read it" under it in 14 px `MUTED`, plus a slow `breathe`. When a card is shown, top-align it and size its art preview to fill the width (see #43). | `board/card_details_panel.gd`, `game/game_details.gd` |
| 43 | Card Details panel | `tutorial/069...`, `tutorial/104...` | For basic units the panel shows only name, tags and two stat boxes, then 400 px of nothing. | P2 | Add a large art crop (full width x 160 px, a soft vignette bottom) at the top of the panel for every card; it fills the space with what the player most wants to see. | `board/card_details_panel.gd` |
| 44 | Card Details panel | `tutorial/104...`, `tutorial/116...` | The card name "BOOM, COUNCILLOR OF THE ORDER" in 22 px Cinzel wraps to 2 lines with "ORDER" alone on line 2. | P2 | T2 at 20 px; auto-shrink to 16 px before wrapping; when it wraps anyway, balance the lines (split at the comma). | `board/card_details_panel.gd` |
| 45 | Card Details panel | `tutorial/069...` | The ATK/DEF stat boxes: the "ATK" label, "Base: 8" and the big number are three sizes with no alignment baseline; the box is an F3 inset with a 1 px border only. | P3 | Number baseline aligned with "ATK"; the base value moves under the number in 11 px; tint the box edge red (ATK) / blue (DEF) at 40% to echo the card badges. | `board/card_details_panel.gd` |
| 46 | Game log | `modals/*`, `flow/*` | The log well is near-pure black (#0b0a09) with no grain and only 10 px padding; it looks like a terminal. | P2 | An F3 inset with 25% leather grain, `PANEL_INK` #12100f, 14 px padding, a 12 px gap to its scrollbar. New entries slide in (`stagger` 40 ms, 8 px up and a fade) and the newest entry briefly glows gold 30% (600 ms). | `game/game_log.gd` |
| 47 | Game log | `series/series_08_first_player.png`, `flow/13_series_over.png` | **Adjacent D7.** Besides the wording, "GAME OVER: Ben wins ..." uses a magenta/violet (#e070ff-like) that appears nowhere else in the palette. | P3 | Use `GOLD_HI` bold for the winner line, plus a small crown glyph. | `game/game_log.gd` |
| 48 | Game log | `modals/*` | The log height is fixed and leaves about 60 px of empty black below a short log, while the Card Details panel below is starved. | P3 | Make the log/details split adapt: the log takes 28% of the sidebar height (min 180 px), the details panel the rest. | `game/game_sidebar.gd` |
| 49 | Sidebar | `series/series_03_custom_empty.png`, `modals/04_deck_select.png` | During deck choice the Series panel is about 80% empty (names, "Choosing a deck..." and the score), and the bottom panel repeats the modal title "CHOOSE YOUR DECK". | P2 | Series panel: show a "Best of 3" medallion with three game sockets (empty / won / lost gems) and both players' plates with a waiting animation. Remove the bottom echo panel or turn it into a status line with `WaitingDots`. | `game/game_series_overlay.gd`, `game/game_sidebar.gd` |
| 50 | Deck select | `modals/04_deck_select.png` | The deck tile grid scrolls under the frame: the third row peeks 20 px at the bottom with a hard cut and no fade. | P2 | A 32 px bottom fade mask on the scroll area; or size the tile height so two rows fit exactly with 16 px clearance. Add a scroll cue (`scroll_cue.gd`) when more exist. | `game/deck_select_view.gd`, `widgets/scroll_area.gd` |
| 51 | Deck select | same | The thumbnails' card names are 8 px; the colour-distribution strip is 4 px and reads as a stray line. | P3 | Names 9.5 px minimum or drop them (art only; the tooltip shows the name). Strip 6 px with 1 px gaps between colours and a 1 px dark frame; a tooltip lists the percentages. | `game/deck_tile.gd` |
| 52 | Deck select | same | The deck tiles have no hover state visible (no lift, glow or sound) even though the whole tile is the choice. | P2 | Tile hover: lift 3 px, border to `GOLD` 90%, a 10 px gold glow, the thumbnail strip brightens 10%, and `ui_hover`. "Choose deck" gets its hover. | `game/deck_tile.gd` |
| 53 | Deck select | same | The hint "Starter decks, ready to play" is 10 px `TEXT_DIM` floating at the tab row's right end, out of alignment with the tab baseline (4 px lower). | P3 | 13 px italic `MUTED`, baseline aligned with the tab labels. **Adjacent F3/F5** (tabs, wording). | `game/deck_select_view.gd` |
| 54 | Deck select (custom, empty) | `series/series_03_custom_empty.png` | The empty state is an OrnatePanel (with filigree corners and glow) *inside* the deck-choice OrnatePanel, in a 1125x610 black void. Nested gold frames, and a huge black field. | P2 | Rule: no nested F1. The empty state is just a centred group (icon 64 px, T2 title, body, a 44 px secondary button) directly on the pane's leather; the pane body gets leather grain instead of flat black. | `game/deck_select_view.gd` |
| 55 | Deck select (custom, empty) | same | "Show Structured decks" is a tiny (about 140x24) button. | P3 | A standard 44 px secondary button. | `game/deck_select_view.gd` |
| 56 | Draft | `series/draft_01_open.png` | Three offered cards on an empty 1100x420 area with 150 px gaps; the cards are small for the screen's only decision. | P2 | Scale the offers to fill: 260 px wide cards (from 220), 48 px gaps, centred vertically; hover lifts and tilts 2°; reveal with a `stagger` flip (120 ms each, `card_draw`). | `game/game_reward_panels.gd` / draft view (`game/game_series_overlay.gd`) |
| 57 | Draft | same | The pick progress row is 20 tiny 8 px diamonds; at that size "pick 1 of 20" is only readable from the text. | P3 | 12 px diamonds grouped in 4s by 6 px extra gaps; the current one `breathe`s; past ones are gold, future ones bronze outline. | draft view (`game/game_series_overlay.gd`), `game/pick_pips.gd` |
| 58 | Draft | same | **[D5]** The "Basic: Basic Mage (Water) ×3" blue chip and "Change" button are squeezed against the right frame (10 px) and sit 6 px higher than the tab row's centre line. | P2 | 24 px from the frame, vertically centred on the tab row; the chip uses F4 at 13 px. | draft view |
| 59 | Draft sidebar | same | "YOUR DRAFT (0)" shows one line and 500 px of empty space, plus a "Scroll for more" bar with nothing to scroll. **Adjacent D1** (the scroll cue logic). | P2 | The empty state shows 20 engraved card-slot outlines (a 4x5 grid of 40x56 placeholders) that fill as cards are drafted, which makes progress visible and fills the space. | `game/game_sidebar.gd`, draft view |
| 60 | Next game | `series/series_08_first_player.png` | "I go first" / "My opponent goes first" are two identical secondaries, and "Start next duel" below is a disabled dark slab larger than both: the visual weight is inverted, and the disabled state looks like a dead panel. | P2 | Make the two options a segmented choice (an F4 pair; the chosen one fills gold with a ✓), then "Start next duel" is the primary, disabled per §1.4.4 until a choice is made. "View your deck" becomes a 36 px secondary with a deck icon. | `game/game_series_overlay.gd` |
| 61 | Rewards | `series/rewards_01_choose.png` | The primary (gold) action is "Skip remaining rewards", so the screen's strongest call to action is to skip the rewards. | P2 | "Skip remaining rewards" becomes secondary; "View your deck" a text link. The reward tiles are the primary interaction (hover glow, lift). **Adjacent E1-E3.** | `game/game_reward_panels.gd` |
| 62 | Rewards | same | The reward tiles have no visible hover state, and the icons (a flat card with a + or - badge) are generic. The description text is 11 px dim. | P2 | Tile hover: lift 4 px, the border glows in the tile's colour, the icon floats 3 px on a 2.4 s `breathe`, `ui_hover`. Pick: the tile flashes, a gem leaves the PICKS strip and flies to it (`reward_pick`). Description 12 px `MUTED`. | `game/game_reward_panels.gd`, `widgets/choice_tile.gd` |
| 63 | Rewards | `series/rewards_01_choose.png` | The modal opens with no reveal; the moment of reward has no ceremony. | P2 | `panel_in`, then the PICKS gems pop in (`stagger` 60 ms, a chime each), then the tiles rise in a stagger (`reward_reveal`). | `game/game_reward_panels.gd` |
| 64 | Series end | `flow/13_series_over.png` | **[D3]** "DEFEAT" is a flat red bold serif (not even Cinzel) with no outline, shadow or texture; it is the emotional peak of the series and looks like plain HTML. | P1 | The T1 DEFEAT variant: Cinzel 700 at 80 px, the ember gradient, a 2 px #2a0806 outline, a two-layer shadow, a red glow 30%; it drops in from 1.25 scale with a 90 ms hit-stop and a 6 px shake, ash particles drift down (1.2 s). VICTORY: the gold T1 with a crown sigil and rising motes plus `victory_big`. | `fx/fx_game_end.gd`, `game/game_series_overlay.gd` |
| 65 | Series end | same | "Back to main menu" is a small (about 150x26) gold button, undersized for the final CTA; the score "0 – 2" uses the same weight as the names. | P2 | The hero CTA at 52 px high, 240 px wide. The score in T2 at 44 px with the loser's number at 60% opacity. | `game/game_series_overlay.gd` |
| 66 | Series end | same | The game history rows are full-width bars with a thin red border whatever the result; the turn/HP text sits 4 px from the right edge. | P3 | Row style per result (a win = gold edge, a loss = ember edge at 50%), 14 px horizontal padding, rows 36 px. | `game/game_series_overlay.gd` |
| 67 | Pause | `modals/11_pause_veil.png` | "MATCH PAUSED" waits indefinitely with static text: no spinner, no elapsed timer, no "Leave match" option on the panel. | P2 | Add an animated rune ring (`fx_rune_ring.gd`, 3 s rotation) left of the title, "Waiting 0:12" counting up, and a secondary "Leave match" button. Open with `panel_in` and `notice`. | `game/game_series_overlay.gd`, `fx/fx_rune_ring.gd` |
| 68 | Privacy screen | `modals/12_privacy.png` | A pure #0a0a0a void with a lone panel and the floating Menu button; the hot-seat handover looks like a crash screen. | P2 | Backdrop: the table art, heavily blurred (or the menu art) at 25% brightness with a vignette, and a slowly rotating large sigil (`fx_sigil.gd`, 10% alpha) behind the panel. Hide the Menu button (Esc still works). The panel title gets T2 plus a gentle `breathe` glow on the CTA. | `menu/session_launcher.gd`, `fx/fx_sigil.gd` |
| 69 | Concede confirm | `modals/08_confirm_concede.png` | The destructive "Concede" is the gold primary and "Keep playing" is secondary: the most inviting button ends the game. | P1 | "Concede" uses Danger; "Keep playing" is a secondary with default focus (Enter = keep playing). The same for every destructive confirm. | `widgets/confirm_dialog.gd`, `game/game_menu.gd` |
| 70 | Delete deck confirm | `deckbuilder/07_delete_confirm_1600x900.png` | The same: "Delete" is the gold primary. | P1 | Danger style; "Cancel" focused. | `widgets/confirm_dialog.gd`, `deck_builder.gd` |
| 71 | Confirm dialogs | `modals/08...`, `deckbuilder/07...` | The body text is centred with a single line break, and the button pair sits 12 px under the text and 16 px above the bottom frame. | P3 | 20 px text-to-buttons, 24 px to the bottom frame, buttons 44 px high and min 160 px wide. | `widgets/confirm_dialog.gd` |
| 72 | Coin flip | `cards/00d_coin_flip_1600x1000.png` | The result text "BEN GOES FIRST" is rendered *beneath* the dimmed board (it's visible faintly through the field cards at about 10%), so the moment's payload is buried. The coin is plain silver with a single "B" letter. | P1 | Draw the result banner on the FX layer above the veil, T1 at 56 px, appearing as the coin lands (`impact` plus a coin ring). Coin: gold and bronze house metal with an embossed crest on each face (a sun for seat 1, a moon for seat 2) and the initial small under it; a land sound `coin_flip`. | `fx/coin_flip.gd`, `ui_layers.gd` |
| 73 | Card catalogue | `catalogue/01_catalogue_1600x900.png` | **[D3][D5]** The page title "CARD CATALOGUE" is a flat gold Cinzel 15 px from the left edge and about 14 px from the top, with a hairline rule; the Back button is 16 px from the right edge and 15 px from the top. | P1 | Page header bar: 32 px safe margin, T2 title at 36 px, the house divider under it (12 px gap), the Back button as a 44 px secondary with "‹ Back", vertically centred on the title. The same header component for the deck builder. | `menu/card_list_screen.gd`, `deck_builder.gd` |
| 74 | Card catalogue | same | **[D5]** The grid has uneven gutters: about 44 px horizontal and 26 px vertical; the left inset is 20 px and the right gap to the scrollbar about 16 px, so the grid isn't centred. The last row is cut by the panel's bottom edge. | P2 | Equal 16 px gutters, the column count computed from the width, centred, the remainder split equally; a 24 px bottom fade mask; 12 px between the grid and the scrollbar. | `widgets/card_browser.gd`, `menu/card_list_screen.gd` |
| 75 | Card catalogue | same | Vanilla units show an empty text box with a faint "+" cross placeholder in the middle, which reads as a missing asset on 24 cards in a row. | P2 | Replace the cross with a centred, small engraved flourish (a horizontal filigree with a diamond, 40% bronze) or a one-line flavour text in italic. | `card/card_painter.gd`, `card/card_face_parts.gd` |
| 76 | Card catalogue | same | The catalogue cards have no hover state (no lift or glow) and no hover sound. | P2 | Hover: lift 4 px and scale 1.04, depth 3 shadow, a gold 8 px glow, `ui_hover`, plus a right-click hint in the tooltip. | `widgets/card_browser.gd` |
| 77 | Card catalogue | same | The Selected Card panel: below the stat boxes, about 360 px of empty leather. | P2 | Add the full rules block (always shown, even "No rules text" as an italic dim line), then the "In your decks: ×N" usage and the set/rarity line. Or vertically centre the group. | `menu/card_list_screen.gd`, `board/card_details_panel.gd` |
| 78 | Card catalogue | same | The search field and filter dropdowns are flat black boxes with 1 px borders; the dropdowns are 30 px high while "Clear filters" is 28 px. | P3 | F3 inset style for the search field (40 px high, a 16 px search glyph, 12 px left padding); dropdowns and the clear button share 36 px; 8 px between filters. | `menu/card_list_screen.gd`, `ui_style.gd` (`make_theme`) |
| 79 | Card catalogue | `catalogue/06_no_results_1600x900.png` | The no-results panel is a plain black box in the middle of a 1220x700 void; the right panel's "No card selected" box sits at the top with nothing below. | P3 | Drop the box; show an engraved magnifier icon (64 px) plus the T2 title plus the body plus the button directly on leather, with a 2.4 s `breathe` on the icon. | `menu/card_list_screen.gd` |
| 80 | Deck builder | `deckbuilder/01_empty_1600x900.png` | The Preview column has about 280 px of empty space under the stats. **Adjacent F2** (the hover preview and the button removal); after F2 this space grows further. | P2 | Same as #77: the rules block, then a "Copies in deck" gem row (0-3 sockets) that fills on add. | `deck_builder.gd` |
| 81 | Deck builder | same | The stat chips "0 cards / 0 Main / 0 Extra / 0 unique" put a tiny number (about 9 px) in front of the label; it should be the number that stands out. | P2 | Number 15 px Cinzel 700 `GOLD_HI`, label 11 px `MUTED` under or after it; the chips are F4 at 28 px high; the numbers tween on change (`count`). | `deck_builder.gd` |
| 82 | Deck builder | `deckbuilder/03b_deck_grid_1600x900.png` | The "×1" count pills under each card are gold primaries in miniature (the same look as the Save button), so a passive count reads as a button. | P3 | A count badge: a dark F4 chip with a gold number, overlapping the card's bottom-right corner by 6 px (not a separate row under it). | `deck_builder.gd` |
| 83 | Deck builder | `deckbuilder/07...` | The toast "Renamed ..." is a flat black box overlapping the panel bottom frame by about 4 px. | P3 | An F5 toast 24 px above the frame, slide-up 200 ms plus fade, auto-hide 2.5 s, `notice` at -6 dB. | `deck_builder.gd` |
| 84 | Deck builder | `deckbuilder/01...` | **[D5]** "Save" and "New" are 30 px high and sit 10 px under the name field; the tab row is 10 px below them, and the empty-state box 8 px below that. The right column feels stacked with no grouping. | P2 | Group spacing: field → buttons 12 px, buttons → tabs 24 px, tabs → list 0 (the joined-tab rule of F3, adjacent), list → stats 24 px. Buttons 36 px. | `deck_builder.gd` |
| 85 | Deck builder | `deckbuilder/03b...` | Adding a card has a fly-in, but the deck count chips and the target section don't react. | P3 | The landing slot flashes gold (200 ms), the count chip pops (1.15 scale), `deck_add`. Remove: a shrink plus fade, `deck_remove`. | `deck_builder.gd` |
| 86 | Inspector | `inspect/01_inspect_field_unit_protecting.png` | The right column ends about halfway; below the statuses there is about 330 px of empty leather. The Close button floats at the top right with no relation to the title. | P3 | Close becomes an × icon button (32 px) in the header strip; the content column vertically centres when short, or adds the card's flavour/art credit line. | `inspect/card_inspector.gd` |
| 87 | Inspector | same | The open animation (if any) isn't visible; the big card doesn't feel lifted from the board. | P2 | Open: the card flies from its source rect to the panel (`card_move` 300 ms) while the panel fades in; close in reverse; `panel_open`/`panel_close`. | `inspect/card_inspector.gd`, `game/game_inspect.gd` |
| 88 | Inspector | same | The "Attack stance" / "Protecting" chips are blue, the same blue as the Water type chip, so the meaning blurs. **Adjacent D14** (hiding the stat section for spells). | P3 | State chips use a neutral steel-silver F4 (#b4b6bc), types keep their element colour. | `inspect/card_inspector.gd`, `ui_style.gd` |
| 89 | Pile browser | `inspect/04_spent_browser.png` | "Close" here is the gold primary, while every other Close in the app is a secondary; the hint "Right-click a card to read it." sits 18 px right of the title in 12 px. | P3 | Close = secondary (or the header × of #86) everywhere. The hint goes under the title in 13 px `MUTED`. | `inspect/pile_browser.gd` |
| 90 | Pile browser | same | The pile opens instantly with all cards present. | P3 | Cards deal in (`stagger` 30 ms, fly from the pile's board position), `card_draw` soft. | `inspect/pile_browser.gd` |
| 91 | Sidebar pile list | `inspect/09_sidebar_pile_list.png` | Each row repeats the full ATK/DEF boxes and tag set; four Basic Mages make a wall of identical boxes; the rows run 8 px from the scrollbar. | P3 | Compact row: a thumbnail, the name, the element chip and "8 / 8" inline; expand on hover. 12 px to the scrollbar. **Adjacent D15.** | `game/game_sidebar.gd` |
| 92 | Extra deck list | `series/f04_02_method_picker.png` | The "Summon Attack" / "Summon Defense" buttons sit flush with the card row's bottom edge (4 px) and the rules text runs to the scrollbar (6 px). **Adjacent B3** (the stance choice changes). | P2 | 12 px row padding, 12 px to the scrollbar, buttons 32 px with 8 px gaps. | `game/game_sidebar.gd` |
| 93 | Fusion method picker | `series/f04_02_method_picker.png` | Good structure, but the two option cards are small (120 px) for a modal of 460 px, and the "Cast" / "Fusion (1 AP)" buttons don't say which card they go with except by position. | P3 | Cards 150 px; each card and its button form one hoverable tile (a joined frame) so hovering highlights both. | `game/game_ui.gd` (picker), `widgets/choice_tile.gd` |
| 94 | Statistics | `stats/02_record_1600x900.png` | The rows are fine, but the values run to 12 px from the scrollbar and the row striping touches the scrollbar track. The footer "Kept on this computer only." is 10 px. **Adjacent C1** (the footer wording will change). | P3 | 16 px value-to-scrollbar gap, striping inset 6 px from the track, footer 12 px `MUTED`. | `widgets/stats_dialog.gd` |
| 95 | Statistics | same | The numbers appear static; it's a "trophy" screen without ceremony. | P3 | Values count up (`count`, `stagger` 40 ms per row) on open; headline stats (win rate, best streak) get a small gold gem icon. | `widgets/stats_dialog.gd` |
| 96 | Statistics | `stats/01_empty_1600x900.png` | The empty state is a single sentence. | P3 | An engraved trophy icon (64 px) above the sentence; T2 title. | `widgets/stats_dialog.gd` |
| 97 | Tutorial menu | `tutorial/002_menu_tutorial_panel.png` | The lesson list is 7 identical iron bars (13 px text, a 9 px left padding, 12 px gaps) and the first one is gold, so it looks "selected", not "recommended"; there is no completed/locked state. The footer note is 10 px dim. | P2 | Lesson rows 52 px: a number medallion (28 px bronze coin), the title in 15 px Bold plus a subtitle line in 12 px `MUTED`, a right-side state (✓ gold when done, a "Next" chip on the recommended lesson). Hover per §1.4.4. Footer 12 px. | `tutorial/tutorial_menu.gd` |
| 98 | Tutorial sidebar | `tutorial/011_L1_s05_do.png`, `tutorial/022...` | The header "TUTORIAL · LESSON 1 · A TURN OF..." is cut with an ellipsis next to the step chip; the panel title repeats the lesson. | P2 | Two lines: "LESSON 1 OF 7" (11 px T3) above "A Turn of Play" (T2 at 18 px); the step chip on the right. No ellipsis. | `tutorial/tutorial_overlay.gd` |
| 99 | Tutorial sidebar | `tutorial/011...` | The "Restart lesson" / "Exit tutorial" buttons are small (about 92x30) and sit 16 px from the panel bottom; when the step has no Next button, the row looks unbalanced. | P3 | Text-link style for both (they are secondary escape hatches), right-aligned; the Next button (when present) is the primary at 40 px. | `tutorial/tutorial_overlay.gd` |
| 100 | Tutorial off-script hint | `tutorial/022_L2_offscript_hint.png` | The same message is shown twice: a red-bordered box in Cinzel caps inside the panel ("TUTORIAL: FOLLOW THE HIGHLIGHTED STEP.", wrapping) *and* a red floating tooltip over the hand. Red caps shout at a learner. | P2 | Keep one message: the floating hint near the pointer, styled F5 with an amber (not red) edge, sentence case, 14 px, auto-fade 2.2 s, and the highlighted element pulses once. `deny` stays. | `tutorial/tutorial_overlay.gd`, `tutorial/tutorial_highlight.gd` |
| 101 | Tutorial pointer | `tutorial/011_L1_s05_do.png` | The yellow arrow covers the "Battle" pill's label ("Ba|tle"). The arrows are flat solid shapes. | P2 | Offset arrows so they never overlap text (point at the element's edge with a 6 px gap); give them a 1 px dark outline, a soft glow, and a 1.2 s bob (6 px). | `tutorial/tutorial_highlight.gd`, `tutorial/tutorial_deco.gd` |
| 102 | Tutorial lesson complete | `tutorial/015_L1_complete.png` | **[D3]** "LESSON COMPLETE" is flat; the moment has no celebration. "WHAT YOU LEARNED" is 10 px `TEXT_DIM`. | P2 | T1 at 48 px; a gold burst behind the title (`fx_burst.gd`) plus `step_done`/`victory`; the progress segment for this lesson fills with light (500 ms). The "WHAT YOU LEARNED" header in T3 at 13 px. The bullets appear in a `stagger`. | `tutorial/tutorial_overlay.gd`, `fx/fx_burst.gd` |
| 103 | Tutorial complete | `tutorial/116_L7_complete.png` | The final completion is identical to a lesson completion: the same modal and weight. | P3 | Use the series VICTORY treatment (T1, crown sigil, motes, `victory_big`). | `tutorial/tutorial_overlay.gd`, `fx/fx_game_end.gd` |
| 104 | Global: tooltips | `cards/02_status_tip_poison_1600x1000.png` (status tips) | **Adjacent D12.** The tooltips are flat dark boxes; there is no pointer and no open animation. | P3 | F5 tooltip style with a pointer notch, `panel_in` at 140 ms, a 300 ms hover delay. | `widgets/status_tip.gd`, `widgets/status_help.gd` |
| 105 | Global: scroll areas | `modals/04...`, `catalogue/01...`, `cards/00b...` | Every scroll area cuts content with a hard edge; the scrollbars are 4 px gold sticks with no track. | P2 | `ScrollArea` gets top/bottom 24 px fade masks (shown only when there's more content in that direction) and an 8 px track (F3) with a gold 6 px thumb that brightens on hover. | `widgets/scroll_area.gd`, `widgets/smooth_scroll.gd`, `ui_style.gd` |
| 106 | Global: modals | all modal shots | Modals appear without an open/close sound; most snap in. | P2 | `panel_in`/`panel_out` plus `panel_open`/`panel_close` in OrnatePanel itself so every modal inherits it. | `widgets/ornate_panel.gd`, `audio/sfx.gd` |
| 107 | Global: buttons | all | No hover sound anywhere; the secondary (iron) buttons' hover state is subtle (a slightly lighter fill). | P2 | §1.4.4 hover for secondaries (a gold border, text `GOLD_HI`, inner glow) and the `ui_hover` cue wired through the existing `Sfx` button hook (rate-limited). | `juicy_button.gd`, `ui_style.gd`, `audio/sfx.gd` |
| 108 | Global: panel headers | all | **[D3]** Every HousePanel header (GAME LOG, CARD DETAILS, SERIES ...) is flat gold with a hairline rule. | P2 | T3 treatment with an engraved double underline. | `widgets/house_panel.gd` |
| 109 | Global: house frames | all board shots | The sidebar panels (log, details, turn) are thin 1 px bronze frames with 8 px radii, so they look lighter than the modals; the gap between them is 8 px. | P2 | F2 frames (a 2 px gilded bevel, rivets) and 12 px gaps between the stacked panels; 16 px inner padding. | `widgets/house_panel.gd`, `game/game_sidebar.gd` |
| 110 | Global: depth | all | Elements share no consistent shadow; plates and buttons float differently. | P2 | Apply the §1.3 depth table through `UIStyle.lift_style(depth)`. | `ui_style.gd` |

That's 110 findings. Severity count: P1 = 13 (#1, 3, 12, 17, 19, 22, 33, 42, 64, 69, 70, 72, 73),
P2 = 63, P3 = 34.

Not reviewed (screenshot not in the set or not legible at the review size): the lobby list
(`modals/03_lobby_list.png`) and the board shots from `flow/00-08` beyond what the `modals`, `inspect`
and `series` shots show of the same screens. The lobby list should get the same rules: F2 rows, a
hover state, the §1.4.2 spacing, and the T2 title. Check it in the WP-8 sweep.

---

## 3. Prioritised implementation plan

One UI programmer, in order. Each package ends with before/after screenshots in
`production/qa/evidence/2026-10-20-release-batch/h1-<wp>/`, read back and judged. Shaders and
particles go to the technical-artist; new sound cues go to the audio-director, via
`tools/gen_sfx.py`. Everything respects `UIStyle.reduce_motion` and `UIStyle.dur()`.

| WP | Name | Findings | Content | Depends on | Size |
|---|---|---|---|---|---|
| **WP-1** | Style foundation | 29, 105, 107, 110, the §1.4 tokens | Add to `ui_style.gd`: `SPACE` tokens plus `pad()`, the depth shadows in `lift_style(depth)`, the button families (`secondary_button`, `danger_button`, hover/focus/disabled per §1.4.4), the motion tokens (`MOTION` dict plus `tween_in/out` helpers), `SELECT` → gold, F3 inset and F4 chip factories, `ScrollArea` fade masks and track. Wire `ui_hover`, `panel_open/close`, `tab`, `toggle_*` names in `Sfx` (with silent fallbacks until the audio lands). No screen changes yet except what the factories restyle automatically. | none | L |
| **WP-2** | Title depth (D3) | 1, 64, 72, 73, 102, 108, and the D3 inventory | `TitleText` control (gradient, outline, two-layer shadow, glow, sweep) plus `UIStyle.title_label(text, size, tier)`. Apply T1/T2/T3 everywhere in the inventory. The coin-flip result text moves above the veil (#72). | WP-1 | M |
| **WP-3** | HP vial and player plates (D4) | 17, 18, 19, 20, 21 | The Vial of Life (shader plus layered draw, the damage trail, the heal shimmer, the low-HP pulse, the shatter hook), the topaz AP gems, the F2 plate with the active-player breathe and the gem turn marker. Keep `HpBar.set_hp` and the `ApGems` policy APIs and their tests. | WP-1, technical-artist shader | L |
| **WP-4** | Safety and button hierarchy | 14, 34, 35, 40, 60, 61, 65, 69, 70, 71, 89 | Danger style on every destructive confirm (with Cancel focused), primary/secondary corrections, status messages out of the CTA slot, segmented choice on Next Game. | WP-1 | S |
| **WP-5** | Margins sweep (D5) | 4, 8, 9, 10, 11, 12, 13, 15, 16, 30, 53, 58, 74, 84, 92, 94, and every [D5] row | Apply the spacing tokens screen by screen: the shared settings form (one builder for both settings screens), the page header component for the catalogue and the deck builder, the grid gutters, the scrollbar gaps, the hand crop. Add the dev-only `--debug-margins` overlay and re-shoot every screen. | WP-1, WP-2 | L |
| **WP-6** | Board surfaces | 22, 24, 25, 26, 27, 28, 31, 38, 39, 41, 46, 47, 48, 109 | Inlaid zones, pile medallions, the target glow, the phase track, the log inset and adaptive split, F2 sidebar frames, the waiting plate. **Coordinate with D9** (the target preview) and **D2** (the hand). | WP-1, WP-2 | L |
| **WP-7** | Dead space fills | 42, 43, 44, 45, 49, 54, 55, 56, 57, 59, 75, 77, 79, 80, 81, 86, 96 | The illustrated empty states, the art crop in Card Details, the always-shown rules block in the catalogue/deck-builder previews, the draft slots, the series medallion, the vanilla-card flourish. **Coordinate with F2** (the deck builder middle pane) and **D1**. | WP-1 | M |
| **WP-8** | Modals and menus | 2, 3, 5, 6, 7, 67, 68, 97, 98, 99, 100, 101, 103, 106, plus the lobby-list check | Menu item hover, the ambient motes, contextual header tags, the pause panel, the privacy backdrop, the tutorial menu rows and the sidebar header, a single off-script hint, the arrow offset and bob. OrnatePanel open/close motion and sound. | WP-1, WP-2 | M |
| **WP-9** | Motion and sound pass | 23, 32, 52, 62, 63, 76, 85, 87, 90, 95, 104 | Hover lifts and sounds for cards and tiles, reveal staggers (rewards, draft, pile browser), the inspector fly-in, stat count-ups, toasts, the table motes. **Coordinate with D6/D8** (resource sounds, summon FX) so cues don't double up. | WP-1 to WP-8 | M |
| **WP-10** | Polish tail | 36, 37, 51, 66, 78, 82, 83, 88, 91, 93 | The remaining P3 items. | WP-1 | S |

Release cut line: WP-1 to WP-6 are required (they contain all 13 P1s). WP-7 to WP-9 are strongly
recommended (most of the "breathe" brief lives there). WP-10 is optional.

Verification for each WP: (1) the full test suite stays green; (2) before/after screenshots at
1600x900 for every touched screen, read back at full size; (3) a reduce-motion pass screenshot for
any animated element (it must show a clean static state); (4) the margin overlay shows no content
inside the 12 px floor.
