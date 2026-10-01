extends Node2D
class_name YinYueManorRoomNight

# ------------------------------------------------------------
# 飲月山莊・夜間會談
# 掛載：yin_yue_manor_room(night).tscn 根節點
#
# 流程：
# 1. 鐘乳石洞魚怪戰後進入本場景，踩到 trigger 後啟動會談。
# 2. 左飲說「坐」後，劉語塵與書眠沿 Path2D 移動到座位，播放 sit_right_up。
# 3. 會談結束，書眠沿 Su_mien_back_path 回到等待位置。
# 4. 玩家恢復自由行動，可準備補給、接書眠支線，或找左飲出發下一章。
# 5. 找左飲出發時，左飲給 500 文與補給，書眠正式入隊，切換到清風竹林入口。
# ------------------------------------------------------------

@export var music_tag := "yuheng"
@export var map_display_name: String = "飲月山莊・夜間"

# 下一章入口。請在 Inspector 裡改成你的清風竹林入口場景。
@export_file("*.tscn") var qingfeng_bamboo_entrance_scene_path := ""

@export var qingfeng_spawn_point_name := "from_yin_yue_manor"
@export var money_reward := 500

# 左飲補給。ItemDB 已確認這些 ID 存在。
@export var supply_items: Dictionary = {
	"med_jinchuang_small": 2,
	"med_stopbleed_herb": 3,
	"med_qi_restore_small": 2,
	"med_calm_pill": 1,
	"med_awaken_tonic": 1,
	"med_antidote_powder": 1,
	"food_dried_rations": 3,
}

# 對話頭像 / speaker id，若你專案 ID 不同可在 Inspector 調。
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/Shu_mian/ShuMian_headshot.png"
@export var zuoyin_portrait_path := "res://assets/sprites/Zuo_yin/ZuoYin_headshot.png"
@export var huiyin_portrait_path := "res://assets/sprites/Huiyin/Huiyin_headshot.png"

@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 4
@export var huiyin_speaker_id := 5
@export var zuoyin_speaker_id := 6

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var event_area: Area2D = get_node_or_null("yin_yue_manor_event_trigger/yin_yue_manor_event_trigger")

@onready var liuyu_go_path: Path2D = get_node_or_null("yin_yue_manor_event_trigger/Liu_yu_go_path")
@onready var shumian_go_path: Path2D = get_node_or_null("yin_yue_manor_event_trigger/Su_mien_go_path")
@onready var shumian_back_path: Path2D = get_node_or_null("yin_yue_manor_event_trigger/Su_mien_back_path")

@onready var liuyu_initial_point: Marker2D = get_node_or_null("SpawnPoints/Liu_yu_Initial_point")
@onready var zuoyin_initial_point: Marker2D = get_node_or_null("SpawnPoints/Zuo_yin_Initial_point")
@onready var shumian_initial_point: Marker2D = get_node_or_null("SpawnPoints/Su_mien_Initial_point")

@onready var shumian_npc: Node2D = get_node_or_null("Su_mien")
@onready var zuoyin_npc: Node2D = get_node_or_null("Zuo_yin")

signal dialog_closed

# ------------------------------------------------------------
# Flags
# ------------------------------------------------------------
const F_AFTER_FISH_READY := "main_yh_manor_after_fish_ready"
const F_NIGHT_MEETING_DONE := "event_yin_yue_night_meeting_done"

const F_READY_FOR_QINGFENG := "main_yh_ready_for_qingfeng"
const F_SHUMIAN_SIDE_AVAILABLE := "shumian_pre_departure_available"
const F_SHUMIAN_CLEAN_SEWER_DONE := "shumian_clean_sewer_done"

const F_SHUMIAN_JOIN_PENDING := "party_shumian_join_pending"
const F_SHUMIAN_JOINED := "party_shumian_joined"

const F_ZUOYIN_SUPPLIES_RECEIVED := "main_yh_zuoyin_supplies_received"
const F_LIEFENG_CHAPTER_STARTED := "main_chapter_liefeng_started"

var story_locked := false
var transition_locked := false
var post_meeting_interaction_locked := false
var _waiting_for_dialog := false


func _ready() -> void:
	if zuoyin_initial_point and zuoyin_npc:
		zuoyin_npc.global_position = zuoyin_initial_point.global_position

	if shumian_initial_point and shumian_npc and not _get_flag(F_NIGHT_MEETING_DONE, false):
		shumian_npc.global_position = shumian_initial_point.global_position

	if event_area:
		if not event_area.body_entered.is_connected(_on_yin_yue_manor_event_trigger_body_entered):
			event_area.body_entered.connect(_on_yin_yue_manor_event_trigger_body_entered)
	else:
		push_warning("找不到 yin_yue_manor_event_trigger/yin_yue_manor_event_trigger。")

	await _play_entry_fade()
	await show_map_name()

	if _get_flag(F_NIGHT_MEETING_DONE, false):
		_setup_post_meeting_state()
	else:
		await _check_initial_overlap_for_event()


func get_map_display_name() -> String:
	return map_display_name


func _play_entry_fade() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 1.5

	var tween_in := overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished


func show_map_name() -> void:
	var map_popup := get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0

		await get_tree().create_timer(2.0).timeout

		var popup_tween := map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished

		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")


func _check_initial_overlap_for_event() -> void:
	if event_area == null:
		return

	await get_tree().process_frame
	await get_tree().physics_frame

	for body in event_area.get_overlapping_bodies():
		if _is_player(body):
			await _start_night_meeting()
			return


# ------------------------------------------------------------
# 主事件：夜間會談
# ------------------------------------------------------------
func _on_yin_yue_manor_event_trigger_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if story_locked or _get_flag(F_NIGHT_MEETING_DONE, false):
		return

	# 只在魚怪戰後待會談狀態觸發。若你想 debug，可暫時註解這段。
	if not _get_flag(F_AFTER_FISH_READY, true):
		return

	await _start_night_meeting()


func _start_night_meeting() -> void:
	if story_locked:
		return

	story_locked = true
	_disable_event_area()
	_set_player_movable(false)

	var liuyu := _get_player()

	_play_anim(liuyu, "idle_right_up")
	_play_anim(shumian_npc, "idle_right_up")
	_play_anim(zuoyin_npc, "idle_left_down")

	await _show_dialog(_build_meeting_opening_lines())

	# 左飲說「坐」以後，角色真的移動到座位。
	await _move_liuyu_and_shumian_to_seats()

	_play_anim(liuyu, "sit_right_up")
	_play_anim(shumian_npc, "sit_right_up")

	await _show_dialog(_build_meeting_main_lines())

	# 會談結尾，兩人先起身。書眠回等待位置，讓玩家可以找她觸發支線。
	_play_anim(liuyu, "idle_right_up")
	_play_anim(shumian_npc, "idle_right_up")

	await _move_node_along_path(shumian_npc, shumian_back_path, 1.2, "walk_right_up", "idle_right_up")

	_set_flag(F_NIGHT_MEETING_DONE, true)
	_set_flag(F_READY_FOR_QINGFENG, true)
	_set_flag(F_SHUMIAN_SIDE_AVAILABLE, true)
	_set_flag(F_SHUMIAN_JOIN_PENDING, true)

	_setup_post_meeting_state()

	_set_player_movable(true)
	story_locked = false


func _build_meeting_opening_lines() -> Array:
	return [
		_n("紅徽音坐在屏風旁，琴匣未開。屋中燈火不亮，卻足以映出每個人臉上的疲色。"),
		_l("你們回來了。", huiyin_speaker_id, huiyin_portrait_path),
		_l("徽音……", shumian_speaker_id, shumian_portrait_path),
		_l("你受傷了嗎？", huiyin_speaker_id, huiyin_portrait_path),
		_l("沒有。", shumian_speaker_id, shumian_portrait_path),
		_l("坐。", zuoyin_speaker_id, zuoyin_portrait_path),
	]


func _build_meeting_main_lines() -> Array:
	return [
		_l("墨鱗魘將已經退了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("退了，不代表結束。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("牠不是始作俑者。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("只是下面積的東西，先長成了牠。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……是我沒有把符補好。", shumian_speaker_id, shumian_portrait_path),
		_l("不是只有妳。", huiyin_speaker_id, huiyin_portrait_path),
		_l("那些符是我貼的。", shumian_speaker_id, shumian_portrait_path),
		_l("琴聲，是我壓的。", huiyin_speaker_id, huiyin_portrait_path),
		_l("外頭那些東西，是我沒斬乾淨。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……我不覺得這件事該由誰一個人負起全責。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你們幾個，都很在乎玉衡鎮。", liuyu_speaker_id, liuyu_portrait_path),
		_l("只是……你們各自守著的，似乎都只有其中一段。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……我以為，還有時間。", shumian_speaker_id, shumian_portrait_path),
		_l("至少在找到別的辦法以前……還能再撐一陣。", shumian_speaker_id, shumian_portrait_path),
		_l("我知道琴聲壓住的東西，並沒有真的消失。", huiyin_speaker_id, huiyin_portrait_path),
		_l("所以我一直以為……到了夜裡，人在夢裡，總還能慢慢把那些東西放出來。", huiyin_speaker_id, huiyin_portrait_path),
		_l("書眠。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯？", shumian_speaker_id, shumian_portrait_path),
		_l("妳先前在舊水道看到的那句話……", liuyu_speaker_id, liuyu_portrait_path),
		_l("『心亂則語生，語腐則水濁，水濁則夢驚。』", liuyu_speaker_id, liuyu_portrait_path),
		_l("……嗯。", shumian_speaker_id, shumian_portrait_path),
		_l("我在想……這句話，恐怕本來就不是一條走到底的路。", liuyu_speaker_id, liuyu_portrait_path),
		_n("眾人安靜了片刻。"),
		_l("而是一個圈。", liuyu_speaker_id, liuyu_portrait_path),
		_l("白日裡壓下去的東西……到了夜裡，又從夢裡翻上來。", huiyin_speaker_id, huiyin_portrait_path),
		_l("夢驚……便又使人心亂。", shumian_speaker_id, shumian_portrait_path),
		_l("心一亂，語魅便再生。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("然後又回到水裡。", liuyu_speaker_id, liuyu_portrait_path),
		_n("屋中一時無人開口。"),
		_n("那條藏在玉衡鎮地底、日復一日循環的路，直到此刻，才終於在幾人面前接成了完整的一圈。"),
		_l("而我只顧著外面。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("結果，我們都只守住了自己看得見的那一面。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲沉默了一會兒，忽然抬眼看向你。"),
		_l("說起來……你一路找我，總不會只是為了玉衡鎮。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("確實不是。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我在找一本秘笈。", liuyu_speaker_id, liuyu_portrait_path),
		_n("左飲看了你片刻。"),
		_l("……讖語破心訣？", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左莊主知道？", liuyu_speaker_id, liuyu_portrait_path),
		_l("知道些。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("至少知道，該去問誰。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("翼軫鎮。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("映火樓樓主，聞燈。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("他手上未必有《讖語破心訣》。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("但若論它的下落……他知道的，應該比我多。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("聞燈……", liuyu_speaker_id, liuyu_portrait_path),
		_l("本來，等這裡的事情結束，我可以帶你去一趟。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你替玉衡鎮做了這麼多，又護著書眠一路走到現在。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("這份情，我總該還。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲停了一下。"),
		_l("可現在看來……還不行。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("因為玉衡鎮？", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("墨鱗魘將沒了，只是眼前這一場停了。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("底下那個圈，還在。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我現在若走，沒人知道下一次會從哪裡冒出來。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("玉衡鎮不能再只靠壓。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("那要靠什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("疏。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("壓得住一時。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("疏得通，才撐得久。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我的琴能壓心。", huiyin_speaker_id, huiyin_portrait_path),
		_l("可現在的曲，做不到讓那些情緒自己走完。", huiyin_speaker_id, huiyin_portrait_path),
		_l("我的詩能替人留一個出口。", shumian_speaker_id, shumian_portrait_path),
		_l("可光靠詩，也接不住整座鎮子。", shumian_speaker_id, shumian_portrait_path),
		_l("所以，要讓我真的離得開這裡——", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲看向紅徽音。"),
		_l("得先讓她換一首曲。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你知道有這樣的曲？", liuyu_speaker_id, liuyu_portrait_path),
		_l("知道。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("《白鳶橫天》。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("若能讓那些情緒真正有地方可去……", liuyu_speaker_id, liuyu_portrait_path),
		_l("至少，不會再像這次一樣，在地底養出第二頭墨鱗魘將。", liuyu_speaker_id, liuyu_portrait_path),
		_l("正是。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("你沉默片刻。"),
		_n("你原本只是想找到左飲，循著他的線索繼續追查《讖語破心訣》。"),
		_n("可走到如今，你已無法把玉衡鎮發生的一切，當成與自己無關的岔路。"),
		_l("好。", liuyu_speaker_id, liuyu_portrait_path),
		_l("《白鳶橫天》，我去找。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你已經替玉衡鎮走了一趟。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("照理說，該是我還你的時候。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("結果現在，反倒還要再請你替我跑一趟。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左莊主不必算得這麼清。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我算。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("這一次，我再欠你。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("那等玉衡鎮真的穩下來。", liuyu_speaker_id, liuyu_portrait_path),
		_l("再勞煩左莊主陪我去一趟翼軫鎮。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("到時候，我帶你去見聞燈。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("《白鳶橫天》現在在哪裡？", liuyu_speaker_id, liuyu_portrait_path),
		_l("烈風寨。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("列霄手上。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("話音才落，紅徽音搭在琴匣上的手指便微微一頓。她沒有立刻抬頭，只是眉間極輕地收了一下。"),
		_l("……偏偏是他。", huiyin_speaker_id, huiyin_portrait_path),
		_l("妳認得列霄？", liuyu_speaker_id, liuyu_portrait_path),
		_l("認得。", huiyin_speaker_id, huiyin_portrait_path),
		_l("我師兄。", huiyin_speaker_id, huiyin_portrait_path),
		_n("她停了一下。"),
		_l("以前是。", huiyin_speaker_id, huiyin_portrait_path),
		_l("他們都是弦禪子的弟子。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左飲。", huiyin_speaker_id, huiyin_portrait_path),
		_l("總得讓他知道要去見誰。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("所以我才不想欠他。", huiyin_speaker_id, huiyin_portrait_path),
		_n("她頓了一下。"),
		_l("……但現在不是計較這些的時候。", huiyin_speaker_id, huiyin_portrait_path),
		_l("劉少俠，我也去。", shumian_speaker_id, shumian_portrait_path),
		_l("妳留下。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左莊主？", shumian_speaker_id, shumian_portrait_path),
		_l("先留下。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("舊水道，妳還沒回去看。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("白書眠沉默。"),
		_l("那些符是妳貼的。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("妳一直說，是自己沒有補好。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("既然如此，就先回去看清楚。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我不是要妳留在玉衡鎮。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我是要妳先把自己不敢回頭看的地方，看完。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("看完了，妳若還想走——", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我不攔。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……書眠。", huiyin_speaker_id, huiyin_portrait_path),
		_n("白書眠抬頭。"),
		_l("去看看吧。", huiyin_speaker_id, huiyin_portrait_path),
		_l("不是為了補給誰看。", huiyin_speaker_id, huiyin_portrait_path),
		_l("只是去看看。", huiyin_speaker_id, huiyin_portrait_path),
		_l("劉少俠。", shumian_speaker_id, shumian_portrait_path),
		_l("嗯？", liuyu_speaker_id, liuyu_portrait_path),
		_l("出發以前……能陪我去一趟舊水道嗎？", shumian_speaker_id, shumian_portrait_path),
		_l("去看那些符？", liuyu_speaker_id, liuyu_portrait_path),
		_n("白書眠微微點頭。"),
		_l("墨鱗魘將已退，語魅也散了。", shumian_speaker_id, shumian_portrait_path),
		_l("那裡現在已經沒有什麼要躲的了。", shumian_speaker_id, shumian_portrait_path),
		_l("所以我想回去。", shumian_speaker_id, shumian_portrait_path),
		_l("把能補的補好，也把該看的看完。", shumian_speaker_id, shumian_portrait_path),
		_l("好。", liuyu_speaker_id, liuyu_portrait_path),
		_n("主線更新：準備前往烈風寨。"),
		_n("可與書眠對話，前往舊水道查看封印。"),
		_n("準備完成後，與左飲對話，即可出發。"),
	]


# ------------------------------------------------------------
# 會談後：自由行動與左飲出發事件
# ------------------------------------------------------------
func _setup_post_meeting_state() -> void:
	_disable_event_area()

	var liuyu := _get_player()
	_play_anim(liuyu, "idle_right_up")
	_play_anim(shumian_npc, "idle_right_up")
	_play_anim(zuoyin_npc, "idle_left_down")

	# 若重載場景，讓書眠站回等待點；沒有 marker 時，就停留目前位置。
	var back_follow := _get_path_follow(shumian_back_path)
	if shumian_npc and back_follow:
		back_follow.progress_ratio = 1.0
		shumian_npc.global_position = back_follow.global_position

	_set_flag(F_READY_FOR_QINGFENG, true)
	_set_flag(F_SHUMIAN_SIDE_AVAILABLE, true)
	_set_flag(F_SHUMIAN_JOIN_PENDING, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if story_locked or transition_locked or post_meeting_interaction_locked:
			return
		if not _get_flag(F_NIGHT_MEETING_DONE, false):
			return

		var player := _get_player()
		if player == null:
			return

		if zuoyin_npc and player.global_position.distance_to(zuoyin_npc.global_position) <= 90.0:
			await _start_departure_with_zuoyin()


func _start_departure_with_zuoyin() -> void:
	if transition_locked or post_meeting_interaction_locked:
		return

	post_meeting_interaction_locked = true
	_set_player_movable(false)

	await _show_dialog([
		_l("準備好了？", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("嗯。", liuyu_speaker_id, liuyu_portrait_path),
		_l("那就出發。", zuoyin_speaker_id, zuoyin_portrait_path),
	])

	if not _get_flag(F_ZUOYIN_SUPPLIES_RECEIVED, false):
		_give_zuoyin_supplies()
		await _show_dialog(_build_supply_received_lines())

	_set_flag(F_ZUOYIN_SUPPLIES_RECEIVED, true)
	_set_flag(F_SHUMIAN_JOINED, true)
	_set_flag(F_SHUMIAN_JOIN_PENDING, false)
	_set_flag(F_LIEFENG_CHAPTER_STARTED, true)

	_add_shumian_to_party()

	await _show_dialog([
		_n("書眠加入隊伍。"),
		_n("主線更新：前往清風竹林，尋找通往烈風寨的道路。"),
	])

	await _transition_to_qingfeng_bamboo()

	post_meeting_interaction_locked = false


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
	_add_money(money_reward)
	for item_id in supply_items.keys():
		_add_item(str(item_id), int(supply_items[item_id]))


func _transition_to_qingfeng_bamboo() -> void:
	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	if qingfeng_bamboo_entrance_scene_path == "":
		push_warning("尚未設定 qingfeng_bamboo_entrance_scene_path，無法前往清風竹林。")
		_set_player_movable(true)
		transition_locked = false
		return

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = qingfeng_spawn_point_name
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(qingfeng_bamboo_entrance_scene_path)
			return

	get_tree().change_scene_to_file(qingfeng_bamboo_entrance_scene_path)


# ------------------------------------------------------------
# 移動 / 動畫
# ------------------------------------------------------------
func _move_liuyu_and_shumian_to_seats() -> void:
	var liuyu := _get_player()

	var tween_liuyu := _create_move_tween_along_path(liuyu, liuyu_go_path, 1.25, "walk_right_up", "sit_right_up")
	var tween_shumian := _create_move_tween_along_path(shumian_npc, shumian_go_path, 1.25, "walk_right_up", "sit_right_up")

	if tween_liuyu:
		await tween_liuyu.finished

	if tween_shumian and tween_shumian.is_running():
		await tween_shumian.finished


func _move_node_along_path(node: Node2D, path: Path2D, duration: float, moving_anim := "", end_anim := "") -> void:
	var tween := _create_move_tween_along_path(node, path, duration, moving_anim, end_anim)
	if tween:
		await tween.finished


func _create_move_tween_along_path(node: Node2D, path: Path2D, duration: float, moving_anim := "", end_anim := "") -> Tween:
	if node == null or path == null:
		return null

	var follow := _get_path_follow(path)
	if follow == null:
		push_warning("Path2D 缺少 PathFollow2D：" + str(path.name))
		return null

	follow.progress_ratio = 0.0
	node.global_position = follow.global_position

	if moving_anim != "":
		_play_anim(node, moving_anim)

	var tween := create_tween()
	tween.tween_method(
		func(value):
			follow.progress_ratio = value
			node.global_position = follow.global_position,
		0.0,
		1.0,
		duration
	)

	tween.finished.connect(func():
		follow.progress_ratio = 1.0
		node.global_position = follow.global_position
		if end_anim != "":
			_play_anim(node, end_anim)
	, CONNECT_ONE_SHOT)

	return tween


func _get_path_follow(path: Path2D) -> PathFollow2D:
	if path == null:
		return null

	var follow := path.get_node_or_null("PathFollow2D")
	if follow is PathFollow2D:
		return follow

	for child in path.get_children():
		if child is PathFollow2D:
			return child

	return null


func _play_anim(node: Node, anim_name: String) -> void:
	if node == null or anim_name == "":
		return

	var sprite := _find_animated_sprite(node)
	if sprite == null:
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		# 動畫不存在時不報錯，只保留現狀。
		print("動畫不存在：", anim_name, " node=", node.name)


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node

	var direct := node.get_node_or_null("AnimatedSprite2D")
	if direct is AnimatedSprite2D:
		return direct

	for child in node.get_children():
		var found := _find_animated_sprite(child)
		if found:
			return found

	return null


# ------------------------------------------------------------
# Party / Inventory
# ------------------------------------------------------------
func _add_shumian_to_party() -> void:
	var party_manager := _get_first_node([
		"/root/PartyManager",
		"/root/GameRoot/PartyManager",
		"/root/PartyController",
		"/root/GameRoot/PartyController",
	])

	if party_manager:
		if party_manager.has_method("add_member"):
			party_manager.add_member("shumian")
			return
		if party_manager.has_method("set_party_member"):
			party_manager.set_party_member(2, "shumian")
			return
		if party_manager.has_method("add_party_member"):
			party_manager.add_party_member("shumian")
			return

	_set_flag("party_slot_2", "shumian")


func _add_item(item_id: String, amount: int) -> void:
	var inventory := _get_first_node([
		"/root/InventoryManager",
		"/root/GameRoot/InventoryManager",
		"/root/InventorySync",
		"/root/GameRoot/InventorySync",
	])

	if inventory:
		if inventory.has_method("add_item"):
			inventory.add_item(item_id, amount)
			return
		if inventory.has_method("add"):
			inventory.add(item_id, amount)
			return

	# 找不到背包時，至少用 flag 記錄已給過。
	_set_flag("received_item_%s" % item_id, true)


func _add_money(amount: int) -> void:
	var inventory := _get_first_node([
		"/root/InventoryManager",
		"/root/GameRoot/InventoryManager",
		"/root/InventorySync",
		"/root/GameRoot/InventorySync",
		"/root/EconomyManager",
		"/root/GameRoot/EconomyManager",
	])

	if inventory:
		if inventory.has_method("add_money"):
			inventory.add_money(amount)
			return
		if inventory.has_method("add_currency"):
			inventory.add_currency("wen", amount)
			return
		if inventory.has_method("add_gold"):
			inventory.add_gold(amount)
			return

	var current_money := int(_get_flag("money", 0))
	_set_flag("money", current_money + amount)
	var current_wen := int(_get_flag("wen", 0))
	_set_flag("wen", current_wen + amount)


# ------------------------------------------------------------
# 共用：淡出 / 玩家 / Trigger
# ------------------------------------------------------------
func _fade_out() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 0.0

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


func _get_player() -> Node2D:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player is Node2D:
		return player

	player = get_node_or_null("/root/Player")
	if player is Node2D:
		return player

	return null


func _is_player(body: Node) -> bool:
	return body.name == "LiuYu" or body.name == "Player" or body.is_in_group("player")


func _set_player_movable(value: bool) -> void:
	var player := _get_player()
	if player:
		player.set("can_move", value)


func _disable_event_area() -> void:
	if event_area == null:
		return

	for child in event_area.get_children():
		if child is CollisionShape2D:
			child.disabled = true


func _get_first_node(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if node:
			return node
	return null


# ------------------------------------------------------------
# Dialog helpers
# ------------------------------------------------------------
func _show_dialog(lines: Array) -> void:
	var dialog_manager := _get_dialog_manager()

	if dialog_manager == null:
		for line in lines:
			print(line)
		return

	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(lines, self)
		await _wait_dialog_finished(dialog_manager)
		return

	if dialog_manager.has_method("start_dialog"):
		dialog_manager.start_dialog(_lines_to_text_array(lines))
		await _wait_dialog_finished(dialog_manager)
		return

	for line in lines:
		print(line)


func _get_dialog_manager() -> Node:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		return dialog_manager

	dialog_manager = get_node_or_null("/root/DialogManager")
	if dialog_manager:
		return dialog_manager

	return null


func _wait_dialog_finished(dialog_manager: Node) -> void:
	if dialog_manager.has_signal("dialog_sequence_finished"):
		await dialog_manager.dialog_sequence_finished
	elif _waiting_for_dialog:
		await dialog_closed

	_waiting_for_dialog = false


func reset_dialog_state() -> void:
	if _waiting_for_dialog:
		_waiting_for_dialog = false
		dialog_closed.emit()


func _lines_to_text_array(lines: Array) -> Array[String]:
	var result: Array[String] = []
	for line in lines:
		if line is Dictionary and line.has("text"):
			result.append(str(line["text"]))
		else:
			result.append(str(line))
	return result


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


# ------------------------------------------------------------
# GlobalState helpers
# ------------------------------------------------------------
func _get_flag(flag_name: String, default_value = null):
	var global_state := _get_global_state()
	if global_state == null:
		return default_value

	if global_state.has_method("get_flag"):
		var value = global_state.get_flag(flag_name)
		if value == null:
			return default_value
		return value

	var value = global_state.get(flag_name)
	if value == null:
		return default_value

	return value


func _set_flag(flag_name: String, value) -> void:
	var global_state := _get_global_state()
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
		return

	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)


func _get_global_state() -> Node:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state:
		return global_state

	global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state:
		return global_state

	return null
