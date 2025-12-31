extends Node

# ✅ 戰鬥敘事風格（只在這裡呼叫一次）
const BattleStyle = preload("res://scripts/battlestyles/battlestyle_cinematic.gd")
var style: BattleStyle = BattleStyle.new()

# ✅ ToneMap 可以保留（未來也許還會用），但這一支裡不再呼叫 "hit"
const ToneMap = preload("res://scripts/battlestyles/ToneMap.gd")
var tone: ToneMap = ToneMap.new()

# 屬性剋制表：快 > 遲 > 柔 > 剛 > 快
var ke_system: Dictionary = {
	"快": "遲",
	"遲": "柔",
	"柔": "剛",
	"剛": "快"
}

func execute(
	user: Dictionary,
	target: Dictionary,
	skill_data: Dictionary,
	inner_force: Dictionary
) -> Dictionary:
	var result: Dictionary = {
		"log": [],
		"damage": 0,
		"crit": false,
		"skill_name": "",
		"target_down": false
	}

	# === 詞綴組合：有符合 boost_weapon 才套 prefix ===
	var prefix: String = ""
	if inner_force.has("prefix") and inner_force.has("boost_weapon"):
		var boost_weapon: String = String(inner_force.get("boost_weapon", ""))
		var weapon_type_for_skill: String = String(skill_data.get("weapon_type", ""))
		if weapon_type_for_skill == boost_weapon:
			prefix = String(inner_force.get("prefix", ""))

	var raw_skill_name: String = String(skill_data.get("name", "（未命名招式）"))
	var skill_name: String = prefix + raw_skill_name
	result["skill_name"] = skill_name

	# === 類別判斷：外功才檢查武器 ===
	var category: String = String(skill_data.get("category", "外功"))
	if category == "外功":
		var weapon_required: String = String(skill_data.get("weapon_type", ""))
		var require_free_hand: bool = bool(skill_data.get("require_free_hand", false))

		var w1: String = String(user.get("weapon_1", ""))
		var w2: String = String(user.get("weapon_2", ""))

		# 🖐️ 實際「佔手」的實體武器數（拳、掌不算佔手）
		var real_weapon_count = 0
		if w1 != "" and w1 != "拳" and w1 != "掌":
			real_weapon_count += 1
		if w2 != "" and w2 != "拳" and w2 != "掌":
			real_weapon_count += 1

		var has_free_hand = real_weapon_count < 2
		var uname: String = String(user.get("name", "???"))

		if weapon_required == "拳" or weapon_required == "掌":
			# 🔹 拳／掌武學：預設不吃武器限制
			if require_free_hand and not has_free_hand:
				var fail_line_free = "%s 嘗試使出 %s，但雙手都被兵器束縛，無法完全放開身形。" % [
					uname,
					skill_name
				]
				result["log"] = [fail_line_free]
				return result
			# 有空手就 OK，不再檢查 w1 / w2
		else:
			# 🔹 其他武器型技能：需要有對應武器
			if weapon_required != "":
				var has_weapon = (w1 == weapon_required or w2 == weapon_required)
				if not has_weapon:
					var fail_line_weapon = "%s 嘗試使出 %s，但未裝備合適武器，無法施展。" % [
						uname,
						skill_name
					]
					result["log"] = [fail_line_weapon]
					return result

	# === 基礎傷害計算 ===
	var base_attack: float = float(user.get("atk", 10))
	var multiplier: float = float(skill_data.get("power", 1.0))
	var dmg: float = base_attack * multiplier

	var context: Dictionary = {}

	# --- 屬性剋制 ---
	var user_element: String = String(user.get("element", ""))
	var target_element: String = String(target.get("element", ""))
	if ke_system.has(user_element) and String(ke_system[user_element]) == target_element:
		dmg *= 1.2
		context["element_advantage"] = true
	else:
		context["element_advantage"] = false

	# --- 暴擊 ---
	if randf() < 0.1:
		dmg *= 1.5
		context["crit"] = true
		result["crit"] = true
	else:
		context["crit"] = false

	# --- 防禦（target.def * 2） ---
	var defense: float = float(target.get("def", 0))
	if bool(target.get("defending", false)):
		defense *= 2.0
		context["defending"] = true
	else:
		context["defending"] = false

	dmg -= defense
	if dmg < 1.0:
		dmg = 1.0

	var dmg_int: int = int(dmg)
	var target_hp: int = int(target.get("hp", 0)) - dmg_int
	target["hp"] = target_hp
	result["damage"] = dmg_int

	# --- 是否倒下 ---
	if target_hp <= 0:
		result["target_down"] = true
		context["target_down"] = true
	else:
		result["target_down"] = false
		context["target_down"] = false

	# === 補充給 battle style 用的 context ===
	context["weapon_type"] = skill_data.get("weapon_type", user.get("weapon_1", "拳"))

	# 🧩 這裡改成「記錄＆比較 prefix」的版本
	var prefix_for_tone: String = String(inner_force.get("prefix", ""))
	context["inner_force_prefix"] = prefix_for_tone

	var last_prefix: String = String(user.get("_last_innerforce_prefix", ""))
	if prefix_for_tone != "" and prefix_for_tone != last_prefix:
		# ✅ 對這個角色來說，是第一次使用這個心法（或換功後第一次）
		context["first_time_using_inner_force"] = true
		user["_last_innerforce_prefix"] = prefix_for_tone
	else:
		context["first_time_using_inner_force"] = false

	# === 統一交給 battlestyle_cinematic 產生所有敘述（包含受擊台詞）===
	var log_lines: Array = style.describe_attack(
		user,
		target,
		skill_name,
		dmg_int,
		context
	)
	result["log"] = log_lines

	return result
