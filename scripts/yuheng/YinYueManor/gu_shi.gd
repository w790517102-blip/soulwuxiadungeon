extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var speaker_id := 1
@export var liuyu_speaker_id := 2
@export var narration_speaker_id := 0
@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 60.0
@export var use_path_patrol := true
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var last_direction := Vector2.DOWN
var last_idle_direction := Vector2.DOWN
var is_talking: bool = false
var has_recently_talked: bool = false
var patrol_progress := 0.0
var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO

# 對話結束時才落旗，避免玩家還在讀對話時流程已被推進。
var _pending_flags_after_close: Array = []
var _pending_objective_after_close := ""
var _pending_remove_item_id := ""
var _pending_remove_item_amount := 0

# ------------------------------------------------------------
# 可依你現有專案調整的 ID / Flags
# ------------------------------------------------------------
const ITEM_LUNCHBOX := "item_gushi_lunchbox"

const F_LUNCHBOX_RECEIVED := "main_yh_lunchbox_received"
const F_LUNCHBOX_DELIVERED := "main_yh_lunchbox_delivered"

const F_GUSHI_STAGE_1_DONE := "main_yh_gushi_stage_1_done"
const F_GUSHI_STAGE_2_DONE := "main_yh_gushi_stage_2_done"
const F_GUSHI_STAGE_3_DONE := "main_yh_gushi_stage_3_done"

const F_GUSHI_REQUEST_REPORT_GRANDMA := "main_yh_gushi_request_report_grandma"
const F_GRANDMA_REPORTED := "main_yh_grandma_reported"
const F_MANOR_CLOSED := "main_yh_manor_closed"

# 支線 / 調查證據旗標
const F_MARKET_QIN_INVESTIGATED := "yh_market_qin_investigated"
const F_BEANS_COMPLETED := "yh_side_beans_completed"
const F_DABAO_MAP_SHOWN := "yh_side_dabao_map_shown"
const F_CHARCOAL_COMPLETED := "yh_side_charcoal_completed"


func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[顧石] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[顧石] PathFollow2D 沒有設定或找不到：" + str(path_node))

	previous_position = global_position
	dialog_lines = _build_lines_for_stage(_get_main_stage_safely())
	_clear_pending_actions()


# ------------------------------------------------------------
# 對話內容入口：沿用你原本的「依主線/旗標重建台詞」格式
# ------------------------------------------------------------
func _build_lines_for_stage(main_stage: int) -> Array:
	_clear_pending_actions()

	# ❶ 尚未取得阿婆便當：普通擋門
	if not GlobalState.get_flag(F_LUNCHBOX_RECEIVED) and not _has_item_safely(ITEM_LUNCHBOX):
		return _build_before_lunchbox_lines()

	# ❷ 已取得便當，但尚未交給顧石：送便當 + 第一層攻防
	if not GlobalState.get_flag(F_LUNCHBOX_DELIVERED):
		_queue_remove_item(ITEM_LUNCHBOX, 1)
		_queue_flag(F_LUNCHBOX_DELIVERED)
		_queue_flag(F_GUSHI_STAGE_1_DONE)
		_queue_objective("再次與顧石交談。")
		return _build_deliver_lunchbox_stage_1_lines()

	# ❸ 第二層攻防：求見理由 + 支線證據
	if not GlobalState.get_flag(F_GUSHI_STAGE_2_DONE):
		_queue_flag(F_GUSHI_STAGE_2_DONE)
		_queue_objective("再次與顧石交談。")
		return _build_stage_2_evidence_lines()

	# ❹ 第三層攻防：若山門不開，你怎麼辦？
	# 目前照你這份 gu_shi.gd 的格式先做「固定最佳回應版」。
	# 若之後要接 ChoiceBox，可把這段替換成分歧入口。
	if not GlobalState.get_flag(F_GUSHI_STAGE_3_DONE):
		_queue_flag(F_GUSHI_STAGE_3_DONE)
		_queue_flag(F_GUSHI_REQUEST_REPORT_GRANDMA)
		_queue_objective("回到竹林入口，向阿婆報平安。")
		return _build_stage_3_best_answer_lines()

	# ❺ 顧石已請託，但玩家尚未回報阿婆
	if GlobalState.get_flag(F_GUSHI_REQUEST_REPORT_GRANDMA) and not GlobalState.get_flag(F_GRANDMA_REPORTED):
		return _build_waiting_grandma_report_lines()

	# ❻ 已回報阿婆，返回山莊：閉莊
	if GlobalState.get_flag(F_GRANDMA_REPORTED) and not GlobalState.get_flag(F_MANOR_CLOSED):
		_queue_flag(F_MANOR_CLOSED)
		_queue_objective("飲月山莊暫時閉莊。回玉衡鎮尋找其他線索。")
		return _build_manor_closed_lines()

	# ❼ 主線後期：若你之後用 stage 控制「成為山莊客人」，保留這個口子
	if main_stage >= 6:
		return [
			_l("從現在起你是飲月山莊的客人。", speaker_id, portrait_path),
			_l("我不會攔住你了。", speaker_id, portrait_path),
		]

	# ❽ 閉莊後常駐
	return _build_after_manor_closed_lines()


func _build_before_lunchbox_lines() -> Array:
	return [
		_l("止步。飲月山莊不接無帖訪客。", speaker_id, portrait_path),
		_l("我想求見左飲。", liuyu_speaker_id, liuyu_portrait_path),
		_l("求見莊主者，須有莊主允准，或山莊信物。", speaker_id, portrait_path),
		_l("少俠若二者皆無，請勿在山門前久留。", speaker_id, portrait_path),
		_l("……知道了。", liuyu_speaker_id, liuyu_portrait_path),
	]


func _build_deliver_lunchbox_stage_1_lines() -> Array:
	return [
		_l("飲月山莊今日不接外客。少俠請回。", speaker_id, portrait_path),
		_l("我來送東西。", liuyu_speaker_id, liuyu_portrait_path),
		_l("送東西？", speaker_id, portrait_path),
		_n("劉語塵取出食盒，停在顧石槍尖之外。"),
		_l("竹林入口有位老太，托我將這便當送給她兒子。", liuyu_speaker_id, liuyu_portrait_path),
		_l("她說，他名喚顧石。", liuyu_speaker_id, liuyu_portrait_path),
		_n("顧石握槍的手微微一緊，又很快鬆開。"),
		_l("……我娘？", speaker_id, portrait_path),
		_l("她人在哪？", speaker_id, portrait_path),
		_l("樹下歇著。精神尚可，脾氣也尚可。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……看樣子她沒事。", speaker_id, portrait_path),
		_l("她還說，飯再忙也要吃，別真的把自己當石敢當。", liuyu_speaker_id, liuyu_portrait_path),
		_n("顧石沉默片刻，接過食盒。"),
		_l("家母多話，讓少俠見笑了。", speaker_id, portrait_path),
		_l("她走到竹林入口便睡著了。我怕她再往山路走，會出事。", liuyu_speaker_id, liuyu_portrait_path),
		_l("此事我記下了。多謝少俠。", speaker_id, portrait_path),
		_l("但便當已送到，少俠可以回了。", speaker_id, portrait_path),
		_l("我想求見左飲。", liuyu_speaker_id, liuyu_portrait_path),
		_l("果然。", speaker_id, portrait_path),
		_n("劉語塵眉頭微蹙。"),
		_l("果然……？", liuyu_speaker_id, liuyu_portrait_path),
		_l("今日想見莊主的人不少。", speaker_id, portrait_path),
		_l("今日想見左先生的人，已有三個。一個說自己是舊友之後，一個說身負血海深仇，一個說江湖同道不該見死不救。。", speaker_id, portrait_path),
		_l("不意外的,都被你請出去了是吧。", liuyu_speaker_id, liuyu_portrait_path),
		_l("(門衛聽後,不發一語)。", speaker_id, portrait_path),
		_l("少俠拿的是我母親的便當。", speaker_id, portrait_path),
		_l("...", liuyu_speaker_id, liuyu_portrait_path),
		_l("我不是拿她壓你。", liuyu_speaker_id, liuyu_portrait_path),
		_l("那便好。", speaker_id, portrait_path),
		_l("若是，少俠現在便可以下山了。", speaker_id, portrait_path),
		_l("這人不好糊弄。也對。冠冕堂皇的話，他恐怕聽得不少。", liuyu_speaker_id, liuyu_portrait_path),
		_l("(若再繞下去，只會被他當成尋常求見之人。也許直接攤牌，反而能讓他願意聽我說完。)", liuyu_speaker_id, liuyu_portrait_path),
		_l("我承認，得知你是山莊門衛後，我確實想過，這受令堂囑託便當或許能讓你願意聽我說幾句。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但囑託是囑託，求見是求見。我本就沒打算將兩件事混為一談。", liuyu_speaker_id, liuyu_portrait_path),
		_n("顧石看了他一眼。"),
		_l("少俠倒是直。", speaker_id, portrait_path),
		_l("說話再怎麼繞，也不可能讓我繞過你,進入飲月山莊。", liuyu_speaker_id, liuyu_portrait_path),
		_l("(顧石輕輕搖了頭笑了笑)", speaker_id, portrait_path),
		_l("若你方才說自己只是純粹好心，我反倒不信。", speaker_id, portrait_path),
		_n("(顧石似乎願意再聽你說幾句。)"),
	]


func _build_stage_2_evidence_lines() -> Array:
	var lines: Array = [
		_l("說吧。你為何要求見莊主？", speaker_id, portrait_path),
		_l("我有一樁江湖疑問，需向左飲請教。", liuyu_speaker_id, liuyu_portrait_path),
		_l("江湖疑問？", speaker_id, portrait_path),
		_l("是。", liuyu_speaker_id, liuyu_portrait_path),
		_l("少俠說得太輕。", speaker_id, portrait_path),
		_l("江湖上每日都有疑問。有人尋仇，有人尋親，有人尋名，也有人尋利。", speaker_id, portrait_path),
		_l("若人人有疑便能入山莊，這山門便不用守了。", speaker_id, portrait_path),
		_n("(劉語塵沉默片刻。)"),
		_l("(他問得很準。若只說私事，他不會讓路。)", liuyu_speaker_id, liuyu_portrait_path),
		_l("(但『那物』之事，現在還不能說。)", liuyu_speaker_id, liuyu_portrait_path),
		_l("少俠若不願明說，我也不便追問。", speaker_id, portrait_path),
		_l("只是如此一來，我也沒有替你通報的理由。", speaker_id, portrait_path),
		_l("我來玉衡鎮，本是為了私事。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但進鎮之後，我見到的事，已經不只是私事。", liuyu_speaker_id, liuyu_portrait_path),
		_l("玉衡鎮有異，這話我聽過太多遍。", speaker_id, portrait_path),
		_l("有人說琴聲太冷，有人說書眠不賣詩，有人說茶坊的茶喝了睡不安穩。", speaker_id, portrait_path),
		_l("少俠若只是來添一句『我也覺得奇怪』，還是不夠。", speaker_id, portrait_path),
		_l("我不是來添話。", liuyu_speaker_id, liuyu_portrait_path),
		_l("那你是來做什麼？", speaker_id, portrait_path),
		_l("確認。", liuyu_speaker_id, liuyu_portrait_path),
		_l("(顧石臉色一沉)確認什麼？", speaker_id, portrait_path),
		_l("確認這些異樣，是鎮民多心，還是有人正在讓他們不能多心。", liuyu_speaker_id, liuyu_portrait_path),
		_n("(顧石雙眼微微睜大,不經意地倒抽一口氣。"),
		_l("……這句話，是誰教你的？", speaker_id, portrait_path),
		_l("我自己看見的。", liuyu_speaker_id, liuyu_portrait_path),
	]

	lines.append_array(_build_evidence_detail_lines())

	lines.append_array([
		_l("他聽進去了。但還不夠。", liuyu_speaker_id, liuyu_portrait_path),
		_l("守門的人不只看理由，也看來者會不會壞規矩。", liuyu_speaker_id, liuyu_portrait_path),
		_l("少俠既然看出異樣，更該知道，此時山莊不宜讓外人隨意進出。", speaker_id, portrait_path),
		_n("顧石仍未答應通報。也許你需要證明自己不是會強闖山門之人。"),
	])
	return lines


func _build_evidence_detail_lines() -> Array:
	var lines: Array = []
	var evidence_count := _get_evidence_count()
	var has_qin := GlobalState.get_flag(F_MARKET_QIN_INVESTIGATED)

	if has_qin:
		lines.append_array([
			_l("我在市集聽過那陣琴聲。", liuyu_speaker_id, liuyu_portrait_path),
			_l("玉衡鎮人人都聽過。", speaker_id, portrait_path),
			_l("不一樣。", liuyu_speaker_id, liuyu_portrait_path),
			_l("我停下來聽時，心神像被什麼東西輕輕撥開。沒有慌亂，沒有痛苦，反倒很平靜。", liuyu_speaker_id, liuyu_portrait_path),
			_l("平靜到……差點忘了自己為何停下。", liuyu_speaker_id, liuyu_portrait_path),
			_n("顧石眉頭微動。"),
			_l("你想說什麼？", speaker_id, portrait_path),
			_l("你早上忘了帶便當。", liuyu_speaker_id, liuyu_portrait_path),
			_l("……", speaker_id, portrait_path),
			_l("你守山門多年，行事謹慎，連外人一句話都要反覆試探。", liuyu_speaker_id, liuyu_portrait_path),
			_l("這樣的人，為何會忘了吃飯這種小事？", liuyu_speaker_id, liuyu_portrait_path),
			_l("人總有疏漏。", speaker_id, portrait_path),
			_l("也許。", liuyu_speaker_id, liuyu_portrait_path),
			_l("但你難道沒想過，你忘記便當，也可能不是單純疏漏？", liuyu_speaker_id, liuyu_portrait_path),
		])

	# 高證據版：市集琴聲 + 至少兩個支線證據，讓顧石反思自己也受影響。
	if has_qin and evidence_count >= 3:
		lines.append_array([
			_l("婦人走到市集，忘了四季豆生熟。", liuyu_speaker_id, liuyu_portrait_path),
			_l("孩子想說井的位置，話到嘴邊卻說不出來。", liuyu_speaker_id, liuyu_portrait_path),
			_l("藥鋪煮藥的炭火，沾了邪典紙灰味。", liuyu_speaker_id, liuyu_portrait_path),
			_l("一件是偶然，兩件是巧合。", liuyu_speaker_id, liuyu_portrait_path),
			_l("若所有偶然都落在同一座鎮裡，就不是偶然。", liuyu_speaker_id, liuyu_portrait_path),
			_n("顧石手指不自覺按緊食盒提柄。"),
			_l("……我早上出門時，確實記得要帶便當。", speaker_id, portrait_path),
			_l("後來呢？", liuyu_speaker_id, liuyu_portrait_path),
			_l("後來聽見鎮口傳來琴聲。", speaker_id, portrait_path),
			_l("那聲音不近，卻很清楚。", speaker_id, portrait_path),
			_l("我只覺得今日山門要緊，旁的瑣事都可暫放。", speaker_id, portrait_path),
			_n("顧石低頭看向食盒。"),
			_l("可吃飯不是瑣事。", speaker_id, portrait_path),
			_l("對你母親來說，更不是。", liuyu_speaker_id, liuyu_portrait_path),
			_l("所以她才會走到竹林入口，累得睡著。", speaker_id, portrait_path),
			_l("我不是要你立刻信我。", liuyu_speaker_id, liuyu_portrait_path),
			_l("我只問你一句。", liuyu_speaker_id, liuyu_portrait_path),
			_l("問。", speaker_id, portrait_path),
			_l("你守的是山門，還是這座鎮假裝無事的樣子？", liuyu_speaker_id, liuyu_portrait_path),
			_n("顧石抬眼看他，眼神第一次不只是戒備。"),
			_l("少俠，這話很重。", speaker_id, portrait_path),
			_l("我知道。", liuyu_speaker_id, liuyu_portrait_path),
			_l("你是故意說給我聽的。", speaker_id, portrait_path),
			_l("是。", liuyu_speaker_id, liuyu_portrait_path),
			_l("你想讓我動搖。", speaker_id, portrait_path),
			_l("你若不曾在意玉衡鎮，這句話動搖不了你。", liuyu_speaker_id, liuyu_portrait_path),
		])
		return lines

	if GlobalState.get_flag(F_BEANS_COMPLETED):
		lines.append_array([
			_l("有位婦人，站在廣場時清清楚楚記得要買炸熟的四季豆。", liuyu_speaker_id, liuyu_portrait_path),
			_l("可一走到市集菜鋪前，琴聲一近，便連生熟都分不清。", liuyu_speaker_id, liuyu_portrait_path),
			_l("四季豆？", speaker_id, portrait_path),
			_l("生四季豆若未熟透，吃下去會傷人。", liuyu_speaker_id, liuyu_portrait_path),
			_l("她不是眼盲，也不是癡傻。她知道危險，只是到那裡便忘了。", liuyu_speaker_id, liuyu_portrait_path),
			_l("她至少還知道自己忘了。若有人忘了，卻連自己忘了都不知道呢？", liuyu_speaker_id, liuyu_portrait_path),
		])

	if GlobalState.get_flag(F_DABAO_MAP_SHOWN):
		lines.append_array([
			_l("還有一個孩子，說井底有魚精快受不了了。", liuyu_speaker_id, liuyu_portrait_path),
			_l("童言童語，不足為憑。", speaker_id, portrait_path),
			_l("若只是童言，我也不會放在心上。", liuyu_speaker_id, liuyu_portrait_path),
			_l("可我問他井在哪裡時，他明明想說，話卻像被什麼東西按住。", liuyu_speaker_id, liuyu_portrait_path),
			_l("最後只能用繩索在地上排出方位。", liuyu_speaker_id, liuyu_portrait_path),
			_l("用繩索？", speaker_id, portrait_path),
			_l("嘴說不出來，手卻還記得。", liuyu_speaker_id, liuyu_portrait_path),
			_l("這不像孩子胡鬧。倒像是有人不讓他把睡醒之後,好不容易記住的夢境景象完整的說出口。", liuyu_speaker_id, liuyu_portrait_path),
			_n("顧石神色一沉。"),
			_l("井……", speaker_id, portrait_path),
		])

	if GlobalState.get_flag(F_CHARCOAL_COMPLETED):
		lines.append_array([
			_l("另外...藥鋪煮藥的炭火，聞起來有紙灰味。", liuyu_speaker_id, liuyu_portrait_path),
			_l("紙灰？", speaker_id, portrait_path),
			_l("鎮上焚毀邪典，再將灰埋起來。這是你們的規矩吧？", liuyu_speaker_id, liuyu_portrait_path),
			_l("是。", speaker_id, portrait_path),
			_l("可若那灰不只在土裡，也到了炭火裡呢？", liuyu_speaker_id, liuyu_portrait_path),
			_l("若連藥湯都可能沾上穢氣，這鎮上的平靜，還能算平靜嗎？", liuyu_speaker_id, liuyu_portrait_path),
			_l("……此事你從何得知？", speaker_id, portrait_path),
			_l("藥鋪的小童聞出來的。", liuyu_speaker_id, liuyu_portrait_path),
			_l("孩子尚且知道藥不能沾穢。大人卻只顧著說鎮子無事。", liuyu_speaker_id, liuyu_portrait_path),
		])

	if evidence_count == 0:
		lines.append_array([
			_l("我看見鎮民說話時，常像忽然忘了自己原本要說什麼。", liuyu_speaker_id, liuyu_portrait_path),
			_l("不是害怕，也不是癡傻。", liuyu_speaker_id, liuyu_portrait_path),
			_l("像是有人把他們心裡該起的波瀾，輕輕按了下去。", liuyu_speaker_id, liuyu_portrait_path),
		])

	return lines


func _build_stage_3_best_answer_lines() -> Array:
	return [
		_l("我再問少俠一句。", speaker_id, portrait_path),
		_l("請說。", liuyu_speaker_id, liuyu_portrait_path),
		_l("若今日我不替你通報，你會如何？", speaker_id, portrait_path),
		_l("我會先下山，確認阿婆平安。", liuyu_speaker_id, liuyu_portrait_path),
		_n("顧石微微一怔。"),
		_l("你不是急著見莊主？", speaker_id, portrait_path),
		_l("急。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但她年紀大了，山路難走。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你既不能離開山門，那這句平安，我替你帶回去。", liuyu_speaker_id, liuyu_portrait_path),
		_n("顧石沉默良久。"),
		_l("少俠很會挑答案。", speaker_id, portrait_path),
		_l("我只是說該做的事。", liuyu_speaker_id, liuyu_portrait_path),
		_l("正因如此，才像答案。", speaker_id, portrait_path),
		_l("莊主是否願意見你，我不能保證。", speaker_id, portrait_path),
		_l("能通報便可。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但在我通報之前，請少俠先下山一趟。", speaker_id, portrait_path),
		_l("為何？", liuyu_speaker_id, liuyu_portrait_path),
		_l("替我向家母報平安。", speaker_id, portrait_path),
		_l("就說便當我收到了，飯也會吃。讓她別再上山。", speaker_id, portrait_path),
		_l("這也是試探？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不是。", speaker_id, portrait_path),
		_l("是請託。", speaker_id, portrait_path),
		_n("劉語塵看著顧石，點頭。"),
		_l("我會帶到。", liuyu_speaker_id, liuyu_portrait_path),
		_l("等少俠回來，我會給你答覆。", speaker_id, portrait_path),
		_n("主線目標更新：回到竹林入口，向阿婆報平安。"),
	]


func _build_waiting_grandma_report_lines() -> Array:
	return [
		_l("少俠，勞煩先替我向家母報平安。", speaker_id, portrait_path),
		_l("山路不穩，請她莫再上山。", speaker_id, portrait_path),
		_l("我會帶到。", liuyu_speaker_id, liuyu_portrait_path),
	]


func _build_manor_closed_lines() -> Array:
	var lines: Array = [
		_n("劉語塵回到山門。顧石已在門前等候。"),
		_l("少俠,你回來了。", speaker_id, portrait_path),
		_l("話已帶到。", liuyu_speaker_id, liuyu_portrait_path),
		_l("多謝。", speaker_id, portrait_path),
		_l("左飲願意見我嗎？", liuyu_speaker_id, liuyu_portrait_path),
		_l("(話剛說完,顧石臉色一沉,眼神略有閃爍,嘴裡欲言又止)", speaker_id, portrait_path),
		_l("...少俠來得不是時候。", speaker_id, portrait_path),
		_l("不是時候？", liuyu_speaker_id, liuyu_portrait_path),
		_l("莊主方才下令，飲月山莊暫時閉莊。", speaker_id, portrait_path),
		_l("閉莊期間，恕不見客。", speaker_id, portrait_path),
		_l("!?", liuyu_speaker_id, liuyu_portrait_path),
		_l("……閉莊？", liuyu_speaker_id, liuyu_portrait_path),
		_l("這話是什麼意思？左飲不願見我？", liuyu_speaker_id, liuyu_portrait_path),
		_l("少俠誤會了", speaker_id, portrait_path),
		_l("今日閉莊令乃左先生臨時動議,我守山門多年...也極少見莊主如此倉促下令。", speaker_id, portrait_path),
		_l("(一陣錯愕之後,你回過神來)所以你也不知道原因？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不知。", speaker_id, portrait_path),
		_l("(你握緊拳頭,沒好氣的說)你方才說，放錯一個人是失職，擋錯一個人也可能誤事。", liuyu_speaker_id, liuyu_portrait_path),
		_l("現在呢？", liuyu_speaker_id, liuyu_portrait_path),
		_n("顧石沉默。"),
		_l("...現在，我只能守門。", speaker_id, portrait_path),
	]

	if GlobalState.get_flag(F_MARKET_QIN_INVESTIGATED):
		lines.append_array([
			_l("……玉衡鎮的人壓了情，山莊的人關了門。", liuyu_speaker_id, liuyu_portrait_path),
			_l("這地方，像是什麼聲音響過以後，就少了些該有的東西。", liuyu_speaker_id, liuyu_portrait_path),
			_l("你說什麼？", speaker_id, portrait_path),
			_l("沒什麼。(你將頭撇過一邊,匆匆帶過))", liuyu_speaker_id, liuyu_portrait_path),
		])

	lines.append_array([
		_l("真有那麼巧，偏在我來訪時閉門？", liuyu_speaker_id, liuyu_portrait_path),
		_l("……飲月山莊無意戲弄你。", speaker_id, portrait_path),
		_l("我知道。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你方才通過試問，我本該帶你入莊。", speaker_id, portrait_path),
		_l("可莊主之令已下，我不能違。", speaker_id, portrait_path),
		_l("送便當是送便當，入莊是入莊。這本來一碼歸一碼。", liuyu_speaker_id, liuyu_portrait_path),
		_l("如今說閉莊又是閉莊,難道這也要我服?。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……嗯。", speaker_id, portrait_path),
		_l("(顧時略帶心虛,小聲地回答道))", speaker_id, portrait_path),
		_l("顧石，你這門守得真徹底。", liuyu_speaker_id, liuyu_portrait_path),
		_l("(顧石深吸一口氣後,恢復往常沉穩的聲音說)若有下次，我仍會替你通報。", speaker_id, portrait_path),
		_l("但不是今日,請少俠諒解。", speaker_id, portrait_path),
		_l("(沉默良久後,你開口了)我明白了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("少俠……", speaker_id, portrait_path),
		_l("不用道歉。你只是守門的人。", liuyu_speaker_id, liuyu_portrait_path),
		_l("可今日這門，連我也不知為何關上。", speaker_id, portrait_path),
		_l("那就更有意思了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你看起來不像覺得有意思。", speaker_id, portrait_path),
		_l("是啊。", liuyu_speaker_id, liuyu_portrait_path),
		_n("你聳了聳肩，苦笑了一下。"),
		_l("我只是習慣把失望說得像線索。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", speaker_id, portrait_path),
		_l("告辭。", liuyu_speaker_id, liuyu_portrait_path),
		_l("若山莊再開，我會記得今日之事。", speaker_id, portrait_path),
		_l("那就別再忘了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("忘什麼？", speaker_id, portrait_path),
		_l("飯。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……不會了。", speaker_id, portrait_path),
		_n("劉語塵沿著竹林山道往下走。香包的氣味混著竹葉的濕氣，在衣襟旁輕輕晃動。"),
		_n("方才幾乎打開的山門，此刻仍在身後閉著。"),
		_n("他沒有回頭，只是步子比來時慢了些。"),
		_n("主線更新：飲月山莊暫時閉莊，暫無法見到左飲。返回玉衡鎮，尋找新的線索。"),
	])

	return lines


func _build_after_manor_closed_lines() -> Array:
	return [
		_l("飲月山莊閉莊期間，恕不見客。", speaker_id, portrait_path),
		_l("少俠，鎮上的事若另有進展，還請多加小心。", speaker_id, portrait_path),
		_l("你也一樣。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我會守好這道門。", speaker_id, portrait_path),
		_l("也別忘了吃飯。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……記下了。", speaker_id, portrait_path),
	]


# ------------------------------------------------------------
# Dialog line helper：沿用你現在的 Dictionary 格式
# ------------------------------------------------------------
func _l(text: String, speaker = 1, portrait = "") -> Dictionary:
	return {
		"text": "「%s」" % text,
		"speaker": speaker,
		"portrait": portrait,
	}


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": narration_speaker_id,
		"portrait": "",
	}


func _get_evidence_count() -> int:
	var count := 0
	if GlobalState.get_flag(F_MARKET_QIN_INVESTIGATED):
		count += 1
	if GlobalState.get_flag(F_BEANS_COMPLETED):
		count += 1
	if GlobalState.get_flag(F_DABAO_MAP_SHOWN):
		count += 1
	if GlobalState.get_flag(F_CHARCOAL_COMPLETED):
		count += 1
	return count


# ------------------------------------------------------------
# Pending actions：對話結束時執行
# ------------------------------------------------------------
func _clear_pending_actions() -> void:
	_pending_flags_after_close.clear()
	_pending_objective_after_close = ""
	_pending_remove_item_id = ""
	_pending_remove_item_amount = 0


func _queue_flag(flag_name: String) -> void:
	if not _pending_flags_after_close.has(flag_name):
		_pending_flags_after_close.append(flag_name)


func _queue_objective(text: String) -> void:
	_pending_objective_after_close = text


func _queue_remove_item(item_id: String, amount: int = 1) -> void:
	_pending_remove_item_id = item_id
	_pending_remove_item_amount = amount


func _apply_pending_actions() -> void:
	for flag_name in _pending_flags_after_close:
		GlobalState.set_flag(flag_name, true)

	if _pending_remove_item_id != "" and _pending_remove_item_amount > 0:
		_remove_item_safely(_pending_remove_item_id, _pending_remove_item_amount)

	if _pending_objective_after_close != "":
		_set_main_objective_safely(_pending_objective_after_close)

	_clear_pending_actions()


func _has_item_safely(item_id: String) -> bool:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("has_item"):
		return inv.has_item(item_id)

	inv = get_node_or_null("/root/GameRoot/InventoryManager")
	if inv and inv.has_method("has_item"):
		return inv.has_item(item_id)

	# 若專案目前還沒有 InventoryManager，至少不讓顧石腳本報錯。
	return false


func _remove_item_safely(item_id: String, amount: int = 1) -> void:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("remove_item"):
		inv.remove_item(item_id, amount)
		return

	inv = get_node_or_null("/root/GameRoot/InventoryManager")
	if inv and inv.has_method("remove_item"):
		inv.remove_item(item_id, amount)


func _set_main_objective_safely(text: String) -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)
		return

	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)


# ------------------------------------------------------------
# 原本的移動 / 互動邏輯：盡量保留你的格式
# ------------------------------------------------------------
func _process(delta):
	z_index = int(global_position.y + z_index_offset)


func _play_directional_anim(dir: Vector2):
	if dir.length() < 0.1:
		return
	last_direction = dir
	var anim_name = _get_anim_by_vector(dir, "walk")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		animated_sprite.play("idle_down")


func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle = dir.angle()
	if angle >= -PI * 7/8 and angle < -PI * 5/8:
		return "%s_left_up" % prefix
	elif angle >= -PI * 5/8 and angle < -PI * 3/8:
		return "%s_up" % prefix
	elif angle >= -PI * 3/8 and angle < -PI * 1/8:
		return "%s_right_up" % prefix
	elif angle >= -PI * 1/8 and angle < PI * 1/8:
		return "%s_right" % prefix
	elif angle >= PI * 1/8 and angle < PI * 3/8:
		return "%s_right_down" % prefix
	elif angle >= PI * 3/8 and angle < PI * 5/8:
		return "%s_down" % prefix
	elif angle >= PI * 5/8 and angle < PI * 7/8:
		return "%s_left_down" % prefix
	else:
		return "%s_left" % prefix


func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	var anim_name = _get_anim_by_vector(direction, "idle")
	if $AnimatedSprite2D.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
		animated_sprite.play("idle_left_down")


func _unhandled_input(event):
	if not can_interact:
		return
	if dialog_manager == null:
		return
	if dialog_manager.dialog_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true

		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)

		# 在互動瞬間依目前旗標/主線重新組台詞。
		var main_stage := _get_main_stage_safely()
		dialog_lines = _build_lines_for_stage(main_stage)

		dialog_manager.show_dialog_sequence(dialog_lines, self)


func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	_apply_pending_actions()
	dialog_lines = _build_lines_for_stage(_get_main_stage_safely())
	_clear_pending_actions()
	animated_sprite.play("idle_left_down")


func _get_main_stage_safely() -> int:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s: Dictionary = qm.get_main_quest_state()
		return int(s.get("stage", 1))

	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s2: Dictionary = qm.get_main_quest_state()
		return int(s2.get("stage", 1))

	return 1
