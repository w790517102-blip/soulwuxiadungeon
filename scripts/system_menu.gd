# 掛在 system_menu.tscn 的 Panel 根節點上的腳本
extends Panel
const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")
const SpecialItemUseHandlerScript = preload("res://scripts/items/SpecialItemUseHandler.gd")

@onready var tabs: TabContainer = $VBoxContainer
@onready var item_list: ItemList = $VBoxContainer/道具/ItemList
@onready var item_desc: RichTextLabel = $VBoxContainer/道具/RichTextLabel
@onready var gold_label: Label = $VBoxContainer/道具/GoldLabel
@onready var status_tab: VBoxContainer = get_node_or_null("VBoxContainer/狀態")
@onready var status_gold_label: Label = get_node_or_null("VBoxContainer/狀態/GoldLabel")
@onready var use_button: Button = get_node_or_null("VBoxContainer/道具/UseButton")
@onready var martial_tabs: TabContainer = get_node_or_null("VBoxContainer/武術/MartialTabs")
@onready var weapon_tabs: TabContainer = get_node_or_null("VBoxContainer/武術/MartialTabs/武術/WeaponTabs")
@onready var skill_detail: RichTextLabel = get_node_or_null("VBoxContainer/武術/MartialTabs/武術/SkillDetail")
@onready var use_skill_button: Button = get_node_or_null("VBoxContainer/武術/MartialTabs/武術/UseSkillButton")
@onready var martial_character_select: OptionButton = get_node_or_null("VBoxContainer/武術/MartialTabs/武術/CharacterRow/CharacterSelect")
@onready var character_select: OptionButton = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/CharacterRow/CharacterSelect")
@onready var inner_force_tabs: TabContainer = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/InnerForceTabs")
@onready var inner_force_detail: RichTextLabel = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/InnerForceDetail")
@onready var switch_inner_force_button: Button = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/SwitchInnerForceButton")
@onready var weapon1_button: Button = get_node_or_null("VBoxContainer/裝備/Weapon1Button")
@onready var weapon2_button: Button = get_node_or_null("VBoxContainer/裝備/Weapon2Button")
@onready var armor_head_button: Button = get_node_or_null("VBoxContainer/裝備/ArmorHeadButton")
@onready var armor_body_button: Button = get_node_or_null("VBoxContainer/裝備/ArmorBodyButton")
@onready var armor_hands_button: Button = get_node_or_null("VBoxContainer/裝備/ArmorHandsButton")
@onready var armor_feet_button: Button = get_node_or_null("VBoxContainer/裝備/ArmorFeetButton")
@onready var accessory1_button: Button = get_node_or_null("VBoxContainer/裝備/Accessory1Button")
@onready var accessory2_button: Button = get_node_or_null("VBoxContainer/裝備/Accessory2Button")
@onready var equip_popup: PopupMenu = get_node_or_null("EquipPopup")
@onready var skill_target_popup: PopupMenu = get_node_or_null("SkillTargetPopup")
@onready var equipment_tab: VBoxContainer = get_node_or_null("VBoxContainer/裝備")
var _item_entries: Array = []
var _active_equip_slot = ""
var _selected_skill: Dictionary = {}
var _selected_inner_force: Dictionary = {}
var _selected_inner_force_actor_id = ""
var _selected_actor_id = ""
var _skill_debug_logged: bool = false
var _inner_force_debug_logged: bool = false
var _pending_item_use_id = ""
var _pending_item_effect = ""
var _pending_item_amount = 0
var _item_use_locked = false
var _status_member_slots: Array = []
var _status_hover_layer: CanvasLayer = null
var _status_hover_popup: PanelContainer = null
var _status_hover_label: RichTextLabel = null
var _status_hover_timer: Timer = null
var _pending_status_hover_meta: String = ""
var _pending_status_hover_actor_id: String = ""

const CharacterSkillDB = preload("res://scripts/battlescripts/CharacterSkill.gd")
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
const MenuUIFont = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const TAB_STATUS_NORMAL = preload("res://assets/UI/system_menu/tab_status.png")
const TAB_STATUS_SELECTED = preload("res://assets/UI/system_menu/tab_status_selected.png")
const TAB_ITEM_NORMAL = preload("res://assets/UI/system_menu/tab_item.png")
const TAB_ITEM_SELECTED = preload("res://assets/UI/system_menu/tab_item_selected.png")
const TAB_EQUIP_NORMAL = preload("res://assets/UI/system_menu/tab_equip.png")
const TAB_EQUIP_SELECTED = preload("res://assets/UI/system_menu/tab_equip_selected.png")
const TAB_SKILL_NORMAL = preload("res://assets/UI/system_menu/tab_skill.png")
const TAB_SKILL_SELECTED = preload("res://assets/UI/system_menu/tab_skill_selected.png")
const TAB_QUEST_NORMAL = preload("res://assets/UI/system_menu/tab_quest.png")
const TAB_QUEST_SELECTED = preload("res://assets/UI/system_menu/tab_quest_selected.png")
const TAB_SYSTEM_NORMAL = preload("res://assets/UI/system_menu/tab_system.png")
const TAB_SYSTEM_SELECTED = preload("res://assets/UI/system_menu/tab_system_selected.png")
var _skill_db: Node = CharacterSkillDB.new()
var _skill_data_db: Node = SkillDBScript.new()
var _special_item_use_handler: SpecialItemUseHandler = SpecialItemUseHandlerScript.new()
var _custom_tab_entries: Array = []

const DEFAULT_UNARMED_NAME = "空手"
const WEAPON_RULES = {
	"liuyu": {
		"weapon_1": ["劍"],
		"weapon_2": {"deny": ["劍"]},
	},
	"shumian": {
		"weapon_1": ["筆"],
		"weapon_2": ["拳", "掌"],
	},
	"lieshao": {
		"weapon_1": ["琴"],
		"weapon_2": ["刀"],
	},
}

func _ready():
	_align_to_viewport()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	# ✅ Godot 4 正確用法，Control 沒有 pause_mode，這裡不能設！
	# 所以這行我們移除：pause_mode = Node.PAUSE_MODE_PROCESS ❌

	# ✅ 抓焦點與接收輸入
	focus_mode = Control.FOCUS_ALL
	grab_focus()

	# ✅ 這邊開啟輸入處理
	set_process_unhandled_input(true)
	_set_menu_item_use_locked(false)
	_apply_menu_font_style(self)
	if skill_detail:
		skill_detail.bbcode_enabled = true
	if inner_force_detail:
		inner_force_detail.bbcode_enabled = true
	if item_desc:
		item_desc.bbcode_enabled = true

	if item_list:
		item_list.item_selected.connect(_on_item_selected)
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	if tabs:
		tabs.tab_changed.connect(_on_tab_changed)
	_setup_custom_tab_bar()
	if InventorySync:
		InventorySync.inventory_changed.connect(_on_inventory_changed)
		InventorySync.gold_changed.connect(_on_gold_changed)
		InventorySync.equipment_changed.connect(_on_equipment_changed)
	if martial_tabs:
		martial_tabs.tab_changed.connect(_on_martial_tab_changed)
	if weapon_tabs:
		weapon_tabs.tab_changed.connect(_on_weapon_tab_changed)
		_connect_weapon_lists()
	if use_skill_button:
		use_skill_button.pressed.connect(_on_use_skill_pressed)
	if inner_force_tabs:
		inner_force_tabs.tab_changed.connect(_on_inner_force_tab_changed)
		_connect_inner_force_lists()
	if character_select:
		character_select.item_selected.connect(_on_character_selected)
	if switch_inner_force_button:
		switch_inner_force_button.pressed.connect(_on_switch_inner_force_pressed)
	if weapon1_button:
		weapon1_button.pressed.connect(func(): _open_equip_popup("weapon_1"))
	if weapon2_button:
		weapon2_button.pressed.connect(func(): _open_equip_popup("weapon_2"))
	if armor_head_button:
		armor_head_button.pressed.connect(func(): _open_equip_popup("armor_head"))
	if armor_body_button:
		armor_body_button.pressed.connect(func(): _open_equip_popup("armor_body"))
	if armor_hands_button:
		armor_hands_button.pressed.connect(func(): _open_equip_popup("armor_hands"))
	if armor_feet_button:
		armor_feet_button.pressed.connect(func(): _open_equip_popup("armor_feet"))
	if accessory1_button:
		accessory1_button.pressed.connect(func(): _open_equip_popup("accessory_1"))
	if accessory2_button:
		accessory2_button.pressed.connect(func(): _open_equip_popup("accessory_2"))
	if equip_popup:
		equip_popup.index_pressed.connect(_on_equip_popup_selected)
	if skill_target_popup:
		skill_target_popup.index_pressed.connect(_on_skill_target_selected)
	_setup_status_member_slots()
	_ensure_status_hover_popup()
	_setup_equipment_character_select()
	_refresh_item_tab()
	_refresh_gold()
	_refresh_equipment_tab()
	_refresh_status_tab()
	_refresh_martial_tabs()
	_update_use_button("")
	if tabs:
		_sync_custom_tab_visuals(tabs.current_tab)

func _on_viewport_size_changed() -> void:
	_align_to_viewport()

func _align_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

func _exit_tree() -> void:
	_set_menu_item_use_locked(false)

func _apply_menu_font_style(root: Node) -> void:
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

func _unhandled_input(event):
	if _item_use_locked:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		# 直接呼叫 Autoload：SystemMenu
		SystemMenu._close_system_menu()
		get_viewport().set_input_as_handled()

func _on_tab_changed(tab_index: int) -> void:
	if tabs == null:
		return
	_sync_custom_tab_visuals(tab_index)
	var item_tab_index = $VBoxContainer/道具.get_index()
	var martial_tab_index = $VBoxContainer/武術.get_index()
	if tab_index == item_tab_index:
		_refresh_item_tab()
	elif tab_index == martial_tab_index:
		_refresh_martial_tabs()

func _setup_custom_tab_bar() -> void:
	_custom_tab_entries.clear()
	if tabs == null:
		return

	var entries := [
		{"button": get_node_or_null("CustomTabBar/TabStatus"), "tab_node": get_node_or_null("VBoxContainer/狀態"), "normal": TAB_STATUS_NORMAL, "selected": TAB_STATUS_SELECTED},
		{"button": get_node_or_null("CustomTabBar/TabItem"), "tab_node": get_node_or_null("VBoxContainer/道具"), "normal": TAB_ITEM_NORMAL, "selected": TAB_ITEM_SELECTED},
		{"button": get_node_or_null("CustomTabBar/TabEquip"), "tab_node": get_node_or_null("VBoxContainer/裝備"), "normal": TAB_EQUIP_NORMAL, "selected": TAB_EQUIP_SELECTED},
		{"button": get_node_or_null("CustomTabBar/TabSkill"), "tab_node": get_node_or_null("VBoxContainer/武術"), "normal": TAB_SKILL_NORMAL, "selected": TAB_SKILL_SELECTED},
		{"button": get_node_or_null("CustomTabBar/TabQuest"), "tab_node": get_node_or_null("VBoxContainer/任務"), "normal": TAB_QUEST_NORMAL, "selected": TAB_QUEST_SELECTED},
		{"button": get_node_or_null("CustomTabBar/TabSystem"), "tab_node": get_node_or_null("VBoxContainer/系統"), "normal": TAB_SYSTEM_NORMAL, "selected": TAB_SYSTEM_SELECTED},
	]

	for entry in entries:
		var button: TextureButton = entry.get("button")
		var tab_node: Control = entry.get("tab_node")
		if button == null or tab_node == null:
			continue
		var tab_index := tab_node.get_index()
		button.focus_mode = Control.FOCUS_NONE
		if not button.pressed.is_connected(_on_custom_tab_button_pressed):
			button.pressed.connect(_on_custom_tab_button_pressed.bind(tab_index))
		_custom_tab_entries.append({
			"button": button,
			"tab_index": tab_index,
			"normal": entry.get("normal"),
			"selected": entry.get("selected"),
		})

func _on_custom_tab_button_pressed(tab_index: int) -> void:
	if tabs == null:
		return
	if tab_index < 0 or tab_index >= tabs.get_tab_count():
		return
	tabs.current_tab = tab_index

func _sync_custom_tab_visuals(active_tab_index: int) -> void:
	for entry in _custom_tab_entries:
		var button: TextureButton = entry.get("button")
		var tab_index: int = int(entry.get("tab_index", -1))
		var normal_texture: Texture2D = entry.get("normal")
		var selected_texture: Texture2D = entry.get("selected")
		if button == null:
			continue
		var is_selected := tab_index == active_tab_index
		var display_texture: Texture2D = selected_texture if is_selected else normal_texture
		button.texture_normal = display_texture
		button.texture_hover = display_texture
		button.texture_pressed = display_texture
		button.texture_disabled = display_texture
		button.disabled = is_selected

func _refresh_item_tab() -> void:
	if item_list == null or item_desc == null:
		return
	var selected_index = item_list.get_selected_items()
	var selected_id = ""
	if selected_index.size() > 0:
		selected_id = str(item_list.get_item_metadata(selected_index[0]))
	item_list.clear()
	_item_entries = InventorySync.get_items()
	for item in _item_entries:
		var count = int(item.get("quantity", item.get("count", 0)))
		var item_id = str(item.get("id", ""))
		var label = "%s x%d" % [_as_plain_text(item.get("name", item_id if item_id != "" else "???")), count]
		if InventorySync.is_equipped(item_id, _get_active_character_id()):
			label += "（裝備中）"
		item_list.add_item(label)
		var item_index = item_list.item_count - 1
		item_list.set_item_metadata(item_index, item_id)
		if selected_id != "" and item_id == selected_id:
			item_list.select(item_index)
	if _item_entries.is_empty():
		item_desc.text = "背包裡空空如也。"
		_update_use_button("")
	elif selected_id != "":
		var selected_items = item_list.get_selected_items()
		if selected_items.size() > 0:
			_on_item_selected(selected_items[0])
		elif item_list.item_count > 0:
			item_list.select(0)
			_on_item_selected(0)
		else:
			item_desc.text = "背包裡空空如也。"
			_update_use_button("")
	else:
		item_list.select(0)
		_on_item_selected(0)

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= item_list.item_count:
		return
	var item_id = str(item_list.get_item_metadata(index))
	if item_id == "":
		return
	var item: Dictionary = InventorySync.get_item_by_id(item_id)
	if item.is_empty():
		return
	var name = _as_plain_text(item.get("name", item.get("id", "???")))
	var desc = item.get("desc", item.get("description", ""))
	var count = int(item.get("quantity", item.get("count", 0)))
	var effect_text := ItemDB.get_effect_display_text(item)
	_set_detail_bbcode(item_desc, "[b]%s[/b]\n描述：%s\n效果：%s\n數量：%d" % [name, str(desc), effect_text, count])
	_update_use_button(item_id)

func _on_inventory_changed() -> void:
	if tabs == null:
		return
	var item_tab_index = $VBoxContainer/道具.get_index()
	if tabs.current_tab == item_tab_index:
		_refresh_item_tab()

func _on_equipment_changed() -> void:
	_refresh_item_tab()
	_refresh_equipment_tab()
	_refresh_status_tab()
	if tabs and tabs.current_tab == $VBoxContainer/武術.get_index():
		_refresh_weapon_tab_lists()
		if not _selected_skill.is_empty():
			_update_skill_detail(_selected_skill)

func _on_gold_changed(_new_gold: int) -> void:
	_refresh_gold()

func _refresh_gold() -> void:
	var gold = InventorySync.get_gold()
	if gold_label:
		gold_label.text = "💰 盤纏：%d文" % gold
	if status_gold_label:
		status_gold_label.text = "💰 盤纏：%d文" % gold

func _refresh_martial_tabs() -> void:
	_refresh_skill_tabs()
	_refresh_inner_force_tabs()

func _refresh_skill_tabs() -> void:
	if weapon_tabs == null:
		return
	_refresh_martial_character_select()
	_selected_skill = {}
	_refresh_weapon_tab_lists()
	_update_skill_detail({})

func _refresh_inner_force_tabs() -> void:
	_refresh_character_select()
	_refresh_inner_force_lists()
	_update_inner_force_detail({})

func _connect_weapon_lists() -> void:
	for tab in weapon_tabs.get_children():
		var list := _find_item_list(tab, "SkillList")
		if list and not list.item_selected.is_connected(_on_skill_selected):
			list.item_selected.connect(_on_skill_selected.bind(list))

func _connect_inner_force_lists() -> void:
	if inner_force_tabs == null:
		return
	for tab in inner_force_tabs.get_children():
		var list := _find_item_list(tab, "InnerForceList")
		if list and not list.item_selected.is_connected(_on_inner_force_selected):
			list.item_selected.connect(_on_inner_force_selected.bind(list))

func _on_martial_tab_changed(_tab_index: int) -> void:
	_refresh_martial_tabs()

func _on_weapon_tab_changed(_tab_index: int) -> void:
	_refresh_weapon_tab_lists()
	_update_skill_detail({})

func _on_inner_force_tab_changed(_tab_index: int) -> void:
	_refresh_inner_force_lists()
	_update_inner_force_detail({})

func _refresh_weapon_tab_lists() -> void:
	var actor_id = _get_active_character_id()
	var skill_ids: Array = TeamData.get_known_skill_ids(actor_id) if TeamData and TeamData.has_method("get_known_skill_ids") else []
	var skills: Array = []
	if not skill_ids.is_empty():
		skills = _skill_data_db.get_skills_for_actor(actor_id, null, skill_ids)
	else:
		skills = _skill_db.get_skills(actor_id)
	if not _skill_debug_logged:
		var liuyu_count = TeamData.get_known_skill_ids("liuyu").size() if TeamData and TeamData.has_method("get_known_skill_ids") else -1
		var shumian_count = TeamData.get_known_skill_ids("shumian").size() if TeamData and TeamData.has_method("get_known_skill_ids") else -1
		var lieshao_count = TeamData.get_known_skill_ids("lieshao").size() if TeamData and TeamData.has_method("get_known_skill_ids") else -1
		print("[SkillDebug] all_skills=", _skill_data_db.get_all_skills().size(), " qiliaozhang_found=", not _skill_data_db.get_skill("skill_qiliaozhang").is_empty())
		print("[SkillDebug] known_ids liuyu=", liuyu_count, " shumian=", shumian_count, " lieshao=", lieshao_count)
		print("[SkillDebug] actor_id=", actor_id, " menu_skills_after_filter=", skills.size())

	for tab in weapon_tabs.get_children():
		var list := _find_item_list(tab, "SkillList")
		if list == null:
			if not _skill_debug_logged:
				print("[SkillDebug] weapon tab=", tab.name, " list_not_found")
			continue
		list.clear()
		var weapon_type = String(tab.name).strip_edges()
		if not _skill_debug_logged:
			print("[SkillDebug] weapon tab=", tab.name, " list_path=", list.get_path())
		for skill in skills:
			if typeof(skill) != TYPE_DICTIONARY:
				continue
			if not _skill_data_db.is_available_for_actor(str(skill.get("id", "")), actor_id):
				continue
			var skill_weapon = String(skill.get("weapon_type", "")).strip_edges()
			if skill_weapon != weapon_type:
				continue
			var name = str(skill.get("name", "???"))
			var mp_cost = int(skill.get("mp_cost", 0))
			var can_use_now := _can_use_skill_now(skill, actor_id)
			var label = name
			if mp_cost > 0:
				label = "%s (MP %d)" % [name, mp_cost]
			if not can_use_now:
				label += "（不可施展）"
			list.add_item(label)
			list.set_item_metadata(list.item_count - 1, skill)
		if not _skill_debug_logged:
			print("[SkillDebug] weapon tab=", tab.name, " item_count=", list.item_count)
	if not _skill_debug_logged:
		_skill_debug_logged = true

func _on_skill_selected(index: int, list: ItemList) -> void:
	if list == null:
		return
	var skill = list.get_item_metadata(index)
	if typeof(skill) != TYPE_DICTIONARY:
		return
	_selected_skill = skill
	_update_skill_detail(skill)

func _update_skill_detail(skill: Dictionary) -> void:
	if skill_detail == null:
		return
	if skill.is_empty():
		_set_detail_bbcode(skill_detail, "[font_size=20][b]請選擇武術。[/b][/font_size]\n\n[font_size=20][b]【描述】[/b][/font_size]\n-\n\n[font_size=20][b]【效果】[/b][/font_size]\n-\n\n[font_size=20][b]【內功聯動】[/b][/font_size]\n-")
		if use_skill_button:
			use_skill_button.disabled = true
		return
	var name = str(skill.get("name", "???"))
	var desc = str(skill.get("description", skill.get("desc", "")))
	var weapon_type = str(skill.get("weapon_type", ""))
	var target_scope = str(skill.get("target_scope", ""))
	var target_side = str(skill.get("target_side", ""))
	var require_free_hand = bool(skill.get("require_free_hand", false))
	var actor = _get_actor_by_id(_get_active_character_id())
	var actor_dict: Dictionary = actor if typeof(actor) == TYPE_DICTIONARY else {}
	var current_inner_force: Dictionary = actor_dict.get("inner_force", {}) if typeof(actor_dict.get("inner_force", {})) == TYPE_DICTIONARY else {}
	var lines: Array = []
	lines.append("[font_size=20][b]%s[/b][/font_size]" % name)
	lines.append("")
	lines.append("[font_size=20][b]【描述】[/b][/font_size]")
	lines.append(desc if desc != "" else "（未填寫）")
	lines.append("")
	lines.append("[font_size=20][b]【效果】[/b][/font_size]")
	lines.append_array(_build_skill_effect_lines(skill, weapon_type, target_scope, target_side, require_free_hand))
	var linkage_lines := _build_skill_linkage_lines(skill, actor_dict, current_inner_force)
	if not linkage_lines.is_empty():
		lines.append("")
		lines.append("[font_size=20][b]【內功聯動】[/b][/font_size]")
		lines.append_array(linkage_lines)
	_set_detail_bbcode(skill_detail, "\n".join(lines))
	if use_skill_button:
		var menu_usable = bool(skill.get("menu_usable", false))
		use_skill_button.disabled = (not menu_usable) or (not _can_use_skill_now(skill, _get_active_character_id()))

func _build_skill_effect_lines(skill: Dictionary, weapon_type: String, target_scope: String, target_side: String, require_free_hand: bool) -> Array:
	var out: Array = []
	var effects = skill.get("effects", [])
	if typeof(effects) == TYPE_ARRAY:
		for entry_any in effects:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any
			var effect_type := String(entry.get("type", ""))
			if effect_type == "":
				continue
			match effect_type:
				"damage":
					out.append("• 傷害：%.1fx ATK" % float(entry.get("power", skill.get("power", 1.0))))
				"heal_hp":
					out.append("• 回復生命：%d" % int(entry.get("amount", 0)))
				"mp_heal":
					out.append("• 回復內力：%d" % int(entry.get("amount", 0)))
				_:
					var amount := int(entry.get("amount", 0))
					var turns := int(entry.get("turns", 0))
					if turns > 0:
						out.append("• %s：%+d（%d 回合）" % [effect_type, amount, turns])
					elif amount != 0:
						out.append("• %s：%+d" % [effect_type, amount])
					else:
						out.append("• %s" % effect_type)
	if weapon_type != "":
		out.append("• 武器類型：%s" % weapon_type)
	if require_free_hand:
		out.append("• 需求：至少一手空")
	if target_scope != "":
		out.append("• 目標範圍：%s" % target_scope)
	if target_side != "":
		out.append("• 目標陣營：%s" % target_side)
	if out.is_empty():
		out.append("（無明確效果欄位）")
	return out

func _build_skill_linkage_lines(skill: Dictionary, actor: Dictionary, inner_force: Dictionary) -> Array:
	if _skill_data_db == null or not _skill_data_db.has_method("get_inner_force_linkage_entries"):
		return []
	var entries_raw = _skill_data_db.get_inner_force_linkage_entries(skill, actor, inner_force)
	if typeof(entries_raw) != TYPE_ARRAY:
		return []
	var out: Array = []
	for row_any in entries_raw:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		var kind := String(row.get("kind", "聯動"))
		var text := String(row.get("text_long", ""))
		var met := bool(row.get("met", false))
		if text == "":
			continue
		var color = "#88ffb0" if met else "#9aa0aa"
		out.append("[color=%s]• %s：%s[/color]" % [color, kind, text])
	return out

func _on_use_skill_pressed() -> void:
	if _selected_skill.is_empty():
		return
	if not bool(_selected_skill.get("menu_usable", false)):
		return
	var caster = _get_actor_by_id(_get_active_character_id())
	if caster == null:
		print("[MartialUse] caster not found")
		return
	var target_scope := String(_selected_skill.get("target_scope", "single"))
	if target_scope == "ally_all":
		_apply_world_skill(_selected_skill, caster, null)
		return
	var effect = str(_selected_skill.get("effect", ""))
	if effect == "":
		var effects = _selected_skill.get("effects", [])
		if typeof(effects) == TYPE_ARRAY and (effects as Array).size() > 0:
			var first = (effects as Array)[0]
			if typeof(first) == TYPE_DICTIONARY:
				effect = str((first as Dictionary).get("type", ""))
	if effect == "heal_hp" or effect == "mp_heal":
		_open_skill_target_popup()
		return
	print("[MartialUse] not implemented:", _selected_skill.get("name", ""))

func _open_skill_target_popup() -> void:
	if skill_target_popup == null:
		return
	skill_target_popup.clear()
	var party = TeamData.get_active_party()
	for actor in party:
		var actor_id = _get_actor_id_from_entry(actor)
		if actor_id == "":
			continue
		var actor_name = _get_actor_name_from_entry(actor, actor_id)
		skill_target_popup.add_item(actor_name)
		skill_target_popup.set_item_metadata(skill_target_popup.item_count - 1, actor_id)
	var popup_pos = get_viewport().get_mouse_position()
	if use_skill_button:
		popup_pos = use_skill_button.global_position + Vector2(0, use_skill_button.size.y)
	skill_target_popup.position = popup_pos
	skill_target_popup.popup()

func _on_skill_target_selected(index: int) -> void:
	if skill_target_popup == null:
		return
	if index < 0 or index >= skill_target_popup.item_count:
		return
	var actor_id = str(skill_target_popup.get_item_metadata(index))
	if actor_id == "":
		print("[MartialUse] target not found")
		return
	var target = _get_actor_by_id(actor_id)
	if target == null:
		print("[MartialUse] target not found")
		return
	if _pending_item_use_id != "":
		await _apply_pending_item_use_with_sequence(target)
		_pending_item_use_id = ""
		_pending_item_effect = ""
		_pending_item_amount = 0
		return
	var caster = _get_actor_by_id(_get_active_character_id())
	if caster == null:
		print("[MartialUse] caster not found")
		return
	_apply_world_skill(_selected_skill, caster, target)

func _apply_pending_item_use_with_sequence(target) -> void:
	if target == null or _pending_item_use_id == "":
		return
	var item_def = InventorySync.get_item_by_id(_pending_item_use_id)
	var handled_special_use = false
	if _special_item_use_handler and _special_item_use_handler.can_handle_item(item_def):
		handled_special_use = true
		var before_count = int(item_def.get("count", 0))
		var result = {"handled": false}
		if _special_item_use_handler.should_play_special_use_dialog(_pending_item_use_id, item_def):
			_set_menu_item_use_locked(true)
			result = await _special_item_use_handler.play_special_use_dialog(item_def, target)
			_set_menu_item_use_locked(false)
		_apply_world_item(_pending_item_use_id, _pending_item_effect, _pending_item_amount, target)
		var after_count = int(InventorySync.get_item_by_id(_pending_item_use_id).get("count", 0))
		if bool(result.get("handled", false)) and after_count < before_count and GlobalState and GlobalState.has_method("set_flag"):
			GlobalState.set_flag(_special_item_use_handler.get_read_flag(_pending_item_use_id), true)
	if not handled_special_use:
		_apply_world_item(_pending_item_use_id, _pending_item_effect, _pending_item_amount, target)

func _set_menu_item_use_locked(locked: bool) -> void:
	_item_use_locked = locked
	set_process_unhandled_input(not locked)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	if locked:
		release_focus()
		focus_mode = Control.FOCUS_NONE
	else:
		focus_mode = Control.FOCUS_ALL
		grab_focus()
	_set_tab_switch_locked(locked)
	_set_menu_controls_disabled(self, locked)
	if skill_target_popup:
		if locked:
			skill_target_popup.hide()
	if equip_popup:
		if locked:
			equip_popup.hide()
	if GlobalState:
		GlobalState.set_meta("menu_locked", locked)
	if not locked:
		_refresh_item_tab()
		_refresh_martial_tabs()
		_refresh_equipment_tab()
		_refresh_status_tab()

func _set_tab_switch_locked(locked: bool) -> void:
	if tabs:
		var tab_count = tabs.get_tab_count()
		for i in range(tab_count):
			tabs.set_tab_disabled(i, locked)

func _set_menu_controls_disabled(root: Node, disabled: bool) -> void:
	if root is BaseButton:
		(root as BaseButton).disabled = disabled
	elif root is OptionButton:
		(root as OptionButton).disabled = disabled
	elif root is TabContainer:
		var tab_container = root as TabContainer
		var count = tab_container.get_tab_count()
		for i in range(count):
			tab_container.set_tab_disabled(i, disabled)
	for child in root.get_children():
		_set_menu_controls_disabled(child, disabled)

func _apply_world_skill(skill: Dictionary, caster, target) -> void:
	var effects: Array = []
	if typeof(skill.get("effects", null)) == TYPE_ARRAY:
		effects = skill.get("effects", [])
	if effects.is_empty():
		var effect = str(skill.get("effect", ""))
		if effect != "":
			effects.append({
				"type": effect,
				"amount": int(skill.get("amount", skill.get("heal_amount", 0))),
				"turns": int(skill.get("turns", 0)),
				"element": String(skill.get("element", "")),
			})
	if effects.is_empty():
		print("[MartialUse] no effects:", skill.get("name", ""))
		return

	var caster_id := _get_actor_id_from_entry(caster)
	var mp_cost = int(skill.get("mp_cost", 0))
	var caster_mp = int(_get_actor_value(caster, "mp", 0))
	if caster_mp < mp_cost:
		print("內力不足")
		return
	var caster_max_mp := _get_effective_max_mp(caster, caster_id)
	_set_actor_value(caster, "mp", clamp(caster_mp - mp_cost, 0, caster_max_mp))

	var target_scope := String(skill.get("target_scope", "single"))
	var targets: Array = []
	if target_scope == "ally_all":
		if TeamData and TeamData.has_method("get_active_party"):
			targets = TeamData.get_active_party()
	else:
		if target != null:
			targets.append(target)

	if targets.is_empty():
		print("[MartialUse] target not found")
		return

	for t in targets:
		var target_id := _get_actor_id_from_entry(t)
		for eff in effects:
			if typeof(eff) != TYPE_DICTIONARY:
				continue
			var effect_type := String((eff as Dictionary).get("type", ""))
			match effect_type:
				"heal_hp", "heal":
					var heal := int((eff as Dictionary).get("amount", skill.get("heal_amount", 0)))
					var target_hp := int(_get_actor_value(t, "hp", 0))
					var max_hp := _get_effective_max_hp(t, target_id)
					_set_actor_value(t, "hp", min(target_hp + heal, max_hp))
					print("[WorldSkill] heal_hp target=", _get_actor_value(t, "name", "?"), " +", heal, " / max=", max_hp)
				"mp_heal":
					var restore_mp := int((eff as Dictionary).get("amount", skill.get("amount", 0)))
					var target_mp := int(_get_actor_value(t, "mp", 0))
					var max_mp := _get_effective_max_mp(t, target_id)
					_set_actor_value(t, "mp", min(target_mp + restore_mp, max_mp))
					print("[WorldSkill] mp_heal target=", _get_actor_value(t, "name", "?"), " +", restore_mp, " / max=", max_mp)
				"buff_speed":
					print("[WorldSkill] buff_speed target=", _get_actor_value(t, "name", "?"), " +", int((eff as Dictionary).get("amount", 0)), " turns=", int((eff as Dictionary).get("turns", 0)))
				"debuff_speed":
					print("[WorldSkill] debuff_speed target=", _get_actor_value(t, "name", "?"), " -", int((eff as Dictionary).get("amount", 0)), " turns=", int((eff as Dictionary).get("turns", 0)))
				"force_element":
					print("[WorldSkill] force_element target=", _get_actor_value(t, "name", "?"), " ->", String((eff as Dictionary).get("element", "")), " turns=", int((eff as Dictionary).get("turns", 0)))
				_:
					print("[WorldSkill] unsupported effect=", effect_type)
	print("%s 施展 %s。" % [
		str(_get_actor_value(caster, "name", "???")),
		str(skill.get("name", "???"))
	])
	_refresh_status_tab()

func _refresh_character_select() -> void:
	if character_select == null:
		return
	character_select.clear()
	var party = TeamData.get_active_party()
	for actor in party:
		var actor_id = _get_actor_id_from_entry(actor)
		if actor_id == "":
			continue
		var actor_name = _get_actor_name_from_entry(actor, actor_id)
		character_select.add_item(actor_name)
		character_select.set_item_metadata(character_select.item_count - 1, actor_id)
	if character_select.item_count > 0:
		character_select.select(0)
		_selected_inner_force_actor_id = str(character_select.get_item_metadata(0))

func _on_character_selected(index: int) -> void:
	if character_select == null:
		return
	_selected_inner_force_actor_id = str(character_select.get_item_metadata(index))
	_refresh_inner_force_lists()
	_update_inner_force_detail({})

func _refresh_inner_force_lists() -> void:
	if inner_force_tabs == null:
		return
	var actor = _get_actor_by_id(_selected_inner_force_actor_id)
	var forces: Array = []
	if TeamData and TeamData.has_method("get_known_inner_forces"):
		forces = TeamData.get_known_inner_forces(_selected_inner_force_actor_id)
	elif actor != null:
		forces = _get_actor_value(actor, "available_inner_forces", [])
	var active_force_id = ""
	if TeamData and TeamData.has_method("get_current_inner_force_id"):
		active_force_id = String(TeamData.get_current_inner_force_id(_selected_inner_force_actor_id))
	elif actor != null:
		active_force_id = str(_get_actor_value(actor, "inner_force", {}).get("id", ""))
	for tab in inner_force_tabs.get_children():
		var list := _find_item_list(tab, "InnerForceList")
		if list == null:
			if not _inner_force_debug_logged:
				print("[SkillDebug] inner tab=", tab.name, " list_not_found")
			continue
		list.clear()
		var element = String(tab.name).strip_edges()
		if not _inner_force_debug_logged:
			print("[SkillDebug] inner tab=", tab.name, " list_path=", list.get_path())
		for force in forces:
			if typeof(force) != TYPE_DICTIONARY:
				continue
			if String(force.get("element", "")).strip_edges() != element:
				continue
			var force_id = str(force.get("id", ""))
			var force_name = "%s%s" % [str(force.get("prefix", "???")), str(force.get("type", ""))]
			var label = force_name
			if active_force_id != "" and force_id == active_force_id:
				label += "（使用中）"
			list.add_item(label)
			list.set_item_metadata(list.item_count - 1, force)
		if not _inner_force_debug_logged:
			print("[SkillDebug] inner tab=", tab.name, " item_count=", list.item_count)
	if not _inner_force_debug_logged:
		_inner_force_debug_logged = true

func _find_item_list(tab: Node, name_hint: String) -> ItemList:
	if tab == null:
		return null
	var direct = tab.get_node_or_null(name_hint)
	if direct is ItemList:
		return direct
	var by_name = tab.find_child(name_hint, true, false)
	if by_name is ItemList:
		return by_name
	for child in tab.find_children("*", "ItemList", true, false):
		if child is ItemList:
			return child
	return null

func _on_inner_force_selected(index: int, list: ItemList) -> void:
	if list == null:
		return
	var force = list.get_item_metadata(index)
	if typeof(force) != TYPE_DICTIONARY:
		return
	_selected_inner_force = force
	_update_inner_force_detail(force)

func _update_inner_force_detail(force: Dictionary) -> void:
	if inner_force_detail == null:
		return
	if force.is_empty():
		_set_detail_bbcode(inner_force_detail, "[font_size=20][b]請選擇內功。[/b][/font_size]\n\n[font_size=20][b]【描述】[/b][/font_size]\n-\n\n[font_size=20][b]【效果】[/b][/font_size]\n-\n\n[font_size=20][b]【特殊效果】[/b][/font_size]\n-\n\n[font_size=20][b]【聯動】[/b][/font_size]\n-")
		if switch_inner_force_button:
			switch_inner_force_button.disabled = true
		return
	var prefix = str(force.get("prefix", "???"))
	var desc = _strip_embedded_effect_section(str(force.get("description", "")))
	var element = str(force.get("element", ""))
	var boost_weapon = str(force.get("boost_weapon", ""))
	var boost_pct = float(force.get("boost_damage_pct", 0.0))
	var require_unarmed = bool(force.get("boost_require_unarmed", false))
	var stat_bonus: Dictionary = force.get("stat_bonus", {})
	var lines = []
	lines.append("[font_size=20][b]%s[/b][/font_size]" % prefix)
	lines.append("")
	lines.append("[font_size=20][b]【描述】[/b][/font_size]")
	lines.append(desc if desc != "" else "（未填寫）")
	lines.append("")
	lines.append("[font_size=20][b]【效果】[/b][/font_size]")
	var actor = _get_actor_by_id(_selected_inner_force_actor_id)
	var actor_data: Dictionary = actor if typeof(actor) == TYPE_DICTIONARY else {}
	var effect_line := InnerForceDB.get_effect_description_line(force, actor_data)
	if effect_line != "":
		lines.append(effect_line)
	var summary_line := InnerForceDB.get_effect_summary_line(force, actor_data)
	if summary_line != "" and effect_line == "":
		lines.append(summary_line)
	if element != "":
		lines.append("屬性：%s" % element)
	if not stat_bonus.is_empty():
		lines.append("常駐加成：%s" % str(stat_bonus))
	if boost_weapon != "":
		lines.append("強化武器：%s" % boost_weapon)
	if boost_pct > 0.0:
		lines.append("傷害加成：+%d%%" % int(boost_pct * 100))
	if require_unarmed:
		lines.append("需求：空手")
	var special_effect_desc := String(force.get("special_effect_desc", ""))
	if special_effect_desc != "":
		lines.append("")
		lines.append("[font_size=20][b]【特殊效果】[/b][/font_size]")
		lines.append(special_effect_desc)
	lines.append("")
	lines.append("[font_size=20][b]【聯動】[/b][/font_size]")
	lines.append_array(_build_inner_force_combo_lines(force, actor_data))
	_set_detail_bbcode(inner_force_detail, "\n".join(lines))
	if switch_inner_force_button:
		switch_inner_force_button.disabled = false

func _build_inner_force_combo_lines(force: Dictionary, actor_data: Dictionary) -> Array:
	if _skill_data_db == null or not _skill_data_db.has_method("get_all_skills"):
		return ["（無）"]
	var force_id := String(force.get("id", ""))
	var all_skills: Array = _skill_data_db.get_all_skills()
	var out: Array = []
	for skill_any in all_skills:
		if typeof(skill_any) != TYPE_DICTIONARY:
			continue
		var skill: Dictionary = skill_any
		var entries: Array = _skill_data_db.get_inner_force_linkage_entries(skill, actor_data, force)
		for entry_any in entries:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any
			if not bool(entry.get("met", false)):
				continue
			var kind := String(entry.get("kind", ""))
			if kind != "專屬搭配" and kind != "奧義條件" and kind != "絕技分支":
				continue
			var text := String(entry.get("text_long", ""))
			if text == "":
				continue
			out.append("• %s（%s）：%s" % [String(skill.get("name", "???")), kind, text])
	if out.is_empty():
		out.append("• %s 目前沒有可用的專屬／奧義／絕技聯動。" % force_id)
	return out

func _on_switch_inner_force_pressed() -> void:
	if _selected_inner_force.is_empty():
		return
	var actor = _get_actor_by_id(_selected_inner_force_actor_id)
	if actor == null:
		return
	var force_id = str(_selected_inner_force.get("id", ""))
	var switched = false
	if TeamData and TeamData.has_method("set_inner_force") and force_id != "":
		switched = bool(TeamData.set_inner_force(_selected_inner_force_actor_id, force_id))
	else:
		_set_actor_value(actor, "inner_force", _selected_inner_force.duplicate(true))
		switched = true
	if not switched:
		push_warning("無法切換內功：%s" % force_id)
		return
	print("[InnerForce] switched:", _get_actor_value(actor, "name", ""), _selected_inner_force.get("prefix", ""))
	_refresh_inner_force_lists()
	_refresh_status_tab()

func _get_actor_id_from_entry(actor) -> String:
	if actor == null:
		return ""
	if typeof(actor) == TYPE_DICTIONARY:
		return str(actor.get("id", ""))
	if actor is Object:
		var id_value = actor.get("id")
		if typeof(id_value) == TYPE_STRING and id_value != "":
			return String(id_value)
		if actor is Node:
			return String(actor.name)
	return ""

func _get_actor_name_from_entry(actor, fallback_id: String) -> String:
	if actor == null:
		return fallback_id
	if typeof(actor) == TYPE_DICTIONARY:
		return str(actor.get("name", fallback_id))
	if actor is Object:
		var name_value = actor.get("name")
		if typeof(name_value) == TYPE_STRING and name_value != "":
			return String(name_value)
		if actor is Node:
			return String(actor.name)
	return fallback_id

func _get_actor_value(actor, key: String, default_value):
	if actor == null:
		return default_value
	if typeof(actor) == TYPE_DICTIONARY:
		return actor.get(key, default_value)
	if actor is Object:
		var value = actor.get(key)
		if value == null:
			return default_value
		return value
	return default_value

func _set_actor_value(actor, key: String, value) -> void:
	if actor == null:
		return
	if typeof(actor) == TYPE_DICTIONARY:
		actor[key] = value
		return
	if actor is Object:
		actor.set(key, value)

func _get_inner_force_bonus(actor) -> Dictionary:
	var inner_force = _get_actor_value(actor, "inner_force", {})
	if typeof(inner_force) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = {}
	var stat_bonus = (inner_force as Dictionary).get("stat_bonus", {})
	if typeof(stat_bonus) == TYPE_DICTIONARY:
		for key in (stat_bonus as Dictionary).keys():
			out[key] = (stat_bonus as Dictionary)[key]
	var actor_snapshot := {
		"str": int(_get_actor_value(actor, "str", 0)),
		"con": int(_get_actor_value(actor, "con", 0)),
		"agi": int(_get_actor_value(actor, "agi", 0)),
		"int": int(_get_actor_value(actor, "int", 0)),
		"luck": int(_get_actor_value(actor, "luck", 0)),
	}
	var runtime_effects: Dictionary = InnerForceDB.get_runtime_effects(inner_force, actor_snapshot)
	for stat_key in ["str", "con", "agi", "accuracy", "def", "max_hp", "max_mp", "speed", "evasion", "crit_rate_bonus"]:
		if not runtime_effects.has(stat_key):
			continue
		var incoming = runtime_effects.get(stat_key, 0)
		if typeof(incoming) in [TYPE_FLOAT, TYPE_INT]:
			var current = out.get(stat_key, 0)
			if typeof(incoming) == TYPE_FLOAT or typeof(current) == TYPE_FLOAT:
				out[stat_key] = float(current) + float(incoming)
			else:
				out[stat_key] = int(current) + int(incoming)
	return out

func _get_effective_max_hp(actor, actor_id: String = "") -> int:
	var current_hp := int(_get_actor_value(actor, "hp", 1))
	var base_max_hp := int(_get_actor_value(actor, "max_hp", current_hp))
	var actual_actor_id := actor_id if actor_id != "" else _get_actor_id_from_entry(actor)
	var equip_bonus: Dictionary = {}
	if InventorySync and InventorySync.has_method("get_equipment_stat_bonus"):
		equip_bonus = InventorySync.get_equipment_stat_bonus(actual_actor_id)
	var inner_bonus := _get_inner_force_bonus(actor)
	var effective := base_max_hp + int(equip_bonus.get("max_hp", 0)) + int(inner_bonus.get("max_hp", 0))
	return max(effective, 1)

func _get_effective_max_mp(actor, actor_id: String = "") -> int:
	var current_mp := int(_get_actor_value(actor, "mp", 0))
	var base_max_mp := int(_get_actor_value(actor, "max_mp", current_mp))
	var actual_actor_id := actor_id if actor_id != "" else _get_actor_id_from_entry(actor)
	var equip_bonus: Dictionary = {}
	if InventorySync and InventorySync.has_method("get_equipment_stat_bonus"):
		equip_bonus = InventorySync.get_equipment_stat_bonus(actual_actor_id)
	var inner_bonus := _get_inner_force_bonus(actor)
	var effective := base_max_mp + int(equip_bonus.get("max_mp", 0)) + int(inner_bonus.get("max_mp", 0))
	return max(effective, 0)

func _get_actor_by_id(actor_id: String):
	if TeamData == null:
		return null
	for actor in TeamData.get_active_party():
		var entry_id = _get_actor_id_from_entry(actor)
		if entry_id == actor_id:
			return actor
	return null

func _refresh_status_tab() -> void:
	if _status_member_slots.is_empty():
		return
	var party: Array = []
	if TeamData and TeamData.has_method("get_active_party"):
		party = TeamData.get_active_party()

	for i in range(_status_member_slots.size()):
		if i < party.size():
			_fill_status_member_slot(_status_member_slots[i], party[i])
		else:
			_fill_status_member_slot_empty(_status_member_slots[i])

func _refresh_equipment_tab() -> void:
	var equipped = InventorySync.get_equipped(_get_active_character_id())
	_set_equipment_button(weapon1_button, "主武器", str(equipped.get("weapon_1", "")), "weapon_1")
	_set_equipment_button(weapon2_button, "副武器", str(equipped.get("weapon_2", "")), "weapon_2")
	_set_equipment_button(armor_head_button, "頭部", str(equipped.get("armor_head", "")), "armor_head")
	_set_equipment_button(armor_body_button, "身體", str(equipped.get("armor_body", "")), "armor_body")
	_set_equipment_button(armor_hands_button, "手部", str(equipped.get("armor_hands", "")), "armor_hands")
	_set_equipment_button(armor_feet_button, "腳部", str(equipped.get("armor_feet", "")), "armor_feet")
	_set_equipment_button(accessory1_button, "飾品一", str(equipped.get("accessory_1", "")), "accessory_1")
	_set_equipment_button(accessory2_button, "飾品二", str(equipped.get("accessory_2", "")), "accessory_2")

func _set_equipment_button(button: Button, prefix: String, item_id: String, slot: String) -> void:
	if button == null:
		return
	var display_name = "—"
	if item_id != "":
		var item_def = ItemDB.get_def(item_id)
		if not item_def.is_empty():
			display_name = str(item_def.get("name", item_id))
	elif slot.begins_with("weapon"):
		display_name = DEFAULT_UNARMED_NAME
	if slot == "weapon_2" and _is_slot_locked(slot):
		display_name = "%s（固定）" % DEFAULT_UNARMED_NAME
		button.disabled = true
	else:
		button.disabled = false
	button.text = "%s：%s" % [prefix, display_name]

func _is_slot_locked(slot: String) -> bool:
	if _get_active_character_id() == "shumian" and slot == "weapon_2":
		return true
	return false

func _open_equip_popup(slot: String) -> void:
	if equip_popup == null:
		return
	if _is_slot_locked(slot):
		return
	_active_equip_slot = slot
	equip_popup.clear()
	equip_popup.add_item("<卸下>")
	equip_popup.set_item_metadata(0, "")
	var index = 1
	for item in InventorySync.get_items():
		var item_id = str(item.get("id", ""))
		if item_id == "":
			continue
		var item_def = ItemDB.get_def(item_id)
		if item_def.is_empty():
			continue
		if str(item_def.get("use_action", "none")) != "equip":
			continue
		var item_equip_slot := str(item_def.get("equip_slot", ""))
		if slot.begins_with("weapon"):
			if not item_equip_slot.begins_with("weapon"):
				continue
		elif item_equip_slot != slot:
			continue
		if not _is_weapon_type_allowed(item_def, slot):
			continue
		var name = str(item_def.get("name", item_id))
		equip_popup.add_item(name)
		equip_popup.set_item_metadata(index, item_id)
		index += 1
	equip_popup.popup()

func _is_weapon_type_allowed(item_def: Dictionary, slot: String) -> bool:
	if not slot.begins_with("weapon"):
		return true
	var rules = WEAPON_RULES.get(_get_active_character_id(), {})
	var weapon_type = str(item_def.get("weapon_type", ""))
	var slot_rule = rules.get(slot, [])

	if typeof(slot_rule) == TYPE_DICTIONARY:
		var deny_types: Array = slot_rule.get("deny", [])
		if not deny_types.is_empty() and deny_types.has(weapon_type):
			return false
		var allow_types: Array = slot_rule.get("allow", [])
		if allow_types.is_empty():
			return true
		return allow_types.has(weapon_type)

	var allowed_types: Array = slot_rule if typeof(slot_rule) == TYPE_ARRAY else []
	if allowed_types.is_empty():
		return true
	return allowed_types.has(weapon_type)

func _get_active_character_id() -> String:
	if _selected_actor_id != "":
		return _selected_actor_id
	if TeamData and TeamData.current_team_ids.size() > 0:
		return str(TeamData.current_team_ids[0])
	return "liuyu"

func _get_active_actor():
	if TeamData:
		var party = TeamData.get_active_party()
		for actor in party:
			if _get_actor_id_from_entry(actor) == _get_active_character_id():
				return actor
		if party.size() > 0:
			return party[0]
	return null

func _setup_equipment_character_select() -> void:
	if equipment_tab == null or TeamData == null:
		return
	var row = equipment_tab.get_node_or_null("EquipmentCharacterRow") as HBoxContainer
	var selector: OptionButton = null
	if row == null:
		row = HBoxContainer.new()
		row.name = "EquipmentCharacterRow"
		var label = Label.new()
		label.text = "角色："
		row.add_child(label)
		selector = OptionButton.new()
		selector.name = "EquipmentCharacterSelect"
		row.add_child(selector)
		equipment_tab.add_child(row)
		equipment_tab.move_child(row, 0)
	else:
		selector = row.get_node_or_null("EquipmentCharacterSelect") as OptionButton
	if selector == null:
		return
	_apply_menu_font_style(row)

	for actor in TeamData.get_active_party():
		var actor_id = _get_actor_id_from_entry(actor)
		if actor_id == "":
			continue
		selector.add_item(_get_actor_name_from_entry(actor, actor_id))
		selector.set_item_metadata(selector.item_count - 1, actor_id)
	if selector.item_count > 0:
		selector.select(0)
		_selected_actor_id = str(selector.get_item_metadata(0))
	selector.item_selected.connect(func(index: int):
		_selected_actor_id = str(selector.get_item_metadata(index))
		_refresh_equipment_tab()
		_refresh_weapon_tab_lists()
		_update_skill_detail(_selected_skill)
	)

func _refresh_martial_character_select() -> void:
	if martial_character_select == null or TeamData == null:
		return
	var prev_id = _selected_actor_id
	if martial_character_select.item_count > 0:
		var prev_index := martial_character_select.get_selected()
		if prev_index >= 0 and prev_index < martial_character_select.item_count:
			prev_id = str(martial_character_select.get_item_metadata(prev_index))
	martial_character_select.clear()
	var party: Array = TeamData.get_active_party()
	for actor in party:
		var actor_id := _get_actor_id_from_entry(actor)
		if actor_id == "":
			continue
		martial_character_select.add_item(_get_actor_name_from_entry(actor, actor_id))
		martial_character_select.set_item_metadata(martial_character_select.item_count - 1, actor_id)
	if martial_character_select.item_count <= 0:
		return
	var selected_index := 0
	for i in range(martial_character_select.item_count):
		if str(martial_character_select.get_item_metadata(i)) == prev_id:
			selected_index = i
			break
	martial_character_select.select(selected_index)
	_selected_actor_id = str(martial_character_select.get_item_metadata(selected_index))
	if not martial_character_select.item_selected.is_connected(_on_martial_character_selected):
		martial_character_select.item_selected.connect(_on_martial_character_selected)

func _on_martial_character_selected(index: int) -> void:
	if martial_character_select == null:
		return
	_selected_actor_id = str(martial_character_select.get_item_metadata(index))
	_refresh_weapon_tab_lists()
	_update_skill_detail(_selected_skill)

func _setup_status_member_slots() -> void:
	if status_tab == null:
		return
	var row := status_tab.get_node_or_null("PartyStatusRow") as HBoxContainer
	if row == null:
		return
	_status_member_slots.clear()
	for i in range(3):
		var member := row.get_node_or_null("Member%d" % (i + 1)) as VBoxContainer
		if member == null:
			continue
		var raw_stats_node := member.get_node_or_null("Stats")
		var stats_rich: RichTextLabel = null
		if raw_stats_node is RichTextLabel:
			stats_rich = raw_stats_node as RichTextLabel
		elif raw_stats_node is Label:
			var old_label := raw_stats_node as Label
			stats_rich = RichTextLabel.new()
			stats_rich.name = "Stats"
			stats_rich.custom_minimum_size = old_label.custom_minimum_size
			stats_rich.size_flags_horizontal = old_label.size_flags_horizontal
			stats_rich.size_flags_vertical = old_label.size_flags_vertical
			stats_rich.bbcode_enabled = true
			stats_rich.fit_content = true
			stats_rich.scroll_active = false
			stats_rich.mouse_filter = Control.MOUSE_FILTER_STOP
			var parent_node := old_label.get_parent()
			var idx := old_label.get_index()
			parent_node.add_child(stats_rich)
			parent_node.move_child(stats_rich, idx)
			old_label.queue_free()
		if stats_rich:
			if not stats_rich.meta_hover_started.is_connected(_on_status_meta_hover_started):
				stats_rich.meta_hover_started.connect(_on_status_meta_hover_started.bind(stats_rich))
			if not stats_rich.meta_hover_ended.is_connected(_on_status_meta_hover_ended):
				stats_rich.meta_hover_ended.connect(_on_status_meta_hover_ended)
			if not stats_rich.mouse_exited.is_connected(_hide_status_hover_popup):
				stats_rich.mouse_exited.connect(_hide_status_hover_popup)
		_status_member_slots.append({
			"name": member.get_node_or_null("Name") as Label,
			"job_class": member.get_node_or_null("JobClass") as Label,
			"portrait": member.get_node_or_null("Portrait") as TextureRect,
			"stats": stats_rich,
		})
		var stats_label := stats_rich
		if stats_label:
			stats_label.add_theme_font_override("normal_font", MenuUIFont)
			stats_label.add_theme_font_size_override("normal_font_size", 18)
			stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			stats_label.add_theme_constant_override("outline_size", 4)
			stats_label.add_theme_font_size_override("font_size", 18)
		var portrait := member.get_node_or_null("Portrait") as TextureRect
		if portrait:
			var base_size: Vector2 = portrait.custom_minimum_size
			if base_size == Vector2.ZERO:
				base_size = Vector2(96, 96)
			portrait.custom_minimum_size = base_size * 1.5
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func _fill_status_member_slot(slot_data: Dictionary, actor) -> void:
	var actor_id := _get_actor_id_from_entry(actor)
	var actor_name := _get_actor_name_from_entry(actor, actor_id)
	var base_hp := int(_get_actor_value(actor, "hp", 0))
	var base_max_hp := int(_get_actor_value(actor, "max_hp", base_hp))
	var base_mp := int(_get_actor_value(actor, "mp", 0))
	var base_max_mp := int(_get_actor_value(actor, "max_mp", base_mp))
	var base_atk := int(_get_actor_value(actor, "atk", 0))
	var base_def := int(_get_actor_value(actor, "def", 0))
	var base_speed := int(_get_actor_value(actor, "speed", 0))
	var actor_level := int(_get_actor_value(actor, "level", 1))
	var actor_exp := int(_get_actor_value(actor, "exp", 0))
	var next_exp := 0
	if TeamData and TeamData.has_method("exp_required"):
		next_exp = int(TeamData.exp_required(actor_level))
	var equip_bonus: Dictionary = InventorySync.get_equipment_stat_bonus(actor_id)
	var inner_bonus := _get_inner_force_bonus(actor)
	var bonus_atk := int(equip_bonus.get("atk", 0)) + int(inner_bonus.get("atk", 0))
	var bonus_def := int(equip_bonus.get("def", 0)) + int(inner_bonus.get("def", 0))
	var bonus_max_hp := int(equip_bonus.get("max_hp", 0)) + int(inner_bonus.get("max_hp", 0))
	var bonus_max_mp := int(equip_bonus.get("max_mp", 0)) + int(inner_bonus.get("max_mp", 0))
	var bonus_speed := int(equip_bonus.get("speed", 0)) + int(inner_bonus.get("speed", 0))
	var base_str := int(_get_actor_value(actor, "str", 5))
	var base_agi := int(_get_actor_value(actor, "agi", 5))
	var base_int := int(_get_actor_value(actor, "int", 5))
	var base_con := int(_get_actor_value(actor, "con", 5))
	var base_luck := int(_get_actor_value(actor, "luck", 5))
	var bonus_str := int(equip_bonus.get("str", 0)) + int(inner_bonus.get("str", 0))
	var bonus_agi := int(equip_bonus.get("agi", 0)) + int(inner_bonus.get("agi", 0))
	var bonus_int := int(equip_bonus.get("int", 0)) + int(inner_bonus.get("int", 0))
	var bonus_con := int(equip_bonus.get("con", 0)) + int(inner_bonus.get("con", 0))
	var bonus_luck := int(equip_bonus.get("luck", 0)) + int(inner_bonus.get("luck", 0))
	var base_accuracy := int(_get_actor_value(actor, "accuracy", 100))
	var base_evasion := int(_get_actor_value(actor, "evasion", 0))
	var bonus_accuracy := int(equip_bonus.get("accuracy", 0)) + int(inner_bonus.get("accuracy", 0))
	var bonus_evasion := int(equip_bonus.get("evasion", 0)) + int(inner_bonus.get("evasion", 0))
	var total_accuracy := base_accuracy + bonus_accuracy
	var total_evasion := base_evasion + bonus_evasion
	var agi_stat := float(base_agi + bonus_agi)
	var luck_stat := float(base_luck + bonus_luck)
	var hit_power := int(round((float(total_accuracy) - 100.0) + agi_stat * 0.7 + luck_stat * 0.3))
	var evade_power := int(round(agi_stat * 0.7 + luck_stat * 0.3 + float(total_evasion)))
	var crit_rate_pct := _calc_actor_overview_crit_rate_pct(actor, equip_bonus, inner_bonus)

	var name_label := slot_data.get("name") as Label
	if name_label:
		name_label.text = actor_name
	var job_class_label := slot_data.get("job_class") as Label
	if job_class_label:
		var job_text = str(_get_actor_value(actor, "job", ""))
		var subclass_text = str(_get_actor_value(actor, "subclass", ""))
		if job_text != "" and subclass_text != "":
			job_class_label.text = "%s／%s" % [job_text, subclass_text]
		elif job_text != "":
			job_class_label.text = job_text
		elif subclass_text != "":
			job_class_label.text = subclass_text
		else:
			job_class_label.text = ""

	var portrait := slot_data.get("portrait") as TextureRect
	if portrait:
		portrait.texture = _get_actor_portrait(actor)
		portrait.modulate = Color(1, 1, 1, 1)

	var stats_label := slot_data.get("stats") as RichTextLabel
	if stats_label:
		stats_label.set_meta("actor_id", actor_id)
		var stat_str := "%s  %s  %s  %s  %s" % [
			_status_metric_token("str", "力", base_str + bonus_str),
			_status_metric_token("agi", "敏", base_agi + bonus_agi),
			_status_metric_token("int", "智", base_int + bonus_int),
			_status_metric_token("con", "體", base_con + bonus_con),
			_status_metric_token("luck", "幸", base_luck + bonus_luck),
		]
		stats_label.bbcode_text = "Lv.%d  EXP：%d/%d\n氣血：%d/%d (+%d)\n內力：%d/%d (+%d)\n%s  %s  %s\n%s  %s  %s\n%s" % [
			actor_level, actor_exp, next_exp,
			base_hp, base_max_hp + bonus_max_hp, bonus_max_hp,
			base_mp, base_max_mp + bonus_max_mp, bonus_max_mp,
			_status_metric_token("atk", "攻", base_atk + bonus_atk),
			_status_metric_token("def", "防", base_def + bonus_def),
			_status_metric_token("speed", "身法", base_speed + bonus_speed),
			_status_metric_token("hit_power", "命中", hit_power),
			_status_metric_token("crit", "暴擊", "%.1f%%" % crit_rate_pct),
			_status_metric_token("evade_power", "閃避", evade_power),
			stat_str,
		]

func _calc_actor_overview_crit_rate_pct(actor, equip_bonus: Dictionary, inner_bonus: Dictionary = {}) -> float:
	var luck_stat = int(_get_actor_value(actor, "luck", 0))
	var base_crit = 0.05 + floor(float(luck_stat) / 5.0) * 0.01
	var crit_bonus = float(equip_bonus.get("crit_rate_bonus", 0.0)) + float(inner_bonus.get("crit_rate_bonus", 0.0)) + float(_get_actor_value(actor, "crit_rate_bonus", 0.0))
	var crit_rate = base_crit + crit_bonus
	return clampf(crit_rate * 100.0, 0.0, 95.0)

func _status_metric_token(key: String, label: String, value) -> String:
	return "[url=%s]%s：%s[/url]" % [key, label, str(value)]

func _ensure_status_hover_popup() -> void:
	if _status_hover_popup != null and is_instance_valid(_status_hover_popup):
		return
	if _status_hover_layer == null or not is_instance_valid(_status_hover_layer):
		_status_hover_layer = CanvasLayer.new()
		_status_hover_layer.name = "StatusHoverOverlayLayer"
		_status_hover_layer.layer = 200
		add_child(_status_hover_layer)
	_status_hover_popup = PanelContainer.new()
	_status_hover_popup.name = "StatusHoverPopup"
	_status_hover_popup.visible = false
	_status_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_hover_popup.z_index = 100
	_status_hover_popup.top_level = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.09, 1.0)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.8, 0.8, 0.8, 0.22)
	_status_hover_popup.add_theme_stylebox_override("panel", bg)
	_status_hover_layer.add_child(_status_hover_popup)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_bottom", 8)
	_status_hover_popup.add_child(pad)
	_status_hover_label = RichTextLabel.new()
	_status_hover_label.bbcode_enabled = true
	_status_hover_label.fit_content = true
	_status_hover_label.scroll_active = false
	_status_hover_label.custom_minimum_size = Vector2(300, 0)
	_status_hover_label.add_theme_font_override("normal_font", MenuUIFont)
	_status_hover_label.add_theme_font_size_override("normal_font_size", 18)
	_status_hover_label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	_status_hover_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_status_hover_label.add_theme_constant_override("outline_size", 4)
	pad.add_child(_status_hover_label)
	_ensure_status_hover_timer()

func _ensure_status_hover_timer() -> void:
	if _status_hover_timer != null and is_instance_valid(_status_hover_timer):
		return
	_status_hover_timer = Timer.new()
	_status_hover_timer.name = "StatusHoverDelayTimer"
	_status_hover_timer.one_shot = true
	_status_hover_timer.wait_time = 0.5
	_status_hover_timer.timeout.connect(_on_status_hover_delay_timeout)
	add_child(_status_hover_timer)

func _on_status_meta_hover_started(meta: Variant, stats_label: RichTextLabel) -> void:
	_ensure_status_hover_popup()
	_ensure_status_hover_timer()
	if _status_hover_popup == null or _status_hover_label == null or _status_hover_timer == null:
		return
	var actor_id := String(stats_label.get_meta("actor_id", ""))
	if actor_id == "":
		return
	_pending_status_hover_meta = String(meta)
	_pending_status_hover_actor_id = actor_id
	_status_hover_timer.start(0.5)

func _on_status_meta_hover_ended(_meta: Variant) -> void:
	_hide_status_hover_popup()

func _on_status_hover_delay_timeout() -> void:
	if _pending_status_hover_meta == "" or _pending_status_hover_actor_id == "":
		return
	var actor = _get_actor_by_id(_pending_status_hover_actor_id)
	if actor == null:
		return
	var text := _build_status_hover_text(actor, _pending_status_hover_meta)
	if text == "":
		return
	_status_hover_label.bbcode_text = text
	_status_hover_popup.show()
	_status_hover_popup.reset_size()
	_position_status_hover_popup(get_global_mouse_position())

func _hide_status_hover_popup() -> void:
	_pending_status_hover_meta = ""
	_pending_status_hover_actor_id = ""
	if _status_hover_timer:
		_status_hover_timer.stop()
	if _status_hover_popup:
		_status_hover_popup.hide()

func _position_status_hover_popup(mouse_pos: Vector2) -> void:
	if _status_hover_popup == null:
		return
	var viewport_rect := get_viewport_rect()
	var popup_size := _status_hover_popup.size
	var pos := mouse_pos + Vector2(14, 14)
	if pos.x + popup_size.x > viewport_rect.size.x:
		pos.x = max(0.0, viewport_rect.size.x - popup_size.x)
	if pos.y + popup_size.y > viewport_rect.size.y:
		pos.y = max(0.0, viewport_rect.size.y - popup_size.y)
	_status_hover_popup.position = pos

func _build_status_hover_text(actor, stat_key: String) -> String:
	var equip_bonus: Dictionary = InventorySync.get_equipment_stat_bonus(_get_actor_id_from_entry(actor)) if InventorySync else {}
	var inner_bonus := _get_inner_force_bonus(actor)
	var total_value = int(_get_actor_value(actor, stat_key, 0))
	if stat_key in ["str", "agi", "int", "con", "luck", "atk", "def", "speed", "accuracy", "evasion"]:
		total_value += int(equip_bonus.get(stat_key, 0)) + int(inner_bonus.get(stat_key, 0))
	match stat_key:
		"hit_power":
			var acc_total := int(_get_actor_value(actor, "accuracy", 100)) + int(equip_bonus.get("accuracy", 0)) + int(inner_bonus.get("accuracy", 0))
			var agi_total := int(_get_actor_value(actor, "agi", 0)) + int(equip_bonus.get("agi", 0)) + int(inner_bonus.get("agi", 0))
			var luck_total := int(_get_actor_value(actor, "luck", 0)) + int(equip_bonus.get("luck", 0)) + int(inner_bonus.get("luck", 0))
			var hit_power := int(round((float(acc_total) - 100.0) + float(agi_total) * 0.7 + float(luck_total) * 0.3))
			return "[b]命中[/b]\n影響攻擊命中的對抗能力值（不是命中率）。\n目前值：%d\n拆解：敏項 %.1f + 幸項 %.1f + 其他 %d" % [
				hit_power, float(agi_total) * 0.7, float(luck_total) * 0.3, acc_total - 100
			]
		"evade_power":
			var evade_total := int(_get_actor_value(actor, "evasion", 0)) + int(equip_bonus.get("evasion", 0)) + int(inner_bonus.get("evasion", 0))
			var agi_total := int(_get_actor_value(actor, "agi", 0)) + int(equip_bonus.get("agi", 0)) + int(inner_bonus.get("agi", 0))
			var luck_total := int(_get_actor_value(actor, "luck", 0)) + int(equip_bonus.get("luck", 0)) + int(inner_bonus.get("luck", 0))
			var evade_power := int(round(float(agi_total) * 0.7 + float(luck_total) * 0.3 + float(evade_total)))
			return "[b]閃避[/b]\n影響躲避攻擊的對抗能力值（不是閃避率）。\n目前值：%d\n拆解：敏項 %.1f + 幸項 %.1f + 其他 %d" % [
				evade_power, float(agi_total) * 0.7, float(luck_total) * 0.3, evade_total
			]
		"crit":
			var crit_pct := _calc_actor_overview_crit_rate_pct(actor, equip_bonus, inner_bonus)
			return "[b]暴擊[/b]\n目前顯示：%.1f%%\n可逆來源：裝備 %+0.1f%%、內功 %+0.1f%%" % [
				crit_pct, float(equip_bonus.get("crit_rate_bonus", 0.0)) * 100.0, float(inner_bonus.get("crit_rate_bonus", 0.0)) * 100.0
			]
		_:
			var equip_delta := int(equip_bonus.get(stat_key, 0))
			var inner_delta := int(inner_bonus.get(stat_key, 0))
			var reversible := equip_delta + inner_delta
			return "[b]%s[/b]\n目前值：%d\n可逆來源：裝備 %+d、內功 %+d（合計 %+d）" % [
				_status_key_display_name(stat_key), total_value, equip_delta, inner_delta, reversible
			]

func _status_key_display_name(stat_key: String) -> String:
	match stat_key:
		"str":
			return "力"
		"agi":
			return "敏"
		"int":
			return "智"
		"con":
			return "體"
		"luck":
			return "幸"
		"atk":
			return "攻擊"
		"def":
			return "防禦"
		"speed":
			return "速度"
		"hit_power":
			return "命中"
		"evade_power":
			return "閃避"
		"crit":
			return "暴擊"
		_:
			return stat_key

func _fill_status_member_slot_empty(slot_data: Dictionary) -> void:
	var name_label := slot_data.get("name") as Label
	if name_label:
		name_label.text = "—"
	var job_class_label := slot_data.get("job_class") as Label
	if job_class_label:
		job_class_label.text = ""
	var portrait := slot_data.get("portrait") as TextureRect
	if portrait:
		portrait.texture = null
		portrait.modulate = Color(0.4, 0.4, 0.4, 1)
	var stats_label := slot_data.get("stats") as RichTextLabel
	if stats_label:
		stats_label.bbcode_text = "空位"

func _get_actor_portrait(actor) -> Texture2D:
	var portrait_path := str(_get_actor_value(actor, "portrait_path", ""))
	if portrait_path != "":
		var tex = load(portrait_path)
		if tex is Texture2D:
			return tex
	return null



func _has_walnut_cracker() -> bool:
	var cracker = InventorySync.get_item_by_id("misc_walnut_cracker")
	return int(cracker.get("count", 0)) > 0


func _party_can_use_walnut() -> bool:
	if _has_walnut_cracker():
		return true
	if TeamData and TeamData.has_method("get_active_party"):
		for party_member in TeamData.get_active_party():
			if int(_get_actor_value(party_member, "str", 0)) > 30:
				return true
	return false

func _open_party_target_popup() -> void:
	if skill_target_popup == null:
		return
	skill_target_popup.clear()
	for actor in TeamData.get_active_party():
		var actor_id = _get_actor_id_from_entry(actor)
		if actor_id == "":
			continue
		skill_target_popup.add_item(_get_actor_name_from_entry(actor, actor_id))
		skill_target_popup.set_item_metadata(skill_target_popup.item_count - 1, actor_id)
	skill_target_popup.popup()


func _status_name_zh(status_id: String) -> String:
	match status_id:
		"stun":
			return "暈眩"
		"poison":
			return "中毒"
		"confuse":
			return "混亂"
		"slow":
			return "緩速"
		_:
			return status_id


func _push_world_item_feedback(lines: Array) -> void:
	if lines.is_empty():
		return
	for line in lines:
		print("[WorldItem] %s" % String(line))
	if item_desc:
		var old_text = item_desc.text
		_set_detail_bbcode(item_desc, "【使用結果】\n%s\n\n%s" % ["\n".join(lines), old_text])

func _set_detail_bbcode(label: RichTextLabel, content: String) -> void:
	if label == null:
		return
	label.bbcode_enabled = true
	label.text = content

func _as_plain_text(value) -> String:
	var raw := str(value)
	var regex := RegEx.new()
	if regex.compile("\\[[^\\]]+\\]") == OK:
		return regex.sub(raw, "", true)
	return raw

func _strip_embedded_effect_section(desc: String) -> String:
	var marker := "【效果】"
	var idx := desc.find(marker)
	if idx == -1:
		return desc
	return desc.substr(0, idx).strip_edges()

func _apply_world_item(item_id: String, effect: String, amount: int, target, consume_item: bool = true) -> void:
	if target == null:
		return
	var should_consume := true
	var target_id := _get_actor_id_from_entry(target)
	var target_hp = int(_get_actor_value(target, "hp", 0))
	var target_mp = int(_get_actor_value(target, "mp", 0))
	var item_def: Dictionary = InventorySync.get_item_by_id(item_id)
	var feedback_lines: Array = []
	if effect == "heal" or effect == "heal_hp":
		var max_hp := _get_effective_max_hp(target, target_id)
		_set_actor_value(target, "hp", min(target_hp + amount, max_hp))
	elif effect == "mp_heal":
		var max_mp := _get_effective_max_mp(target, target_id)
		_set_actor_value(target, "mp", min(target_mp + amount, max_mp))
	elif effect == "perm_stat":
		if not _apply_world_perm_stat(target, item_def):
			return
	elif effect == "heal_by_stat":
		var heal_amount := _calc_world_scaled_item_amount(item_def, target)
		var max_hp2 := _get_effective_max_hp(target, target_id)
		_set_actor_value(target, "hp", min(target_hp + heal_amount, max_hp2))
	elif effect == "mp_heal_by_stat":
		var mp_heal_amount := _calc_world_scaled_item_amount(item_def, target)
		var max_mp2 := _get_effective_max_mp(target, target_id)
		_set_actor_value(target, "mp", min(target_mp + mp_heal_amount, max_mp2))
	elif effect == "apply_battle_buff":
		if not _apply_world_next_battle_buff(target, item_def):
			return
	elif effect == "walnut":
		var req_key := str(item_def.get("require_stat", "str")).to_lower()
		var req_min := int(item_def.get("require_min", 31))
		var req_val := int(_get_actor_value(target, req_key, 0))
		var has_cracker := _has_walnut_cracker()
		if req_val < req_min and not has_cracker:
			should_consume = false
		else:
			var hp_restore := int(item_def.get("hp_restore", 30))
			var mp_restore := int(item_def.get("mp_restore", 10))
			var max_hp3 := _get_effective_max_hp(target, target_id)
			var max_mp3 := _get_effective_max_mp(target, target_id)
			_set_actor_value(target, "hp", min(target_hp + hp_restore, max_hp3))
			_set_actor_value(target, "mp", min(target_mp + mp_restore, max_mp3))
	elif effect == "cure_status":
		if item_def.is_empty():
			return
		var status_id := str(item_def.get("status_id", ""))
		if status_id == "":
			return
		if not _ensure_world_status_effects(target):
			return
		var effects = _get_actor_value(target, "status_effects", {})
		if typeof(effects) == TYPE_DICTIONARY:
			var had_effect = effects.has(status_id)
			effects.erase(status_id)
			_set_actor_value(target, "status_effects", effects)
			if had_effect:
				match status_id:
					"stun":
						feedback_lines.append("瓶口一傾，清冽藥氣直衝眉心；方才的昏沉像霧一樣散了。")
					"poison":
						feedback_lines.append("藥末入口，苦意先到；腑中翻湧片刻，毒意竟慢慢退了下去。")
					"confuse":
						feedback_lines.append("丸化喉間，心口微暖；雜念自息，眼神也重新聚焦。")
					_:
						feedback_lines.append("藥力入經，紊亂氣息漸漸平復。")
				feedback_lines.append("%s解除。" % _status_name_zh(status_id))
	elif effect == "warm_wine":
		if not _ensure_world_status_effects(target):
			return
		var effects = _get_actor_value(target, "status_effects", {})
		if typeof(effects) != TYPE_DICTIONARY:
			return
		if effects.has("slow"):
			effects.erase("slow")
			_set_actor_value(target, "status_effects", effects)
			feedback_lines.append("溫酒入胃，熱意走遍四肢；沉得像灌鉛的腳步忽然一鬆，身子輕了。")
			feedback_lines.append("緩速解除。")
		else:
			var turns := 3
			if not item_def.is_empty():
				turns = max(int(item_def.get("turns", 3)), 1)
			effects["warm_wine_buff"] = {
				"payload": {"speed_delta": 10, "accuracy_delta": -5},
				"turns_left": turns,
			}
			_set_actor_value(target, "status_effects", effects)
			var base_speed := int(_get_actor_value(target, "base_speed", _get_actor_value(target, "speed", 0)))
			_set_actor_value(target, "base_speed", base_speed)
			_set_actor_value(target, "speed", base_speed + 10)
			var base_accuracy := int(_get_actor_value(target, "base_accuracy", _get_actor_value(target, "accuracy", 100)))
			_set_actor_value(target, "base_accuracy", base_accuracy)
			_set_actor_value(target, "accuracy", base_accuracy - 5)
			_set_actor_value(target, "accuracy_mod", -5)
			feedback_lines.append("他仰頭灌下暖身酒，血脈像被火點著，步伐跟著快了；可酒勁一上頭，眼前也微微發顫。")
			feedback_lines.append("速度上升，命中下降（%d回合）。" % turns)
	else:
		print("[ItemUse] unsupported world effect:", effect)
		return
	if consume_item and should_consume:
		InventorySync.consume_item(item_id, 1)
	_push_world_item_feedback(feedback_lines)
	_refresh_status_tab()
	_refresh_item_tab()


func _calc_world_scaled_item_amount(item_def: Dictionary, target) -> int:
	var stat_key := str(item_def.get("stat_key", "")).to_lower()
	var stat_val := int(_get_actor_value(target, stat_key, 0))
	var base_amount := int(item_def.get("base_amount", item_def.get("amount", 0)))
	var scale := float(item_def.get("scale", 1.0))
	var raw_amount := int(round(base_amount + stat_val * scale))
	var min_amount := int(item_def.get("min_amount", raw_amount))
	var max_amount := int(item_def.get("max_amount", raw_amount))
	if max_amount < min_amount:
		max_amount = min_amount
	return clamp(raw_amount, min_amount, max_amount)


func _apply_world_perm_stat(target, item_def: Dictionary) -> bool:
	if TeamData == null or not TeamData.has_method("add_perm_stat"):
		return false
	var actor_id := _get_actor_id_from_entry(target)
	if actor_id == "":
		return false
	var stat_key := str(item_def.get("stat_key", "")).to_lower()
	var amount := int(item_def.get("amount", 0))
	if stat_key == "" or amount == 0:
		return false
	if not bool(TeamData.add_perm_stat(actor_id, stat_key, amount)):
		return false
	if TeamData.has_method("get_character_by_id"):
		var updated_actor: Dictionary = TeamData.get_character_by_id(actor_id)
		_set_actor_value(target, stat_key, int(updated_actor.get(stat_key, _get_actor_value(target, stat_key, 0))))
	return true


func _apply_world_next_battle_buff(target, item_def: Dictionary) -> bool:
	if TeamData == null or not TeamData.has_method("add_next_battle_modifier"):
		return false
	var actor_id := _get_actor_id_from_entry(target)
	if actor_id == "":
		return false
	var buff_key := str(item_def.get("buff_key", ""))
	var buff_value := float(item_def.get("buff_value", 0.0))
	if buff_key == "" or buff_value == 0.0:
		return false
	return bool(TeamData.add_next_battle_modifier(actor_id, buff_key, buff_value))

func _ensure_world_status_effects(target) -> bool:
	var effects = _get_actor_value(target, "status_effects", null)
	if typeof(effects) != TYPE_DICTIONARY:
		_set_actor_value(target, "status_effects", {})
	return true

func _can_use_skill_now(skill: Dictionary, actor_id: String) -> bool:
	if skill.is_empty() or actor_id == "":
		return false

	# 優先走 SkillDB 同一套武器相容判定，避免 UI / Battle 規則漂移
	if _skill_data_db and _skill_data_db.has_method("is_weapon_compatible"):
		var actor = _get_actor_by_id(actor_id)
		if actor == null:
			return false
		var actor_for_check = actor
		if InventorySync and InventorySync.has_method("get_equipped"):
			var equipped = InventorySync.get_equipped(actor_id)
			if typeof(equipped) == TYPE_DICTIONARY:
				var actor_copy: Dictionary = {}
				if typeof(actor) == TYPE_DICTIONARY:
					actor_copy = (actor as Dictionary).duplicate(true)
				actor_copy["weapon_1"] = _resolve_equipped_weapon_type_with_fallback(
					String((equipped as Dictionary).get("weapon_1", "")),
					String(actor_copy.get("weapon_1", ""))
				)
				actor_copy["weapon_2"] = _resolve_equipped_weapon_type_with_fallback(
					String((equipped as Dictionary).get("weapon_2", "")),
					String(actor_copy.get("weapon_2", ""))
				)
				actor_for_check = actor_copy
		return bool(_skill_data_db.is_weapon_compatible(skill, actor_for_check))

	# fallback（理論上不應走到）
	return true

func _resolve_equipped_weapon_type(item_id: String) -> String:
	if item_id == "":
		return ""
	var item_def = ItemDB.get_def(item_id)
	if item_def.is_empty():
		return ""
	return String(item_def.get("weapon_type", ""))

func _resolve_equipped_weapon_type_with_fallback(item_id: String, fallback_weapon_type: String) -> String:
	var resolved_weapon_type := _resolve_equipped_weapon_type(item_id)
	if resolved_weapon_type != "":
		return resolved_weapon_type
	return fallback_weapon_type

func _on_equip_popup_selected(index: int) -> void:
	if equip_popup == null:
		return
	if _active_equip_slot == "":
		return
	var item_id = str(equip_popup.get_item_metadata(index))
	if item_id == "":
		InventorySync.unequip(_active_equip_slot, _get_active_character_id())
		return
	if InventorySync.has_method("equip_item_to_slot"):
		InventorySync.equip_item_to_slot(item_id, _active_equip_slot, _get_active_character_id())
	else:
		InventorySync.equip_item(item_id, _get_active_character_id())

func _on_use_pressed() -> void:
	if _item_use_locked:
		return
	if item_list == null:
		return
	var selected_items = item_list.get_selected_items()
	if selected_items.is_empty():
		return
	var item_id = str(item_list.get_item_metadata(selected_items[0]))
	if item_id == "":
		return
	var item_def = InventorySync.get_item_by_id(item_id)
	if item_def.is_empty():
		return
	var use_action = str(item_def.get("use_action", "none"))
	var use_scope = str(item_def.get("use_scope", "none"))
	if use_action == "consume":
		if use_scope == "any" or use_scope == "world":
			var effect = str(item_def.get("effect", ""))
			var amount = int(item_def.get("amount", 0))
			if effect == "walnut" and not _party_can_use_walnut():
				if item_desc:
					item_desc.text = "未達到條件，無法使用"
				await _play_walnut_fail_dialog()
				return
			var target_scope = str(item_def.get("target_scope", "ally_single"))
			if target_scope == "ally_single" or target_scope == "single":
				_pending_item_use_id = item_id
				_pending_item_effect = effect
				_pending_item_amount = amount
				_open_party_target_popup()
			elif target_scope == "ally_all":
				if TeamData and TeamData.has_method("get_active_party"):
					for party_member in TeamData.get_active_party():
						_apply_world_item(item_id, effect, amount, party_member, false)
					InventorySync.consume_item(item_id, 1)
					_refresh_status_tab()
					_refresh_item_tab()
			else:
				var target = _get_actor_by_id(_get_active_character_id())
				if target:
					_apply_world_item(item_id, effect, amount, target)
		return
	if use_action == "equip":
		if use_scope != "any" and use_scope != "world":
			return
		var slot = str(item_def.get("equip_slot", ""))
		if slot == "":
			return
		if InventorySync.is_equipped(item_id, _get_active_character_id()):
			InventorySync.unequip(slot, _get_active_character_id())
			print("[Unequip] slot=%s" % slot)
		else:
			InventorySync.equip_item(item_id, _get_active_character_id())
			print("[Equip] slot=%s id=%s" % [slot, item_id])
		return

func _play_walnut_fail_dialog() -> void:
	if _special_item_use_handler == null:
		return
	var lines = _special_item_use_handler.get_walnut_fail_dialog_lines()
	if lines.is_empty():
		return
	_set_menu_item_use_locked(true)
	await _special_item_use_handler.play_foreground_sequence(lines)
	_set_menu_item_use_locked(false)

func _update_use_button(item_id: String) -> void:
	if use_button == null:
		return
	if item_id == "":
		use_button.disabled = true
		use_button.text = "不可使用"
		return
	var item_def = InventorySync.get_item_by_id(item_id)
	if item_def.is_empty():
		use_button.disabled = true
		use_button.text = "不可使用"
		return
	var use_action = str(item_def.get("use_action", "none"))
	var use_scope = str(item_def.get("use_scope", "none"))
	if use_action == "consume":
		if use_scope == "any" or use_scope == "world":
			use_button.disabled = false
			use_button.text = "使用"
		elif use_scope == "battle":
			use_button.disabled = true
			use_button.text = "戰鬥可用"
		else:
			use_button.disabled = true
			use_button.text = "不可使用"
		return
	if use_action == "equip":
		if use_scope == "any" or use_scope == "world":
			use_button.disabled = false
			use_button.text = "卸下" if InventorySync.is_equipped(item_id, _get_active_character_id()) else "裝備"
		else:
			use_button.disabled = true
			use_button.text = "不可在此更換"
		return
	use_button.disabled = true
	use_button.text = "不可使用"
