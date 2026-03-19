extends Node
class_name battlestyle_cinematic

const ToneMap = preload("res://scripts/battlestyles/ToneMap.gd")
const EnemyDB = preload("res://scripts/db/EnemyDB.gd")
var tone_map = ToneMap.new()

func describe_attack(
	user: Dictionary,
	target: Dictionary,
	skill_name: String,
	damage: int,
	context := {}
) -> Array:
	var lines: Array = []
	var user_side := _detect_target_side(user)
	var target_side := context.get("target_side", "")
	if target_side == "":
		target_side = _detect_target_side(target)

	if user_side == "enemy":
		var enemy_attack_line := _format_enemy_tone(
			tone_map.get_tone_text("enemy_attack", _resolve_enemy_archetype(user), String(user.get("id", ""))),
			user,
			target,
			skill_name
		)
		if enemy_attack_line != "":
			lines.append(enemy_attack_line)

	# === 內功氣息詞綴敘述（第一次運轉該內功時） ===
	var prefix = context.get("inner_force_prefix", "")
	if context.get("first_time_using_inner_force", false) and prefix != "":
		var tone_line: String = tone_map.get_tone_text("innerforce_applied", prefix, user.get("id", ""))
		if tone_line != "":
			lines.append(tone_line)

	# === 武器類型開場敘述 ===
	var weapon_type = context.get("weapon_type", "")
	var weapon_openers = {
		"劍": [
			"%s 長劍一指，寒光劃破長空，展開「%s」攻勢。",
			"劍氣縱橫，%s 使出「%s」，劍招凌厲逼人！"
		],
		"刀": [
			"%s 揚刀而起，「%s」氣勢如破竹，直劈向 %s。",
			"刀光斬落，%s 使出「%s」，勢不可擋！"
		],
		"拳": [
			"%s 雙拳如風，「%s」一式轟出，空氣震動！",
			"%s 喊聲一震，一拳「%s」破空而來！"
		],
		"掌": [
			"%s 吐氣開聲，掌勢如山，「%s」撼得地動山搖！",
			"%s 身形一旋，掌影連綿，「%s」驟然拍至 %s！"
		],
		"筆": [
			"%s 揮筆如劍，「%s」筆鋒直指敵首，墨氣如劍氣般爆發！",
			"濃墨淋漓，%s 使出「%s」，筆落驚風雨！"
		],
		"琴": [
			"%s 撫琴一震，旋律間藏殺機，「%s」震得 %s 氣血翻湧。",
			"音律飄渺，%s 撥弦化刃，「%s」凝聚殺意一曲！"
		]
	}

	if user_side != "enemy" and weapon_openers.has(weapon_type):
		var w_lines: Array = weapon_openers[weapon_type]
		var template: String = w_lines[randi() % w_lines.size()]
		if template.count("%s") == 2:
			lines.append(template % [user.get("name", "???"), skill_name])
		elif template.count("%s") == 3:
			lines.append(template % [user.get("name", "???"), skill_name, target.get("name", "???")])
	elif user_side != "enemy":
		var openers = [
			"在電光石火之間，%s 凝神運氣，使出「%s」。",
			"只見 %s 身形一閃，「%s」如雷霆萬鈞般擊向 %s。",
			"%s 一聲低喝，真氣貫通掌心，使出「%s」！",
			"%s 提氣縱身而上，赫然揮出「%s」！"
		]
		var opener: String = openers[randi() % openers.size()]
		if opener.count("%s") == 2:
			lines.append(opener % [user.get("name", "???"), skill_name])
		elif opener.count("%s") == 3:
			lines.append(opener % [user.get("name", "???"), skill_name, target.get("name", "???")])

	# === 元素剋制加乘敘述 ===
	if context.get("element_advantage", false):
		lines.append("此招[color=#ff2b2d]剋制[/color]屬性，氣勢凌人，%s 明顯落於下風。" % target.get("name", "???"))

	# === 暴擊敘述 ===
	if context.get("crit", false):
		lines.append("這一擊竟是會心一擊，殺氣四溢，氣勁炸裂！")

	# === 傷害主句（數值上色＋暴擊粗體） ===
	var dmg_str = "%d" % damage
	dmg_str = "[color=#ffd447]%s[/color]" % dmg_str

	if context.get("crit", false):
		dmg_str = "[color=#ffd447][b]%d[/b][/color]" % damage

	lines.append("擊中 %s，造成 %s 點傷害！" % [
		target.get("name", "???"),
		dmg_str
	])

	# === 擊倒 or 受擊反應 ===
	if context.get("target_down", false):
		var down_line := ""
		if target_side == "enemy":
			var archetype := _resolve_enemy_archetype(target)
			down_line = tone_map.get_tone_text("enemy_defeat", archetype, String(target.get("id", "")))
		if down_line == "":
			down_line = "%s 傷重倒地，已無再戰之力！" % target.get("name", "???")
		down_line = down_line.replace("{name}", String(target.get("name", "???")))
		lines.append(down_line)
	else:
		if target_side == "enemy":
			var suffer_line := _format_enemy_tone(
				tone_map.get_tone_text("enemy_suffer", _resolve_enemy_archetype(target), String(target.get("id", ""))),
				target,
				user,
				skill_name
			)
			if suffer_line != "":
				lines.append(suffer_line)
				return lines

		var hit_kind := _calc_hit_kind(context)  # normal / weak / def_normal / def_weak

		var hit_line := tone_map.get_tone_text(
			"hit",
			hit_kind,
			String(target.get("id", "")),
			target_side
		)
		if hit_line != "":
			lines.append(hit_line)

	return lines


# 判斷「被打的那一個」是我方還是敵方
func _detect_target_side(target: Dictionary) -> String:
	if bool(target.get("is_enemy", false)):
		return "enemy"
	var tid := String(target.get("id", ""))
	if tid.begins_with("enemy"):
		return "enemy"
	return "ally"


func _resolve_enemy_archetype(actor: Dictionary) -> String:
	return EnemyDB.resolve_archetype(String(actor.get("archetype", actor.get("species", ""))))


func _format_enemy_tone(template: String, actor: Dictionary, target: Dictionary, skill_name: String) -> String:
	if template == "":
		return ""
	return template \
		.replace("{name}", String(actor.get("name", "???"))) \
		.replace("{target}", String(target.get("name", "???"))) \
		.replace("{skill}", skill_name)


# 依照防禦 / 剋制情況決定 hit_kind
func _calc_hit_kind(context: Dictionary) -> String:
	var is_def: bool = bool(context.get("defending", false))
	var is_adv: bool = bool(context.get("element_advantage", false))

	if is_def and is_adv:
		return "def_weak"
	elif is_def:
		return "def_normal"
	elif is_adv:
		return "weak"
	else:
		return "normal"
