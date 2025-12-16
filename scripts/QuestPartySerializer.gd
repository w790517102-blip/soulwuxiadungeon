extends Node
class_name QuestPartySerializerInstance

func collect_save_data() -> Dictionary:
	var main_quest = QuestManager.get_main_quest_state()
	var party = PartyManager.get_all_members_data()
	
	# 主線簡述（任務描述）
	var quest_desc := "無主線"
	if main_quest.has("description"):
		quest_desc = main_quest["description"]
	
	# 隊長簡述（第一個隊員名稱與等級）
	var leader_desc := "無隊員"
	if party.size() > 0:
		var leader = party[0]
		if leader.has("name") and leader.has("level"):
			leader_desc = "%s Lv%d" % [leader["name"], leader["level"]]
	
	var summary := "%s｜主線：%s" % [leader_desc, quest_desc]

	return {
		"main_quest": main_quest,
		"side_quests": QuestManager.get_all_side_quests(),
		"party_members": party,
		"summary": summary
	}

func apply_loaded_data(data: Dictionary) -> void:
	if data.has("main_quest"):
		QuestManager.load_main_quest(data["main_quest"])
	if data.has("side_quests"):
		QuestManager.load_side_quests(data["side_quests"])
	if data.has("party_members"):
		PartyManager.load_members_from_data(data["party_members"])
