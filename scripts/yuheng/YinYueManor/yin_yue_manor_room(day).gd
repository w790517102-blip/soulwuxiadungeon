extends Node2D

# ------------------------------------------------------------
# 飲月山莊內（白天）
#
# 序章收尾（夜談、留宿之後的翌日）在這裡：
#   - 醒來後第一次進場：旁白顯示主線更新，玩家恢復自由操作。
#   - 白書眠（NPC）：還沒答應的話，主動找她才會邀請去舊水道補符；答應 → 接支線、入隊、NPC 消失；拒絕 → 什麼都不變。
#   - 左飲（NPC）：主動找他才有「啟程烈風寨」的選擇；支線沒完成要二次確認；確定啟程才結算支線、補給、書眠入隊並轉場。
#   - 紅徽音已回到醉月茶坊，這個場景沒有她。
# 所有狀態（入隊、支線、啟程）都在 YuhengPrologueState.gd，這裡不另外保存旗標。
# ------------------------------------------------------------

@export var YinYueManor: String = "res://scenes/yuheng/YinYueManor/yin_yue_manor.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "station_stillwind"
@export var map_display_name: String = "飲月山莊內"

## 下一章（烈風寨）入口。沿用夜間場景原本的設定：尚未設定時，啟程不會留下任何狀態變更。
@export_file("*.tscn") var qingfeng_bamboo_entrance_scene_path := ""
@export var qingfeng_spawn_point_name := "from_yin_yue_manor"

@export var money_reward := 500
## 左飲補給。ItemDB 已確認這些 ID 存在。
@export var supply_items: Dictionary = {
	"med_jinchuang_small": 2,
	"med_stopbleed_herb": 3,
	"med_qi_restore_small": 2,
	"med_calm_pill": 1,
	"med_awaken_tonic": 1,
	"med_antidote_powder": 1,
	"food_dried_rations": 3,
}

## 頭像規則同夜間會談：劉語塵固定用原本頭像、下方對話框（speaker id 2）；其他角色在上方對話框用原本頭像。
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/NPC/Yuheng/Su_Mien_headshot.png"
@export var zuoyin_portrait_path := "res://assets/sprites/NPC/Yuheng/Zuo_Yin_headshot.png"
@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 4
@export var zuoyin_speaker_id := 6

## 劉語塵腳底與 NPC 腳底的距離在這之內才能互動（B 型固定半徑）。
const INTERACT_DISTANCE := 80.0
const SHUMIAN_IDLE_ANIMATION := "idle_right_down"
const ZUOYIN_IDLE_ANIMATION := "idle_right_down"

@onready var shumian_npc: Node2D = get_node_or_null("Su_mien")
@onready var zuoyin_npc: Node2D = get_node_or_null("Zuo_yin")

var _busy := false
## 啟程轉場已經開始：不再把控制權還給玩家（場景馬上就會被換掉）。
var _departing := false
var _choice_result := -1


func _ready():
	_setup_npcs()

	overlay.modulate.a = 1.5
	var tween_in = overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished

	show_map_name()
	await _play_day_arrival_once()


func _exit_tree() -> void:
	var player := _get_player()
	if player != null and is_instance_valid(player):
		player.set("z_index_offset", 0)


func get_map_display_name() -> String:
	return map_display_name

func show_map_name():
	var map_popup = get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0
		await get_tree().create_timer(2.0).timeout
		var popup_tween = map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished
		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")

func _on_to_yin_yue_manor_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yin_yue_manor_room(day)"
		get_node("/root/GameRoot").change_map_to(YinYueManor)


# ------------------------------------------------------------
# NPC 配置（依持久化狀態，不是只靠這次 hide）
# ------------------------------------------------------------
func _setup_npcs() -> void:
	if zuoyin_npc:
		_play_anim(zuoyin_npc, ZUOYIN_IDLE_ANIMATION)
	if shumian_npc:
		_play_anim(shumian_npc, SHUMIAN_IDLE_ANIMATION)
		if not _shumian_should_be_here():
			_remove_shumian_npc()
	_setup_interaction_targets()


## 書眠只在「序章收尾階段、尚未入隊」時站在山莊裡等。入隊後（不論是答應了支線，或啟程時自動入隊）一律不在場景上。
func _shumian_should_be_here() -> bool:
	return YuhengPrologueState.is_prologue_ending_phase() and not YuhengPrologueState.is_shumian_joined()


func _remove_shumian_npc() -> void:
	if shumian_npc and is_instance_valid(shumian_npc):
		shumian_npc.queue_free()
	shumian_npc = null


# ------------------------------------------------------------
# 前後遮擋：以腳底 y 排序（劉語塵的 z_index_offset 一併對到腳底，離開場景時還原）
# ------------------------------------------------------------
func _process(_delta: float) -> void:
	for npc: Node2D in [zuoyin_npc, shumian_npc]:
		if npc != null and is_instance_valid(npc):
			npc.z_index = int(YuhengPrologueState.feet_global(npc).y)
	var player := _get_player()
	if player != null and is_instance_valid(player):
		var feet_y: float = YuhengPrologueState.feet_global(player).y
		player.set("z_index_offset", int(feet_y - player.global_position.y))


# ------------------------------------------------------------
# 醒來後第一次進場
# ------------------------------------------------------------
func _play_day_arrival_once() -> void:
	if not YuhengPrologueState.flag(YuhengPrologueState.F_OVERNIGHT_DONE):
		return
	if YuhengPrologueState.flag(YuhengPrologueState.F_DAY_ARRIVAL_DONE):
		return
	YuhengPrologueState.set_flag(YuhengPrologueState.F_DAY_ARRIVAL_DONE, true)
	_busy = true
	_set_player_movable(false)
	await _show_dialog([
		_n("主線更新：準備前往烈風寨。"),
		_n("可與書眠對話，前往舊水道查看封印。"),
		_n("準備完成後，與左飲對話，即可出發。"),
	])
	_set_player_movable(true)
	_busy = false


# ------------------------------------------------------------
# 互動：B 型固定半徑（交給中央 InteractionResolver：滑鼠點選、靠近後互動，或按 Space）
# ------------------------------------------------------------
## 書眠與左飲各掛一個 InteractionTarget。Space、滑鼠選取、唯一目標的裁決都由 InteractionResolver 處理，
## 這個場景不再自己監聽輸入（避免新舊兩套同時回應同一次 Space）。
func _setup_interaction_targets() -> void:
	_add_interaction_target(shumian_npc, "白書眠", _interact_with_shumian)
	_add_interaction_target(zuoyin_npc, "左飲", _interact_with_zuoyin)


func _add_interaction_target(npc: Node2D, label: String, handler: Callable) -> void:
	if npc == null:
		return
	var target := InteractionTarget.new()
	target.name = "InteractionTarget"
	target.mode = InteractionTarget.Mode.RADIUS
	target.display_name = label
	target.interaction_radius = INTERACT_DISTANCE
	target.hover_margin = 6.0
	target.availability = _interaction_available
	target.handler = handler
	npc.add_child(target)


## 序章收尾階段才有互動；醒來後的旁白、對話、選項進行中不接受新的互動。
func _interaction_available() -> bool:
	return not _busy and YuhengPrologueState.is_prologue_ending_phase()


func _interact_with_shumian(_player: Node2D) -> void:
	_busy = true
	_set_player_movable(false)
	await _talk_to_shumian()
	_finish_interaction()


func _interact_with_zuoyin(_player: Node2D) -> void:
	_busy = true
	_set_player_movable(false)
	await _talk_to_zuoyin()
	_finish_interaction()


func _finish_interaction() -> void:
	if _departing:
		return
	_set_player_movable(true)
	_busy = false


func _face_player(npc: Node2D, idle_prefix := "idle") -> void:
	var player := _get_player()
	var sprite := YuhengPrologueState.find_animated_sprite(npc)
	if player == null or sprite == null:
		return
	var direction: Vector2 = (player.global_position - npc.global_position).normalized()
	var vertical := "down" if direction.y > 0.0 else "up"
	var horizontal := "right" if direction.x > 0.0 else "left"
	var anim := "%s_%s_%s" % [idle_prefix, horizontal, vertical]
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


# ------------------------------------------------------------
# 白書眠：舊水道補符支線入口
# ------------------------------------------------------------
func _talk_to_shumian() -> void:
	_face_player(shumian_npc)
	if YuhengPrologueState.get_side_quest_state() != YuhengPrologueState.SideQuestState.AVAILABLE:
		# 理論上只有「可接取」時書眠才在場；若遇到其他狀態，不重複接取、不改任何狀態。
		await _show_dialog([_l("劉少俠。", shumian_speaker_id, shumian_portrait_path)])
		return

	_choice_result = -1
	await _show_dialog([
		_l("劉少俠。", shumian_speaker_id, shumian_portrait_path),
		_l("書眠姑娘，怎麼了？", liuyu_speaker_id, liuyu_portrait_path),
		_l("昨夜左莊主說的話……我想了很久。", shumian_speaker_id, shumian_portrait_path),
		_l("舊水道裡那些符，是我親手貼下的。", shumian_speaker_id, shumian_portrait_path),
		_l("如今墨鱗魘將已退，我想再回去看一趟。", shumian_speaker_id, shumian_portrait_path),
		_l("把能補的補好，也把該看的看完。", shumian_speaker_id, shumian_portrait_path),
		_l("劉少俠……你願意陪我一起去嗎？", shumian_speaker_id, shumian_portrait_path),
		_choice_line(["好，我陪妳去。", "我還有些事要辦。"]),
	])

	if _choice_result == 0:
		YuhengPrologueState.accept_qudeng()
		await _show_dialog([
			_l("謝謝你，劉少俠。", shumian_speaker_id, shumian_portrait_path),
			_l("舊水道那邊，我們走一趟吧。", shumian_speaker_id, shumian_portrait_path),
			_n("書眠加入隊伍。"),
			_n("支線更新：《渠燈補封》——陪書眠回舊水道，補穩藥師舊室的符、水口與渠燈。"),
		])
		await _fade_shumian_away()
	elif _choice_result == 1:
		await _show_dialog([
			_l("……好。那我在這裡等你。", shumian_speaker_id, shumian_portrait_path),
			_l("什麼時候準備好了，再來找我。", shumian_speaker_id, shumian_portrait_path),
		])
	# 沒有選擇（對話被中斷）時什麼都不變。


## 入隊後書眠離開場景（NPC 是否出現由持久化的入隊狀態決定，這裡只是演出）。
func _fade_shumian_away() -> void:
	if shumian_npc == null or not is_instance_valid(shumian_npc):
		return
	var tween := shumian_npc.create_tween()
	tween.tween_property(shumian_npc, "modulate:a", 0.0, 0.6)
	await tween.finished
	_remove_shumian_npc()


# ------------------------------------------------------------
# 左飲：啟程烈風寨
# ------------------------------------------------------------
func _talk_to_zuoyin() -> void:
	_face_player(zuoyin_npc)
	_choice_result = -1
	await _show_dialog([
		_l("準備好了？", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("前往烈風寨？", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("列霄手上有《白鳶橫天》的線索。這一趟，總得走。", zuoyin_speaker_id, zuoyin_portrait_path),
		_choice_line(["準備好了，啟程吧。", "我還有事要辦……"]),
	])
	if _choice_result != 0:
		# 稍後再說：關閉對話，所有狀態保持，書眠的支線仍然可以繼續。
		return

	# 書眠的支線還沒完成：第二次確認，取消的話什麼都不改。
	if YuhengPrologueState.get_side_quest_state() != YuhengPrologueState.SideQuestState.DONE:
		_choice_result = -1
		await _show_dialog([
			_n("一旦離開玉衡鎮前往烈風寨，將無法再完成白書眠的「舊水道補符」支線。"),
			_n("確定現在出發嗎？"),
			_choice_line(["確定啟程", "我還有事要辦"]),
		])
		if _choice_result != 0:
			return

	await _depart_for_liefeng()


## 正式啟程：先確認轉場目標可用（不可用就不留下任何狀態），再結算支線、補給、書眠入隊，最後轉場。
func _depart_for_liefeng() -> void:
	if qingfeng_bamboo_entrance_scene_path == "" or not ResourceLoader.exists(qingfeng_bamboo_entrance_scene_path):
		push_warning("尚未設定 qingfeng_bamboo_entrance_scene_path（飲月山莊白天場景根節點），無法前往烈風寨；本次啟程不變更任何狀態。")
		await _show_dialog([_n("（前往烈風寨的路還沒有接上。）")])
		return

	await _show_dialog([_l("那就出發。", zuoyin_speaker_id, zuoyin_portrait_path)])

	if not YuhengPrologueState.flag(YuhengPrologueState.F_ZUOYIN_SUPPLIES_RECEIVED):
		_give_zuoyin_supplies()
		YuhengPrologueState.set_flag(YuhengPrologueState.F_ZUOYIN_SUPPLIES_RECEIVED, true)
		await _show_dialog(_build_supply_received_lines())

	var joined_before := YuhengPrologueState.is_shumian_joined()
	YuhengPrologueState.settle_side_quest_for_departure()
	YuhengPrologueState.join_shumian()

	var lines: Array = []
	if not joined_before:
		lines.append(_n("書眠加入隊伍。"))
	lines.append(_n("主線更新：前往清風竹林，尋找通往烈風寨的道路。"))
	await _show_dialog(lines)

	_departing = true
	_set_player_movable(false)
	await _transition_to_qingfeng_bamboo()


func _transition_to_qingfeng_bamboo() -> void:
	await _fade_out()
	YuhengPrologueState.set_flag(YuhengPrologueState.F_LIEFENG_CHAPTER_STARTED, true)
	if QuestManager:
		QuestManager.advance_main_quest(QuestManager.STAGE_YH_LIEFENG_STARTED)

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root and game_root.has_method("change_map_to"):
		game_root.spawn_point_name = qingfeng_spawn_point_name
		game_root.change_map_to(qingfeng_bamboo_entrance_scene_path)
		return
	get_tree().change_scene_to_file(qingfeng_bamboo_entrance_scene_path)


func _build_supply_received_lines() -> Array:
	return [
		_n("獲得 500 文。"),
		_n("獲得 金創藥·小 ×2。"),
		_n("獲得 止血草 ×3。"),
		_n("獲得 回氣散·小 ×2。"),
		_n("獲得 清心丸 ×1。"),
		_n("獲得 醒神湯 ×1。"),
		_n("獲得 解毒散 ×1。"),
		_n("獲得 乾糧 ×3。"),
	]


func _give_zuoyin_supplies() -> void:
	if InventorySync == null:
		push_warning("找不到 InventorySync，左飲的補給無法發放。")
		return
	InventorySync.add_gold(money_reward, false)
	for item_id in supply_items.keys():
		InventorySync.add_item_stack(str(item_id), int(supply_items[item_id]), false)


# ------------------------------------------------------------
# 對話 / 選項 / 玩家
# ------------------------------------------------------------
func _get_dialog_manager() -> Node:
	return get_node_or_null("/root/GameRoot/DialogManager")


func _dialog_is_active() -> bool:
	var dialog_manager := _get_dialog_manager()
	return dialog_manager != null and bool(dialog_manager.get("dialog_active"))


func _show_dialog(lines: Array) -> void:
	var dialog_manager := _get_dialog_manager()
	if dialog_manager == null:
		for line in lines:
			print(line)
		return
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_sequence_finished
	# DialogManager 結束時會嘗試還原控制；這個場景的互動流程結束前仍由這裡持有。
	if not _departing:
		_set_player_movable(false if _busy else true)


## 對話序列中的選項：選了之後把選到的索引放進 _choice_result，並收起選項框，序列接著往下走（DialogManager 的 choice 行）。
func _choice_line(options: Array) -> Dictionary:
	var entries: Array = []
	for i in options.size():
		var index: int = i
		entries.append({
			"text": String(options[i]),
			"callback": func() -> void:
				_choice_result = index
				var dialog_manager := _get_dialog_manager()
				if dialog_manager and dialog_manager.get("choice_box") != null:
					dialog_manager.choice_box.hide_choices()
		})
	return {"choice": entries}


func reset_dialog_state() -> void:
	# DialogManager 在 emit dialog_sequence_finished 之前會呼叫這裡；實際的控制權還原由流程結束處統一處理。
	pass


func _l(text: String, speaker: int, portrait: String = "") -> Dictionary:
	return {
		"text": text,
		"speaker": speaker,
		"portrait": portrait if portrait != "" else empty_portrait_path,
	}


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": narration_speaker_id,
		"portrait": empty_portrait_path,
	}


func _get_player() -> Node2D:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player is Node2D:
		return player
	return null


func _set_player_movable(value: bool) -> void:
	var player := _get_player()
	if player:
		player.set("can_move", value)


func _fade_out() -> void:
	overlay.visible = true
	overlay.modulate.a = 0.0
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


func _play_anim(node: Node, anim_name: String) -> void:
	var sprite := YuhengPrologueState.find_animated_sprite(node)
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
