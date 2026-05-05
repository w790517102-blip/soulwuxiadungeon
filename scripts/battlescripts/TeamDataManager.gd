# TeamDataManager.gd
# ✅ 負責管理所有角色資料與隊伍編組，用於戰鬥 / 地圖 / UI 等模組

extends Node

const InnerForceDBScript = preload("res://scripts/battlescripts/InnerForceDB.gd")
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
const CharacterDBScript = preload("res://scripts/db/CharacterDB.gd")
const JobDBScript = preload("res://scripts/db/JobDB.gd")
var _inner_force_db: Node = InnerForceDBScript.new()
var _skill_db: Node = SkillDBScript.new()
var _character_db: Node = CharacterDBScript.new()
var _job_db: Node = JobDBScript.new()
const LEVEL_BASE_HP_GAIN := 10
const LEVEL_BASE_MP_GAIN := 5
const LEVEL_ACCURACY_GAIN := 3
const LEVEL_EVASION_GAIN := 3
const LEVEL_MAIN_STAT_GAIN := 3

# === 所有可用角色（包含未上場） ===
var all_characters: Dictionary = {
	"liuyu": {
		"id": "liuyu",
		"name": "劉語塵",
		"hp": 150,
		"max_hp": 150,
		"mp": 60,
		"max_mp": 60,
		"atk": 20,
		"def": 5,
		"element": "快",
		"speed": 8,
		"weapon_1": "劍",
		"weapon_2": "",
		"defending": false,
		"defense_value": 0,
		"portrait_path": "res://assets/sprites/Liu_Yu/LiuYu_battle.png",
		"inner_force_id": "qingfeng_jue",
		"known_inner_force_ids": ["qingfeng_jue", "liuchen_jue", "wuji_zhenjing", "fuchao_jue", "tiancan_jue"],
		"inner_force_used_prefixes": [],
		"str": 5,
		"agi": 5,
		"int": 5,
		"con": 5,
		"luck": 5,
		"battle_modifiers": {},
	},
	"lieshao": {
		"id": "lieshao",
		"name": "列肖",
		"hp": 180,
		"max_hp": 180,
		"mp": 80,
		"max_mp": 80,
		"atk": 18,
		"def": 4,
		"element": "剛",
		"speed": 6,
		"weapon_1": "琴",
		"weapon_2": "刀",
		"defending": false,
		"defense_value": 0,
		"portrait_path": "res://assets/sprites/NPC/LieFong/LieShao_battle.png",
		"inner_force_id": "chi_yang_zhenjing",
		"known_inner_force_ids": ["chi_yang_zhenjing", "po_jun_zhenjing"],
		"inner_force_used_prefixes": [],
		"str": 5,
		"agi": 5,
		"int": 5,
		"con": 5,
		"luck": 5,
		"battle_modifiers": {},
	},
	"shumian": {
		"id": "shumian",
		"name": "書眠",
		"hp": 120,
		"max_hp": 120,
		"mp": 100,
		"max_mp": 100,
		"atk": 12,
		"def": 3,
		"element": "柔",
		"speed": 9,
		"weapon_1": "筆",
		"weapon_2": "拳",
		"defending": false,
		"defense_value": 0,
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Su_Mien_battle.png",
		"inner_force_id": "meng_ying_xinfa",
		"known_inner_force_ids": ["meng_ying_xinfa", "ling_feng_jue"],
		"inner_force_used_prefixes": [],
		"str": 5,
		"agi": 5,
		"int": 5,
		"con": 5,
		"luck": 5,
		"battle_modifiers": {},
	},
}

# === 目前出戰隊伍（用角色 ID 陣列） ===
var current_team_ids: Array = ["liuyu",]# "shumian", "lieshao"]
var known_skill_ids_by_actor: Dictionary = {
	"liuyu": ["skill_lianjuejian", "skill_badaozhan", "skill_duanshuizhan", "skill_diquejian", "skill_mujian_saoye", "skill_qiliaozhang", "skill_xianglong18", "skill_hawkeye_focus", "skill_zhengxinquan"],
	"shumian": ["skill_bisaoyanxia", "skill_luobichengshi", "skill_zhengxinquan", "skill_buff_speed_test", "skill_qihui_talisman", "skill_jufu_talisman", "skill_debuff_speed_test", "skill_force_element_test", "skill_smoky_ink_blind", "skill_hawkeye_focus", "skill_mobishuxin", "skill_inkveil_swiftroute"],
	"lieshao": ["skill_liedaoposhi", "skill_luanyinsuiqin", "skill_huagu_mianzhang", "skill_huanbu_zhang", "skill_liumai_shenjian", "skill_bagua_gunfa", "skill_binding_shadow", "skill_hawkeye_focus", "skill_qin_resonant_focus"],
}

func _ready() -> void:
	_normalize_all_characters()
	_normalize_known_skills()

# === 回傳目前出戰角色完整資料（用 ID 反查） ===
func get_active_party() -> Array:
	var party: Array = []
	for id in current_team_ids:
		if all_characters.has(id):
			var actor: Dictionary = all_characters[id]
			_normalize_character(actor)
			party.append(actor)
		else:
			push_warning("❗ 找不到角色 ID：%s" % id)
	return party

# === 設定目前出戰隊伍（給 BattleController 的 fallback 用） ===
func set_active_party(party: Array) -> void:
	current_team_ids.clear()

	for member in party:
		if typeof(member) != TYPE_DICTIONARY:
			continue

		var id: String = String(member.get("id", ""))
		if id == "":
			continue

		current_team_ids.append(id)

		if all_characters.has(id):
			var base: Dictionary = all_characters[id]
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

			base["inner_force_id"] = member.get("inner_force_id", base.get("inner_force_id", ""))
			base["known_inner_force_ids"] = member.get("known_inner_force_ids", base.get("known_inner_force_ids", []))

			if typeof(member.get("inner_force", null)) == TYPE_DICTIONARY:
				var legacy_force_id = _inner_force_db.resolve_legacy_force_id(member.get("inner_force", {}))
				if legacy_force_id != "":
					base["inner_force_id"] = legacy_force_id

			if typeof(member.get("available_inner_forces", null)) == TYPE_ARRAY:
				var legacy_known := _resolve_known_force_ids_from_legacy(id, member.get("available_inner_forces", []))
				if not legacy_known.is_empty():
					base["known_inner_force_ids"] = legacy_known

			_normalize_character(base)
			all_characters[id] = base
		else:
			var created: Dictionary = member.duplicate(true)
			_normalize_character(created)
			all_characters[id] = created

func get_character_by_id(id: String) -> Dictionary:
	if not all_characters.has(id):
		return {}
	var actor: Dictionary = all_characters[id]
	_normalize_character(actor)
	return actor

func add_perm_stat(actor_id: String, stat_key: String, delta: int) -> bool:
	if delta == 0:
		return false
	if not all_characters.has(actor_id):
		return false
	var key := String(stat_key).to_lower()
	if not ["str", "agi", "int", "con", "luck"].has(key):
		return false
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	actor[key] = int(actor.get(key, 0)) + delta
	all_characters[actor_id] = actor
	return true

func add_next_battle_modifier(actor_id: String, mod_key: String, value: float) -> bool:
	if actor_id == "" or mod_key == "" or value == 0.0:
		return false
	if not all_characters.has(actor_id):
		return false
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	var mods: Dictionary = actor.get("battle_modifiers", {})
	if typeof(mods) != TYPE_DICTIONARY:
		mods = {}
	mods[mod_key] = float(mods.get(mod_key, 0.0)) + value
	actor["battle_modifiers"] = mods
	all_characters[actor_id] = actor
	return true

func clear_next_battle_modifiers(actor_id: String) -> void:
	if actor_id == "" or not all_characters.has(actor_id):
		return
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	actor["battle_modifiers"] = {}
	all_characters[actor_id] = actor

func get_known_skill_ids(actor_id: String) -> Array:
	if not known_skill_ids_by_actor.has(actor_id):
		known_skill_ids_by_actor[actor_id] = _get_default_skill_ids_for_actor(actor_id)
	var ids = known_skill_ids_by_actor.get(actor_id, [])
	if typeof(ids) != TYPE_ARRAY:
		return []
	return (ids as Array).duplicate()

func knows_skill(actor_id: String, skill_id: String) -> bool:
	return get_known_skill_ids(actor_id).has(skill_id)

func learn_skill(actor_id: String, skill_id: String) -> void:
	var canonical_id = _skill_db.coerce_skill_id(skill_id)
	if canonical_id == "":
		return
	if not _skill_db.is_available_for_actor(canonical_id, actor_id):
		return
	var ids = get_known_skill_ids(actor_id)
	if ids.has(canonical_id):
		return
	ids.append(canonical_id)
	known_skill_ids_by_actor[actor_id] = ids

func get_current_inner_force_id(actor_id: String) -> String:
	if not all_characters.has(actor_id):
		return ""
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	return String(actor.get("inner_force_id", ""))

func get_known_inner_forces(actor_id: String) -> Array:
	if not all_characters.has(actor_id):
		return []
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	return _inner_force_db.get_forces_for_actor(actor_id, actor.get("known_inner_force_ids", []))

func set_inner_force(actor_id: String, force_id: String) -> bool:
	if not all_characters.has(actor_id):
		return false
	if not _inner_force_db.is_available_to_actor(force_id, actor_id):
		return false

	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	var known_ids: Array = actor.get("known_inner_force_ids", [])
	if not known_ids.has(force_id):
		return false

	actor["inner_force_id"] = force_id
	_apply_inner_force_to_actor(actor)
	all_characters[actor_id] = actor
	_sync_inner_force_to_global_state(actor_id, force_id)
	return true

func learn_inner_force(actor_id: String, force_id: String) -> bool:
	if actor_id == "" or force_id == "":
		return false
	if not all_characters.has(actor_id):
		return false
	if not _inner_force_db.is_available_to_actor(force_id, actor_id):
		return false
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	var known_ids: Array = actor.get("known_inner_force_ids", [])
	if known_ids.has(force_id):
		return false
	known_ids.append(force_id)
	actor["known_inner_force_ids"] = known_ids
	all_characters[actor_id] = actor
	return true

func export_team_state() -> Dictionary:
	var out := {
		"current_team_ids": current_team_ids.duplicate(),
		"known_skill_ids_by_actor": known_skill_ids_by_actor.duplicate(true),
		"all_characters": {},
	}
	var chars: Dictionary = out["all_characters"]
	for actor_id in all_characters.keys():
		var actor: Dictionary = all_characters[actor_id]
		_normalize_character(actor)
		chars[String(actor_id)] = {
			"hp": actor.get("hp", 0),
			"max_hp": actor.get("max_hp", 0),
			"mp": actor.get("mp", 0),
			"max_mp": actor.get("max_mp", 0),
			"inner_force_id": actor.get("inner_force_id", ""),
			"known_inner_force_ids": (actor.get("known_inner_force_ids", []) as Array).duplicate(),
			"str": actor.get("str", 5),
			"agi": actor.get("agi", 5),
			"int": actor.get("int", 5),
			"con": actor.get("con", 5),
			"luck": actor.get("luck", 5),
			"level": actor.get("level", 1),
			"exp": actor.get("exp", 0),
			"stat_cycle_index": actor.get("stat_cycle_index", 0),
			"battle_modifiers": (actor.get("battle_modifiers", {}) as Dictionary).duplicate(true),
			}
	return out

func import_team_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	if typeof(data.get("current_team_ids", null)) == TYPE_ARRAY:
		current_team_ids = (data.get("current_team_ids", []) as Array).duplicate()
	if typeof(data.get("known_skill_ids_by_actor", null)) == TYPE_DICTIONARY:
		known_skill_ids_by_actor = (data.get("known_skill_ids_by_actor", {}) as Dictionary).duplicate(true)
	var chars = data.get("all_characters", {})
	if typeof(chars) == TYPE_DICTIONARY:
		for actor_id in chars.keys():
			if not all_characters.has(actor_id):
				continue
			var patch = chars[actor_id]
			if typeof(patch) != TYPE_DICTIONARY:
				continue
			var actor: Dictionary = all_characters[actor_id]
			actor["hp"] = patch.get("hp", actor.get("hp", 0))
			actor["max_hp"] = patch.get("max_hp", actor.get("max_hp", actor.get("hp", 0)))
			actor["mp"] = patch.get("mp", actor.get("mp", 0))
			actor["max_mp"] = patch.get("max_mp", actor.get("max_mp", actor.get("mp", 0)))
			actor["inner_force_id"] = patch.get("inner_force_id", actor.get("inner_force_id", ""))
			actor["str"] = patch.get("str", actor.get("str", 5))
			actor["agi"] = patch.get("agi", actor.get("agi", 5))
			actor["int"] = patch.get("int", actor.get("int", 5))
			actor["con"] = patch.get("con", actor.get("con", 5))
			actor["luck"] = patch.get("luck", actor.get("luck", 5))
			actor["level"] = patch.get("level", actor.get("level", 1))
			actor["exp"] = patch.get("exp", actor.get("exp", 0))
			actor["stat_cycle_index"] = patch.get("stat_cycle_index", actor.get("stat_cycle_index", 0))
			if typeof(patch.get("battle_modifiers", null)) == TYPE_DICTIONARY:
				actor["battle_modifiers"] = (patch.get("battle_modifiers", {}) as Dictionary).duplicate(true)
			if typeof(patch.get("known_inner_force_ids", null)) == TYPE_ARRAY:
				actor["known_inner_force_ids"] = patch.get("known_inner_force_ids", []).duplicate()
			_normalize_character(actor)
			all_characters[actor_id] = actor
	_normalize_all_characters()
	_normalize_known_skills()

func _normalize_known_skills() -> void:
	for actor_id in all_characters.keys():
		var ids: Array = []
		if known_skill_ids_by_actor.has(actor_id):
			var from_map = known_skill_ids_by_actor[actor_id]
			if typeof(from_map) == TYPE_ARRAY:
				ids = (from_map as Array).duplicate()
		if ids.is_empty():
			ids = _get_default_skill_ids_for_actor(String(actor_id))
		var normalized: Array = []
		for raw_id in ids:
			var skill_id = _skill_db.coerce_skill_id(raw_id)
			if skill_id == "" or normalized.has(skill_id):
				continue
			if not _skill_db.is_available_for_actor(skill_id, String(actor_id)):
				continue
			normalized.append(skill_id)
		if normalized.is_empty():
			normalized = _get_default_skill_ids_for_actor(String(actor_id))
		known_skill_ids_by_actor[String(actor_id)] = normalized

func _get_default_skill_ids_for_actor(actor_id: String) -> Array:
	var out: Array = []
	for raw_id in _skill_db.get_default_skill_ids(actor_id):
		var skill_id = _skill_db.coerce_skill_id(raw_id)
		if skill_id == "" or out.has(skill_id):
			continue
		if _skill_db.is_available_for_actor(skill_id, actor_id):
			out.append(skill_id)

	for skill in _skill_db.get_all_skills():
		if typeof(skill) != TYPE_DICTIONARY:
			continue
		var weapon_type := String(skill.get("weapon_type", ""))
		if weapon_type != "":
			continue
		var skill_id := String(skill.get("id", ""))
		if skill_id == "" or out.has(skill_id):
			continue
		if _skill_db.is_available_for_actor(skill_id, actor_id):
			out.append(skill_id)

	return out

func _normalize_all_characters() -> void:
	for actor_id in all_characters.keys():
		var actor: Dictionary = all_characters[actor_id]
		_normalize_character(actor)
		all_characters[actor_id] = actor

func _normalize_character(actor: Dictionary) -> void:
	var actor_id := String(actor.get("id", ""))
	if actor_id == "":
		return

	var known_ids: Array = []
	if typeof(actor.get("known_inner_force_ids", null)) == TYPE_ARRAY:
		known_ids = (actor.get("known_inner_force_ids", []) as Array).duplicate()
	elif typeof(actor.get("available_inner_forces", null)) == TYPE_ARRAY:
		known_ids = _resolve_known_force_ids_from_legacy(actor_id, actor.get("available_inner_forces", []))

	if known_ids.is_empty() and typeof(actor.get("inner_force", null)) == TYPE_DICTIONARY:
		var legacy_id = _inner_force_db.resolve_legacy_force_id(actor.get("inner_force", {}))
		if legacy_id != "":
			known_ids.append(legacy_id)

	if known_ids.is_empty():
		known_ids = _default_known_force_ids(actor_id)

	var unique_known: Array = []
	for force_id in known_ids:
		var id := String(force_id)
		if id == "" or unique_known.has(id):
			continue
		if _inner_force_db.is_available_to_actor(id, actor_id):
			unique_known.append(id)
	actor["known_inner_force_ids"] = unique_known

	var inner_force_id := String(actor.get("inner_force_id", ""))
	if inner_force_id == "" and typeof(actor.get("inner_force", null)) == TYPE_DICTIONARY:
		inner_force_id = _inner_force_db.resolve_legacy_force_id(actor.get("inner_force", {}))
	if inner_force_id == "" or not unique_known.has(inner_force_id):
		if unique_known.is_empty():
			inner_force_id = ""
		else:
			inner_force_id = String(unique_known[0])
	actor["inner_force_id"] = inner_force_id
	if _character_db != null and _character_db.has_method("ensure_actor_stats"):
		actor = _character_db.ensure_actor_stats(actor_id, actor)
	else:
		actor["str"] = int(actor.get("str", 5))
		actor["agi"] = int(actor.get("agi", 5))
		actor["int"] = int(actor.get("int", 5))
		actor["con"] = int(actor.get("con", 5))
		actor["luck"] = int(actor.get("luck", 5))
		if not actor.has("job"):
			actor["job"] = ""
		if not actor.has("subclass"):
			actor["subclass"] = ""
		if not actor.has("battle_modifiers") or typeof(actor.get("battle_modifiers", {})) != TYPE_DICTIONARY:
			actor["battle_modifiers"] = {}

	actor["level"] = max(int(actor.get("level", 1)), 1)
	actor["exp"] = max(int(actor.get("exp", 0)), 0)
	actor["stat_cycle_index"] = max(int(actor.get("stat_cycle_index", 0)), 0)

	_apply_inner_force_to_actor(actor)


func exp_required(_level: int) -> int:
	return 50


func add_exp_to_active_party(exp_gain: int) -> Array:
	var level_events: Array = []
	if exp_gain <= 0:
		return level_events
	for actor_id in current_team_ids:
		if not all_characters.has(actor_id):
			continue
		var actor: Dictionary = all_characters[actor_id]
		_normalize_character(actor)
		level_events.append_array(_apply_exp_to_actor(actor, exp_gain))
		all_characters[actor_id] = actor
	return level_events


func _apply_exp_to_actor(actor: Dictionary, exp_gain: int) -> Array:
	var events: Array = []
	actor["exp"] = int(actor.get("exp", 0)) + exp_gain
	while int(actor.get("exp", 0)) >= exp_required(int(actor.get("level", 1))):
		var req = exp_required(int(actor.get("level", 1)))
		actor["exp"] = int(actor.get("exp", 0)) - req
		events.append(_level_up_actor(actor))
	return events


func _level_up_actor(actor: Dictionary) -> Dictionary:
	var job_name = String(actor.get("job", ""))
	var job_def: Dictionary = {}
	if _job_db != null and _job_db.has_method("get_job_def"):
		job_def = _job_db.get_job_def(job_name)

	var hp_gain = LEVEL_BASE_HP_GAIN
	var mp_gain = LEVEL_BASE_MP_GAIN
	var atk_gain = int(job_def.get("atk_per_level", 1))
	var def_gain = int(job_def.get("def_per_level", 1))

	actor["level"] = int(actor.get("level", 1)) + 1
	actor["max_hp"] = int(actor.get("max_hp", actor.get("hp", 0))) + hp_gain
	actor["max_mp"] = int(actor.get("max_mp", actor.get("mp", 0))) + mp_gain
	actor["atk"] = int(actor.get("atk", 0)) + atk_gain
	actor["def"] = int(actor.get("def", 0)) + def_gain
	actor["accuracy"] = int(actor.get("accuracy", 100)) + LEVEL_ACCURACY_GAIN
	actor["evasion"] = int(actor.get("evasion", 0)) + LEVEL_EVASION_GAIN
	actor["hp"] = min(int(actor.get("hp", 0)) + hp_gain, int(actor.get("max_hp", 0)))
	actor["mp"] = min(int(actor.get("mp", 0)) + mp_gain, int(actor.get("max_mp", 0)))

	var stat_cycle: Array = []
	if typeof(job_def.get("stat_cycle", null)) == TYPE_ARRAY:
		stat_cycle = (job_def.get("stat_cycle", []) as Array)
	if stat_cycle.is_empty():
		stat_cycle = ["str", "agi", "int", "con", "luck"]

	var cycle_index = int(actor.get("stat_cycle_index", 0))
	var stat_key = String(stat_cycle[cycle_index % stat_cycle.size()])
	actor["stat_cycle_index"] = cycle_index + 1
	actor[stat_key] = int(actor.get(stat_key, 0)) + LEVEL_MAIN_STAT_GAIN

	var stat_to_atk: Dictionary = {}
	if typeof(job_def.get("stat_to_atk", null)) == TYPE_DICTIONARY:
		stat_to_atk = job_def.get("stat_to_atk", {})
	actor["atk"] = int(actor.get("atk", 0)) + int(stat_to_atk.get(stat_key, 0))

	actor["hp"] = min(int(actor.get("hp", 0)), int(actor.get("max_hp", 0)))
	actor["mp"] = min(int(actor.get("mp", 0)), int(actor.get("max_mp", 0)))

	return {
		"actor_id": String(actor.get("id", "")),
		"name": String(actor.get("name", "")),
		"level": int(actor.get("level", 1)),
		"stat_key": stat_key,
		"hp_gain": hp_gain,
		"mp_gain": mp_gain,
		"atk_gain": atk_gain,
		"def_gain": def_gain,
	}

func _apply_inner_force_to_actor(actor: Dictionary) -> void:
	var actor_id := String(actor.get("id", ""))
	var force_id := String(actor.get("inner_force_id", ""))
	var force = _inner_force_db.get_force(force_id)
	if force.is_empty() and not _default_known_force_ids(actor_id).is_empty():
		force_id = String(_default_known_force_ids(actor_id)[0])
		actor["inner_force_id"] = force_id
		force = _inner_force_db.get_force(force_id)
	actor["inner_force"] = force
	actor["available_inner_forces"] = _inner_force_db.get_forces_for_actor(actor_id, actor.get("known_inner_force_ids", []))
	if force.has("element"):
		actor["element"] = force["element"]

func _resolve_known_force_ids_from_legacy(actor_id: String, legacy_forces: Array) -> Array:
	var out: Array = []
	for force in legacy_forces:
		if typeof(force) != TYPE_DICTIONARY:
			continue
		var force_id = _inner_force_db.resolve_legacy_force_id(force)
		if force_id == "":
			continue
		if out.has(force_id):
			continue
		if _inner_force_db.is_available_to_actor(force_id, actor_id):
			out.append(force_id)
	return out

func _default_known_force_ids(actor_id: String) -> Array:
	match actor_id:
		"liuyu":
			return ["qingfeng_jue", "liuchen_jue", "wuji_zhenjing", "fuchao_jue"]
		"lieshao":
			return ["chi_yang_zhenjing", "po_jun_zhenjing"]
		"shumian":
			return ["meng_ying_xinfa", "ling_feng_jue"]
		_:
			return []

func _sync_inner_force_to_global_state(actor_id: String, force_id: String) -> void:
	if GlobalState == null:
		return
	var mapping = GlobalState.get_meta("inner_force_ids", {})
	if typeof(mapping) != TYPE_DICTIONARY:
		mapping = {}
	mapping[actor_id] = force_id
	GlobalState.set_meta("inner_force_ids", mapping)
