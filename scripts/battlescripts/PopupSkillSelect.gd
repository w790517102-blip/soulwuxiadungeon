# ✅ 更新版 PopupSkillSelect.gd
# 支援 weapon_type / category，並加入「拳掌混合規則」：
# - 拳、掌：預設不吃武器限制，可以視為徒手武學
# - 若技能有 require_free_hand = true，則至少要空出一隻手才可用
extends PopupPanel

signal skill_selected(skill_data: Dictionary)
signal selection_cancelled()

@onready var skill_list = $VBoxContainer/SkillList
@onready var description_label = $VBoxContainer/Description
@onready var confirm_button = $VBoxContainer/ButtonRow/Confirm
@onready var cancel_button = $VBoxContainer/ButtonRow/Cancel

var skill_provider: Node = null
var available_skills: Array = []
var valid_skill_indices: Array = []
var selected_index = -1
var inner_force = {}
var equipped_weapons: Array = []
var character_skill_db: Node = null

func _ready():
	confirm_button.disabled = true
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
	skill_provider = skill_provider_ref
	equipped_weapons.clear()
	selected_index = -1
	confirm_button.disabled = true
	skill_list.clear()
	valid_skill_indices.clear()
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
		if skill_provider and skill_provider.has_method("resolve_runtime_skill"):
			skill = skill_provider.resolve_runtime_skill(source_skill, inner_force, actor)
		available_skills.append(skill)
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

		# （未來可以在這裡加更多條件，例如內功狀態、debuff 禁技等等）

		skill_list.add_item(skill_name)
		if skill_provider and skill_provider.has_method("get_skill_color"):
			skill_list.set_item_custom_fg_color(i, skill_provider.get_skill_color(skill, inner_force))
		if can_use:
			valid_skill_indices.append(i)
		else:
			skill_list.set_item_disabled(i, true)

	popup_centered()

func _on_SkillList_item_selected(index: int) -> void:
	selected_index = index
	var skill: Dictionary = available_skills[index]
	var can_use: bool = not skill_list.is_item_disabled(index)

	description_label.text = "【%s】\n類型：%s\n分類：%s\n說明：%s" % [
		skill.get("name", "???"),
		skill.get("weapon_type", "-"),
		skill.get("category", "外功"),
		skill.get("desc", "（未填說明）")
	]

	confirm_button.disabled = not can_use

func _on_Confirm_pressed() -> void:
	if selected_index >= 0 and not confirm_button.disabled:
		emit_signal("skill_selected", available_skills[selected_index])
		hide()

func _on_Cancel_pressed() -> void:
	emit_signal("selection_cancelled")
	hide()
