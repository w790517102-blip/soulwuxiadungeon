# ✅ 白箋居前暴發戶事件觸發腳本
# 觸發時機：劉語塵於飲月山莊吃到閉門羹後，返回玉衡鎮、靠近白箋居前 Area2D。
# 劇情功能：銜接「飲月山莊閉莊」→「白箋居開門」→「書眠與銀屏語」。
extends Node2D

var triggered := false

@onready var dialog_manager := get_node("/root/GameRoot/DialogManager")
@onready var player := get_node("/root/GameRoot/LiuYu")
@onready var area := $Area2D

# 依照你的專案實際圖像路徑可再調整
const EMPTY_PORTRAIT := "res://assets/sprites/empty.png"
const LIUYU_PORTRAIT := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const SHUMIAN_PORTRAIT := "res://assets/sprites/Shumian/Shumian_headshot.png"
const RICHMAN_PORTRAIT := "res://assets/sprites/NPC/richman_headshot.png"

# 依照你的 DialogManager speaker 定義可再調整
const NPC_SPEAKER := 1
const LIUYU_SPEAKER := 2
const SHUMIAN_SPEAKER := 3
const RICHMAN_SPEAKER := 4

const F_MANOR_CLOSED := "main_yh_manor_closed"
const F_EVENT_DONE := "event_baijianju_richman_done"
const F_BAIJIANJU_OPEN := "main_yh_baijianju_open"

func _ready():
	if GlobalState.get_flag(F_EVENT_DONE):
		queue_free()
		return
	area.body_entered.connect(_on_player_entered)

func _on_player_entered(body):
	if triggered or not body.name == "LiuYu":
		return
	
	# 這段劇情必須在飲月山莊閉莊後才觸發。
	if not GlobalState.get_flag(F_MANOR_CLOSED):
		return
	
	triggered = true
	player.can_move = false
	
	_face_player_down_left()
	await get_tree().create_timer(0.35).timeout
	
	dialog_manager.show_dialog_sequence(_build_dialog_lines())
	await dialog_manager.dialog_sequence_finished
	
	GlobalState.set_flag(F_EVENT_DONE, true)
	GlobalState.set_flag(F_BAIJIANJU_OPEN, true)
	
	player.can_move = true
	queue_free()

func _build_dialog_lines() -> Array:
	var lines: Array = [

		_l("飲月山莊既已閉門，左飲暫不可見。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("玉衡鎮內，仍有線索未明。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("書眠或許知道些什麼。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("前方忽然傳來一陣爭執聲。"),
		#暴發戶.tscn的visible切換成true,沿著parth2D移動,移動結束後animation播放idle_up
		_l("書眠先生，妳這話未免太不近人情了吧？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		#書眠tscn的visible切換成true,沿著parth2D移動
		_l("我昨日已說過。詩可讀，不可拿來撐場面。", SHUMIAN_SPEAKER, SHUMIAN_PORTRAIT),
		_l("我老老實實出銀子買，怎麼就叫撐場面？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("若只是想讀，白箋居的詩冊可以借。", SHUMIAN_SPEAKER, SHUMIAN_PORTRAIT),
		_l("若只是想掛在廳堂上讓賓客稱羨，那便不賣。", SHUMIAN_SPEAKER, SHUMIAN_PORTRAIT),
		_l("妳——", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		#書眠tscn沿著parth2D移動,她的visible切換成false,
		_n("書眠沒有再答，只輕輕合上門。"),
		_n("暴發戶站在門前，臉上一陣青一陣白。"),
		#暴發戶animation播放idle_left
		_l("唉唷？這不是早上跟我聊詩的那位小哥嗎？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("……", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你來得正好！", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("早上咱們也算談過詩了吧？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("你說過很多話。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("那就是談過了！", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("既然你懂幾分詩，也算半個風雅人。你替我進去說幾句話。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("說什麼？", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("說服她賣我一卷親筆詩稿。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("價錢好談。若你能辦成，我也少不了你的好處。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("你覺得我像是能替你說話的人？", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("江湖人嘛，總比這些讀書人懂人情世故。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("我剛從一個守門人那裡回來。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("他也很懂人情世故。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("所以呢？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("所以我現在對拿東西敲門的人，沒什麼好感。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("小哥這話就偏了。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("我拿的是真金白銀，又不是空口白話。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("不喊價，如何顯出誠意？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("你那不是誠意。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("那是什麼？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("是俗氣的銀子。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("暴發戶怔了一瞬，隨即冷笑。"),
		_l("少俠倒是伶牙俐嘴。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("可這世上，哪件雅事不要銀子撐著？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("紙要銀子，墨要銀子，書齋要銀子，名聲也要銀子。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("所以你要買的是詩？", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("不然呢？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_n("劉語塵看了他一眼。"),
		_l("我看不像。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("此話怎說？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("像買門面。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你——", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("書是給人讀的。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你想買回去掛起來，讓賓客看見，說一句『這是書眠親筆』。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你要的不是字。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("是旁人看你時，多敬你半寸的眼神。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("暴發戶臉色變得難看。"),
		_l("胡說！", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("我家中藏書千卷，宴客時談詩論賦，往來皆是名士。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("我若不懂詩，誰懂？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("藏書千卷，未必讀過一卷。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("放肆！", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("往來名士，未必有一人願意聽你說話。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你一介江湖客，衣著寒酸，也配論我？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("我不論你。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("那你是在做什麼？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("替白箋居省些口水。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("一旁幾名鎮民本在裝作路過，聽到這句，忍不住低笑。"),
		_l("笑什麼！", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("你們玉衡鎮不過偏安一隅，真以為出了一個書眠，便人人都高雅起來了？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("高雅不高雅，我不知道。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("但白箋居人人可入，你卻進不去。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你說什麼？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("不是規矩太複雜。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("是你腦袋太簡單。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你敢辱我？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("你若只是買不到書，我不會開口。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你若只是被拒在門外，也與我無關。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("但你把別人的心血當成宴席上的酒杯，把清詞雅句當成臉上的金粉。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("這就不只是買書了。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("書寫出來，不就是給人看的？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("劍鑄出來，也是給人用的。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("可若有人拿劍去切席上的肉，還自稱懂劍。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("鑄劍的人，自然會把他趕出去。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("暴發戶一時語塞。"),
		_l("好，好。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("你們玉衡鎮的人清高，連路過的江湖客也學會擺架子。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("我不是玉衡鎮人。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("那你為何替他們說話？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_n("劉語塵沉默須臾。"),
		_n("遠處琴聲掠過街角。"),
		_n("他想起飲月山莊緊閉的山門，與顧石欲言又止的神情。"),
		_n("也想起白箋居門內那片被吵擾的清靜。"),
		_l("因為有人不想賣。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("就這樣？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("就這樣。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("荒唐！世上哪有銀子買不到的東西？", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("有。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你買不到別人願意。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("暴發戶怔住。"),
		_l("買不到，便是買不到。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你再喊大聲些，也只是讓旁人更確定你不懂。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("好一張利嘴。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("比不上你的錢袋響。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("你——！", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_n("暴發戶狠狠一甩袖。"),
		_l("今日她不賣，來日自有人求著我買！", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("你可以等。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("算你識相。", RICHMAN_SPEAKER, RICHMAN_PORTRAIT),
		_l("等到書懂得嫌人。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("暴發戶腳下一頓，滿臉通紅氣得說不出話。"),
#暴發戶tscn沿著path 2D移動,await 0.5s後 black overlay fade in, await 0.5s後, black overlay fade out
		_n("四周漸漸安靜。"),
		_n("幾名鎮民看向劉語塵，似想道謝，又被遠處琴聲一壓，各自低頭散去。"),
		_l("飲月山莊關門，白箋居也關門。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("只是前者擋我，後者擋他。", LIUYU_SPEAKER, LIUYU_PORTRAIT),

		_n("劉語塵看向白箋居。"),
		_n("方才書眠請人出門時，語氣很穩。"),
		_n("可那種穩，與紅徽音的琴聲有些相似。"),
		_n("都像是在把什麼東西壓住。"),
		_l("「書眠把他趕出來，看來不是脾氣不好。」", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("「...她應該也被困在什麼裡面。」", SHUMIAN_SPEAKER, SHUMIAN_PORTRAIT),
		_n("白箋居的門沒有鎖。"),
		_n("門縫裡透出淡淡墨香。"),
		_l("「……進去看看吧。」", LIUYU_SPEAKER, LIUYU_PORTRAIT),

		_l("主線更新：進入白箋居，察看書眠的狀況。", NPC_SPEAKER, EMPTY_PORTRAIT),
	]
	return lines

func _face_player_down_left():
	if not player:
		return
	if player.has_method("get_idle_anim_name"):
		player.animated_sprite.play(player.get_idle_anim_name(Vector2(-1, 1)))

func _l(text: String, speaker: int, portrait: String = EMPTY_PORTRAIT) -> Dictionary:
	return {
		"text": text,
		"speaker": speaker,
		"portrait": portrait
	}

func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": NPC_SPEAKER,
		"portrait": EMPTY_PORTRAIT
	}
