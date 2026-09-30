extends Node
class_name EnemyDB


const ARCHETYPE_ALIASES := {
	"地痞": "地痞",
	"山賊": "地痞",
	"匪徒": "地痞",
	"流氓": "地痞",
	"軍人": "朝廷",
	"官兵": "朝廷",
	"猛獸": "野獸",
	"蛇蟲": "爬蟲"
}

const ENEMY_DEFS := {
	"bamboo_macaque": {
		"display_name": "獼猴",
		"hp": 52,
		"max_hp": 52,
		"mp": 0,
		"atk": 29,
		"def": 5,
		"speed": 13,
		"element": "快",
		"exp": 8,
		"gold": {"chance": 0.95, "min": 15, "max": 20},
		"drops": [],
		"ai_profile": "aggressive",
		"skills": [],
		"family": "animal",
		"archetype": "野獸",
		"accuracy": 104,
		"evasion": 5,
		"crit_rate_bonus": 0.01
	},
	"bamboo_bobcat": {
		"display_name": "山貓",
		"hp": 48,
		"max_hp": 48,
		"mp": 0,
		"atk": 32,
		"def": 4,
		"speed": 15,
		"element": "快",
		"exp": 10,
		"gold": {"chance": 0.95, "min": 15, "max": 20},
		"drops": [],
		"ai_profile": "aggressive",
		"skills": [],
		"family": "animal",
		"archetype": "野獸",
		"accuracy": 111,
		"evasion": 7,
		"crit_rate_bonus": 0.03
	},
	"bamboo_wild_boar": {
		"display_name": "野豬",
		"hp": 90,
		"max_hp": 90,
		"mp": 0,
		"atk": 33,
		"def": 7,
		"speed": 8,
		"element": "剛",
		"exp": 12,
		"gold": {"chance": 0.95, "min": 20, "max": 35},
		"drops": [],
		"ai_profile": "aggressive",
		"skills": [],
		"family": "animal",
		"archetype": "野獸",
		"accuracy": 98,
		"evasion": 0,
		"crit_rate_bonus": 0.01
	},
	"bamboo_poison_snake": {
		"display_name": "毒蛇",
		"hp": 45,
		"max_hp": 45,
		"mp": 0,
		"atk": 32,
		"def": 4,
		"speed": 14,
		"element": "柔",
		"exp": 10,
		"gold": {"chance": 0.95, "min": 20, "max": 40},
		"drops": [],
		"ai_profile": "aggressive",
		"skills": [],
		"family": "animal",
		"archetype": "爬蟲",
		"accuracy": 108,
		"evasion": 7,
		"crit_rate_bonus": 0.02
	},
	"sewer_rat_swarm": {
		"display_name": "鼠群",
		"hp": 55,
		"max_hp": 55,
		"mp": 0,
		"atk": 10,
		"def": 5,
		"speed": 13,
		"element": "群",
		"exp": 9,
		"gold": {"chance": 0.35, "min": 2, "max": 5},
		"drops": [],
		"ai_profile": "default",
		"skills": [],
		"family": "animal",
		"archetype": "野獸"
	},
	"sewer_thug": {
		"display_name": "下水道匪徒",
		"hp": 85,
		"max_hp": 85,
		"mp": 10,
		"atk": 13,
		"def": 7,
		"speed": 10,
		"element": "剛",
		"exp": 13,
		"gold": {"chance": 0.45, "min": 3, "max": 8},
		"drops": [],
		"ai_profile": "default",
		"skills": [],
		"archetype": "地痞"
	},
	"sewer_ooze_slime": {
		"display_name": "污泥怪",
		"hp": 110,
		"max_hp": 110,
		"mp": 0,
		"atk": 12,
		"def": 9,
		"speed": 6,
		"element": "濁",
		"exp": 16,
		"gold": {"chance": 0.4, "min": 4, "max": 10},
		"drops": [],
		"ai_profile": "default",
		"skills": [],
		"archetype": "未知"
	},
	"sewer_drowned_wight": {
		"display_name": "溺魂",
		"hp": 120,
		"max_hp": 120,
		"mp": 25,
		"atk": 14,
		"def": 8,
		"speed": 8,
		"element": "陰",
		"exp": 18,
		"gold": {"chance": 0.5, "min": 5, "max": 12},
		"drops": [],
		"ai_profile": "support",
		"skills": [],
		"archetype": "鬼神"
	},
	"yumei_sewer_rat": {
		"display_name": "污水鼠",
		"portrait_path": "res://assets/Enemy/yumei_sewer_rat.png",
		"hp": 55,
		"max_hp": 55,
		"mp": 0,
		"atk": 37,
		"def": 4,
		"speed": 14,
		"element": "快",
		"exp": 9,
		"gold": {"chance": 0.35, "min": 2, "max": 5},
		"drops": [],
		"ai_profile": "aggressive",
		"skills": [],
		"family": "animal",
		"archetype": "野獸",
		"accuracy": 112,
		"evasion": 4,
		"crit_rate_bonus": 0.01
	},
	"yumei_sewer_bat": {
		"display_name": "潮翳蝠",
		"portrait_path": "res://assets/Enemy/yumei_sewer_bat.png",
		"hp": 60,
		"max_hp": 60,
		"mp": 0,
		"atk": 36,
		"def": 3,
		"speed": 17,
		"element": "柔",
		"exp": 10,
		"gold": {"chance": 0.25, "min": 2, "max": 6},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_sewer_bat_tidal_swoop", "category": "attack", "weight": 10, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_sewer_bat_veiling_wings", "category": "debuff", "weight": 3, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "animal",
		"archetype": "野獸",
		"accuracy": 118,
		"evasion": 10,
		"crit_rate_bonus": 0.02
	},
	"fidgety_sewer_fish": {
		"display_name": "燥尾魚蝦魅",
		"portrait_path": "res://assets/Enemy/fidgety_sewer_fish.png",
		"hp": 64,
		"max_hp": 64,
		"mp": 0,
		"atk": 39,
		"def": 4,
		"speed": 15,
		"element": "快",
		"exp": 11,
		"gold": {"chance": 0.30, "min": 3, "max": 7},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_fidgety_sewer_fish_tail_flurry", "category": "attack", "weight": 8, "cd_turns": 1, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_fidgety_sewer_fish_dirty_splash", "category": "debuff", "weight": 3, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "animal",
		"archetype": "野獸",
		"accuracy": 114,
		"evasion": 6,
		"crit_rate_bonus": 0.01
	},
	"broken_string_tone_phantom": {
		"display_name": "斷弦魅",
		"portrait_path": "res://assets/Enemy/broken_string_tone_phantom.png",
		"hp": 74,
		"max_hp": 74,
		"mp": 0,
		"atk": 45,
		"def": 4,
		"speed": 15,
		"element": "剛",
		"exp": 15,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_broken_string_snapping_note", "category": "attack", "weight": 9, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_broken_string_wrong_beat", "category": "debuff", "weight": 3, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "yumei",
		"archetype": "語魅",
		"kind": "斷弦魅",
		"accuracy": 119,
		"evasion": 6,
		"crit_rate_bonus": 0.03
	},
	"turbid_tone_phantom": {
		"display_name": "濁語蝕靈",
		"portrait_path": "res://assets/Enemy/turbid_tone_phantom.png",
		"hp": 78,
		"max_hp": 78,
		"mp": 0,
		"atk": 40,
		"def": 6,
		"speed": 10,
		"element": "遲",
		"exp": 14,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_turbid_tone_murky_strike", "category": "attack", "weight": 10, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_turbid_tone_corroding_touch", "category": "debuff", "weight": 3, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "yumei",
		"archetype": "語魅",
		"kind": "濁語蝕靈",
		"accuracy": 118,
		"evasion": 4,
		"crit_rate_bonus": 0.01
	},
	"broken_talisman_tone_phantom": {
		"display_name": "漏咒靈",
		"portrait_path": "res://assets/Enemy/broken_talisman_tone_phantom.png",
		"hp": 80,
		"max_hp": 80,
		"mp": 0,
		"atk": 40,
		"def": 5,
		"speed": 11,
		"element": "柔",
		"exp": 16,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_broken_talisman_paper_cut", "category": "attack", "weight": 10, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_broken_talisman_residual_mark", "category": "debuff", "weight": 3, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_broken_talisman_leaking_curse", "category": "debuff", "weight": 2, "cd_turns": 3, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "yumei",
		"archetype": "語魅",
		"kind": "漏咒靈",
		"accuracy": 120,
		"evasion": 5,
		"crit_rate_bonus": 0.01
	},
	"bitterness_tone_phantom": {
		"display_name": "苦息藥魅",
		"portrait_path": "res://assets/Enemy/bitterness_tone_phantom.png",
		"hp": 84,
		"max_hp": 84,
		"mp": 0,
		"atk": 41,
		"def": 7,
		"speed": 8,
		"element": "遲",
		"exp": 16,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_bitterness_tone_medicine_dregs", "category": "attack", "weight": 10, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_bitterness_tone_bitter_breath", "category": "debuff", "weight": 3, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "yumei",
		"archetype": "語魅",
		"kind": "苦息藥魅",
		"accuracy": 115,
		"evasion": 2,
		"crit_rate_bonus": 0.01
	},
	"echo_tone_phantom": {
		"display_name": "回音魘",
		"portrait_path": "res://assets/Enemy/echo_tone_phantom.png",
		"hp": 96,
		"max_hp": 96,
		"mp": 0,
		"atk": 42,
		"def": 6,
		"speed": 12,
		"element": "柔",
		"exp": 19,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_echo_tone_returning_wave", "category": "attack", "weight": 10, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_echo_tone_misheard_answer", "category": "debuff", "weight": 2, "cd_turns": 4, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "yumei",
		"archetype": "語魅",
		"kind": "回音魘",
		"accuracy": 121,
		"evasion": 8,
		"crit_rate_bonus": 0.02
	},
	"fixation_tone_phantom": {
		"display_name": "縛願殘影",
		"portrait_path": "res://assets/Enemy/fixation_tone_phantom.png",
		"hp": 104,
		"max_hp": 104,
		"mp": 0,
		"atk": 43,
		"def": 9,
		"speed": 7,
		"element": "遲",
		"exp": 20,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_fixation_crushing_shadow", "category": "attack", "weight": 11, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_fixation_wish_bind", "category": "debuff", "weight": 2, "cd_turns": 3, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_fixation_heavy_resentment", "category": "debuff", "weight": 2, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"family": "yumei",
		"archetype": "語魅",
		"kind": "縛願殘影",
		"accuracy": 114,
		"evasion": 1,
		"crit_rate_bonus": 0.01
	},
	"molin_yanjiang": {
		"display_name": "墨鱗魘將",
		"portrait_path": "res://assets/Enemy/molingyanjiang_phase1.png",
		"hp": 560,
		"max_hp": 560,
		"mp": 0,
		"atk": 38,
		"def": 10,
		"speed": 16,
		"accuracy": 115,
		"evasion": 10,
		"element": "遲",
		"weapon_1": "槍",
		"weapon_2": "",
		"exp": 0,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_molin_tail_sweep", "category": "attack", "weight": 4, "cd_turns": 4, "mp_cost": 0, "target": "enemy_all"},
			{"skill_id": "skill_molin_water_bullet", "category": "debuff", "weight": 10, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_molin_rusty_fork_thrust", "category": "attack", "weight": 9, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_molin_breaking_wave_fork", "category": "attack", "weight": 5, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"committed_intent": {
			"enabled": true,
			"skill_id": "skill_molin_deluge_burial",
			"intent_weight": 1,
			"weight_pool": 6,
			"cooldown_turns": 6,
			"tone_event": "deluge_tell",
			"modifiers": [],
			"pity": {"enabled": false, "start_after_failures": 0, "weight_per_failure": 0}
		},
		"attribute_switch_intent": {
			"enabled": true,
			"minimum_dwell_actions": 2,
			"base_chance": 0.0,
			"chance_curve": [
				{"action_count": 3, "chance": 0.25},
				{"action_count": 4, "chance": 0.40},
				{"action_count": 5, "chance": 0.60},
				{"action_count": 6, "chance": 1.00}
			],
			"switches_by_element": {
				"遲": {"skill_id": "skill_molin_reverse_scale_iron_stance", "target_element": "剛"},
				"剛": {"skill_id": "skill_molin_sunken_tide_breath", "target_element": "遲"}
			},
			"modifiers": [
				{"self_hp_pct_lte": 0.70, "chance_add": 0.05},
				{"self_hp_pct_lte": 0.35, "chance_add": 0.05}
			]
		},
		"family": "animal",
		"archetype": "爬蟲",
		"species": "reptile",
		"tone_profile": "molin_yanjiang"
	},
	"molin_yanjiang_phase2": {
		"display_name": "墨鱗魘將",
		"portrait_path": "res://assets/Enemy/molingyanjiang_phase2.png",
		"hp": 720,
		"max_hp": 720,
		"mp": 0,
		"atk": 44,
		"def": 13,
		"speed": 18,
		"accuracy": 118,
		"evasion": 10,
		"element": "剛",
		"weapon_1": "槍",
		"weapon_2": "",
		"exp": 0,
		"gold": {"chance": 1.0, "min": 500, "max": 500},
		"drops": [
			{"id": "wep_yanjiang_fishbone_spear", "chance": 1.0, "min": 1, "max": 1},
		],
		"ai_profile": "default",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_molin_tail_sweep", "category": "attack", "weight": 4, "cd_turns": 4, "mp_cost": 0, "target": "enemy_all"},
			{"skill_id": "skill_molin_water_bullet", "category": "debuff", "weight": 10, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_molin_rusty_fork_thrust", "category": "attack", "weight": 9, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_molin_breaking_wave_fork", "category": "attack", "weight": 5, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"committed_intent": {
			"enabled": true,
			"skill_id": "skill_molin_deluge_burial",
			"intent_weight": 1,
			"weight_pool": 6,
			"cooldown_turns": 6,
			"tone_event": "deluge_tell",
			"modifiers": [],
			"pity": {"enabled": false, "start_after_failures": 0, "weight_per_failure": 0}
		},
		"family": "animal",
		"archetype": "爬蟲",
		"species": "reptile",
		"tone_profile": "molin_yanjiang",
		"phase": 2,
		"balance_pending": true
	},
	"tea_house_guest_guard": {
		"display_name": "單步雷",
		"hp": 220,
		"max_hp": 220,
		"mp": 60,
		"atk": 24,
		"def": 16,
		"speed": 18,
		"element": "剛",
		"exp": 0,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "aggressive",
		"skills_mode": "cycle",
		"skills": [
			{"skill_id": "skill_enemy_stun_palm", "category": "debuff", "weight": 10, "cd_turns": 1, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_poison_fang", "category": "debuff", "weight": 10, "cd_turns": 1, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_confuse_shout", "category": "debuff", "weight": 10, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_weaken_strike", "category": "debuff", "weight": 10, "cd_turns": 1, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_break_def_strike", "category": "debuff", "weight": 10, "cd_turns": 1, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_weak_curse", "category": "debuff", "weight": 10, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_seal_acupoint", "category": "debuff", "weight": 10, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_blind_sand", "category": "debuff", "weight": 10, "cd_turns": 1, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_root_bind", "category": "debuff", "weight": 10, "cd_turns": 1, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_sparring_palm", "category": "attack", "weight": 8, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"}
		],
		"archetype": "江湖人士"
	},
	"yuheng_old_fighter": {
		"display_name": "演武老翁",
		"hp": 120,
		"max_hp": 120,
		"mp": 20,
		"atk": 20,
		"def": 8,
		"speed": 9,
		"element": "剛",
		"exp": 18,
		"gold": {"chance": 0.0, "min": 0, "max": 0},
		"drops": [],
		"ai_profile": "old_fighter_sparring",
		"skills_mode": "weighted",
		"skills": [
			{"skill_id": "skill_enemy_old_fighter_probe_palm", "category": "attack", "weight": 12, "cd_turns": 0, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_old_fighter_sweep_step", "category": "debuff", "weight": 5, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"},
			{"skill_id": "skill_enemy_old_fighter_stubborn_fist", "category": "attack", "weight": 8, "cd_turns": 2, "mp_cost": 0, "target": "enemy_single"}
		],
		"archetype": "江湖人士",
		"accuracy": 98,
		"evasion": 3,
		"crit_rate_bonus": 0.01
	}
}

static func get_def(id: String) -> Dictionary:
	if not ENEMY_DEFS.has(id):
		push_warning("Enemy def not found: %s" % id)
		return {}
	return _normalize_enemy_def(ENEMY_DEFS[id].duplicate(true))

static func make_enemy(id: String) -> Dictionary:
	var data: Dictionary = ENEMY_DEFS.get(id, {})
	if data.is_empty():
		push_warning("Enemy def not found: %s" % id)
		return {}
	var enemy := data.duplicate(true)
	enemy["id"] = id
	if not enemy.has("name"):
		enemy["name"] = enemy.get("display_name", id)
	if not enemy.has("display_name"):
		enemy["display_name"] = enemy.get("name")
	if enemy.has("hp") and not enemy.has("max_hp"):
		enemy["max_hp"] = enemy["hp"]
	if not enemy.has("exp"):
		enemy["exp"] = 0
	if not enemy.has("ai_profile"):
		enemy["ai_profile"] = "default"
	if not enemy.has("skills_mode"):
		enemy["skills_mode"] = "weighted"
	enemy = _normalize_enemy_def(enemy)
	enemy["gold"] = _normalize_gold(enemy.get("gold", {"chance": 0.0, "min": 0, "max": 0}))
	enemy["drops"] = _normalize_drops(enemy.get("drops", []))
	return enemy

static func _normalize_gold(gold_data) -> Dictionary:
	var gold: Dictionary = gold_data if typeof(gold_data) == TYPE_DICTIONARY else {}
	var chance = float(gold.get("chance", 0.0))
	if chance > 1.0:
		chance = chance / 100.0
	chance = clamp(chance, 0.0, 1.0)
	var min_gold = int(gold.get("min", 0))
	var max_gold = int(gold.get("max", 0))
	if min_gold > max_gold:
		var tmp = min_gold
		min_gold = max_gold
		max_gold = tmp
	return {"chance": chance, "min": min_gold, "max": max_gold}

static func _normalize_drops(drops_data) -> Array:
	var drops: Array = drops_data if typeof(drops_data) == TYPE_ARRAY else []
	var normalized: Array = []
	for entry in drops:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id = str(entry.get("id", ""))
		if id == "":
			continue
		var chance = float(entry.get("chance", 1.0))
		if chance > 1.0:
			chance = chance / 100.0
		chance = clamp(chance, 0.0, 1.0)
		var min_count = int(entry.get("min", entry.get("count", 1)))
		var max_count = int(entry.get("max", entry.get("count", 1)))
		if min_count > max_count:
			var tmp = min_count
			min_count = max_count
			max_count = tmp
		normalized.append({
			"id": id,
			"chance": chance,
			"min": min_count,
			"max": max_count
		})
	return normalized

static func _normalize_enemy_def(enemy: Dictionary) -> Dictionary:
	if typeof(enemy.get("skills", [])) != TYPE_ARRAY:
		enemy["skills"] = []
	if not enemy.has("family"):
		enemy["family"] = ""
	var raw_archetype := String(enemy.get("archetype", enemy.get("species", ""))).strip_edges()
	var normalized_archetype := resolve_archetype(raw_archetype)
	if normalized_archetype == "":
		normalized_archetype = "江湖人士"
	enemy["archetype"] = normalized_archetype
	if not enemy.has("species") or String(enemy.get("species", "")).strip_edges() == "":
		enemy["species"] = normalized_archetype
	return enemy

static func resolve_archetype(raw_archetype: String) -> String:
	var key := raw_archetype.strip_edges()
	if key == "":
		return "江湖人士"
	return String(ARCHETYPE_ALIASES.get(key, key)).strip_edges()
