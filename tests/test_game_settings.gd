extends SceneTree

# 玩家設定：匯流排建立、音量／靜音、依名稱自動指派匯流排、存取。不動玩家的設定檔（測完還原）。
# 執行：godot --headless --path . --script tests/test_game_settings.gd

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)

func _run() -> void:
	await process_frame
	var gs = root.get_node("GameSettings")
	var backup := ConfigFile.new()
	var had := backup.load(gs.PATH) == OK
	for b in gs.BUSES:
		_check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)
	gs.set_volume("Music", 50)
	_check(abs(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.5)) < 0.01, "music volume 50% sets the bus db")
	gs.set_volume("SFX", 0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "volume 0 mutes the bus")
	gs.set_volume("SFX", 100)
	gs.set_muted("Voice", true)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Voice")), "mute toggle")
	gs.set_muted("Voice", false)
	_check(gs.bus_for_name("battleaudio/bgmplayer") == "Music" and gs.bus_for_name("musicplayer/gameroot") == "Music", "bgm and music players go to Music")
	_check(gs.bus_for_name("swordsound/main") == "SFX" and gs.bus_for_name("voicelines/liuyu") == "Voice", "others go to SFX, voice to Voice")
	var p := AudioStreamPlayer.new()
	p.name = "BGMPlayer"
	root.add_child(p)
	_check(p.bus == "Music", "a new BGM player is assigned to Music automatically")
	var q := AudioStreamPlayer.new()
	q.name = "Hit"
	root.add_child(q)
	_check(q.bus == "SFX", "a new generic player is assigned to SFX")
	gs.set_volume("Music", 33)
	var reload := ConfigFile.new()
	_check(reload.load(gs.PATH) == OK and int(reload.get_value("audio", "Music_volume", -1)) == 33, "settings are saved to the config file")
	p.queue_free()
	q.queue_free()
	for b in gs.BUSES:
		gs.volume[b] = 100
		gs.muted[b] = false
	gs.apply_audio()
	if had:
		backup.save(gs.PATH)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.PATH))
	print("PASS test_game_settings" if _failures == 0 else "FAILED test_game_settings: %d" % _failures)
	quit(1 if _failures > 0 else 0)
