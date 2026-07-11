# 白箋居內｜書眠主線專用角色腳本
# 掛載對象：劇情專用的書眠 CharacterBody2D，不建議掛在平常賣詩詞的書眠 NPC 上。
# 觸發方式：玩家靠近書眠，按 Space 互動。
# 劇情功能：探望書眠 → 獲得/閱讀《銀屏語》 → 讀懂封底空白 → 共鳴被琴聲介入 → 書眠請劉語塵離開 → 轉場至夜晚玉衡鎮西市集。

extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/Shumian/Shumian_headshot.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var huiyin_portrait_path := "res://assets/sprites/Huiyin/Huiyin_headshot.png"
@export var empty_portrait_path := "res://assets/sprites/empty.png"

@export var speaker_id := 3              # 書眠
@export var liuyu_speaker_id := 2        # 劉語塵
@export var huiyin_speaker_id := 5       # 紅徽音 / 弦外之音
@export var narration_speaker_id := 0    # 旁白 / 系統

# 銀屏語事件結束後要切去的夜晚市集副本。
# 請在 Inspector 依你的專案實際路徑調整。
@export_file("*.tscn") var night_market_scene_path := "res://Scenes/Yuheng/yuheng_market_west_night.tscn"
@export var change_to_night_market_after_event := true

@onready var animated_sprite := get_node_or_null("AnimatedSprite2D")

var dialog_manager: Node = null
var can_interact := false
var is_talking := false
var dialog_lines: Array = []

# ------------------------------------------------------------
# Flags
# ------------------------------------------------------------
const F_BAIJIANJU_OPEN := "main_yh_baijianju_open"
const F_YINPINGYU_DONE := "event_yinpingyu_done"
const F_YINPINGYU_OBTAINED := "item_yinpingyu_obtained"
# 完成銀屏語後，不在室內直接播放紅徽音弦外之音；
# 改由夜晚玉衡鎮副本的 Hong_hue_yin_recall_event_trigger.gd 觸發。
const F_READY_HUIYIN_VOICE := "main_yh_ready_huiyin_voice"
const F_HEARD_HUIYIN_VOICE := "main_yh_heard_huiyin_voice"
const F_GO_TO_ZUIYUE_HUIYIN := "main_yh_go_to_zuiyue_huiyin"

# 條件分歧用 flags
const F_MARKET_QIN_INVESTIGATED := "yh_market_qin_investigated"
const F_DABAO_MAP_SHOWN := "yh_side_dabao_map_shown"

# 可選道具 ID：若專案有 InventoryManager.add_item，會嘗試加入；沒有也不會報錯。
const ITEM_YINPINGYU := "item_yinpingyu_scroll"

# 對話結束後才落旗，避免玩家還在讀對話時流程已被推進。
var _pending_flags_after_close: Array[String] = []
var _pending_objective_after_close := ""
var _pending_add_item_id := ""
var _pending_add_item_amount := 0


func _ready() -> void:
	dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[白箋居銀屏語事件] DialogManager 沒抓到！")

	# 這是主線專用書眠；未開啟白箋居主線，或事件已完成，就移除，避免干擾普通書眠 NPC。
	if not GlobalState.get_flag(F_BAIJIANJU_OPEN) or GlobalState.get_flag(F_YINPINGYU_DONE):
		queue_free()
		return

	dialog_lines = _build_yinpingyu_event_lines()


func _process(_delta: float) -> void:
	z_index = int(global_position.y + z_index_offset)


func _unhandled_input(event: InputEvent) -> void:
	if not can_interact:
		return
	if dialog_manager == null:
		return
	if dialog_manager.dialog_active:
		return
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		return
	if is_talking:
		return

	is_talking = true

	var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = false
		face_towards(liuyu.global_position)

	_clear_pending_actions()
	_queue_flag(F_YINPINGYU_DONE)
	_queue_flag(F_YINPINGYU_OBTAINED)
	_queue_flag(F_READY_HUIYIN_VOICE)
	_queue_add_item(ITEM_YINPINGYU, 1)
	_queue_objective("離開白箋居。")

	dialog_lines = _build_yinpingyu_event_lines()
	dialog_manager.show_dialog_sequence(dialog_lines, self)


func reset_dialog_state() -> void:
	var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true

	is_talking = false
	_apply_pending_actions()
	_clear_pending_actions()

	# 這支是一次性主線劇情專用 NPC；跑完後移除，讓普通書眠 NPC 接手後續狀態。
	# 接著切到夜晚玉衡鎮西市集，由那裡的紅徽音弦外之音 trigger 接手後續劇情。
	if change_to_night_market_after_event:
		_go_to_night_market_scene()

	queue_free()


# ------------------------------------------------------------
# 對話本體
# ------------------------------------------------------------
func _build_yinpingyu_event_lines() -> Array:
	var lines: Array = []

	lines.append_array([
		_n("白箋居內光線安靜，書架與紙卷整齊排列。"),
		_n("窗邊書燈未熄，墨香淡淡。書眠坐在案前，神色有些疲倦。"),
		_l("語塵？", speaker_id, portrait_path),
		_l("你怎麼進來了？", speaker_id, portrait_path),
		_l("外頭那人走了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我知道。", speaker_id, portrait_path),
		_n("書眠垂眼看向案上的詩箋，指尖停在紙邊，像是仍聽得見門外餘下的喧鬧。"),
		_l("他本不是惡人，只是……粗鄙了些。", speaker_id, portrait_path),
		_l("粗鄙到被你請出去？", liuyu_speaker_id, liuyu_portrait_path),
		_l("一開始，我只是明確拒絕他。", speaker_id, portrait_path),
		_l("我想著，話說清楚，他自然會知難而退。", speaker_id, portrait_path),
		_l("可他越說越急，聲音越來越大。", speaker_id, portrait_path),
		_l("白箋居不是只容我一人安靜的地方。", speaker_id, portrait_path),
		_l("若讓他一人吵得滿屋讀書人都不得安寧，那便不是我的清高，是我的失職。", speaker_id, portrait_path),
		_l("所以你把他請出去了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", speaker_id, portrait_path),
		_l("只是沒想到，他到了門外仍不肯罷休。", speaker_id, portrait_path),
		_l("他找上我了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("他找你？", speaker_id, portrait_path),
		_l("要我替他進來說情。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", speaker_id, portrait_path),
		_l("你答應了？", speaker_id, portrait_path),
		_l("沒有。", liuyu_speaker_id, liuyu_portrait_path),
		_l("那你說了什麼？", speaker_id, portrait_path),
		_l("我說，白箋居人人可入，他卻進不去。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", speaker_id, portrait_path),
		_l("不是規矩太複雜，是他腦袋太簡單。", liuyu_speaker_id, liuyu_portrait_path),
		_n("書眠怔了一下。下一瞬，她忍不住笑出聲。那笑聲很輕，像緊繃許久的紙頁終於鬆開一角。"),
		_l("你當真這麼說？", speaker_id, portrait_path),
		_l("他不服，說自己縱橫商場，算計天下。", liuyu_speaker_id, liuyu_portrait_path),
		_l("然後呢？", speaker_id, portrait_path),
		_l("他又問我，知不知道他那身衣裳的作工值多少錢。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……這倒像是他會說的話。", speaker_id, portrait_path),
		_l("所以我說，可惜。", liuyu_speaker_id, liuyu_portrait_path),
		_l("可惜？", speaker_id, portrait_path),
		_l("衣服穿得富麗堂皇，道貌岸然。", liuyu_speaker_id, liuyu_portrait_path),
		_l("做人卻還膚淺成這樣。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", speaker_id, portrait_path),
		_n("書眠望著他，神情裡的笑意慢慢淡下，卻不是失落。"),
		_n("她像是第一次真正看見這個沉默的江湖客，原來也會在該出聲的時候，將話說得如此鋒利。"),
		_l("你平日話不多，原來不是不會說。", speaker_id, portrait_path),
		_l("平日沒必要。", liuyu_speaker_id, liuyu_portrait_path),
		_l("今日有必要？", speaker_id, portrait_path),
		_l("他把你的詩當成擺設，又把你的拒絕當成抬價。", liuyu_speaker_id, liuyu_portrait_path),
		_l("這不是買賣。", liuyu_speaker_id, liuyu_portrait_path),
		_l("是糟蹋。", liuyu_speaker_id, liuyu_portrait_path),
		_n("屋內忽然靜了些。遠處琴聲仍在，卻像被牆與紙窗隔遠。"),
		_l("玉衡鎮很久沒有人這樣說話了。", speaker_id, portrait_path),
		_l("怎樣？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不是為了討好誰，也不是為了壓住誰。", speaker_id, portrait_path),
		_l("只是心裡動了，便說出來。", speaker_id, portrait_path),
		_l("真性情這種東西，在這裡……已經很久沒聽見了。", speaker_id, portrait_path),
		_l("我只是看不慣。", liuyu_speaker_id, liuyu_portrait_path),
		_l("看不慣，便已經很好了。", speaker_id, portrait_path),
		_l("至少你還看得見。", speaker_id, portrait_path),
		_n("書眠起身，從案旁取出一冊薄薄詩卷。"),
		_n("詩冊封面素淨，只題三字：《銀屏語》。"),
		_l("這冊詩，本不該這麼早交給人。", speaker_id, portrait_path),
		_l("給我？", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", speaker_id, portrait_path),
		_l("它叫《銀屏語》。", speaker_id, portrait_path),
		_l("我一直不知道它算不算寫完。", speaker_id, portrait_path),
		_l("但方才聽你說那些話，我忽然覺得，也許它等的不是我落下最後一筆。", speaker_id, portrait_path),
		_l("而是有人願意讀到那個空白處。", speaker_id, portrait_path),
		_n("獲得詩卷：《銀屏語》"),
	])

	lines.append_array(_build_yinpingyu_reading_lines())
	lines.append_array(_build_resonance_lines())
	lines.append_array(_build_leave_baijianju_lines())
	return lines


func _build_yinpingyu_reading_lines() -> Array:
	var lines: Array = [
		_n("畫面淡暗，白箋居內環境音降低。"),
		_n("書燈微晃，詩卷展開。紙頁聲很輕。"),
		_n("《銀屏語》第一首"),
		_n("銀屏不語月先明，\n一寸清光照舊城。\n人倚窗前聽遠曲，\n不知心事已無聲。"),
		_n("劉語塵原本只是翻閱。"),
		_n("可『遠曲』二字落入眼中時，他忽然覺得那道一直浮在鎮上的琴聲，也像從紙背後傳來。"),
		_n("《銀屏語》第二首"),
		_n("簾外風過竹影斜，\n杯中茶冷未歸家。\n欲問故人何處去，\n半句吞回作落花。"),
		_n("劉語塵的指尖停在『半句吞回』四字上。"),
	]

	if GlobalState.get_flag(F_DABAO_MAP_SHOWN):
		lines.append_array([
			_n("他想起大寶。"),
			_n("想起那孩子明明想說井在哪裡，話卻像被什麼按住，只能用繩索在地上排出方位。"),
			_n("那些沒說出口的話，原來也能在詩裡找到形狀。"),
		])
	else:
		lines.append_array([
			_n("那些字像落在水面上，明明輕，卻把心底某處壓得很深。"),
			_n("劉語塵說不出自己想起了誰，只覺得這半句吞回，像玉衡鎮裡太多人說到一半便消失的聲音。"),
		])

	lines.append_array([
		_n("《銀屏語》第三首"),
		_n("紙上春山留白處，\n有人執筆不成書。\n若問此心何所似，\n一痕墨盡一痕無。"),
		_n("屋內安靜下來。"),
		_n("劉語塵讀到最後一句時，忽然覺得遠處琴聲淡了。"),
		_n("不是聲音真的變小，而是他的心神暫時被詩意牽住，沒有立刻被琴音帶走。"),
		_n("他翻過第三首。"),
		_n("後面沒有第四首。"),
		_n("只有封底內頁一片空白。"),
		_l("……", liuyu_speaker_id, liuyu_portrait_path),
		_l("最後一頁是空白。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但那不是封底。", liuyu_speaker_id, liuyu_portrait_path),
		_n("須臾之後，他的目光慢慢定住。"),
		_n("他想起前三首裡那些欲言又止、心事無聲、墨盡無痕的句子。"),
		_n("若最後仍落成字，反而太滿。"),
		_l("這就是第四首詩。", liuyu_speaker_id, liuyu_portrait_path),
		_n("書眠抬眼看向他，神色微動。"),
		_l("你看見了？", speaker_id, portrait_path),
		_l("前三首都在說欲言又止。", liuyu_speaker_id, liuyu_portrait_path),
		_l("到了最後，若再寫下去，反而太滿。", liuyu_speaker_id, liuyu_portrait_path),
		_l("空白不是沒寫。", liuyu_speaker_id, liuyu_portrait_path),
		_l("是把沒能說出口的那句，留給讀的人接住。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", speaker_id, portrait_path),
		_n("那一瞬間，書眠像是被什麼輕輕擊中。"),
		_n("不是驚嚇，而是久未有人真正讀見之後，忽然湧上來的酸楚與喜悅。"),
		_l("我未寫下的那一筆，其實是——", speaker_id, portrait_path),
		_l("你沉默時，我想說的那一句。", speaker_id, portrait_path),
		_n("BGM 切換為低聲版本『心音重疊』。"),
		_n("環境音靜默三秒。書燈輕晃，紙頁聲停止。"),
		_n("劉語塵看著那片空白。"),
		_n("一時間，飲月山莊閉門的不甘、尋找『那物』的焦急、一路所見的異樣，都像被這片空白暫時盛住。"),
		_n("他不是忘了自己為何而來，而是忽然明白，心神原來可以不被琴聲牽走，也不被目的拖著走。"),
	])

	return lines


func _build_resonance_lines() -> Array:
	var lines: Array = [
		_n("醉月茶坊方向傳來琴聲。"),
		_n("琴聲極輕，卻穿透白箋居內的靜默。"),
		_n("那琴聲一起，劉語塵便察覺到了。"),
		_n("他曾在讀《臨風寄影》時被這樣的琴聲壓住過。"),
		_n("心裡剛要浮起的感動，會先變得遲緩；接著，那些酸楚、不甘、憐惜，都像被一隻溫柔卻不容抗拒的手按回水底。"),
		_n("這一次，他知道預兆。"),
		_n("也知道自己不願再讓它發生。"),
		_l("……不行。", liuyu_speaker_id, liuyu_portrait_path),
		_l("語塵？", speaker_id, portrait_path),
		_l("這份感動不是多餘的。", liuyu_speaker_id, liuyu_portrait_path),
		_l("不能又被它收走。", liuyu_speaker_id, liuyu_portrait_path),
		_n("書眠指尖微顫。"),
		_n("她也感覺到了。那份終於被讀懂的喜悅剛剛浮起，便被琴聲一寸寸壓低。"),
		_n("她眼中方才亮起的光，像快要被水淹沒。"),
		_l("每次都是這樣。", speaker_id, portrait_path),
		_l("當話快要抵達心底時，它便會來。", speaker_id, portrait_path),
		_l("不是惡意。", speaker_id, portrait_path),
		_l("可它總會把那些剛要浮上來的東西……重新壓回去。", speaker_id, portrait_path),
		_l("這次不同。", liuyu_speaker_id, liuyu_portrait_path),
		_n("他沒有大聲說話，卻像在心裡將某個地方按住。"),
		_n("不是壓下情緒，而是不讓情緒被奪走。"),
	]

	if GlobalState.get_flag(F_MARKET_QIN_INVESTIGATED):
		lines.append_array([
			_l("這不是我第一次聽見那琴聲。", liuyu_speaker_id, liuyu_portrait_path),
			_l("之前它像一隻手，把人的情緒往水底按。", liuyu_speaker_id, liuyu_portrait_path),
			_l("可這一次，我聽見的不是壓抑。", liuyu_speaker_id, liuyu_portrait_path),
			_l("是愧疚。", liuyu_speaker_id, liuyu_portrait_path),
			_n("書眠身體微微一震。"),
			_n("那一瞬間，她像被說中了長久以來不敢明說的事。"),
			_l("……你感覺到了嗎？", speaker_id, portrait_path),
			_l("那麼遠……那麼細的弦……", speaker_id, portrait_path),
		])
	else:
		lines.append_array([
			_l("琴聲裡……有人。", liuyu_speaker_id, liuyu_portrait_path),
			_l("有人？", speaker_id, portrait_path),
			_l("不是壓迫。", liuyu_speaker_id, liuyu_portrait_path),
			_l("是呼喚。", liuyu_speaker_id, liuyu_portrait_path),
			_l("你竟能聽到這一步……", speaker_id, portrait_path),
		])

	lines.append_array([
		_l("是她在愧疚吧？", liuyu_speaker_id, liuyu_portrait_path),
		_l("紅徽音？", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", speaker_id, portrait_path),
		_l("可為什麼，你也在道歉？", liuyu_speaker_id, liuyu_portrait_path),
		_n("書眠垂下眼，指尖按在詩卷封底的空白處。"),
		_n("那片空白像一盞未點亮的燈，也像一句遲遲未出口的歉意。"),
		_l("因為……我本該讓大家說出話。", speaker_id, portrait_path),
		_l("可我的詩，沒有穿過她的琴。", speaker_id, portrait_path),
		_l("她的琴？", liuyu_speaker_id, liuyu_portrait_path),
		_l("她不是錯。", speaker_id, portrait_path),
		_l("她只是不得不。", speaker_id, portrait_path),
		_l("不得不壓住整座鎮的情緒？", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", speaker_id, portrait_path),
		_n("書眠沒有答。"),
		_n("窗紙微微震動，琴聲從外頭流過，像有人在遠處忍住一聲嘆息。"),
		_l("語塵。", speaker_id, portrait_path),
		_l("有些話，我現在若說了，只會讓你更早走進霧裡。", speaker_id, portrait_path),
		_l("我已經在霧裡。", liuyu_speaker_id, liuyu_portrait_path),
		_l("那就至少……別由我把你推下去。", speaker_id, portrait_path),
		_l("對不起。", speaker_id, portrait_path),
		_l("你到底在對誰道歉？", liuyu_speaker_id, liuyu_portrait_path),
		_l("對她。", speaker_id, portrait_path),
		_l("對這座鎮。", speaker_id, portrait_path),
		_l("也對那些本來該被我寫下，卻最後只剩空白的話。", speaker_id, portrait_path),
		_n("她起身，像是想再說什麼，卻終究把話停在唇邊。"),
		_n("那停頓不是拒絕，而是怕自己一開口，便把劉語塵推進更深的水裡。"),
		_l("你先回去吧。", speaker_id, portrait_path),
		_l("現在？", liuyu_speaker_id, liuyu_portrait_path),
		_l("今晚的風太重了。", speaker_id, portrait_path),
		_l("我怕再說下去，連窗也關不住。", speaker_id, portrait_path),
		_n("書眠轉身走向內室。走到屏風旁時，她停了一下，沒有回頭。"),
		_l("語塵。", speaker_id, portrait_path),
		_l("嗯？", liuyu_speaker_id, liuyu_portrait_path),
		_l("你方才替我說的那些話……", speaker_id, portrait_path),
		_l("我會記得。", speaker_id, portrait_path),
		_l("我不是替你。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我知道。", speaker_id, portrait_path),
		_l("所以我才更會記得。", speaker_id, portrait_path),
		_n("書眠離開，白箋居內暫時無法繼續對話。"),
	])

	return lines


func _build_leave_baijianju_lines() -> Array:
	return [
		_n("書眠離開後，白箋居內只剩書燈與墨香。"),
		_n("遠處琴聲仍在，像隔著一層水，輕輕壓著未說完的話。"),
		_l("……出去吧。", liuyu_speaker_id, liuyu_portrait_path),
		_n("主線更新：離開白箋居。"),
	]


func _go_to_night_market_scene() -> void:
	if night_market_scene_path == "":
		push_warning("[白箋居銀屏語事件] night_market_scene_path 未設定，無法切到夜晚玉衡鎮。")
		return

	# 若專案有自己的轉場管理器，優先走它；否則使用 Godot 內建切場景。
	var transition_manager := get_node_or_null("/root/TransitionManager")
	if transition_manager and transition_manager.has_method("change_scene_with_fade"):
		transition_manager.change_scene_with_fade(night_market_scene_path)
		return

	transition_manager = get_node_or_null("/root/GameRoot/TransitionManager")
	if transition_manager and transition_manager.has_method("change_scene_with_fade"):
		transition_manager.change_scene_with_fade(night_market_scene_path)
		return

	get_tree().change_scene_to_file(night_market_scene_path)

# ------------------------------------------------------------
# 互動區域：請將書眠子節點 Area2D 的 body_entered/body_exited 連到這兩個函式。
# ------------------------------------------------------------
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false


# ------------------------------------------------------------
# 角色朝向
# ------------------------------------------------------------
func face_towards(target_position: Vector2) -> void:
	if animated_sprite == null:
		return
	var direction := (target_position - global_position).normalized()
	var anim_name := _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle := dir.angle()
	if angle >= -PI * 7.0 / 8.0 and angle < -PI * 5.0 / 8.0:
		return "%s_left_up" % prefix
	elif angle >= -PI * 5.0 / 8.0 and angle < -PI * 3.0 / 8.0:
		return "%s_up" % prefix
	elif angle >= -PI * 3.0 / 8.0 and angle < -PI * 1.0 / 8.0:
		return "%s_right_up" % prefix
	elif angle >= -PI * 1.0 / 8.0 and angle < PI * 1.0 / 8.0:
		return "%s_right" % prefix
	elif angle >= PI * 1.0 / 8.0 and angle < PI * 3.0 / 8.0:
		return "%s_right_down" % prefix
	elif angle >= PI * 3.0 / 8.0 and angle < PI * 5.0 / 8.0:
		return "%s_down" % prefix
	elif angle >= PI * 5.0 / 8.0 and angle < PI * 7.0 / 8.0:
		return "%s_left_down" % prefix
	else:
		return "%s_left" % prefix


# ------------------------------------------------------------
# Pending action helpers
# ------------------------------------------------------------
func _queue_flag(flag_name: String) -> void:
	if not _pending_flags_after_close.has(flag_name):
		_pending_flags_after_close.append(flag_name)


func _queue_objective(text: String) -> void:
	_pending_objective_after_close = text


func _queue_add_item(item_id: String, amount: int = 1) -> void:
	_pending_add_item_id = item_id
	_pending_add_item_amount = amount


func _apply_pending_actions() -> void:
	for flag_name in _pending_flags_after_close:
		GlobalState.set_flag(flag_name, true)

	if _pending_add_item_id != "" and _pending_add_item_amount > 0:
		_add_item_safely(_pending_add_item_id, _pending_add_item_amount)

	if _pending_objective_after_close != "":
		_set_main_objective_safely(_pending_objective_after_close)


func _clear_pending_actions() -> void:
	_pending_flags_after_close.clear()
	_pending_objective_after_close = ""
	_pending_add_item_id = ""
	_pending_add_item_amount = 0


func _add_item_safely(item_id: String, amount: int = 1) -> void:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("add_item"):
		inv.add_item(item_id, amount)
		return

	inv = get_node_or_null("/root/GameRoot/InventoryManager")
	if inv and inv.has_method("add_item"):
		inv.add_item(item_id, amount)


func _set_main_objective_safely(text: String) -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)
		return

	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)


# ------------------------------------------------------------
# Dialog line helpers
# ------------------------------------------------------------
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
