# ✅ 更新版 PopupSkillSelect.gd
# 支援 weapon_type / category，並加入「拳掌混合規則」：
# - 拳、掌：預設不吃武器限制，可以視為徒手武學
# - 若技能有 require_free_hand = true，則至少要空出一隻手才可用
extends PopupPanel
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
const CharacterSkillScript = preload("res://scripts/battlescripts/CharacterSkill.gd")
const SkillViewScript = preload("res://scripts/battlescripts/SkillView.gd")

signal skill_selected(skill_data: Dictionary)
signal selection_cancelled()

@onready var skill_list = $VBoxContainer/SkillList
@onready var description_label = $VBoxContainer/Description
@onready var confirm_button = $VBoxContainer/ButtonRow/Confirm
@onready var cancel_button = $VBoxContainer/ButtonRow/Cancel

var skill_provider: Node = null
var available_skills: Array = []
var valid_skill_indices: Array = []
## Per list entry: why it cannot be used right now ("" = it can), and the muted colour the card-stage menu shows it in
## (null = the normal look).
var unusable_reasons: Array = []
var row_parts: Array = []   # [name, "N MP"] per row, to pad the cost to the right edge
var option_tints: Array = []
var selected_index = -1
var inner_force = {}
var equipped_weapons: Array = []
var character_skill_db: Node = null
var current_actor: Dictionary = {}
var _skill_data_db: Node = SkillDBScript.new()

func _ready():
	confirm_button.disabled = true
	description_label.bbcode_enabled = true
	description_label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description_label.add_theme_constant_override("outline_size", 4)
	hide()
	skill_list.item_selected.connect(_on_SkillList_item_selected)
	confirm_button.pressed.connect(_on_Confirm_pressed)
	cancel_button.pressed.connect(_on_Cancel_pressed)

# ☑️ 顯示技能清單，並依「拳掌混合規則」決定是否可用
func show_skills(
	skills: Array,
	current_inner_force: Dictionary,
	skill_provider_ref: Node,
	equipped_weapon_list: Array,
	actor: Dictionary = {}
) -> void:
	available_skills = []
	inner_force = current_inner_force
	current_actor = actor
	skill_provider = skill_provider_ref
	equipped_weapons.clear()
	selected_index = -1
	confirm_button.disabled = true
	skill_list.clear()
	row_parts.clear()
	valid_skill_indices.clear()
	unusable_reasons.clear()
	option_tints.clear()
	description_label.text = "請選擇一項武學。"

	# 從傳入的 equipped_weapon_list 中設定武器
	# （BattleUI 那邊已經會把空字串過濾掉，沒武器時會傳 ["拳", "掌"]）
	if equipped_weapon_list.size() == 0:
		equipped_weapons = []
	else:
		for w in equipped_weapon_list:
			if w != "":
				equipped_weapons.append(w)

	print("⚔️ 武器清單：", equipped_weapons)

	# 🖐️ 真正「佔手」的實體武器數量（拳/掌不算佔手，只是徒手型態）
	var real_weapon_count = 0
	for w in equipped_weapons:
		if w != "拳" and w != "掌":
			real_weapon_count += 1

	var has_free_hand = real_weapon_count < 2  # fallback（舊規則）
	if not actor.is_empty():
		var aw1 := String(actor.get("weapon_1", ""))
		var aw2 := String(actor.get("weapon_2", ""))
		has_free_hand = (aw1 == "" or aw2 == "")  # ✅ 至少一個武器槽是空的

	for i in range(skills.size()):
		var source_skill: Dictionary = skills[i]
		var skill: Dictionary = source_skill
		if skill_provider and skill_provider.has_method("resolve_effective_skill"):
			skill = skill_provider.resolve_effective_skill(String(source_skill.get("id", "")), actor, {"inner_force": inner_force})
		elif skill_provider and skill_provider.has_method("resolve_runtime_skill"):
			skill = skill_provider.resolve_runtime_skill(source_skill, inner_force, actor)
		var weapon_type: String = skill.get("weapon_type", "")
		var category: String    = skill.get("category", "外功")  # 預設外功
		var require_free_hand: bool = skill.get("require_free_hand", false)

		var skill_name: String = skill_provider.resolve_skill_name(skill, inner_force)

		var can_use = false

		if weapon_type == "拳" or weapon_type == "掌":
			# 🔹 拳 / 掌武學：預設不吃武器限制
			if require_free_hand:
				# 高階拳掌：需要至少一隻手是空的
				can_use = has_free_hand
			else:
				can_use = true
		elif weapon_type == "" or weapon_type == "通用":
			# 🔹 通用技能：不綁武器，直接可用
			can_use = true
		else:
			# 🔹 其他武器型技能：照舊，需要有對應武器
			can_use = weapon_type in equipped_weapons

		# 沒有對應武器就不顯示（拳掌/通用除外）
		if not can_use:
			continue

		available_skills.append(skill)
		# The cost shown here is the one the controller will charge (SkillView), and the skill stays in the list - and
		# stays selectable, so its description can be read - when it cannot be used right now: only its colour is
		# muted (same hue, less saturation and brightness).
		var cost: int = SkillViewScript.mp_cost(actor, skill)
		var verdict: Dictionary = SkillViewScript.check(actor, skill)
		skill_list.add_item("%s　　%d MP" % [skill_name, cost])
		row_parts.append([String(skill_name), "%d MP" % cost])
		var ui_index = skill_list.get_item_count() - 1
		var skill_color := Color.WHITE
		if skill_provider and skill_provider.has_method("get_skill_color"):
			skill_color = skill_provider.get_skill_color(skill, inner_force)
		var usable: bool = bool(verdict.ok)
		if not usable:
			skill_color = SkillViewScript.muted(skill_color)
		skill_list.set_item_custom_fg_color(ui_index, skill_color)
		unusable_reasons.append("" if usable else String(verdict.text))
		option_tints.append(null if usable else skill_color)
		valid_skill_indices.append(ui_index)

	popup_centered()
	_align_costs()
	_align_costs_next_frame()

func _on_SkillList_item_selected(index: int) -> void:
	preload("res://scripts/presentation/CardStageSound.gd").play(self, "SE_card_command_open", 10.0)
	selected_index = index
	var skill: Dictionary = available_skills[index]
	var reason: String = String(unusable_reasons[index]) if index < unusable_reasons.size() else ""
	var can_use: bool = not skill_list.is_item_disabled(index) and reason == ""

	var lines: Array = []
	if reason != "":
		lines.append("[color=#ff7b7b]%s[/color]" % reason)
	lines.append("[b]【%s】[/b]" % String(skill.get("name", "???")))
	lines.append("類型：%s｜分類：%s" % [String(skill.get("weapon_type", "-")), String(skill.get("category", "外功"))])
	lines.append("消耗：內力 %d" % SkillViewScript.mp_cost(current_actor, skill))
	lines.append("說明：%s" % String(skill.get("desc", "（未填說明）")))
	var strikes: Dictionary = SkillViewScript.strike_info(skill, inner_force)
	if int(strikes.delta) != 0:
		lines.append("攻擊段數：基礎 %s → 目前 %s（%s專屬 %+d）" % [String(strikes.base_text), String(strikes.effective_text), String(strikes.source), int(strikes.delta)])
	lines.append("效果：%s" % _build_short_effect_summary(skill))
	for link_line in _build_short_linkage_lines(skill):
		lines.append(link_line)
	description_label.text = "\n".join(lines)

	confirm_button.disabled = not can_use

func _on_Confirm_pressed() -> void:
	if selected_index >= 0 and not confirm_button.disabled:
		preload("res://scripts/presentation/CardStageSound.gd").play(self, "SE_skill_confirm", 10.0)
		emit_signal("skill_selected", available_skills[selected_index])
		hide()

func _on_Cancel_pressed() -> void:
	preload("res://scripts/presentation/CardStageSound.gd").play(self, "SE_action_cancel", 10.0)
	emit_signal("selection_cancelled")
	hide()

func _build_short_effect_summary(skill: Dictionary) -> String:
	return SkillViewScript.effect_summary(skill)


func _build_short_linkage_lines(skill: Dictionary) -> Array:
	if _skill_data_db == null or not _skill_data_db.has_method("get_inner_force_linkage_entries"):
		return []
	var entries_raw = _skill_data_db.get_inner_force_linkage_entries(skill, current_actor, inner_force)
	if typeof(entries_raw) != TYPE_ARRAY:
		return []
	var lines: Array = []
	for row_any in entries_raw:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		var short_text := String(row.get("text_short", ""))
		if short_text == "":
			continue
		var kind := String(row.get("kind", "聯動"))
		var met := bool(row.get("met", false))
		var color = "#87ffb3" if met else "#9aa0aa"
		lines.append("[color=%s]【%s】%s[/color]" % [color, kind, short_text])
	return lines


## Pads each row so its "N MP" ends at the list's right edge, whatever the skill name's length (the row stays
## "name ... N MP"; only the spaces in between change).
func _align_costs() -> void:
	var font: Font = skill_list.get_theme_font("font")
	var font_size: int = skill_list.get_theme_font_size("font_size")
	if font == null or row_parts.size() != skill_list.item_count:
		return
	var target: float = skill_list.size.x - 40.0   # scrollbar, item padding and the selection frame
	var space: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if target <= 0.0 or space <= 0.0:
		return
	for index: int in range(row_parts.size()):
		var parts: Array = row_parts[index]
		var used: float = font.get_string_size(String(parts[0]) + String(parts[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var count: int = maxi(2, int(floor((target - used) / space)))
		skill_list.set_item_text(index, String(parts[0]) + " ".repeat(count) + String(parts[1]))


## The list is laid out a frame after the popup opens; align again once its real width is known.
func _align_costs_next_frame() -> void:
	await get_tree().process_frame
	if visible:
		_align_costs()
