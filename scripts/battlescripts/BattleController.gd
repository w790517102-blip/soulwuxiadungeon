extends Node

const ToneMapScript = preload("res://scripts/battlestyles/ToneMap.gd")
const ItemDB = preload("res://scripts/db/ItemDB.gd")
const BattleIntroDB = preload("res://scripts/db/BattleIntroDB.gd")
const EnemyDB = preload("res://scripts/db/EnemyDB.gd")
const StatusEffectManagerScript = preload("res://scripts/battle/StatusEffectManager.gd")
var tone_map = ToneMapScript.new()
var status_manager = StatusEffectManagerScript.new()

var player_party: Array = []
var enemy_party: Array = []

var battle_ui: Node = null
var skill_db: Node = null
var action_log_ui: LogPanel = null  # ✅ LogPanel 掛的腳本
var last_round_logged: int = -1
var last_round_regen: int = -1
var battle_finished: bool = false
var _ending: bool = false
var _player_base_snapshot: Dictionary = {}
var _pending_ally_down_reactions: Array = []
var battle_context: Dictionary = {}
var ruleset: Dictionary = {}
var regen_policy: Dictionary = {}

const GAME_OVER_NARRATION_LINES := [
	"你們已用盡全力對抗強敵，卻仍在這場惡戰中敗下陣來。",
	"滿腔俠義與未竟心願，終究沒能走出這一戰的風塵，只得在此刻沉入歷史的餘燼之中。",
	"從今往後，這片江湖不再有你們親自踏過的足跡，",
	"可那些曾燃燒過的熱血、曾守住的情義、曾照亮彼此的微光，卻不會就此消失。",
	"後來的人也許不再見到你們，卻仍會在傳聞與故事裡，記得你們曾經如此認真地活過、戰過。"
]

@onready var skill_resolver = $SkillResolver
@onready var emotion_modulator = $EmotionModulator
@onready var inventory_sync = $InventorySync
@onready var victory_handler = $VictoryHandler
@onready var skill_executor = $SkillExecutor
@onready var item_dispatcher: ItemEffectDispatcher = ItemEffectDispatcher.new()
@onready var team_data_manager = get_node_or_null("/root/TeamData")
@onready var turn_manager = $TurnManager
@onready var enemy_ai = get_parent().get_node_or_null("EnemyAI") # 敵人 AI 掛載

func _ready() -> void:
	if victory_handler == null:
		push_error("❌ VictoryHandler missing in battle scene!")
	else:
		print("[BattleController] VictoryHandler=", victory_handler)
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

	var battle_ui_node = root.get_node_or_null("BattleUILayer/BattleUI")
	if battle_ui_node == null:
		battle_ui_node = root.get_node_or_null("BattleUI")

	if battle_ui_node != null:
		battle_ui = battle_ui_node
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

	# ⭐ 戰鬥開始前，把隊伍資料丟給 BattleUI
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.round_ended.connect(_on_round_ended)
	print("✅ BattleController 完成初始化，等待外部 start_battle(context)。")

func start_battle(context: Dictionary) -> void:
	if not context.has("player_party") or not context.has("enemy_party"):
		push_error("❌ BattleContext 缺少 player_party 或 enemy_party。")
		return

	var ctx_players = context.get("player_party", [])
	var ctx_enemies = context.get("enemy_party", [])
	if ctx_players.is_empty() or ctx_enemies.is_empty():
		push_error("❌ BattleContext 的 player_party / enemy_party 不可為空。")
		return

	battle_context = context
	player_party = ctx_players
	enemy_party = ctx_enemies
	_pending_ally_down_reactions.clear()
	ruleset = context.get("ruleset", {})
	regen_policy = context.get("regen_policy", {})
	_snapshot_player_base_stats()
	_apply_equipment_bonuses()
	_sync_actor_weapon_types()

	for p in player_party:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		p["max_hp"] = int(p.get("max_hp", p.get("hp", 0)))
		p["max_mp"] = int(p.get("max_mp", p.get("mp", 0)))

	for i in range(enemy_party.size()):
		var e = enemy_party[i]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		e["max_hp"] = int(e.get("max_hp", e.get("hp", 0)))
		e["is_enemy"] = true
		if not e.has("ui_index"):
			e["ui_index"] = i
		print("[EnemyInit]", e.get("id", ""), " exp=", e.get("exp", 0), " gold=", e.get("gold", {}), " drops=", e.get("drops", []))

	if enemy_ai and enemy_ai.has_method("begin_battle"):
		enemy_ai.begin_battle(enemy_party)

	if battle_ui:
		battle_ui.set_teams(player_party, enemy_party)
		battle_ui.apply_ruleset(ruleset)

	battle_finished = false
	last_round_logged = -1
	last_round_regen = -1

	await _run_battle_opening_sequence(context)
	turn_manager.start_battle(player_party, enemy_party)

func _apply_equipment_bonuses() -> void:
	if InventorySync == null:
		return
	for p in player_party:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var bonus := InventorySync.get_equipment_stat_bonus(str(p.get("id", "")))
		var inner_force: Dictionary = p.get("inner_force", {})
		var force_bonus: Dictionary = inner_force.get("stat_bonus", {})
		var bonus_atk := int(bonus.get("atk", 0)) + int(force_bonus.get("atk", 0))
		var bonus_def := int(bonus.get("def", 0)) + int(force_bonus.get("def", 0))
		var bonus_speed := int(bonus.get("speed", 0)) + int(force_bonus.get("speed", 0))
		var bonus_accuracy := int(bonus.get("accuracy", 0)) + int(force_bonus.get("accuracy", 0))
		var bonus_evasion := int(bonus.get("evasion", 0)) + int(force_bonus.get("evasion", 0))
		var bonus_max_hp := int(bonus.get("max_hp", 0)) + int(force_bonus.get("max_hp", 0))
		var bonus_max_mp := int(bonus.get("max_mp", 0)) + int(force_bonus.get("max_mp", 0))
		var max_hp := int(p.get("max_hp", p.get("hp", 0))) + bonus_max_hp
		var max_mp := int(p.get("max_mp", p.get("mp", 0))) + bonus_max_mp
		p["atk"] = int(p.get("atk", 0)) + bonus_atk
		p["def"] = int(p.get("def", 0)) + bonus_def
		p["speed"] = int(p.get("speed", 0)) + bonus_speed
		p["accuracy"] = int(p.get("accuracy", 100)) + bonus_accuracy
		p["evasion"] = int(p.get("evasion", 0)) + bonus_evasion
		p["max_hp"] = max_hp
		p["max_mp"] = max_mp
		p["hp"] = min(int(p.get("hp", 0)), max_hp)
		p["mp"] = min(int(p.get("mp", 0)), max_mp)

func _sync_actor_weapon_types() -> void:
	if InventorySync == null:
		return
	for p in player_party:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var actor_id := str(p.get("id", ""))
		var equipped := InventorySync.get_equipped(actor_id)
		p["weapon_1"] = _resolve_equipped_weapon_type_with_fallback(
			str(equipped.get("weapon_1", "")),
			str(p.get("weapon_1", ""))
		)
		p["weapon_2"] = _resolve_equipped_weapon_type_with_fallback(
			str(equipped.get("weapon_2", "")),
			str(p.get("weapon_2", ""))
		)

func _weapon_type_from_item(item_id: String) -> String:
	if item_id == "":
		return ""
	var item_def := ItemDB.get_def(item_id)
	if item_def.is_empty():
		return ""
	return str(item_def.get("weapon_type", ""))

func _resolve_equipped_weapon_type_with_fallback(item_id: String, fallback_weapon_type: String) -> String:
	var resolved_weapon_type := _weapon_type_from_item(item_id)
	if resolved_weapon_type != "":
		return resolved_weapon_type
	return fallback_weapon_type

func _run_battle_opening_sequence(context: Dictionary) -> void:
	var intro_line := _resolve_battle_intro_line(context)
	if intro_line == "":
		intro_line = "四周氣氛驟沉，殺機一觸即發。"
	if battle_ui and battle_ui.has_method("play_battle_opening"):
		await battle_ui.play_battle_opening(intro_line)
	else:
		_log(intro_line)
		await _await_log_stage_continue()
	_log_system("戰鬥開始")

func _resolve_battle_intro_line(context: Dictionary) -> String:
	return BattleIntroDB.resolve_intro(context, tone_map)

func _actor_key(actor: Dictionary) -> String:
	var id = str(actor.get("id", ""))
	if id != "":
		return id
	return str(actor.get("name", ""))

func _snapshot_player_base_stats() -> void:
	_player_base_snapshot.clear()
	for p in player_party:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var key = _actor_key(p)
		if key == "":
			continue
		_player_base_snapshot[key] = p.duplicate(true)

func _restore_player_base_stats() -> void:
	if _player_base_snapshot.is_empty():
		return
	for p in player_party:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var key = _actor_key(p)
		if key == "" or not _player_base_snapshot.has(key):
			continue
		var snapshot: Dictionary = _player_base_snapshot[key].duplicate(true)
		var keep_hp = int(p.get("hp", snapshot.get("hp", 0)))
		var keep_mp = int(p.get("mp", snapshot.get("mp", 0)))
		print("[BattleRestore] before status_effects=", p.get("status_effects", null), " buffs=", p.get("buffs", null))
		p.clear()
		for field in snapshot.keys():
			p[field] = snapshot[field]
		var restored_max_hp = int(p.get("max_hp", keep_hp))
		var restored_max_mp = int(p.get("max_mp", keep_mp))
		p["hp"] = min(keep_hp, restored_max_hp)
		p["mp"] = min(keep_mp, restored_max_mp)
		print("[BattleRestore] after status_effects=", p.get("status_effects", null), " buffs=", p.get("buffs", null))


func _log(msg: String, allow_when_ending: bool = false) -> void:
	print("📨 LogPanel 記錄中：", msg)
	if (battle_finished or _ending) and not allow_when_ending:
		return
	if action_log_ui:
		if action_log_ui.has_method("log"):
			action_log_ui.log(msg)          # 白字戰報＋打字機
		elif action_log_ui.has_method("log_narration"):
			action_log_ui.log_narration(msg)
		else:
			action_log_ui.append_text(msg + "\n")


# ✅ 系統訊息專用（優先用 LogPanel.log_system）
func _log_system(msg: String, allow_when_ending: bool = false) -> void:
	if (battle_finished or _ending) and not allow_when_ending:
		return
	if action_log_ui and action_log_ui.has_method("log_system"):
		action_log_ui.log_system(msg)
	else:
		_log(msg, allow_when_ending)

func _log_narration(msg: String, allow_when_ending: bool = false) -> void:
	if (battle_finished or _ending) and not allow_when_ending:
		return
	if action_log_ui and action_log_ui.has_method("log_narration"):
		action_log_ui.log_narration(msg)
	else:
		_log(msg, allow_when_ending)


func _await_log_stage_continue() -> void:
	if action_log_ui == null:
		return
	if battle_ui and battle_ui.has_node("ActionPanel"):
		battle_ui.get_node("ActionPanel").hide()
	if action_log_ui.has_method("wait_for_all_logs"):
		await action_log_ui.wait_for_all_logs()
	if action_log_ui.has_method("wait_for_continue"):
		await action_log_ui.wait_for_continue()


func log_system(msg: String) -> void:
	_log_system(msg)

func can_use_items() -> bool:
	return _is_rule_allowed("allow_items", true)

func can_switch_inner_force() -> bool:
	return _is_rule_allowed("allow_inner_force_switch", true)

func apply_inner_force_switch(actor: Dictionary, force: Dictionary) -> bool:
	if not _is_rule_allowed("allow_inner_force_switch", true):
		_log_system("本場規則禁止切換內功。")
		return false

	actor["inner_force"] = force
	if force.has("element"):
		actor["element"] = force["element"]

	if battle_ui:
		battle_ui.update_ally_panel()

	return true

func _is_rule_allowed(rule_key: String, default_value: bool) -> bool:
	if ruleset.is_empty():
		return default_value
	return bool(ruleset.get(rule_key, default_value))


func _on_turn_started(actor: Dictionary) -> void:
	# 🛡️ 如果上一輪你是選防禦，那現在輪到你新的回合，就把防禦狀態解除
	if bool(actor.get("defending", false)):
		actor["defending"] = false
		if battle_ui:
			battle_ui.clear_defend_motion(actor)  # 下面第 2 步會加這個函式

	# ⚡ v1: 暈眩（stun）在回合開始立即判定，直接跳過行動
	if _try_consume_stun(actor):
		_end_turn_due_to_stun()
		return

	# 🪦 安全檢查：如果這個人已經倒下，就直接略過他的回合
	var hp = int(actor.get("hp", 0))
	if hp <= 0:
		print("⚰️ %s 已經倒下，略過他的回合。" % actor.get("name", "???"))
		safe_end_turn()
		return

	if actor in player_party:
		await _maybe_play_pending_ally_down_reaction(actor)

	# 🟥 敵方回合
	if actor in enemy_party:
		var name = String(actor.get("name", "???"))
		_log_system("輪到「%s」行動。" % name)

		await perform_enemy_action(actor)
		safe_end_turn()
		return

	# 🟦 我方回合
	if actor in player_party and battle_ui:
		print("🟦 Begin UI for: ", actor.get("name", "???"))
		battle_ui.begin_turn(actor)


func _try_consume_stun(actor: Dictionary) -> bool:
	if actor.is_empty() or status_manager == null:
		return false
	if not status_manager.has_method("has_effect"):
		return false
	if not bool(status_manager.has_effect(actor, "stun")):
		return false
	var actor_name := String(actor.get("name", "???"))
	_log_system("%s 暈眩了，無法行動！" % actor_name)
	if status_manager.has_method("remove_effect"):
		status_manager.remove_effect(actor, "stun")
	return true


func _end_turn_due_to_stun() -> void:
	# 避免在 turn_started signal callback 直接重入 end_turn
	call_deferred("safe_end_turn")

func _on_turn_ended(actor: Dictionary) -> void:
	# ❌ 不在這裡清 defending，單純交棒就好
	if battle_finished or _ending:
		return
	turn_manager.next_turn()

func _on_round_started(round_number: int) -> void:
	if battle_finished:
		return
	if last_round_logged == round_number:
		return
	last_round_logged = round_number
	_log("第 %d 回合開始！" % round_number)

func _on_round_ended(_round_number: int) -> void:
	if battle_finished:
		return
	if last_round_regen == _round_number:
		return
	last_round_regen = _round_number
	_restore_mp_after_round()

func _restore_mp_after_round() -> void:
	for a in (player_party + enemy_party):
		if typeof(a) != TYPE_DICTIONARY:
			continue

		if bool(a.get("is_dead", false)) or bool(a.get("dead", false)):
			continue
		if a.has("alive") and not bool(a.get("alive", true)):
			continue

		var hp = int(a.get("hp", 0))
		if hp <= 0:
			continue

		var new_mp = _calc_round_mp_regen(a, regen_policy, battle_context)
		a["mp"] = new_mp
	if battle_finished or _ending:
		return

func _build_battle_result(result: String) -> Dictionary:
	var out := {
		"result": result,
		"exp": 0,
		"gold": 0,
		"drops": [],
	}

	if result != "victory":
		return out
	var no_rewards: bool = bool(battle_context.get("no_rewards", false))

	var exp_total := 0
	var gold_total := 0
	var drops_acc := {}

	for e in enemy_party:
		if typeof(e) != TYPE_DICTIONARY:
			continue

		var exp_each := int(e.get("exp", 0))
		if str(e.get("id", "")) == "tea_house_guest_guard":
			exp_each = max(exp_each, 50)
		elif exp_each <= 0:
			exp_each = 25
		# v1 測試模式：先保證每隻怪至少 25 EXP，方便兩場內升級驗收
		exp_each = max(exp_each, 25)
		exp_total += exp_each

		if no_rewards:
			continue

		var gold_def = e.get("gold", {})
		if typeof(gold_def) == TYPE_DICTIONARY:
			var chance := float(gold_def.get("chance", 0.0))
			if chance > 1.0:
				chance /= 100.0
			chance = clamp(chance, 0.0, 1.0)
			if randf() < chance:
				var mn := int(gold_def.get("min", 0))
				var mx := int(gold_def.get("max", mn))
				if mn > mx:
					var tmp = mn
					mn = mx
					mx = tmp
				gold_total += randi_range(mn, mx)

		var drops_val = e.get("drops", [])
		var drops: Array = drops_val if typeof(drops_val) == TYPE_ARRAY else []
		for d in drops:
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var drop_id := str(d.get("id", ""))
			if drop_id == "":
				continue
			var d_chance := float(d.get("chance", 1.0))
			if d_chance > 1.0:
				d_chance /= 100.0
			d_chance = clamp(d_chance, 0.0, 1.0)
			if randf() >= d_chance:
				continue
			var mn_c := int(d.get("min", d.get("count", 1)))
			var mx_c := int(d.get("max", mn_c))
			if mn_c > mx_c:
				var tmp2 = mn_c
				mn_c = mx_c
				mx_c = tmp2
			var cnt := randi_range(mn_c, mx_c)
			if cnt <= 0:
				continue
			drops_acc[drop_id] = int(drops_acc.get(drop_id, 0)) + cnt

	out["exp"] = exp_total
	out["gold"] = gold_total

	var drops_out: Array = []
	for key in drops_acc.keys():
		drops_out.append({"id": key, "count": int(drops_acc[key])})
	out["drops"] = drops_out

	return out

func _calc_round_mp_regen(actor: Dictionary, policy: Dictionary, context: Dictionary) -> int:
	var mp = int(actor.get("mp", 0))
	var base = int(policy.get("mp_base", 5))
	var bonus = int(policy.get("mp_global_bonus", 0)) + int(actor.get("mp_regen_bonus", 0))
	var multiplier = float(policy.get("mp_multiplier", 1.0))
	var regen = int(round((base + bonus) * multiplier))
	var new_mp = mp + regen

	if bool(policy.get("clamp_to_max_mp", true)) and actor.has("max_mp"):
		var max_mp = int(actor.get("max_mp", 0))
		if max_mp > 0:
			new_mp = min(new_mp, max_mp)

	return new_mp

func _on_player_action_complete(actor: Dictionary) -> void:
	var current = turn_manager.get_current_actor()
	if current.get("id", "") != actor.get("id", ""):
		print("⚠️ 回報角色與當前行動者不一致，當成忽略")
		return

	# ✅ 等戰報分段完成，玩家確認後再結束玩家回合
	await _await_log_stage_continue()

	safe_end_turn()


func perform_enemy_action(enemy: Dictionary) -> void:
	await get_tree().process_frame
	if battle_finished or _ending:
		return

	var skills = skill_db.get_skills(enemy.get("id", ""))
	var inner_force = enemy.get("inner_force", {})
	if enemy_ai == null:
		push_error("❌ 找不到 EnemyAI 節點")
		return

	var action = enemy_ai.get_action(enemy, player_party, skills)
	if action.is_empty():
		push_warning("❗ 敵人 AI 回傳空值，略過此回合")
		await get_tree().create_timer(0.3).timeout
		enemy["acted_this_turn"] = true
		_maybe_end_turn()
		return

	var skill = action.skill
	var target = action.target
	var scope := String(skill.get("target_scope", "single"))
	target = _resolve_confuse_target(enemy, target, scope)
	var result = skill_executor.execute(enemy, target, skill, inner_force)

	# 🎬 敵人出招：描述 → 動畫 → 傷害結果
	var enemy_logs = await _play_attack_cinematic(enemy, target, skill, result)

	if enemy_logs.size() > 0:
		for line in enemy_logs:
			_log(line)
		if action_log_ui and action_log_ui.has_method("wait_for_all_logs"):
			await action_log_ui.wait_for_all_logs()
		await _await_log_stage_continue()

	var enemy_applied: Array = _apply_skill_effects(enemy, target, skill, [target])
	_log_applied_statuses(enemy_applied)
	if enemy_applied.size() > 0:
		await _await_log_stage_continue()

	check_battle_status()
	if battle_finished:
		return
	enemy["acted_this_turn"] = true
	_maybe_end_turn()
	print("🔚 %s 結束行動，交棒給下一位" % enemy.get("name", "???"))


func safe_end_turn() -> void:
	if battle_finished or _ending:
		return
	if turn_manager:
		turn_manager.end_turn()


func check_battle_status() -> void:
	if battle_finished or _ending:
		return
	if player_party.all(func(p): return p["hp"] <= 0):
		_pending_ally_down_reactions.clear()
		_begin_end_battle("defeat")
		return
	if enemy_party.all(func(e): return e["hp"] <= 0):
		_begin_end_battle("victory")
		return

func request_escape_from_item(_user: Dictionary, _item: Dictionary) -> void:
	if battle_finished or _ending:
		return
	_begin_end_battle("escape")

func _begin_end_battle(result: String) -> void:
	if _ending:
		return
	_ending = true
	battle_finished = true
	var current_actor_id := ""
	if turn_manager and turn_manager.has_method("get_current_actor"):
		var current_actor = turn_manager.get_current_actor()
		if typeof(current_actor) == TYPE_DICTIONARY:
			current_actor_id = str(current_actor.get("id", ""))
	print("[BattleEnd] result=", result, " actor_id=", current_actor_id)

	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	if turn_manager:
		turn_manager.set_process(false)
		turn_manager.set_physics_process(false)
	if battle_ui:
		if battle_ui.has_method("update_enemy_panel"):
			battle_ui.update_enemy_panel()
		if battle_ui.has_method("update_ally_panel"):
			battle_ui.update_ally_panel()
		if battle_ui.has_method("set_process_input"):
			battle_ui.set_process_input(false)
		if battle_ui.has_method("set_physics_process"):
			battle_ui.set_physics_process(false)
		if battle_ui.has_node("ActionPanel"):
			battle_ui.get_node("ActionPanel").hide()

	await get_tree().process_frame
	await get_tree().process_frame

	if action_log_ui and action_log_ui.has_method("wait_for_all_logs"):
		await action_log_ui.wait_for_all_logs()

	if result == "escape":
		_log("你們撤出戰圈，暫時脫離了危險。", true)
		_log("此戰視為撤退，無戰利品可得。", true)
	elif result == "defeat":
		_pending_ally_down_reactions.clear()
		await _play_game_over_narration()
	else:
		_log("戰勢已定，眾人緩緩收勢。", true)
		_log("風聲漸歇，殺氣散去。", true)
		_log("片刻寂靜後，你們回過神來。", true)

	if action_log_ui and action_log_ui.has_method("wait_for_all_logs"):
		await action_log_ui.wait_for_all_logs()

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	var battle_result = _build_battle_result(result)
	print("[BattleResult]", battle_result)
	if result == "victory" and battle_ui and battle_ui.has_method("show_battle_result"):
		battle_ui.show_battle_result(battle_result)
		await battle_ui.battle_result_confirmed

	if result != "escape":
		_restore_player_base_stats()
	_clear_next_battle_modifiers_for_party()

	if victory_handler:
		if result == "victory":
			victory_handler.victory(battle_result)
		elif result == "escape" and victory_handler.has_method("escape"):
			victory_handler.escape(battle_result)
		else:
			victory_handler.defeat(battle_result)
	else:
		push_error("❌ VictoryHandler 缺失，無法處理返回流程。")

func _maybe_end_turn() -> void:
	if battle_finished or _ending:
		return
	var alive: Array = []
	for a in (player_party + enemy_party):
		if typeof(a) == TYPE_DICTIONARY and int(a.get("hp", 0)) > 0:
			alive.append(a)

	if alive.is_empty():
		return

	for a in alive:
		if not bool(a.get("acted_this_turn", false)):
			return

	var status_events: Array = status_manager.tick_end_of_turn(alive)
	var has_end_turn_logs: bool = false
	for event in status_events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if String(event.get("type", "")) == "poison_tick":
			var evt_actor: Dictionary = event.get("actor", {})
			var dmg = int(event.get("damage", 0))
			if not evt_actor.is_empty() and dmg > 0:
				if int(evt_actor.get("hp", 0)) <= 0:
					_mark_actor_down(evt_actor)
				var remain = 0
				if evt_actor.has("status_effects") and typeof(evt_actor["status_effects"]) == TYPE_DICTIONARY and evt_actor["status_effects"].has("poison"):
					remain = int(evt_actor["status_effects"]["poison"].get("turns_left", 0))
				has_end_turn_logs = true
				_log("%s 中毒發作，損失 [color=#9cff66]%d[/color] 點生命！（剩 %d 回合）" % [String(evt_actor.get("name", "???")), dmg, remain])
				if int(evt_actor.get("hp", 0)) <= 0:
					if evt_actor in enemy_party:
						_log(_enemy_defeat_line(evt_actor))
					else:
						_log(_ally_down_self_line(evt_actor))

	for a in alive:
		_update_ui_for_actor(a)

	if battle_ui:
		battle_ui.update_enemy_panel()

	if has_end_turn_logs:
		await _await_log_stage_continue()

	check_battle_status()
	if battle_finished:
		return

	for a in alive:
		a["acted_this_turn"] = false


# ⭐ 決定這招要用哪個 FX 動畫
func _get_fx_id_for_skill(skill_data: Dictionary, attacker: Dictionary) -> String:
	var fx_id = String(skill_data.get("fx_id", ""))
	if fx_id != "":
		return fx_id

	# 若 skill 沒特別指定，就用武器推一個預設
	var weapon = String(skill_data.get("weapon_type", attacker.get("weapon_1", "")))

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


# ⭐ 核心：攻擊演出流程（動畫 → 血量更新）
func _play_attack_cinematic(attacker: Dictionary, target: Dictionary, skill_data: Dictionary, result: Dictionary) -> Array:
	var logs: Array = []
	if result.has("log"):
		logs = result.log

	# ❶ 攻擊方前傾 → FX → 受擊閃爍
	if battle_ui and not target.is_empty():
		# 攻擊方動作
		battle_ui.play_attack_motion(attacker)
		await get_tree().create_timer(0.12).timeout

		var did_hit := bool(result.get("hit", true))
		if did_hit:
			# FX：根據 skill / 武器決定動畫
			var fx_id = _get_fx_id_for_skill(skill_data, attacker)
			if fx_id != "":
				battle_ui.play_hit_fx_on_target(target, fx_id)

			# ⭐ 判斷是否處於防禦狀態
			var is_blocking = bool(target.get("defending", false))
			if is_blocking:
				battle_ui.play_guard_react(target)
			else:
				battle_ui.play_damage_react(target)

			await get_tree().create_timer(0.25).timeout
		else:
			await get_tree().create_timer(0.12).timeout

	# ❷ 在這一刻才更新血條 / MP（SkillExecutor 早就算完，但 UI 延後刷新）
	_update_ui_for_actor(target)
	_update_ui_for_actor(attacker)

	return logs


# ✅ 改版：可以接受指定 target，給玩家選目標用
func execute_action(actor: Dictionary, skill_data: Dictionary, target: Dictionary = {}) -> void:
	var effect: String = str(skill_data.get("effect", ""))
	if effect == "" and skill_data.has("effects") and typeof(skill_data.get("effects")) == TYPE_ARRAY:
		var arr: Array = skill_data.get("effects", [])
		if not arr.is_empty() and typeof(arr[0]) == TYPE_DICTIONARY:
			effect = str((arr[0] as Dictionary).get("type", ""))
	var scope: String  = str(skill_data.get("target_scope", "single"))
	var side: String   = str(skill_data.get("target_side", "enemy"))
	target = _resolve_confuse_target(actor, target, scope)
	var support_status_effects = ["buff_speed", "debuff_speed", "force_element"]
	var mp_cost = int(skill_data.get("mp_cost", 0))
	var actor_mp = int(actor.get("mp", 0))
	var user_name = str(actor.get("name", "???"))

	if mp_cost > 0 and actor_mp < mp_cost:
		_log("%s 真氣不足，無法施展「%s」。" % [user_name, str(skill_data.get("name", "???"))])
		return

	if mp_cost > 0:
		actor["mp"] = actor_mp - mp_cost
		_update_ui_for_actor(actor)

	# =========================
	# 0️⃣ 支援 / 補血技能分流（保持你現在的回血邏輯）
	# =========================
	if effect == "heal_hp" or effect == "mp_heal" or side == "ally" or support_status_effects.has(effect):
		await _execute_support_heal_action(actor, skill_data, target)
		check_battle_status()
		if battle_finished:
			return
		actor["acted_this_turn"] = true
		_maybe_end_turn()
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

		# 先把每個敵人的結果算好（不直接改本體）
		var aoe_results: Array = []  # [ { "enemy": enemy_dict, "result": result_dict, "after_hp": int }, ... ]

		for enemy in enemy_party:
			if typeof(enemy) != TYPE_DICTIONARY:
				continue
			if int(enemy.get("hp", 0)) <= 0:
				continue

			var enemy_copy: Dictionary = enemy.duplicate(true)
			var before_hp: int = int(enemy.get("hp", 0))
			var r: Dictionary = skill_executor.execute(actor, enemy_copy, skill_data, inner_force)
			var after_hp: int = max(before_hp - int(r.get("damage", 0)), 0)
			aoe_results.append({
				"enemy": enemy,
				"result": r,
				"after_hp": after_hp
			})

		# 🎬 出手動畫只播一次
		if battle_ui and battle_ui.has_method("play_attack_motion"):
			battle_ui.play_attack_motion(actor)
			await get_tree().create_timer(0.35).timeout

		# 屬性剋制表只在這邊用
		var ke_system = {
			"快": "遲",
			"遲": "柔",
			"柔": "剛",
			"剛": "快"
		}
		var user_element: String = str(actor.get("element", ""))

		var any_down = false
		var alive_targets: Array = []
		var hit_targets: Array = []

		# 🌊 全場級起手描述
		_log("%s 使出「%s」，掌風層層拍出，氣浪如驟雨般席捲整個敵陣。" % [
			actor_name,
			display_skill_name
		])

		# 先同步寫回傷害結果
		for entry in aoe_results:
			var enemy: Dictionary = entry["enemy"]
			enemy["hp"] = entry["after_hp"]
			_update_ui_for_actor(enemy)
			alive_targets.append(enemy)
			if bool(entry["result"].get("hit", true)):
				hit_targets.append(enemy)
		# 💥 全體受擊動畫（同時播放）
		if battle_ui and not hit_targets.is_empty():
			if battle_ui.has_method("play_hit_fx_multi"):
				battle_ui.play_hit_fx_multi(hit_targets, "fx_hit_fist")
			elif battle_ui.has_method("play_hit_fx_on_target"):
				for enemy in hit_targets:
					battle_ui.play_hit_fx_on_target(enemy, "fx_hit_fist")

			if battle_ui.has_method("play_damage_react_multi"):
				battle_ui.play_damage_react_multi(hit_targets)
			elif battle_ui.has_method("play_damage_react"):
				for enemy in hit_targets:
					battle_ui.play_damage_react(enemy)

		await get_tree().create_timer(0.15).timeout

		# 💥 每隻各自敘事＋傷害數字
		for entry in aoe_results:
			var enemy: Dictionary = entry["enemy"]
			var r: Dictionary     = entry["result"]

			var name_e: String = str(enemy.get("name", "???"))
			var dmg_int: int = int(r.get("damage", 0))

			if not bool(r.get("hit", true)):
				for line in r.get("log", []):
					_log(str(line))
				continue

			# ▶ 狀態旗標
			var target_element: String = str(enemy.get("element", ""))
			var is_crit: bool  = bool(r.get("crit", false))
			var after_hp_now: int = int(enemy.get("hp", 0))
			var is_down: bool  = after_hp_now <= 0

			# 簡單算一下「有沒有剋到」：快>遲>柔>剛>快
			var has_ke_advantage = false
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
			var state_key = "normal"
			if is_down:
				state_key = "down"
			elif has_ke_advantage:
				state_key = "ke"
			elif is_crit:
				state_key = "crit"

			# ▶ 額外敘事：完全交給 ToneMap
			if tone_map != null and not is_down:
				# 第二個 key：把「技能 + 狀態」打包，讓你在 ToneMap 裡自由配招式台詞
				var skill_key = str(skill_data.get("id", display_skill_name))
				var tone_key  = "%s|%s" % [skill_key, state_key]
				var target_id = str(enemy.get("id", ""))

				var extra_line = tone_map.get_tone_text("aoe_suffer", tone_key, target_id)
				if extra_line != "":
					_log(extra_line)

			# 🔢 數字戰報
			if dmg_int > 0:
				var dmg_str = "[color=#ffd447]%d[/color]" % dmg_int
				_log("%s 受到 %s 點傷害。" % [
					name_e,
					dmg_str
				])

				# 倒地判定＋經典死亡台詞
				if is_down:
					_mark_actor_down(enemy)
					any_down = true
					_log(_enemy_defeat_line(enemy))

		var aoe_applied: Array = _apply_skill_effects(actor, {}, skill_data, hit_targets)
		_log_applied_statuses(aoe_applied)
		if aoe_applied.size() > 0:
			await _await_log_stage_continue()

		await get_tree().create_timer(0.2).timeout
		await get_tree().process_frame
		await get_tree().process_frame

		if any_down and battle_ui:
			battle_ui.update_enemy_panel()

		check_battle_status()
		if battle_finished:
			return
		actor["acted_this_turn"] = true
		_maybe_end_turn()
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
	var effects: Array = []
	if skill_data.has("effects") and typeof(skill_data.get("effects")) == TYPE_ARRAY:
		effects = skill_data.get("effects", [])

	var damage_skill_data: Dictionary = skill_data
	if not effects.is_empty():
		for entry in effects:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if str(entry.get("type", "")) == "damage":
				damage_skill_data = skill_data.duplicate(true)
				damage_skill_data["power"] = float(entry.get("power", skill_data.get("power", 1.0)))
				break

	var result_single = skill_executor.execute(actor, actual_target, damage_skill_data, inner_force_single)

	# 🎬 單體：照舊跑 cinematic（描述＋動畫）
	var attack_logs = await _play_attack_cinematic(actor, actual_target, skill_data, result_single)

	if attack_logs.size() > 0:
		for line in attack_logs:
			_log(line)
		if action_log_ui and action_log_ui.has_method("wait_for_all_logs"):
			await action_log_ui.wait_for_all_logs()
		await _await_log_stage_continue()

	var single_target_pool: Array = [actual_target] if bool(result_single.get("hit", true)) else []
	var single_applied: Array = _apply_skill_effects(actor, actual_target, skill_data, single_target_pool)
	_log_applied_statuses(single_applied)
	if single_applied.size() > 0:
		await _await_log_stage_continue()

	if result_single.target_down:
		_mark_actor_down(actual_target)
		if battle_ui:
			battle_ui.update_enemy_panel()

	check_battle_status()
	if battle_finished:
		return
	actor["acted_this_turn"] = true
	_maybe_end_turn()




func _resolve_enemy_archetype(enemy: Dictionary) -> String:
	return EnemyDB.resolve_archetype(str(enemy.get("archetype", enemy.get("species", ""))))

func _enemy_defeat_line(enemy: Dictionary) -> String:
	var name_e := str(enemy.get("name", "???"))
	var archetype := _resolve_enemy_archetype(enemy)
	if tone_map != null:
		var line := tone_map.get_tone_text("enemy_defeat", archetype, str(enemy.get("id", "")))
		if line != "":
			return line.replace("{name}", name_e)
	return "%s 倒下，傷勢過重，已無力再戰。" % name_e

func _ally_down_self_line(actor: Dictionary) -> String:
	return "%s 傷重倒地，已無再戰之力！" % str(actor.get("name", "???"))

func _mark_actor_down(actor: Dictionary) -> void:
	if typeof(actor) != TYPE_DICTIONARY or actor.is_empty():
		return
	var already_down := bool(actor.get("is_dead", false))
	actor["hp"] = 0
	actor["is_dead"] = true
	if already_down:
		return
	if actor in player_party:
		if _all_players_defeated():
			_pending_ally_down_reactions.clear()
			return
		_queue_ally_down_reaction(actor)

func _queue_ally_down_reaction(downed_actor: Dictionary) -> void:
	if typeof(downed_actor) != TYPE_DICTIONARY or downed_actor.is_empty():
		return
	var downed_id := str(downed_actor.get("id", ""))
	if downed_id == "":
		return
	for pending in _pending_ally_down_reactions:
		if typeof(pending) != TYPE_DICTIONARY:
			continue
		if str(pending.get("downed_id", "")) == downed_id:
			return
	_pending_ally_down_reactions.append({
		"downed_id": downed_id,
		"downed_name": str(downed_actor.get("name", "???")),
	})

func _maybe_play_pending_ally_down_reaction(actor: Dictionary) -> void:
	if typeof(actor) != TYPE_DICTIONARY or actor.is_empty():
		return
	if actor not in player_party:
		return
	if int(actor.get("hp", 0)) <= 0:
		return
	if _pending_ally_down_reactions.is_empty():
		return

	var actor_id := str(actor.get("id", ""))
	var pending_index := -1
	var pending_event: Dictionary = {}
	for i in range(_pending_ally_down_reactions.size()):
		var candidate = _pending_ally_down_reactions[i]
		if typeof(candidate) != TYPE_DICTIONARY:
			continue
		if str(candidate.get("downed_id", "")) == actor_id:
			continue
		pending_index = i
		pending_event = candidate
		break

	if pending_index == -1:
		return

	_pending_ally_down_reactions.remove_at(pending_index)
	var reaction_line := ""
	if tone_map != null:
		reaction_line = tone_map.get_tone_text(
			"ally_down_reaction",
			str(pending_event.get("downed_id", "")),
			actor_id
		)
	if reaction_line == "":
		reaction_line = "{observer_name} 眼見 {downed_name} 倒下，胸口驟然一沉，仍咬牙穩住了架勢。"
	reaction_line = reaction_line \
		.replace("{observer_name}", str(actor.get("name", "???"))) \
		.replace("{downed_name}", str(pending_event.get("downed_name", "同伴")))
	_log_narration(reaction_line)
	await _await_log_stage_continue()

func _all_players_defeated() -> bool:
	for actor in player_party:
		if typeof(actor) != TYPE_DICTIONARY:
			continue
		if int(actor.get("hp", 0)) > 0:
			return false
	return true

func _play_game_over_narration() -> void:
	for line in GAME_OVER_NARRATION_LINES:
		_log_narration(line, true)
	await _await_log_stage_continue()

func _is_single_target_scope(scope: String) -> bool:
	return ["single", "enemy_single", "ally_single", "all_single"].has(scope)


func _pick_random_alive_actor() -> Dictionary:
	var alive: Array = []
	for a in (player_party + enemy_party):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		if int(a.get("hp", 0)) <= 0:
			continue
		alive.append(a)
	if alive.is_empty():
		return {}
	return alive[randi() % alive.size()]


func _resolve_confuse_target(actor: Dictionary, target: Dictionary, scope: String) -> Dictionary:
	if actor.is_empty() or status_manager == null:
		return target
	if not _is_single_target_scope(scope):
		return target
	if not status_manager.has_method("has_effect"):
		return target
	if not bool(status_manager.has_effect(actor, "confuse")):
		return target
	var randomized := _pick_random_alive_actor()
	if randomized.is_empty():
		return target
	_log_system("%s 神智混亂，出手方向失控！" % String(actor.get("name", "???")))
	return randomized


func _log_applied_statuses(applied_statuses: Array) -> void:
	for row in applied_statuses:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var tone_cast := String(row.get("tone_cast", ""))
		if tone_cast != "":
			_log_narration(tone_cast)
		var desc := String(row.get("desc", ""))
		if desc != "":
			_log(desc)
		var tone_suffer := String(row.get("tone_suffer", ""))
		if tone_suffer != "":
			_log_narration(tone_suffer)


func _apply_skill_effects(user: Dictionary, primary_target: Dictionary, skill_data: Dictionary, target_pool: Array = []) -> Array:
	var applied: Array = []
	if not skill_data.has("effects") or typeof(skill_data.get("effects")) != TYPE_ARRAY:
		return applied
	var effects: Array = skill_data.get("effects", [])
	for entry in effects:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var effect_type := str(entry.get("type", ""))
		if effect_type == "" or effect_type == "damage":
			continue
		var targets: Array = []
		var scope := str(skill_data.get("target_scope", "single"))
		var side := str(skill_data.get("target_side", "enemy"))
		if str(entry.get("target", "")) == "self":
			targets = [user]
		elif side == "enemy" and target_pool.is_empty():
			targets = []
		elif scope == "enemy_all" and side == "enemy":
			targets = target_pool
		else:
			targets = [primary_target]

		for t in targets:
			if typeof(t) != TYPE_DICTIONARY or t.is_empty():
				continue
			var record := _apply_single_skill_effect(user, t, effect_type, entry, skill_data)
			if record.is_empty():
				continue
			applied.append(record)
			_update_ui_for_actor(t)
	return applied


func _apply_single_skill_effect(user: Dictionary, effect_target: Dictionary, effect_type: String, entry: Dictionary, skill_data: Dictionary) -> Dictionary:
	var turns = int(entry.get("turns", _default_turns_for_status(effect_type)))
	if turns <= 0:
		turns = _default_turns_for_status(effect_type)
	var payload := _build_status_payload_from_skill_effect(effect_type, entry)
	var normalized_effect_id := effect_type
	match effect_type:
		"buff_speed":
			normalized_effect_id = "speed_buff"
			if int(payload.get("speed_delta", 0)) <= 0:
				payload["speed_delta"] = int(entry.get("amount", 0))
		"debuff_speed":
			normalized_effect_id = "speed_debuff"
			if int(payload.get("slow_delta", 0)) <= 0:
				payload["slow_delta"] = int(entry.get("amount", 0))
		"force_element":
			normalized_effect_id = "force_element"
			payload["element"] = str(entry.get("element", ""))
		_:
			pass

	if status_manager == null:
		return {}
	var ok := bool(status_manager.apply_effect(effect_target, normalized_effect_id, payload, turns))
	if not ok:
		return {}
	var effect_record := {}
	if effect_target.has("status_effects") and typeof(effect_target["status_effects"]) == TYPE_DICTIONARY:
		effect_record = effect_target["status_effects"].get(normalized_effect_id, {})
	var desc := ""
	if status_manager.has_method("describe_effect"):
		desc = String(status_manager.describe_effect(normalized_effect_id, effect_target, effect_record))
	var tone_cast := ""
	var tone_suffer := ""
	if tone_map != null:
		tone_cast = tone_map.get_tone_text("status_apply", normalized_effect_id, str(user.get("id", "")))
		var suffer_key := normalized_effect_id
		if bool(effect_target.get("is_enemy", false)):
			suffer_key = "%s|%s" % [normalized_effect_id, _resolve_enemy_archetype(effect_target)]
		tone_suffer = tone_map.get_tone_text("status_suffer", suffer_key, str(effect_target.get("id", "")))
		if tone_suffer != "":
			tone_suffer = tone_suffer.replace("{name}", str(effect_target.get("name", "???")))
	return {
		"effect_id": normalized_effect_id,
		"turns": turns,
		"payload": payload,
		"target": effect_target,
		"desc": desc,
		"tone_cast": tone_cast,
		"tone_suffer": tone_suffer,
	}


func _default_turns_for_status(effect_type: String) -> int:
	match effect_type:
		"poison":
			return 3
		"confuse":
			return 2
		"root":
			return 2
		"stun":
			return 1
		"buff_speed", "debuff_speed", "force_element":
			return 2
		_:
			return 3


func _build_status_payload_from_skill_effect(effect_type: String, entry: Dictionary) -> Dictionary:
	var payload := {}
	var amount := int(entry.get("amount", 0))
	match effect_type:
		"buff_speed":
			payload["speed_delta"] = abs(amount if amount > 0 else 3)
		"debuff_speed":
			payload["slow_delta"] = abs(amount if amount > 0 else 3)
		"force_element":
			payload["element"] = str(entry.get("element", ""))
		"weaken":
			payload["atk_delta"] = -abs(amount if amount > 0 else 10)
		"break_def":
			payload["def_delta"] = -abs(amount if amount > 0 else 10)
		"weak":
			payload["max_hp_delta"] = -abs(amount if amount > 0 else 30)
		"seal_mp":
			payload["max_mp_delta"] = -abs(amount if amount > 0 else 15)
		"blind":
			payload["accuracy_delta"] = -abs(amount if amount > 0 else 15)
		"root":
			payload["evasion_delta"] = -abs(amount if amount > 0 else 20)
		"slow":
			payload["slow_delta"] = abs(amount if amount > 0 else 10)
		_:
			pass
	return payload


func _try_apply_skill_status_effect(effect_target: Dictionary, effect_type: String, entry: Dictionary) -> bool:
	var fake_user := {"id": "", "name": ""}
	var record := _apply_single_skill_effect(fake_user, effect_target, effect_type, entry, {})
	if record.is_empty():
		return false
	if String(record.get("desc", "")) != "":
		_log(String(record.get("desc", "")))
	return true

func defend_action(actor: Dictionary) -> void:
	actor["defending"] = true
	_log("%s 採取了防禦姿態。" % actor.get("name", "???"))
	actor["acted_this_turn"] = true
	_maybe_end_turn()

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
	var effects: Array = []
	if skill_data.has("effects") and typeof(skill_data.get("effects")) == TYPE_ARRAY:
		effects = skill_data.get("effects", [])
	if effect == "" and not effects.is_empty() and typeof(effects[0]) == TYPE_DICTIONARY:
		effect = str((effects[0] as Dictionary).get("type", "heal_hp"))

	# 狀態類支援：速度增減、屬性強制
	if effect == "buff_speed" or effect == "debuff_speed" or effect == "force_element":
		var ok = await _execute_support_status_action(user, skill_data, target)
		if not ok:
			_log("WARN: support status failed: %s" % effect)
			return
		return

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
	if not effects.is_empty():
		for entry in effects:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var t = str((entry as Dictionary).get("type", ""))
			if t == "heal_hp" or t == "mp_heal":
				effect = t
				base_amount = int((entry as Dictionary).get("amount", base_amount))
				break
			if t == "buff_speed" or t == "debuff_speed" or t == "force_element":
				var patched = skill_data.duplicate(true)
				patched["effect"] = t
				patched["amount"] = int((entry as Dictionary).get("amount", skill_data.get("amount", 0)))
				patched["turns"] = int((entry as Dictionary).get("turns", skill_data.get("turns", 3)))
				if t == "force_element":
					patched["element"] = str((entry as Dictionary).get("element", skill_data.get("element", "")))
				var ok2 = await _execute_support_status_action(user, patched, target)
				if not ok2:
					_log("WARN: support status failed: %s" % t)
				return
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
			var amount_str = "[color=#80ff80]%d[/color]" % restored
			_log("%s 的生命恢復了 %s 點。" % [
				name_t,
				amount_str
			])
	else:
		var t0: Dictionary = targets[0]
		var tid0: String = t0.get("id", str(t0))
		var restored0: int = int(restored_map.get(tid0, 0))
		var amount_str0 = "[color=#80ff80]%d[/color]" % restored0
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

	var amount_str = "[color=#80ffe0]%d[/color]" % restored
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


func _execute_support_status_action(user: Dictionary, skill_data: Dictionary, target: Dictionary) -> bool:
	var effect: String = str(skill_data.get("effect", ""))
	var skill_name: String = str(skill_data.get("name", "???"))
	var turns = int(skill_data.get("turns", 3))
	if turns <= 0:
		_log("WARN: support status missing turns: %s" % skill_name)
		return false

	if target.is_empty() and (effect == "debuff_speed" or effect == "force_element"):
		_log("WARN: support status %s missing target: %s" % [effect, skill_name])
		return false

	var actual_target: Dictionary = target
	if actual_target.is_empty():
		actual_target = user

	var user_name: String = user.get("name", "???")
	var target_name: String = actual_target.get("name", "???")

	if battle_ui and battle_ui.has_method("play_attack_motion"):
		battle_ui.play_attack_motion(user)
		if battle_ui.has_method("play_hit_fx_on_target"):
			var fx_id = _get_fx_id_for_skill(skill_data, user)
			if fx_id != "":
				battle_ui.play_hit_fx_on_target(actual_target, fx_id)
		if battle_ui.has_method("play_damage_react"):
			battle_ui.play_damage_react(actual_target)
		await get_tree().create_timer(0.2).timeout

	match effect:
		"buff_speed":
			var amt = int(skill_data.get("amount", skill_data.get("power", 0)))
			if amt <= 0:
				_log("WARN: support buff_speed missing amount: %s" % skill_name)
				return false
			var ok = status_manager.apply_effect(actual_target, "speed_buff", {"speed_delta": amt}, turns)
			if not ok:
				return false
			_log("%s 對 %s 施展「%s」，速度提升 %d，持續 %d 回合。" % [
				user_name,
				target_name,
				skill_name,
				amt,
				turns
			])
		"debuff_speed":
			var slow_amt = int(skill_data.get("amount", skill_data.get("power", 0)))
			if slow_amt <= 0:
				_log("WARN: support debuff_speed missing amount: %s" % skill_name)
				return false
			var ok2 = status_manager.apply_effect(actual_target, "speed_debuff", {"slow_delta": slow_amt}, turns)
			if not ok2:
				return false
			_log("%s 對 %s 施展「%s」，速度降低 %d，持續 %d 回合。" % [
				user_name,
				target_name,
				skill_name,
				slow_amt,
				turns
			])
		"force_element":
			var new_ele = str(skill_data.get("element", skill_data.get("target_element", "")))
			if new_ele == "":
				_log("WARN: support force_element missing element: %s" % skill_name)
				return false
			var ok3 = status_manager.apply_effect(actual_target, "force_element", {"element": new_ele}, turns)
			if not ok3:
				return false
			_log("%s 對 %s 施展「%s」，屬性轉為「%s」，持續 %d 回合。" % [
				user_name,
				target_name,
				skill_name,
				new_ele,
				turns
			])
		_:
			_log("WARN: unsupported support status effect: %s" % effect)
			return false

	_update_ui_for_actor(actual_target)
	return true

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
		var warn_item_id = str(item.get("id", "unknown_item"))
		push_warning("⚠️ 炸彈道具 %s 的 amount <= 0，沒有造成傷害。" % warn_item_id)
		_log("WARN: item missing amount: %s" % warn_item_id)
		return

	var before_hp: int = int(target.get("hp", 0))
	if before_hp <= 0:
		return

	var after_hp: int = max(before_hp - power, 0)

	var dmg: int = before_hp - after_hp
	target["hp"] = after_hp

	var tname = str(target.get("name", "???"))
	var tid   = str(target.get("id", ""))

	# 🎬 FX + 抖動
	if battle_ui:
		if battle_ui.has_method("play_hit_fx_on_target"):
			battle_ui.play_hit_fx_on_target(target, "fx_hit_fist")  # 先借用萬用打擊
		if battle_ui.has_method("play_damage_react"):
			battle_ui.play_damage_react(target)

	# 敘事：被炸到的感覺
	if tone_map != null:
		var suffer_line = tone_map.get_tone_text("item_suffer", effect_key, tid)
		if suffer_line != "":
			_log(suffer_line)

	# 數字戰報
	var dmg_str = "[color=#ffd447]%d[/color]" % dmg
	_log("%s 受到 %s 點傷害。" % [tname, dmg_str])

	if after_hp <= 0:
		_mark_actor_down(target)
		if target in enemy_party:
			_log(_enemy_defeat_line(target))
		else:
			_log(_ally_down_self_line(target))

	_update_ui_for_actor(target)

func _calculate_bomb_damage(target: Dictionary, item: Dictionary) -> Dictionary:
	var power: int = int(item.get("amount", 0))
	if power <= 0:
		var warn_item_id = str(item.get("id", "unknown_item"))
		push_warning("⚠️ 炸彈道具 %s 的 amount <= 0，沒有造成傷害。" % warn_item_id)
		_log("WARN: item missing amount: %s" % warn_item_id)
		return {}

	var before_hp: int = int(target.get("hp", 0))
	if before_hp <= 0:
		return {}

	var after_hp: int = max(before_hp - power, 0)
	return {
		"before_hp": before_hp,
		"after_hp": after_hp,
		"damage": before_hp - after_hp
	}


# 單體霹靂彈：打指定 target，沒選就打第一隻敵人
func _apply_bomb_single(user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	if target.is_empty():
		if enemy_party.is_empty():
			return
		target = enemy_party[0]

	# 使用者敘事（丟出去的動作）
	if tone_map != null:
		var use_line = tone_map.get_tone_text("item_use", "bomb_single", str(user.get("id", "")))
		if use_line != "":
			_log(use_line)

	_apply_bomb_damage_to_target(user, item, target, "bomb_single")


# 轟雷霹靂彈：敵方全體
func _apply_bomb_aoe(user: Dictionary, item: Dictionary) -> void:
	if enemy_party.is_empty():
		return

	# 使用者敘事（起手）
	if tone_map != null:
		var use_line = tone_map.get_tone_text("item_use", "bomb_aoe", str(user.get("id", "")))
		if use_line != "":
			_log(use_line)

	var aoe_results: Array = [] # [ { "enemy": Dictionary, "result": Dictionary } ]
	for enemy in enemy_party:
		if typeof(enemy) != TYPE_DICTIONARY:
			continue
		if int(enemy.get("hp", 0)) <= 0:
			continue

		var result = _calculate_bomb_damage(enemy, item)
		if result.is_empty():
			continue
		aoe_results.append({
			"enemy": enemy,
			"result": result
		})

	# 先同步寫回傷害
	for entry in aoe_results:
		var enemy: Dictionary = entry["enemy"]
		var result: Dictionary = entry["result"]
		enemy["hp"] = result["after_hp"]
		_update_ui_for_actor(enemy)

	var alive_targets: Array = []
	for entry in aoe_results:
		alive_targets.append(entry["enemy"])

	if battle_ui:
		if battle_ui.has_method("play_hit_fx_multi"):
			battle_ui.play_hit_fx_multi(alive_targets, "fx_hit_fist")
		elif battle_ui.has_method("play_hit_fx_on_target"):
			for enemy in alive_targets:
				battle_ui.play_hit_fx_on_target(enemy, "fx_hit_fist")

		if battle_ui.has_method("play_damage_react_multi"):
			battle_ui.play_damage_react_multi(alive_targets)
		elif battle_ui.has_method("play_damage_react"):
			for enemy in alive_targets:
				battle_ui.play_damage_react(enemy)

	await get_tree().create_timer(0.15).timeout

	# 再逐一敘事、戰報
	for entry in aoe_results:
		var enemy: Dictionary = entry["enemy"]
		var result: Dictionary = entry["result"]
		var tname = str(enemy.get("name", "???"))
		var tid = str(enemy.get("id", ""))

		if tone_map != null:
			var suffer_line = tone_map.get_tone_text("item_suffer", "bomb_aoe", tid)
			if suffer_line != "":
				_log(suffer_line)

		var dmg_str = "[color=#ffd447]%d[/color]" % int(result["damage"])
		_log("%s 受到 %s 點傷害。" % [tname, dmg_str])

		if int(result["after_hp"]) <= 0:
			_mark_actor_down(enemy)
			_log(_enemy_defeat_line(enemy))



func use_item(user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	if not _is_rule_allowed("allow_items", true):
		_log_system("本場規則禁止使用道具。")
		return
	# ✅ 套用效果（dispatcher）
	var ok = item_dispatcher.apply(self, user, item, target)

	# ✅ 套用成功才消耗道具（可由道具設為 no_consume）
	if ok and not bool(item.get("no_consume", false)):
		InventorySync.consume_item(item.get("id", ""))

	# ✅ 道具效果跑完後，同步 UI（避免自補 / 互補更新不同步）
	_update_ui_for_actor(target)
	_update_ui_for_actor(user)

	check_battle_status()
	if battle_finished:
		return
	user["acted_this_turn"] = true
	_maybe_end_turn()


# ✅ 回傳某道具可以選的目標清單，給 BattleUI / TargetSelectPopup 用
func get_valid_targets_for_item(item: Dictionary, user: Dictionary) -> Array:
	var scope: String = item.get("target_scope", "ally_single")
	var effect: String = item.get("effect", "")
	var result: Array = []

	# 💡 先預留：哪些 effect 視為「復活」類型
	var revive_effects = ["revive", "revive_hp"]
	var include_dead = revive_effects.has(effect)

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
	var include_dead = false

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

	var idx = player_party.find(actor)
	if idx != -1:
		battle_ui.update_ally_status(idx, actor)
		return

	idx = enemy_party.find(actor)
	if idx != -1:
		battle_ui.update_enemy_status(idx, actor)


func _filter_targets_by_hp(source: Array, include_dead: bool) -> Array:
	var result: Array = []
	for a in source:
		var hp = int(a.get("hp", 0))
		if hp > 0 or include_dead:
			result.append(a)
	return result


func _clear_next_battle_modifiers_for_party() -> void:
	if team_data_manager == null or not team_data_manager.has_method("clear_next_battle_modifiers"):
		return
	var cleared: Dictionary = {}
	for actor in player_party:
		if typeof(actor) != TYPE_DICTIONARY:
			continue
		var actor_id := String(actor.get("id", ""))
		if actor_id == "" or cleared.has(actor_id):
			continue
		team_data_manager.clear_next_battle_modifiers(actor_id)
		actor["battle_modifiers"] = {}
		cleared[actor_id] = true
