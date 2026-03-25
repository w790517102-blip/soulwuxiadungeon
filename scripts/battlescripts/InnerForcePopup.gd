# ✅ 修正版 InnerForcePopup.gd（對應新版 PopupPanel + innerforce_switch 敘述）
# 內功選擇彈窗，支援多內功切換，含描述與確認取消按鈕

extends PopupPanel

signal inner_force_selected(force_data: Dictionary)
signal selection_cancelled()

@onready var force_list       = $VBoxContainer/ForceList
@onready var description      = $VBoxContainer/Description
@onready var confirm_button   = $VBoxContainer/ButtonRow/Confirm
@onready var cancel_button    = $VBoxContainer/ButtonRow/Cancel

# ✅ 載入 ToneMap
const ToneMap = preload("res://scripts/battlestyles/ToneMap.gd")
const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")
var tone = ToneMap.new()

var current_actor  : Dictionary = {}
var selected_force : Dictionary = {}
var force_options  : Array      = []


func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	force_list.item_selected.connect(_on_force_selected)


func show_inner_forces(actor: Dictionary) -> void:
	current_actor  = actor
	force_options  = actor.get("available_inner_forces", [])
	selected_force = {}

	force_list.clear()
	description.text = ""

	# 建立清單：顯示「清風・訣（屬性：快）」這種格式
	for force in force_options:
		var prefix  = str(force.get("prefix", "？"))
		var f_type  = str(force.get("type", "？"))
		var element = str(force.get("element", "？"))

		if element == "":
			element = "？"

		var label = "%s・%s（屬性：%s）" % [prefix, f_type, element]
		force_list.add_item(label)

	# 預設選第一個，並顯示描述
	if force_options.size() > 0:
		force_list.select(0)
		_update_description_for_index(0)

	popup_centered()


func _on_force_selected(index: int) -> void:
	_update_description_for_index(index)


# 🔹 更新描述欄位（標題 + 內功風格描述 + 強化武器 + ToneMap 敘事）
func _update_description_for_index(index: int) -> void:
	if index < 0 or index >= force_options.size():
		description.text = ""
		selected_force = {}
		return

	var force: Dictionary = force_options[index]
	selected_force = force

	var prefix       = str(force.get("prefix", ""))
	var f_type       = str(force.get("type", ""))
	var element      = str(force.get("element", ""))
	var boost_weapon = str(force.get("boost_weapon", ""))

	# 標題：清風訣（屬性：快）
	var header = "%s%s（屬性：%s）" % [prefix, f_type, element]

	# 內功本身描述（優先使用 TeamDataManager 裡的 description）
	var main_desc = str(force.get("description", ""))

	# 若資料層沒有寫 description，就給一個 fallback
	if main_desc == "":
		if boost_weapon != "":
			main_desc = "%s%s，內力運行別具一格，能強化「%s」系招式的威力。" % [
				prefix,
				f_type,
				boost_weapon
			]
		else:
			main_desc = "%s%s，內功特性尚待摸索。" % [prefix, f_type]

	# 補一句明講「可強化哪種武器」
	var extra_info = ""
	if boost_weapon != "":
		extra_info = "\n\n（此心法可強化：%s 系招式）" % boost_weapon
	var effect_line := InnerForceDB.get_effect_description_line(force, current_actor)
	var summary_line := InnerForceDB.get_effect_summary_line(force, current_actor)
	var effect_block := ""
	if effect_line != "":
		effect_block += "\n\n" + effect_line
	if summary_line != "":
		effect_block += "\n" + summary_line

	# ToneMap 額外敘事（可選）
	var extra_tone = tone.get_tone_text("innerforce", prefix, current_actor.get("id", ""))
	if extra_tone != "":
		extra_tone = "\n\n" + extra_tone

	description.text = "%s\n\n%s%s%s%s" % [header, main_desc, effect_block, extra_info, extra_tone]


func _on_confirm_pressed() -> void:
	if not selected_force.is_empty():
		hide()
		emit_signal("inner_force_selected", selected_force)


func _on_cancel_pressed() -> void:
	hide()
	emit_signal("selection_cancelled")
