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
const MAIN_STAT_KEYS := ["str", "agi", "int", "con", "luck"]
const BASE_DERIVED_KEYS := ["max_hp", "max_mp", "atk", "def", "speed", "accuracy", "evasion"]
const ACTOR_ID_ALIASES := {
	"su_mien": "shumian",
}
## 劉語塵 learns these at level 1; older saves are topped up in _normalize_known_skills.
const LIUYU_INNATE_SKILL_IDS := ["skill_bajian_chishao", "skill_shaojian_lianji", "skill_shouqiao_beibei"]
const YUHENG_SHUMIAN_STORY_PROFILE_ID := "yuheng_shumian_lv6"
const SHUMIAN_INITIAL_LEVEL := 6
const SHUMIAN_INITIAL_SKILL_IDS := [
	"skill_luobichengshi",
	"skill_mobishuxin",
	"skill_smoky_ink_blind",
	"skill_linfu_humai",
	"skill_zhengxinquan",
	"skill_substitute_talisman",
]

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
		"weapon_aptitudes": ["刀", "劍", "棍", "槍", "拳", "掌", "琴", "筆", "通用"],
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
		"name": "列霄",
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
		"weapon_aptitudes": ["琴", "刀", "拳", "掌", "通用"],
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
		"name": "白書眠",
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
		"weapon_aptitudes": ["筆", "拳", "掌", "通用"],
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
var roster_unlocked_actor_ids: Array = ["liuyu"]
var known_skill_ids_by_actor: Dictionary = {
	"liuyu": ["skill_lianjuejian", "skill_badaozhan", "skill_duanshuizhan", "skill_diquejian", "skill_mujian_saoye", "skill_qiliaozhang", "skill_xianglong18", "skill_hawkeye_focus", "skill_zhengxinquan", "skill_bajian_chishao", "skill_shaojian_lianji", "skill_shouqiao_beibei"],
	"shumian": SHUMIAN_INITIAL_SKILL_IDS.duplicate(),
	"lieshao": ["skill_liedaoposhi", "skill_luanyinsuiqin", "skill_huagu_mianzhang", "skill_huanbu_zhang", "skill_liumai_shenjian", "skill_bagua_gunfa", "skill_binding_shadow", "skill_hawkeye_focus", "skill_qin_resonant_focus"],
}
var acquired_skill_manual_ids: Array = []
var acquired_inner_force_manual_ids: Array = []
var _refreshing_liuyu_insights: bool = false
var _initial_team_state: Dictionary = {}
var _initial_story_battle_cards: Dictionary = {}
var _initial_story_battle_skill_ids: Dictionary = {}

func _ready() -> void:
	_initialize_canonical_character_states_once()
	_normalize_all_characters()
	_normalize_roster_unlocks()
	_normalize_current_team_ids()
	_normalize_known_skills()
	_normalize_manual_knowledge()
	_refresh_all_natural_skill_learning()
	refresh_liuyu_companion_insights()
	_initial_team_state = export_team_state().duplicate(true)
	# Keep a full, read-only-in-practice copy of the authored initial cards before
	# any save slot can overlay long-term progression.  Special story battles can
	# request this snapshot without mutating TeamData's canonical progression.
	_initial_story_battle_cards = all_characters.duplicate(true)
	_initial_story_battle_skill_ids = known_skill_ids_by_actor.duplicate(true)

func canonicalize_actor_id(actor_id: String) -> String:
	return String(ACTOR_ID_ALIASES.get(actor_id, actor_id))

func character_exists(actor_id: String) -> bool:
	return all_characters.has(canonicalize_actor_id(actor_id))

func is_roster_unlocked(actor_id: String) -> bool:
	return roster_unlocked_actor_ids.has(canonicalize_actor_id(actor_id))

func unlock_roster(actor_id: String) -> bool:
	var canonical_id := canonicalize_actor_id(actor_id)
	if canonical_id == "" or not all_characters.has(canonical_id):
		return false
	if roster_unlocked_actor_ids.has(canonical_id):
		return false
	roster_unlocked_actor_ids.append(canonical_id)
	refresh_liuyu_companion_insights()
	return true

## 書眠正式入隊（飲月山莊的支線同意，或啟程時自動入隊）時呼叫：確保她是玉衡鎮序章的正式 Lv6。
## 新遊戲的書眠本來就是 Lv6（_initialize_canonical_character_states_once）；但舊存檔裡的書眠卡片（Lv1 時代留下的
## 進度，例如 Lv2）會在讀檔時蓋掉它。這裡只「補到 Lv6」，不會降級，也不會重複套用：
##  - 等級已經 >= 6：什麼都不做（包含已經超過 6 級的書眠，以及已經修正過的書眠）。
##  - 等級 < 6：走正式的升級管線（_level_up_actor）一級一級升到 6，能力值、HP／MP 與劉語塵升級時同一套公式；
##    經驗值保留（玩家已經賺到的不扣），學武／內功只補齊缺的，不覆蓋。
## 回傳是否真的升了級。只動永久角色資料，不碰 Boss 戰的劇情戰鬥卡片（get_story_battle_party_for_actor_ids）。
func ensure_shumian_story_join_level() -> bool:
	var actor_id := "shumian"
	if not all_characters.has(actor_id):
		return false
	_initialize_canonical_character_states_once()
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	var changed := false
	if int(actor.get("level", 1)) < SHUMIAN_INITIAL_LEVEL:
		while int(actor.get("level", 1)) < SHUMIAN_INITIAL_LEVEL:
			_level_up_actor(actor)
		var next_exp_cap := exp_required(int(actor.get("level", 1))) - 1
		actor["exp"] = clampi(int(actor.get("exp", 0)), 0, next_exp_cap)
		all_characters[actor_id] = actor
		changed = true
	# 序章就該會的起始武學（只補缺的）
	var known := get_known_skill_ids(actor_id)
	for skill_id in SHUMIAN_INITIAL_SKILL_IDS:
		if not known.has(skill_id):
			if learn_skill(actor_id, String(skill_id), false):
				changed = true
	if changed:
		refresh_natural_skill_learning(actor_id)
		refresh_liuyu_companion_insights()
	return changed


func get_roster_unlocked_actor_ids() -> Array:
	return roster_unlocked_actor_ids.duplicate()

func get_reserve_actor_ids(active_ids: Array = []) -> Array:
	var source_active_ids: Array = current_team_ids if active_ids.is_empty() else active_ids
	var canonical_active := _canonicalize_actor_id_array(source_active_ids)
	var out: Array = []
	for actor_id_any in roster_unlocked_actor_ids:
		var actor_id := String(actor_id_any)
		if actor_id != "" and not canonical_active.has(actor_id):
			out.append(actor_id)
	return out

# === 回傳目前出戰角色完整資料（用 ID 反查） ===
func get_active_party() -> Array:
	return get_party_for_actor_ids(current_team_ids)


func get_party_for_actor_ids(actor_ids: Array) -> Array:
	var party: Array = []
	for raw_id in actor_ids:
		var id := canonicalize_actor_id(String(raw_id))
		if all_characters.has(id):
			var actor: Dictionary = all_characters[id]
			_normalize_character(actor)
			party.append(actor)
		else:
			push_warning("❗ 找不到角色 ID：%s" % id)
	return party


func get_story_battle_party_for_actor_ids(actor_ids: Array) -> Array:
	# Return authored story-time battle cards without changing canonical state.
	# The Yuheng stalactite encounter temporarily needs Shumian's approved initial
	# Lv6 card even when a loaded save contains later or legacy test progression.
	# Other party members continue to use their current canonical cards; only the
	# story-specific Shumian card is replaced by the captured initial snapshot.
	_ensure_story_battle_snapshot()
	var party: Array = []
	for raw_id in actor_ids:
		var id := canonicalize_actor_id(String(raw_id))
		if id == "":
			continue
		var actor: Dictionary = {}
		if id == "shumian" and _initial_story_battle_cards.has(id):
			actor = (_initial_story_battle_cards[id] as Dictionary).duplicate(true)
			var story_skill_ids_any = _initial_story_battle_skill_ids.get(id, [])
			if typeof(story_skill_ids_any) == TYPE_ARRAY:
				actor["battle_skill_ids"] = (story_skill_ids_any as Array).duplicate()
			else:
				actor["battle_skill_ids"] = []
			actor["story_battle_profile_id"] = YUHENG_SHUMIAN_STORY_PROFILE_ID
			# HP/MP are resources, not part of the story baseline. Carry the
			# current canonical resource values into this fresh profile; the battle
			# boundary will clamp them to the profile's reconstructed maxima.
			var current_actor: Dictionary = all_characters.get(id, {})
			if not current_actor.is_empty():
				actor["hp"] = int(current_actor.get("hp", actor.get("hp", 0)))
				actor["mp"] = int(current_actor.get("mp", actor.get("mp", 0)))
		elif all_characters.has(id):
			actor = (all_characters[id] as Dictionary).duplicate(true)
		else:
			push_warning("❗ 找不到角色 ID：%s" % id)
			continue
		party.append(actor)
	return party


func _ensure_story_battle_snapshot() -> void:
	if not _initial_story_battle_cards.is_empty():
		return
	_initialize_canonical_character_states_once()
	_normalize_all_characters()
	_normalize_known_skills()
	_initial_story_battle_cards = all_characters.duplicate(true)
	_initial_story_battle_skill_ids = known_skill_ids_by_actor.duplicate(true)

# === 設定目前出戰隊伍（給 BattleController 的 fallback 用） ===
func set_active_party(party: Array) -> void:
	current_team_ids.clear()

	for member in party:
		if typeof(member) != TYPE_DICTIONARY:
			continue

		var id: String = canonicalize_actor_id(String(member.get("id", "")))
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
			created["id"] = id
			_normalize_character(created)
			all_characters[id] = created
	_refresh_all_natural_skill_learning()
	refresh_liuyu_companion_insights()

func get_character_by_id(id: String) -> Dictionary:
	id = canonicalize_actor_id(id)
	if id == "shumian":
		_initialize_canonical_character_states_once()
	if not all_characters.has(id):
		return {}
	var actor: Dictionary = all_characters[id]
	_normalize_character(actor)
	return actor

func get_weapon_aptitudes(actor_id: String, actor_override: Dictionary = {}) -> Array:
	actor_id = canonicalize_actor_id(actor_id)
	var actor: Dictionary = actor_override
	if actor.is_empty() and all_characters.has(actor_id):
		actor = all_characters[actor_id]
	var raw_aptitudes = actor.get("weapon_aptitudes", _default_weapon_aptitudes(actor_id))
	if typeof(raw_aptitudes) != TYPE_ARRAY:
		return _default_weapon_aptitudes(actor_id)
	var out: Array = []
	for raw_type in raw_aptitudes:
		var weapon_type := String(raw_type)
		if weapon_type != "" and not out.has(weapon_type):
			out.append(weapon_type)
	return out

func has_weapon_aptitude(actor_id: String, weapon_type: String, actor_override: Dictionary = {}) -> bool:
	if weapon_type == "":
		return true
	return get_weapon_aptitudes(actor_id, actor_override).has(weapon_type)

func get_known_roster_actor_ids() -> Array:
	# Companion Insight sources are formal roster members. Temporary battle
	# actors may be active without becoming permanent knowledge sources.
	return get_roster_unlocked_actor_ids()

func add_perm_stat(actor_id: String, stat_key: String, delta: int) -> bool:
	actor_id = canonicalize_actor_id(actor_id)
	if delta == 0:
		return false
	if not all_characters.has(actor_id):
		return false
	var key := String(stat_key).to_lower()
	if not ["str", "agi", "int", "con", "luck"].has(key):
		return false
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	var base_key := "base_%s" % key
	if actor.has(base_key):
		actor[base_key] = int(actor.get(base_key, actor.get(key, 0))) + delta
	else:
		actor[key] = int(actor.get(key, 0)) + delta
	_normalize_character(actor)
	all_characters[actor_id] = actor
	return true

func add_next_battle_modifier(actor_id: String, mod_key: String, value: float) -> bool:
	actor_id = canonicalize_actor_id(actor_id)
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
	actor_id = canonicalize_actor_id(actor_id)
	if actor_id == "" or not all_characters.has(actor_id):
		return
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	actor["battle_modifiers"] = {}
	all_characters[actor_id] = actor

func get_known_skill_ids(actor_id: String) -> Array:
	actor_id = canonicalize_actor_id(actor_id)
	if actor_id == "shumian":
		_initialize_canonical_character_states_once()
	if not known_skill_ids_by_actor.has(actor_id):
		known_skill_ids_by_actor[actor_id] = _get_default_skill_ids_for_actor(actor_id)
	var ids = known_skill_ids_by_actor.get(actor_id, [])
	if typeof(ids) != TYPE_ARRAY:
		return []
	return (ids as Array).duplicate()

func knows_skill(actor_id: String, skill_id: String) -> bool:
	return get_known_skill_ids(actor_id).has(skill_id)

func learn_skill(actor_id: String, skill_id: String, refresh_companion_insights: bool = true) -> bool:
	actor_id = canonicalize_actor_id(actor_id)
	var canonical_id = _skill_db.coerce_skill_id(skill_id)
	if canonical_id == "":
		return false
	if not _skill_db.is_available_for_actor(canonical_id, actor_id):
		return false
	var skill: Dictionary = _skill_db.get_skill(canonical_id)
	if skill.is_empty() or not has_weapon_aptitude(actor_id, String(skill.get("weapon_type", ""))):
		return false
	var ids = get_known_skill_ids(actor_id)
	if ids.has(canonical_id):
		return false
	ids.append(canonical_id)
	known_skill_ids_by_actor[actor_id] = ids
	if refresh_companion_insights and actor_id != "liuyu" and not _refreshing_liuyu_insights:
		refresh_liuyu_companion_insights()
	return true

func refresh_natural_skill_learning(actor_id: String) -> Array:
	actor_id = canonicalize_actor_id(actor_id)
	var learned: Array = []
	if actor_id == "" or not all_characters.has(actor_id):
		return learned
	var actor: Dictionary = all_characters[actor_id]
	var actor_level: int = max(1, int(actor.get("level", 1)))
	for skill_any in _skill_db.get_all_skills():
		if typeof(skill_any) != TYPE_DICTIONARY:
			continue
		var skill: Dictionary = skill_any
		var skill_id := String(skill.get("id", ""))
		if skill_id == "" or knows_skill(actor_id, skill_id):
			continue
		if not _skill_db.is_available_for_actor(skill_id, actor_id):
			continue
		if not has_weapon_aptitude(actor_id, String(skill.get("weapon_type", "")), actor):
			continue
		for route_any in _skill_db.get_acquisition_routes(skill_id):
			if typeof(route_any) != TYPE_DICTIONARY:
				continue
			var route: Dictionary = route_any
			var route_type := String(route.get("type", ""))
			var route_level: int = max(1, int(route.get("required_level", skill.get("required_level", 1))))
			if actor_level < route_level:
				continue
			var route_matches: bool = false
			if route_type == SkillDBScript.ACQUISITION_ROUTE_WEAPON_FAMILY_LEVEL:
				var route_weapon: String = String(route.get("weapon_type", skill.get("weapon_type", "")))
				route_matches = has_weapon_aptitude(actor_id, route_weapon, actor)
			elif route_type == SkillDBScript.ACQUISITION_ROUTE_ACTOR_GROWTH:
				var route_actor_id := String(route.get("actor_id", ""))
				var route_actor_ids = route.get("actor_ids", [])
				route_matches = route_actor_id == actor_id or (
					typeof(route_actor_ids) == TYPE_ARRAY and (route_actor_ids as Array).has(actor_id)
				)
			# quest_event and manual are fulfilled by their existing explicit
			# learn_skill()/acquire_skill_manual() entry points.
			if not route_matches:
				continue
			if learn_skill(actor_id, skill_id, false):
				learned.append(skill_id)
			break
	return learned

func refresh_liuyu_companion_insights(extra_source_actor_ids: Array = []) -> Array:
	var learned: Array = []
	if _refreshing_liuyu_insights or not all_characters.has("liuyu"):
		return learned
	_refreshing_liuyu_insights = true
	var liuyu: Dictionary = all_characters["liuyu"]
	var liuyu_level: int = max(1, int(liuyu.get("level", 1)))
	var source_actor_ids := get_known_roster_actor_ids()
	for raw_source_id in extra_source_actor_ids:
		var extra_source_id := canonicalize_actor_id(String(raw_source_id))
		if character_exists(extra_source_id) and not source_actor_ids.has(extra_source_id):
			source_actor_ids.append(extra_source_id)
	for source_actor_id in source_actor_ids:
		if source_actor_id == "liuyu":
			continue
		for skill_id_any in get_known_skill_ids(String(source_actor_id)):
			var skill_id = _skill_db.coerce_skill_id(skill_id_any)
			if skill_id == "" or knows_skill("liuyu", skill_id):
				continue
			if not _skill_db.allows_companion_insight(skill_id):
				continue
			if not _skill_db.is_shareable(skill_id) or _skill_db.is_exclusive_skill(skill_id):
				continue
			if not _skill_db.is_available_for_actor(skill_id, String(source_actor_id)):
				continue
			if not _skill_db.is_available_for_actor(skill_id, "liuyu"):
				continue
			var skill: Dictionary = _skill_db.get_skill(skill_id)
			if skill.is_empty() or not has_weapon_aptitude("liuyu", String(skill.get("weapon_type", "")), liuyu):
				continue
			if liuyu_level < _skill_db.get_companion_insight_required_level(skill_id):
				continue
			if learn_skill("liuyu", skill_id, false):
				learned.append(skill_id)
	_refreshing_liuyu_insights = false
	return learned

func acquire_skill_manual(skill_id: String) -> bool:
	var canonical_id = _skill_db.coerce_skill_id(skill_id)
	if canonical_id == "" or acquired_skill_manual_ids.has(canonical_id):
		return false
	acquired_skill_manual_ids.append(canonical_id)
	return true

func has_skill_manual_knowledge(skill_id: String) -> bool:
	var canonical_id = _skill_db.coerce_skill_id(skill_id)
	return canonical_id != "" and acquired_skill_manual_ids.has(canonical_id)

func get_acquired_skill_manual_ids() -> Array:
	return acquired_skill_manual_ids.duplicate()

func get_current_inner_force_id(actor_id: String) -> String:
	actor_id = canonicalize_actor_id(actor_id)
	if not all_characters.has(actor_id):
		return ""
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	return String(actor.get("inner_force_id", ""))

func get_known_inner_forces(actor_id: String) -> Array:
	actor_id = canonicalize_actor_id(actor_id)
	if not all_characters.has(actor_id):
		return []
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	return _inner_force_db.get_forces_for_actor(actor_id, actor.get("known_inner_force_ids", []), actor)

func actor_has_effective_inner_force(actor_id: String, force_id: String, actor_override: Dictionary = {}) -> bool:
	actor_id = canonicalize_actor_id(actor_id)
	if actor_id == "" or force_id == "":
		return false
	var actor: Dictionary = actor_override
	if actor.is_empty() and all_characters.has(actor_id):
		actor = all_characters[actor_id]
	if not _inner_force_db.is_available_to_actor(force_id, actor_id, actor):
		return false
	var actor_level = max(1, int(actor.get("level", 1)))
	if not _inner_force_db.is_level_eligible(force_id, actor_level):
		return false
	var personal_ids: Array = []
	if typeof(actor.get("known_inner_force_ids", null)) == TYPE_ARRAY:
		personal_ids = actor.get("known_inner_force_ids", [])
	return personal_ids.has(force_id) or acquired_inner_force_manual_ids.has(force_id)

func get_effective_inner_forces(actor_id: String, actor_override: Dictionary = {}) -> Array:
	actor_id = canonicalize_actor_id(actor_id)
	var actor: Dictionary = actor_override
	if actor.is_empty() and all_characters.has(actor_id):
		actor = all_characters[actor_id]
	var out: Array = []
	for force_any in _inner_force_db.get_all_forces():
		if typeof(force_any) != TYPE_DICTIONARY:
			continue
		var force: Dictionary = force_any
		var force_id := String(force.get("id", ""))
		if actor_has_effective_inner_force(actor_id, force_id, actor):
			out.append(force)
	return out

func acquire_inner_force_manual(force_id: String) -> bool:
	if _inner_force_db.get_force(force_id).is_empty() or acquired_inner_force_manual_ids.has(force_id):
		return false
	acquired_inner_force_manual_ids.append(force_id)
	return true

func has_inner_force_manual_knowledge(force_id: String) -> bool:
	return not _inner_force_db.get_force(force_id).is_empty() and acquired_inner_force_manual_ids.has(force_id)

func get_acquired_inner_force_manual_ids() -> Array:
	return acquired_inner_force_manual_ids.duplicate()

func set_inner_force(actor_id: String, force_id: String) -> bool:
	actor_id = canonicalize_actor_id(actor_id)
	if not all_characters.has(actor_id):
		return false

	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	if not _inner_force_db.is_available_to_actor(force_id, actor_id, actor):
		return false
	if not actor_has_effective_inner_force(actor_id, force_id, actor):
		return false

	actor["inner_force_id"] = force_id
	_apply_inner_force_to_actor(actor)
	all_characters[actor_id] = actor
	_sync_inner_force_to_global_state(actor_id, force_id)
	return true

func learn_inner_force(actor_id: String, force_id: String) -> bool:
	actor_id = canonicalize_actor_id(actor_id)
	if actor_id == "" or force_id == "":
		return false
	if not all_characters.has(actor_id):
		return false
	var actor: Dictionary = all_characters[actor_id]
	_normalize_character(actor)
	if not _inner_force_db.is_available_to_actor(force_id, actor_id, actor):
		return false
	var known_ids: Array = actor.get("known_inner_force_ids", [])
	if known_ids.has(force_id):
		return false
	known_ids.append(force_id)
	actor["known_inner_force_ids"] = known_ids
	all_characters[actor_id] = actor
	return true

func export_team_state() -> Dictionary:
	_initialize_canonical_character_states_once()
	var out := {
		"current_team_ids": _canonicalize_actor_id_array(current_team_ids),
		"roster_unlocked_actor_ids": _canonicalize_actor_id_array(roster_unlocked_actor_ids),
		"known_skill_ids_by_actor": known_skill_ids_by_actor.duplicate(true),
		"acquired_skill_manual_ids": acquired_skill_manual_ids.duplicate(),
		"acquired_inner_force_manual_ids": acquired_inner_force_manual_ids.duplicate(),
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
		for key in MAIN_STAT_KEYS + BASE_DERIVED_KEYS:
			var base_key := "base_%s" % key
			if actor.has(base_key):
				chars[String(actor_id)][base_key] = actor.get(base_key)
	return out

func import_team_state(data: Dictionary) -> void:
	# Loading another slot must begin from the canonical initial card. This also
	# gives legacy/partial saves safe defaults for actors absent from their payload.
	reset_to_initial_team_state()
	# Older saves have no martial-knowledge fields; their safe default is empty.
	acquired_skill_manual_ids = []
	acquired_inner_force_manual_ids = []
	if data.is_empty():
		return
	if typeof(data.get("current_team_ids", null)) == TYPE_ARRAY:
		current_team_ids = _canonicalize_actor_id_array(data.get("current_team_ids", []))
	if typeof(data.get("roster_unlocked_actor_ids", null)) == TYPE_ARRAY:
		roster_unlocked_actor_ids = _canonicalize_actor_id_array(data.get("roster_unlocked_actor_ids", []))
	else:
		# Legacy saves predate formal roster unlocks. Character progression is
		# preserved below, but existing data alone must not expose future actors.
		roster_unlocked_actor_ids = ["liuyu"]
	if typeof(data.get("known_skill_ids_by_actor", null)) == TYPE_DICTIONARY:
		known_skill_ids_by_actor = _canonicalize_actor_keyed_dictionary(data.get("known_skill_ids_by_actor", {}))
	if typeof(data.get("acquired_skill_manual_ids", null)) == TYPE_ARRAY:
		acquired_skill_manual_ids = (data.get("acquired_skill_manual_ids", []) as Array).duplicate()
	if typeof(data.get("acquired_inner_force_manual_ids", null)) == TYPE_ARRAY:
		acquired_inner_force_manual_ids = (data.get("acquired_inner_force_manual_ids", []) as Array).duplicate()
	var chars = data.get("all_characters", {})
	if typeof(chars) == TYPE_DICTIONARY:
		var canonical_patches := _canonicalize_actor_keyed_dictionary(chars)
		for actor_id in canonical_patches.keys():
			if not all_characters.has(actor_id):
				continue
			var patch = canonical_patches[actor_id]
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
			for key in MAIN_STAT_KEYS + BASE_DERIVED_KEYS:
				var base_key := "base_%s" % key
				if patch.has(base_key):
					actor[base_key] = int(patch.get(base_key, actor.get(base_key, 0)))
			if actor_id == "shumian":
				actor["_canonical_initial_state_applied"] = true
			_normalize_character(actor)
			all_characters[actor_id] = actor
	_normalize_all_characters()
	_normalize_roster_unlocks()
	_normalize_current_team_ids()
	_normalize_known_skills()
	_normalize_manual_knowledge()
	_refresh_all_natural_skill_learning()
	refresh_liuyu_companion_insights()


func reset_to_initial_team_state() -> void:
	if _initial_team_state.is_empty():
		return
	var initial_characters = _initial_team_state.get("all_characters", {})
	if typeof(initial_characters) != TYPE_DICTIONARY:
		return
	# Rebuild from the script's actor cards first, then apply the captured initial
	# progression payload through the ordinary import-compatible shape below.
	current_team_ids = (_initial_team_state.get("current_team_ids", ["liuyu"]) as Array).duplicate()
	roster_unlocked_actor_ids = (_initial_team_state.get("roster_unlocked_actor_ids", ["liuyu"]) as Array).duplicate()
	known_skill_ids_by_actor = (_initial_team_state.get("known_skill_ids_by_actor", {}) as Dictionary).duplicate(true)
	acquired_skill_manual_ids = (_initial_team_state.get("acquired_skill_manual_ids", []) as Array).duplicate()
	acquired_inner_force_manual_ids = (_initial_team_state.get("acquired_inner_force_manual_ids", []) as Array).duplicate()
	for actor_id_any in initial_characters.keys():
		var actor_id := canonicalize_actor_id(String(actor_id_any))
		if not all_characters.has(actor_id):
			continue
		var patch: Dictionary = (initial_characters[actor_id_any] as Dictionary).duplicate(true)
		var actor: Dictionary = all_characters[actor_id]
		for key_any in patch.keys():
			actor[String(key_any)] = patch[key_any]
		if actor_id == "shumian":
			actor["_canonical_initial_state_applied"] = true
		_normalize_character(actor)
		all_characters[actor_id] = actor
	_normalize_roster_unlocks()
	_normalize_current_team_ids()
	_normalize_known_skills()
	_normalize_manual_knowledge()

func _initialize_canonical_character_states_once() -> void:
	var actor_id := "shumian"
	if not all_characters.has(actor_id):
		return
	var actor: Dictionary = all_characters[actor_id]
	if bool(actor.get("_canonical_initial_state_applied", false)):
		return

	# Build the canonical Lv6 card through the same permanent growth pipeline
	# used by ordinary level-ups. This is character progression data, not the
	# separate boss/special-battle card.
	actor["id"] = actor_id
	actor["level"] = 1
	actor["exp"] = 0
	actor["stat_cycle_index"] = 0
	actor["inner_force_id"] = "meng_ying_xinfa"
	actor["known_inner_force_ids"] = ["meng_ying_xinfa", "ling_feng_jue"]
	actor["weapon_1"] = "筆"
	actor["weapon_2"] = ""
	_normalize_character(actor)
	while int(actor.get("level", 1)) < SHUMIAN_INITIAL_LEVEL:
		_level_up_actor(actor)
	actor["exp"] = 0
	actor["hp"] = int(actor.get("max_hp", actor.get("hp", 1)))
	actor["mp"] = int(actor.get("max_mp", actor.get("mp", 0)))
	actor["_canonical_initial_state_applied"] = true
	all_characters[actor_id] = actor
	known_skill_ids_by_actor[actor_id] = SHUMIAN_INITIAL_SKILL_IDS.duplicate()

func _canonicalize_actor_id_array(raw_ids) -> Array:
	var out: Array = []
	if typeof(raw_ids) != TYPE_ARRAY:
		return out
	for raw_id in raw_ids:
		var actor_id := canonicalize_actor_id(String(raw_id))
		if actor_id != "" and not out.has(actor_id):
			out.append(actor_id)
	return out

func _canonicalize_actor_keyed_dictionary(raw_map) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_map) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = raw_map
	# Aliases are accepted for legacy data, while an explicit canonical entry
	# wins if both are present.
	for raw_id in source.keys():
		var actor_id := canonicalize_actor_id(String(raw_id))
		if actor_id == "" or out.has(actor_id):
			continue
		out[actor_id] = _duplicate_state_value(source[raw_id])
	for raw_id in source.keys():
		var actor_id := String(raw_id)
		if actor_id != canonicalize_actor_id(actor_id):
			continue
		out[actor_id] = _duplicate_state_value(source[raw_id])
	return out

func _duplicate_state_value(value):
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value

func _normalize_roster_unlocks() -> void:
	roster_unlocked_actor_ids = _canonicalize_actor_id_array(roster_unlocked_actor_ids)
	for i in range(roster_unlocked_actor_ids.size() - 1, -1, -1):
		if not all_characters.has(String(roster_unlocked_actor_ids[i])):
			roster_unlocked_actor_ids.remove_at(i)
	if all_characters.has("liuyu") and not roster_unlocked_actor_ids.has("liuyu"):
		roster_unlocked_actor_ids.push_front("liuyu")

func _normalize_current_team_ids() -> void:
	current_team_ids = _canonicalize_actor_id_array(current_team_ids)
	for i in range(current_team_ids.size() - 1, -1, -1):
		if not all_characters.has(String(current_team_ids[i])):
			current_team_ids.remove_at(i)

func _normalize_known_skills() -> void:
	known_skill_ids_by_actor = _canonicalize_actor_keyed_dictionary(known_skill_ids_by_actor)
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
		if String(actor_id) == "liuyu":
			for innate_id: String in LIUYU_INNATE_SKILL_IDS:
				if not normalized.has(innate_id):
					normalized.append(innate_id)
		if normalized.is_empty():
			normalized = _get_default_skill_ids_for_actor(String(actor_id))
		known_skill_ids_by_actor[String(actor_id)] = normalized

func _normalize_manual_knowledge() -> void:
	var normalized_skills: Array = []
	for raw_id in acquired_skill_manual_ids:
		var skill_id = _skill_db.coerce_skill_id(raw_id)
		if skill_id != "" and not normalized_skills.has(skill_id):
			normalized_skills.append(skill_id)
	acquired_skill_manual_ids = normalized_skills

	var normalized_forces: Array = []
	for raw_id in acquired_inner_force_manual_ids:
		var force_id := String(raw_id)
		if force_id != "" and not _inner_force_db.get_force(force_id).is_empty() and not normalized_forces.has(force_id):
			normalized_forces.append(force_id)
	acquired_inner_force_manual_ids = normalized_forces

func _refresh_all_natural_skill_learning() -> void:
	for actor_id in all_characters.keys():
		refresh_natural_skill_learning(String(actor_id))

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
	if all_characters.has("su_mien"):
		if not all_characters.has("shumian") and typeof(all_characters["su_mien"]) == TYPE_DICTIONARY:
			var migrated: Dictionary = (all_characters["su_mien"] as Dictionary).duplicate(true)
			migrated["id"] = "shumian"
			all_characters["shumian"] = migrated
		all_characters.erase("su_mien")
	for actor_id in all_characters.keys():
		var actor: Dictionary = all_characters[actor_id]
		_normalize_character(actor)
		all_characters[actor_id] = actor

func _normalize_character(actor: Dictionary) -> void:
	var actor_id := canonicalize_actor_id(String(actor.get("id", "")))
	if actor_id == "":
		return
	actor["id"] = actor_id
	var raw_aptitudes = actor.get("weapon_aptitudes", _default_weapon_aptitudes(actor_id))
	var normalized_aptitudes: Array = []
	if typeof(raw_aptitudes) == TYPE_ARRAY:
		for raw_type in raw_aptitudes:
			var weapon_type := String(raw_type)
			if weapon_type != "" and not normalized_aptitudes.has(weapon_type):
				normalized_aptitudes.append(weapon_type)
	if normalized_aptitudes.is_empty():
		normalized_aptitudes = _default_weapon_aptitudes(actor_id)
	actor["weapon_aptitudes"] = normalized_aptitudes

	var known_ids: Array = []
	if typeof(actor.get("known_inner_force_ids", null)) == TYPE_ARRAY:
		known_ids = (actor.get("known_inner_force_ids", []) as Array).duplicate()
	elif typeof(actor.get("available_inner_forces", null)) == TYPE_ARRAY:
		known_ids = _resolve_known_force_ids_from_legacy(actor_id, actor.get("available_inner_forces", []), actor)

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
		if _inner_force_db.is_available_to_actor(id, actor_id, actor):
			unique_known.append(id)
	actor["known_inner_force_ids"] = unique_known

	var inner_force_id := String(actor.get("inner_force_id", ""))
	if inner_force_id == "" and typeof(actor.get("inner_force", null)) == TYPE_DICTIONARY:
		inner_force_id = _inner_force_db.resolve_legacy_force_id(actor.get("inner_force", {}))
	if inner_force_id == "" or not actor_has_effective_inner_force(actor_id, inner_force_id, actor):
		var effective_forces := get_effective_inner_forces(actor_id, actor)
		if effective_forces.is_empty():
			inner_force_id = ""
		else:
			inner_force_id = String((effective_forces[0] as Dictionary).get("id", ""))
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
	var growth_result := add_exp_to_active_party_with_growth(exp_gain)
	var level_events = growth_result.get("level_events", [])
	return (level_events as Array) if typeof(level_events) == TYPE_ARRAY else []


func add_exp_to_active_party_with_growth(exp_gain: int) -> Dictionary:
	return add_exp_to_actor_ids_with_growth(exp_gain, current_team_ids)


func add_exp_to_actor_ids_with_growth(
	exp_gain: int,
	recipient_actor_ids: Array,
	extra_companion_insight_source_actor_ids: Array = []
) -> Dictionary:
	var growth_result := {
		"level_events": [],
		"level_ups": [],
		"skills_learned": [],
	}
	if exp_gain < 0:
		return growth_result
	var canonical_recipients := _canonicalize_actor_id_array(recipient_actor_ids)
	for actor_id in canonical_recipients:
		if not all_characters.has(actor_id):
			continue
		var actor: Dictionary = all_characters[actor_id]
		_normalize_character(actor)
		var old_level: int = int(actor.get("level", 1))
		if exp_gain > 0:
			(growth_result["level_events"] as Array).append_array(_apply_exp_to_actor(actor, exp_gain))
		all_characters[actor_id] = actor
		var new_level: int = int(actor.get("level", 1))
		if new_level > old_level:
			(growth_result["level_ups"] as Array).append({
				"actor_id": String(actor_id),
				"actor_name": String(actor.get("name", actor_id)),
				"old_level": old_level,
				"new_level": new_level,
			})
		for skill_id_any in refresh_natural_skill_learning(String(actor_id)):
			_append_growth_skill_event(
				growth_result["skills_learned"] as Array,
				String(actor_id),
				String(skill_id_any),
				"level_acquisition"
			)
	for skill_id_any in refresh_liuyu_companion_insights(extra_companion_insight_source_actor_ids):
		_append_growth_skill_event(
			growth_result["skills_learned"] as Array,
			"liuyu",
			String(skill_id_any),
			"companion_insight"
		)
	return growth_result


func _append_growth_skill_event(events: Array, actor_id: String, skill_id: String, source: String) -> void:
	if actor_id == "" or skill_id == "":
		return
	for event_any in events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any
		if String(event.get("actor_id", "")) == actor_id and String(event.get("skill_id", "")) == skill_id:
			return
	var actor_name := actor_id
	if all_characters.has(actor_id):
		actor_name = String((all_characters[actor_id] as Dictionary).get("name", actor_id))
	var skill: Dictionary = _skill_db.get_skill(skill_id)
	events.append({
		"actor_id": actor_id,
		"actor_name": actor_name,
		"skill_id": skill_id,
		"skill_name": String(skill.get("name", skill_id)),
		"source": source,
	})


func _apply_exp_to_actor(actor: Dictionary, exp_gain: int) -> Array:
	var events: Array = []
	actor["exp"] = int(actor.get("exp", 0)) + exp_gain
	while int(actor.get("exp", 0)) >= exp_required(int(actor.get("level", 1))):
		var req = exp_required(int(actor.get("level", 1)))
		actor["exp"] = int(actor.get("exp", 0)) - req
		events.append(_level_up_actor(actor))
	return events


func _level_up_actor(actor: Dictionary) -> Dictionary:
	_ensure_base_stat_snapshot(actor)
	var job_name = String(actor.get("job", ""))
	var job_def: Dictionary = {}
	if _job_db != null and _job_db.has_method("get_job_def"):
		job_def = _job_db.get_job_def(job_name)

	var hp_gain = int(job_def.get("hp_per_level", LEVEL_BASE_HP_GAIN))
	var mp_gain = int(job_def.get("mp_per_level", LEVEL_BASE_MP_GAIN))
	var atk_gain = int(job_def.get("atk_per_level", 1))
	var def_gain = int(job_def.get("def_per_level", 1))
	var hp_before = int(actor.get("hp", 0))
	var mp_before = int(actor.get("mp", 0))

	actor["level"] = int(actor.get("level", 1)) + 1
	_add_base_stat(actor, "max_hp", hp_gain)
	_add_base_stat(actor, "max_mp", mp_gain)
	_add_base_stat(actor, "atk", atk_gain)
	_add_base_stat(actor, "def", def_gain)
	_add_base_stat(actor, "accuracy", LEVEL_ACCURACY_GAIN)
	_add_base_stat(actor, "evasion", LEVEL_EVASION_GAIN)

	var stat_cycle: Array = []
	if typeof(job_def.get("stat_cycle", null)) == TYPE_ARRAY:
		stat_cycle = (job_def.get("stat_cycle", []) as Array)
	if stat_cycle.is_empty():
		stat_cycle = ["str", "agi", "int", "con", "luck"]

	var cycle_index = int(actor.get("stat_cycle_index", 0))
	var stat_key = String(stat_cycle[cycle_index % stat_cycle.size()])
	actor["stat_cycle_index"] = cycle_index + 1
	_add_base_stat(actor, stat_key, LEVEL_MAIN_STAT_GAIN)

	var stat_to_atk: Dictionary = {}
	if typeof(job_def.get("stat_to_atk", null)) == TYPE_DICTIONARY:
		stat_to_atk = job_def.get("stat_to_atk", {})
	var stat_atk_gain = int(stat_to_atk.get(stat_key, 0))
	_add_base_stat(actor, "atk", stat_atk_gain)

	_apply_inner_force_to_actor(actor)
	actor["hp"] = min(hp_before + hp_gain, int(actor.get("max_hp", 0)))
	actor["mp"] = min(mp_before + mp_gain, int(actor.get("max_mp", 0)))

	return {
		"actor_id": String(actor.get("id", "")),
		"name": String(actor.get("name", "")),
		"level": int(actor.get("level", 1)),
		"stat_key": stat_key,
		"hp_gain": hp_gain,
		"mp_gain": mp_gain,
		"atk_gain": atk_gain + stat_atk_gain,
		"def_gain": def_gain,
	}


func _add_base_stat(actor: Dictionary, stat_key: String, delta: int) -> void:
	if delta == 0:
		return
	var base_key := "base_%s" % stat_key
	actor[base_key] = int(actor.get(base_key, actor.get(stat_key, 0))) + delta
	actor[stat_key] = int(actor.get(base_key, actor.get(stat_key, 0)))


func _ensure_base_stat_snapshot(actor: Dictionary) -> void:
	for stat_key in MAIN_STAT_KEYS:
		var base_key := "base_%s" % stat_key
		if not actor.has(base_key):
			actor[base_key] = int(actor.get(stat_key, 5))
	for stat_key in BASE_DERIVED_KEYS:
		var base_key := "base_%s" % stat_key
		if not actor.has(base_key):
			var fallback = 100 if stat_key == "accuracy" else 0
			if stat_key == "max_hp":
				fallback = int(actor.get("hp", 1))
			elif stat_key == "max_mp":
				fallback = int(actor.get("mp", 0))
			actor[base_key] = int(actor.get(stat_key, fallback))


func _reset_actor_to_base_stats(actor: Dictionary) -> void:
	_ensure_base_stat_snapshot(actor)
	for stat_key in MAIN_STAT_KEYS:
		actor[stat_key] = int(actor.get("base_%s" % stat_key, actor.get(stat_key, 5)))
	for stat_key in BASE_DERIVED_KEYS:
		actor[stat_key] = int(actor.get("base_%s" % stat_key, actor.get(stat_key, 0)))


func _apply_inner_force_runtime_stats(actor: Dictionary, force: Dictionary) -> void:
	# 氣血、內力原本是滿的，套用五維後最大值變大時要一起補滿（否則開局是 150/157）；受過傷的維持原值
	var was_full_hp := int(actor.get("hp", 0)) >= int(actor.get("max_hp", actor.get("hp", 0)))
	var was_full_mp := int(actor.get("mp", 0)) >= int(actor.get("max_mp", actor.get("mp", 0)))
	_reset_actor_to_base_stats(actor)
	var actor_snapshot := {}
	for stat_key in MAIN_STAT_KEYS:
		actor_snapshot[stat_key] = int(actor.get(stat_key, 0))
	var runtime_effects: Dictionary = _inner_force_db.get_runtime_effects(force, actor_snapshot) if not force.is_empty() else {}
	for stat_key in MAIN_STAT_KEYS:
		actor[stat_key] = int(actor.get(stat_key, 0)) + int(runtime_effects.get(stat_key, 0))

	var effective_str := int(actor.get("str", 0))
	var effective_agi := int(actor.get("agi", 0))
	var effective_int := int(actor.get("int", 0))
	var effective_con := int(actor.get("con", 0))
	var effective_luck := int(actor.get("luck", 0))

	actor["max_hp"] = max(1, int(round(float(actor.get("base_max_hp", actor.get("max_hp", 1))) * (1.0 + float(max(0, effective_con)) * 0.01))) + int(runtime_effects.get("max_hp", 0)))
	actor["max_mp"] = max(0, int(round(float(actor.get("base_max_mp", actor.get("max_mp", 0))) * (1.0 + float(max(0, effective_int)) * 0.01))) + int(runtime_effects.get("max_mp", 0)))
	actor["atk"] = max(0, int(actor.get("base_atk", actor.get("atk", 0))) + int(floor(float(effective_str) * 1.2)) + int(runtime_effects.get("atk", 0)))
	actor["def"] = max(0, int(actor.get("base_def", actor.get("def", 0))) + int(floor(float(effective_con) * 0.8)) + int(runtime_effects.get("def", 0)))
	actor["speed"] = max(0, int(actor.get("base_speed", actor.get("speed", 0))) + effective_agi + int(runtime_effects.get("speed", 0)))
	actor["accuracy"] = max(0, int(actor.get("base_accuracy", actor.get("accuracy", 100))) + int(round(float(effective_agi) * 0.7 + float(effective_luck) * 0.3)) + int(runtime_effects.get("accuracy", 0)))
	actor["evasion"] = max(0, int(actor.get("base_evasion", actor.get("evasion", 0))) + int(round(float(effective_agi) * 0.7 + float(effective_luck) * 0.3)) + int(runtime_effects.get("evasion", 0)))
	actor["crit_rate"] = clampf((0.05 + floor(float(effective_luck) / 5.0) * 0.01 + float(runtime_effects.get("crit_rate_bonus", 0.0))), 0.0, 0.95)
	actor["derived_stats_applied"] = true
	actor["hp"] = int(actor.get("max_hp", 1)) if was_full_hp else min(int(actor.get("hp", 0)), int(actor.get("max_hp", 1)))
	actor["mp"] = int(actor.get("max_mp", 0)) if was_full_mp else min(int(actor.get("mp", 0)), int(actor.get("max_mp", 0)))


func _apply_inner_force_to_actor(actor: Dictionary) -> void:
	var actor_id := String(actor.get("id", ""))
	var force_id := String(actor.get("inner_force_id", ""))
	var force = _inner_force_db.get_force(force_id)
	if force.is_empty() and not _default_known_force_ids(actor_id).is_empty():
		force_id = String(_default_known_force_ids(actor_id)[0])
		actor["inner_force_id"] = force_id
		force = _inner_force_db.get_force(force_id)
	actor["inner_force"] = force
	actor["available_inner_forces"] = get_effective_inner_forces(actor_id, actor)
	if force.has("element"):
		actor["element"] = force["element"]
	_apply_inner_force_runtime_stats(actor, force)

func _resolve_known_force_ids_from_legacy(actor_id: String, legacy_forces: Array, actor_override: Dictionary = {}) -> Array:
	var out: Array = []
	for force in legacy_forces:
		if typeof(force) != TYPE_DICTIONARY:
			continue
		var force_id = _inner_force_db.resolve_legacy_force_id(force)
		if force_id == "":
			continue
		if out.has(force_id):
			continue
		if _inner_force_db.is_available_to_actor(force_id, actor_id, actor_override):
			out.append(force_id)
	return out

func _default_known_force_ids(actor_id: String) -> Array:
	actor_id = canonicalize_actor_id(actor_id)
	match actor_id:
		"liuyu":
			return ["qingfeng_jue", "liuchen_jue", "wuji_zhenjing", "fuchao_jue"]
		"lieshao":
			return ["chi_yang_zhenjing", "po_jun_zhenjing"]
		"shumian":
			return ["meng_ying_xinfa", "ling_feng_jue"]
		_:
			return []

func _default_weapon_aptitudes(actor_id: String) -> Array:
	actor_id = canonicalize_actor_id(actor_id)
	match actor_id:
		"liuyu":
			return ["刀", "劍", "棍", "槍", "拳", "掌", "琴", "筆", "通用"]
		"shumian":
			return ["筆", "拳", "掌", "通用"]
		"lieshao":
			return ["琴", "刀", "拳", "掌", "通用"]
		_:
			# Unknown/future actors must declare their permanent aptitude data;
			# current equipment is intentionally not used as a fallback.
			return ["通用"]

func _sync_inner_force_to_global_state(actor_id: String, force_id: String) -> void:
	actor_id = canonicalize_actor_id(actor_id)
	if GlobalState == null:
		return
	var mapping = GlobalState.get_meta("inner_force_ids", {})
	if typeof(mapping) != TYPE_DICTIONARY:
		mapping = {}
	mapping[actor_id] = force_id
	GlobalState.set_meta("inner_force_ids", mapping)
