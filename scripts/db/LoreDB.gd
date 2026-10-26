extends Node
class_name LoreDB

const CharacterDB = preload("res://scripts/db/CharacterDB.gd")
const EnemyDB = preload("res://scripts/db/EnemyDB.gd")
const ItemDB = preload("res://scripts/db/ItemDB.gd")

const HERO_DEFS := {
	"liuyu": {
		"name": "劉語塵",
		"portrait_path": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png",
		"bio": "江湖初行的少俠。行事講究分寸，也願在亂局中尋一條不負本心的路。",
		"default_unlocked": true,
		"unlock_flags": [],
	},
	"zuoyin": {
		"name": "左飲",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Zuo_Yin_headshot.png",
		"meta": ["身分：飲月山莊莊主"],
		# 動態人物誌：玩家知道多少就記錄多少（見下方「動態人物誌」說明）。
		# 劉語塵在鐘乳石洞親眼見到左飲出手相助、並得知他的身分（「原來，你就是飲月山莊的左大俠」那段）之後，才收錄。
		# 劇情裡這段結束時會落 battle_stalactite_fish_boss_phase2；打贏魘將之後還會有 battle_stalactite_fish_boss_won，
		# 兩個旗標都是永久旗標（會存檔）。只聽過鎮民傳聞時不會收錄。
		"stages": [
			{"any": [{"flag": "battle_stalactite_fish_boss_phase2"}, {"flag": "battle_stalactite_fish_boss_won"}, {"flag": "main_yh_manor_after_fish_ready"}]},
		],
		"sections": [
			{"stage": 1, "text": "江湖上關於左飲的傳聞眾說紛紜。有人稱他豪爽重義，也有人說他行事詭譎，似正似邪。其過往鮮為人知，性情看似灑脫不羈，卻令人難以捉摸。"},
			{"stage": 1, "text": "身為飲月山莊莊主，平日不輕易見客。玉衡鎮風波漸起之際，他卻在危急關頭現身，出手替劉語塵與白書眠解圍。"},
			{"stage": 1, "text": "傳聞究竟有幾分真實？這位看似隨性的江湖人物，又在守護著什麼？或許唯有相識漸深，方能知曉。"},
		],
	},
	"old_fighter": {
		"name": "比武老翁",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Old_Man_headshot.png",
		"meta": ["地點：玉衡鎮演武台", "姓名：未詳"],
		# 三個階段（高階段成立時，前面的階段一併收錄——第一次比武就完全卸裝獲勝會直接看到全部）：
		#   1 初次交談（老翁腳本在第一段介紹結束時落 heard_oldman_zuoyin）
		#   2 比武獲勝：持武器獲勝（yh_side_oldfighter_weapon_win）或空手但仍穿其他裝備獲勝（yh_side_oldfighter_unarmed_win）
		#   3 完全卸裝獲勝、完成支線〈拳骨未老〉（SideQuestManager 的 yh_side_oldfighter_01 is_finished）
		# 看的是「曾經完成什麼」（旗標與任務進度，都會存檔），不是玩家現在穿著什麼。
		"stages": [
			{"any": [{"flag": "heard_oldman_zuoyin"}]},
			{"any": [{"flag": "yh_side_oldfighter_weapon_win"}, {"flag": "yh_side_oldfighter_unarmed_win"}]},
			{"any": [{"quest_done": "yh_side_oldfighter_01"}]},
		],
		"sections": [
			{"stage": 1, "text": "玉衡鎮舊演武台旁，一名終日持帚清掃的老翁。常念昔日武堂盛況，感嘆如今少年多習文墨，少有人願登台較量。"},
			{"stage": 1, "text": "據其自述，年輕時曾與左飲在此切磋，對其「燕行破風斬」至今記憶猶新。只是每逢問起當年勝負，總愛含糊帶過。"},
			{"stage": 2, "text": "老翁性情好勝，尤重拳腳根骨。嘴上說是點到為止，真遇上有本事的後輩，卻又忍不住爭個高下。雖然時常嘴硬逞強，談起武學卻也並非全無真才實學。"},
			{"stage": 3, "text": "至於他那套「捨去外物，方見真功」的道理……若見他手中那把從不離身的掃帚，最好還是別急著追問。"},
		],
	},
	"hong_huei_yin": {
		"name": "紅徽音",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png",
		"bio": "琴聲清遠，神情若定若離。表面從容，實則每一句都像在試探人心。",
		"default_unlocked": false,
		"unlock_flags": ["event_tea_house_first_met"],
	},
	"zhe_yen_won": {
		"name": "折簷翁",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Zhe_yen_won_headshot.png",
		"bio": "行跡飄忽的說書人，常在章節地圖現身，似觀局者又似布局者。",
		"default_unlocked": false,
		"unlock_flags": ["met_zhe_yen_won"],
	},
	"xan_bu_lay": {
		"name": "單步雷",
		"portrait_path": "res://assets/sprites/NPC/YinHuo/Xan_Bu_Lay_headshot.png",
		"bio": "出手乾淨俐落，談笑間自有鋒芒。與其交手更像一場試心。",
		"default_unlocked": false,
		"unlock_flags": ["met_yuheng_teahouse_guard"],
	},
	"shumian": {
		"name": "白書眠",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Su_Mien_headshot2.png",
		"bio": "筆意如劍，語氣似水。看似溫和，實則每一步都踩在節奏之上。",
		"default_unlocked": false,
		"unlock_flags": ["met_Su_Mien"],
	},
}

static func get_hero_ids() -> Array:
	return HERO_DEFS.keys()

## ------------------------------------------------------------------
## 動態人物誌：玩家知道多少，豪傑誌就記錄多少
## 人物資料可以有 "stages"（階段條件）與 "sections"（段落）：
##   stages：陣列，第 i 個元素是第 i 階段的條件 {"any": [條件…]}，任一條件成立就達成這個階段。
##           條件： {"flag": 旗標名}（GlobalState 旗標）、{"quest_done": 支線 id}（SideQuestManager 已完成）。
##   sections：每段 {"stage": N, "text": 文字}；達成階段 ≥ N 的段落才顯示，依序排列。
## 達成的階段＝「條件成立的最高階段」，所以玩家跳級（直接完成高階條件）時，前面的段落一併解鎖。
## 全部都從旗標與任務進度即時判斷（不另外存狀態、不快取），所以存讀檔、重新進場景都不會倒退或不同步。
## 沒有 stages 的人物維持原本的 bio／unlock_flags 規則。
## ------------------------------------------------------------------
static func _condition_met(cond: Dictionary) -> bool:
	if cond.has("flag"):
		return GlobalState != null and GlobalState.has_method("get_flag") and bool(GlobalState.get_flag(String(cond["flag"])))
	if cond.has("quest_done"):
		return SideQuestManager != null and SideQuestManager.has_method("is_quest_finished") and bool(SideQuestManager.is_quest_finished(String(cond["quest_done"])))
	return false

## 目前達成的階段（0 ＝ 還沒有任何階段，不收錄）；沒有階段設定的人物回傳 -1
static func get_hero_stage(hero_id: String) -> int:
	var raw: Dictionary = HERO_DEFS.get(hero_id, {})
	var stages: Array = raw.get("stages", [])
	if stages.is_empty():
		return -1
	for i in range(stages.size() - 1, -1, -1):
		for cond in (stages[i] as Dictionary).get("any", []):
			if _condition_met(cond as Dictionary):
				return i + 1
	return 0

## 目前已解鎖的段落文字（依序）；沒有分段設定的人物回傳空陣列
static func get_hero_paragraphs(hero_id: String) -> Array:
	var raw: Dictionary = HERO_DEFS.get(hero_id, {})
	var out: Array = []
	if raw.get("sections", []).is_empty():
		return out
	var stage := get_hero_stage(hero_id)
	for sec in raw.get("sections", []):
		if int((sec as Dictionary).get("stage", 1)) <= stage:
			out.append(String((sec as Dictionary).get("text", "")))
	return out

static func get_hero_def(hero_id: String) -> Dictionary:
	var raw: Dictionary = HERO_DEFS.get(hero_id, {})
	if raw.is_empty():
		return {}
	var out := raw.duplicate(true)
	out["id"] = hero_id
	if not raw.get("sections", []).is_empty():
		var paragraphs := get_hero_paragraphs(hero_id)
		out["paragraphs"] = paragraphs
		out["bio"] = "\n".join(paragraphs)      # 舊見聞頁直接讀 bio（段落之間換一行）
	return out

static func is_hero_unlocked(hero_id: String) -> bool:
	var data := get_hero_def(hero_id)
	if data.is_empty():
		return false
	if not (HERO_DEFS.get(hero_id, {}) as Dictionary).get("stages", []).is_empty():
		return get_hero_stage(hero_id) >= 1
	if bool(data.get("default_unlocked", false)):
		return true
	var flags: Array = data.get("unlock_flags", [])
	for flag_any in flags:
		var flag_name := String(flag_any)
		if flag_name != "" and GlobalState and GlobalState.has_method("get_flag") and bool(GlobalState.get_flag(flag_name)):
			return true
	return false

static func get_enemy_display_name(enemy_id: String) -> String:
	var enemy := EnemyDB.get_def(enemy_id)
	if enemy.is_empty():
		return enemy_id
	return str(enemy.get("display_name", enemy.get("name", enemy_id)))

static func get_enemy_lore_detail(enemy_id: String) -> Dictionary:
	var enemy := EnemyDB.get_def(enemy_id)
	if enemy.is_empty():
		return {}
	var out := enemy.duplicate(true)
	out["id"] = enemy_id
	out["name"] = str(out.get("display_name", out.get("name", enemy_id)))
	return out

static func get_item_lore_detail(item_id: String) -> Dictionary:
	var item := ItemDB.get_def(item_id)
	if item.is_empty():
		return {}
	var out := item.duplicate(true)
	out["id"] = item_id
	out["name"] = str(out.get("name", item_id))
	out["description"] = str(out.get("desc", out.get("description", "")))
	return out

static func item_type_display_name(item_type: String) -> String:
	match item_type:
		"equipment":
			return "裝備"
		"consumable":
			return "消耗"
		"material":
			return "材料"
		"tool":
			return "器具"
		"food":
			return "食物"
		"misc":
			return "雜項"
		"quest":
			return "任務"
		_:
			return item_type
