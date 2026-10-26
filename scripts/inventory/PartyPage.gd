extends "res://scripts/inventory/StudyPageBase.gd"
# 隊伍頁：書房桌面＋大卷軸（與狀態頁、裝備頁同一個外殼）。
# 左＝上陣隊伍（三格，第一位固定是劉語塵）、中＝候補隊友清單、右＝選中隊友的詳情與「移入／移出」。
# 隊伍資料只有 TeamData.current_team_ids 一份；移入、移出走 system_menu._apply_party_ids（會一併重整舊分頁）。
# 座標一律是邏輯 px（1152×648）。素材全部沿用已驗收的書房套件，共邊國交隊伍頁專用素材後再換。

const BUTTON_Y := 586
const LIST_RECT := Rect2(324, 132, 436, 440)     # 候補清單的可視範圍（超出可捲動）
const ROW_SIZE := Vector2(420, 64)
const ROW_GAP := 6.0
const X0 := 790.0                                # 右頁內容左緣
const DETAIL_ROWS := [["atk", "攻擊"], ["def", "防禦"], ["speed", "身法"], ["hit", "命中"], ["crit", "暴擊"], ["evade", "閃避"]]
const MAX_PARTY := 3
const SUMMARY_TILE := Vector2(66, 63)
const SUMMARY_ORDER := ["weapon_1", "weapon_2", "armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "mechanism"]

var _focus_id := ""                      # 右頁正在看的角色
var _swap_target := ""                   # 隊伍已滿時，要被換下的上陣隊員（最後點過的非劉語塵隊員）
var _list_box: VBoxContainer
var _list_scroll: ScrollContainer
var _row_buttons: Dictionary = {}
var _tiles: Dictionary = {}                 # slot_id → 裝備格（只顯示、不能點）
var _detail_box: Control
var _btn_action: Button
var _btn_back: Button
var _hint: Label
var _count_label: Label

func _ready() -> void:
	name = "PartyPage"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100      # 舊隊伍分頁節點的 z_index 比其他分頁高，新頁要蓋在上面
	_build_background(false)
	_image(E + "equip_scroll_complete", Vector2(0, 0), Vector2(1152, 648.5))
	_build_nav("TabParty")
	build_roster_panel(false)
	_build_candidate_list()
	_detail_box = Control.new()
	_detail_box.name = "Detail"
	_detail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_box)
	_build_equipment_tiles()
	# 移入／移出按鈕放在中頁底部（右頁下半部留給八格裝備）
	_btn_action = _tex_button(Vector2(190, 40), Vector2(LIST_RECT.position.x + 123, 522), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16)
	_btn_action.pressed.connect(_on_action_pressed)
	_hint = _label("", Vector2(LIST_RECT.position.x, 494), Vector2(LIST_RECT.size.x, 24), 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_btn_back = _tex_button(Vector2(165, 38), Vector2(494, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_btn_back.text = "返回"
	_btn_back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()
	_refresh()

func _foreground_preset() -> String:
	return "cloth_big"

# ------------------------------------------------------------------
# 建立畫面
# ------------------------------------------------------------------
## 八格裝備：沿用裝備頁的格子與圖示（與狀態頁的裝備摘要同一套），顯示目前查看的隊員穿戴
func _build_equipment_tiles() -> void:
	for i in SUMMARY_ORDER.size():
		var slot_id: String = SUMMARY_ORDER[i]
		var tile := make_slot_tile(slot_id, SUMMARY_TILE, self)
		tile.position = Vector2(X0 + (i % 4) * (SUMMARY_TILE.x + 6), 396 + (i / 4) * (SUMMARY_TILE.y + 8))
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tiles[slot_id] = tile

func _build_candidate_list() -> void:
	_outlined(_label("候補隊友", Vector2(LIST_RECT.position.x, 98), Vector2(160, 28), 22, INK))
	_count_label = _label("", Vector2(LIST_RECT.position.x + 200, 98), Vector2(236, 28), 15, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_image("divider_h", Vector2(LIST_RECT.position.x, 126), Vector2(LIST_RECT.size.x, 6))
	_list_scroll = ScrollContainer.new()
	_list_scroll.position = LIST_RECT.position
	_list_scroll.size = LIST_RECT.size
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", int(ROW_GAP))
	_list_box.custom_minimum_size = Vector2(ROW_SIZE.x + 8, 0)
	_list_scroll.add_child(_list_box)

# ------------------------------------------------------------------
# 資料
# ------------------------------------------------------------------
func _team_ids() -> Array:
	var ids: Array = menu._get_canonical_team_ids() if menu != null else ["liuyu"]
	var out: Array = []
	for id in ids:
		if String(id) != "":
			out.append(String(id))
	return out

func _reserve_ids(team_ids: Array) -> Array:
	return menu._get_reserve_actor_ids(team_ids) if menu != null else []

func _job_text(a: Dictionary) -> String:
	var job := String(a.get("job", ""))
	var subclass := String(a.get("subclass", ""))
	return "%s·%s" % [subclass, job] if subclass != "" and job != "" else (job + subclass)

func _head_texture(id: String) -> Texture2D:
	var head: Texture2D = EquipmentDollScript.head_portrait(id)
	if head != null:
		return head
	var path := String(_actor(id).get("portrait_path", ""))
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null

# ------------------------------------------------------------------
# 重整
# ------------------------------------------------------------------
func _refresh() -> void:
	var team := _team_ids()
	var reserves := _reserve_ids(team)
	if _focus_id == "" or not (team.has(_focus_id) or reserves.has(_focus_id)):
		_focus_id = String(team[0]) if not team.is_empty() else ""
	if _swap_target != "" and not team.has(_swap_target):
		_swap_target = ""
	rebuild_roster(team, _focus_id if team.has(_focus_id) else "", _on_party_card_pressed)
	_rebuild_candidates(reserves)
	_count_label.text = "上陣 %d／%d" % [team.size(), MAX_PARTY]
	_refresh_detail(team)

func _rebuild_candidates(reserves: Array) -> void:
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	_row_buttons.clear()
	if reserves.is_empty():
		var empty := Label.new()
		empty.text = "尚無候補隊友"
		empty.custom_minimum_size = Vector2(ROW_SIZE.x, 80)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_override("font", FONT)
		empty.add_theme_font_size_override("font_size", 17)
		empty.add_theme_color_override("font_color", INK_DIM)
		_list_box.add_child(empty)
		return
	for rid in reserves:
		var id := String(rid)
		var a := _actor(id)
		var on := id == _focus_id
		var b := Button.new()
		b.custom_minimum_size = ROW_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("actor_id", id)
		var normal := _box("row_normal", 16, 4)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, normal)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var glow := _image("row_selected" if on else "row_hover", Vector2.ZERO, ROW_SIZE, b)
		glow.modulate.a = 1.0 if on else 0.0
		if not on:
			b.mouse_entered.connect(func(): glow.modulate.a = 0.6)
			b.mouse_exited.connect(func(): glow.modulate.a = 0.0)
		var clip := Control.new()
		clip.position = Vector2(8, 6)
		clip.size = Vector2(52, 52)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(clip)
		var pr := TextureRect.new()
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pr.size = clip.size
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.texture = _head_texture(id)
		clip.add_child(pr)
		_outlined(_label(String(a.get("name", id)), Vector2(72, 6), Vector2(150, 28), 19, INK, HORIZONTAL_ALIGNMENT_LEFT, b))
		_outlined(_label(_job_text(a), Vector2(72, 34), Vector2(150, 22), 13, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, b))
		_outlined(_label("Lv.%d" % int(a.get("level", 1)), Vector2(236, 6), Vector2(70, 28), 16, INK, HORIZONTAL_ALIGNMENT_LEFT, b))
		var st := _vitals(id)
		_bar(b, Vector2(236, 40), "hp", float(st[0]), float(maxi(1, st[1])), 80.0)
		_bar(b, Vector2(326, 40), "mp", float(st[2]), float(maxi(1, st[3])), 80.0)
		b.pressed.connect(_on_candidate_pressed.bind(id))
		_list_box.add_child(b)
		_row_buttons[id] = b

## [氣血, 氣血上限, 內力, 內力上限]（含裝備加成的上限；本來是滿的就顯示滿，與狀態頁一致）
func _vitals(id: String) -> Array:
	var a := _actor(id)
	var stats: Dictionary = menu.compute_overview_stats(a, InventorySync.get_equipment_stat_bonus(id)) if menu != null else {}
	var hp_max := int(stats.get("max_hp", a.get("max_hp", 1)))
	var mp_max := int(stats.get("max_mp", a.get("max_mp", 1)))
	var hp_now: int = menu._displayed_resource(int(a.get("hp", 0)), int(a.get("max_hp", 1)), hp_max) if menu != null else int(a.get("hp", 0))
	var mp_now: int = menu._displayed_resource(int(a.get("mp", 0)), int(a.get("max_mp", 1)), mp_max) if menu != null else int(a.get("mp", 0))
	return [hp_now, hp_max, mp_now, mp_max]

func _refresh_detail(team: Array) -> void:
	for c in _detail_box.get_children():
		_detail_box.remove_child(c)
		c.queue_free()
	if _focus_id == "":
		_btn_action.visible = false
		_hint.text = ""
		for t in _tiles.values():
			(t as Control).visible = false
		return
	for t in _tiles.values():
		(t as Control).visible = true
	var a := _actor(_focus_id)
	var in_team := team.has(_focus_id)
	var clip := Control.new()
	clip.position = Vector2(X0, 100)
	clip.size = Vector2(100, 108)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_box.add_child(clip)
	var pr := TextureRect.new()
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pr.size = clip.size
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.texture = _head_texture(_focus_id)
	clip.add_child(pr)
	_outlined(_label(String(a.get("name", _focus_id)), Vector2(X0 + 106, 106), Vector2(150, 34), 24, INK, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	_outlined(_label(_job_text(a), Vector2(X0 + 106, 142), Vector2(150, 24), 15, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	_outlined(_label("Lv.%d　%s" % [int(a.get("level", 1)), "上陣中" if in_team else "候補"], Vector2(X0 + 106, 168), Vector2(150, 24), 15, INK, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	var st := _vitals(_focus_id)
	_outlined(_label("氣血", Vector2(X0, 222), Vector2(40, 22), 14, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	_bar(_detail_box, Vector2(X0 + 44, 228), "hp", float(st[0]), float(maxi(1, st[1])), 160.0)
	_outlined(_label("%d/%d" % [st[0], st[1]], Vector2(X0 + 212, 222), Vector2(84, 22), 13, INK, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	_outlined(_label("內力", Vector2(X0, 250), Vector2(40, 22), 14, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	_bar(_detail_box, Vector2(X0 + 44, 256), "mp", float(st[2]), float(maxi(1, st[3])), 160.0)
	_outlined(_label("%d/%d" % [st[2], st[3]], Vector2(X0 + 212, 250), Vector2(84, 22), 13, INK, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	_image("divider_h", Vector2(X0, 280), Vector2(296, 6), _detail_box)
	var stats: Dictionary = menu.compute_overview_stats(a, InventorySync.get_equipment_stat_bonus(_focus_id)) if menu != null else {}
	for i in DETAIL_ROWS.size():
		var key: String = DETAIL_ROWS[i][0]
		var col := i % 2
		var row := i / 2
		var pos := Vector2(X0 + col * 150.0, 292 + row * 26.0)
		_outlined(_label(String(DETAIL_ROWS[i][1]), pos, Vector2(60, 24), 15, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
		var v = stats.get(key, 0)
		_outlined(_label(("%.1f%%" % float(v)) if key == "crit" else str(int(v)), pos + Vector2(62, 0), Vector2(70, 24), 16, INK, HORIZONTAL_ALIGNMENT_LEFT, _detail_box))
	var equipped: Dictionary = InventorySync.get_equipped(_focus_id)
	for slot_id in SUMMARY_ORDER:
		var locked: bool = menu != null and menu.is_slot_locked_for(_focus_id, slot_id)
		fill_slot_tile(_tiles[slot_id], String(equipped.get(slot_id, "")), locked, false)
	# 按鈕與提示
	_btn_action.visible = true
	_hint.text = ""
	if _focus_id == "liuyu":
		_btn_action.text = "移出隊伍"
		_btn_action.disabled = true
		_hint.text = "劉語塵固定在隊伍中"
	elif in_team:
		_btn_action.text = "移出隊伍"
		_btn_action.disabled = false
	else:
		_btn_action.text = "移入隊伍"
		_btn_action.disabled = false
		if team.size() >= MAX_PARTY:
			_hint.text = "隊伍已滿：換下 %s" % String(_actor(_swap_target).get("name", "")) if _swap_target != "" else "隊伍已滿：先點一位上陣隊員來替換"
			_btn_action.disabled = _swap_target == ""

# ------------------------------------------------------------------
# 操作
# ------------------------------------------------------------------
func _on_party_card_pressed(id: String) -> void:
	_focus_id = id
	if id != "liuyu":
		_swap_target = id
	_refresh()

func _on_candidate_pressed(id: String) -> void:
	_focus_id = id
	_refresh()

func _on_action_pressed() -> void:
	var team := _team_ids()
	if _focus_id == "" or _focus_id == "liuyu":
		return
	if team.has(_focus_id):
		team.erase(_focus_id)
		_swap_target = ""
		_apply(team)
		show_toast("%s 離開了隊伍" % String(_actor(_focus_id).get("name", _focus_id)))
		return
	if team.size() < MAX_PARTY:
		team.append(_focus_id)
	elif _swap_target != "" and team.has(_swap_target):
		var out_name := String(_actor(_swap_target).get("name", ""))
		team[team.find(_swap_target)] = _focus_id
		_swap_target = ""
		_apply(team)
		show_toast("%s 換下了 %s" % [String(_actor(_focus_id).get("name", _focus_id)), out_name])
		return
	else:
		show_toast("隊伍已滿，請先點選要換下的隊員")
		return
	_apply(team)
	show_toast("%s 加入了隊伍" % String(_actor(_focus_id).get("name", _focus_id)))

func _apply(ids: Array) -> void:
	if menu != null and menu.has_method("_apply_party_ids"):
		menu._apply_party_ids(ids)
	elif TeamData:
		TeamData.current_team_ids = ids.duplicate()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
