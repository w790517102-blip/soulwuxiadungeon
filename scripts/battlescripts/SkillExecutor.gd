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
		"target_down": false,
		"hit": true,
		"dodged": false,
		"hit_chance": 100,
		"hit_roll": 0.0
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

	var w1: String = String(user.get("weapon_1", ""))
	var w2: String = String(user.get("weapon_2", ""))

	# 🖐️ 實際「佔手」的實體武器數（拳、掌不算佔手）
	var real_weapon_count = 0
	if w1 != "" and w1 != "拳" and w1 != "掌":
		real_weapon_count += 1
	if w2 != "" and w2 != "拳" and w2 != "掌":
		real_weapon_count += 1

	var has_free_hand = real_weapon_count < 2

	# === 邏輯分類判斷：武學才檢查武器（不要用 UI 分類欄位） ===
	var kind: String = String(skill_data.get("kind", "武學"))
	if kind == "武學":
		var weapon_required: String = String(skill_data.get("weapon_type", ""))
		var require_free_hand: bool = bool(skill_data.get("require_free_hand", false))
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

	var scaling_bonus = _calc_stat_scaling_bonus(user, skill_data)

	# === 基礎傷害計算 ===
	var base_attack: float = float(user.get("atk", 10))
	var effective_attack: float = base_attack + float(scaling_bonus)
	if effective_attack < 1.0:
		effective_attack = 1.0
	var multiplier: float = float(skill_data.get("power", 1.0))
	var dmg: float = effective_attack * multiplier

	# === 內功 boost 傷害加成（C-run）===
	var skill_weapon_type := String(skill_data.get("weapon_type", ""))
	if skill_weapon_type != "" and not inner_force.is_empty():
		var boost_weapon := String(inner_force.get("boost_weapon", ""))
		var boost_pct := float(inner_force.get("boost_damage_pct", 0.0))
		var require_unarmed := bool(inner_force.get("boost_require_unarmed", false))
		var boost_ok := (boost_weapon != "" and skill_weapon_type == boost_weapon and boost_pct > 0.0)
		if boost_ok and require_unarmed and real_weapon_count > 0:
			boost_ok = false
		if boost_ok:
			dmg *= (1.0 + boost_pct)
			result["boost_applied"] = true
			result["boost_pct"] = boost_pct

	var context: Dictionary = {}
	var suppress_attack_opener := bool(skill_data.get("_suppress_attack_opener", false))

	# --- 命中 / 閃避 ---
	var hit_context := _roll_hit(user, target)
	result["hit"] = bool(hit_context.get("hit", true))
	result["dodged"] = not bool(hit_context.get("hit", true))
	result["hit_chance"] = int(hit_context.get("chance", 100))
	result["hit_roll"] = float(hit_context.get("roll", 0.0))

	if not bool(hit_context.get("hit", true)):
		result["damage"] = 0
		result["target_down"] = false
		result["log"] = _build_dodge_log(user, target, skill_name, suppress_attack_opener)
		return result

	# --- 屬性剋制 ---
	var user_element: String = String(user.get("element", ""))
	var target_element: String = String(target.get("element", ""))
	if ke_system.has(user_element) and String(ke_system[user_element]) == target_element:
		dmg *= 1.2
		context["element_advantage"] = true
	else:
		context["element_advantage"] = false

	# --- 書籍戰鬥修飾（筆系技能） ---
	if skill_weapon_type == "筆":
		var atk_mods = user.get("battle_modifiers", {})
		if typeof(atk_mods) == TYPE_DICTIONARY:
			var up := float(atk_mods.get("pen_damage_up", 0.0))
			if up != 0.0:
				dmg *= (1.0 + up)
		var def_mods = target.get("battle_modifiers", {})
		if typeof(def_mods) == TYPE_DICTIONARY:
			var resist := float(def_mods.get("pen_damage_resist", 0.0))
			if resist != 0.0:
				dmg *= max(0.0, 1.0 - resist)

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
	context["suppress_attack_opener"] = suppress_attack_opener

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


func _calc_stat_scaling_bonus(user: Dictionary, skill_data: Dictionary) -> int:
	var scaling = skill_data.get("stat_scaling", {})
	if typeof(scaling) != TYPE_DICTIONARY:
		return 0
	var scaling_dict: Dictionary = scaling
	if scaling_dict.is_empty():
		return 0
	var total: float = 0.0
	for stat_key in ["str", "agi", "int", "con", "luck"]:
		var coeff: float = float(scaling_dict.get(stat_key, 0.0))
		if coeff == 0.0:
			continue
		total += float(int(user.get(stat_key, 0))) * coeff
	return int(floor(total))


func _roll_hit(user: Dictionary, target: Dictionary) -> Dictionary:
	var accuracy := int(user.get("accuracy", 100))
	var evasion := int(target.get("evasion", 0))
	var chance := clampi(accuracy - evasion, 5, 100)
	var roll := randf() * 100.0
	return {
		"hit": roll < float(chance),
		"chance": chance,
		"roll": roll,
	}


func _build_dodge_log(user: Dictionary, target: Dictionary, skill_name: String, suppress_attack_opener: bool = false) -> Array:
	var user_name := String(user.get("name", "???"))
	var target_name := String(target.get("name", "???"))
	var lines: Array = []
	if not suppress_attack_opener:
		lines.append("%s 使出「%s」，攻勢直取 %s！" % [user_name, skill_name, target_name])
	var dodge_line := tone.get_tone_text("ally_dodge", "", String(target.get("id", "")))
	if dodge_line == "":
		dodge_line = "%s 身形一晃，避開了這一擊！" % target_name
	lines.append(dodge_line.replace("{name}", target_name))
	lines.append("這一招沒有命中。")
	return lines
