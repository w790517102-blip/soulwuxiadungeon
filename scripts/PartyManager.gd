extends Node
class_name PartyManagerInstance

var party_members := []

func get_all_members_data() -> Array:
	return party_members

func load_members_from_data(data: Array) -> void:
	party_members = data
	print("[隊伍] 角色資料載入成功:", party_members)
