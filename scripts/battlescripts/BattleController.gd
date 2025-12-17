extends Node

const ToneMapScript := preload("res://scripts/battlestyles/ToneMap.gd")
var tone_map := ToneMapScript.new()

var player_party: Array = []
var enemy_party: Array = []

var battle_ui: Node = null
var skill_db: Node = null
var action_log_ui: LogPanel = null  # ✅ LogPanel 掛的腳本

@onready var skill_resolver = $SkillResolver
@onready var emotion_modulator = $EmotionModulator
@onready var inventory_sync = $InventorySync
@onready var victory_handler = $VictoryHandler
@onready var skill_executor = $SkillExecutor
@onready var team_data_manager := get_node("/root/BattleScene/TeamDataManager")
@onready var turn_manager := $TurnManager
@onready var enemy_ai := get_parent().get_node_or_null("EnemyAI") # 敵人 AI 掛載

func _ready() -> void:
	call_deferred("_init_battle_safe")


func _init_battle_safe() -> void:
	var root = get_parent()
	if root == null:
		push_error("❌ BattleController 無法找到父節點 BattleScene。")
		return

	if root.has_node("CharacterDataManager"):
		skill_db = root.get_node("CharacterDataManager")
	else:
		push_error("❌ 無法找到 CharacterDataManager")

	if root.has_node("BattleUI"):
		battle_ui = root.get_node("BattleUI")
		battle_ui.character_skill_db = skill_db
		battle_ui.combat_controller = self
		battle_ui.player_action_complete.connect(_on_player_action_complete)

		# ✅ 這裡往 BattleUI 裡面抓 LogPanel！
		if battle_ui.has_node("LogPanel"):
			action_log_ui = battle_ui.get_node("LogPanel")
			print("📦 成功從 BattleUI 找到 LogPanel：", action_log_ui)
		else:
			push_error("❌ BattleUI 裡面找不到 LogPanel 節點")
	else:
		push_error("❌ 無法找到 BattleUI")

	# 🧩 取得玩家隊伍資料（暫時還是用 TeamData）
	player_party = TeamData.get_active_party()
	if player_party.is_empty():
		# ⭐ Fallback：單人測試用，也補上 max_hp / mp / max_mp，跟 TeamData schema 對齊
		player_party = [
			{
				"id": "liuyu",
				"name": "劉語塵",
				"speed": 8,
				"hp": 150,
				"max_hp": 150,
				"mp": 60,
				"max_mp": 60,
				"atk": 20,
				"def": 5,
				"element": "快",
				"weapon_1": "劍",
				"weapon_2": "刀",
				"inner_force": {
					"prefix": "清風",
					"type": "訣",
					"boost_weapon": "刀"
				}
			}
		]
		TeamData.set_active_party(player_party)

	# 🧩 Phase 1：敵人資料用「完整 schema」，之後可以直接搬到 EnemyDatabase
	enemy_party = [
		{
			"id": "enemy1",
			"name": "滯水語魅",
			"hp": 40,
			"atk": 15,
			"def": 3,
			"speed": 7,
			"element": "遲",
			"weapon_1": "掌",
		},
		{
			"id": "enemy2",
			"name": "磐石語魅",
			"hp": 50,
			"atk": 10,
			"def": 8,
			"speed": 4,
			"element": "剛",
			"weapon_1": "拳",
			"portrait_path": "res://assets/sprites/NPC/Enemy/Stone_TP.png"
		}
	]

	# ⭐ 新增：標記這些是敵方單位，給語氣系統 & 之後 AI / UI 用
	for e in enemy_party:
		e["max_hp"] = int(e.get("max_hp", e.get("hp", 0)))
		e["is_enemy"] = true

	# ⭐ 戰鬥開始前，把隊伍資料丟給 BattleUI
	if battle_ui:
		battle_ui.set_teams(player_party, enemy_party)

	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.start_battle(player_party, enemy_party)


func _log(msg: String) -> void:
	print("📨 LogPanel 記錄中：", msg)
	if action_log_ui:
		if action_log_ui.has_method("log"):
			action_log_ui.log(msg)          # 白字戰報＋打字機
		elif action_log_ui.has_method("log_narration"):
			action_log_ui.log_narration(msg)
		else:
			action_log_ui.append_text(msg + "\n")


# ✅ 系統訊息專用（優先用 LogPanel.log_system）
func _log_system(msg: String) -> void:
	if action_log_ui and action_log_ui.has_method("log_system"):
		action_log_ui.log_system(msg)
	else:
		_log(msg)


func _on_turn_started(actor: Dictionary) -> void:
	# 🛡️ 如果上一輪你是選防禦，那現在輪到你新的回合，就把防禦狀態解除
	if bool(actor.get("defending", false)):
		actor["defending"] = false
		if battle_ui:
			battle_ui.clear_defend_motion(actor)  # 下面第 2 步會加這個函式

	# 🪦 安全檢查：如果這個人已經倒下，就直接略過他的回合
	var hp := int(actor.get("hp", 0))
	if hp <= 0:
		print("⚰️ %s 已經倒下，略過他的回合。" % actor.get("name", "???"))
		turn_manager.end_turn()
		return
		
	# 🟥 敵方回合
	if actor in enemy_party:
		var name := String(actor.get("name", "???"))
		_log_system("輪到「%s」行動。" % name)

		await perform_enemy_action(actor)
		turn_manager.end_turn()
		return

	# 🟦 我方回合
	if actor in player_party and battle_ui:
		print("🟦 Begin UI for: ", actor.get("name", "???"))
		battle_ui.begin_turn(actor)

func _on_turn_ended(actor: Dictionary) -> void:
	# ❌ 不在這裡清 defending，單純交棒就好
	turn_manager.next_turn()

func _on_player_action_complete(actor: Dictionary) -> void:
	var current = turn_manager.get_current_actor()
	if current.get("id", "") != actor.get("id", ""):
		print("⚠️ 回報角色與當前行動者不一致，當成忽略")
		return

	# ✅ 等逐字機全部跑完再結束玩家回合
	if action_log_ui and action_log_ui.has_method("wait_for_all_logs"):
		await action_log_ui.wait_for_all_logs()

	turn_manager.end_turn()


func perform_enemy_action(enemy: Dictionary) -> void:
	await get_tree().process_frame

	var skills = skill_db.get_skills(enemy.get("id", ""))
	var inner_force = enemy.get("inner_force", {})
	if enemy_ai == null:
		push_error("❌ 找不到 EnemyAI 節點")
		return

	var action = enemy_ai.get_action(enemy, player_party, skills)
	if action.is_empty():
		push_warning("❗ 敵人 AI 回傳空值，略過此回合")
		await get_tree().create_timer(0.3).timeout
		return

	var skill = action.skill
	var target = action.target
	var result = skill_executor.execute(enemy, target, skill, inner_force)

	# 🎬 敵人出招：描述 → 動畫 → 傷害結果
	await _play_attack_cinematic(enemy, target, skill, result)

	check_battle_status()
	print("🔚 %s 結束行動，交棒給下一位" % enemy.get("name", "???"))


func safe_end_turn() -> void:
	if turn_manager:
		turn_manager.end_turn()


func check_battle_status() -> void:
	if player_party.all(func(p): return p["hp"] <= 0):
		victory_handler.defeat()
	elif enemy_party.all(func(e): return e["hp"] <= 0):
		victory_handler.victory()


# ⭐ 決定這招要用哪個 FX 動畫
func _get_fx_id_for_skill(skill_data: Dictionary, attacker: Dictionary) -> String:
	var fx_id := String(skill_data.get("fx_id", ""))
	if fx_id != "":
		return fx_id

	# 若 skill 沒特別指定，就用武器推一個預設
	var weapon := String(skill_data.get("weapon_type", attacker.get("weapon_1", "")))

	match weapon:
		"劍":
			return "fx_slash_sword"
		"刀":
			return "fx_slash_blade"
		"琴":
			return "fx_qin_pillar"  # 或 fx_wave_qin_water，看你實際命名
		"拳", "掌":
			return "fx_hit_fist"
		"筆":
			return "fx_brush_stroke"
		_:
			return "fx_hit_fist"       # 萬用打擊


# ⭐ 核心：攻擊演出流程（攻擊描述 → 動畫 → 傷害文字）
func _play_attack_cinematic(attacker: Dictionary, target: Dictionary, skill_data: Dictionary, result: Dictionary) -> void:
	var logs: Array = []
	if result.has("log"):
		logs = result.log

	# ❶ weapon_openers：先播第一行描述
	if logs.size() > 0:
		_log(logs[0])
		if action_log_ui and action_log_ui.has_method("wait_for_all_logs"):
			await action_log_ui.wait_for_all_logs()

	# ❷ 攻擊方前傾 → FX → 受擊閃爍
	if battle_ui and not target.is_empty():
		# 攻擊方動作
		battle_ui.play_attack_motion(attacker)
		await get_tree().create_timer(0.12).timeout

		# FX：根據 skill / 武器決定動畫
		var fx_id := _get_fx_id_for_skill(skill_data, attacker)
		if fx_id != "":
			battle_ui.play_hit_fx_on_target(target, fx_id)

		# ⭐ 判斷是否處於防禦狀態
		var is_blocking := bool(target.get("defending", false))
		if is_blocking:
			battle_ui.play_guard_react(target)
		else:
			battle_ui.play_damage_react(target)

		await get_tree().create_timer(0.25).timeout

	# ❸ 在這一刻才更新血條 / MP（SkillExecutor 早就算完，但 UI 延後刷新）
	_update_ui_for_actor(target)
	_update_ui_for_actor(attacker)

	# ❹ 播放剩下的 log（包含「擊中 %s，造成 %d 點傷害！」）
	if logs.size() > 1:
		for i in range(1, logs.size()):
			_log(logs[i])

		if action_log_ui and action_log_ui.has_method("wait_for_all_logs"):
			await action_log_ui.wait_for_all_logs()


# ✅ 改版：可以接受指定 target，給玩家選目標用
func execute_action(actor: Dictionary, skill_data: Dictionary, target: Dictionary = {}) -> void:
	var effect: String = str(skill_data.get("effect", ""))
	var scope: String  = str(skill_data.get("target_scope", "single"))
	var side: String   = str(skill_data.get("target_side", "enemy"))

	# =========================
	# 0️⃣ 支援 / 補血技能分流（保持你現在的回血邏輯）
	# =========================
	if effect == "heal_hp" or effect == "mp_heal" or side == "ally":
		await _execute_support_heal_action(actor, skill_data, target)
		check_battle_status()
		return

	# =========================
	# 1️⃣ AOE：全體敵方（例：翔龍十八掌）
	# =========================
	if scope == "enemy_all" and side == "enemy":
		if enemy_party.is_empty():
			push_warning("❗ execute_action：敵方隊伍為空，AOE 無目標。")
			return

		var inner_force = actor.get("inner_force", {})

		# 🎭 顯示用的招式名稱（含 prefix）
		var display_skill_name: String = str(skill_data.get("name", "???"))
		if inner_force.has("prefix") and inner_force.has("boost_weapon"):
			var bw: String = str(inner_force.get("boost_weapon", ""))
			var wt: String = str(skill_data.get("weapon_type", ""))
			if bw == wt:
				display_skill_name = "%s%s" % [
					str(inner_force.get("prefix", "")),
					display_skill_name
				]

		var actor_name: String = str(actor.get("name", "???"))

		# 🌊 全場級起手描述
		_log("%s 使出「%s」，掌風層層拍出，氣浪如驟雨般席捲整個敵陣。" % [
			actor_name,
			display_skill_name
		])

		# 先把每個敵人的結果算好
		var aoe_results: Array = []  # [ { "enemy": enemy_dict, "result": result_dict }, ... ]

		for enemy in enemy_party:
			if typeof(enemy) != TYPE_DICTIONARY:
				continue
			if int(enemy.get("hp", 0)) <= 0:
				continue

			var r: Dictionary = skill_executor.execute(actor, enemy, skill_data, inner_force)
			aoe_results.append({
				"enemy": enemy,
				"result": r
			})

		# 🎬 出手動畫只播一次
		if battle_ui and battle_ui.has_method("play_attack_motion"):
			battle_ui.play_attack_motion(actor)
			await get_tree().create_timer(0.35).timeout

		# 屬性剋制表只在這邊用
		var ke_system := {
			"快": "遲",
			"遲": "柔",
			"柔": "剛",
			"剛": "快"
		}
		var user_element: String = str(actor.get("element", ""))

		var any_down := false

		# 💥 全體受擊動畫＋每隻各自敘事＋傷害數字
		for entry in aoe_results:
			var enemy: Dictionary = entry["enemy"]
			var r: Dictionary     = entry["result"]

			# 動畫：敵人抖一下（幾乎同時）
			if battle_ui and battle_ui.has_method("play_damage_react"):
				battle_ui.play_damage_react(enemy)

			var name_e: String = str(enemy.get("name", "???"))
			var dmg_int: int = int(r.get("damage", 0))

			# ▶ 狀態旗標
			var target_element: String = str(enemy.get("element", ""))
			var is_crit: bool  = bool(r.get("crit", false))
			var is_down: bool  = bool(r.get("target_down", false))

			# 簡單算一下「有沒有剋到」：快>遲>柔>剛>快
			var has_ke_advantage := false
			match user_element:
				"快":
					has_ke_advantage = (target_element == "遲")
				"遲":
					has_ke_advantage = (target_element == "柔")
				"柔":
					has_ke_advantage = (target_element == "剛")
				"剛":
					has_ke_advantage = (target_element == "快")
				_:
					has_ke_advantage = false

			# ▶ 交給 ToneMap 的「狀態 key」
			var state_key := "normal"
			if is_down:
				state_key = "down"
			elif has_ke_advantage:
				state_key = "ke"
			elif is_crit:
				state_key = "crit"

			# ▶ 額外敘事：完全交給 ToneMap
			if tone_map != null:
				# 第二個 key：把「技能 + 狀態」打包，讓你在 ToneMap 裡自由配招式台詞
				var skill_key := str(skill_data.get("id", display_skill_name))
				var tone_key  := "%s|%s" % [skill_key, state_key]
				var target_id := str(enemy.get("id", ""))

				var extra_line := tone_map.get_tone_text("aoe_suffer", tone_key, target_id)
				if extra_line != "":
					_log(extra_line)

			# 🔢 數字戰報
			if dmg_int > 0:
				var dmg_str := "[color=#ff8080]%d[/color]" % dmg_int
				_log("%s 受到 %s 點傷害。" % [
					name_e,
					dmg_str
				])

			# 倒地判定＋經典死亡台詞
			if is_down:
				enemy["hp"] = 0
				enemy["is_dead"] = true
				any_down = true
				_log("%s 倒下，傷勢過重，已無力再戰。" % name_e)

		await get_tree().create_timer(0.2).timeout

		if any_down and battle_ui:
			battle_ui.update_enemy_panel()

		check_battle_status()
		return

	# =========================
	# 2️⃣ 原本的單體攻擊流程
	# =========================
	if enemy_party.is_empty() and target.is_empty():
		push_warning("❗ execute_action 被呼叫時沒有敵人可以攻擊")
		return

	var actual_target: Dictionary
	if target.is_empty():
		actual_target = enemy_party[0]
	else:
		actual_target = target

	var inner_force_single = actor.get("inner_force", {})
	var result_single = skill_executor.execute(actor, actual_target, skill_data, inner_force_single)

	# 🎬 單體：照舊跑 cinematic（描述＋動畫）
	await _play_attack_cinematic(actor, actual_target, skill_data, result_single)

	if result_single.target_down:
		actual_target["hp"] = 0
		actual_target["is_dead"] = true
		if battle_ui:
			battle_ui.update_enemy_panel()

	check_battle_status()



func defend_action(actor: Dictionary) -> void:
	actor["defending"] = true
	_log("%s 採取了防禦姿態。" % actor.get("name", "???"))

# =========================
#  支援系技能：回血 / 回內力
#  - 氣療掌：單體補血
#  - 墨筆舒心：全體少量補血
# =========================
func _execute_support_heal_action(user: Dictionary, skill_data: Dictionary, target: Dictionary) -> void:
	var user_name: String  = user.get("name", "???")
	var user_id: String    = user.get("id", "")
	var skill_name: String = skill_data.get("name", "???")
	var effect: String     = str(skill_data.get("effect", "heal_hp"))
	var scope: String      = str(skill_data.get("target_scope", "single"))  # "single" / "ally_all"

	# 如果是補內力型技能，丟給專門的處理
	if effect == "mp_heal":
		_execute_support_mp_heal(user, skill_data, target)
		return

	# 🔸 決定要補誰：單體 or 全體
	var targets: Array[Dictionary] = []

	if scope == "ally_all":
		# 全體：抓目前還活著的我方成員
		for ally in player_party:
			if typeof(ally) == TYPE_DICTIONARY:
				var hp: int = ally.get("hp", 0)
				if hp > 0:
					targets.append(ally)
		# 若整隊都是 0 HP，理論上就不該進來，不過保險一下
		if targets.is_empty():
			targets.append(user)
	else:
		# 單體：有選就用選的，沒選就補自己
		var actual_target: Dictionary = target
		if actual_target.is_empty():
			actual_target = user
		targets.append(actual_target)

	# 🔢 回復量：優先 heal_amount，沒有就用 power
	var base_amount: int = int(skill_data.get("heal_amount", skill_data.get("power", 0)))
	if base_amount <= 0:
		base_amount = 1

	var any_restored: bool = false
	var restored_map: Dictionary = {}  # target_id → restored amount

	# 🔁 對每個目標做溢補檢查與實際回血
	for t in targets:
		var before_hp: int = int(t.get("hp", 0))
		var max_hp: int    = int(t.get("max_hp", before_hp))
		if max_hp <= 0:
			max_hp = before_hp if before_hp > 0 else 1

		var after_hp: int = min(before_hp + base_amount, max_hp)
		var restored: int = after_hp - before_hp
		t["hp"] = after_hp

		if restored > 0:
			any_restored = true
			restored_map[t.get("id", str(t))] = restored

	# 🔹 完全沒補到（全隊都滿血）：只吐槽，不播特效
	if not any_restored:
		var line_no: String

		if scope == "ally_all":
			# 墨筆舒心那種全體治療時，全都滿血版本
			if skill_name == "墨筆舒心":
				line_no = "%s 揮筆在空中勾勒了一圈氣韻，結果一掌一筆拍下去，才發現眾人都是帶傷上陣的強者——至少這一回，不是傷在肉上。" % user_name
			elif skill_name == "氣療掌":
				line_no = "%s 連環出掌為眾人理氣，拍了半圈才發現大家氣血都穩得很，倒像是在幫人暖身。" % user_name
			else:
				line_no = "%s 展開「%s」在隊中流轉一圈，真氣繞了一圈才發現，這一陣忙裡忙外，多半只是圖個心安。" % [
					user_name,
					skill_name
				]
		else:
			# 單體版本（氣療掌原本的吐槽）
			var target_name: String = targets[0].get("name", "???")
			if user_name == target_name:
				line_no = "%s 運起「%s」順了順氣，才發現自己好得很，這一掌反倒像是在給自己壓驚。" % [
					user_name,
					skill_name
				]
			else:
				line_no = "%s 掌心貼上 %s 背心運起「%s」，手一搭上去才發現對方毫髮無傷，只好當作幫人暖了一下背。" % [
					user_name,
					target_name,
					skill_name
				]

		_log(line_no)

		# 同步 UI
		for t in targets:
			_update_ui_for_actor(t)
		return

	# 🔹 有補到：敘事台詞 + 戰報數字 + 動畫/特效

	# ✍️ 先打一句「出招說明」
	if scope == "ally_all":
		if skill_name == "墨筆舒心":
			_log("%s 提筆在半空寫下一個看不見的字，墨意化開時，整個隊伍的呼吸都默契地輕了一拍。" % user_name)
		elif skill_name == "氣療掌":
			_log("%s 站在眾人中央，雙掌一圈圈推送出去，真氣如水波般層層蕩開。" % user_name)
		else:
			_log("%s 展開「%s」，真氣在隊伍間迴旋，帶走了幾分血腥氣與疲憊。" % [
				user_name,
				skill_name
			])
	else:
		var target0: Dictionary = targets[0]
		var target_name: String = target0.get("name", "???")

		if skill_name == "墨筆舒心":
			if user_name == target_name:
				_log("%s 提筆在掌心虛劃幾筆，墨意沉入胸口，壓著的悶氣隨著呼吸一點點散去。" % user_name)
			else:
				_log("%s 以筆尖在 %s 背心輕點幾下，墨意順脊骨而下，亂掉的氣息逐漸平復。" % [
					user_name,
					target_name
				])
		elif skill_name == "氣療掌":
			if user_name == target_name:
				_log("%s 雙掌覆在丹田之上，真氣回流，自體內一寸寸推開積壓的淤滯。" % user_name)
			else:
				_log("%s 掌心貼上 %s 背心，一股溫潤真氣沿著經脈緩緩推送，替他把隱痛揉散。" % [
					user_name,
					target_name
				])
		else:
			if user_name == target_name:
				_log("%s 運起療傷心法，真氣在體內繞行一圈，帶走了胸口暗壓的疼意。" % user_name)
			else:
				_log("%s 將內力緩緩送入 %s 經脈，替他拾起快散掉的氣勢。" % [
					user_name,
					target_name
				])

	# 🧮 再來是戰報數字
	if scope == "ally_all":
		# 先來一句總宣布
		_log("「%s」的氣息在隊中流轉，眾人的傷勢都有所緩解。" % skill_name)

		for t in targets:
			var tid: String = t.get("id", str(t))
			if not restored_map.has(tid):
				continue
			var restored: int = int(restored_map[tid])
			if restored <= 0:
				continue

			var name_t: String = t.get("name", "???")
			var amount_str := "[color=#80ff80]%d[/color]" % restored
			_log("%s 的生命恢復了 %s 點。" % [
				name_t,
				amount_str
			])
	else:
		var t0: Dictionary = targets[0]
		var tid0: String = t0.get("id", str(t0))
		var restored0: int = int(restored_map.get(tid0, 0))
		var amount_str0 := "[color=#80ff80]%d[/color]" % restored0
		var target_name0: String = t0.get("name", "???")

		var result_line: String
		if user_name == target_name0:
			result_line = "%s 使出「%s」，恢復了 %s 點生命。" % [
				user_name,
				skill_name,
				amount_str0
			]
		else:
			result_line = "%s 對 %s 施展「%s」，恢復了 %s 點生命。" % [
				user_name,
				target_name0,
				skill_name,
				amount_str0
			]
		_log(result_line)

	# 🎞️ 動畫：施術者前傾，目標播補血特效
	if battle_ui:
		if battle_ui.has_method("play_attack_motion"):
			battle_ui.play_attack_motion(user)

		if battle_ui.has_method("play_heal_react"):
			for t in targets:
				battle_ui.play_heal_react(t)

	# 🔁 同步 UI
	for t in targets:
		_update_ui_for_actor(t)
	_update_ui_for_actor(user)

# 🔹 預留：補內力型支援技能（如果之後有「回內力心法」再用）
func _execute_support_mp_heal(user: Dictionary, skill_data: Dictionary, target: Dictionary) -> void:
	var user_name: String   = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var skill_name: String  = skill_data.get("name", "???")

	var base_amount: int = skill_data.get("heal_amount", skill_data.get("power", 0))
	if base_amount <= 0:
		base_amount = 1

	var before_mp: int = int(target.get("mp", 0))
	var max_mp: int    = int(target.get("max_mp", before_mp))
	if max_mp <= 0:
		max_mp = before_mp if before_mp > 0 else 1

	var after_mp: int = min(before_mp + base_amount, max_mp)
	var restored: int = after_mp - before_mp
	target["mp"] = after_mp

	if restored <= 0:
		var line_no: String
		if user_name == target_name:
			line_no = "%s 調息運功，卻發現丹田真氣早已盈滿，只剩一聲悶悶的嘆息。" % user_name
		else:
			line_no = "%s 伸掌替 %s 理氣補元，真氣一探入卻只覺得對方氣海穩得很。" % [
				user_name,
				target_name
			]
		_log(line_no)
		_update_ui_for_actor(target)
		return

	var amount_str := "[color=#80ffe0]%d[/color]" % restored
	var line_ok: String
	if user_name == target_name:
		line_ok = "%s 運轉「%s」，丹田真氣重新充盈了 %s 點。" % [
			user_name,
			skill_name,
			amount_str
		]
	else:
		line_ok = "%s 以「%s」替 %s 補了一記真氣，恢復了 %s 點內力。" % [
			user_name,
			skill_name,
			target_name,
			amount_str
		]
	_log(line_ok)

	if battle_ui and battle_ui.has_method("play_heal_react"):
		battle_ui.play_heal_react(target)

	_update_ui_for_actor(target)
	_update_ui_for_actor(user)

# 固定傷害炸彈：扣固定數值，不吃防禦／剋制
func _apply_bomb_damage_to_target(
	user: Dictionary,
	item: Dictionary,
	target: Dictionary,
	effect_key: String
) -> void:
	if target.is_empty():
		return

	var power: int = int(item.get("amount", 0))
	if power <= 0:
		push_warning("⚠️ 炸彈道具 %s 的 amount <= 0，沒有造成傷害。" % str(item.get("id", "unknown_item")))
		return

	var before_hp: int = int(target.get("hp", 0))
	if before_hp <= 0:
		return

	var after_hp: int = max(before_hp - power, 0)
	var dmg: int = before_hp - after_hp
	target["hp"] = after_hp

	var tname := str(target.get("name", "???"))
	var tid   := str(target.get("id", ""))

	# 🎬 FX + 抖動
	if battle_ui:
		if battle_ui.has_method("play_hit_fx_on_target"):
			battle_ui.play_hit_fx_on_target(target, "fx_hit_fist")  # 先借用萬用打擊
		if battle_ui.has_method("play_damage_react"):
			battle_ui.play_damage_react(target)

	# 敘事：被炸到的感覺
	if tone_map != null:
		var suffer_line := tone_map.get_tone_text("item_suffer", effect_key, tid)
		if suffer_line != "":
			_log(suffer_line)

	# 數字戰報
	var dmg_str := "[color=#ff8080]%d[/color]" % dmg
	_log("%s 受到 %s 點傷害。" % [tname, dmg_str])

	if after_hp <= 0:
		target["is_dead"] = true
		_log("%s 倒下了，已無力再戰。" % tname)

	_update_ui_for_actor(target)

# 單體霹靂彈：打指定 target，沒選就打第一隻敵人
func _apply_bomb_single(user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	if target.is_empty():
		if enemy_party.is_empty():
			return
		target = enemy_party[0]

	# 使用者敘事（丟出去的動作）
	if tone_map != null:
		var use_line := tone_map.get_tone_text("item_use", "bomb_single", str(user.get("id", "")))
		if use_line != "":
			_log(use_line)

	_apply_bomb_damage_to_target(user, item, target, "bomb_single")


# 轟雷霹靂彈：敵方全體
func _apply_bomb_aoe(user: Dictionary, item: Dictionary) -> void:
	if enemy_party.is_empty():
		return

	# 使用者敘事（起手）
	if tone_map != null:
		var use_line := tone_map.get_tone_text("item_use", "bomb_aoe", str(user.get("id", "")))
		if use_line != "":
			_log(use_line)

	# 對每一隻活著的敵人套固定傷害
	for enemy in enemy_party:
		if typeof(enemy) != TYPE_DICTIONARY:
			continue
		if int(enemy.get("hp", 0)) <= 0:
			continue

		_apply_bomb_damage_to_target(user, item, enemy, "bomb_aoe")



func use_item(user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	# ✅ 先消耗道具
	InventorySync.consume_item(item.get("id", ""))

	var effect: String      = item.get("effect", "")
	var user_name: String   = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String   = item.get("name", "???")
	var user_id: String     = user.get("id", "")
	var target_id: String   = target.get("id", "")

	match effect:
		# === 回復 HP ===
		"heal", "heal_hp":
			var amount: int = item.get("amount", 0)

			var before_hp: int = target.get("hp", 0)
			var max_hp: int = target.get("max_hp", before_hp)
			var after_hp: int = min(before_hp + amount, max_hp)

			var restored: int = after_hp - before_hp
			target["hp"] = after_hp

			if restored <= 0:
				# ✅ 沒補到：只有吐槽，不講 item_use 的文青藥香
				var line_no_effect: String
				if user_name == target_name:
					line_no_effect = "%s 看了看 %s，還是吞了下去——反正都帶在身上了，只是這一回似乎派不上用場。" % [
						user_name,
						item_name
					]
				else:
					line_no_effect = "%s 好心替 %s 用上 %s，結果傷勢早已無礙，藥力幾乎只是圖個心安。" % [
						user_name,
						target_name,
						item_name
					]
				_log(line_no_effect)
			else:
				# ✅ 有補到：先講 ToneMap 敘事，再講戰報
				if tone_map != null:
					var extra_hp := tone_map.get_tone_text("item_use", "heal", user_id)
					if extra_hp != "":
						_log(extra_hp)

				var amount_str := "[color=#80ff80]%d[/color]" % restored

				var line: String
				if user_name == target_name:
					line = "%s 使用了 %s，恢復了 %s 點生命。" % [
						user_name,
						item_name,
						amount_str
					]
				else:
					line = "%s 對 %s 使用了 %s，恢復了 %s 點生命。" % [
						user_name,
						target_name,
						item_name,
						amount_str
					]

				_log(line)

				# ✨ 有實際回復才播綠光特效
				if battle_ui and battle_ui.has_method("play_heal_react"):
					battle_ui.play_heal_react(target)

		# === 回復 MP（內力）===
		"mp_heal":
			var amount_mp: int = item.get("amount", 0)

			var before_mp: int = target.get("mp", 0)
			var max_mp: int = target.get("max_mp", before_mp)
			var after_mp: int = min(before_mp + amount_mp, max_mp)

			var restored_mp: int = after_mp - before_mp
			target["mp"] = after_mp

			if restored_mp <= 0:
				# ✅ 沒補到內力：只有吐槽，不講 item_use 的 mp 敘事
				var line_no_mp: String
				if user_name == target_name:
					line_no_mp = "%s 喝下了 %s，但真氣早已盈滿，只剩苦澀的味道在舌尖空打轉。" % [
						user_name,
						item_name
					]
				else:
					line_no_mp = "%s 對 %s 使用了 %s，但對方的內力早已飽和，頂多算潤潤嗓子。" % [
						user_name,
						target_name,
						item_name
					]
				_log(line_no_mp)
			else:
				# ✅ 有補到內力：正常 item_use 敘事 + 戰報
				if tone_map != null:
					var extra_mp := tone_map.get_tone_text("item_use", "mp_heal", user_id)
					if extra_mp != "":
						_log(extra_mp)

				var amount_mp_str := "[color=#80ffe0]%d[/color]" % restored_mp

				var line2: String
				if user_name == target_name:
					line2 = "%s 使用了 %s，恢復了 %s 點內力。" % [
						user_name,
						item_name,
						amount_mp_str
					]
				else:
					line2 = "%s 對 %s 使用了 %s，恢復了 %s 點內力。" % [
						user_name,
						target_name,
						item_name,
						amount_mp_str
					]

				_log(line2)

				# ✨ 有實際回復才播綠光特效
				if battle_ui and battle_ui.has_method("play_heal_react"):
					battle_ui.play_heal_react(target)

		# === 純速度 BUFF ===
		"buff_speed":
			var amount_spd: int = item.get("amount", 0)

	# 1️⃣ 先算數值
			var before_spd: int = target.get("speed", 0)
			var after_spd: int = before_spd + amount_spd
			target["speed"] = after_spd

	# 2️⃣ 敘事：施術者（item_use）＋ 被加持者（item_suffer）
			if tone_map != null:
		# 出手那個人：把輕身散／奇物交出去的動作
				var use_line := tone_map.get_tone_text("item_use", "buff_speed", user_id)
				if use_line != "":
					_log(use_line)

		# 受術者：身體變輕的感覺
				var suffer_line := tone_map.get_tone_text("item_suffer", "buff_speed", target_id)
				if suffer_line != "":
					_log(suffer_line)

	# 3️⃣ 最後是戰報數字
			var amount_spd_str := "[color=#ffd000]%d[/color]" % amount_spd
			var line_spd := "%s 受到 %s 加持，速度提升了 %s 點。" % [
				target_name,
				item_name,
				amount_spd_str
			]
			_log(line_spd)


		# === 降速 DEBUFF（例如雞爪釘）===
		"debuff_speed":
			var amount_speed: int = item.get("amount", 0)

			# 1️⃣ 出手者視角：item_use（劉語塵丟雞爪釘那句）
			if tone_map != null:
				var use_line := tone_map.get_tone_text("item_use", "debuff_speed", user_id)
				if use_line != "":
					_log(use_line)

			# 2️⃣ 實際套用數值（支援 speed / spd 兩種欄位名）
			var before_spd: int = 0
			if target.has("speed"):
				before_spd = int(target.get("speed", 0))
			elif target.has("spd"):
				before_spd = int(target.get("spd", 0))

			var after_spd: int = max(before_spd - amount_speed, 0)
			var reduced: int = before_spd - after_spd

			if target.has("speed"):
				target["speed"] = after_spd
			elif target.has("spd"):
				target["spd"] = after_spd

			# 3️⃣ 中招者視角：item_suffer（「腳下氣勁一滯…」）
			if tone_map != null:
				var suffer_line := tone_map.get_tone_text("item_suffer", "debuff_speed", target_id)
				if suffer_line != "":
					_log(suffer_line)

			# 4️⃣ 戰報
			if reduced > 0:
				var amount_str := "[color=#ffcc66]%d[/color]" % reduced
				var line3 := "%s 對 %s 使用了 %s，%s 的速度降低了 %s 點。" % [
					user_name,
					target_name,
					item_name,
					target_name,
					amount_str
				]
				_log(line3)
			else:
				var line_no_effect2 := "%s 使出 %s 想絆住 %s 的腳步，但對方氣勢如虹，幾乎沒被拖慢。" % [
					user_name,
					item_name,
					target_name
				]
				_log(line_no_effect2)

		# === 神速符 ===
		# === 神速符 ===
		"haste_talisman":
			var amount_haste: int = int(item.get("amount", 0))
			var amount_haste_str := "[color=#ffd000]%d[/color]" % amount_haste
			var is_ally: bool = target in player_party

			if tone_map != null:
				var use_line := tone_map.get_tone_text("item_use", "haste_talisman", user_id)
				if use_line != "":
					_log(use_line)

			if is_ally:
				target["speed"] = target.get("speed", 0) + amount_haste
				_log("%s 身上貼上%s，腳下似有風生，速度提升了 %s 點。" % [
					target_name, item_name, amount_haste_str
				])
			else:
				target["element"] = "快"
				_log("%s 被%s貼中，氣脈驟然加速，屬性轉為「快」。" % [
					target_name, item_name
				])

		# === 烈火符：我方 atk+ / 敵方固定傷害 ===
		"fire_talisman":
			var amount_atk: int = int(item.get("amount", 15))
			var amount_atk_str := "[color=#ff8080]%d[/color]" % amount_atk

			if target in player_party:
				target["atk"] = target.get("atk", 0) + amount_atk

				if tone_map != null:
					var use_line := tone_map.get_tone_text("item_use", "fire_talisman_ally", user_id)
					if use_line != "":
						_log(use_line)

					var suffer_line := tone_map.get_tone_text("item_suffer", "fire_talisman_ally", target_id)
					if suffer_line != "":
						_log(suffer_line)

				_log("%s 身上貼上%s，攻擊力提升 %s。" % [
					target_name, item_name, amount_atk_str
				])

			elif target in enemy_party:
				if tone_map != null:
					var use_line2 := tone_map.get_tone_text("item_use", "fire_talisman_enemy", user_id)
					if use_line2 != "":
						_log(use_line2)

				# ✅ 不改你的整套傷害系統：直接走你現有的「固定傷害套用」 helper
				var dmg_item := item.duplicate()
				dmg_item["amount"] = int(item.get("enemy_damage", 30))
				_apply_bomb_damage_to_target(user, dmg_item, target, "fire_talisman_enemy")

		# === 霹靂彈：單體固定傷害 ===
		"bomb_single":
			if target.is_empty():
				_log("%s 丟出了 %s。" % [user_name, item_name])
			else:
				_log("%s 對 %s 丟出了 %s。" % [user_name, target_name, item_name])

			_apply_bomb_single(user, item, target)

		# === 轟雷霹靂彈：敵方全體固定傷害 ===
		"bomb_aoe":
			_log("%s 拋出了 %s，準備在敵陣中引爆。" % [user_name, item_name])
			_apply_bomb_aoe(user, item)

		_:
			_log("%s 使用了 %s，但目前尚未實作 effect：%s。" % [
				user_name, item_name, effect
			])

	# ✅ 道具效果跑完後，同步 UI（避免自補 / 互補更新不同步）
	_update_ui_for_actor(target)
	_update_ui_for_actor(user)

	check_battle_status()


# ✅ 回傳某道具可以選的目標清單，給 BattleUI / TargetSelectPopup 用
func get_valid_targets_for_item(item: Dictionary, user: Dictionary) -> Array:
	var scope: String = item.get("target_scope", "ally_single")
	var effect: String = item.get("effect", "")
	var result: Array = []

	# 💡 先預留：哪些 effect 視為「復活」類型
	var revive_effects := ["revive", "revive_hp"]
	var include_dead := revive_effects.has(effect)

	match scope:
		"ally_single":
			result = _filter_targets_by_hp(player_party, include_dead)
		"enemy_single":
			result = _filter_targets_by_hp(enemy_party, include_dead)
		"enemy_all":               # 🆕 新增：敵方全體
			result = _filter_targets_by_hp(enemy_party, include_dead)
		"all_single":
			result = _filter_targets_by_hp(player_party + enemy_party, include_dead)
		"self":
			result = _filter_targets_by_hp([user], include_dead)
		_:
			result = _filter_targets_by_hp(player_party, include_dead)


	return result


# ✅ 技能用：回傳可以選的目標清單（目前預設打單體敵人）
func get_valid_targets_for_skill(skill_data: Dictionary, user: Dictionary) -> Array:
	var scope: String = skill_data.get("target_scope", "enemy_single")
	var result: Array = []

	# 之後如果要做「復活術」，可以像 item 一樣檢查 skill_data["effect"] 再決定 include_dead
	var include_dead := false

	match scope:
		"enemy_single":
			result = _filter_targets_by_hp(enemy_party, include_dead)
		"ally_single":
			result = _filter_targets_by_hp(player_party, include_dead)
		"all_enemies":
			result = _filter_targets_by_hp(enemy_party, include_dead)
		"all_allies":
			result = _filter_targets_by_hp(player_party, include_dead)
		"self":
			result = _filter_targets_by_hp([user], include_dead)
		"all":
			result = _filter_targets_by_hp(player_party + enemy_party, include_dead)
		_:
			result = _filter_targets_by_hp(enemy_party, include_dead)

	return result


# ⭐ 統一入口，依照 actor 是我方或敵人，更新對應 UI slot
func _update_ui_for_actor(actor: Dictionary) -> void:
	if battle_ui == null or actor.is_empty():
		return

	var idx := player_party.find(actor)
	if idx != -1:
		battle_ui.update_ally_status(idx, actor)
		return

	idx = enemy_party.find(actor)
	if idx != -1:
		battle_ui.update_enemy_status(idx, actor)


func _filter_targets_by_hp(source: Array, include_dead: bool) -> Array:
	var result: Array = []
	for a in source:
		var hp := int(a.get("hp", 0))
		if hp > 0 or include_dead:
			result.append(a)
	return result
