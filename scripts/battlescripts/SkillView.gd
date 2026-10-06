extends RefCounted
## One place that answers "what does this skill cost, can this actor use it now, and what does it turn into in this
## build" - for the battle skill list, the Card Inspect skill page and the controller's own check before it executes.
## Nothing here changes a rule; it only reads the same data the rules use, so the two screens and the rule can never
## disagree (a cost changed from 20 to 25 is changed in one place).
##
## `check(actor, skill)` is the single door. Today it knows two reasons (not enough MP, a stance that forbids the
## skill); the code field is the extension point for more (needs the sheath, wrong weapon, sealed, no legal target,
## on cooldown...). Add a reason by adding a branch there; the screens only show `text`.

const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
const CharacterSkillScript = preload("res://scripts/battlescripts/CharacterSkill.gd")

const CODE_OK := ""
const CODE_MP := "mp"
const CODE_STANCE := "stance"
const CODE_WEAPON := "weapon"

static var _skill_db: Node = null


static func _db() -> Node:
	if _skill_db == null:
		_skill_db = SkillDBScript.new()
	return _skill_db


## The MP this actor pays for this skill right now (the inner force can make it cheaper or dearer).
static func mp_cost(actor: Dictionary, skill: Dictionary) -> int:
	var base_cost: int = int(skill.get("mp_cost", 0))
	if base_cost <= 0:
		return 0
	var force: Dictionary = actor.get("inner_force", {}) if typeof(actor.get("inner_force", {})) == TYPE_DICTIONARY else {}
	if force.is_empty():
		return base_cost
	var multiplier: float = float(force.get("skill_mp_cost_multiplier", 1.0))
	var weapon_type: String = String(skill.get("weapon_type", ""))
	var by_weapon: Variant = force.get("skill_mp_cost_multiplier_by_weapon", {})
	if weapon_type != "" and typeof(by_weapon) == TYPE_DICTIONARY and (by_weapon as Dictionary).has(weapon_type):
		multiplier *= float((by_weapon as Dictionary).get(weapon_type, 1.0))
	var adjusted: int = int(floor(float(base_cost) * maxf(0.0, multiplier)))
	return maxi(adjusted, 1)


## The verdict: {"ok": bool, "code": String, "text": String, "need": int, "have": int}. `include_weapon` is for screens
## that list skills the actor cannot wield at the moment (the battle list simply does not list those).
static func check(actor: Dictionary, skill: Dictionary, include_weapon: bool = false) -> Dictionary:
	var verdict: Dictionary = {"ok": true, "code": CODE_OK, "text": "", "need": 0, "have": 0}
	if not bool(_db().is_stance_compatible(skill, actor)):
		verdict.ok = false
		verdict.code = CODE_STANCE
		verdict.text = "目前的姿態下無法使用"
		return verdict
	if include_weapon and not bool(_db().is_weapon_compatible(skill, actor)):
		verdict.ok = false
		verdict.code = CODE_WEAPON
		verdict.text = "需要裝備對應的武器（%s）" % String(skill.get("weapon_type", ""))
		return verdict
	var cost: int = mp_cost(actor, skill)
	var have: int = int(actor.get("mp", 0))
	if cost > 0 and have < cost:
		verdict.ok = false
		verdict.code = CODE_MP
		verdict.need = cost
		verdict.have = have
		verdict.text = "內力不足：需要 %d，目前 %d" % [cost, have]
	return verdict


static func can_use(actor: Dictionary, skill: Dictionary) -> bool:
	return bool(check(actor, skill).ok)


## "" when the skill can be used, otherwise the reason to show the player.
static func disabled_reason(actor: Dictionary, skill: Dictionary) -> String:
	return String(check(actor, skill).text)


## The attack count in three layers (基礎 / 相合 / 目前), fixed or ranged:
## {"base", "effective", "delta", "source", "ranged", "base_min", "base_max", "effective_min", "effective_max",
##  "base_text", "effective_text"}. `base` / `effective` are the (lowest) counts - for a fixed skill the count itself; the
## texts read "3擊" or "2～4擊". This is display only: the real count is rolled by BattleController._resolve_strike_count,
## which adds the same synergy delta.
static func strike_info(skill: Dictionary, inner_force: Dictionary) -> Dictionary:
	var base_skill: Dictionary = _db().get_skill(String(skill.get("id", "")))
	if base_skill.is_empty():
		base_skill = skill
	var base_range: Vector2i = _strike_range(base_skill)
	var own_range: Vector2i = _strike_range(skill) if _has_strikes(skill) else base_range
	var pairing: Dictionary = CharacterSkillScript.get_pairing_rule(String(skill.get("id", "")), String(inner_force.get("id", "")))
	var delta: int = int((pairing.get("effects", {}) as Dictionary).get("strike_count_delta", 0))
	var effective_min: int = own_range.x
	var effective_max: int = own_range.y
	if delta != 0:
		effective_min = maxi(base_range.x + delta, 1)
		effective_max = maxi(base_range.y + delta, 1)
	var source: String = ""
	if effective_min != base_range.x or effective_max != base_range.y:
		source = String(inner_force.get("prefix", "")) + String(inner_force.get("type", ""))
	return {
		"base": base_range.x, "effective": effective_min, "delta": effective_min - base_range.x, "source": source,
		"ranged": base_range.x != base_range.y or effective_min != effective_max,
		"base_min": base_range.x, "base_max": base_range.y, "effective_min": effective_min, "effective_max": effective_max,
		"base_text": strike_text(base_range.x, base_range.y), "effective_text": strike_text(effective_min, effective_max),
	}


static func strike_text(low: int, high: int) -> String:
	return "%d擊" % low if low == high else "%d～%d擊" % [low, high]


static func _has_strikes(skill: Dictionary) -> bool:
	return skill.has("strike_count") or skill.has("strike_count_min") or skill.has("strike_count_max")


## The same reading BattleController._resolve_strike_count makes of a skill (without rolling).
static func _strike_range(skill: Dictionary) -> Vector2i:
	var low: int = int(skill.get("strike_count_min", 0))
	var high: int = int(skill.get("strike_count_max", 0))
	if low > 0 or high > 0:
		if low <= 0:
			low = high
		if high <= 0:
			high = low
		return Vector2i(mini(low, high), maxi(low, high))
	var count: int = int(skill.get("strike_count", 0))
	for key: String in ["attack_count", "hit_count", "hits"]:
		if count <= 0:
			count = int(skill.get(key, 0))
	count = maxi(count, 1)
	return Vector2i(count, count)


## The same colour with less saturation and brightness - for a skill that cannot be used right now. The hue stays,
## so the player still reads what kind of skill it is.
static func muted(color: Color) -> Color:
	var result: Color = color
	result.s = color.s * 0.45
	result.v = clampf(color.v * 0.55, 0.0, 1.0)
	return result


## One line per effect of a skill ("傷害 1.0x", "回復HP 30"...).
static func effect_summary(skill: Dictionary) -> String:
	var effects: Variant = skill.get("effects", [])
	if typeof(effects) != TYPE_ARRAY or (effects as Array).is_empty():
		return "（無）"
	var tokens: Array[String] = []
	for entry_any: Variant in effects:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any
		match String(entry.get("type", "")):
			"damage":
				tokens.append("傷害 %.1fx" % float(entry.get("power", skill.get("power", 1.0))))
			"heal_hp":
				tokens.append("回復HP %d" % int(entry.get("amount", 0)))
			var other:
				tokens.append(other)
	return "（無）" if tokens.is_empty() else "、".join(tokens)
