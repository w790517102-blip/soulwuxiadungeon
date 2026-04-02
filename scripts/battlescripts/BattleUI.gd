extends Control

signal player_action_complete(actor: Dictionary)
signal battle_result_confirmed(result: Dictionary)
signal battle_opening_confirmed

const ToneMap = preload("res://scripts/battlestyles/ToneMap.gd")
const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")
const MenuUIFont = preload("res://assets/fonts/DotGothic16-Regular.ttf")
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
@onready var status_hover_popup: PanelContainer = $StatusHoverPopup
@onready var status_hover_label: RichTextLabel = $StatusHoverPopup/StatusHoverLabel

var character_skill_db: Node = null
var skill_provider : Node = null
var current_actor: Dictionary = {}
var on_action_selection = false
var waiting_for_action = false # legacy unused flag (kept for compatibility)
var combat_controller: Node = null
var current_turn_id = ""
var current_target_focus: Dictionary = {}  # ⭐ 目前在 TargetSelect 中被選中的那個

var _opening_overlay: ColorRect
var _opening_intro_label: Label
var _opening_hint_label: Label
var _opening_start_label: Label
var _battle_opening_locked := false
var _battle_opening_waiting_confirm := false


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
var _ally_status_labels: Array = []
var _enemy_status_labels: Array = []
var _actor_bubble_labels: Dictionary = {}
var _actor_bubble_boxes: Dictionary = {}
var _actor_bubble_tokens: Dictionary = {}
var _bubble_debug_logged: Dictionary = {}
var _status_abbrev_accum := 0.0
var _has_blinking_tokens := false

const COMBAT_DIALOGUE := {
	"dodge": {
		"liuyu": ["還不夠快。", "看清了。", "差一寸。", "這種招，碰不到我。", "別浪費力氣。", "你出手前，我就知道了。"],
		"shumian": ["差一點，就碰著墨痕了呢。", "還好，紙頁沒有亂。", "風先替我讓開了。", "你來得急，我退得輕。", "這一下，還沒落到我身上。", "筆意未亂，心也未亂。"],
		"lieshao": ["嘖，差遠了。", "就這？", "你連我的衣角都沒碰著。", "慢了半拍。", "我還以為能有點意思。", "別急，再練幾年吧。"],
		"_generic": ["擦身而過。", "這招落空了。", "可惜，沒碰到我。"],
	}
}

const DEBUFF_ABBREV := {
	"poison": "毒",
	"stun": "暈",
	"slow": "緩",
	"confuse": "亂",
	"weaken": "弱",
	"break_def": "破",
	"weak": "衰",
	"seal_mp": "損",
	"blind": "盲",
	"root": "困",
	"stat_debuff_str": "力",
	"stat_debuff_agi": "敏",
	"stat_debuff_int": "智",
	"stat_debuff_con": "體",
	"stat_debuff_luck": "幸",
}

const BUFF_ABBREV := {
	"speed_buff": "速",
	"warm_wine_buff": "攻",
	"atk_up": "攻",
	"focus": "命",
	"evasion_boost": "閃",
	"stat_buff_str": "力",
	"stat_buff_agi": "敏",
	"stat_buff_int": "智",
	"stat_buff_con": "體",
	"stat_buff_luck": "幸",
}


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
	_apply_menu_font_style(action_panel)
	_apply_logpanel_style_to_battle_lists()
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
	_setup_actor_bubble_labels()
	_ensure_status_abbrev_labels()
	set_process(true)
	battle_result_overlay.hide()
	_setup_opening_overlay()
	_setup_hover_slots()
	if status_hover_popup:
		status_hover_popup.hide()
		status_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_menu_font_style(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		var ctrl: Control = root
		ctrl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		ctrl.add_theme_constant_override("outline_size", 4)
		ctrl.add_theme_font_override("font", MenuUIFont)
		ctrl.add_theme_font_size_override("font_size", 20)
		if ctrl is RichTextLabel:
			ctrl.add_theme_font_override("normal_font", MenuUIFont)
			ctrl.add_theme_font_size_override("normal_font_size", 20)
	for child in root.get_children():
		_apply_menu_font_style(child)

func _apply_logpanel_style_to_battle_lists() -> void:
	if log_panel == null:
		return
	var targets: Array[ItemList] = []
	if skill_list_popup:
		var skill_list := skill_list_popup.get_node_or_null("VBoxContainer/SkillList") as ItemList
		if skill_list:
			targets.append(skill_list)
	if inner_force_popup:
		var force_list := inner_force_popup.get_node_or_null("VBoxContainer/ForceList") as ItemList
		if force_list:
			targets.append(force_list)
	if item_list_popup:
		var item_list := item_list_popup.get_node_or_null("VBoxContainer/ItemListPopup") as ItemList
		if item_list:
			targets.append(item_list)
	for list in targets:
		_apply_logpanel_style_to_item_list(list)

func _apply_logpanel_style_to_item_list(list: ItemList) -> void:
	if list == null or log_panel == null:
		return
	var font = log_panel.get_theme_font("normal_font")
	if font:
		list.add_theme_font_override("font", font)
	var font_size := int(log_panel.get_theme_font_size("normal_font_size"))
	if font_size > 0:
		list.add_theme_font_size_override("font_size", font_size)
	var outline_size := int(log_panel.get_theme_constant("outline_size"))
	if outline_size > 0:
		list.add_theme_constant_override("outline_size", outline_size)
	var outline_color: Color = log_panel.get_theme_color("font_outline_color")
	list.add_theme_color_override("font_outline_color", outline_color)

func _setup_opening_overlay() -> void:
	_opening_overlay = ColorRect.new()
	_opening_overlay.name = "BattleOpeningOverlay"
	_opening_overlay.visible = false
	_opening_overlay.color = Color(0, 0, 0, 0.66)
	_opening_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_opening_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_opening_overlay)

	var intro := Label.new()
	intro.name = "IntroLabel"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 24)
	intro.add_theme_color_override("font_color", Color(1, 0.96, 0.82, 1))
	intro.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	intro.add_theme_constant_override("outline_size", 5)
	intro.anchor_left = 0.5
	intro.anchor_top = 0.5
	intro.anchor_right = 0.5
	intro.anchor_bottom = 0.5
	intro.offset_left = 180
	intro.offset_top = 190
	intro.offset_right = 1020
	intro.offset_bottom = 410
	_opening_overlay.add_child(intro)
	_opening_intro_label = intro

	var hint := Label.new()
	hint.name = "ConfirmHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.text = "按確認鍵 / 滑鼠左鍵"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0, 0.95))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hint.add_theme_constant_override("outline_size", 4)
	hint.anchor_left = 0.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -88
	hint.offset_bottom = -52
	_opening_overlay.add_child(hint)
	_opening_hint_label = hint

	var start := Label.new()
	start.name = "BattleStartLabel"
	start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start.text = "戰鬥開始"
	start.add_theme_font_size_override("font_size", 64)
	start.add_theme_color_override("font_color", Color(1, 0.95, 0.55, 1))
	start.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	start.add_theme_constant_override("outline_size", 8)
	start.anchor_left = 0.5
	start.anchor_top = 0.5
	start.anchor_right = 0.5
	start.anchor_bottom = 0.5
	start.offset_left = 180
	start.offset_top = 190
	start.offset_right = 1020
	start.offset_bottom = 410
	start.visible = false
	_opening_overlay.add_child(start)
	_opening_start_label = start

func play_battle_opening(intro_line: String) -> void:
	if _opening_overlay == null:
		return
	_battle_opening_locked = true
	_battle_opening_waiting_confirm = true
	_set_battle_input_locked(true)
	action_panel.hide()
	hide_all_popups()
	on_action_selection = false
	_opening_intro_label.text = intro_line
	_opening_hint_label.visible = true
	_opening_intro_label.visible = true
	_opening_start_label.visible = false
	_opening_overlay.modulate = Color(1, 1, 1, 1)
	_opening_overlay.visible = true
	await battle_opening_confirmed
	_battle_opening_waiting_confirm = false
	_opening_hint_label.visible = false
	_opening_intro_label.visible = false
	_opening_start_label.visible = true
	_opening_start_label.modulate = Color(1, 1, 1, 0.0)
	_opening_start_label.scale = Vector2(0.88, 0.88)
	var tween := create_tween()
	tween.tween_property(_opening_start_label, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_opening_start_label, "scale", Vector2(1.0, 1.0), 0.18)
	tween.tween_interval(0.30)
	tween.tween_property(_opening_start_label, "modulate:a", 0.0, 0.22)
	await tween.finished
	_opening_overlay.visible = false
	_opening_intro_label.visible = true
	_battle_opening_locked = false
	_set_battle_input_locked(false)

func _unhandled_input(event: InputEvent) -> void:
	if not _battle_opening_locked or not _battle_opening_waiting_confirm:
		return
	var confirm_pressed := event.is_action_pressed("ui_accept")
	if not confirm_pressed and event is InputEventMouseButton:
		confirm_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not confirm_pressed:
		return
	if _opening_overlay != null and _opening_overlay.visible:
		_battle_opening_waiting_confirm = false
		emit_signal("battle_opening_confirmed")
		get_viewport().set_input_as_handled()

func _set_battle_input_locked(locked: bool) -> void:
	if action_panel:
		action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
		_set_buttons_disabled(action_panel, locked)
	_set_popup_locked(target_select_popup, locked)
	_set_popup_locked(item_list_popup, locked)
	_set_popup_locked(skill_list_popup, locked)

func _set_popup_locked(popup: Node, locked: bool) -> void:
	if popup == null:
		return
	if locked and popup.has_method("hide"):
		popup.hide()
	for child in popup.get_children():
		_set_popup_content_locked(child, locked)

func _set_popup_content_locked(node: Node, locked: bool) -> void:
	if node is BaseButton:
		node.disabled = locked
	elif node is ItemList:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	for child in node.get_children():
		_set_popup_content_locked(child, locked)

func _set_buttons_disabled(node: Node, disabled: bool) -> void:
	if node is BaseButton:
		node.disabled = disabled
	for child in node.get_children():
		_set_buttons_disabled(child, disabled)

func _setup_hover_slots() -> void:
	for i in range(ally_slots.size()):
		var slot = ally_slots[i]
		if slot is Control:
			if not slot.mouse_entered.is_connected(_on_slot_hover_entered):
				slot.mouse_entered.connect(_on_slot_hover_entered.bind(false, i))
			if not slot.mouse_exited.is_connected(_on_slot_hover_exited):
				slot.mouse_exited.connect(_on_slot_hover_exited)
	for i in range(enemy_slots.size()):
		var enemy_slot = enemy_slots[i]
		if enemy_slot is Control:
			if not enemy_slot.mouse_entered.is_connected(_on_slot_hover_entered):
				enemy_slot.mouse_entered.connect(_on_slot_hover_entered.bind(true, i))
			if not enemy_slot.mouse_exited.is_connected(_on_slot_hover_exited):
				enemy_slot.mouse_exited.connect(_on_slot_hover_exited)

func _on_slot_hover_entered(is_enemy: bool, index: int) -> void:
	if status_hover_popup == null or status_hover_label == null:
		return
	var actor: Dictionary = {}
	if is_enemy:
		if index >= 0 and index < enemies.size():
			actor = enemies[index]
	else:
		if index >= 0 and index < allies.size():
			actor = allies[index]
	if actor.is_empty():
		return
	status_hover_label.text = _build_status_hover_text(actor)
	status_hover_popup.show()
	status_hover_popup.reset_size()
	_position_hover_popup(get_viewport().get_mouse_position())

func _on_slot_hover_exited() -> void:
	if status_hover_popup:
		status_hover_popup.hide()

func _position_hover_popup(mouse_pos: Vector2) -> void:
	if status_hover_popup == null:
		return
	var viewport_rect = get_viewport_rect()
	var popup_size = status_hover_popup.size
	var pos = mouse_pos + Vector2(16, 16)
	if pos.x + popup_size.x > viewport_rect.size.x:
		pos.x = max(0.0, viewport_rect.size.x - popup_size.x)
	if pos.y + popup_size.y > viewport_rect.size.y:
		pos.y = max(0.0, viewport_rect.size.y - popup_size.y)
	status_hover_popup.global_position = pos

func _build_status_hover_text(actor: Dictionary) -> String:
	var name = str(actor.get("display_name", actor.get("name", "???")))
	var hp = int(actor.get("hp", 0))
	var max_hp = int(actor.get("max_hp", hp))
	var mp = int(actor.get("mp", 0))
	var max_mp = int(actor.get("max_mp", mp))
	var atk = int(actor.get("atk", 0))
	var def = int(actor.get("def", 0))
	var speed = int(actor.get("speed", 0))
	var stat_str = int(actor.get("str", 0))
	var stat_agi = int(actor.get("agi", 0))
	var stat_int = int(actor.get("int", 0))
	var stat_con = int(actor.get("con", 0))
	var stat_luck = int(actor.get("luck", 0))
	var lines = []
	lines.append("[b]%s[/b]" % name)
	lines.append("HP：%d / %d" % [hp, max_hp])
	lines.append("MP：%d / %d" % [mp, max_mp])
	lines.append("ATK：%d   DEF：%d   SPD：%d" % [atk, def, speed])
	lines.append("STR：%d   AGI：%d   INT：%d" % [stat_str, stat_agi, stat_int])
	lines.append("CON：%d   LUCK：%d" % [stat_con, stat_luck])
	lines.append("狀態：")
	var effects_text = _format_status_effects(actor)
	lines.append(effects_text)
	return "\n".join(lines)

func _format_status_effects(actor: Dictionary) -> String:
	var effects = actor.get("status_effects", {})
	if typeof(effects) != TYPE_DICTIONARY or effects.is_empty():
		return "無"
	var lines: Array = []
	for effect_id in effects.keys():
		var data: Dictionary = effects[effect_id]
		lines.append(_format_status_effect_line(effect_id, data))
	return "\n".join(lines)

func _format_status_effect_line(effect_id: String, data: Dictionary) -> String:
	var turns = int(data.get("turns_left", 0))
	match effect_id:
		"speed_buff":
			var delta = int(data.get("payload", {}).get("speed_delta", 0))
			return "速度提升 +%d（剩 %d 回合）" % [delta, turns]
		"speed_debuff", "slow":
			var slow_delta = int(data.get("payload", {}).get("slow_delta", 0))
			return "速度下降 -%d（剩 %d 回合）" % [slow_delta, turns]
		"poison":
			return "中毒（剩 %d 回合）" % turns
		"stun":
			return "暈眩（剩 %d 回合）" % turns
		"confuse":
			return "混亂（剩 %d 回合）" % turns
		"weaken":
			var atk_delta = int(data.get("payload", {}).get("atk_delta", 0))
			return "無力：攻擊 %+d（剩 %d 回合）" % [atk_delta, turns]
		"atk_up":
			var atk_up_delta = int(data.get("payload", {}).get("atk_delta", 0))
			return "昂勢：攻擊 %+d（剩 %d 回合）" % [atk_up_delta, turns]
		"break_def":
			var def_delta = int(data.get("payload", {}).get("def_delta", 0))
			return "破防：防禦 %+d（剩 %d 回合）" % [def_delta, turns]
		"weak":
			var hp_delta = int(data.get("payload", {}).get("max_hp_delta", 0))
			return "虛弱：生命上限 %+d（剩 %d 回合）" % [hp_delta, turns]
		"seal_mp":
			var mp_delta = int(data.get("payload", {}).get("max_mp_delta", 0))
			return "封穴：內力上限 %+d（剩 %d 回合）" % [mp_delta, turns]
		"blind":
			var acc_delta = int(data.get("payload", {}).get("accuracy_delta", 0))
			return "目盲：命中 %+d（剩 %d 回合）" % [acc_delta, turns]
		"focus":
			var focus_acc = int(data.get("payload", {}).get("accuracy_delta", 0))
			return "凝神：命中 %+d（剩 %d 回合）" % [focus_acc, turns]
		"stat_buff_str":
			return "強身：力量 +%d（剩 %d 回合）" % [int(data.get("payload", {}).get("stat_delta", 0)), turns]
		"stat_buff_agi":
			return "敏捷：敏捷 +%d（剩 %d 回合）" % [int(data.get("payload", {}).get("stat_delta", 0)), turns]
		"stat_buff_int":
			return "啟慧：智慧 +%d（剩 %d 回合）" % [int(data.get("payload", {}).get("stat_delta", 0)), turns]
		"stat_buff_con":
			return "健體：體能 +%d（剩 %d 回合）" % [int(data.get("payload", {}).get("stat_delta", 0)), turns]
		"stat_buff_luck":
			return "聚福：幸運 +%d（剩 %d 回合）" % [int(data.get("payload", {}).get("stat_delta", 0)), turns]
		"stat_debuff_str":
			return "壓勁：力量 -%d（剩 %d 回合）" % [abs(int(data.get("payload", {}).get("stat_delta", 0))), turns]
		"stat_debuff_agi":
			return "亂弦：敏捷 -%d（剩 %d 回合）" % [abs(int(data.get("payload", {}).get("stat_delta", 0))), turns]
		"stat_debuff_int":
			return "惑思：智慧 -%d（剩 %d 回合）" % [abs(int(data.get("payload", {}).get("stat_delta", 0))), turns]
		"stat_debuff_con":
			return "奪息：體能 -%d（剩 %d 回合）" % [abs(int(data.get("payload", {}).get("stat_delta", 0))), turns]
		"stat_debuff_luck":
			return "厄運：幸運 -%d（剩 %d 回合）" % [abs(int(data.get("payload", {}).get("stat_delta", 0))), turns]
		"evasion_boost":
			var eva_boost = int(data.get("payload", {}).get("evasion_delta", 0))
			return "輕身：閃避 %+d（剩 %d 回合）" % [eva_boost, turns]
		"root":
			var eva_delta = int(data.get("payload", {}).get("evasion_delta", 0))
			return "定身：閃避 %+d（剩 %d 回合）" % [eva_delta, turns]
		"warm_wine_buff":
			var spd = int(data.get("payload", {}).get("speed_delta", 0))
			var acc = int(data.get("payload", {}).get("accuracy_delta", 0))
			return "暖身酒：速 %+d／命中 %+d（剩 %d 回合）" % [spd, acc, turns]
		"force_element":
			var element = str(data.get("payload", {}).get("element", ""))
			return "元素變化：%s（剩 %d 回合）" % [element, turns]
		_:
			return "%s（剩 %d 回合）" % [effect_id, turns]


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
	_setup_actor_bubble_labels()
	update_ally_panel()
	update_enemy_panel()
	_refresh_all_status_abbrev_labels()

func show_actor_line(actor_id: String, text: String) -> void:
	if actor_id == "" or text == "":
		return
	if not _actor_bubble_labels.has(actor_id):
		_setup_actor_bubble_labels()
	if not _actor_bubble_labels.has(actor_id) or not _actor_bubble_boxes.has(actor_id):
		return
	var bubble = _actor_bubble_labels[actor_id] as Label
	var bubble_box = _actor_bubble_boxes[actor_id] as PanelContainer
	if bubble == null or bubble_box == null:
		return
	var slot := _find_ally_slot_by_actor_id(actor_id)
	if slot:
		_position_bubble_on_portrait(slot, bubble_box)
	var token := int(_actor_bubble_tokens.get(actor_id, 0)) + 1
	_actor_bubble_tokens[actor_id] = token
	var full_text := text
	var total_duration := randf_range(2.0, 4.0)
	var type_step := 0.03
	bubble.text = ""
	bubble_box.visible = true
	for i in range(full_text.length()):
		if int(_actor_bubble_tokens.get(actor_id, -1)) != token:
			return
		bubble.text = full_text.substr(0, i + 1)
		await get_tree().create_timer(type_step).timeout
	var typing_duration := float(full_text.length()) * type_step
	var hold_duration: float = maxf(0.2, total_duration - typing_duration)
	await get_tree().create_timer(hold_duration).timeout
	if int(_actor_bubble_tokens.get(actor_id, -1)) != token:
		return
	bubble_box.visible = false

func show_actor_event_line(actor_id: String, event_key: String) -> void:
	var event_map_any = COMBAT_DIALOGUE.get(event_key, {})
	if typeof(event_map_any) != TYPE_DICTIONARY:
		return
	var event_map: Dictionary = event_map_any
	var lines_any = event_map.get(actor_id, event_map.get("_generic", []))
	if typeof(lines_any) != TYPE_ARRAY:
		return
	var lines: Array = lines_any
	if lines.is_empty():
		return
	var text := str(lines[randi() % lines.size()])
	show_actor_line(actor_id, text)

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

func _setup_actor_bubble_labels() -> void:
	_actor_bubble_labels.clear()
	_actor_bubble_boxes.clear()
	_actor_bubble_tokens.clear()
	for i in range(allies.size()):
		if i >= ally_slots.size():
			continue
		var actor: Dictionary = allies[i]
		var actor_id := str(actor.get("id", ""))
		if actor_id == "":
			continue
		var slot := ally_slots[i] as Control
		if slot == null:
			continue
		_apply_slot_label_font_style(slot)
		var bubble_name := "OSBubble_%s" % actor_id
		var bubble_box := get_node_or_null(bubble_name) as PanelContainer
		var bubble: Label = null
		if bubble_box == null:
			bubble_box = PanelContainer.new()
			bubble_box.name = bubble_name
			bubble_box.visible = false
			bubble_box.top_level = true
			bubble_box.z_index = 20
			bubble_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bubble_box.custom_minimum_size = Vector2(132, 30)
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0, 0, 0, 0.42)
			bg.corner_radius_top_left = 4
			bg.corner_radius_top_right = 4
			bg.corner_radius_bottom_right = 4
			bg.corner_radius_bottom_left = 4
			bubble_box.add_theme_stylebox_override("panel", bg)
			bubble = Label.new()
			bubble.name = "Text"
			bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bubble.size_flags_vertical = Control.SIZE_EXPAND_FILL
			bubble.add_theme_font_override("font", MenuUIFont)
			bubble.add_theme_font_size_override("font_size", 18)
			bubble.add_theme_color_override("font_color", Color(1, 0.97, 0.87, 1))
			bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			bubble.add_theme_constant_override("outline_size", 4)
			bubble_box.add_child(bubble)
			add_child(bubble_box)
		else:
			bubble = bubble_box.get_node_or_null("Text") as Label
			if bubble == null:
				bubble = Label.new()
				bubble.name = "Text"
				bubble_box.add_child(bubble)
		_position_bubble_on_portrait(slot, bubble_box)
		_actor_bubble_labels[actor_id] = bubble
		_actor_bubble_boxes[actor_id] = bubble_box

func _apply_slot_label_font_style(slot: Control) -> void:
	for node_name in ["Name", "HPLabel", "MPLabel"]:
		var label := slot.get_node_or_null("StatusUI/%s" % node_name) as Label
		if label == null:
			continue
		label.add_theme_font_override("font", MenuUIFont)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 4)

func _position_bubble_on_portrait(slot: Control, bubble_box: PanelContainer) -> void:
	var portrait := slot.get_node_or_null("Portrait") as Control
	if portrait == null:
		return
	var portrait_size := portrait.size
	if portrait_size == Vector2.ZERO:
		portrait_size = portrait.custom_minimum_size
	var bubble_size := bubble_box.size
	if bubble_size == Vector2.ZERO:
		bubble_size = bubble_box.custom_minimum_size
	var portrait_global := portrait.global_position
	var x := portrait_global.x + portrait_size.x
	var y := portrait_global.y
	bubble_box.global_position = Vector2(x, y)
	var actor_id := str(slot.get("actor_id"))
	if actor_id != "" and not bool(_bubble_debug_logged.get(actor_id, false)):
		print("[BubblePos] actor=", actor_id, " portrait_global=", portrait_global, " bubble_global=", bubble_box.global_position, " bubble_parent=", bubble_box.get_parent().name, " top_level=", bubble_box.top_level)
		_bubble_debug_logged[actor_id] = true

func _find_ally_slot_by_actor_id(actor_id: String) -> Control:
	for i in range(allies.size()):
		if i >= ally_slots.size():
			continue
		var actor: Dictionary = allies[i]
		if str(actor.get("id", "")) == actor_id:
			return ally_slots[i] as Control
	return null

## 每回合開頭會重新刷新一次 UI
func begin_turn(actor: Dictionary) -> void:
	if _battle_opening_locked:
		return
	if combat_controller:
		if bool(combat_controller.get("battle_finished")) or bool(combat_controller.get("_ending")):
			_enter_battle_end_ui_cleanup()
			return
	current_actor = actor
	current_turn_id = actor.get("id", "")
	var actor_name: String = actor.get("name", "？？")
	print("🎯 UI 開始行動者: ", actor_name)

	update_ally_panel()
	update_enemy_panel()
	_refresh_all_status_abbrev_labels()

	# ⭐ 新增：更新回合高亮
	_update_turn_highlight()

	hide_all_popups()
	action_panel.show()
	on_action_selection = true

	_log_system("輪到「%s」行動。" % actor_name)

func show_battle_result(result: Dictionary) -> void:
	_enter_battle_end_ui_cleanup()
	_pending_battle_result = result.duplicate(true)
	var outcome = str(result.get("result", "victory"))
	var exp = int(result.get("exp", 0))
	var gold = int(result.get("gold", 0))
	var drops: Array = result.get("drops", [])
	var drops_lines: Array = []
	for d in drops:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var drop_id = str(d.get("id", "unknown"))
		var count = int(d.get("count", 1))
		if count <= 0:
			continue
		drops_lines.append("%s x%d" % [drop_id, count])
	var drops_block = "掉落：無"
	if drops_lines.size() > 0:
		drops_block = "掉落：\n" + "\n".join(drops_lines)

	match outcome:
		"defeat":
			battle_result_title.text = "戰鬥失敗"
		_:
			battle_result_title.text = "戰鬥勝利"

	battle_result_body.text = "經驗：%d\n金幣：%d\n%s" % [exp, gold, drops_block]
	action_panel.hide()
	battle_result_overlay.show()
	if battle_result_confirm:
		battle_result_confirm.grab_focus()

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
	_refresh_all_status_abbrev_labels()


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
	_refresh_all_status_abbrev_labels()

## 單一我方成員狀態更新（被打 / 回血 時由 BattleController 呼叫）
func update_ally_status(index: int, actor: Dictionary) -> void:
	if index < 0 or index >= ally_slots.size():
		return
	var slot = ally_slots[index]
	if slot.has_method("update_from_actor"):
		slot.update_from_actor(actor)
	_refresh_all_status_abbrev_labels()


## 單一敵方成員狀態更新
func update_enemy_status(index: int, actor: Dictionary) -> void:
	if index < 0 or index >= enemy_slots.size():
		return
	var slot = enemy_slots[index]
	if slot.has_method("update_from_actor"):
		slot.update_from_actor(actor)
	_refresh_all_status_abbrev_labels()

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

func _process(delta: float) -> void:
	_status_abbrev_accum += delta
	if _status_abbrev_accum < 0.15:
		return
	_status_abbrev_accum = 0.0
	if _has_blinking_tokens:
		_refresh_all_status_abbrev_labels()


func _ensure_status_abbrev_labels() -> void:
	_ally_status_labels.clear()
	for slot in ally_slots:
		_ally_status_labels.append(_ensure_slot_status_label(slot))
	_enemy_status_labels.clear()
	for slot in enemy_slots:
		_enemy_status_labels.append(_ensure_slot_status_label(slot))


func _ensure_slot_status_label(slot: Node) -> RichTextLabel:
	if slot == null:
		return null
	var status_ui: VBoxContainer = slot.get_node_or_null("StatusUI") as VBoxContainer
	if status_ui == null:
		return null
	var name_label: Label = status_ui.get_node_or_null("Name") as Label
	if name_label == null:
		return null

	var name_row: HBoxContainer = status_ui.get_node_or_null("NameRow") as HBoxContainer
	if name_row == null:
		name_row = HBoxContainer.new()
		name_row.name = "NameRow"
		name_row.custom_minimum_size = Vector2(0, 30)
		name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx = name_label.get_index()
		status_ui.remove_child(name_label)
		status_ui.add_child(name_row)
		status_ui.move_child(name_row, idx)
		name_row.add_child(name_label)
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var label: RichTextLabel = name_row.get_node_or_null("StatusAbbrev") as RichTextLabel
	if label == null:
		label = RichTextLabel.new()
		label.name = "StatusAbbrev"
		label.bbcode_enabled = true
		label.fit_content = false
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size = Vector2(120, 30)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.clip_contents = true
		name_row.add_child(label)
	label.text = ""
	return label


func _refresh_all_status_abbrev_labels() -> void:
	_has_blinking_tokens = false
	for i in range(_ally_status_labels.size()):
		var label: RichTextLabel = _ally_status_labels[i]
		if label == null:
			continue
		if i >= allies.size():
			label.text = ""
			continue
		var packed := _build_status_abbrev_text(allies[i])
		label.text = String(packed.get("text", ""))
		if bool(packed.get("blink", false)):
			_has_blinking_tokens = true

	for i in range(_enemy_status_labels.size()):
		var label: RichTextLabel = _enemy_status_labels[i]
		if label == null:
			continue
		if i >= enemies.size():
			label.text = ""
			continue
		var enemy: Dictionary = enemies[i]
		if int(enemy.get("hp", 0)) <= 0:
			label.text = ""
			continue
		var packed_enemy := _build_status_abbrev_text(enemy)
		label.text = String(packed_enemy.get("text", ""))
		if bool(packed_enemy.get("blink", false)):
			_has_blinking_tokens = true


func _build_status_abbrev_text(actor: Dictionary) -> Dictionary:
	var effects: Dictionary = actor.get("status_effects", {}) if typeof(actor.get("status_effects", {})) == TYPE_DICTIONARY else {}
	var debuff_tokens: Array = []
	var buff_tokens: Array = []
	var has_blink := false
	var blink_visible := sin(float(Time.get_ticks_msec()) / 180.0) > 0.0
	var has_blind_token := false
	var has_root_token := false
	var has_focus_token := false
	var has_evasion_token := false

	for effect_id in effects.keys():
		var effect_data: Dictionary = effects[effect_id] if typeof(effects[effect_id]) == TYPE_DICTIONARY else {}
		var turns_left := int(effect_data.get("turns_left", 0))
		if DEBUFF_ABBREV.has(effect_id):
			var dtoken := String(DEBUFF_ABBREV[effect_id])
			if turns_left == 1:
				has_blink = true
				dtoken = dtoken if blink_visible else "·"
			debuff_tokens.append(dtoken)
			if effect_id == "blind":
				has_blind_token = true
			elif effect_id == "root":
				has_root_token = true
			elif effect_id == "focus":
				has_focus_token = true
		elif BUFF_ABBREV.has(effect_id):
			var btoken := String(BUFF_ABBREV[effect_id])
			if turns_left == 1:
				has_blink = true
				btoken = btoken if blink_visible else "·"
			buff_tokens.append(btoken)
			if effect_id == "focus":
				has_focus_token = true
			elif effect_id == "evasion_boost":
				has_evasion_token = true

	var warm_wine: Dictionary = effects.get("warm_wine_buff", {}) if typeof(effects.get("warm_wine_buff", {})) == TYPE_DICTIONARY else {}
	if not warm_wine.is_empty() and not has_blind_token:
		var warm_payload: Dictionary = warm_wine.get("payload", {}) if typeof(warm_wine.get("payload", {})) == TYPE_DICTIONARY else {}
		if int(warm_payload.get("accuracy_delta", 0)) < 0:
			var blind_token := "盲"
			if int(warm_wine.get("turns_left", 0)) == 1:
				has_blink = true
				blind_token = blind_token if blink_visible else "·"
			debuff_tokens.append(blind_token)
			has_blind_token = true

	if int(actor.get("accuracy_mod", 0)) > 0 and not has_focus_token:
		buff_tokens.append("命")
		has_focus_token = true
	if int(actor.get("accuracy_mod", 0)) < 0 and not has_blind_token:
		debuff_tokens.append("盲")
		has_blind_token = true
	if int(actor.get("evasion_mod", 0)) < 0 and not has_root_token:
		debuff_tokens.append("困")
		has_root_token = true
	if int(actor.get("evasion_mod", 0)) > 0 and not has_evasion_token:
		buff_tokens.append("閃")
		has_evasion_token = true

	var battle_mods = actor.get("battle_modifiers", {})
	if typeof(battle_mods) == TYPE_DICTIONARY:
		if float(battle_mods.get("pen_damage_up", 0.0)) > 0.0:
			buff_tokens.append("攻")
		if float(battle_mods.get("pen_damage_resist", 0.0)) > 0.0:
			buff_tokens.append("防")

	var parts: Array = []
	if debuff_tokens.size() > 0:
		parts.append("[color=#ff6b6b]%s[/color]" % "".join(debuff_tokens))
	if buff_tokens.size() > 0:
		parts.append("[color=#67e08a]%s[/color]" % "".join(buff_tokens))
	return {
		"text": " ".join(parts),
		"blink": has_blink
	}


func hide_all_popups() -> void:
	skill_list_popup.hide()
	item_list_popup.hide()
	defense_confirm_popup.hide()
	inner_force_popup.hide()
	target_select_popup.hide()

func _enter_battle_end_ui_cleanup() -> void:
	hide_all_popups()
	if not current_target_focus.is_empty():
		_set_actor_target_focus(current_target_focus, false)
		current_target_focus = {}
	pending_item = {}
	pending_item_user = {}
	pending_skill = {}
	pending_skill_user = {}
	action_panel.hide()
	on_action_selection = false
	waiting_for_action = false


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
	skill_list_popup.show_skills(skills, inner_force, character_skill_db, weapons, current_actor)

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
	if scope == "ally_all" or scope == "enemy_all" or scope == "enemy_all_shared_random_hits" or scope == "enemy_all_per_target_random_hits":
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
	if not current_actor.is_empty():
		current_actor["inner_force"] = force
		if force.has("id"):
			current_actor["inner_force_id"] = str(force.get("id", ""))
		if force.has("element"):
			current_actor["element"] = force["element"]

	var actor_name := str(current_actor.get("name", "俠士"))
	var prefix := str(force.get("prefix", "？"))
	var ftype := str(force.get("type", "？"))
	var boost_weapon := str(force.get("boost_weapon", "？"))
	_log_system("%s 切換內功為「%s・%s」（強化：%s）。" % [actor_name, prefix, ftype, boost_weapon])

	var switch_template := tone.get_tone_text("innerforce_switch", prefix, current_actor.get("id", ""))
	if switch_template == "":
		switch_template = "{name} 調勻內息，氣機運轉一變，整個人的攻守節奏也隨之調整。"
	_log_narration(switch_template.replace("{name}", actor_name))
	var effect_line := InnerForceDB.get_effect_description_line(force, current_actor)
	if effect_line != "":
		_log_system(effect_line)
	var summary_line := InnerForceDB.get_effect_summary_line(force, current_actor)
	if summary_line != "":
		_log_system(summary_line)

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
	var use_scope = String(item.get("use_scope", "none"))
	var item_name: String = str(item.get("name", "???"))
	if not ["battle", "any"].has(use_scope):
		_log_system("戰鬥中無法使用")
		pending_item = {}
		pending_item_user = {}
		return

	pending_item = item
	pending_item_user = current_actor
	_log_system("你使用了「%s」。" % item_name)

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
