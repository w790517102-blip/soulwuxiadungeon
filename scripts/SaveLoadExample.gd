func get_party_data() -> Array:
	var data = []
	for member in PartyManager.get_party_members():
		data.append({
			"name": member.name,
			"level": member.level,
			"stats": member.stats,
			"武學": {
				"內功": member.internal_skills,
				"外功": member.external_skills
			},
			"裝備": member.equipment,
			"道具欄": member.items
		})
	return data

func do_save():
	var save_data = {
		"main_story_progress": StoryManager.get_main_progress(),
		"side_quests": QuestManager.get_side_quests_status(),
		"relations": RelationManager.get_current_status(),
		"party": get_party_data(),
		"player_position": get_node("/root/MainScene/LiuYu").global_position,
		"current_scene": get_tree().current_scene.name,
		"global_flags": GlobalState.get_meta_dict(),
		"timestamp": Time.get_datetime_string_from_system()
	}
	SaveManager.save_game(save_data)

func do_load():
	var data = SaveManager.load_game()
	if data.is_empty():
		print("No save found.")
		return

	GlobalState.set_meta_dict(data["global_flags"])
	StoryManager.set_main_progress(data["main_story_progress"])
	RelationManager.load_status(data["relations"])
	QuestManager.load_side_quests(data["side_quests"])

	get_tree().change_scene_to_file("res://scenes/" + data["current_scene"] + ".tscn")
	await get_tree().create_timer(0.1).timeout

	var player = get_node("/root/MainScene/LiuYu")
	player.global_position = data["player_position"]
	PartyManager.restore_from_data(data["party"])
