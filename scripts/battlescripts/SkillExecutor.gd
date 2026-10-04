extends Node

# ✅ 戰鬥敘事風格（只在這裡呼叫一次）
const BattleStyle = preload("res://scripts/battlestyles/battlestyle_cinematic.gd")
var style: BattleStyle = BattleStyle.new()

# ✅ ToneMap 可以保留（未來也許還會用），但這一支裡不再呼叫 "hit"
const ToneMap = preload("res://scripts/battlestyles/ToneMap.gd")
var tone: ToneMap = ToneMap.new()

const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")
const BattleDamageGuard = preload("res://scripts/battle/BattleDamageGuard.gd")

## Callable(actor, family) -> float: effects handed out by position in the ADB row (see StageAdjacency),
## read at the moment damage is worked out. Unset = none.
var adjacency_provider: Callable = Callable()
## The effect family of a 臨符 card that adds to each stat.
const STAT_FAMILIES: Dictionary = {"str": "STRENGTH_UP", "agi": "AGILITY_UP", "int": "INTELLECT_UP", "con": "CONSTITUTION_UP", "luck": "LUCK_UP"}

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
		"target_defending": false,
		"hit_chance": 100,
		"hit_roll": 0.0
	}

	# === 詞綴組合：有符合 boost_weapon 才套 prefix ===
	var prefix: String = ""
	# Effective variants already own their display name (for example
	# 「沉潮破浪槍」 or 「真．石破天驚拳」).  Do not prepend the active
	# inner-force prefix a second time when a resolved clone reaches execution.
	if not skill_data.has("coupling_tier") and inner_force.has("prefix") and inner_force.has("boost_weapon"):
		var boost_weapon: String = String(inner_force.get("boost_weapon", ""))
		var weapon_type_for_skill: String = String(skill_data.get("weapon_type", ""))
		if weapon_type_for_skill == boost_weapon:
			prefix = String(inner_force.get("prefix", ""))

	var raw_skill_name: String = String(skill_data.get("name", "（未命名招式）"))
	var skill_name: String = prefix + raw_skill_name
	result["skill_name"] = skill_name

	var w1: String = String(user.get("weapon_1", ""))
	var w2: String = String(user.get("weapon_2", ""))
	var has_empty_weapon_slot := (w1 == "" or w2 == "")
	var both_weapon_slots_empty := (w1 == "" and w2 == "")

	# 🖐️ 實際「佔手」的實體武器數（拳、掌不算佔手）
	var real_weapon_count = 0
	if w1 != "" and w1 != "拳" and w1 != "掌":
		real_weapon_count += 1
	if w2 != "" and w2 != "拳" and w2 != "掌":
		real_weapon_count += 1

	var has_free_hand = has_empty_weapon_slot

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
		elif weapon_required == "" or weapon_required == "通用":
			# 🔹 通用技能：不綁武器
			pass
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
	var attack_context := _resolve_effective_attack(user)
	var base_attack: float = float(attack_context.get("effective_atk", user.get("atk", 10)))
	# 臨符 cards beside the attacker: strength adds attack (1.2 per point, as the stat does), and an
	# ATTACK_UP card raises it by a rate. Read live; same family never stacks.
	base_attack += floorf(_adjacency(user, "STRENGTH_UP") * 1.2)
	base_attack *= 1.0 + _adjacency(user, "ATTACK_UP")
	var effective_attack: float = base_attack + float(scaling_bonus)
	if effective_attack < 1.0:
		effective_attack = 1.0
	result["base_atk"] = int(attack_context.get("base_atk", user.get("atk", 0)))
	result["effective_atk"] = int(base_attack)
	result["atk_status_delta"] = int(attack_context.get("status_delta", 0))
	var multiplier: float = float(skill_data.get("power", 1.0))
	var dmg: float = effective_attack * multiplier

	# === 石破心法：空手拳勢增幅 ===
	var inner_force_id := String(inner_force.get("id", ""))
	var is_fist_skill := String(skill_data.get("weapon_type", "")) == "拳"
	if inner_force_id == "shipo_xinfa" and is_fist_skill:
		if has_empty_weapon_slot:
			dmg *= (1.0 + float(inner_force.get("fist_damage_pct_if_free_hand", 0.0)))

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
	var weapon_accuracy_bonus := 0.0
	if skill_weapon_type != "" and not inner_force.is_empty():
		var boost_weapon_for_accuracy := String(inner_force.get("boost_weapon", ""))
		if boost_weapon_for_accuracy != "" and boost_weapon_for_accuracy == skill_weapon_type:
			weapon_accuracy_bonus = float(inner_force.get("weapon_accuracy_flat_bonus", 0))
	if inner_force_id == "shipo_xinfa" and is_fist_skill and both_weapon_slots_empty:
		weapon_accuracy_bonus += float(inner_force.get("fist_accuracy_flat_if_both_hands_free", 0.0))
	var hit_context := _roll_hit(user, target, weapon_accuracy_bonus)
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
	var element_advantage_multiplier := InnerForceDB.resolve_element_advantage_multiplier(user_element, target_element)
	if element_advantage_multiplier > 1.0:
		dmg *= element_advantage_multiplier
		context["element_advantage"] = true
	else:
		context["element_advantage"] = false
	var target_inner_force: Dictionary = target.get("inner_force", {}) if typeof(target.get("inner_force", {})) == TYPE_DICTIONARY else {}
	if user_element == "快" and not target_inner_force.is_empty():
		var reduction_base := float(target_inner_force.get("damage_reduction_vs_fast_base", 0.0))
		var reduction_from_str := float(target_inner_force.get("damage_reduction_vs_fast_from_str", 0.0))
		var reduction_cap := float(target_inner_force.get("damage_reduction_vs_fast_cap", 0.8))
		var target_str := float(int(target.get("str", 0)))
		var reduction := clampf(reduction_base + target_str * reduction_from_str, 0.0, max(0.0, reduction_cap))
		if reduction > 0.0:
			dmg *= (1.0 - reduction)
			context["inner_force_fast_resist"] = reduction

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
	var luck_stat := int(user.get("luck", 0)) + int(_adjacency(user, "LUCK_UP"))
	var base_crit := 0.05
	var luck_bonus = floor(float(luck_stat) / 5.0) * 0.01
	var crit_rate = base_crit + luck_bonus + float(skill_data.get("crit_rate_bonus", 0.0))
	crit_rate += float(user.get("crit_rate_bonus", 0.0))
	if inner_force_id == "tiancan_jue" and skill_weapon_type == "劍":
		var max_hp = max(1, int(user.get("max_hp", user.get("hp", 1))))
		var cur_hp = int(user.get("hp", 0))
		if float(cur_hp) < float(max_hp) * 0.5:
			crit_rate += float(inner_force.get("sword_crit_bonus_low_hp", 0.0))
	if inner_force_id == "shipo_xinfa" and _is_actor_fully_unequipped(user):
		crit_rate += float(inner_force.get("crit_rate_bonus_if_naked", 0.0))
	crit_rate = InnerForceDB.resolve_element_final_stat(user_element, "crit_rate", crit_rate)
	crit_rate = clampf(crit_rate, 0.0, 0.95)
	if randf() < crit_rate:
		dmg *= 1.5
		context["crit"] = true
		result["crit"] = true
	else:
		context["crit"] = false

	# --- 防禦（target.def * 2） ---
	var defense: float = InnerForceDB.resolve_element_final_stat(
		target_element,
		"def",
		float(target.get("def", 0))
	)
	# 臨符 cards beside the target add to its defense (same family never stacks: highest only):
	# constitution adds flat defense (0.8 per point, as the stat does), DEFENSE_UP a rate.
	defense += floorf(_adjacency(target, "CONSTITUTION_UP") * 0.8)
	var adjacency_bonus: float = _adjacency(target, "DEFENSE_UP")
	if adjacency_bonus > 0.0:
		defense *= 1.0 + adjacency_bonus
		context["adjacency_def_bonus"] = adjacency_bonus
	if bool(target.get("defending", false)):
		defense *= 2.0
		context["defending"] = true
	else:
		context["defending"] = false

	dmg -= defense
	if dmg < 1.0:
		dmg = 1.0
	if String(target_inner_force.get("id", "")) == "shipo_xinfa" and _is_actor_fully_unequipped(target):
		var reduction := clampf(float(target_inner_force.get("damage_reduction_pct_if_naked", 0.0)), 0.0, 0.95)
		dmg *= (1.0 - reduction)
		if dmg < 1.0:
			dmg = 1.0

	# 裝備效果在最終取整前套用；只認敵人資料的正式 family，不由名稱或外觀推斷。
	if String(user.get("family", "")) == "animal":
		var target_actor_id := String(target.get("id", ""))
		var inventory_sync := _get_inventory_sync()
		if target_actor_id != "" and inventory_sync and inventory_sync.has_method("get_equipment_effect"):
			var animal_multiplier := float(inventory_sync.get_equipment_effect(
				target_actor_id,
				"animal_damage_taken_multiplier",
				1.0
			))
			if animal_multiplier < 1.0:
				dmg *= clampf(animal_multiplier, 0.0, 1.0)
				context["animal_damage_reduction"] = 1.0 - animal_multiplier
				if dmg < 1.0:
					dmg = 1.0

	var dmg_int: int = int(dmg)
	var damage_guard: Dictionary = BattleDamageGuard.resolve_hp_damage(user, target, dmg_int)
	if bool(damage_guard.get("blocked", false)):
		dmg_int = 0
		result["damage_prevented"] = true
		result["damage_prevention_effect_id"] = String(damage_guard.get("effect_id", ""))
		result["damage_prevention_log"] = String(damage_guard.get("log", ""))
		# A blocked blow may still count as a hit for attached-status resolution,
		# but it is not presented as a damaging critical hit.
		result["crit"] = false
	else:
		dmg_int = int(damage_guard.get("damage", dmg_int))
	var target_hp: int = int(target.get("hp", 0)) - dmg_int
	target["hp"] = target_hp
	result["damage"] = dmg_int
	result["target_defending"] = bool(context.get("defending", false))

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
	# For recomposing a multi-strike log: what follows the damage line (the target's reaction / down line).
	var damage_line_index: int = int(context.get("_damage_line_index", -1))
	result["closing_lines"] = log_lines.slice(damage_line_index + 1) if damage_line_index >= 0 else []
	result["element_advantage"] = bool(context.get("element_advantage", false))
	if bool(result.get("damage_prevented", false)):
		# The strike aggregator emits one shield line for the whole action, so a
		# multi-hit skill cannot repeat the same long narration per segment.
		log_lines.clear()
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
		total += float(int(user.get(stat_key, 0)) + int(_adjacency(user, STAT_FAMILIES.get(stat_key, "")))) * coeff
	return int(floor(total))

func _resolve_effective_attack(actor: Dictionary) -> Dictionary:
	var current_atk := int(actor.get("atk", 10))
	var base_atk := current_atk
	if actor.has("battle_base_atk"):
		base_atk = int(actor.get("battle_base_atk", current_atk))
	elif actor.has("base_atk"):
		base_atk = int(actor.get("base_atk", current_atk))
	var effects = actor.get("status_effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		return {"base_atk": base_atk, "effective_atk": max(0, base_atk), "status_delta": 0}
	var effect_dict: Dictionary = effects
	var status_delta := 0
	if effect_dict.has("weaken") and typeof(effect_dict["weaken"]) == TYPE_DICTIONARY:
		var weaken_payload = effect_dict["weaken"].get("payload", {})
		if typeof(weaken_payload) == TYPE_DICTIONARY:
			status_delta += int((weaken_payload as Dictionary).get("atk_delta", 0))
	if effect_dict.has("atk_up") and typeof(effect_dict["atk_up"]) == TYPE_DICTIONARY:
		var atk_up_payload = effect_dict["atk_up"].get("payload", {})
		if typeof(atk_up_payload) == TYPE_DICTIONARY:
			status_delta += int((atk_up_payload as Dictionary).get("atk_delta", 0))
	return {
		"base_atk": base_atk,
		"effective_atk": max(0, base_atk + status_delta),
		"status_delta": status_delta,
	}

func _is_actor_fully_unequipped(actor: Dictionary) -> bool:
	if actor.is_empty():
		return false
	var actor_id := String(actor.get("id", ""))
	if actor_id == "":
		return false
	var inventory_sync := _get_inventory_sync()
	if inventory_sync == null or not inventory_sync.has_method("get_equipped"):
		return false
	var equip_slots := ["weapon_1", "weapon_2", "armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "accessory_2"]
	var equipped: Dictionary = inventory_sync.get_equipped(actor_id)
	for slot in equip_slots:
		if String(equipped.get(slot, "")) != "":
			return false
	return true

func _get_inventory_sync() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/InventorySync")


func _roll_hit(user: Dictionary, target: Dictionary, extra_accuracy: float = 0.0) -> Dictionary:
	var final_accuracy := InnerForceDB.resolve_element_final_stat(
		String(user.get("element", "")),
		"accuracy",
		float(user.get("accuracy", 100))
	)
	var final_evasion := InnerForceDB.resolve_element_final_stat(
		String(target.get("element", "")),
		"evasion",
		float(target.get("evasion", 0))
	)
	# 臨符 cards beside the target: agility and luck feed evasion as the stats do (0.7 and 0.3 a point).
	final_evasion += roundf(_adjacency(target, "AGILITY_UP") * 0.7 + _adjacency(target, "LUCK_UP") * 0.3)
	var accuracy_mod := final_accuracy - 100.0
	var evasion_mod := final_evasion
	# Player Accuracy/Evasion already include the canonical AGI/Luck contribution
	# from TeamData. Enemy actors provide these final fields directly, so the
	# contest must consume only the resolved combat stats on both sides.
	var hit_score := accuracy_mod + extra_accuracy
	var evade_score := evasion_mod
	var chance := clampi(int(round(75.0 + (hit_score - evade_score))), 5, 95)
	var roll := randf() * 100.0
	return {
		"hit": roll <= float(chance),
		"chance": chance,
		"roll": roll,
		"hit_score": hit_score,
		"evade_score": evade_score,
	}


func _build_dodge_log(user: Dictionary, target: Dictionary, skill_name: String, suppress_attack_opener: bool = false) -> Array:
	var user_name := String(user.get("name", "???"))
	var target_name := String(target.get("name", "???"))
	var lines: Array = []
	if not suppress_attack_opener:
		lines.append("%s 使出「%s」，攻勢直取 %s！" % [user_name, skill_name, target_name])
	var dodge_line := tone.get_character_tone_text("ally_dodge", String(target.get("id", "")))
	if dodge_line == "":
		dodge_line = "%s 身形一晃，避開了這一擊！" % target_name
	lines.append(dodge_line.replace("{name}", target_name))
	lines.append("這一招沒有命中。")
	return lines


## What a 臨符 card beside `actor` gives it right now for one effect family (0.0 when none).
func _adjacency(actor: Dictionary, family: String) -> float:
	if not adjacency_provider.is_valid():
		return 0.0
	return float(adjacency_provider.call(actor, family))
