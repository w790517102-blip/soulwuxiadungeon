# 掛在 system_menu.tscn 的 Panel 根節點上的腳本
extends Panel

@onready var tabs: TabContainer = $VBoxContainer
@onready var item_list: ItemList = $VBoxContainer/道具/ItemList
@onready var item_desc: RichTextLabel = $VBoxContainer/道具/RichTextLabel
@onready var gold_label: Label = $VBoxContainer/道具/GoldLabel
@onready var status_gold_label: Label = get_node_or_null("VBoxContainer/狀態/GoldLabel")
@onready var use_button: Button = get_node_or_null("VBoxContainer/道具/UseButton")
@onready var weapon1_button: Button = get_node_or_null("VBoxContainer/裝備/Weapon1Button")
@onready var weapon2_button: Button = get_node_or_null("VBoxContainer/裝備/Weapon2Button")
@onready var armor_button: Button = get_node_or_null("VBoxContainer/裝備/ArmorButton")
@onready var accessory_button: Button = get_node_or_null("VBoxContainer/裝備/AccessoryButton")
@onready var equip_popup: PopupMenu = get_node_or_null("EquipPopup")
var _item_entries: Array = []
var _active_equip_slot := ""

const DEFAULT_UNARMED_NAME := "拳掌"
const WEAPON_RULES := {
	"liuyu": {
		"weapon_1": ["劍"],
		"weapon_2": [],
	},
	"shumian": {
		"weapon_1": ["筆"],
		"weapon_2": ["拳掌"],
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
	_refresh_item_tab()
	_refresh_gold()
	_refresh_equipment_tab()
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
	if tab_index == item_tab_index:
		_refresh_item_tab()

func _refresh_item_tab() -> void:
	if item_list == null or item_desc == null:
		return
	var selected_index = item_list.get_selected_items()
	var selected_id := ""
	if selected_index.size() > 0:
		selected_id = str(item_list.get_item_metadata(selected_index[0]))
	item_list.clear()
	_item_entries = InventorySync.get_items()
	for item in _item_entries:
		var count = int(item.get("quantity", item.get("count", 0)))
		var item_id = str(item.get("id", ""))
		var label = "%s x%d" % [item.get("name", item_id if item_id != "" else "???"), count]
		if InventorySync.is_equipped(item_id):
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

func _on_gold_changed(_new_gold: int) -> void:
	_refresh_gold()

func _refresh_gold() -> void:
	var gold := InventorySync.get_gold()
	if gold_label:
		gold_label.text = "💰 盤纏：%d文" % gold
	if status_gold_label:
		status_gold_label.text = "💰 盤纏：%d文" % gold

func _refresh_equipment_tab() -> void:
	var equipped := InventorySync.get_equipped()
	_set_equipment_button(weapon1_button, "主武器", str(equipped.get("weapon_1", "")), "weapon_1")
	_set_equipment_button(weapon2_button, "副武器", str(equipped.get("weapon_2", "")), "weapon_2")
	_set_equipment_button(armor_button, "防具", str(equipped.get("armor", "")), "armor")
	_set_equipment_button(accessory_button, "飾品", str(equipped.get("accessory", "")), "accessory")

func _set_equipment_button(button: Button, prefix: String, item_id: String, slot: String) -> void:
	if button == null:
		return
	var display_name := "—"
	if item_id != "":
		var item_def := ItemDB.get_def(item_id)
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
	var index := 1
	for item in InventorySync.get_items():
		var item_id := str(item.get("id", ""))
		if item_id == "":
			continue
		var item_def := ItemDB.get_def(item_id)
		if item_def.is_empty():
			continue
		if str(item_def.get("use_action", "none")) != "equip":
			continue
		if str(item_def.get("equip_slot", "")) != slot:
			continue
		if not _is_weapon_type_allowed(item_def, slot):
			continue
		var name := str(item_def.get("name", item_id))
		equip_popup.add_item(name)
		equip_popup.set_item_metadata(index, item_id)
		index += 1
	equip_popup.popup()

func _is_weapon_type_allowed(item_def: Dictionary, slot: String) -> bool:
	if not slot.begins_with("weapon"):
		return true
	var rules := WEAPON_RULES.get(_get_active_character_id(), {})
	var allowed_types: Array = rules.get(slot, [])
	if allowed_types.is_empty():
		return true
	var weapon_type := str(item_def.get("weapon_type", ""))
	return allowed_types.has(weapon_type)

func _get_active_character_id() -> String:
	if TeamData and TeamData.current_team_ids.size() > 0:
		return str(TeamData.current_team_ids[0])
	return "liuyu"

func _on_equip_popup_selected(index: int) -> void:
	if equip_popup == null:
		return
	if _active_equip_slot == "":
		return
	var item_id = str(equip_popup.get_item_metadata(index))
	if item_id == "":
		InventorySync.unequip(_active_equip_slot)
		return
	InventorySync.equip_item(item_id)

func _on_use_pressed() -> void:
	if item_list == null:
		return
	var selected_items = item_list.get_selected_items()
	if selected_items.is_empty():
		return
	var item_id = str(item_list.get_item_metadata(selected_items[0]))
	if item_id == "":
		return
	var item_def := InventorySync.get_item_by_id(item_id)
	if item_def.is_empty():
		return
	var use_action := str(item_def.get("use_action", "none"))
	var use_scope := str(item_def.get("use_scope", "none"))
	if use_action == "consume":
		if use_scope == "any" or use_scope == "world":
			InventorySync.consume_item(item_id, 1)
			print("[ItemUse] used:", item_id)
		return
	if use_action == "equip":
		if use_scope != "any" and use_scope != "world":
			return
		var slot := str(item_def.get("equip_slot", ""))
		if slot == "":
			return
		if InventorySync.is_equipped(item_id):
			InventorySync.unequip(slot)
			print("[Unequip] slot=%s" % slot)
		else:
			InventorySync.equip_item(item_id)
			print("[Equip] slot=%s id=%s" % [slot, item_id])
		return

func _update_use_button(item_id: String) -> void:
	if use_button == null:
		return
	if item_id == "":
		use_button.disabled = true
		use_button.text = "不可使用"
		return
	var item_def := InventorySync.get_item_by_id(item_id)
	if item_def.is_empty():
		use_button.disabled = true
		use_button.text = "不可使用"
		return
	var use_action := str(item_def.get("use_action", "none"))
	var use_scope := str(item_def.get("use_scope", "none"))
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
			use_button.text = "卸下" if InventorySync.is_equipped(item_id) else "裝備"
		else:
			use_button.disabled = true
			use_button.text = "不可在此更換"
		return
	use_button.disabled = true
	use_button.text = "不可使用"
