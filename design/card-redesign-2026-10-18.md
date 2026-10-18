# Card art, card redesign and material surfaces (2026-10-18)

Owner request (2026-10-18): move the accepted card art into the repo and put it on the cards in place
of the placeholder; make the art square and larger on the card; draw statuses as icons over the art,
naming each one the moment it is hovered; review the card layout and design (clean, art prominent,
sensible placement, a version per context that stays consistent); and add some wood / metal / leather /
gem texture to the flat UI without overdoing it.

## 1. Card art

- 188 accepted images (`C:\Users\fergm\Documents\rldb\tools\card-art-review\accepted-art`, 1024x1024
  PNG, 323 MB) were imported by `tools/godot/import_card_art.gd` to `rldb/assets/art/cards/<id>.webp`:
  Lanczos to 768 px, lossy WebP q0.9, 30 MB in all. 768 px is sharp on the 4K inspector card. The
  originals are left where they were (copied, not moved; they are the masters).
- Art is found **by card id only** (`CardArt.path_for(id)`), the number at the start of each file
  name. Renaming a card never breaks its art. The CSV's old `image` column is no longer used for it.
- Import settings: VRAM compressed (S3TC/BPTC) with mipmaps. That is about 393 KB of GPU memory a card,
  74 MB with every card loaded (the catalogue). Lossless import would be about 590 MB. Mipmaps keep the
  art smooth at field size. Cards draw with linear-mipmap filtering.
- New art later: drop `<id> - <name>.png` files in a folder and run
  `godot --headless --path rldb -s ../tools/godot/import_card_art.gd -- "<folder>"`, then
  `godot --headless --path rldb --import`, then copy the import settings from any existing
  `assets/art/cards/*.webp.import` file (`compress/mode=2`, `mipmaps/generate=true`). The tool rejects
  ids not in the database, duplicate ids and non-square images, and lists cards without art. Cards
  without art keep the old placeholder.
- Tests: every database card has art, every art file belongs to a card, a missing image falls back to
  the placeholder (`tests/unit/ui/card_redesign_test.gd`).

## 2. Design review of the card (before → after)

Findings on the old layout (screenshots in `production/qa/evidence/2026-10-18-carddb/`):

1. The art window was a wide letterbox (field 77x60, hand 108x58, under half the card) of
   placeholders, so the card read as frame and text, not as a picture.
2. Status chips were full-name text pills. At field size they shrank to 7-8 px text, crowded the
   space above the stat badges, and the reserved zone pushed text and stats apart.
3. Tall cards spent a strip on chips and another on the stat badges, which left the rules well
   44 px for long effects.
4. Hand, mini and big drew from two separate geometry tables that had drifted (badge sizes, fonts).

Redesign (all in `src/ui/card/`, geometry in `CardLayouts.FIELD` / `CardLayouts.TALL`):

| Element | Field (85x128) | Tall: hand 120x180, mini, big 224x336 (inspector, previews, rewards) |
|---|---|---|
| Art | square 79x79, top | square 112x112, top |
| Cost gem / Type pip | top-left / top-right on the art | same |
| Statuses, Runes | icon rows over the art's lower edge, 2 rows, then "+N" | icon rows centred between the stat badges (3 rows; full width on Spells / Traps / Powers) |
| Name | banner over the art's lower edge; two lines for long names | same |
| ATK / DEF | large badges in the bottom strip | on the art's lower corners, above the banner |
| Rules | not on field units (sidebar, inspector); short text on field Powers / Traps | race · Type line, then a full-width rules well that fits the whole text; an empty well shows a faint kind emblem |

Rationale:
- **Square art, as wide as the card allows, on every card** makes the art the first thing read and
  keeps one crop of each image everywhere (the art is square, so nothing is cropped).
- **Field vs tall.** On the field the job is *who is this and how strong*: art, name, big numbers.
  Rules live in the sidebar and inspector, so the strip under the banner goes to the stats. In the
  hand and catalogue the job is *what does this do*: the stats move onto the art's lower corners
  (Hearthstone-style) so the rules well gets the full width and about 45 px more room.
- **One tall layout** drawn at three scales (mini 0.75, hand 1, big 1.87) means the hand,
  catalogue, deck builder, rewards, prompt and inspector cards are the same card at different sizes.
- **Unchanged on purpose:** 2:3 proportions; the kind-coloured frame; the cost gem shapes (AP
  circle, Fusion ring, Ritual diamond, Arcane hexagon); the ATK diamond and DEF shield; the
  Defense / backrow rotation (badges, gem, pip and icons stay upright); the card back; hover lift
  without reflow (F05-03).

## 3. Statuses as icons

- `CardStatusIcons` draws each status / Rune as a white glyph on a dark token. The token shape and
  rim colour say what it is, so it never relies on colour alone: buff round with a green rim, debuff
  rounded-square with a red rim, Rune hexagon with a blue rim. Stacks above 1 (and every Rune count)
  get a number badge.
- Glyphs: game-icons.net (CC BY 3.0), one SVG per status in `rldb/assets/icons/status/`. The
  authors are credited in-game (main menu > Credits) and in `rldb/assets/CREDITS.md`. Choices: Rune
  rune-stone, Retain anchor, Eternal ankh, Pierce broadhead arrow, Cleanse sparkles, Medic heart-plus,
  Infiltrate hood, Nimble sprint, Reveal eye, Burn flame, Paralyse crossed chains, Curse pentacle,
  Poison skull-and-drop, Blind crossed-out eye, Debilitate cracked shield.
- **Instant name tip:** every drawn icon records its rect. Hovering one shows `StatusTip` at once
  ("Poison ×2"); the native tooltip waits for its delay, which is too long for something this small.
  The "+N" token's tip lists the hidden statuses. The card's own tooltip is held back while the
  pointer is on an icon. This works on the field, in the hand, in the catalogue and in the inspector.
- The card details panel rows use the same tokens, so the icon on the card and its explanation match.

## 4. Material surfaces

Asset packs considered: Kenney UI packs (CC0, but cartoon-styled and clash with the art), 9-slice
frame packs (fixed borders, poor at the many panel sizes), and PBR scans from ambientCG and Poly
Haven (CC0, photographic, seamless). Chosen: four ambientCG scans, **Leather032** (creased leather),
**Leather030** (pebbled), **Wood051** (dark wood) and **Metal009** (brushed metal). The colour and
normal maps are baked by `tools/godot/bake_ui_materials.gd` into 512 px seamless grayscale relief maps:

- fine colour variation plus normal-map lighting from the upper left;
- large-scale blotches removed (true box low-pass), so tiling never shows patches;
- normalised to a mean of 0.5.

`UiSurface` draws a relief map tinted with twice the surface's own colour, which leaves the colour on
average unchanged and adds only grain. Nothing in the palette moves:

| Where | Material | Strength |
|---|---|---|
| Sidebar panels, player plates, deck builder / catalogue plates, modals (HousePanel), OrnatePanel | leather | `UIStyle.PANEL_GRAIN` 0.55 (0.44 under gradients) |
| Every themed button and `primary_button` | brushed metal | `BUTTON_GRAIN` 0.6, gold faces `GOLD_GRAIN` 0.32 |
| Catalogue / deck builder backdrop | wood | `BACKDROP_GRAIN` 0.85 |
| Card bodies / card name plates | pebbled leather / brushed metal | `CardFaceParts.BODY_GRAIN` 0.55 / `PLATE_GRAIN` 0.7 |

The play field and menu already use photographic table and forest art, so they are unchanged. Gems
(cost gem, AP gems, deck crest) stay vector: their faceted highlights read better at 10-30 px than a
gem photo would.

Mechanism: `UiSurface.SurfaceBox` is a StyleBox wrapping a StyleBoxFlat. It draws the flat box
(shadow, fill, border), then the grain clipped to the rounded fill. Hand-drawn parts call
`UiSurface.draw_round`. `UiSurface.restyled()` recolours a wrapped box and keeps its grain; the
danger buttons in the confirm dialog use it.

## 5. Evidence and checks

- `production/qa/evidence/2026-10-18-card-redesign/`, from the windowed driver
  `rldb/src/dev/card_redesign_shots.gd` at 1600x1000 and 3840x2160 (14 checks: art on every visible
  card, icons over the art, instant tips on field / Defense / overflow / inspector, Runes first, tip
  hides on leave, credits list the licences). Plus series, rewards and prompt screens from
  `f04_series_driver`.
- `tests/unit/ui/card_redesign_test.gd`: 18 tests (art lookup, coverage and orphans, placeholder
  fallback, icon entries and order, every status has an icon, icons inside the art on every kind
  and on a rotated card, the "+N" overflow, the instant tip and the held-back card tooltip, tip
  ownership, square windows, tall-card badge placement, material textures, tint, round-rect points,
  SurfaceBox margins and restyle).
