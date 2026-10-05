extends RefCounted
## What the Card Inspect panel shows: one plain data container for every kind of card (a party member, an enemy,
## a support card), built from the real battle data. Nothing here is invented: a field the game does not have
## (armour, weaknesses of a species, a source that was never recorded) is simply left out.
##
## {
##   "title": String, "subtitle": String,
##   "blocks": [{"heading": String, "lines": [bbcode String]}],
##   "statuses": [{"id", "glyph", "kind": "buff"|"debuff"|"guard"|"info", "name", "effect", "turns": String, "source": String}],
##   "notes": [String],
## }

const StageAdjacency = preload("res://scripts/battlescripts/StageAdjacency.gd")
const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")
const StatusDisplay = preload("res://scripts/db/StatusDisplayDB.gd")

const STATUS_NAMES := {
	"speed_buff": "速度提升", "slow": "速度下降", "poison": "中毒", "stun": "暈眩", "confuse": "混亂",
	"weaken": "無力", "atk_up": "昂勢", "def_up": "護脈", "break_def": "破防", "weak": "虛弱", "seal_mp": "封穴",
	"blind": "目盲", "focus": "凝神", "evasion_boost": "輕身", "root": "定身", "warm_wine_buff": "暖身酒",
	"force_element": "元素變化",
	"stat_buff_str": "強身", "stat_buff_agi": "敏捷", "stat_buff_int": "啟慧", "stat_buff_con": "健體", "stat_buff_luck": "聚福",
	"stat_debuff_str": "壓勁", "stat_debuff_agi": "亂弦", "stat_debuff_int": "惑思", "stat_debuff_con": "奪息", "stat_debuff_luck": "厄運",
}
const GLYPHS := {
	"speed_buff": "速", "slow": "緩", "poison": "毒", "stun": "暈", "confuse": "亂", "weaken": "弱", "atk_up": "攻",
	"def_up": "防", "break_def": "破", "weak": "衰", "seal_mp": "損", "blind": "盲", "focus": "命", "evasion_boost": "閃",
	"root": "困", "warm_wine_buff": "攻", "force_element": "元",
}
const NEGATIVE := ["poison", "stun", "confuse", "slow", "weaken", "break_def", "weak", "seal_mp", "blind", "root"]
const STAT_NAMES := {"str": "力量", "agi": "敏捷", "int": "智慧", "con": "體能", "luck": "幸運"}
const FAMILY_NAMES := {
	"DEFENSE_UP": "防禦提升", "ATTACK_UP": "攻擊提升", "RALLY_ATTACK_UP": "攻擊提升（戰鼓）", "STRENGTH_UP": "力量提升",
	"CONSTITUTION_UP": "體能提升", "AGILITY_UP": "敏捷提升", "INTELLECT_UP": "智慧提升", "LUCK_UP": "幸運提升",
	"DAMAGE_REDUCTION": "傷害減免", "PARRY_UP": "招架提升", "STATUS_RESIST": "狀態抵抗",
}
## Support-card effect family -> status icon id (families without a matching icon simply show their word).
const FAMILY_ICONS := {
	"DEFENSE_UP": "def_up", "ATTACK_UP": "atk_up", "RALLY_ATTACK_UP": "atk_up", "STRENGTH_UP": "stat_buff_str",
	"AGILITY_UP": "stat_buff_agi", "INTELLECT_UP": "stat_buff_int", "CONSTITUTION_UP": "stat_buff_con", "LUCK_UP": "stat_buff_luck",
}
const ENTITY_KIND_NAMES := {"substitute_talisman": "僚卡／防護符", "linfu_talisman": "僚卡／臨符", "sheath_card": "僚卡／架勢"}
const ENTITY_SOURCE_NAMES := {"substitute_talisman": "替身符", "sheath_card": "拔劍持鞘"}
const ELEMENTS := ["快", "柔", "遲", "剛"]


# --- Characters ---------------------------------------------------------------------------------------------

static func for_actor(ui: Object, actor: Dictionary, enemy: bool) -> Dictionary:
	var data: Dictionary = {"title": String(actor.get("display_name", actor.get("name", "???"))), "subtitle": "", "blocks": [], "statuses": [], "notes": []}
	var sub: Array[String] = []
	if enemy:
		var species: String = String(actor.get("archetype", actor.get("species", actor.get("family", ""))))
		if species != "":
			sub.append("種族：%s" % species)
		if String(actor.get("element", "")) != "":
			sub.append("屬性：%s" % String(actor.get("element", "")))
	else:
		sub.append("Lv %d" % int(actor.get("level", 1)))
		var force: Dictionary = actor.get("inner_force", {}) if typeof(actor.get("inner_force", {})) == TYPE_DICTIONARY else {}
		if not force.is_empty() and String(force.get("name", "")) != "":
			sub.append("內功：%s" % String(force.get("name", "")))
	data.subtitle = "　".join(sub)

	var basics: Array = []
	var hp: int = int(actor.get("hp", 0))
	var max_hp: int = int(actor.get("max_hp", hp))
	basics.append("氣血　%d / %d" % [clampi(hp, 0, max_hp), max_hp])
	if not enemy and int(actor.get("max_mp", 0)) > 0:
		basics.append("內力　%d / %d" % [int(actor.get("mp", 0)), int(actor.get("max_mp", 0))])
	var place: int = _row_position(ui, actor, enemy)
	if place > 0:
		basics.append("行動順位　第 %d 位（最右為下一個）" % place)
	(data.blocks as Array).append({"heading": "基本", "lines": ["　".join(PackedStringArray(basics.slice(0, 2)))] + basics.slice(2)})

	var numbers: Array = []
	var primary: Array[String] = []
	for key: String in ["str", "agi", "int", "con", "luck"]:
		if actor.has(key):
			primary.append("%s %d" % [STAT_NAMES[key], int(actor.get(key, 0))])
	if not primary.is_empty():
		numbers.append("　".join(primary))
	var derived: Array[String] = []
	for pair: Array in [["atk", "攻擊"], ["def", "防禦"], ["speed", "速度"], ["accuracy", "命中"], ["evasion", "閃避"]]:
		if actor.has(String(pair[0])):
			derived.append("%s %d" % [String(pair[1]), int(actor.get(String(pair[0]), 0))])
	if actor.has("crit_rate"):
		derived.append("會心 %.0f%%" % (float(actor.get("crit_rate", 0.0)) * 100.0))
	if not derived.is_empty():
		numbers.append("　".join(derived))
	if not numbers.is_empty():
		(data.blocks as Array).append({"heading": "數值（目前值）", "lines": numbers})

	if not enemy:
		var gear: Array = []
		for pair: Array in [["weapon_1", "武器"], ["weapon_2", "武器"], ["armor", "防具"], ["accessory", "飾品"]]:
			if String(actor.get(String(pair[0]), "")) != "":
				gear.append("%s　%s" % [String(pair[1]), String(actor.get(String(pair[0]), ""))])
		if gear.is_empty() and actor.has("weapon_1"):
			gear.append("徒手（拳／掌）")
		if not gear.is_empty():
			(data.blocks as Array).append({"heading": "裝備", "lines": gear})
		var skills: Array = _skill_lines(ui, actor)
		if not skills.is_empty():
			(data.blocks as Array).append({"heading": "武學", "lines": skills})
	else:
		var intel: Array = _enemy_intel(actor)
		if not intel.is_empty():
			(data.blocks as Array).append({"heading": "戰鬥情報", "lines": intel})
		if String(actor.get("description", "")) != "":
			(data.notes as Array).append(String(actor.get("description", "")))

	data.statuses = _statuses_for(ui, actor, enemy)
	return data


static func _row_position(ui: Object, actor: Dictionary, enemy: bool) -> int:
	var controller: Object = ui.get("combat_controller") as Object
	if controller == null or controller.get("turn_manager") == null:
		return 0
	var row: Array = controller.turn_manager.get_display_row(enemy)
	var key: String = StageAdjacency.key_of(actor)
	var index: int = StageAdjacency.index_of(row, key)
	return index + 1 if index >= 0 else 0


static func _skill_lines(ui: Object, actor: Dictionary) -> Array:
	var lines: Array = []
	var provider: Object = ui.get("character_skill_db") as Object
	if provider == null or not provider.has_method("get_skills_by_actor"):
		return lines
	for skill_any: Variant in provider.get_skills_by_actor(actor):
		if typeof(skill_any) != TYPE_DICTIONARY:
			continue
		var skill: Dictionary = skill_any
		if String(skill.get("name", "")) == "":
			continue
		var cost: String = "　（內力 %d）" % int(skill.get("mp_cost", 0)) if int(skill.get("mp_cost", 0)) > 0 else ""
		var text: String = "[b]%s[/b]%s" % [String(skill.get("name", "")), cost]
		var description: String = String(skill.get("description", ""))
		if description != "":
			text += "\n[color=#b9b29c]%s[/color]" % description.left(46)
		lines.append(text)
	return lines


## What can be said about an enemy from the real rules: the element that beats it and the one it beats.
static func _enemy_intel(actor: Dictionary) -> Array:
	var lines: Array = []
	var element: String = String(actor.get("element", ""))
	if element != "":
		var strong_against: Array[String] = []
		var weak_to: Array[String] = []
		for other: String in ELEMENTS:
			if InnerForceDB.resolve_element_advantage_multiplier(other, element) > 1.0:
				weak_to.append(other)
			if InnerForceDB.resolve_element_advantage_multiplier(element, other) > 1.0:
				strong_against.append(other)
		if not weak_to.is_empty():
			lines.append("弱點　被「%s」屬性剋制（傷害 ×%.1f）" % ["、".join(weak_to), InnerForceDB.ELEMENT_ADVANTAGE_MULTIPLIER])
		if not strong_against.is_empty():
			lines.append("剋制　「%s」屬性" % "、".join(strong_against))
	var effects: Dictionary = actor.get("status_effects", {}) if typeof(actor.get("status_effects", {})) == TYPE_DICTIONARY else {}
	if effects.has("yumei_entanglement"):
		lines.append("[color=#c79bff]%s：玩家造成的生命傷害歸零[/color]" % StatusDisplay.GUARD_BARRIER_NAME)
	return lines


# --- Statuses -----------------------------------------------------------------------------------------------

static func _statuses_for(ui: Object, actor: Dictionary, enemy: bool) -> Array:
	var rows: Array = []
	var effects: Dictionary = actor.get("status_effects", {}) if typeof(actor.get("status_effects", {})) == TYPE_DICTIONARY else {}
	for id_any: Variant in effects.keys():
		var id: String = String(id_any)
		var record: Dictionary = effects[id_any] if typeof(effects[id_any]) == TYPE_DICTIONARY else {}
		rows.append(_status_row(id, record))
	if bool(actor.get("defending", false)):
		rows.append({"id": "", "glyph": "守", "kind": "info", "name": "防禦姿態", "effect": "受到的傷害降低", "turns": "至下次行動前", "source": "自身"})
	if String(actor.get("stance", "")) == "HOLDING_SHEATH":
		rows.append({"id": "", "glyph": "鞘", "kind": "info", "name": "持鞘姿態", "effect": "左手持鞘：可用招式受限，持鞘卡緊貼時可格擋", "turns": "直到收鞘", "source": "拔劍持鞘"})
	var modifiers: Dictionary = actor.get("battle_modifiers", {}) if typeof(actor.get("battle_modifiers", {})) == TYPE_DICTIONARY else {}
	if float(modifiers.get("pen_damage_up", 0.0)) > 0.0:
		rows.append({"id": "pen_damage_up", "glyph": "攻", "kind": "buff", "name": "筆傷害提升", "effect": "筆系傷害 +%.0f%%" % (float(modifiers.get("pen_damage_up", 0.0)) * 100.0), "turns": "整場戰鬥", "source": "書籍"})
	if float(modifiers.get("pen_damage_resist", 0.0)) > 0.0:
		rows.append({"id": "pen_damage_resist", "glyph": "防", "kind": "buff", "name": "筆傷害降低", "effect": "受筆系傷害 −%.0f%%" % (float(modifiers.get("pen_damage_resist", 0.0)) * 100.0), "turns": "整場戰鬥", "source": "書籍"})
	rows.append_array(_support_card_rows(ui, actor))
	return rows


static func _status_row(id: String, record: Dictionary) -> Dictionary:
	var payload: Dictionary = record.get("payload", {}) if typeof(record.get("payload", {})) == TYPE_DICTIONARY else {}
	var turns: int = int(record.get("turns_left", 0))
	var timing: String = String(record.get("decrement_timing", ""))
	var kind: String = "debuff" if (NEGATIVE.has(id) or id.begins_with("stat_debuff_")) else "buff"
	var name: String = String(STATUS_NAMES.get(id, id))
	var glyph: String = String(GLYPHS.get(id, ""))
	if id.begins_with("stat_buff_") or id.begins_with("stat_debuff_"):
		glyph = String(STAT_NAMES.get(id.get_slice("_", 2), "")).left(1)
	var effect: String = _effect_text(id, payload)
	var turn_text: String = "%d 回合" % turns
	if timing == "manual" or id == "yumei_entanglement":
		turn_text = "至被破除"
	if id == "yumei_entanglement":
		kind = "guard"
		name = StatusDisplay.display_name(id, name)
		glyph = "護"
		effect = "玩家造成的生命傷害歸零"
	return {"id": id, "glyph": glyph, "kind": kind, "name": name, "effect": effect, "turns": turn_text, "source": _source_text(record.get("source", {}))}


static func _effect_text(id: String, payload: Dictionary) -> String:
	match id:
		"speed_buff":
			return "速度 +%d" % int(payload.get("speed_delta", 0))
		"slow":
			return "速度 −%d" % abs(int(payload.get("slow_delta", 0)))
		"poison":
			return "每回合結束損失生命"
		"stun":
			return "無法行動"
		"confuse":
			return "單體行動可能誤擊敵我"
		"weaken":
			return "攻擊 −%d" % abs(int(payload.get("atk_delta", 0)))
		"atk_up":
			return "攻擊 +%d" % int(payload.get("atk_delta", 0))
		"def_up":
			return "防禦 +%d" % int(payload.get("def_delta", 0))
		"break_def":
			return "防禦 −%d" % abs(int(payload.get("def_delta", 0)))
		"weak":
			return "最大生命 −%d" % abs(int(payload.get("max_hp_delta", 0)))
		"seal_mp":
			return "最大內力 −%d" % abs(int(payload.get("max_mp_delta", 0)))
		"blind":
			return "命中 −%d" % abs(int(payload.get("accuracy_delta", 0)))
		"focus":
			return "命中 +%d" % int(payload.get("accuracy_delta", 0))
		"evasion_boost":
			return "閃避 +%d" % int(payload.get("evasion_delta", 0))
		"root":
			return "閃避 −%d" % abs(int(payload.get("evasion_delta", 0)))
		"warm_wine_buff":
			return "速度 %+d／命中 %+d" % [int(payload.get("speed_delta", 0)), int(payload.get("accuracy_delta", 0))]
		"force_element":
			return "屬性轉為「%s」" % String(payload.get("element", "?"))
	if id.begins_with("stat_buff_") or id.begins_with("stat_debuff_"):
		var stat: String = id.get_slice("_", 2)
		return "%s %+d" % [String(STAT_NAMES.get(stat, stat)), int(payload.get("stat_delta", 0))]
	return ""


## Who or what put the status there. Only what was recorded when it was applied; nothing is guessed.
static func _source_text(source: Variant) -> String:
	if typeof(source) != TYPE_DICTIONARY or (source as Dictionary).is_empty():
		return ""
	var record: Dictionary = source
	var name: String = String(record.get("name", ""))
	var by: String = String(record.get("by", ""))
	var text: String = name
	match String(record.get("kind", "")):
		"skill":
			text = "招式「%s」" % name
		"item":
			text = "道具「%s」" % name
		"card":
			text = "僚卡「%s」" % name
		"self":
			text = name if name != "" else "自身招式"
	# A skill that leaves a named state behind (天殘．地缺劍 -> 殘脈): the skill is the source, the state is a label.
	var state: String = String(record.get("state", ""))
	if state != "":
		text += "→「%s」" % state
	if by != "" and by != name:
		text += "（%s）" % by
	return text


## The effects of support cards that reach this actor right now, from the live row, with the same rule the damage
## calculation uses: effects of one family do not add, the highest wins; the others are listed as not in force.
static func _support_card_rows(ui: Object, actor: Dictionary) -> Array:
	var rows: Array = []
	var controller: Object = ui.get("combat_controller") as Object
	if controller == null or controller.get("stage_entities") == null or controller.get("turn_manager") == null or controller.stage_entities.is_empty():
		return rows
	var key: String = StageAdjacency.key_of(actor)
	var sources: Array = []
	for enemy_side: bool in [false, true]:
		var row: Array = controller.turn_manager.get_display_row(enemy_side)
		for index: int in range(row.size()):
			var entry: Dictionary = row[index]
			if not StageAdjacency.is_entity(entry):
				continue
			var entity: Object = controller.stage_entities.get_entity(String(entry.get("entity_id", "")))
			if entity == null or not ("adjacency_effects" in entity):
				continue
			for recipient: Dictionary in StageAdjacency.recipients(row, index, String(entity.get("adjacency_pattern"))):
				if StageAdjacency.key_of(recipient) != key:
					continue
				for effect: Variant in entity.get("adjacency_effects"):
					sources.append({"entity": entity, "effect": effect})
	var best: Dictionary = {}
	for source: Dictionary in sources:
		var family: String = String(source.effect.get("family", ""))
		best[family] = maxf(float(best.get(family, 0.0)), float(source.effect.get("value", 0.0)))
	for source: Dictionary in sources:
		var effect: Dictionary = source.effect
		var family: String = String(effect.get("family", ""))
		var value: float = float(effect.get("value", 0.0))
		var in_force: bool = is_equal_approx(value, float(best.get(family, 0.0)))
		var percent: bool = String(effect.get("mode", "flat")) == "percent"
		var value_text: String = "%+.0f%%" % (value * 100.0) if percent else "%+d" % int(value)
		var entity: Object = source.entity
		var card_name: String = String(entity.get("display_name"))
		var effect_text: String = "%s %s" % [String(FAMILY_NAMES.get(family, family)), value_text]
		if not in_force:
			effect_text += "（同類只取最高，此項未生效）"
		rows.append({
			"id": String(FAMILY_ICONS.get(family, "")), "glyph": "符", "kind": "buff", "name": card_name, "effect": effect_text,
			"turns": _entity_turns_text(entity), "source": "僚卡「%s」" % card_name,
		})
	return rows


static func _entity_turns_text(entity: Object) -> String:
	var duration: int = int(entity.get("duration_turns"))
	if duration >= 0:
		return "%d 次行動" % duration
	return "留到被消耗"


# --- Support cards --------------------------------------------------------------------------------------------

static func for_entity(ui: Object, entity: Object) -> Dictionary:
	var type: String = String(entity.get("entity_type"))
	var name: String = String(entity.get("display_name"))
	var data: Dictionary = {"title": name, "subtitle": String(ENTITY_KIND_NAMES.get(type, "僚卡／支援卡")), "blocks": [], "statuses": [], "notes": []}
	var owner_name: String = _actor_name(ui, String(entity.get("owner_id")))
	var basics: Array = []
	basics.append("所屬　%s" % (owner_name if owner_name != "" else "—"))
	var source_skill: String = String(ENTITY_SOURCE_NAMES.get(type, name))
	basics.append("來源　%s．%s" % [owner_name, source_skill] if owner_name != "" else "來源　%s" % source_skill)
	basics.append("陣營　%s" % ("敵方" if String(entity.get("faction")) == "enemy" else "我方"))
	(data.blocks as Array).append({"heading": "基本", "lines": basics})

	var rules: Array = []
	var charges: Variant = entity.get("guard_charges")
	var duration: int = int(entity.get("duration_turns"))
	if charges != null:
		rules.append("剩餘次數　%d" % int(charges))
	if duration >= 0:
		rules.append("剩餘回合　%d（輪到它自己時 −1）" % duration)
	elif charges == null:
		rules.append("沒有回合壽命，留到被消耗或移除")
	rules.append("位置　只依牌陣位置結算，不吃角色速度")
	rules.append("可被攻擊　%s　可被治療　%s" % ["是" if bool(entity.get("targetable")) else "否", "是" if bool(entity.get("healable")) else "否"])
	var controller: Object = ui.get("combat_controller") as Object
	if controller != null and controller.get("turn_manager") != null:
		var proxy: Dictionary = controller.turn_manager.find_queue_actor(String(entity.get("entity_id")))
		if not proxy.is_empty():
			rules.append("本輪　%s" % ("已行動（變灰）" if controller.turn_manager.has_acted(proxy) else "尚未行動"))
	(data.blocks as Array).append({"heading": "存在規則", "lines": rules})

	var effect_lines: Array = _entity_effect_lines(entity, type)
	if not effect_lines.is_empty():
		(data.blocks as Array).append({"heading": "效果", "lines": effect_lines})
	var stance: String = String(entity.get("grants_stance"))
	if stance != "":
		(data.notes as Array).append("存在期間，%s處於「持鞘姿態」；卡片離場時姿態一併解除。" % (owner_name if owner_name != "" else "持有者"))
	return data


static func _entity_effect_lines(entity: Object, type: String) -> Array:
	var lines: Array = []
	match type:
		"substitute_talisman":
			lines.append("不吸引仇恨：敵人照原本的邏輯攻擊角色。")
			lines.append("擋下緊貼它左右兩側角色卡受到的傷害（一次敵方行動內的所有命中），行動結束後符紙碎裂。")
			lines.append("不保護僚卡，也不保護沒有緊貼它的角色。")
		"sheath_card":
			lines.append("緊貼持有者時，每個落在他身上的命中有 %.0f%% 機率被格擋。" % (float(entity.get("block_chance")) * 100.0))
			lines.append("已行動變灰也不影響格擋。")
		_:
			pass
	if "adjacency_effects" in entity:
		var effects: Array = entity.get("adjacency_effects")
		var pattern: String = String(entity.get("adjacency_pattern"))
		var who: String = "右側最近的角色" if pattern == "anchor" else ("左側相鄰角色" if pattern == "left" else ("右側相鄰角色" if pattern == "right" else "左右相鄰的角色"))
		for effect: Variant in effects:
			var family: String = String(effect.get("family", ""))
			var percent: bool = String(effect.get("mode", "flat")) == "percent"
			var value: float = float(effect.get("value", 0.0))
			lines.append("%s%s %s" % [who, String(FAMILY_NAMES.get(family, family)), ("%+.0f%%" % (value * 100.0)) if percent else ("%+d" % int(value))])
		if not effects.is_empty():
			lines.append("同類效果不疊加，只取最高值；效果依「此刻」的牌陣位置計算。")
	return lines


static func _actor_name(ui: Object, actor_id: String) -> String:
	if actor_id == "":
		return ""
	var controller: Object = ui.get("combat_controller") as Object
	if controller != null and controller.get("player_party") != null:
		for actor: Variant in controller.player_party:
			if typeof(actor) == TYPE_DICTIONARY and String((actor as Dictionary).get("id", "")) == actor_id:
				return String((actor as Dictionary).get("display_name", (actor as Dictionary).get("name", "")))
	return ""
