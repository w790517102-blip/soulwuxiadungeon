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
		_n("鐘乳石洞一戰後，左飲帶著劉語塵與書眠返回飲月山莊。"),
		_n("山莊夜燈未熄，廳中茶盞早已冷透。"),
		_n("紅徽音坐在屏風旁，琴匣未開，卻像已聽見所有未說出口的話。"),
		_l("你們回來了。", huiyin_speaker_id, huiyin_portrait_path),
		_l("徽音……", shumian_speaker_id, shumian_portrait_path),
		_l("你受傷了嗎？", huiyin_speaker_id, huiyin_portrait_path),
		_l("沒有。", shumian_speaker_id, shumian_portrait_path),
		_n("書眠答得很快。快得像怕自己一慢，便會承認別的什麼也受了傷。"),
		_l("坐。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("他只說了一個字。"),
		_n("可這一字落下，竟比山門前的閉莊令更沉。"),
	]


func _build_meeting_main_lines() -> Array:
	return [
		_l("魚怪已退。", liuyu_speaker_id, liuyu_portrait_path),
		_l("退了，不代表結束。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("牠不是始作俑者。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("牠只是先撐不住的那一個。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("廳中一時無聲。"),
		_l("是我沒有補好。", shumian_speaker_id, shumian_portrait_path),
		_l("不是只有你。", huiyin_speaker_id, huiyin_portrait_path),
		_l("那些符是我貼的。", shumian_speaker_id, shumian_portrait_path),
		_l("琴聲是我壓的。", huiyin_speaker_id, huiyin_portrait_path),
		_l("外頭那些邪典，是我沒斬乾淨。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("三句話落下，像三枚冷石投入同一池水。"),
		_l("若要問罪，你們每個人都能把自己問到無路可走。", liuyu_speaker_id, liuyu_portrait_path),
		_l("可玉衡鎮現在缺的不是罪人。", liuyu_speaker_id, liuyu_portrait_path),
		_l("是下一步。", liuyu_speaker_id, liuyu_portrait_path),
		_n("左飲抬眼看他。"),
		_l("你倒是清楚。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("在舊水道裡走過一趟，多少清楚一些。", liuyu_speaker_id, liuyu_portrait_path),
		_l("藥、琴、符，本來都是救人的東西。", liuyu_speaker_id, liuyu_portrait_path),
		_l("後來卻一個悶成毒，一個扭成雜響，一個被迫壓成封印。", liuyu_speaker_id, liuyu_portrait_path),
		_n("書眠低下眼。"),
		_l("我以為只要再補一次，再撐一夜，就能多等一點時間。", shumian_speaker_id, shumian_portrait_path),
		_l("我也是。", huiyin_speaker_id, huiyin_portrait_path),
		_l("我以為只要琴聲不斷，鎮民的心就不會被語魅吞掉。", huiyin_speaker_id, huiyin_portrait_path),
		_l("我以為只要把外頭的污染源斬斷，鎮裡就能慢慢恢復。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲看向廳外。"),
		_n("夜色壓在山莊瓦脊上，像一封遲遲沒有拆開的信。"),
		_l("結果，我們都只守住了自己看得見的那一面。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("所以才讓玉衡鎮越來越安靜。", liuyu_speaker_id, liuyu_portrait_path),
		_l("安靜到不像活著。", huiyin_speaker_id, huiyin_portrait_path),
		_l("也不像寫得出詩。", shumian_speaker_id, shumian_portrait_path),
		_n("這句話很輕。"),
		_n("可說出口後，書眠像終於聽見了自己。"),
		_l("玉衡鎮不能再只靠壓。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("那要靠什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("疏。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("壓得住一時，疏得通，才撐得久。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我的琴能壓心，不能疏心。", huiyin_speaker_id, huiyin_portrait_path),
		_l("我的詩能留出口，卻不能讓整座鎮的聲音重新流動。", shumian_speaker_id, shumian_portrait_path),
		_l("所以要找一門能引風入水、斬濁不斷脈的功夫。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你知道在哪裡？", liuyu_speaker_id, liuyu_portrait_path),
		_l("烈風寨。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("書眠微微一怔。"),
		_l("列霄・風約？", shumian_speaker_id, shumian_portrait_path),
		_n("紅徽音指尖一緊。"),
		_l("白鳶橫天……", huiyin_speaker_id, huiyin_portrait_path),
		_n("她念出那四個字時，聲音很輕，卻不像懷念。"),
		_n("更像一根多年未碰的弦，忽然被人撥了一下。"),
		_l("你認得他？", liuyu_speaker_id, liuyu_portrait_path),
		_l("同門舊人。", huiyin_speaker_id, huiyin_portrait_path),
		_l("也算……舊怨。", huiyin_speaker_id, huiyin_portrait_path),
		_l("徽音。", shumian_speaker_id, shumian_portrait_path),
		_l("我知道現在不是說這些的時候。", huiyin_speaker_id, huiyin_portrait_path),
		_l("可若要向他借《白鳶橫天》，你們至少要知道，他不是單純離開弦心門。", huiyin_speaker_id, huiyin_portrait_path),
		_l("《白鳶橫天》是什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("一式刀琴並行的舊招。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("能斬濁氣，也能保住水脈不碎。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("當年列霄離開弦心門後，便很少再讓人聽見那一式。", huiyin_speaker_id, huiyin_portrait_path),
		_l("他和弦心門有仇？", liuyu_speaker_id, liuyu_portrait_path),
		_l("他和我們的師父有結。", huiyin_speaker_id, huiyin_portrait_path),
		_l("他始終不肯相信，師父當年接受各派推舉、前往剿滅語魅巢穴，不是為了名聲，也不是為了什麼武林盟主之位。", huiyin_speaker_id, huiyin_portrait_path),
		_l("他覺得師父被江湖捧高了，也被江湖帶走了。", huiyin_speaker_id, huiyin_portrait_path),
		_l("可我知道，師父不是那樣的人。", huiyin_speaker_id, huiyin_portrait_path),
		_n("她說得很穩。"),
		_n("可「不是那樣的人」幾個字落下時，琴匣裡像有一根弦極輕地顫了一下。"),
		_l("列霄不會承認。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("他若肯承認，當年就不會斷弦離門。", huiyin_speaker_id, huiyin_portrait_path),
		_l("所以我去見他，可能不是借譜。", liuyu_speaker_id, liuyu_portrait_path),
		_l("是破結。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("不。", huiyin_speaker_id, huiyin_portrait_path),
		_n("紅徽音看向劉語塵。"),
		_l("先別急著破。", huiyin_speaker_id, huiyin_portrait_path),
		_l("那人最厭旁人替他判斷真相。", huiyin_speaker_id, huiyin_portrait_path),
		_l("你只要讓他願意聽見，師父當年也許不是他以為的那種人。", huiyin_speaker_id, huiyin_portrait_path),
		_l("這比借譜難。", liuyu_speaker_id, liuyu_portrait_path),
		_l("是。", huiyin_speaker_id, huiyin_portrait_path),
		_l("所以我才不想欠他。", huiyin_speaker_id, huiyin_portrait_path),
		_n("這句話說出口後，紅徽音自己也沉默了一瞬。"),
		_l("可玉衡鎮現在，已經沒有餘地讓我只顧自己的不甘。", huiyin_speaker_id, huiyin_portrait_path),
		_l("他會借嗎？", shumian_speaker_id, shumian_portrait_path),
		_l("不會。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲答得太快，快得連紅徽音都看了他一眼。"),
		_l("那你還要我去？", liuyu_speaker_id, liuyu_portrait_path),
		_l("我去，他不會見。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我去，他就會見？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不一定。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……", liuyu_speaker_id, liuyu_portrait_path),
		_l("但你不是玉衡鎮的人。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("有些話，我們說，他只會當成舊帳。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你說，或許還能被他聽成江湖事。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("若他不肯聽？", liuyu_speaker_id, liuyu_portrait_path),
		_l("那就先別提弦心門。", huiyin_speaker_id, huiyin_portrait_path),
		_l("也別提我。", huiyin_speaker_id, huiyin_portrait_path),
		_l("提風。", huiyin_speaker_id, huiyin_portrait_path),
		_l("他可以不認同我們，卻不會聽不懂風。", huiyin_speaker_id, huiyin_portrait_path),
		_l("你倒是會把難題交給外人。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你已經不是外人了。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("劉語塵沒有立刻回答。"),
		_n("他想起白箋居的空白，想起舊水道裡被水泡皺的符紙，也想起那尾被濁氣逼成妖物的鯉魚。"),
		_l("我原本來玉衡鎮，是為了向你打聽一件東西。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我知道。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("劉語塵抬眼。"),
		_l("讖語破心訣。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("紅徽音與書眠同時沉默。"),
		_l("你要找的東西，我確實知道一些。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("條件？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不是條件。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("是順序。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("玉衡鎮若撐不住，你拿到答案，也走不出這場濁流。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("所以先去烈風寨。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("清風竹林外有舊驛道，往北入幽霧峽谷，穿過亂風，便能找到烈風寨的山門。", huiyin_speaker_id, huiyin_portrait_path),
		_l("劉少俠，我也去。", shumian_speaker_id, shumian_portrait_path),
		_l("你留下。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左莊主。", shumian_speaker_id, shumian_portrait_path),
		_l("舊水道的符還要有人看。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("書眠指尖微微收緊。"),
		_l("她不是想逃。", liuyu_speaker_id, liuyu_portrait_path),
		_n("左飲看向他。"),
		_l("她是想補自己沒有補完的地方。", liuyu_speaker_id, liuyu_portrait_path),
		_n("廳中又靜了一瞬。"),
		_l("讓她去吧。", huiyin_speaker_id, huiyin_portrait_path),
		_l("書眠若一直留在鎮上，只會繼續把所有沒說出口的話都當成自己的錯。", huiyin_speaker_id, huiyin_portrait_path),
		_n("左飲沒有立刻回話。"),
		_n("許久。"),
		_l("可以。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("但不是去送命。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我明白。", shumian_speaker_id, shumian_portrait_path),
		_l("你們去烈風寨。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我守玉衡鎮。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我會穩住琴聲。", huiyin_speaker_id, huiyin_portrait_path),
		_l("撐到你們回來。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("若列霄不肯借呢？", liuyu_speaker_id, liuyu_portrait_path),
		_l("那就讓他肯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("這話很像命令。", liuyu_speaker_id, liuyu_portrait_path),
		_l("是請託。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("不像。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我不擅長。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("書眠忽然輕輕笑了一下。"),
		_n("那笑很淡，卻讓廳中凝住的氣稍微鬆開。"),
		_l("劉少俠。", shumian_speaker_id, shumian_portrait_path),
		_l("嗯？", liuyu_speaker_id, liuyu_portrait_path),
		_l("這一次，不是你一個人去。", shumian_speaker_id, shumian_portrait_path),
		_n("劉語塵看向她。"),
		_n("書眠沒有避開他的目光。"),
		_l("我也想知道，若風真的能進入這座鎮——", shumian_speaker_id, shumian_portrait_path),
		_l("我還能不能重新寫詩。", shumian_speaker_id, shumian_portrait_path),
		_l("既然這是我對你的請託，劉少俠，山莊也會備些補給與盤纏。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你也可自行準備。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("準備好了，來知會我一聲。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我會請人送你們到清風竹林入口。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("倒是周全。", liuyu_speaker_id, liuyu_portrait_path),
		_l("路不好走。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("人也不好見。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("劉少俠。", shumian_speaker_id, shumian_portrait_path),
		_l("嗯？", liuyu_speaker_id, liuyu_portrait_path),
		_l("出發前……我有一事想請你同行。", shumian_speaker_id, shumian_portrait_path),
		_l("舊水道？", liuyu_speaker_id, liuyu_portrait_path),
		_n("書眠微微一怔，隨即輕輕點頭。"),
		_l("魚怪已退，水脈暫清。", shumian_speaker_id, shumian_portrait_path),
		_l("可那些封印只是重新穩住，還稱不上真正安定。", shumian_speaker_id, shumian_portrait_path),
		_l("我想趁離開前，再去看一眼。", shumian_speaker_id, shumian_portrait_path),
		_l("把能補的補好。", shumian_speaker_id, shumian_portrait_path),
		_l("好。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你不問我為什麼？", shumian_speaker_id, shumian_portrait_path),
		_l("紅姑娘說過。", liuyu_speaker_id, liuyu_portrait_path),
		_l("見到你時，不問你為什麼逃。", liuyu_speaker_id, liuyu_portrait_path),
		_l("問你還想不想回來。", liuyu_speaker_id, liuyu_portrait_path),
		_n("書眠眼睫微微一顫。"),
		_l("那我現在可以答你。", shumian_speaker_id, shumian_portrait_path),
		_l("我想回來。", shumian_speaker_id, shumian_portrait_path),
		_l("所以，才要先讓自己能放心離開。", shumian_speaker_id, shumian_portrait_path),
		_n("主線更新：準備前往清風竹林。"),
		_n("可與書眠對話，前往舊水道穩固封印。"),
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
