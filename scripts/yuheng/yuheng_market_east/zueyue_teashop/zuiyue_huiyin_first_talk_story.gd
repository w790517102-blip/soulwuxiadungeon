# 醉月茶坊｜紅徽音主線專用角色腳本
# 掛載對象：醉月茶坊夜間場景中的紅徽音 CharacterBody2D。
# 觸發方式：玩家靠近紅徽音，按 Space 互動。
# 劇情功能：紅徽音初次完整對話 → 說明琴聲壓情與三人守護結構 → 委託調查書眠 → 取得半弦銅釦 → 開啟主線《濁渠尋蹤》。

extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var empty_portrait_path := "res://assets/sprites/empty.png"

@export var speaker_id := 5              # 正式通名後：紅徽音
@export var unknown_speaker_id := 1      # 正式通名前：茶坊女伶（沿用一般 NPC 上方對話軌）
@export var liuyu_speaker_id := 2        # 劉語塵
@export var narration_speaker_id := 0    # 旁白 / 系統

# 若你的互動 Area2D 不叫 Area2D，可以在 Inspector 改。
@export var interaction_area_path: NodePath = "Area2D"

@onready var animated_sprite := get_node_or_null("AnimatedSprite2D")
@onready var interaction_area := get_node_or_null(interaction_area_path) as Area2D

var dialog_manager: Node = null
var can_interact := false
var is_talking := false
const TeaHouseNightDialog = preload("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/tea_house_night_dialog.gd")

var player: Node = null
var _first_talk_mode := false

# ------------------------------------------------------------
# Flags
# ------------------------------------------------------------
const F_GO_TO_ZUIYUE_HUIYIN := "main_yh_go_to_zuiyue_huiyin"
const F_HUIYIN_FIRST_TALK_DONE := "event_huiyin_first_talk_done"
const F_MET_HUIYIN_NAME := "met_hong_huiyin_name"
const F_GOT_HALF_STRING_BUTTON := "main_yh_got_half_string_copper_button"
const F_ZHUOQU_XUNZONG_STARTED := "main_yh_zhuoqu_xunzong_started"

# 分歧用：大寶繩索/井口支線
const F_DABAO_MAP_SHOWN := "yh_side_dabao_map_shown"

# 道具 ID
const ITEM_HALF_STRING_BUTTON := "item_half_string_copper_button"

# 對話結束後才落旗，避免玩家還在讀對話時流程已被推進。
var _pending_flags_after_close: Array[String] = []


func _ready() -> void:
	dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[紅徽音主線事件] DialogManager 沒抓到！")

	if interaction_area:
		if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
			interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
			interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	else:
		push_warning("[紅徽音主線事件] 找不到互動 Area2D：%s" % str(interaction_area_path))



func _is_first_talk_available() -> bool:
	return (
		GlobalState.get_flag(F_GO_TO_ZUIYUE_HUIYIN)
		and not GlobalState.get_flag(F_HUIYIN_FIRST_TALK_DONE)
	)


func _process(_delta: float) -> void:
	z_index = int(global_position.y + z_index_offset)


func _unhandled_input(event: InputEvent) -> void:
	if not can_interact:
		return
	if dialog_manager == null:
		return
	if dialog_manager.dialog_active:
		return
	if is_talking:
		return
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		return

	# 首次長劇情做完以後仍可互動：只播短對白，不重發銅釦、不推進主線。
	_first_talk_mode = _is_first_talk_available()
	if not _first_talk_mode and not (GlobalState.get_flag(F_HUIYIN_FIRST_TALK_DONE) and GlobalState.get_flag(F_GOT_HALF_STRING_BUTTON)):
		return

	is_talking = true

	player = get_node_or_null("/root/GameRoot/LiuYu")
	if player:
		player.set("can_move", false)

	if not _first_talk_mode:
		dialog_manager.show_dialog_sequence(_build_revisit_lines(), self)
		return


	_clear_pending_actions()
	_queue_flag(F_HUIYIN_FIRST_TALK_DONE)
	_queue_flag(F_MET_HUIYIN_NAME)

	dialog_manager.show_dialog_sequence(_build_huiyin_first_talk_lines(), self)


func reset_dialog_state() -> void:
	if player:
		player.set("can_move", true)

	# DialogManager 會先呼叫此 callback，再隱藏對話框；延後到本次呼叫鏈結束，
	# 確保道具、旗標與主線進度都在畫面上的對話完整關閉後才套用。
	call_deferred("_complete_first_talk_after_dialog_closed")


func _complete_first_talk_after_dialog_closed() -> void:
	# 只有首次長劇情才發銅釦、落旗、推進主線；回訪對話結束只要把互動還給玩家。
	if _first_talk_mode:
		_apply_pending_actions()
		_clear_pending_actions()
		_first_talk_mode = false
	is_talking = false


## 首次劇情之後的回訪（夜晚只有 04：「拜託你了，少俠。」）。白天 05／06 的回訪在 Hong_huei_yin.gd。
func _build_revisit_lines() -> Array:
	# 夜晚只有 04。會談完成後劇情直接切到翌日白天，夜晚不存在 05／06；碰到就當異常狀態，安全處理。
	if GlobalState.get_flag(TeaHouseNightDialog.F_NIGHT_MEETING_DONE) or TeaHouseNightDialog.is_stage_06():
		push_warning("[紅徽音] 會談完成後仍在夜晚茶坊（異常旗標或場景直入），改用安全旁白。")
		return TeaHouseNightDialog.huiyin_revisit_abnormal_night(empty_portrait_path)
	return TeaHouseNightDialog.huiyin_revisit_04(speaker_id, portrait_path, empty_portrait_path)


# ------------------------------------------------------------
# 對話本體
# ------------------------------------------------------------
func _build_huiyin_first_talk_lines() -> Array:
	var lines: Array = []

	lines.append_array([
		_n("醉月茶坊內燈火低垂，客人稀少。"),
		_n("紅衣女伶仍坐於琴旁，琴弦在她指下微微震動。"),
		_n("她沒有立刻抬頭，像是剛剛那段弦外之音耗去了不少心力。"),
		_l("你來了。", unknown_speaker_id, portrait_path),
		_l("我聽見你了。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅衣女伶指尖仍按在琴弦上。"),
		_n("那不像彈奏，更像在壓住一口不能散的氣。"),
		_l("劉語塵。", unknown_speaker_id, portrait_path),
		_l("姑娘識得在下？", liuyu_speaker_id, liuyu_portrait_path),
		_l("你回應弦外之音時，名字也隨著心念一同傳了過來。", unknown_speaker_id, portrait_path),
		_l("原來如此。", liuyu_speaker_id, liuyu_portrait_path),
		_l("那麼，在下還未請教姑娘如何稱呼。", liuyu_speaker_id, liuyu_portrait_path),
		_l("弦心門．紅徽音。", unknown_speaker_id, portrait_path),
		_l("徽弦之徽，音律之音。", speaker_id, portrait_path),
		_l("紅姑娘。", liuyu_speaker_id, liuyu_portrait_path),
		_n("她仍未開口。"),
		_n("那個名字卻像一枚音落在琴弦上，自此有了可以被呼喚的形狀。"),
		_l("能聽見，便代表你已經不只是被琴音壓住的人。", speaker_id, portrait_path),
		_l("你能從弦外走進來。", speaker_id, portrait_path),
		_l("我彈琴時不能開口。內息一散，琴音便亂；琴音一亂，鎮上的情緒也會亂。", speaker_id, portrait_path),
		_l("所以我只能把想說的話藏進弦裡。", speaker_id, portrait_path),
		_n("琴聲依舊平穩，卻在這句話的尾音處，透出一絲難以察覺的澀意。"),
		_y("你與她的心念隨琴音相通，竟從那份平靜之下，聽出幾分無奈，以及藏得極深的歉疚。"),
		_y("你望向她那雙未曾停歇的手，忽然想起書眠曾說過的話。"),
		_l("書眠說，你不是錯，只是不得不。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅徽音眼神微微一沉，像心底某處被輕輕碰了一下。"),
		_l("她還是這樣。", speaker_id, portrait_path),
		_l("明明自己快被沉默壓垮，卻先替別人留一條退路。", speaker_id, portrait_path),
		_n("茶坊裡很靜。"),
		_n("外頭路人偶有經過，聲音很快被琴聲化開。"),
		_l("可我不是沒有錯。", speaker_id, portrait_path),
		_l("我的琴壓住語魅，也壓住了人心。", speaker_id, portrait_path),
		_l("我救了玉衡鎮的一部分，也讓另一部分慢慢失聲。", speaker_id, portrait_path),
		_l("你們到底在守什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("玉衡鎮。", speaker_id, portrait_path),
		_n("她說出這三個字時，並沒有半分自豪。"),
		_n("那更像一個多年背著重物的人，終於承認肩上的重量。"),
		_l("左飲守外。他追查邪典，清除語魅，讓污染源不能在鎮上擴散。", speaker_id, portrait_path),
		_l("我守心。我以琴壓情，讓鎮民過大的情緒波動沉下去，使語魅不易誕生，也不易彼此傳染。", speaker_id, portrait_path),
		_l("書眠守語。她用詩詞替人留下出口。若有人讀懂她的詩，心裡未能說出的情緒便能借詩成形，不至於爛在胸口。", speaker_id, portrait_path),
		_n("她停了一會兒。"),
		_n("琴弦在她指下無聲震動，像那三人原本穩定的局，如今已開始偏移。"),
		_l("本來，這是一個完整的局。", speaker_id, portrait_path),
		_l("現在不是了。", speaker_id, portrait_path),
		_l("因為你的琴越彈越重。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", speaker_id, portrait_path),
		_l("左飲的刀越走越遠。", speaker_id, portrait_path),
		_l("而書眠的詩……越來越少得到回聲。", speaker_id, portrait_path),
		_y("你想起《銀屏語》的封底空白。"),
		_y("那片空白不是未完，而是等待回聲。"),
		_l("我的琴讓語魅無法輕易誕生。", speaker_id, portrait_path),
		_l("卻也讓大家越來越難真正說出心裡的話。", speaker_id, portrait_path),
		_l("她需要讀者的真心回聲。沒有回聲，她便不知道下一筆該往哪裡落。", speaker_id, portrait_path),
		_l("她不是不寫。", speaker_id, portrait_path),
		_l("她是被整座鎮的沉默困住了。", speaker_id, portrait_path),
		_l("所以她道歉。", liuyu_speaker_id, liuyu_portrait_path),
		_l("她覺得自己沒能讓大家說出話。", speaker_id, portrait_path),
		_l("可我知道，真正壓住那些話的人，是我。", speaker_id, portrait_path),
		_l("你也在道歉。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅徽音抬起眼。燈火在她眼底晃了一下，很快又被壓回平靜。"),
		_l("我一直在道歉。", speaker_id, portrait_path),
		_l("只是以前，沒有人聽得見。", speaker_id, portrait_path),
		_n("琴聲未曾稍歇。"),
		_y("你卻聽得出來，那份歉疚並非只為了這一鎮百姓，也為了那個始終替人留下言語出口的姑娘。"),
		_l("書眠的詩，近來越寫越少了。", speaker_id, portrait_path),
		_l("她替旁人留下那麼多話，自己的心事，卻不知還能向誰說。", speaker_id, portrait_path),
		_n("她指尖輕輕掠過琴弦，神色依舊平靜，琴音深處卻多了一絲難以掩飾的牽掛。"),
		_l("有些話，我本該親自去對她說的……", speaker_id, portrait_path),
		_n("她沒有把話說完。"),
		_y("你望著那雙始終未曾離開琴弦的手，心下已有幾分明白。"),
		_l("紅姑娘，若有在下幫得上忙的地方，但說無妨。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅徽音抬眼望來。"),
		_n("那一瞬間，她似乎有些意外，片刻後才輕輕點了點頭。"),
	])

	if GlobalState.get_flag(F_DABAO_MAP_SHOWN):
		lines.append_array(_build_dabao_branch_lines())
	else:
		lines.append_array(_build_no_dabao_branch_lines())

	lines.append_array(_build_request_and_key_lines())
	return lines


func _build_dabao_branch_lines() -> Array:
	return [
		_y("你想起先前與大寶的交談。"),
		_l("有個孩子曾告訴我，他夢見井底有魚在哭。", liuyu_speaker_id, liuyu_portrait_path),
		_l("大寶？", speaker_id, portrait_path),
		_l("紅姑娘也認得他？", liuyu_speaker_id, liuyu_portrait_path),
		_l("那孩子的感知，比大人乾淨。", speaker_id, portrait_path),
		_l("有些聲音，大人聽不見，動物聽得見。", speaker_id, portrait_path),
		_l("有些痛，大人不肯承認，孩子會先夢到。", speaker_id, portrait_path),
		_l("他用繩索告訴我，有一口井能通往下水道。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅徽音沉默。她的指尖無意識地按住一根琴弦，那根弦沒有響，卻像壓著一聲嘆息。"),
		_l("……那口井，正是我要告訴你的入口。", speaker_id, portrait_path),
		_l("妳也知道？", liuyu_speaker_id, liuyu_portrait_path),
		_l("知道入口。", speaker_id, portrait_path),
		_l("至於下面如今變成什麼樣……我不知道。", speaker_id, portrait_path),
	]


func _build_no_dabao_branch_lines() -> Array:
	return [
		_l("既如此，該從何處尋起？", liuyu_speaker_id, liuyu_portrait_path),
		_l("從地下。", speaker_id, portrait_path),
		_n("她將目光移向茶坊後方。那裡隔著一扇小門，門外是後巷，井聲與水氣皆藏在夜裡。"),
		_l("醉月茶坊後方，有一口舊井。", speaker_id, portrait_path),
		_l("外人只當那是廢井，其實是早年藥師取水與避火用的暗道。", speaker_id, portrait_path),
		_l("井下連著玉衡鎮早年的舊水道。", speaker_id, portrait_path),
		_l("至於下面如今變成什麼樣……我不知道。", speaker_id, portrait_path),
	]


func _build_request_and_key_lines() -> Array:
	return [
		_l("還有一件事，我始終放心不下。", speaker_id, portrait_path),
		_l("近來每到夜深，我總會聽見茶坊後巷的舊井下，傳來一陣腳步聲。", speaker_id, portrait_path),
		_l("三步稍急，第四步慢半拍；遇到轉角，右腳落地總比左腳輕些。", speaker_id, portrait_path),
		_n("她指尖略微一頓。"),
		_l("很像書眠。", speaker_id, portrait_path),
		_l("這妳也聽得出來？", liuyu_speaker_id, liuyu_portrait_path),
		_l("聽得久了，自然認得。", speaker_id, portrait_path),
		_l("只是我不曾親眼見到她，也不知那腳步聲究竟從何而來。", speaker_id, portrait_path),
		_y("你想起白箋居裡，那位始終替旁人留下一線言語的姑娘。"),
		_y("若那腳步聲真是書眠，她為何會出現在那樣的地方？"),
		_y("若不是她，又是誰有著如此相似的步履？而真正的書眠，此刻又身在何處？"),
		_l("單憑腳步聲，尚不能斷定就是白姑娘。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但既有這條線索，便值得走一趟。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我也曾想過告訴左飲。", speaker_id, portrait_path),
		_l("可眼下只有幾夜的腳步聲，尚不足以驚動山莊。", speaker_id, portrait_path),
		_l("若因此惹得滿鎮猜疑，只怕又要添上許多不安。", speaker_id, portrait_path),
		_n("她低頭望向琴弦。"),
		_l("偏偏我又無法擅離此處。", speaker_id, portrait_path),
		_l("琴聲若停，鎮上那些好不容易壓下的情緒，恐怕又要失控。", speaker_id, portrait_path),
		_y("你看了看她始終未曾停歇的雙手，心下已有了決定。"),
		_l("紅姑娘不必為難。", liuyu_speaker_id, liuyu_portrait_path),
		_l("既然答應幫妳，這一趟便由我去。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅徽音抬眼望來，琴音中透出一絲感激。"),
		_l("多謝少俠。", speaker_id, portrait_path),
		_l("只是，若真見到了書眠……", speaker_id, portrait_path),
		_l("我明白。先聽她怎麼說。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅徽音輕輕頷首。"),
		_l("嗯。先聽。", speaker_id, portrait_path),
		_n("她從琴案旁取出一枚半月形銅釦。"),
		_l("這枚半弦銅釦，是書眠早年交給我的。", speaker_id, portrait_path),
		_l("茶坊後巷的舊井藏有機關。持此銅釦，便能開啟通往舊水道的暗道。", speaker_id, portrait_path),
		_y("你接過銅釦，將它收入懷中。"),
		_l("到茶坊後巷的井旁，找一塊刻著半枚月紋的石磚。", speaker_id, portrait_path),
		_l("將銅釦按入月紋缺口，井下的路便會開。", speaker_id, portrait_path),
		_l("機關？", liuyu_speaker_id, liuyu_portrait_path),
		_l("也是一段舊琴弦。", speaker_id, portrait_path),
		_l("它不認鑰匙，只認共鳴。", speaker_id, portrait_path),
		_l("若下面真是污染最深的地方呢？", liuyu_speaker_id, liuyu_portrait_path),
		_l("那你更該小心。", speaker_id, portrait_path),
		_l("井下原是取水道，越往深處，水聲越亂。", speaker_id, portrait_path),
		_l("若聽見有人喚你的名字，不要立刻答應。", speaker_id, portrait_path),
		_l("語魅？", liuyu_speaker_id, liuyu_portrait_path),
		_l("也可能是你自己。", speaker_id, portrait_path),
		_y("你沒有立刻回話。"),
		_y("你忽然想起《銀屏語》最後那片空白。"),
		_y("地下若真有聲音等著你，未必每一道聲音都該回答。"),
		_l("語塵。", speaker_id, portrait_path),
		_l("嗯？", liuyu_speaker_id, liuyu_portrait_path),
		_l("若你見到書眠，不要問她為什麼逃。", speaker_id, portrait_path),
		_l("那問什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("問她，還想不想回來。", speaker_id, portrait_path),
		_n("這句話落下時，茶坊裡的琴弦輕輕顫了一下。"),
		_n("像有人在很遠的地方，終於承認自己也害怕答案。"),
		_l("我明白了。", liuyu_speaker_id, liuyu_portrait_path),
		_n("主線更新：《濁渠尋蹤》"),
		_n("前往醉月茶坊後巷，尋找通往地下密道的井口。"),
	]


# ------------------------------------------------------------
# Interaction / Facing
# ------------------------------------------------------------
func _on_interaction_area_body_entered(body: Node) -> void:
	if body.name == "LiuYu":
		can_interact = true


func _on_interaction_area_body_exited(body: Node) -> void:
	if body.name == "LiuYu":
		can_interact = false


func face_towards(target_position: Vector2) -> void:
	if animated_sprite == null:
		return

	var dir := target_position - global_position
	if abs(dir.x) > abs(dir.y):
		animated_sprite.flip_h = dir.x < 0


# ------------------------------------------------------------
# Pending actions
# ------------------------------------------------------------
func _clear_pending_actions() -> void:
	_pending_flags_after_close.clear()


func _queue_flag(flag_name: String) -> void:
	if not _pending_flags_after_close.has(flag_name):
		_pending_flags_after_close.append(flag_name)


func _apply_pending_actions() -> void:
	for flag_name in _pending_flags_after_close:
		GlobalState.set_flag(flag_name, true)

	var button_already_received := GlobalState.get_flag(F_GOT_HALF_STRING_BUTTON)
	if not InventorySync.has_item(ITEM_HALF_STRING_BUTTON):
		InventorySync.add_item_stack(ITEM_HALF_STRING_BUTTON, 1, true)

	if button_already_received:
		return

	GlobalState.set_flag(F_GOT_HALF_STRING_BUTTON, true)
	GlobalState.set_flag(F_ZHUOQU_XUNZONG_STARTED, true)
	_advance_main_quest_after_button_grant()


func _advance_main_quest_after_button_grant() -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm == null:
		qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm == null or not qm.has_method("get_main_quest_state") or not qm.has_method("advance_main_quest"):
		push_warning("[紅徽音主線事件] 找不到正式 QuestManager，無法推進《濁渠尋蹤》。")
		return

	var main_state: Dictionary = qm.get_main_quest_state()
	if str(main_state.get("id", "")) != "main_001":
		push_warning("[紅徽音主線事件] 當前主線不是 main_001，未推進《濁渠尋蹤》。")
		return

	var current_stage := int(main_state.get("stage", 0))
	if current_stage >= QuestManager.STAGE_YH_SEWER_STARTED:
		return
	qm.advance_main_quest(
		QuestManager.STAGE_YH_SEWER_STARTED,
		"前往醉月茶坊後巷的廢井調查。"
	)


# ------------------------------------------------------------
# Dialog helpers
# ------------------------------------------------------------
## 角色發話：把「名稱：「」」直接寫進文字（姓名欄是停用的）。
## 紅徽音彈琴時不能開口，所有話都是琴音傳心；報出名字前稱「紅衣女伶」，之後才稱「紅徽音」。
func _l(text: String, speaker: int, portrait: String = "") -> Dictionary:
	var spoken := text
	if speaker == liuyu_speaker_id:
		spoken = "劉語塵：「%s」" % text
	elif speaker == unknown_speaker_id:
		spoken = "紅衣女伶：「（琴音）%s」" % text
	elif speaker == self.speaker_id:
		spoken = "紅徽音：「（琴音）%s」" % text
	return {
		"text": spoken,
		"speaker": speaker,
		"portrait": portrait if portrait != "" else empty_portrait_path,
	}


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": narration_speaker_id,
		"portrait": empty_portrait_path,
	}


## 第二人稱旁白（你覺得／你發現）與劉語塵的內心描述：用下方、劉語塵同側的對話框，不帶頭像。
func _y(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": liuyu_speaker_id,
		"portrait": empty_portrait_path,
	}
