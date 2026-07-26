# 醉月茶坊｜紅徽音主線專用角色腳本
# 掛載對象：醉月茶坊夜間場景中的紅徽音 CharacterBody2D。
# 觸發方式：玩家靠近紅徽音，按 Space 互動。
# 劇情功能：紅徽音初次完整對話 → 說明琴聲壓情與三人守護結構 → 委託調查書眠 → 取得半弦銅釦 → 開啟主線《濁渠尋蹤》。

extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/Huiyin/Huiyin_headshot.png"
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
var player: Node = null

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
	if not _is_first_talk_available():
		return
	if dialog_manager == null:
		return
	if dialog_manager.dialog_active:
		return
	if is_talking:
		return
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		return

	is_talking = true

	player = get_node_or_null("/root/GameRoot/LiuYu")
	if player:
		player.set("can_move", false)


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
	_apply_pending_actions()
	_clear_pending_actions()
	is_talking = false

	# 同一個紅徽音角色留在場景中；事件完成後只停用這次一次性主線互動。
	can_interact = false


# ------------------------------------------------------------
# 對話本體
# ------------------------------------------------------------
func _build_huiyin_first_talk_lines() -> Array:
	var lines: Array = []

	lines.append_array([
		_n("醉月茶坊內燈火低垂，客人稀少。"),
		_n("彈琴女伶仍坐於琴旁，琴弦在她指下微微震動。"),
		_n("她沒有立刻抬頭，像是剛剛那段弦外之音耗去了不少心力。"),
		_l("你來了。", unknown_speaker_id, portrait_path),
		_l("我聽見你了。", liuyu_speaker_id, liuyu_portrait_path),
		_n("彈琴女伶指尖仍按在琴弦上。"),
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
		_n("劉語塵想起《銀屏語》的封底空白。"),
		_n("那片空白不是未完，而是等待回聲。"),
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
	])

	if GlobalState.get_flag(F_DABAO_MAP_SHOWN):
		lines.append_array(_build_dabao_branch_lines())
	else:
		lines.append_array(_build_no_dabao_branch_lines())

	lines.append_array(_build_request_and_key_lines())
	return lines


func _build_dabao_branch_lines() -> Array:
	return [
		_l("有個孩子曾告訴我，他夢見井底有魚在哭。", liuyu_speaker_id, liuyu_portrait_path),
		_l("大寶？", speaker_id, portrait_path),
		_l("你知道他？", liuyu_speaker_id, liuyu_portrait_path),
		_l("那孩子的感知比大人乾淨。", speaker_id, portrait_path),
		_l("有些聲音，大人聽不見，動物聽得見。", speaker_id, portrait_path),
		_l("有些痛，大人不肯承認，孩子會先夢到。", speaker_id, portrait_path),
		_l("他用繩索告訴我，有一口井能通往下水道。", liuyu_speaker_id, liuyu_portrait_path),
		_n("紅徽音沉默。她的指尖無意識地按住一根琴弦，那根弦沒有響，卻像壓著一聲嘆息。"),
		_l("那口井，和我要告訴你的路，是同一條。", speaker_id, portrait_path),
		_l("同一條？", liuyu_speaker_id, liuyu_portrait_path),
		_l("密道只是它還乾淨時的名字。", speaker_id, portrait_path),
		_l("如今，它也是污染最深處的一道裂口。", speaker_id, portrait_path),
	]


func _build_no_dabao_branch_lines() -> Array:
	return [
		_l("你要我怎麼查？", liuyu_speaker_id, liuyu_portrait_path),
		_l("從地下。", speaker_id, portrait_path),
		_n("紅徽音望向茶坊後方。那裡隔著一扇小門，門外是後巷，井聲與水氣皆藏在夜裡。"),
		_l("醉月茶坊後方有一口舊井。", speaker_id, portrait_path),
		_l("外人只當那是廢井，其實是早年藥師取水與避火用的暗道。", speaker_id, portrait_path),
		_l("井下連著舊水道，其中一條支路，可以通往白箋居下方的地窖。", speaker_id, portrait_path),
	]


func _build_request_and_key_lines() -> Array:
	return [
		_l("你懷疑書眠夜裡會從那裡離開？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不是懷疑。", speaker_id, portrait_path),
		_l("我聽見過她的腳步。", speaker_id, portrait_path),
		_n("劉語塵看向紅徽音。"),
		_n("茶坊和白箋居隔著街，也隔著井下水聲。若連腳步都能聽見，聽見的便未必只是聲音。"),
		_l("她每次經過密道時，心音都太重。", speaker_id, portrait_path),
		_l("我想不聽見也難。", speaker_id, portrait_path),
		_l("為什麼不告訴左飲？", liuyu_speaker_id, liuyu_portrait_path),
		_l("左飲若知道，會直接介入。", speaker_id, portrait_path),
		_l("他習慣把事情斬斷。", speaker_id, portrait_path),
		_l("可書眠現在最怕的，就是被人當成必須立刻處理的異常。", speaker_id, portrait_path),
		_n("她說到這裡，聲音低了些。"),
		_n("那不是責備左飲，而是對三人如今各守一方、卻漸漸無法互相靠近的無奈。"),
		_l("你不是玉衡鎮的人。", speaker_id, portrait_path),
		_l("也不是左飲的人。", speaker_id, portrait_path),
		_l("你今日讀懂了她的空白，也替她擋過粗鄙之言。", speaker_id, portrait_path),
		_l("她不一定會對你說真話。", speaker_id, portrait_path),
		_l("但她至少不會立刻把你關在門外。", speaker_id, portrait_path),
		_l("你想要我調查書眠。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我想請你，先找到她到底把自己帶去了哪裡。", speaker_id, portrait_path),
		_l("如果她不想讓人知道呢？", liuyu_speaker_id, liuyu_portrait_path),
		_l("那就不要逼她。", speaker_id, portrait_path),
		_l("只要在她快走到回不了頭的地方以前，替她點一盞燈。", speaker_id, portrait_path),
		_l("我不是很會點燈的人。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你會拔劍。", speaker_id, portrait_path),
		_l("拔劍未必能救人。", liuyu_speaker_id, liuyu_portrait_path),
		_l("所以這一次，先別急著拔。", speaker_id, portrait_path),
		_l("先聽。", speaker_id, portrait_path),
		_n("紅徽音從琴旁取出一枚半月形銅釦。"),
		_n("銅釦邊緣刻著細細弦紋，映著燈火時，像半截未續完的月。"),
		_n("她沒有立刻遞出。"),
		_n("那一瞬間，劉語塵看得出來——這不是普通鑰匙。"),
		_l("拿著這個。", speaker_id, portrait_path),
		_l("這是？", liuyu_speaker_id, liuyu_portrait_path),
		_l("半弦銅釦。", speaker_id, portrait_path),
		_l("醉月茶坊舊物，也是通往井下的信物。", speaker_id, portrait_path),
		_l("你現在才交給我。", liuyu_speaker_id, liuyu_portrait_path),
		_l("因為今日以前，你只是聽見琴聲。", speaker_id, portrait_path),
		_l("現在，你聽見了弦外的話。", speaker_id, portrait_path),
		_n("銅釦落入掌心時，冰涼微震。"),
		_n("像有一根很細的弦，在他手裡應了一聲。"),
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
		_n("劉語塵沒有立刻回話。"),
		_n("他將半弦銅釦收入懷中，忽然想起《銀屏語》最後那片空白。"),
		_n("地下若真有聲音等著他，未必每一道聲音都該回答。"),
		_l("語塵。", speaker_id, portrait_path),
		_l("嗯？", liuyu_speaker_id, liuyu_portrait_path),
		_l("若你見到書眠，不要問她為什麼逃。", speaker_id, portrait_path),
		_l("那問什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("問她，還想不想回來。", speaker_id, portrait_path),
		_n("這句話落下時，茶坊裡的琴弦輕輕顫了一下。"),
		_n("像有人在很遠的地方，終於承認自己也害怕答案。"),
		_l("我明白了。", liuyu_speaker_id, liuyu_portrait_path),
		_n("半弦銅釦：醉月茶坊舊物，形似半枚月。邊緣刻有細弦紋，靠近井旁月紋石磚時，似乎會微微震動。"),
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
