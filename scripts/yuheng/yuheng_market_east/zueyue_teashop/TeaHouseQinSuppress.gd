extends RefCounted
## 《臨風寄影》壓情事件之後、白書眠還沒解釋之前，玩家先跑來醉月茶坊質問紅徽音的那段「特殊階段」。
##
## 階段：從白箋居的詩人（bookstore_guest_a）讓玩家實際被琴音壓情開始（F_SUPPRESSED），到白書眠的對話完成（met_Su_Mien／主線 stage 離開 1）為止。
##   - 階段內、還沒跟紅徽音說過話（F_FIRST_MET 沒落）的玩家：進白天的醉月茶坊時，門口強制播一次特殊演出（tea_house_qin_suppress_entry.gd），
##     不論以前有沒有踏進過茶坊、有沒有調查過琴音。
##   - 已經跟她說過話（F_FIRST_MET 已落）的玩家：不播門口演出，只有找她時的特殊對白（A）。
##   - 階段內找紅徽音（沒說過話的要先看完門口演出）：循環播放短對白，A＝以前跟她說過話、B＝從沒說過。
##   - 先去找白書眠的玩家，階段在進茶坊前就結束了：不播門口演出，茶坊照原本的初見／重訪流程。
## 旗標：
##   F_SUPPRESSED  白箋居詩人那段壓情演出結束時落旗（bookstore_guest_a.gd）。
##   F_ENTRY_DONE  門口特殊演出播完時落旗（同時補上 event_tea_house_melody_recall：琴音這件事已經親耳聽過）。
## 演出不碰 event_tea_house_first_met：紅徽音「第一次正式交談」沒有真的發生，階段結束後仍要播原本的初見。
## 也不碰任何夜訪、銅釦、山莊主線的旗標。

const F_SUPPRESSED := "event_linfeng_qin_suppressed"
const F_ENTRY_DONE := "event_tea_house_qin_suppress_entry_done"
const F_FIRST_MET := "event_tea_house_first_met"
const F_MELODY_RECALL := "event_tea_house_melody_recall"
const F_MET_SHUMIAN := "met_Su_Mien"

const LIU_PORTRAIT := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const EMPTY_PORTRAIT := "res://assets/sprites/empty.png"


## 階段還沒結束：已經被壓情、白書眠還沒解釋，而且主線還在第 1 階段。
static func is_window_open() -> bool:
	if not GlobalState.get_flag(F_SUPPRESSED) or GlobalState.get_flag(F_MET_SHUMIAN):
		return false
	return int(QuestManager.get_main_quest_state().get("stage", 1)) <= 1


## 門口演出還沒播、且現在該播：階段內、還沒跟紅徽音說過話、演出沒播過。
static func entry_pending() -> bool:
	return is_window_open() and not GlobalState.get_flag(F_FIRST_MET) and not GlobalState.get_flag(F_ENTRY_DONE)


## 紅徽音的特殊互動是否生效：階段內，而且門口演出播完了，或根本不用播（已經跟她說過話）。
static func huiyin_special_active() -> bool:
	return is_window_open() and (GlobalState.get_flag(F_ENTRY_DONE) or GlobalState.get_flag(F_FIRST_MET))


static func _n(text: String) -> Dictionary:
	return { "text": text, "speaker": 0, "portrait": EMPTY_PORTRAIT }


static func _liu(text: String) -> Dictionary:
	return { "text": "劉語塵：「%s」" % text, "speaker": 2, "portrait": LIU_PORTRAIT }


## 門口演出第一段：到第一聲琴音之後、第二聲之前。
static func entry_part1() -> Array:
	return [
		_n("你踏進醉月茶坊，腳步比往常急了幾分。"),
		_n("方才在白箋居，那首《臨風寄影》明明讓你心頭一熱，幾乎難以自持，卻被一陣突如其來的琴音，將那份感動生生壓了回去。"),
		_n("你循聲而來，心中既覺委屈，也有幾分不平。"),
		_n("正想尋那撫琴之人問個明白，琴聲忽然又起。"),
		_n("錚——"),
		_n("不知怎地，方才積在胸口的那股氣，竟隨著琴音漸漸散去。"),
		_n("你停下腳步。"),
		_n("明明記得自己是來質問的，此刻卻無論如何，也提不起半分怒意。"),
		_n("這突如其來的轉變，讓你心中一驚。"),
		_n("然而，還未來得及細想——"),
	]


## 第二段：第二聲琴音之後，連驚訝也被撫平，只剩冷靜的分析。
static func entry_part2() -> Array:
	return [
		_n("錚——"),
		_n("第二聲琴音悠悠傳來。"),
		_n("就連方才的驚訝與疑惑，也像是被一隻無形的手輕輕撫平。"),
		_n("你仍記得自己為何而來，也清楚記得白箋居裡發生的一切。"),
		_n("只是如今再回想，心中竟再無波瀾。"),
		_liu("（心想）嗯……看來這琴音，當真能壓制他人情感，使人心緒平靜。"),
		_liu("（心想）可若要以壓下人的真情，換得這份平靜……真就是好事麼？"),
		_n("你循著琴聲望去。"),
		_n("琴案前，那名女伶仍安靜地撫著琴，彷彿方才什麼也沒有發生。"),
	]


## 紅徽音的循環短對白：以前跟她說過話（A）／從沒說過（B）。
static func huiyin_loop(already_met: bool) -> Array:
	if already_met:
		return [
			_n("你再次走近琴案。"),
			_n("原想質問女伶，為何要以琴音壓住眾人的情緒。"),
			_n("可聽著那不曾停歇的曲調，你竟不知不覺沉浸其中。"),
			_n("那些本已想好的話，到了嘴邊，卻又不知該從何說起。"),
			_n("你終究沒有開口，只是靜靜聽了一會兒琴。"),
		]
	return [
		_n("你來到琴案前，望著眼前這位素未謀面的女伶。"),
		_n("明知正是她的琴聲，壓下了自己在白箋居的那份感動，你卻怎麼也提不起怒氣。"),
		_n("一切彷彿都變得合乎情理，連原本想要質問的念頭，也失去了催促你開口的力量。"),
		_n("你看著她專心撫琴的模樣，終究沒有出聲。"),
	]
