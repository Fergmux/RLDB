# RLDB Art Bible (first pass)

Status: Draft v1, 2026-10-15. Covers I-03. Layout lives in `design/ux/match-board.md`. Hex values are starting tokens; tune in `ui_style.gd`, not per widget. All art is original; no franchise frames, logos or assets.

## 1. Direction

A candle-lit war table: dark, weathered wood and slate, with cards as the brightest, most tactile objects on it. Hearthstone supplies the readable, chunky, juicy card feedback (bevelled frames, big stat shields, springy motion); The Witcher supplies the mood (muted earth tones, worn bronze, parchment, restrained magical glow). Rule: **atmosphere lives in the background, clarity lives on the cards.** Dark never means low contrast; effects explain a state change and never hide stats.

Pillars for review: (1) Stats readable at a glance at 1280x800. (2) Colour carries meaning only; decoration stays desaturated. (3) One accent (gold) for "act here"; one cool (cyan) for "yours/selected".

## 2. Palette (tokens)

| Group | Token | Hex | Use |
|---|---|---|---|
| Table | `table_deep` | `#0e0d0c` | outer vignette, screen edges |
| | `table_wood` | `#2a211a` | main table base (gradient to `#1b1612`) |
| | `table_inlay` | `#3a2e22` | centre line, grain highlights |
| Panels | `panel_slate` | `#1f1c1a` | sidebar, plates (gradient to `#171513`) |
| | `panel_raised` | `#2a2623` | buttons, chips, hover plates |
| | `panel_ink` | `#12100f` | text wells, log background (85% alpha) |
| Trim | `bronze` | `#7a5a30` | default borders |
| | `gold` | `#d4a64a` | active borders, primary buttons |
| | `gold_hi` | `#f0cf7a` | bevel highlight, hover |
| Text | `text_primary` | `#ece4d2` | parchment white; AAA on panels |
| | `text_secondary` | `#a79c88` | labels, type line |
| | `text_disabled` | `#6f6757` | disabled (never used for stats) |
| | `text_on_gold` | `#1a1208` | text on gold/amber fills |
| Type | Water | `#3f86d6` | |
| | Fire | `#d4533a` | |
| | Earth | `#8f7340` | |
| | Lightning | `#e0bd32` | |
| | Heavenly | `#f0e4b0` | |
| | Necrotic | `#7e4fb5` | |
| | Physical | `#98979a` | |
| | none | `#5b5a58` | |
| Category frame | basic | `#6d6a66` | iron |
| | unit | `#9a8f7c` | bone steel |
| | spell | `#2f9a6a` | verdigris |
| | trap | `#a8386f` | wine |
| | power | `#c9a23a` | gold |
| | fusion | `#7f5fd0` | violet |
| | ritual | `#3f7fd0` | sapphire |
| | arcane | `#1fb0a0` | teal |
| Cost badge | AP | `#f2b544` | amber round gem |
| | Rune | `#4a8fe0` | blue diamond |
| | Arcane | `#1fb0a0` | teal hexagon |
| | Fusion | `#9d7ae8` | violet double-ring |
| Status | buff | `#6fd38a` | stat above base, positive chips |
| | debuff | `#e8605a` | stat below base, negative chips |
| | rune | `#5aa2ff` | Rune counters |
| Highlight | `hl_target` | `#ffd84a` | legal target ring (pulsing) |
| | `hl_select` | `#63b3ff` | selected card/source |
| | `hl_hover` | `#f0cf7a` | hover glow (softer than target) |
| | `hl_danger` | `#e8605a` | lethal / illegal flash |

Colour-blind rule: cost badges differ by **shape** as well as hue; category frames also carry an icon glyph on the name plate; stat change uses arrows (up/down) alongside green/red. Type colour is always paired with the type word on the type line.

Zone role tints (board only, subdued ~35% of reference): unit `#3b2a1a`, trap `#3a1c1c`, power `#1c2a3d`; see section 5.

## 3. Typography

| Role | Font | Notes |
|---|---|---|
| Card name, titles, banners, HP/AP, stats, costs, damage numbers | `Cinzel-Variable.ttf` (weight 600-700 via `FontVariation` variation_opentype `wght`) | all-caps not needed; Cinzel is caps-style already, keep names <= 18 chars or shrink |
| Rules text, log, prompts, type line, chips, buttons | `AlegreyaSans-Regular/Bold` | Italic for flavour and type line |

Build once: a `Theme` with `default_font` = Alegreya Regular, plus `UIStyle.font_display()` returning a cached Cinzel `FontVariation`. Outline 2px `#000` at 60% on stats/numbers for legibility over art.

| Element | Hand 128x180 | Board 128x128 | Big (inspect) 240x336 |
|---|---|---|---|
| Name (Cinzel 600) | 13 | 12 | 20 |
| ATK/DEF (Cinzel 700) | 20 | 18 | 32 |
| Cost (Cinzel 700) | 16 | 14 | 24 |
| Type line (Alegreya Italic) | 10 | 9 | 13 |
| Rules text (Alegreya Regular) | 11 (clamp, ellipsis) | hidden | 15, full text scrolls |
| Status chip (Alegreya Bold) | 9 | 9 | 12 |

Sizes are at 1600x1000 base; stretch scales them. Floor at 1280x800 (x0.8): stats >= 14, names >= 9.6. Use `autowrap` + `shrink to fit` loop (step 1px down to 9) for long names.

## 4. Card frame anatomy

All layers are Controls/`StyleBoxFlat`/`draw_*` in `card_widget.gd`; no textures required. Layer order bottom to top:

1. **Drop shadow**: `StyleBoxFlat.shadow_size` 8, offset (0,4), `#000` 50%. Grows to 16 on hover.
2. **Outer frame**: `StyleBoxFlat`, radius 8 (hand/big) or 6 (board), border 3px in category colour, `border_blend` true; fill = vertical gradient `panel_slate` to darker (GradientTexture2D, or `bg_color` + `draw_style`). Inner 1px bevel line `gold_hi` 40% on top edge only (a 1px Line2D/`draw_line`).
3. **Art window**: inset 6px, top 52% of card (board: top 55%). Clip rect; shows art `Texture2D` when `res://art/cards/<file>` exists, else procedural placeholder = type-colour radial gradient (centre 60% lightness, edge 20%) + category glyph at 25% alpha. Thin 2px `bronze` inner border, and an inner shadow strip (top 6px black 35% gradient).
4. **Name plate**: overlaps the art bottom edge; height 22 (hand), 18 (board). Banner shape (`StyleBoxFlat` radius 4, fill `#1a1613` 92%, 1px gold border, category-colour 3px underline). Name left-aligned with 28px reserve for the cost gem.
5. **Cost gem**: top-left, centre on the card corner (offset -6,-6), diameter 28 (hand) / 24 (board) / 40 (big). Shape per cost kind (AP circle, Rune diamond, Arcane hexagon, Fusion double ring) via `draw_circle` / `draw_colored_polygon`; vertical gradient fill, 2px dark border, number in `text_on_gold` (or white on blue/teal/violet). Multi-cost cards stack small gems down the left edge.
6. **Type / Race line**: below name plate, `Race · Type` in `text_secondary`; small Type-colour square (8px) before the type word. Hidden on board size except in inspection.
7. **Rules text box** (hand/big only): parchment well `#d8ccb0` at 8% over slate, text `text_primary`, 4px padding.
8. **ATK / DEF shields**: bottom corners, overlapping the frame by 4px. ATK bottom-left (sword glyph, fill `#8a2f26` to `#5a1c17`), DEF bottom-right (shield glyph, fill `#2f5f8f` to `#1b3a5a`). Shield = `draw_colored_polygon` 6-point heater shape, 2px gold border, number Cinzel 700 white with outline. Number tint: `buff` if above printed, `debuff` if below, white otherwise, plus a 6px up/down arrow. Size 34x38 (hand), 30x34 (board), 52x58 (big).
9. **Status chips**: single row above the shields, between them, left to right; max 3 visible then "+N". Rounded pill height 14 (board 13), fill category-neutral dark with 1px coloured border (debuff red / buff green / rune blue), text = existing `STATUS_SHORT` abbreviations + stack count (full names in inspect). **Chips and shields are the reserved zone: nothing (hover buttons, glows, VFX) may cover the bottom 38px of a card.**
10. **Stance indicator**: ATK = small crossed-swords tab on the right edge of the name plate (red-gold); DEF = shield tab (blue-silver). Defence-position cards are also drawn with the art window desaturated 15% and a blue-tinted inner border. Do not rotate the card 90 degrees (zones are fixed square).
11. **State overlays** (topmost): selection ring (`hl_select`, 3px outer glow), target ring (`hl_target`), exhausted/already-acted cards dim by modulate 0.8 and gain a small "zzz"-free grey corner dot; hidden-info "?" marks only on the card back.
12. **Foil sheen** (optional shader, rare/fusion/ritual/arcane only): diagonal soft-light band across art window, `time * 0.25` sweep, intensity 0.12; paused when reduced-motion.

**Face-down back**: deep `#1d1630` field, 3px gold border, central 8-point star-and-ring emblem drawn procedurally (two rotated squares + circle, `gold` 70%), faint rune ticks around the rim, subtle noise. Same silhouette and corner radius as the front at every size. Opponent's hand uses the back at "mini" scale.

**Parchment/grain shader** (`card_grain.gdshader`, canvas_item): value-noise multiplied at 6% over frame fill; one shared material, no per-card textures.

## 5. Board / table look

- **Table**: full-screen `ColorRect` with a shader: `table_wood` base, stretched fbm noise as wood grain (horizontal, 8% contrast), radial vignette to `table_deep` (corners 55% dark), a warm light pool centred slightly above middle (`#4a3b28`, 18%). No visible grid.
- **Centre line**: 2px `table_inlay` with a small gold diamond ornament at midpoint; the front rows face across it.
- **Zone plates**: rounded rect radius 8, fill = role tint at 55% alpha with inner shadow, 1px border `bronze` at 50%, faint role glyph (sword / eye-trap / star) at 8% alpha centred. Empty zone = plate only; occupied = plate fully covered by card. Role tints: unit `#3b2a1a`, trap `#3a1c1c`, power `#1c2a3d`. Slot labels (e.g. "Front 2") shown at 40% alpha only for the first turn and for legal-target highlighting; otherwise omitted.
- **Opponent side** is not mirrored art-wise: same plate styling; only layout position differs. Active player gets a `gold` 2px underglow along their half's edge.
- **Panels** (sidebar, info plates): `panel_slate` gradient, 2px `bronze` border, 1px `gold` inner at 30%, corner radius 10, small corner rivets (4px `gold` circles). Headers in Cinzel with a thin gold rule below.
- **Buttons**: normal `panel_raised` + bronze border; hover gold border + `gold_hi` text tint; pressed 1px down shift; primary = `gold` fill with `text_on_gold`; disabled = flat `panel_slate`, `text_disabled`, no border glow (and not shown on hover cards at all, see UX spec).
- **Ambient**: 8-12 slow dust motes (GPUParticles2D/CPUParticles2D, 2px, 6% alpha), skipped when reduced-motion. Optional low-frequency candle flicker on the light pool (+/-4% brightness, 3s).

## 6. Motion language

Easing: `TRANS_BACK`/`EASE_OUT` for arrivals and lifts (springy), `TRANS_QUART`/`EASE_OUT` for settles, `TRANS_SINE`/`EASE_IN_OUT` for pulses. Animation reads state events; it never gates rule resolution or response timing (queue + skip: any click or `ui_accept` completes the current effect instantly).

| Event | Duration | Motion |
|---|---|---|
| Hover lift (hand) | 120ms in / 90ms out | y -48, scale 1.0 to 1.25, z-top, shadow grows; neighbours spread 10px |
| Hover lift (field) | 100ms | scale 1.0 to 1.08, glow ring `hl_hover`; buttons fade in over 100ms after 60ms delay |
| Select | 90ms | scale 1.05, ring to `hl_select`, pop 1.0 -> 1.06 -> 1.05 |
| Legal-target pulse | 900ms loop | ring alpha 0.55 <-> 1.0, SINE |
| Draw | 280ms each, 70ms stagger | from deck pile to hand, arc, slight rotation settle |
| Play / summon | 320ms | hand to zone: move 220ms QUART, then land squash (1.0 -> 0.94 -> 1.0, 100ms), dust ring (6 particles), plate flash gold 150ms |
| Set trap/spell | 260ms | slides to zone face-down, small "thunk" flash |
| Attack lunge | 360ms | wind-up back 8px (80ms), lunge 60% of the way toward target (110ms, QUINT in), impact hold 40ms, return 130ms; z above all |
| Damage number | 700ms | spawn at hit point, Cinzel 28 red with outline, rises 36px, scale 1.3 -> 1.0 in 90ms, fades last 250ms; heal in `buff` green with "+"; target card shakes 6px x 3 over 150ms and flashes white 60ms |
| Stat change | 300ms | number rolls (old fades up, new in from below), colour flashes then settles to buff/debuff tint |
| Destruction | 450ms | desaturate + dissolve shader (`dissolve` 0 -> 1 with burnt `#ff8a3a` edge), 8 ember particles; ends in grave pile fly-out 200ms |
| Status applied | 250ms | chip scales 0 -> 1.15 -> 1.0; owner card pulses its status colour once (400ms) |
| Status tick (burn/poison) | 400ms | chip pulse + damage number |
| Phase banner | 900ms total | centre band slides in 180ms, holds 540ms, slides out 180ms; Cinzel 44 on dark band 60% alpha with gold rules; "YOUR TURN" gets a gold flare |
| Turn change | 500ms | active-underglow cross-fades between halves; HP/AP plates pulse |
| Response prompt | 150ms in | rest of board dims to 0.55, prompt panel gets gold border pulse (1.2s loop) |
| Panel/prompt open/close | 140ms / 100ms | fade + 8px slide |

**Reduced motion** (setting `reduce_motion`, default follows OS hint if available): all travel animations become 80ms cross-fades or instant; no shake, no screen/banner slide (banner fades 150ms, 600ms hold); no particles, dust, dissolve (use 200ms fade), foil sheen, or looping pulses (target ring = static solid `hl_target`); hover lift scale capped at 1.05; damage numbers appear in place, 500ms, no rise. Also provide "fast animations" (x0.5 all durations).

## 7. Asset request list (all optional; procedural versions ship)

| # | Asset | Purpose | Size / aspect | Alpha | Style | Maps to |
|---|---|---|---|---|---|---|
| 1 | Card back | richer face-down card | 512x716 (5:7) | opaque, rounded corners cut in-engine | deep purple/black, gold sigil, worn leather texture | opponent hand, face-down traps, deck pile |
| 2 | Table texture | replace shader wood | 2048x1280 seamless-ish | opaque | dark aged wood/slate, low contrast, no strong features | background |
| 3 | Frame 9-slice set (unit, spell, trap, power) | tactile frames over StyleBoxFlat | 256x358 each, 9-slice margins ~24px | yes | bevelled bronze/iron, scratches, category tint left neutral (tinted in code) | card frames |
| 4 | Zone plate glyphs (sword, eye, star) | role hints on empty zones | 128x128 | yes, white on transparent | engraved line icons | empty zones |
| 5 | Gem/shield badge sprites | polished cost gems and ATK/DEF shields | 96x96 each | yes | glossy faceted gem, hammered shield | card stats/costs |
| 6 | Soft particle + ember sprites | VFX (dust, embers, sparkle) | 64x64 | yes, white soft | round, additive-friendly | VFX |
| 7 | Panel 9-slice + rivets | sidebar and plates | 128x128, margins 20 | yes | worn bronze trim on dark slate | UI panels |

Card art itself: user-supplied, dropped at `rldb/art/cards/<source image filename>` (e.g. `170.png`); art window ratio is ~ 1.9:1 hand/board crop (centre-cropped via `Control.clip_contents` + `TextureRect.STRETCH_KEEP_ASPECT_COVERED`), full frame preview 5:7 on inspection.

## 8. Naming (per project convention)

`ui_panel_sidebar_9slice.png`, `ui_btn_primary_hover.png`, `env_table_wood_large.png`, `env_zone_glyph_unit.png`, `char_card_back_default_large.png`, `vfx_ember_loop_small.png`, `ui_frame_unit_large.png`.
