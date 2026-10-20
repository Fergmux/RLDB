extends GdUnitTestSuite
## A2: in the public lobby list a lobby with a free seat is joined; a full one is watched.


func test_open_seat_reads_join() -> void:
	assert_str(LobbyListPanel.lobby_label("Aldric", 1)).is_equal("Join Aldric's lobby (1/2 players)")


func test_full_table_reads_watch_with_spectator_count() -> void:
	assert_str(LobbyListPanel.lobby_label("Aldric", 2)).is_equal("Watch Aldric's game · no spectators yet")
	assert_str(LobbyListPanel.lobby_label("Aldric", 5)).is_equal("Watch Aldric's game · 3 watching")
