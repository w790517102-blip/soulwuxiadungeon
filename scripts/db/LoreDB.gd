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
	"inn_boss": {
		"name": "旅館老闆",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/inn_boss.png",
		"bio": "茶坊與消息的掌舵人，善察人心與風向，言語間常藏弦外之音。",
		"default_unlocked": false,
		"unlock_flags": ["met_yuheng_inn_boss", "met_yuheng_teahouse_boss"],
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
		"name": "書眠",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Su_Mien_battle.png",
		"bio": "筆意如劍，語氣似水。看似溫和，實則每一步都踩在節奏之上。",
		"default_unlocked": false,
		"unlock_flags": ["met_Su_Mien"],
	},
}

static func get_hero_ids() -> Array:
	return HERO_DEFS.keys()

static func get_hero_def(hero_id: String) -> Dictionary:
	var raw: Dictionary = HERO_DEFS.get(hero_id, {})
	if raw.is_empty():
		return {}
	var out := raw.duplicate(true)
	out["id"] = hero_id
	return out

static func is_hero_unlocked(hero_id: String) -> bool:
	var data := get_hero_def(hero_id)
	if data.is_empty():
		return false
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
