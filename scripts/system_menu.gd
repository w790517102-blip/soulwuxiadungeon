# 掛在 system_menu.tscn 的 Panel 根節點上的腳本
extends Panel

@onready var tabs: TabContainer = $VBoxContainer
@onready var item_list: ItemList = $VBoxContainer/道具/ItemList
@onready var item_desc: RichTextLabel = $VBoxContainer/道具/RichTextLabel
@onready var gold_label: Label = $VBoxContainer/道具/GoldLabel
@onready var status_gold_label: Label = get_node_or_null("VBoxContainer/狀態/GoldLabel")
@onready var status_atk_label: Label = get_node_or_null("VBoxContainer/狀態/StatusAtkLabel")
@onready var status_def_label: Label = get_node_or_null("VBoxContainer/狀態/StatusDefLabel")
@onready var status_hp_label: Label = get_node_or_null("VBoxContainer/狀態/StatusHpLabel")
@onready var status_mp_label: Label = get_node_or_null("VBoxContainer/狀態/StatusMpLabel")
@onready var status_speed_label: Label = get_node_or_null("VBoxContainer/狀態/StatusSpeedLabel")
@onready var use_button: Button = get_node_or_null("VBoxContainer/道具/UseButton")
@onready var martial_tabs: TabContainer = get_node_or_null("VBoxContainer/武術/MartialTabs")
@onready var weapon_tabs: TabContainer = get_node_or_null("VBoxContainer/武術/MartialTabs/武術/WeaponTabs")
@onready var skill_detail: RichTextLabel = get_node_or_null("VBoxContainer/武術/MartialTabs/武術/SkillDetail")
@onready var use_skill_button: Button = get_node_or_null("VBoxContainer/武術/MartialTabs/武術/UseSkillButton")
@onready var character_select: OptionButton = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/CharacterRow/CharacterSelect")
@onready var inner_force_tabs: TabContainer = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/InnerForceTabs")
@onready var inner_force_detail: RichTextLabel = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/InnerForceDetail")
@onready var switch_inner_force_button: Button = get_node_or_null("VBoxContainer/武術/MartialTabs/內功/SwitchInnerForceButton")
@onready var weapon1_button: Button = get_node_or_null("VBoxContainer/裝備/Weapon1Button")
@onready var weapon2_button: Button = get_node_or_null("VBoxContainer/裝備/Weapon2Button")
@onready var armor_button: Button = get_node_or_null("VBoxContainer/裝備/ArmorButton")
@onready var accessory_button: Button = get_node_or_null("VBoxContainer/裝備/AccessoryButton")
@onready var equip_popup: PopupMenu = get_node_or_null("EquipPopup")
@onready var skill_target_popup: PopupMenu = get_node_or_null("SkillTargetPopup")
var _item_entries: Array = []
var _active_equip_slot = ""
var _selected_skill: Dictionary = {}
var _selected_inner_force: Dictionary = {}
var _selected_inner_force_actor_id = ""
var _skill_debug_logged: bool = false

const CharacterSkillDB = preload("res://scripts/battlescripts/CharacterSkill.gd")
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
var _skill_db: Node = CharacterSkillDB.new()
var _skill_data_db: Node = SkillDBScript.new()

const DEFAULT_UNARMED_NAME = "空手"
const WEAPON_RULES = {
	"liuyu": {
		"weapon_1": ["劍"],
		"weapon_2": [],
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
	# ✅ Godot 4 正確用法，Control 沒有 pause_mode，這裡不能設！
	# 所以這行我們移除：pause_mode = Node.PAUSE_MODE_PROCESS ❌

	# ✅ 抓焦點與接收輸入
	focus_mode = Control.FOCUS_ALL
	grab_focus()

	# ✅ 這邊開啟輸入處理
	set_process_unhandled_input(true)

	if item_list:
		item_list.item_selected.connect(_on_item_selected)
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	if tabs:
		tabs.tab_changed.connect(_on_tab_changed)
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
	if armor_button:
		armor_button.pressed.connect(func(): _open_equip_popup("armor"))
	if accessory_button:
		accessory_button.pressed.connect(func(): _open_equip_popup("accessory"))
	if equip_popup:
		equip_popup.index_pressed.connect(_on_equip_popup_selected)
	if skill_target_popup:
		skill_target_popup.index_pressed.connect(_on_skill_target_selected)
	_refresh_item_tab()
	_refresh_gold()
	_refresh_equipment_tab()
	_refresh_status_tab()
	_refresh_martial_tabs()
	_update_use_button("")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		# 直接呼叫 Autoload：SystemMenu
		SystemMenu._close_system_menu()
		get_viewport().set_input_as_handled()

func _on_tab_changed(tab_index: int) -> void:
	if tabs == null:
		return
	var item_tab_index = $VBoxContainer/道具.get_index()
	var martial_tab_index = $VBoxContainer/武術.get_index()
	if tab_index == item_tab_index:
		_refresh_item_tab()
	elif tab_index == martial_tab_index:
		_refresh_martial_tabs()

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
		var label = "%s x%d" % [item.get("name", item_id if item_id != "" else "???"), count]
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
	var name = item.get("name", item.get("id", "???"))
	var desc = item.get("desc", item.get("description", ""))
	var count = int(item.get("quantity", item.get("count", 0)))
	item_desc.text = "[b]%s[/b]\n數量：%d\n\n%s" % [name, count, desc]
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
	_selected_skill = {}
	_refresh_weapon_tab_lists()
	_update_skill_detail({})

func _refresh_inner_force_tabs() -> void:
	_refresh_character_select()
	_refresh_inner_force_lists()
	_update_inner_force_detail({})

func _connect_weapon_lists() -> void:
	for tab in weapon_tabs.get_children():
		if tab.has_node("SkillList"):
			var list: ItemList = tab.get_node("SkillList")
			if not list.item_selected.is_connected(_on_skill_selected):
				list.item_selected.connect(_on_skill_selected.bind(list))

func _connect_inner_force_lists() -> void:
	if inner_force_tabs == null:
		return
	for tab in inner_force_tabs.get_children():
		if tab.has_node("InnerForceList"):
			var list: ItemList = tab.get_node("InnerForceList")
			if not list.item_selected.is_connected(_on_inner_force_selected):
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
		_skill_debug_logged = true
	for tab in weapon_tabs.get_children():
		if not tab.has_node("SkillList"):
			continue
		var list: ItemList = tab.get_node("SkillList")
		list.clear()
		var weapon_type = str(tab.name)
		for skill in skills:
			if typeof(skill) != TYPE_DICTIONARY:
				continue
			if not _skill_data_db.is_available_for_actor(str(skill.get("id", "")), actor_id):
				continue
			var skill_weapon = str(skill.get("weapon_type", ""))
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
		skill_detail.text = "請選擇武術。"
		if use_skill_button:
			use_skill_button.disabled = true
		return
	var name = str(skill.get("name", "???"))
	var desc = str(skill.get("description", skill.get("desc", "")))
	var weapon_type = str(skill.get("weapon_type", ""))
	var power = skill.get("power", null)
	var target_scope = str(skill.get("target_scope", ""))
	var target_side = str(skill.get("target_side", ""))
	var require_free_hand = bool(skill.get("require_free_hand", false))
	var lines = []
	lines.append("[b]%s[/b]" % name)
	if desc != "":
		lines.append(desc)
	if power != null:
		lines.append("威力：%s" % str(power))
	if weapon_type != "":
		lines.append("武器類型：%s" % weapon_type)
	if require_free_hand:
		lines.append("需求：至少一手空")
	if target_scope != "":
		lines.append("目標範圍：%s" % target_scope)
	if target_side != "":
		lines.append("目標陣營：%s" % target_side)
	skill_detail.text = "\n".join(lines)
	if use_skill_button:
		var menu_usable = bool(skill.get("menu_usable", false))
		use_skill_button.disabled = (not menu_usable) or (not _can_use_skill_now(skill, _get_active_character_id()))

func _on_use_skill_pressed() -> void:
	if _selected_skill.is_empty():
		return
	if not bool(_selected_skill.get("menu_usable", false)):
		return
	var effect = str(_selected_skill.get("effect", ""))
	if effect == "":
		var effects = _selected_skill.get("effects", [])
		if typeof(effects) == TYPE_ARRAY and (effects as Array).size() > 0:
			var first = (effects as Array)[0]
			if typeof(first) == TYPE_DICTIONARY:
				effect = str((first as Dictionary).get("type", ""))
	if effect == "heal_hp":
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
	var caster = _get_actor_by_id(_get_active_character_id())
	if caster == null:
		print("[MartialUse] caster not found")
		return
	_apply_world_skill(_selected_skill, caster, target)

func _apply_world_skill(skill: Dictionary, caster, target) -> void:
	var effect = str(skill.get("effect", ""))
	if effect != "heal_hp":
		print("[MartialUse] not implemented:", skill.get("name", ""))
		return
	var mp_cost = int(skill.get("mp_cost", 0))
	var caster_mp = int(_get_actor_value(caster, "mp", 0))
	if caster_mp < mp_cost:
		print("內力不足")
		return
	var heal = int(skill.get("heal_amount", 0))
	var max_hp = int(_get_actor_value(target, "max_hp", _get_actor_value(target, "hp", 0)))
	_set_actor_value(caster, "mp", max(caster_mp - mp_cost, 0))
	_set_actor_value(target, "hp", min(int(_get_actor_value(target, "hp", 0)) + heal, max_hp))
	print("%s 施展 %s，氣血回復 %d。" % [
		str(_get_actor_value(caster, "name", "???")),
		str(skill.get("name", "???")),
		heal
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
		if not tab.has_node("InnerForceList"):
			continue
		var list: ItemList = tab.get_node("InnerForceList")
		list.clear()
		var element = str(tab.name)
		for force in forces:
			if typeof(force) != TYPE_DICTIONARY:
				continue
			if str(force.get("element", "")) != element:
				continue
			var force_id = str(force.get("id", ""))
			var force_name = "%s%s" % [str(force.get("prefix", "???")), str(force.get("type", ""))]
			var label = force_name
			if active_force_id != "" and force_id == active_force_id:
				label += "（使用中）"
			list.add_item(label)
			list.set_item_metadata(list.item_count - 1, force)

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
		inner_force_detail.text = "請選擇內功。"
		if switch_inner_force_button:
			switch_inner_force_button.disabled = true
		return
	var prefix = str(force.get("prefix", "???"))
	var desc = str(force.get("description", ""))
	var element = str(force.get("element", ""))
	var boost_weapon = str(force.get("boost_weapon", ""))
	var boost_pct = float(force.get("boost_damage_pct", 0.0))
	var require_unarmed = bool(force.get("boost_require_unarmed", false))
	var stat_bonus: Dictionary = force.get("stat_bonus", {})
	var lines = []
	lines.append("[b]%s[/b]" % prefix)
	if desc != "":
		lines.append(desc)
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
	inner_force_detail.text = "\n".join(lines)
	if switch_inner_force_button:
		switch_inner_force_button.disabled = false

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

func _get_actor_by_id(actor_id: String):
	if TeamData == null:
		return null
	for actor in TeamData.get_active_party():
		var entry_id = _get_actor_id_from_entry(actor)
		if entry_id == actor_id:
			return actor
	return null

func _refresh_status_tab() -> void:
	var actor = _get_active_actor()
	if actor == null:
		return
	var base_atk = int(_get_actor_value(actor, "atk", 0))
	var base_def = int(_get_actor_value(actor, "def", 0))
	var base_hp = int(_get_actor_value(actor, "hp", 0))
	var base_max_hp = int(_get_actor_value(actor, "max_hp", base_hp))
	var base_mp = int(_get_actor_value(actor, "mp", 0))
	var base_max_mp = int(_get_actor_value(actor, "max_mp", base_mp))
	var base_speed = int(_get_actor_value(actor, "speed", 0))
	var bonus = InventorySync.get_equipment_stat_bonus(_get_active_character_id())
	var inner_force_bonus: Dictionary = _get_actor_value(actor, "inner_force", {}).get("stat_bonus", {})
	var bonus_atk = int(bonus.get("atk", 0)) + int(inner_force_bonus.get("atk", 0))
	var bonus_def = int(bonus.get("def", 0)) + int(inner_force_bonus.get("def", 0))
	var bonus_max_hp = int(bonus.get("max_hp", 0)) + int(inner_force_bonus.get("max_hp", 0))
	var bonus_max_mp = int(bonus.get("max_mp", 0)) + int(inner_force_bonus.get("max_mp", 0))
	var bonus_speed = int(bonus.get("speed", 0)) + int(inner_force_bonus.get("speed", 0))
	if status_atk_label:
		status_atk_label.text = "攻：%d (+%d)" % [base_atk, bonus_atk]
	if status_def_label:
		status_def_label.text = "防：%d (+%d)" % [base_def, bonus_def]
	if status_hp_label:
		status_hp_label.text = "氣血：%d/%d (+%d max)" % [base_hp, base_max_hp + bonus_max_hp, bonus_max_hp]
	if status_mp_label:
		status_mp_label.text = "內力：%d/%d (+%d max)" % [base_mp, base_max_mp + bonus_max_mp, bonus_max_mp]
	if status_speed_label:
		status_speed_label.text = "身法：%d (+%d)" % [base_speed, bonus_speed]

func _refresh_equipment_tab() -> void:
	var equipped = InventorySync.get_equipped(_get_active_character_id())
	_set_equipment_button(weapon1_button, "主武器", str(equipped.get("weapon_1", "")), "weapon_1")
	_set_equipment_button(weapon2_button, "副武器", str(equipped.get("weapon_2", "")), "weapon_2")
	_set_equipment_button(armor_button, "防具", str(equipped.get("armor", "")), "armor")
	_set_equipment_button(accessory_button, "飾品", str(equipped.get("accessory", "")), "accessory")

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
		if str(item_def.get("equip_slot", "")) != slot:
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
	var allowed_types: Array = rules.get(slot, [])
	if allowed_types.is_empty():
		return true
	var weapon_type = str(item_def.get("weapon_type", ""))
	return allowed_types.has(weapon_type)

func _get_active_character_id() -> String:
	if TeamData and TeamData.current_team_ids.size() > 0:
		return str(TeamData.current_team_ids[0])
	return "liuyu"

func _get_active_actor():
	if TeamData:
		var party = TeamData.get_active_party()
		if party.size() > 0:
			return party[0]
	return null

func _can_use_skill_now(skill: Dictionary, actor_id: String) -> bool:
	if skill.is_empty():
		return false
	var weapon_required := String(skill.get("weapon_type", ""))
	if weapon_required == "":
		return true

	var equipped = InventorySync.get_equipped(actor_id) if InventorySync else {}
	var w1_type := _resolve_equipped_weapon_type(String(equipped.get("weapon_1", "")))
	var w2_type := _resolve_equipped_weapon_type(String(equipped.get("weapon_2", "")))
	var real_weapon_count := 0
	if w1_type != "" and w1_type != "拳" and w1_type != "掌":
		real_weapon_count += 1
	if w2_type != "" and w2_type != "拳" and w2_type != "掌":
		real_weapon_count += 1

	if bool(skill.get("require_free_hand", false)) and real_weapon_count >= 2:
		return false

	if weapon_required == "拳" or weapon_required == "掌":
		return true
	if weapon_required == "空手":
		return real_weapon_count == 0

	return w1_type == weapon_required or w2_type == weapon_required

func _resolve_equipped_weapon_type(item_id: String) -> String:
	if item_id == "":
		return ""
	var item_def = ItemDB.get_def(item_id)
	if item_def.is_empty():
		return ""
	return String(item_def.get("weapon_type", ""))

func _on_equip_popup_selected(index: int) -> void:
	if equip_popup == null:
		return
	if _active_equip_slot == "":
		return
	var item_id = str(equip_popup.get_item_metadata(index))
	if item_id == "":
		InventorySync.unequip(_active_equip_slot, _get_active_character_id())
		return
	InventorySync.equip_item(item_id, _get_active_character_id())

func _on_use_pressed() -> void:
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
			InventorySync.consume_item(item_id, 1)
			print("[ItemUse] used:", item_id)
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
