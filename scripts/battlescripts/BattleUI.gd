extends Control

signal player_action_complete(actor: Dictionary)
signal battle_result_confirmed(result: Dictionary)

const ToneMap = preload("res://scripts/battlestyles/ToneMap.gd")
var tone = ToneMap.new()

@onready var ally_panel = $AllyPanel
@onready var action_panel = $ActionPanel
@onready var log_panel = $LogPanel as LogPanel
@onready var enemy_panel = $EnemyPanel
@onready var skill_list_popup = $ActionPanel/PopupSkillSelect
@onready var inner_force_popup = $ActionPanel/InnerForcePopup
@onready var item_list_popup = $ActionPanel/ItemListPopup
@onready var defense_confirm_popup = $ActionPanel/DefenseConfirmPopup
@onready var target_select_popup = $ActionPanel/TargetSelectPopup
@onready var btn_item = $ActionPanel/BtnItem
@onready var btn_inner_force = $ActionPanel/BtnInnerForce
@onready var btn_weapon_switch = $ActionPanel.get_node_or_null("BtnWeaponSwitch")
@onready var battle_result_overlay = $BattleResultOverlay
@onready var battle_result_title = $BattleResultOverlay/ResultPanel/ResultContent/ResultTitle
@onready var battle_result_body = $BattleResultOverlay/ResultPanel/ResultContent/ResultBody
@onready var battle_result_confirm = $BattleResultOverlay/ResultPanel/ResultContent/ConfirmButton

var character_skill_db: Node = null
var skill_provider : Node = null
var current_actor: Dictionary = {}
var on_action_selection = false
var waiting_for_action = false
var combat_controller: Node = null
var current_turn_id = ""
var current_target_focus: Dictionary = {}  # ⭐ 目前在 TargetSelect 中被選中的那個

# 用來暫存「還沒真正結算」的指令
var pending_item: Dictionary = {}
var pending_item_user: Dictionary = {}
var pending_skill: Dictionary = {}
var pending_skill_user: Dictionary = {}
var _pending_battle_result: Dictionary = {}

# 隊伍資料與 UI slot 參考
var allies: Array = []      # 由 BattleController / TeamDataManager 傳進來
var enemies: Array = []
var ally_slots: Array = []  # AllyPanel 底下的 TeamMate_1/2/3
var enemy_slots: Array = [] # EnemyPanel 底下的敵人 slot（之後你可以做 EnemySlot.gd）


# 🔹 共用 log helper：系統 / 敘事分色
func _log_system(text: String) -> void:
	if log_panel:
		log_panel.log_system(text)

func _log_narration(text: String) -> void:
	if log_panel:
		log_panel.log_narration(text)


func _ready() -> void:
	print("✅ BattleUI 啟動")
	print("📦 LogPanel 物件是：", log_panel)
	hide_all_popups()
	action_panel.hide()

	# 訊號連線
	skill_list_popup.skill_selected.connect(_on_PopupSkillSelect_skill_selected)
	skill_list_popup.selection_cancelled.connect(_on_PopupSkillSelect_selection_cancelled)

	inner_force_popup.inner_force_selected.connect(_on_InnerForcePopup_force_selected)
	inner_force_popup.selection_cancelled.connect(_on_InnerForcePopup_selection_cancelled)

	defense_confirm_popup.defense_confirmed.connect(_on_DefenseConfirmPopup_confirmed)
	defense_confirm_popup.selection_cancelled.connect(_on_DefenseConfirmPopup_cancelled)

	item_list_popup.item_selected.connect(_on_ItemListPopup_item_selected)
	item_list_popup.selection_cancelled.connect(_on_ItemListPopup_selection_cancelled)

	# 目標選擇彈窗訊號
	target_select_popup.target_selected.connect(_on_TargetSelectPopup_target_selected)
	target_select_popup.selection_cancelled.connect(_on_TargetSelectPopup_selection_cancelled)
# ⭐ 新增：選單裡選到目標時，讓頭像閃一下
	target_select_popup.target_focus_changed.connect(_on_TargetSelectPopup_target_focus_changed)
	battle_result_confirm.pressed.connect(_on_battle_result_confirmed)
	# 把 AllyPanel / EnemyPanel 底下現有的 slot 存起來（例如 TeamMate_1, TeamMate_2...）
	ally_slots = ally_panel.get_children()
	enemy_slots = enemy_panel.get_children()
	battle_result_overlay.hide()


# =========================
#  隊伍資料載入 / UI 更新
# =========================

## 戰鬥開始時由 BattleController 呼叫，載入雙方隊伍資料
# =========================
#  隊伍資料載入 / UI 更新
# =========================

## 戰鬥開始時由 BattleController 呼叫，載入雙方隊伍資料
func set_teams(allies_data: Array, enemies_data: Array) -> void:
	allies = allies_data
	enemies = enemies_data
	update_ally_panel()
	update_enemy_panel()

func apply_ruleset(ruleset: Dictionary) -> void:
	var allow_items = bool(ruleset.get("allow_items", true))
	var allow_inner = bool(ruleset.get("allow_inner_force_switch", true))
	var allow_weapon = bool(ruleset.get("allow_weapon_switch", true))

	_set_button_allowed(btn_item, allow_items)
	_set_button_allowed(btn_inner_force, allow_inner)
	_set_button_allowed(btn_weapon_switch, allow_weapon)

func _set_button_allowed(button: Node, allowed: bool) -> void:
	if button == null:
		return
	if button is BaseButton:
		button.disabled = not allowed
	button.visible = true

# ⭐ 新增：讓 BattleController 可以指定「這個 actor 被打，播哪個 FX」
func play_hit_fx_on_actor(actor: Dictionary, fx_name: String) -> void:
	if actor.is_empty():
		return

	# 先找是不是我方
	var idx = allies.find(actor)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot and slot.has_method("play_hit_fx"):
			slot.play_hit_fx(fx_name)
		return

	# 再找是不是敵方
	idx = _find_enemy_slot_index(actor)
	if idx != -1 and idx < enemy_slots.size():
		var enemy_slot = enemy_slots[idx]
		if enemy_slot and enemy_slot.has_method("play_hit_fx"):
			enemy_slot.play_hit_fx(fx_name)

func play_damage_react_multi(targets: Array) -> void:
	for t in targets:
		play_damage_react(t)

func play_hit_fx_multi(targets: Array, fx_name: String) -> void:
	for t in targets:
		play_hit_fx_on_target(t, fx_name)

func _find_enemy_slot_index(target: Dictionary) -> int:
	if target.has("ui_index"):
		var idx = int(target.get("ui_index", -1))
		if idx >= 0 and idx < enemy_slots.size():
			return idx
	return enemies.find(target)

## 每回合開頭會重新刷新一次 UI
func begin_turn(actor: Dictionary) -> void:
	if combat_controller and (combat_controller.battle_finished or combat_controller._ending):
		return
	current_actor = actor
	current_turn_id = actor.get("id", "")
	var actor_name: String = actor.get("name", "？？")
	print("🎯 UI 開始行動者: ", actor_name)

	update_ally_panel()
	update_enemy_panel()

	# ⭐ 新增：更新回合高亮
	_update_turn_highlight()

	hide_all_popups()
	action_panel.show()
	on_action_selection = true

	_log_system("輪到「%s」行動。" % actor_name)

func show_battle_result(result: Dictionary) -> void:
	_pending_battle_result = result
	var exp = int(result.get("exp", 0))
	var gold = int(result.get("gold", 0))
	var drops: Array = result.get("drops", [])
	var drops_line = "掉落：無"
	if drops.size() > 0:
		var drop_parts: Array = []
		for d in drops:
			if typeof(d) == TYPE_DICTIONARY:
				var drop_id = str(d.get("id", "unknown"))
				var count = int(d.get("count", 1))
				drop_parts.append("%s x%d" % [drop_id, count])
		if not drop_parts.is_empty():
			drops_line = "掉落：" + ", ".join(drop_parts)

	battle_result_title.text = "戰鬥勝利"
	battle_result_body.text = "經驗：%d\n金幣：%d\n%s" % [exp, gold, drops_line]
	action_panel.hide()
	battle_result_overlay.show()

func _on_battle_result_confirmed() -> void:
	battle_result_overlay.hide()
	emit_signal("battle_result_confirmed", _pending_battle_result)


## 整隊我方 UI 刷新（例如回合開始時）
func update_ally_panel() -> void:
	if allies.is_empty():
		return

	var count: int = min(allies.size(), ally_slots.size())
	for i in range(count):
		var slot = ally_slots[i]
		var actor: Dictionary = allies[i]

		# 優先使用 update_from_actor，沒有的話就用 setup_from_actor
		if slot.has_method("update_from_actor"):
			slot.update_from_actor(actor)
		elif slot.has_method("setup_from_actor"):
			slot.setup_from_actor(actor)


## 整隊敵方 UI 刷新
func update_enemy_panel() -> void:
	var total_slots = enemy_slots.size()

	for i in range(total_slots):
		var slot = enemy_slots[i]

		if i < enemies.size():
			var actor: Dictionary = enemies[i]
			var hp = int(actor.get("hp", 0))

			if hp > 0:
				# 還活著 → 正常顯示
				if slot.has_method("update_from_actor"):
					slot.update_from_actor(actor)
				elif slot.has_method("setup_from_actor"):
					slot.setup_from_actor(actor)
				slot.show()
			else:
				# 已死亡 / 失去戰鬥力 → 清空這個 slot 的畫面
				if slot.has_method("clear_slot"):
					slot.clear_slot()
				else:
					slot.hide()
		else:
			# 陣列裡已經沒有這個 index 對應的敵人 → 清空/隱藏
			if slot.has_method("clear_slot"):
				slot.clear_slot()
			else:
				slot.hide()

## 單一我方成員狀態更新（被打 / 回血 時由 BattleController 呼叫）
func update_ally_status(index: int, actor: Dictionary) -> void:
	if index < 0 or index >= ally_slots.size():
		return
	var slot = ally_slots[index]
	if slot.has_method("update_from_actor"):
		slot.update_from_actor(actor)


## 單一敵方成員狀態更新
func update_enemy_status(index: int, actor: Dictionary) -> void:
	if index < 0 or index >= enemy_slots.size():
		return
	var slot = enemy_slots[index]
	if slot.has_method("update_from_actor"):
		slot.update_from_actor(actor)

# =========================
#  攻擊動畫橋接：讓 Controller 不用管 slot 細節
# =========================

func play_attack_motion(actor: Dictionary) -> void:
	if allies.is_empty() and enemies.is_empty():
		return

	var idx = allies.find(actor)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot.has_method("play_attack_motion"):
			slot.play_attack_motion()
		return

	idx = _find_enemy_slot_index(actor)
	if idx != -1 and idx < enemy_slots.size():
		var slot = enemy_slots[idx]
		if slot.has_method("play_attack_motion"):
			slot.play_attack_motion()

# ===== 防禦動作：玩家選擇防禦時，做一個收招姿態 =====
func play_defend_motion(actor: Dictionary) -> void:
	if allies.is_empty() and enemies.is_empty():
		return

	var idx = allies.find(actor)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot.has_method("play_defend_pose"):
			slot.play_defend_pose()
		return

	idx = _find_enemy_slot_index(actor)
	if idx != -1 and idx < enemy_slots.size():
		var slot = enemy_slots[idx]
		if slot.has_method("play_defend_pose"):
			slot.play_defend_pose()

func clear_defend_motion(actor: Dictionary) -> void:
	if allies.is_empty() and enemies.is_empty():
		return

	var idx = allies.find(actor)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot.has_method("clear_defend_pose"):
			slot.clear_defend_pose()
		return

	idx = _find_enemy_slot_index(actor)
	if idx != -1 and idx < enemy_slots.size():
		var slot = enemy_slots[idx]
		if slot.has_method("clear_defend_pose"):
			slot.clear_defend_pose()


func play_hit_fx_on_target(target: Dictionary, fx_id: String) -> void:
	if fx_id == "":
		return
	if allies.is_empty() and enemies.is_empty():
		return

	var idx = _find_enemy_slot_index(target)
	if idx != -1 and idx < enemy_slots.size():
		var slot = enemy_slots[idx]
		if slot.has_method("play_hit_fx"):
			slot.play_hit_fx(fx_id)
		return

	idx = allies.find(target)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot.has_method("play_hit_fx"):
			slot.play_hit_fx(fx_id)

func play_damage_react(target: Dictionary) -> void:
	if allies.is_empty() and enemies.is_empty():
		return

	var idx = _find_enemy_slot_index(target)
	if idx != -1 and idx < enemy_slots.size():
		var slot = enemy_slots[idx]
		if slot.has_method("play_damage_react"):
			slot.play_damage_react()
		return

	idx = allies.find(target)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot.has_method("play_damage_react"):
			slot.play_damage_react()

func play_heal_react(target: Dictionary) -> void:
	if allies.is_empty() and enemies.is_empty():
		return

	var idx = allies.find(target)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot and slot.has_method("play_heal_react"):
			slot.play_heal_react()
		return

	idx = _find_enemy_slot_index(target)
	if idx != -1 and idx < enemy_slots.size():
		var eslot = enemy_slots[idx]
		if eslot and eslot.has_method("play_heal_react"):
			eslot.play_heal_react()


func play_guard_react(target: Dictionary) -> void:
	if allies.is_empty() and enemies.is_empty():
		return

	var idx = enemies.find(target)
	if idx != -1 and idx < enemy_slots.size():
		var slot = enemy_slots[idx]
		if slot.has_method("play_guard_react"):
			slot.play_guard_react()
		return

	idx = allies.find(target)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot.has_method("play_guard_react"):
			slot.play_guard_react()


# 在 BattleUI.gd 裡面，和 update_ally_status / update_enemy_status 放一起就好

func play_ally_hit_fx(index: int, effect: String) -> void:
	if index < 0 or index >= ally_slots.size():
		return
	var slot = ally_slots[index]
	if slot and slot.has_method("play_hit_fx"):
		slot.play_hit_fx(effect)

func play_enemy_hit_fx(index: int, effect: String) -> void:
	if index < 0 or index >= enemy_slots.size():
		return
	var slot = enemy_slots[index]
	if slot and slot.has_method("play_hit_fx"):
		slot.play_hit_fx(effect)

func hide_all_popups() -> void:
	skill_list_popup.hide()
	item_list_popup.hide()
	defense_confirm_popup.hide()
	inner_force_popup.hide()
	target_select_popup.hide()


# ===== 技能 =====
func _on_btn_skill_pressed() -> void:
	hide_all_popups()

	var w1 = current_actor.get("weapon_1", "")
	var w2 = current_actor.get("weapon_2", "")
	var weapons: Array = []
	if w1 == "" and w2 == "":
		weapons = ["拳", "掌"]
	else:
		if w1 != "":
			weapons.append(w1)
		if w2 != "":
			weapons.append(w2)

	var skills = character_skill_db.get_skills(current_actor["id"])
	var inner_force = current_actor.get("inner_force", {})
	skill_list_popup.show_skills(skills, inner_force, character_skill_db, weapons)

# ⭐ 根據技能的 effect / target_scope / target_side 來決定候選目標
func _start_target_select_for_skill(user: Dictionary, skill_data: Dictionary) -> void:
	var effect = str(skill_data.get("effect", "damage"))
	var scope  = str(skill_data.get("target_scope", "single"))  # "single" / "ally_all" / ...
	var side   = str(skill_data.get("target_side", ""))         # "ally" / "enemy" / "self"

	# 🧠 自動推論目標陣營
	if side == "":
		if effect in ["heal", "heal_hp", "mp_heal", "buff_speed"]:
			# 補血、補內力、加速 → 預設補隊友
			side = "ally"
		elif scope.begins_with("ally"):
			side = "ally"
		elif scope.begins_with("enemy"):
			side = "enemy"
		else:
			# 沒寫就當作打敵人
			side = "enemy"

	# 🌀 群體技（例如 ally_all / enemy_all）→ 不需要選目標，直接結算
	if scope == "ally_all" or scope == "enemy_all":
		var dummy_target: Dictionary = {}
		if side == "ally":
			# 全體補血：給自己當代表就好，真正目標會在 BattleController 裡用 player_party 算
			dummy_target = user
		elif side == "enemy":
			# 全體攻擊：隨便挑一個敵人當代表（execute_action 會再依技能做處理）
			if enemies.size() > 0:
				dummy_target = enemies[0]

		_apply_skill_and_finish_turn(user, skill_data, dummy_target)
		pending_skill = {}
		pending_skill_user = {}
		return

	# 🎯 單體技能：收集候選目標
	var candidates: Array = []

	if side == "ally":
		for a in allies:
			if typeof(a) == TYPE_DICTIONARY and int(a.get("hp", 0)) > 0:
				candidates.append(a)
	elif side == "self":
		candidates.append(user)
	else:
		for e in enemies:
			if typeof(e) == TYPE_DICTIONARY and int(e.get("hp", 0)) > 0:
				candidates.append(e)

	# 🛑 沒東西可以選
	if candidates.is_empty():
		_log_system("目前沒有可選擇的目標。")
		pending_skill = {}
		pending_skill_user = {}
		if user.get("id", "") == current_turn_id:
			emit_signal("player_action_complete", user)
		return

	# 🎯 只有一個目標 → 直接結算技能
	if candidates.size() == 1:
		var only_target: Dictionary = candidates[0]
		_apply_skill_and_finish_turn(user, skill_data, only_target)
		pending_skill = {}
		pending_skill_user = {}
	else:
		# 👀 多個目標 → 開 TargetSelectPopup 讓玩家選
		if target_select_popup:
			target_select_popup.show_targets(candidates)

func _on_PopupSkillSelect_skill_selected(skill_data: Dictionary) -> void:
	# 關閉技能選單，本回合仍在進行
	skill_list_popup.hide()
	on_action_selection = false

	var skill_name: String = skill_data.get("name", "???")
	_log_system("你選擇了「%s」。" % skill_name)

	# 暫存這次要用的技能與使用者
	pending_skill = skill_data
	pending_skill_user = current_actor

	# 🎯 改成由 BattleUI 自己決定候選目標（攻擊 → 敵人，治療 → 我方）
	_start_target_select_for_skill(current_actor, skill_data)

func _on_PopupSkillSelect_selection_cancelled() -> void:
	_log_system("操作取消。請重新選擇行動。")

# ===== 內功 =====
func _on_btn_inner_force_pressed() -> void:
	hide_all_popups()
	if combat_controller and combat_controller.has_method("can_switch_inner_force"):
		if not combat_controller.can_switch_inner_force():
			if combat_controller.has_method("log_system"):
				combat_controller.log_system("本場規則禁止切換內功。")
			return
	inner_force_popup.show_inner_forces(current_actor)


func _on_InnerForcePopup_force_selected(force: Dictionary):
	print("🎯 成功觸發內功切換訊號：", force)

	if combat_controller and combat_controller.has_method("apply_inner_force_switch"):
		var ok = combat_controller.apply_inner_force_switch(current_actor, force)
		if not ok:
			inner_force_popup.hide()
			return

	# 下面是原本的敘事文字
	var base = "你切換了內功為「%s・%s」（強化：%s）。" % [
		force.get("prefix", "？"),
		force.get("type", "？"),
		force.get("boost_weapon", "？")
	]
	var extra = tone.get_tone_text(
		"innerforce_switch",
		force.get("prefix", ""),
		current_actor.get("id", "")
	)

	_log_system(base)

	if extra != "":
		_log_narration(extra)

	_log_system("腳色行動結束。")

	action_panel.hide()
	on_action_selection = false
	emit_signal("player_action_complete", current_actor)



func _on_InnerForcePopup_selection_cancelled() -> void:
	_log_system("你放棄了切換內功。")


# ===== 防禦 =====
func _on_btn_defend_pressed() -> void:
	hide_all_popups()
	defense_confirm_popup.popup_centered()


func _on_DefenseConfirmPopup_confirmed() -> void:
	action_panel.hide()
	on_action_selection = false

	_log_system("你選擇了防禦姿態。該回合結束。")

	var extra = tone.get_tone_text("defend", "", current_actor.get("id", ""))
	if extra == "":
		var actor_name: String = current_actor.get("name", "？？")
		extra = "%s 收招後氣沉丹田，雙臂微抬，小心提防對手動向。" % actor_name
	_log_narration(extra)

	# ⭐ 播放防禦姿態動畫
	play_defend_motion(current_actor)

	combat_controller.defend_action(current_actor)
	emit_signal("player_action_complete", current_actor)


func _on_DefenseConfirmPopup_cancelled() -> void:
	_log_system("你放棄了防禦。")


# ===== 道具 =====
func _on_btn_item_pressed() -> void:
	hide_all_popups()
	if combat_controller and combat_controller.has_method("can_use_items"):
		if not combat_controller.can_use_items():
			if combat_controller.has_method("log_system"):
				combat_controller.log_system("本場規則禁止使用道具。")
			return
	item_list_popup.show_items(current_actor)


func _on_ItemListPopup_item_selected(item) -> void:
	item_list_popup.hide()
	on_action_selection = false

	# ⭐ 讀道具的 target_scope，預設還是 ally_single
	var scope = String(item.get("target_scope", "ally_single"))

	var item_name: String = item.name if item is Object and item.has_method("get") == false else str(item.get("name", "???"))
	_log_system("你使用了「%s」。" % item_name)

	pending_item = item
	pending_item_user = current_actor

	# =========================
	# 先處理「不用選目標」的情況
	# =========================
	match scope:
		# 🧨 敵方全體：轟雷霹靂彈這種 AOE 攻擊
		"enemy_all":
			# 目標交給 BattleController.use_item 內部自己 loop 敵人
			_apply_item_and_finish_turn(pending_item_user, pending_item, {})
			pending_item = {}
			pending_item_user = {}
			return

		# 💊 我方全體道具（未來如果有「全體補血藥」之類）
		"ally_all":
			# 傳自己當代表就好，實際目標在 BattleController 裡會用 allies 去算
			_apply_item_and_finish_turn(pending_item_user, pending_item, pending_item_user)
			pending_item = {}
			pending_item_user = {}
			return

		# 🙋‍♂️ 自用型道具（target_scope = "self"）
		"self":
			_apply_item_and_finish_turn(pending_item_user, pending_item, pending_item_user)
			pending_item = {}
			pending_item_user = {}
			return

		# 其他情況（單體道具之類）才需要走原本的 target 選擇流程
		_:
			pass

	# =========================
	# 需要選目標的情況：沿用原本的邏輯
	# =========================
	var targets: Array = combat_controller.get_valid_targets_for_item(item, current_actor)
	if targets.is_empty():
		_log_system("目前沒有可選擇的目標。")
		pending_item = {}
		pending_item_user = {}
		if current_actor.get("id", "") == current_turn_id:
			emit_signal("player_action_complete", current_actor)
		return

	if targets.size() == 1:
		var only_target: Dictionary = targets[0]
		_apply_item_and_finish_turn(pending_item_user, pending_item, only_target)
		pending_item = {}
		pending_item_user = {}
	else:
		target_select_popup.show_targets(targets)


func _on_ItemListPopup_selection_cancelled() -> void:
	_log_system("你放棄了使用道具。")

# ===== TargetSelectPopup 回傳 =====
func _on_TargetSelectPopup_target_selected(target: Dictionary) -> void:
	# 優先判斷道具，其次技能（看誰有暫存）
	if not pending_item.is_empty():
		_apply_item_and_finish_turn(pending_item_user, pending_item, target)
		pending_item = {}
		pending_item_user = {}
	elif not pending_skill.is_empty():
		_apply_skill_and_finish_turn(pending_skill_user, pending_skill, target)
		pending_skill = {}
		pending_skill_user = {}
	else:
		_log_system("系統：找不到待處理的指令。")
		# ⭐ 選定之後就把目標閃爍關掉，接下來交給攻擊演出
	if not current_target_focus.is_empty():
		_set_actor_target_focus(current_target_focus, false)
		current_target_focus = {}

func _on_TargetSelectPopup_target_focus_changed(target: Dictionary) -> void:
	# 先把上一個被選中的目標關掉閃爍
	if not current_target_focus.is_empty():
		_set_actor_target_focus(current_target_focus, false)

	current_target_focus = target

	if current_target_focus.is_empty():
		return

	# 新選中的目標開始白色呼吸閃爍
	_set_actor_target_focus(current_target_focus, true)

func _set_actor_target_focus(actor: Dictionary, active: bool) -> void:
	if actor.is_empty():
		return

	var idx = allies.find(actor)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot and slot.has_method("set_target_focus"):
			slot.set_target_focus(active)
		return

	idx = enemies.find(actor)
	if idx != -1 and idx < enemy_slots.size():
		var enemy_slot = enemy_slots[idx]
		if enemy_slot and enemy_slot.has_method("set_target_focus"):
			enemy_slot.set_target_focus(active)

func _on_TargetSelectPopup_selection_cancelled() -> void:
	# 關掉目標 highlight
	if not current_target_focus.is_empty():
		_set_actor_target_focus(current_target_focus, false)
		current_target_focus = {}

	if not pending_item.is_empty() or not pending_skill.is_empty():
		_log_system("你放棄了選擇目標。")
	pending_item = {}
	pending_item_user = {}
	pending_skill = {}
	pending_skill_user = {}

	action_panel.show()
	on_action_selection = true

# ===== 實際結算：道具 =====
func _apply_item_and_finish_turn(user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	action_panel.hide()
	on_action_selection = false

	# ✅ 道具敘事改由 BattleController.use_item + ToneMap 處理
	# 這裡不再額外加一行「藥香」描述避免重複、也避免效果錯配
	combat_controller.use_item(user, item, target)

	if user.get("id", "") == current_turn_id:
		emit_signal("player_action_complete", user)

# ===== 實際結算：技能 =====
func _apply_skill_and_finish_turn(user: Dictionary, skill_data: Dictionary, target: Dictionary) -> void:
	action_panel.hide()
	on_action_selection = false

	# ⭐ 重點：等 BattleController 把整個攻擊演出跑完（描述＋前傾＋FX＋受擊＋剩餘戰報）
	if combat_controller:
		await combat_controller.execute_action(user, skill_data, target)
	else:
		push_error("BattleUI: combat_controller 為 null，無法執行技能。")
		return

	# ⭐ 整個攻擊流程跑完之後，才結束這一回合
	if user.get("id", "") == current_turn_id:
		emit_signal("player_action_complete", user)

# ⭐ 根據 current_turn_id，決定哪一個 slot 要白色閃爍
func _update_turn_highlight() -> void:
	if current_turn_id == "":
		return

	# 我方
	for i in range(allies.size()):
		if i >= ally_slots.size():
			break
		var a: Dictionary = allies[i]
		var slot = ally_slots[i]
		var is_active = (a.get("id", "") == current_turn_id)
		if slot and slot.has_method("set_turn_highlight"):
			slot.set_turn_highlight(is_active)

	# 敵方（如果你想讓敵人回合也閃，就保留這段；不想的話可以整段註解）
	for i in range(enemies.size()):
		if i >= enemy_slots.size():
			break
		var e: Dictionary = enemies[i]
		var enemy_slot = enemy_slots[i]
		var enemy_is_active = (e.get("id", "") == current_turn_id)
		if enemy_slot and enemy_slot.has_method("set_turn_highlight"):
			enemy_slot.set_turn_highlight(enemy_is_active)

# ⭐ 讓某個 actor（我方或敵方）切換目標高亮
func _set_target_highlight_for_actor(actor: Dictionary, is_active: bool) -> void:
	if actor.is_empty():
		return

	# 先找我方
	var idx = allies.find(actor)
	if idx != -1 and idx < ally_slots.size():
		var slot = ally_slots[idx]
		if slot and slot.has_method("set_target_highlight"):
			slot.set_target_highlight(is_active)
		return

	# 再找敵方
	idx = enemies.find(actor)
	if idx != -1 and idx < enemy_slots.size():
		var enemy_slot = enemy_slots[idx]
		if enemy_slot and enemy_slot.has_method("set_target_highlight"):
			enemy_slot.set_target_highlight(is_active)

# ⭐ 一次把全場的 target 高亮關掉（避免殘留）
func _clear_all_target_highlight() -> void:
	for slot in ally_slots:
		if slot and slot.has_method("set_target_highlight"):
			slot.set_target_highlight(false)
	for slot in enemy_slots:
		if slot and slot.has_method("set_target_highlight"):
			slot.set_target_highlight(false)

# ⭐ 被選取成目標時：閃一下再進入結算
func _flash_target_confirm(target: Dictionary) -> void:
	_clear_all_target_highlight()
	_set_target_highlight_for_actor(target, true)
	# 稍微停留一下讓玩家看得清楚
	await get_tree().create_timer(0.3).timeout
	_set_target_highlight_for_actor(target, false)
