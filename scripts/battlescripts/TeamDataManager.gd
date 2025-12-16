# TeamDataManager.gd
# ✅ 負責管理所有角色資料與隊伍編組，用於戰鬥 / 地圖 / UI 等模組

extends Node

# === 所有可用角色（包含未上場） ===
var all_characters: Dictionary = {
"liuyu": {
	"id": "liuyu",
	"name": "劉語塵",
	# --- 能力值 ---
	"hp": 150,
	"max_hp": 150,
	"mp": 60,
	"max_mp": 60,
	"atk": 20,
	"def": 5,
	"element": "快",
	"speed": 8,
	# --- 裝備 & 狀態 ---
	"weapon_1": "劍",
	"weapon_2": "",
	"defending": false,
	"defense_value": 0,
	# --- 頭像 ---
	"portrait_path": "res://assets/sprites/Liu_Yu/LiuYu_battle.png",
	# --- 內功（當前使用中） ---
	"inner_force": {
		"prefix": "清風",
		"type": "訣",
		"boost_weapon": "刀",
		"element": "快",
		"description": "清風訣，氣行經脈如風掠青峯，出招輕靈而不失鋒利。修至純熟者，刀勢如風卷殘雲。"
	},
	"available_inner_forces": [
		{
			"prefix": "清風",
			"type": "訣",
			"boost_weapon": "刀",
			"element": "快",
			"description": "清風訣，行功講究一吐一納之間，體內真氣隨呼吸盤旋，如清風拂面，最利刀勢與迅疾身法。"
		},
		{
			"prefix": "無極",
			"type": "真經",
			"boost_weapon": "劍",
			"element": "遲",
			"description": "無極真經，意守丹田如天地初開，不動則如山，一動則驚人。劍勢緩發卻後勁綿長，專破浮躁之敵。"
		}
	],
	"inner_force_used_prefixes": []  # ★ 新增
},

"lieshao": {
	"id": "lieshao",
	"name": "列肖",
	# --- 能力值 ---
	"hp": 180,
	"max_hp": 180,
	"mp": 80,
	"max_mp": 80,
	"atk": 18,
	"def": 4,
	"element": "剛",
	"speed": 6,
	# --- 裝備 & 狀態 ---
	"weapon_1": "琴",
	"weapon_2": "刀",
	"defending": false,
	"defense_value": 0,
	# --- 頭像 ---
	"portrait_path": "res://assets/sprites/NPC/LieFong/LieShao_battle.png",
	# --- 內功 ---
	"inner_force": {
		"prefix": "赤陽",
		"type": "真經",
		"boost_weapon": "琴",
		"element": "剛",
		"description": "赤陽真經，以烈陽為象，運轉之時胸臆如有烈日騰昇，琴音每顫一分，勁力便狠辣一分。"
	},
	"available_inner_forces": [
		{
			"prefix": "赤陽",
			"type": "真經",
			"boost_weapon": "琴",
			"element": "剛",
			"description": "赤陽真經，出自弦心門烈火脈，專為琴音殺伐而生。內息如火走弦，聲聲皆可焚心。"
		},
		{
			"prefix": "破軍",
			"type": "真經",
			"boost_weapon": "刀",
			"element": "快",
			"description": "破軍真經，逆勢行功，專破堅城厚甲。心法一起，刀意如星墜天江，勢若破軍。"
		}
	],
	"inner_force_used_prefixes": []  # ★ 新增
},

"shumian": {
	"id": "shumian",
	"name": "書眠",
	# --- 能力值 ---
	"hp": 120,
	"max_hp": 120,
	"mp": 100,
	"max_mp": 100,
	"atk": 12,
	"def": 3,
	"element": "柔",
	"speed": 9,
	# --- 裝備 & 狀態 ---
	"weapon_1": "筆",
	"weapon_2": "拳",
	"defending": false,
	"defense_value": 0,
	# --- 頭像 ---
	"portrait_path": "res://assets/sprites/NPC/Yuheng/Su_Mien_battle.png",
	# --- 內功 ---
	"inner_force": {
		"prefix": "夢影",
		"type": "心法",
		"boost_weapon": "筆",
		"element": "柔",
		"description": "夢影心法，如夢似幻，修者能在半醒半寐間調息行氣，使經脈鬆弛而不散，筆鋒隨心意流轉。"
	},
	"available_inner_forces": [
		{
			"prefix": "夢影",
			"type": "心法",
			"boost_weapon": "筆",
			"element": "柔",
			"description": "夢影心法，講究一念入夢，一念出塵。運轉得法時，書寫如雲煙流動，筆鋒隨心意流轉。"
		},
		{
			"prefix": "靈風",
			"type": "訣",
			"boost_weapon": "拳",
			"element": "快",
			"description": "靈風訣，輕身如燕，出拳若風行林梢。氣機不著痕跡，卻能在掠過之處留下一記暗勁。"
		}
	],
	"inner_force_used_prefixes": []  # ★ 新增
}

}

# === 目前出戰隊伍（用角色 ID 陣列） ===
var current_team_ids: Array = ["liuyu", "shumian", "lieshao"]
# 之後你要在戰鬥前換隊，只要改這個陣列即可，或呼叫 set_active_party()


# === 回傳目前出戰角色完整資料（用 ID 反查） ===
func get_active_party() -> Array:
	var party: Array = []
	for id in current_team_ids:
		if all_characters.has(id):
			var actor = all_characters[id]

			# 🧩 關鍵：用當前 inner_force 的 element 覆蓋角色的 element
			var inner_force: Dictionary = actor.get("inner_force", {})
			if inner_force.has("element"):
				actor["element"] = inner_force["element"]

			party.append(actor)
		else:
			push_warning("❗ 找不到角色 ID：%s" % id)
	return party


# === 設定目前出戰隊伍（給 BattleController 的 fallback 用） ===
# BattleController 裡有：
#   player_party = TeamData.get_active_party()
#   if player_party.is_empty():
#       player_party = [ {...} ]
#       TeamData.set_active_party(player_party)
#
# 為了跟這段相容，我們實作 set_active_party
func set_active_party(party: Array) -> void:
	current_team_ids.clear()

	for member in party:
		if typeof(member) != TYPE_DICTIONARY:
			continue

		var id: String = member.get("id", "")
		if id == "":
			continue

		current_team_ids.append(id)

		# 如果原本有這個角色，就更新他的資料；沒有就直接新增
		if all_characters.has(id):
			var base = all_characters[id]

			# 安全同步幾個重要欄位（避免 nil）
			base["name"] = member.get("name", base.get("name", id))

			base["hp"] = member.get("hp", base.get("hp", 0))
			base["max_hp"] = member.get("max_hp", base.get("max_hp", base["hp"]))
			base["mp"] = member.get("mp", base.get("mp", 0))
			base["max_mp"] = member.get("max_mp", base.get("max_mp", base["mp"]))

			base["atk"] = member.get("atk", base.get("atk", 0))
			base["def"] = member.get("def", base.get("def", 0))
			base["element"] = member.get("element", base.get("element", ""))
			base["speed"] = member.get("speed", base.get("speed", 0))

			base["weapon_1"] = member.get("weapon_1", base.get("weapon_1", ""))
			base["weapon_2"] = member.get("weapon_2", base.get("weapon_2", ""))

			base["inner_force"] = member.get("inner_force", base.get("inner_force", {}))
			base["available_inner_forces"] = member.get(
				"available_inner_forces",
				base.get("available_inner_forces", [])
			)

			# 🧩 若 inner_force 有帶 element，就用它覆蓋角色當前屬性
			var inner_force: Dictionary = base.get("inner_force", {})
			if inner_force.has("element"):
				base["element"] = inner_force["element"]

			all_characters[id] = base
		else:
			# 完全新角色，直接收
			all_characters[id] = member


# === 提供角色查詢（未來可搭配 UI 編組使用） ===
func get_character_by_id(id: String) -> Dictionary:
	return all_characters.get(id, {})
