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
