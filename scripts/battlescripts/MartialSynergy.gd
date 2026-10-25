extends RefCounted
## The canonical table of martial synergies (武學相合): one inner force (內功) making one martial skill (武術) more than
## itself. Everything that talks about a synergy - the rule the battle applies, the exclusive-skill list on the inner
## force, the linkage lines on a skill description, SkillView and the Card Inspect 「相合」 page - reads THIS table, so a
## pairing is written once.
##
## relation_type
##   standard        標準相合: the runtime rule lives here (`effects`) and CharacterSkill / BattleController apply it.
##   legendary_chain 傳說鏈: described here for the screens only; the runtime lives in SkillDB.legendary_chain.
##   risk_branch     絕技分支: described here for the screens only; the runtime lives in SkillDB.risk_upgrade.
## Only `standard` records have runtime meaning (see `runtime_rule`); the other two never change a battle result.
##
## A record is not limited to "+hits". `effects` is what the battle consumes (strike_count_delta, on_hit_status,
## bonus_stat_scaling, ...); `modifiers` is the player-facing view of the same thing and is derived from `effects` unless a
## record states it (hit_count, damage, mp_cost, element, target_rule, status_apply, stat_scaling, spawn_entity, other).

const RELATION_STANDARD := "standard"
const RELATION_LEGENDARY := "legendary_chain"
const RELATION_RISK := "risk_branch"

const RELATION_LABELS := {
	RELATION_STANDARD: "標準相合",
	RELATION_LEGENDARY: "傳說鏈",
	RELATION_RISK: "絕技分支",
}

const RECORDS := [
	{
		"synergy_id": "liuchen_jue__skill_lianjuejian",
		"relation_type": RELATION_STANDARD,
		"inner_skill_id": "liuchen_jue",
		"martial_skill_id": "skill_lianjuejian",
		"display_name": "流塵連決劍",
		"display_description": "流塵訣下可進化為「流塵連決劍」。",
		"short_description": "專屬：可進化為流塵連決劍。",
		"linkage_kind": "專屬搭配",
		"conditions": [],
		"effects": {"strike_count_delta": 1},
		"log": "{name} 運轉流塵訣，連決劍勢再起一重，追擊如塵隨風！",
	},
	{
		"synergy_id": "fuchao_jue__skill_duanshuizhan",
		"relation_type": RELATION_STANDARD,
		"inner_skill_id": "fuchao_jue",
		"martial_skill_id": "skill_duanshuizhan",
		"display_name": "伏潮斷水斬",
		"display_description": "伏潮訣下可進化為「伏潮斷水斬」，命中附加破防 2 回合。",
		"short_description": "專屬：伏潮斷水斬，命中附加破防2回合。",
		"linkage_kind": "專屬搭配",
		"conditions": [],
		"effects": {"on_hit_status": {"effect_id": "break_def", "amount": 10, "turns": 2}},
		"log": "{name} 刀勢忽沉，伏潮勁意先壓後斬，招路更見沉狠。",
	},
	{
		"synergy_id": "chenchao_jue__skill_breaking_wave_spear",
		"relation_type": RELATION_STANDARD,
		"inner_skill_id": "chenchao_jue",
		"martial_skill_id": "skill_breaking_wave_spear",
		"display_name": "沉潮破浪槍",
		"display_description": "沉潮訣下可進化為「沉潮破浪槍」，追加 STR / AGI 加權。",
		"short_description": "專屬：沉潮破浪槍，追加 STR / AGI 加權。",
		"linkage_kind": "專屬搭配",
		"conditions": [],
		"effects": {"bonus_stat_scaling": {"str": 0.70, "agi": 0.45}},
	},
	{
		"synergy_id": "qingqu_gongyin__skill_chengxin_luobi",
		"relation_type": RELATION_STANDARD,
		"inner_skill_id": "qingqu_gongyin",
		"martial_skill_id": "skill_chengxin_luobi",
		"display_name": "清渠澄心落筆",
		"display_description": "清渠共印下可進化為「清渠澄心落筆」：保留澄心落筆的解控與回復，並使全隊獲得 3 回合的清渠護印。",
		"short_description": "專屬：清渠澄心落筆，全隊獲得3回合清渠護印。",
		"linkage_kind": "專屬搭配",
		"conditions": [],
		# On cast the whole party gets the 清渠護印 status; its numbers are the inner force's own (InnerForceDB.ward_payload_from_force).
		"effects": {"team_status": {"effect_id": "qingqu_ward", "turns": 3, "payload_from_inner_force": true}},
		"modifiers": {"target_rule": "全隊獲得清渠護印（3 回合）", "other": ["遲屬性攻擊：防禦 +15", "語魅造成的傷害 ×0.9"]},
		"log": "{name} 運轉清渠共印，筆意順著水路淌開，替同伴把守住了出口。",
	},
	# --- described only; the runtime is SkillDB.legendary_chain / risk_upgrade and is not moved here
	{
		"synergy_id": "shipo_xinfa__skill_tianjingquan",
		"relation_type": RELATION_LEGENDARY,
		"inner_skill_id": "shipo_xinfa",
		"martial_skill_id": "skill_tianjingquan",
		"display_name": "石破天驚拳",
		"display_description": "石破心法下可進化為「石破天驚拳」，全場共享 2~4 次攻擊。",
		"short_description": "石破心法：進化為石破天驚拳。",
		"linkage_kind": "專屬搭配",
		"conditions": [],
		"modifiers": {"target_rule": "全場共享 2～4 次攻擊"},
	},
	{
		"synergy_id": "shipo_xinfa__skill_tianjingquan__bare",
		"relation_type": RELATION_LEGENDARY,
		"inner_skill_id": "shipo_xinfa",
		"martial_skill_id": "skill_tianjingquan",
		"display_name": "真．石破天驚拳",
		"display_description": "石破心法下，且全身無裝備時，可進化為「真．石破天驚拳」，每名敵人各承受 2~4 次攻擊。",
		"short_description": "奧義：全身無裝備時進化為真．石破天驚拳。",
		"linkage_kind": "奧義條件",
		"conditions": [{"type": "fully_unequipped", "text": "全身無裝備"}],
		"modifiers": {"target_rule": "每名敵人各承受 2～4 次攻擊"},
	},
	{
		"synergy_id": "tiancan_jue__skill_diquejian",
		"relation_type": RELATION_RISK,
		"inner_skill_id": "tiancan_jue",
		"martial_skill_id": "skill_diquejian",
		"display_name": "天殘．地缺劍",
		"display_description": "天殘訣下可施展「天殘．地缺劍」，消耗目前 HP 的 50%，對全體造成 3.0x ATK 傷害，並受 STR / CON 加權。",
		"short_description": "絕技：可施展天殘．地缺劍（耗50%HP，全體3.0x ATK，STR/CON加權）。",
		"linkage_kind": "絕技分支",
		"conditions": [],
		"modifiers": {"target_rule": "全體", "damage": "3.0x ATK", "other": ["消耗目前 HP 的 50%", "STR / CON 加權"]},
	},
]


## 閃卡等級（武學頁搭配框的掃光顏色，所有武學呈現共用同一套）：1 加成＝藍、2 專屬＝橘、3 絕技分支＝紫、4 奧義＝紅。
## 由搭配的 linkage_kind 決定；武器加成（內功 boost_weapon 與招式武器類型相同）也走這裡，所以每個內功都有自己的閃卡。
static func shine_tier(linkage_kind: String) -> int:
	if linkage_kind.contains("奧義"):
		return 4
	if linkage_kind.contains("絕技"):
		return 3
	if linkage_kind.contains("專屬"):
		return 2
	return 1


static func all() -> Array:
	return RECORDS.duplicate(true)


static func relation_label(relation_type: String) -> String:
	return String(RELATION_LABELS.get(relation_type, ""))


## The runtime rule for a standard pairing ({} when there is none) - the shape CharacterSkill.get_pairing_rule has
## always returned: inner_force_id, skill_id, effects, display_name, log.
static func runtime_rule(skill_id: String, inner_force_id: String) -> Dictionary:
	if skill_id == "" or inner_force_id == "":
		return {}
	for record: Dictionary in RECORDS:
		if String(record.relation_type) != RELATION_STANDARD:
			continue
		if String(record.martial_skill_id) == skill_id and String(record.inner_skill_id) == inner_force_id:
			var rule: Dictionary = {
				"inner_force_id": record.inner_skill_id,
				"skill_id": record.martial_skill_id,
				"effects": (record.effects as Dictionary).duplicate(true),
				"display_name": record.display_name,
			}
			if record.has("log"):
				rule["log"] = record.log
			return rule
	return {}


## Standard pairings only: the martial skills an inner force makes exclusive (what `exclusive_skill_ids` used to hold).
static func exclusive_skill_ids(inner_force_id: String) -> Array:
	var ids: Array = []
	for record: Dictionary in RECORDS:
		if String(record.relation_type) == RELATION_STANDARD and String(record.inner_skill_id) == inner_force_id:
			ids.append(record.martial_skill_id)
	return ids


static func for_martial(skill_id: String) -> Array:
	var out: Array = []
	for record: Dictionary in RECORDS:
		if String(record.martial_skill_id) == skill_id:
			out.append(record.duplicate(true))
	return out


static func for_inner(inner_force_id: String) -> Array:
	var out: Array = []
	for record: Dictionary in RECORDS:
		if String(record.inner_skill_id) == inner_force_id:
			out.append(record.duplicate(true))
	return out


## The record as modifiers: {hit_count, status_apply, stat_scaling, target_rule, damage, other...}, derived from the
## runtime `effects` unless the record states its own.
static func modifiers(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var effects: Dictionary = record.get("effects", {}) if typeof(record.get("effects", {})) == TYPE_DICTIONARY else {}
	if effects.has("strike_count_delta"):
		result["hit_count"] = int(effects.strike_count_delta)
	if effects.has("on_hit_status"):
		result["status_apply"] = (effects.on_hit_status as Dictionary).duplicate(true)
	if effects.has("bonus_stat_scaling"):
		result["stat_scaling"] = (effects.bonus_stat_scaling as Dictionary).duplicate(true)
	var stated: Dictionary = record.get("modifiers", {}) if typeof(record.get("modifiers", {})) == TYPE_DICTIONARY else {}
	for key: Variant in stated.keys():
		result[key] = stated[key]
	return result


const STATUS_NAMES := {"break_def": "破防", "blind": "目盲", "stun": "暈眩"}
const STAT_NAMES := {"str": "STR", "agi": "AGI", "con": "CON", "int": "INT", "wis": "WIS"}


## What the synergy adds, one short phrase each, for the 「相合」 layer. Hit count is left out when `skip_hits` is set
## (the three-layer view shows it on its own lines).
static func modifier_texts(record: Dictionary, skip_hits: bool = false) -> Array[String]:
	var mods: Dictionary = modifiers(record)
	var texts: Array[String] = []
	if mods.has("hit_count") and not skip_hits:
		texts.append("攻擊段數 %+d" % int(mods.hit_count))
	if mods.has("status_apply"):
		var status: Dictionary = mods.status_apply
		var name: String = String(STATUS_NAMES.get(String(status.get("effect_id", "")), String(status.get("effect_id", ""))))
		texts.append("命中附加%s %d 回合" % [name, int(status.get("turns", 0))])
	if mods.has("stat_scaling"):
		var parts: Array[String] = []
		for key: Variant in (mods.stat_scaling as Dictionary).keys():
			parts.append("%s +%.2f" % [String(STAT_NAMES.get(String(key), String(key).to_upper())), float((mods.stat_scaling as Dictionary)[key])])
		texts.append("威力加權 " + "、".join(parts))
	if mods.has("target_rule"):
		texts.append("目標：%s" % String(mods.target_rule))
	if mods.has("damage"):
		texts.append("傷害：%s" % String(mods.damage))
	if mods.has("mp_cost"):
		texts.append("內力消耗：%s" % str(mods.mp_cost))
	if mods.has("element"):
		texts.append("屬性：%s" % String(mods.element))
	if mods.has("other") and typeof(mods.other) == TYPE_ARRAY:
		for line: Variant in mods.other:
			texts.append(String(line))
	return texts
