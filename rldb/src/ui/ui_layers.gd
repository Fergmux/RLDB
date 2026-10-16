class_name UiLayers
extends RefCounted
## Draw order (z_index) of every layered UI element in one place. Equal values fall back to
## child order, so the numbers only need to be unique where overlap matters.

## Effect cards while their holder animates (cast flash, ghosts) and the front-most effect card.
const FX_CARD := 20
const FX_CARD_FRONT := 30
## A hovered / lifted board card.
const LIFTED_CARD := 40
const ARROW := 55
## Floating effects (FxPlayer's layer).
const FX := 60
const TRAY := 65
const WAIT := 66
const BANNER := 70
const TOAST := 80
const COIN_FLIP := 85
## Killing-blow white flash, then the full-screen victory / defeat look above it (F04-04 / F04-07).
const SCREEN_FLASH := 87
const GAME_END := 88
const PILE_POPUP := 90
const GAME_MENU := 95
## Spell/Trap spotlight: backdrop, card, caption pill (above lifted cards, status glows, floating text).
const SPOTLIGHT_DIM := 95
const SPOTLIGHT_CARD := 96
const SPOTLIGHT_PILL := 97
const HOVER := 100
## Near-full-screen pile browser and the large card inspector (the inspector opens over the browser).
const PILE_BROWSER := 105
const CARD_INSPECTOR := 110
const CONFIRM_DIALOG := 120
## Screen transitions cover everything.
const FADER := 300
