extends RefCounted
## 醉月茶坊掌櫃（boss）與店小二（servant）的「時序台詞」：夜晚七格、05（舊水道與山莊會談之後的白天）、06（《白鳶橫天》奏響後）。
## 台詞來源：共邊國〈醉月茶坊正式台詞與旗標修正交接信〉。NPC 台詞統一寫成「名稱：「對白」」（對話框的姓名欄是停用的，名字要寫在文字裡）。
##
## 劇情時空標籤（不等於 QuestManager 的 stage）。優先權：06 > 05 > 04 > 更早期的一般茶坊對話。
##   04：夜訪紅徽音、取得半弦銅釦（旗標 F_HUIYIN_FIRST_TALK_DONE／F_GOT_HALF_STRING_BUTTON）。
##   （銅釦後、會談前的白天不是正常流程：夜晚地圖是封閉的，只能經 鐘乳石洞 → 山莊夜晚會談 → 留宿 → 翌日白天，所以不設專屬台詞。）
##   05：舊水道事件解決、飲月山莊四人會談完成（旗標 event_yin_yue_night_meeting_done，由 yin_yue_manor_room(night) 落旗）。
##   06：紅徽音「實際奏響」《白鳶橫天》新心譜（旗標 F_BAIYUAN_PLAYED）。
## 【F_BAIYUAN_PLAYED 目前沒有任何流程會落旗】只有這裡讀它；等新譜奏響的正式演出寫好後，由那段演出在結束時落旗，06 台詞才會出現。
## 不可以拿「取得琴譜」「烈風寨開始」「舊水道解決」「拿到銅釦」或主線 stage 數字來代替。
##
## 夜晚七格由三個條件決定：白天有沒有跟他說過話（day_met）／夜晚有沒有（night_met）／拿到半弦銅釦了沒（button）。
## 拿銅釦以前，夜晚只有「紅徽音第一次對話之前」這一段（window）；拿了銅釦以後，夜晚再來就是回訪。
## 白天有沒有說過話：各自的 *_day 旗標；舊存檔沒有這個旗標時，退回原本的 met_ 旗標（當時）。夜晚說過話：*_night 旗標。

const NIGHT_TEASHOP_SCENE_PATH := "res://scenes/yuheng/zueyue_teashop/zueyue_teashop_night.tscn"
const F_GO_TO_ZUIYUE_HUIYIN := "main_yh_go_to_zuiyue_huiyin"
const F_HUIYIN_FIRST_TALK_DONE := "event_huiyin_first_talk_done"
const F_GOT_HALF_STRING_BUTTON := "main_yh_got_half_string_copper_button"
const F_NIGHT_MEETING_DONE := "event_yin_yue_night_meeting_done"
const F_BAIYUAN_PLAYED := "event_baiyuan_hengtian_played"

const MET_FLAGS := {
	"boss": "met_yuheng_teahouse_boss",
	"servant": "met_yuheng_teahouse_servant",
}
const DAY_FLAGS := {
	"boss": "met_teahouse_boss_day",
	"servant": "met_teahouse_servant_day",
}
const NIGHT_FLAGS := {
	"boss": "met_teahouse_boss_night",
	"servant": "met_teahouse_servant_night",
}
## 06 的「新曲奏響後」第一組已經聽過；之後改播循環組。
const HEARD_06_FLAGS := {
	"boss": "teahouse_boss_06_heard",
	"servant": "teahouse_servant_06_heard",
}
const NAMES := {
	"boss": "掌櫃",
	"servant": "店小二",
}


static func is_night_scene(npc: Node) -> bool:
	var scene_root := npc.get_parent() if npc != null else null
	return scene_root != null and scene_root.scene_file_path == NIGHT_TEASHOP_SCENE_PATH


static func has_met_in_day(key: String) -> bool:
	if GlobalState.get_flag(String(DAY_FLAGS[key])):
		return true
	# 舊存檔：沒有分日夜的旗標時，原本的 met_ 旗標且夜晚還沒說過，就當作白天說過
	return GlobalState.get_flag(String(MET_FLAGS[key])) and not GlobalState.get_flag(String(NIGHT_FLAGS[key]))


static func has_met_at_night(key: String) -> bool:
	return GlobalState.get_flag(String(NIGHT_FLAGS[key]))


## 06：新心譜已經實際奏響
static func is_stage_06() -> bool:
	return GlobalState.get_flag(F_BAIYUAN_PLAYED)


## 05：舊水道事件與山莊會談都完成了，但新曲還沒奏響
static func is_stage_05() -> bool:
	return GlobalState.get_flag(F_NIGHT_MEETING_DONE) and not is_stage_06()


## 對話結束後呼叫：依現在所在的場景落「白天／夜晚說過話」旗標；06 的第一組聽過就記下來。
static func mark_talked(key: String, npc: Node) -> void:
	if is_night_scene(npc):
		GlobalState.set_flag(String(NIGHT_FLAGS[key]), true)
		return
	GlobalState.set_flag(String(DAY_FLAGS[key]), true)
	if is_stage_06():
		GlobalState.set_flag(String(HEARD_06_FLAGS[key]), true)


## 夜晚茶坊該說的對白；不是夜晚場景、或夜晚場景裡還輪不到夜晚對白（例如主線還沒到紅徽音）就回空陣列，由呼叫端用原本的邏輯。
## reunion_lines：拿銅釦以前、白天已經說過話的重逢對白（第 2 格，各角色自己的版本）。
static func lines_for(key: String, npc: Node, speaker_id: int, portrait: String, reunion_lines: Array) -> Array:
	if not is_night_scene(npc):
		return []
	var day_met := has_met_in_day(key)
	var night_met := has_met_at_night(key)
	var window: bool = GlobalState.get_flag(F_GO_TO_ZUIYUE_HUIYIN) and not GlobalState.get_flag(F_HUIYIN_FIRST_TALK_DONE)
	var button: bool = GlobalState.get_flag(F_GOT_HALF_STRING_BUTTON)
	if window and not button:
		if night_met:
			return _repeat_before_button(key, speaker_id, portrait)
		if day_met:
			return reunion_lines
		return _first_meeting_at_night(key, speaker_id, portrait)
	if button:
		return _after_button(key, day_met, night_met, speaker_id, portrait)
	return []


## 白天茶坊在 05／06 該說的對白；還沒到 05 就回空陣列，由呼叫端用原本（早期／階段）的邏輯。夜晚場景一律回空陣列。
static func day_lines_for(key: String, npc: Node, speaker_id: int, portrait: String) -> Array:
	if is_night_scene(npc):
		return []
	if is_stage_06():
		return _stage_06(key, GlobalState.get_flag(String(HEARD_06_FLAGS[key])), speaker_id, portrait)
	if is_stage_05():
		return _stage_05(key, has_met_in_day(key) or has_met_at_night(key), speaker_id, portrait)
	return []


## 把一組純文字包成「名稱：「對白」」的對話列；第一句帶頭像。
static func _say(key: String, texts: Array, s: int, p: String) -> Array:
	var out: Array = []
	for i in texts.size():
		var line := {"text": "%s：「%s」" % [NAMES[key], texts[i]], "speaker": s}
		if i == 0 and p != "":
			line["portrait"] = p
		out.append(line)
	return out


## 第 1 格｜白天沒說過、夜晚第一次、銅釦前：初次見面的語氣（不能像是早就認識）
static func _first_meeting_at_night(key: String, s: int, p: String) -> Array:
	if key == "boss":
		return _say(key, [
			"客倌，頭一回光臨？夜裡還有座。",
			"怪了……我竟提前溫了這盞茶。",
			"明明不識您，卻像早就在等人。",
		], s, p)
	return _say(key, [
		"客倌裡邊坐！咦，頭回見您哪。",
		"小的怎麼先擺好您那份茶盞？",
		"莫不是忙昏頭……咳，怪了。",
	], s, p)


## 第 3 格｜夜晚已說過、銅釦前：簡短循環（不分白天有沒有說過）
static func _repeat_before_button(key: String, s: int, p: String) -> Array:
	if key == "boss":
		return _say(key, [
			"客倌若還坐得住，茶便替您溫著。",
			"這琴聲……夜深了，也未曾歇。",
		], s, p)
	return _say(key, [
		"茶還熱著，小的再添半盞？",
		"咳……話說大聲了，又卡嗓子。",
	], s, p)


## 第 4～7 格｜拿到半弦銅釦以後回到夜晚茶坊：依「白天／夜晚有沒有說過話」四種
static func _after_button(key: String, day_met: bool, night_met: bool, s: int, p: String) -> Array:
	if key == "boss":
		if not day_met and not night_met:
			return _say(key, [
				"客倌，方才見您一進門便往琴案去，我還沒來得及招呼。",
				"那位姑娘平日少與客人往來，今夜倒是難得。",
				"江湖上的事，我不多問。客倌若要歇腳，夜茶仍有。",
			], s, p)
		if day_met and not night_met:
			return _say(key, [
				"客倌，白日才見過，今夜又來了。",
				"方才見您與那位姑娘相望許久，倒是少見。",
				"我不多問。茶若想喝，還溫著。",
			], s, p)
		if not day_met and night_met:
			return _say(key, [
				"客倌又來坐坐？這夜還長。",
				"茶若涼了，我再替您換一盞。",
				"別見怪，今夜總有些心神不寧。",
			], s, p)
		return _say(key, [
			"客倌，今晚又來坐了。",
			"喝茶便喝茶，不必急著說什麼。",
			"琴聲未歇，我也還守著這盞燈。",
		], s, p)
	if not day_met and not night_met:
		return _say(key, [
			"客倌！方才見您直往琴案去，小的還以為出了什麼事。",
			"那位姑娘竟抬眼瞧您，還遞了件東西……",
			"咳！小的多嘴。您要喝茶嗎？",
		], s, p)
	if day_met and not night_met:
		return _say(key, [
			"客倌！白日才招呼過您，方才怎麼一進門就往琴案去了？",
			"那位姑娘竟還遞了件東西給您。嘿，小的可什麼都沒問！",
			"咳……又說快了。客倌要添茶嗎？",
		], s, p)
	if not day_met and night_met:
		return _say(key, [
			"又見著您啦，客倌！",
			"小的方才想說句什麼來著……",
			"欸，讓琴音一攪，又給忘了。",
		], s, p)
	return _say(key, [
		"客倌今日來得可勤哪！",
		"小的這茶壺都快認得您了。",
		"嘿嘿……咦，我又話多了。",
	], s, p)


## 05｜舊水道事件與山莊會談之後，翌日白天：兩人都記得昨夜看見的事（目擊與交談是兩回事），但琴聲還沒變。
static func _stage_05(key: String, talked_before: bool, s: int, p: String) -> Array:
	if key == "boss":
		if talked_before:
			return _say(key, [
				"客倌，昨夜您來得匆忙，連茶也沒點。",
				"我見那位姑娘騰出一隻手，遞了件小東西給您。",
				"江湖上的事，我不多問。今早的茶，仍替您溫著。",
			], s, p)
		return _say(key, [
			"客倌，昨夜我見您進來，直往琴案去了。",
			"那位姑娘還遞了件東西給您。倒是少見。",
			"昨日沒能招呼，今日喝盞茶再走吧。",
		], s, p)
	if talked_before:
		return _say(key, [
			"客倌！昨夜您往琴師面前一站，小的都忘了招呼。",
			"兩人半句話都沒說，她倒遞了件東西給您！",
			"小的本來還想問……咳，算了，先添茶！",
		], s, p)
	return _say(key, [
		"啊！您不是昨夜那位佩劍的客倌嗎？",
		"小的見您直奔琴案，還以為出了什麼事。",
		"咳，說這麼多做甚！客倌要喝茶嗎？",
	], s, p)


## 06｜《白鳶橫天》實際奏響之後：琴聲改變，鎮民開始重新表達喜好。first_done：第一組已聽過，改播循環組。
static func _stage_06(key: String, first_done: bool, s: int, p: String) -> Array:
	if key == "boss":
		if first_done:
			return _say(key, [
				"女伶近日奏了別的曲，客人也不像從前那樣好同一品淡茶。",
				"現在所有人都願意嘗試不同茶品了！",
			], s, p)
		return _say(key, [
			"近日女伶彈奏的曲調似乎有些不同。",
			"聽得比先前更加通暢、如沐春風。",
		], s, p)
	if first_done:
		return _say(key, [
			"客倌！想喝什麼儘管說，店內茶品五花八門，不怕你叫！",
			"前陣子流行『醉月青魁』，現在無論什麼濃淡溫涼，大家什麼茶都喝！",
		], s, p)
	return _say(key, [
		"（聲音宏亮）客倌！裡面坐喲！想喝什麼儘管說嘿！",
		"女伶換了首曲，聽著聽著嗓子也不啞了呢！",
	], s, p)


## 05｜紅徽音在翌日白天的重訪演出。完整版只播一次（落 F_HUIYIN_REVISIT_05_SEEN），之後播精簡循環。
## 劉語塵幾乎不開口：情緒靠旁白帶出（speaker 0、無頭像），紅徽音用琴音傳心。
const F_HUIYIN_REVISIT_05_SEEN := "event_huiyin_revisit_05_seen"


static func _n(text: String, empty_portrait: String) -> Dictionary:
	return {"text": text, "speaker": 0, "portrait": empty_portrait}


static func _hong(text: String, speaker_id: int, portrait: String) -> Dictionary:
	return {"text": "紅徽音：「（琴音）%s」" % text, "speaker": speaker_id, "portrait": portrait}


static func huiyin_revisit_full(speaker_id: int, portrait: String, empty_portrait: String) -> Array:
	return [
		_n("晨光穿過窗櫺，落在茶坊幾張空桌上。", empty_portrait),
		_n("你循著熟悉的琴聲走進醉月茶坊。昨夜舊水道中的種種遭遇，至今仍歷歷在目。", empty_portrait),
		_n("琴案前，紅徽音依舊一襲紅衣，端坐如故。", empty_portrait),
		_n("她眉宇間藏著未曾消散的倦意，十指卻仍穩穩撫過琴弦。曲調不曾錯亂，彷彿昨夜什麼都未曾發生。", empty_portrait),
		_n("你在琴案旁停下腳步。", empty_portrait),
		_n("紅徽音抬眼望了你一眼，指下琴聲未歇。", empty_portrait),
		_hong("少俠是擔心我？", speaker_id, portrait),
		_n("你沒有否認，只輕輕點了點頭。", empty_portrait),
		_hong("不妨事。這琴，還不能停。", speaker_id, portrait),
		_n("她垂下眼簾，將指尖移向下一根琴弦。", empty_portrait),
		_hong("我早知道，這琴壓住的不只有語魅。", speaker_id, portrait),
		_hong("可直到昨夜，才真正看清，我們守住了多少，又讓多少話沉在了水底。", speaker_id, portrait),
		_n("你沒有急著接話。", empty_portrait),
		_n("琴聲依舊平穩，與昨日聽來並無二致。", empty_portrait),
		_n("只是望著她那雙不曾停歇的手，你漸漸明白，她並非不願停下，而是此刻還沒有停下的餘地。", empty_portrait),
		_hong("少俠不必為我掛心。", speaker_id, portrait),
		_hong("若真有餘力，便替我多聽聽那些尚未說出口的話吧。", speaker_id, portrait),
		_n("你向她略一頷首，沒有再打擾。", empty_portrait),
		_n("琴聲仍在身後緩緩流轉。", empty_portrait),
		_n("今日的醉月茶坊，與昨日似乎毫無分別。", empty_portrait),
		_n("但你知道，有些事情已經不同了。", empty_portrait),
	]


static func huiyin_revisit_loop(speaker_id: int, portrait: String, empty_portrait: String) -> Array:
	return [
		_n("你走近琴案，紅徽音並未停下指間的曲調。", empty_portrait),
		_n("她向你微微頷首，似乎已不必再問來意。", empty_portrait),
		_hong("少俠，又來聽琴了。", speaker_id, portrait),
		_hong("此曲尚不能停。不過，總有一天，該讓它換一種奏法。", speaker_id, portrait),
		_n("你在旁聽了片刻，便悄然退開。", empty_portrait),
	]


const LIUYU_PORTRAIT := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"


static func _liu(text: String) -> Dictionary:
	return {"text": "劉語塵：「%s」" % text, "speaker": 2, "portrait": LIUYU_PORTRAIT}


## 夜晚 04：銅釦到手之後再走近琴案（正式定稿）。
static func huiyin_revisit_04(speaker_id: int, portrait: String, empty_portrait: String) -> Array:
	return [
		_n("你再次走近琴案。", empty_portrait),
		_n("紅徽音仍專心撫琴，見你折返，微微抬眼。", empty_portrait),
		_hong("拜託你了，少俠。", speaker_id, portrait),
	]


## 夜晚沒有 05、06：會談完成後劇情直接切到翌日白天，玩家回不到同一晚的茶坊。
## 若因異常旗標／測試模式／場景直入而在夜晚碰到這個狀態，只給一行不含劇情資訊的旁白（安全處理，不建立新劇情）。
static func huiyin_revisit_abnormal_night(empty_portrait: String) -> Array:
	return [_n("你走近琴案，紅徽音專心撫琴，指下琴聲未歇。", empty_portrait)]


## 【待確認・概念預覽，非正式驗收文本】06 紅徽音專屬重訪；先保留 event_baiyuan_hengtian_played 的路由，正式劇情確認後再換文字。
static func huiyin_revisit_06(speaker_id: int, portrait: String, empty_portrait: String) -> Array:
	return [
		_n("你再次聽見琴聲。這一次，曲調已不再是往日的模樣。", empty_portrait),
		_hong("這一次，我想讓他們自己選擇。", speaker_id, portrait),
		_liu("（欣慰）這支曲子，終於不一樣了。"),
	]
