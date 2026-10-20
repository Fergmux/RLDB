class_name SessionOptions
extends RefCounted
## The player's choices for the next series, shared by the main menu (which edits them) and the
## session launcher (which reads them). Lives as long as the Main scene, so the choices survive
## going back to the menu.

const DEFAULT_LAN_PORT := 24680
const DEFAULT_LAN_ADDR := "127.0.0.1:24680"
const BEST_OF_CHOICES: Array[int] = [1, 3, 5, 7]

## Series config handed to LocalHost / NetSession (best_of, deck_mode, names, public_lobby, ...).
var series: Dictionary = {"best_of": 3, "deck_mode": "starter", "names": ["Player 1", "Player 2"]}
## Hot-seat: hide the screen behind a "Pass to ..." panel between turns.
var privacy: bool = true
## Last address typed into "Join LAN" (host:port).
var lan_addr: String = DEFAULT_LAN_ADDR


# ---------------------------------------------------------------- bot options (J24)

## J24 (owner, 22 Oct): Play vs Bot with Custom decks asks for the bot's deck after yours instead
## of giving it a random Structure deck. Remembered for this viewer (this profile's settings file,
## [bot] choose_deck); automated runs keep it in a test file, never the player's.
var choose_bot_deck: bool = load_choose_bot_deck()

## Settings file and keys of the remembered choice.
static var PREFS_PATH := TEST_PREFS_PATH if DeckStore._default_path() == DeckStore.TEST_PATH else PLAYER_PREFS_PATH
const PLAYER_PREFS_PATH := "user://ui_settings.cfg"
const TEST_PREFS_PATH := "user://test_ui_settings.cfg"
const BOT_SECTION := "bot"
const BOT_CHOOSE_KEY := "choose_deck"


## The remembered "Choose the bot's deck" choice (false until set).
static func load_choose_bot_deck() -> bool:
	var cf := ConfigFile.new()
	if cf.load(PREFS_PATH) != OK:
		return false
	return bool(cf.get_value(BOT_SECTION, BOT_CHOOSE_KEY, false))


## Sets the choice and remembers it (keeps the file's other sections).
func set_choose_bot_deck(on: bool) -> void:
	choose_bot_deck = on
	var cf := ConfigFile.new()
	cf.load(PREFS_PATH)   # a missing file is fine
	cf.set_value(BOT_SECTION, BOT_CHOOSE_KEY, on)
	cf.save(PREFS_PATH)


## True when a bot series with `cfg` lets the player choose the bot's deck: the option is on and
## the series uses custom decks (a draft has no deck to choose).
func bot_deck_pick(cfg: Dictionary) -> bool:
	return choose_bot_deck and String(cfg.get("deck_mode", "starter")) == "starter"
