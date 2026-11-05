# Asset credits

The in-game list (main menu, Options > Credits) is read from `rldb/data/credits.json`; keep the two in step.

| Asset | Where | Source | Licence |
|---|---|---|---|
| Card art (188 cards) | `assets/art/cards/<id>.webp` | RLDB team, accepted through the card art review tool; imported by `tools/godot/import_card_art.gd` | Project-owned |
| Table / menu backgrounds, soundtrack | `assets/art/tables/`, `assets/art/menu_background.jpg`, `assets/audio/music/` | RLDB team | Project-owned |
| Sound effects | `assets/audio/sfx/` | Generated with ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), Nov 2026; mastered by `tools/sfx_master.py` | ElevenLabs output; commercial use needs a paid ElevenLabs plan at generation time (see `assets/audio/sfx/README.md`) |
| Painted card backs (6) | `assets/art/card_backs/back_<id>.webp` | Generated with GPT Image 2 (`gpt-image-2`, via ElevenLabs), Nov 2026; one take picked per back, resized to 512x768 WebP; the frame and the Violet Sigil are drawn in code (`src/ui/card/card_back.gd`) | AI-generated output made for RLDB; no third-party artwork |
| Status icons | `assets/icons/status/*.svg` | [game-icons.net](https://game-icons.net) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Surface relief maps | `assets/art/materials/*.png` | [ambientCG](https://ambientcg.com) scans, converted by `tools/godot/bake_ui_materials.gd` | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Fonts | `assets/fonts/` | Cinzel, Alegreya Sans; RLDB Symbols, a subset of Noto Sans Symbols 2 made by `tools/fonts/make_symbols.py` (see the `*-OFL.txt` files) | SIL OFL 1.1 |

## Status icons (game-icons.net, CC BY 3.0)

L8 (2026-11-05): the glyphs are composited (dark outline, drop shadow, tinted fill) onto enamelled,
gold-bezelled badges by `tools/gen_status_badges.py`, which writes `badge_<key>.svg` next to them;
`CardStatusIcons` draws the badges. The badge frames, enamels and motifs are RLDB's own. The
Paralyse badge uses RLDB's own lightning bolt; `paralyse.svg` (crossed-chains) stays as the
plain-token fallback only. Since the final review (2026-11-05) the Cleanse badge uses RLDB's own
bold sparkle too (`cleanse.svg` stays as the plain-token fallback).

| File | Icon | Author |
|---|---|---|
| rune.svg | rune-stone | Lorc |
| retain.svg | anchor | Lorc |
| eternal.svg | ankh | Lorc |
| pierce.svg | broadhead-arrow | Lorc |
| cleanse.svg | sparkles (fallback only; the badge uses RLDB's own sparkle) | Delapouite |
| medic.svg | heart-plus | Zeromancer |
| infiltrate.svg | hood | Lorc |
| nimble.svg | sprint | Lorc |
| reveal.svg | semi-closed-eye | Lorc |
| burn.svg | flame | Carl Olsen |
| paralyse.svg | crossed-chains (fallback only; the badge uses RLDB's own bolt) | Lorc |
| curse.svg | pentacle | Skoll |
| poison.svg | death-juice | Darkzaitzev |
| blind.svg | sight-disabled | Skoll |
| debilitate.svg | cracked-shield | Lorc |

## Surface textures (ambientCG, CC0)

| File | Scan |
|---|---|
| leather.png | Leather032 (creased leather: panels, plates, modals) |
| pebble.png | Leather030 (pebbled leather: card bodies) |
| wood.png | Wood051 (dark wood: screen backdrops) |
| metal.png | Metal009 (brushed metal: buttons, card name plates) |

Rebake: download the 1K-JPG zips, unzip their `_Color.jpg` and `_NormalGL.jpg` into one folder, then
`godot --headless --path rldb -s ../tools/godot/bake_ui_materials.gd -- <folder> leather=Leather032 pebble=Leather030 wood=Wood051 metal=Metal009:1.0:0.25:1`.
