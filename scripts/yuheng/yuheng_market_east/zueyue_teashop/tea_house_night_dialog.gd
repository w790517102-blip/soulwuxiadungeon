extends RefCounted
## 【待辦・等台詞規格統一】下面第 1、3～7 格的台詞是占位，正式版要等「統一台詞撰寫規格」的大工程完成後才寫
## （需求表：docs/tea_house_dialog_brief.md）。同一批要等的還有紅徽音交出半弦銅釦之後的台詞。規格改了，這裡的資料格式也要跟著調。
##
## 醉月茶坊掌櫃（boss）與店小二（servant）在「夜晚茶坊」的對白。
##
## 三個條件決定說甚麼（共 2×2×2 = 8 種）：
##   白天有沒有跟他說過話（day_met）／夜晚有沒有跟他說過話（night_met）／拿到半弦銅釦了沒（button）。
## 拿銅釦以前，夜晚只有「紅徽音第一次對話之前」這一段（window）；拿了銅釦以後，夜晚再來就是回訪。
##
## 白天有沒有說過話：各自的 *_day 旗標；舊存檔沒有這個旗標時，退回原本的 met_ 旗標（當時白天夜晚共用）。
## 夜晚說過話：*_night 旗標，每次在夜晚場景對話結束後落旗。
##
## 白天茶坊拿了銅釦以後的對白、以及「烈風寨事件解決後客人都願意嘗試不同茶品」那段，不在這個檔案（白天腳本自己管）。

const NIGHT_TEASHOP_SCENE_PATH := "res://scenes/yuheng/zueyue_teashop/zueyue_teashop_night.tscn"
const F_GO_TO_ZUIYUE_HUIYIN := "main_yh_go_to_zuiyue_huiyin"
const F_HUIYIN_FIRST_TALK_DONE := "event_huiyin_first_talk_done"
const F_GOT_HALF_STRING_BUTTON := "main_yh_got_half_string_copper_button"

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


## 對話結束後呼叫：依現在所在的場景落「白天／夜晚說過話」旗標。
static func mark_talked(key: String, npc: Node) -> void:
	GlobalState.set_flag(String(NIGHT_FLAGS[key]) if is_night_scene(npc) else String(DAY_FLAGS[key]), true)


## 夜晚茶坊該說的對白；不是夜晚場景、或夜晚場景裡還輪不到夜晚對白（例如主線還沒到紅徽音）就回空陣列，由呼叫端用原本的邏輯。
## reunion_lines：拿銅釦以前、白天已經說過話的重逢對白（原本就有的那一組，各角色自己的版本）。
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


static func _l(text: String, speaker_id: int, portrait: String = "") -> Dictionary:
	var line := {"text": text, "speaker": speaker_id}
	if portrait != "":
		line["portrait"] = portrait
	return line


## 白天沒說過、夜晚第一次：初次見面的語氣（不能像是早就認識）
static func _first_meeting_at_night(key: String, s: int, p: String) -> Array:
	if key == "boss":
		return [
			_l("「客倌，夜裡才上門的客人，小店還是頭一回見。」", s, p),
			_l("「說來也怪，今夜琴聲一起，我心裡便空出一個位子，像是有人該來似的。」", s),
			_l("「您就是那位客倌吧？我說不上緣由，只覺得該替您留盞燈。」", s),
			_l("「茶坊裡的事，我只管茶與座。琴聲裡的事……您不妨去問那位撫琴的姑娘。」", s),
		]
	return [
		_l("「客倌請裡坐——咦，夜裡來的客人，小的還是頭一回伺候。」", s, p),
		_l("「說來好笑，今夜添水擺盞時，我總不自覺多留了一副茶具。」", s),
		_l("「方才琴聲一響，腦中便晃過一個佩劍進門的身影，如今竟與您對上了。」", s),
		_l("「您別笑我，這話連小的自己都覺得玄。」", s),
	]


## 拿銅釦以前、夜晚已經說過一次：簡短循環
static func _repeat_before_button(key: String, s: int, p: String) -> Array:
	if key == "boss":
		return [
			_l("「燈還亮著，茶也溫著，客倌慢坐。」", s, p),
			_l("「那位撫琴的姑娘就在那頭，有話，您親自去同她說罷。」", s),
		]
	return [
		_l("「客倌，那副多留的茶具還給您擱著呢。」", s, p),
		_l("「撫琴的姑娘就在那頭，您去看看罷。」", s),
	]


## 拿到半弦銅釦以後回到夜晚茶坊：依「白天／夜晚有沒有說過話」四種
static func _after_button(key: String, day_met: bool, night_met: bool, s: int, p: String) -> Array:
	if key == "boss":
		if not day_met and not night_met:
			return [
				_l("「客倌夜裡才來？小店白日也有茶，下回可以早些。」", s, p),
				_l("「見您從那位姑娘那頭過來，神色比進門時沉了些。」", s),
				_l("「坊裡的規矩不變：茶是茶，琴是琴，各管各的。」", s),
				_l("「客倌要往哪兒去，掌櫃的我不問；只是夜路難走，茶先喝一盞再說。」", s),
			]
		if day_met and not night_met:
			return [
				_l("「客倌今夜又來了，這回神色和白日不大一樣。」", s, p),
				_l("「方才那位姑娘同您說了些甚麼，掌櫃的我不打聽。」", s),
				_l("「只是夜路難走，喝盞茶再去，總不吃虧。」", s),
			]
		if not day_met and night_met:
			return [
				_l("「客倌回來了。」", s, p),
				_l("「方才您進門時，我說得沒頭沒腦的。如今見您辦完事回來，倒覺得先前那點預感沒有白生。」", s),
				_l("「往後夜裡要走動，小店的燈會替您留著。」", s),
			]
		return [
			_l("「客倌又回來了。日裡見過，夜裡也見過，咱們算是熟客了。」", s, p),
			_l("「那位姑娘既已同您說上了話，往後的路，掌櫃的我只能說：茶坊的燈夜夜都亮。」", s),
			_l("「出門前，喝一盞再走吧。」", s),
		]
	if not day_met and not night_met:
		return [
			_l("「客倌夜裡才來？小的白日當差、夜裡添水，您可算見著小的這副睡眼了。」", s, p),
			_l("「聽說夜裡的琴聲，比白日還要靜些。」", s),
			_l("「您要出門的話，小的給您添壺熱茶，路上暖手。」", s),
		]
	if day_met and not night_met:
		return [
			_l("「客倌又來啦，白日見過一回，夜裡這回，您腳步都不一樣了。」", s, p),
			_l("「小的嘴笨，不會說話，只覺得您像是揣著事兒。」", s),
			_l("「來，添壺熱茶，路上暖手。」", s),
		]
	if not day_met and night_met:
		return [
			_l("「客倌回來啦！先前多留的那副茶具，今夜算是派上用場了。」", s, p),
			_l("「您這趟事辦得順不順，小的不敢問。茶是熱的，先喝一口。」", s),
		]
	return [
		_l("「客倌又回來了，白日、夜裡都見過，小的可算認得您啦。」", s, p),
		_l("「先前那點玄乎的預感，如今看來，倒像是琴聲替您先打了個招呼。」", s),
		_l("「茶熱著，您喝了再走。」", s),
	]
