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
## The top strip (Menu, Chat) during play: above every burst (UI review F12).
const TOP_STRIP := 61
const TRAY := 65
const WAIT := 66
const BANNER := 70
## The Evolve prompt's hover comparison, beside the banner (final review #10).
const PROMPT_FLYOUT := 72
## Tutorial highlight ring and arrow: over the board, banner and tray, under every modal, popup
## and popover (F04-08).
const TUTORIAL_RING := 75
const TOAST := 80
const COIN_FLIP := 85
## Killing-blow white flash, then the full-screen victory / defeat look above it (F04-04 / F04-07).
const SCREEN_FLASH := 87
const GAME_END := 88
## Spell/Trap spotlight: backdrop, card, caption pill (above lifted cards, status glows, floating text).
const SPOTLIGHT_DIM := 95
const SPOTLIGHT_CARD := 96
const SPOTLIGHT_PILL := 97
const HOVER := 100
## J10 / J15 (owner, 22 Oct): the series-stage modal (rewards, deck choice, next game, series over) and its
## full-window dim sit above EVERY board layer (lifted and hovered cards, selection brackets, arrows,
## damage numbers, the action row), so nothing from the finished game draws over it.
const SERIES_MODAL := 101
## The top strip (Menu, Chat, spectator badge) while the series modal is up: above its dim, in place.
const SERIES_TOP_STRIP := 102
## The "your deck" popup opened from the series modal.
const PILE_POPUP := 103
## A picker opened from a series-stage modal (F06-06 Choose basic unit), over it and its dim.
const MODAL_PICKER := 104
## The network pause veil: over the series modal (it used to hide the veil between duels), under the menu.
const PAUSE := 105
## The in-game menu, settings, chat and spectator list (the tutorial plate and the hot-seat privacy
## backdrop sit just under it).
const GAME_MENU := 109
## Near-full-screen pile browser and the large card inspector (the inspector opens over the browser).
const PILE_BROWSER := 112
const CARD_INSPECTOR := 115
const CONFIRM_DIALOG := 120
## Screen transitions cover everything.
const FADER := 300
