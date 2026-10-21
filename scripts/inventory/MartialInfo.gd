extends RefCounted
const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")
## 武術頁的資料整理：外功分類（依已習得動態產生）、招式與內功效果的白話文字、目標說明。
## 只讀資料，不改遊戲規則；數值與效果代碼都來自 SkillDB / InnerForceDB。

## 外功分類的固定順序（資料裡有九種武器類別；畫面只顯示「已習得」涉及的那幾種）
const CATEGORY_ORDER := ["刀", "劍", "琴", "筆", "棍", "槍", "拳", "掌", "通用"]
const ELEMENTS := ["快", "遲", "柔", "剛"]

## 效果代碼 → 白話名稱（沒有的代碼不顯示內部名稱，退回招式描述）
const STATUS_NAMES := {
	"slow": "減速", "root": "定身", "blind": "致盲", "break_def": "破防", "weaken": "虛弱", "weak": "虛弱",
	"stun": "暈眩", "seal_mp": "封住內力", "poison": "中毒", "confuse": "混亂", "focus": "凝神",
	"buff_speed": "提升速度", "evasion_boost": "提升閃避", "atk_up": "提升攻擊", "stat_debuff": "削弱能力",
}

const STAT_NAMES := {
	"atk": "攻擊", "def": "防禦", "speed": "速度", "evasion": "閃避", "accuracy": "命中", "max_hp": "氣血上限", "max_mp": "內力上限",
	"str": "力量", "agi": "敏捷", "int": "智力", "con": "體能", "luck": "幸運",
	"str_flat_bonus": "力量", "agi_flat_bonus": "敏捷", "int_flat_bonus": "智力", "con_flat_bonus": "體能", "luck_flat_bonus": "幸運",
	"accuracy_flat_bonus": "命中", "max_mp_flat_bonus": "內力上限", "max_hp_flat_bonus": "氣血上限",
}

## 這位角色已習得的外功依武器類別分出來有哪些類別（照固定順序；沒有的不出現）
static func categories(skills: Array) -> Array:
	var have := {}
	for s in skills:
		have[String((s as Dictionary).get("weapon_type", "")).strip_edges()] = true
	var out: Array = []
	for c in CATEGORY_ORDER:
		if have.has(c):
			out.append(c)
	return out

static func target_text(skill: Dictionary) -> String:
	var scope := String(skill.get("target_scope", ""))
	var side := String(skill.get("target_side", ""))
	match scope:
		"self": return "自身"
		"enemy_all": return "敵方全體"
		"ally_all": return "我方全體"
		"single":
			return "單一敵人" if side == "enemy" else ("單一同伴" if side == "ally" else "單一目標")
	return "—"

## 招式效果的白話條列。一定回傳至少一行（沒有任何可翻譯的效果就退回招式描述）。
static func effect_lines(skill: Dictionary) -> Array:
	var out: Array = []
	var effects = skill.get("effects", [])
	if typeof(effects) == TYPE_ARRAY:
		for entry_any in effects:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any
			var t := String(entry.get("type", ""))
			var amount := int(entry.get("amount", 0))
			var turns := int(entry.get("turns", 0))
			match t:
				"damage":
					out.append("對目標造成 %.1f 倍攻擊力的傷害" % float(entry.get("power", skill.get("power", 1.0))))
				"heal_hp":
					out.append("回復氣血 %d" % amount)
				"mp_heal":
					out.append("回復內力 %d" % amount)
				_:
					if STATUS_NAMES.has(t):
						var parts := String(STATUS_NAMES[t])
						if amount != 0:
							parts += " %d" % absi(amount)
						if turns > 0:
							parts += "，持續 %d 回合" % turns
						out.append(parts)
	if bool(skill.get("require_free_hand", false)):
		out.append("需要至少一隻手空著")
	if out.is_empty():
		var desc := String(skill.get("description", skill.get("desc", ""))).strip_edges()
		out.append(desc if desc != "" else "（尚無效果說明）")
	return out

## 內功的「當前效果」條列：先用 InnerForceDB 現成的效果說明，再補常駐加成與傷害加成
static func force_effect_lines(force: Dictionary, actor: Dictionary) -> Array:
	var out: Array = []
	var line := String(InnerForceDB.get_effect_description_line(force, actor))
	if line == "":
		line = String(InnerForceDB.get_effect_summary_line(force, actor))
	if line != "":
		for part in line.split("\n"):
			if String(part).strip_edges() != "":
				out.append(String(part).strip_edges())
	var bonus = force.get("stat_bonus", {})
	if typeof(bonus) == TYPE_DICTIONARY:
		for k in (bonus as Dictionary).keys():
			var label := String(STAT_NAMES.get(String(k), ""))
			if label != "":
				out.append("%s %+d" % [label, int(bonus[k])])
	var boost_weapon := String(force.get("boost_weapon", ""))
	var boost_pct := float(force.get("boost_damage_pct", 0.0))
	if boost_weapon != "" and boost_pct > 0.0:
		out.append("%s類武學傷害 +%d%%" % [boost_weapon, int(round(boost_pct * 100.0))])
	if bool(force.get("boost_require_unarmed", false)):
		out.append("需要空手")
	if out.is_empty():
		out.append("（尚無效果說明）")
	return out

static func force_name(force: Dictionary) -> String:
	return "%s%s" % [String(force.get("prefix", "???")), String(force.get("type", ""))]
