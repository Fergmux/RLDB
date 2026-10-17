extends GdUnitTestSuite
## F06-02: menu playlist between games, battle playlist during a game; each playlist plays its
## songs in turn and loops; switching playlist crossfades into the other playlist's next song.


func test_playlists_hold_the_user_tracks_and_load() -> void:
	assert_array(Music.PLAYLISTS["menu"]).has_size(2)
	assert_array(Music.PLAYLISTS["battle"]).has_size(3)
	for list in Music.PLAYLISTS.values():
		for path in list:
			assert_object(load(path)).is_instanceof(AudioStreamOggVorbis)


func test_each_playlist_cycles_through_all_its_songs() -> void:
	var m: Music = auto_free(Music.new())
	var seen := []
	for i in 4:
		seen.append(m._take_next("battle"))
	assert_array(seen).is_equal([Music.PLAYLISTS["battle"][0], Music.PLAYLISTS["battle"][1],
		Music.PLAYLISTS["battle"][2], Music.PLAYLISTS["battle"][0]])
	assert_str(m._take_next("menu")).is_equal(Music.PLAYLISTS["menu"][0])
	assert_str(m._take_next("menu")).is_equal(Music.PLAYLISTS["menu"][1])


func test_switching_playlist_crossfades_into_its_next_song() -> void:
	var m: Music = auto_free(Music.new())
	add_child(m)
	m._switch("menu")
	var first: AudioStreamPlayer = m._players[m._active]
	assert_str(first.stream.resource_path).is_equal(Music.PLAYLISTS["menu"][0])
	m._switch("menu")   # same playlist: no change
	assert_object(m._players[m._active]).is_same(first)
	m._switch("battle")
	var second: AudioStreamPlayer = m._players[m._active]
	assert_object(second).is_not_same(first)
	assert_str(second.stream.resource_path).is_equal(Music.PLAYLISTS["battle"][0])
	assert_bool(m._fading).is_true()   # the menu song fades out while the battle song fades in
	m._switch("menu")
	assert_str(m._players[m._active].stream.resource_path).is_equal(Music.PLAYLISTS["menu"][1])
