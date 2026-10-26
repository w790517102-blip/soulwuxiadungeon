extends SceneTree
## 對話文字排版：短句不硬斷、長句斷在停頓處且不留孤字尾行、專有名詞與「名稱：「」」開頭不拆、自帶換行與詩詞原樣、過長拆頁。
## Run: --headless --path . --script tests/test_dialog_text_layout.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	var Layout: Script = load("res://scripts/DialogTextLayout.gd")
	var font: Font = load("res://assets/fonts/DotGothic16-Regular.ttf")
	var m = Layout.Measurer.new(font, 28)
	var width := 776.0

	for t in ["你想起先前與大寶的交談。", "此時，你忽然察覺異樣。", "但你知道，有些事情已經不同了。", "不是聲音變小，而是你的心神被詩意牽住。", "只是望著她的手，你漸漸明白。"]:
		_expect(Layout.is_second_person_narration(t), "second-person narration: " + t)
	for t in ["顧石看了你一眼。", "阿婆遞到你手中。", "紅徽音輕輕頷首。", "劉語塵：「你來了。」", "她向你微微頷首。"]:
		_expect(not Layout.is_second_person_narration(t), "not second-person narration: " + t)

	var short := "白書眠：「劉少俠，今日來得好早。」"
	_expect(Layout.layout_pages(short, m, width) == [short], "short line stays on one line")

	var poem := "銀屏寂寂月微明，\n一紙空白待回聲。"
	_expect(Layout.layout_pages(poem, m, width) == [poem], "text with its own line breaks is untouched")

	var long := "紅徽音：「（琴音）我早知道，這琴壓住的不只有語魅。可直到昨夜，才真正看清，我們守住了多少，又讓多少話沉在了水底。」"
	var pages: Array = Layout.layout_pages(long, m, width)
	_expect(pages.size() == 1, "long line fits in one page")
	var lines: PackedStringArray = String(pages[0]).split("\n")
	_expect(lines.size() >= 2, "long line is wrapped")
	for line in lines:
		_expect(m.width(line) <= width, "line fits the safe width: " + line)
		_expect(line.length() >= 4, "no orphan line: " + line)
		_expect(not "，。、！？；：」）".contains(line.substr(0, 1)), "no line starts with punctuation: " + line)
	_expect(String(lines[0]).begins_with("紅徽音：「（琴音）"), "speaker prefix and (琴音) are not split")

	var names := "你想起《銀屏語》的封底空白，那片空白不是未完，而是等待回聲。劉語塵握著那枚半弦銅釦，白鳶橫天四個字在心頭轉了又轉，一時說不出話來，只能靜靜看著她。"
	var name_pages: Array = Layout.layout_pages(names, m, 600.0)
	var joined := "\n".join(name_pages)
	for word in ["《銀屏語》", "劉語塵", "半弦銅釦", "白鳶橫天"]:
		_expect(joined.contains(word), "name kept whole: " + word)

	var huge := ""
	for i in 6:
		huge += "你沒有開口，只是靜靜站在她身旁，聽著那一曲壓住了整座玉衡鎮的琴聲，一遍又一遍地響起來。"
	var huge_pages: Array = Layout.layout_pages(huge, m, width)
	_expect(huge_pages.size() >= 2, "over-long text is split into adjacent pages")
	for page in huge_pages:
		_expect(String(page).split("\n").size() <= Layout.MAX_LINES, "each page fits the line limit")
	_expect("".join(huge_pages).replace("\n", "") == huge, "paging keeps every character in order")

	# 行內填滿到右緣（不為了平衡提早斷行）：第一行應該接近安全寬度
	var fill_pages: Array = Layout.layout_pages(long, m, width)
	var first_line: String = String(fill_pages[0]).split("\n")[0]
	_expect(m.width(first_line) >= width - 5.0 * 28.0, "first line is filled up to the right edge")

	# 以句號為單位分頁：不滿兩行補到兩行，超過兩行的一句自己一頁
	var narr := "你循著熟悉的琴聲走進醉月茶坊。昨夜舊水道中的種種遭遇，至今仍歷歷在目。琴案前，紅徽音依舊一襲紅衣，端坐如故。她眉宇間藏著未曾消散的倦意，十指卻仍穩穩撫過琴弦，曲調不曾錯亂，彷彿昨夜什麼都未曾發生，只有窗外的月色比往日更冷了些，落在案上那一枚半弦銅釦之上，像一彎還沒有圓的月。你沒有開口。"
	var narr_pages: Array = Layout.layout_pages(narr, m, 966.0)
	_expect(narr_pages.size() >= 2, "narration is paged by sentence, not crammed into one box")
	for page in narr_pages:
		_expect(String(page).split("\n").size() <= 3, "narration page stays within three lines")
	var long_sentence_page := ""
	for page in narr_pages:
		if String(page).replace("\n", "").begins_with("她眉宇間"):
			long_sentence_page = String(page).replace("\n", "")
	_expect(long_sentence_page.begins_with("她眉宇間") and not long_sentence_page.contains("琴案前"), "a sentence longer than two lines gets its own page")
	_expect("".join(narr_pages).replace("\n", "") == narr, "sentence paging keeps every character in order")

	# 一頁塞滿兩行才換頁：第一句不滿兩行時，後面短的句子要接上來，不要急著換頁
	var packed := "老翁：「不錯不錯！果然英雄出少年。能把我逼到這般境地的，你是第二個。」"
	var packed_pages: Array = Layout.layout_pages(packed, m, 966.0)
	_expect(packed_pages.size() == 1, "short sentences that fit in two lines share one page: %s" % str(packed_pages))
	var overflow := "老翁：「不錯不錯！果然英雄出少年，能把我逼到這般境地的人，你是第二個，也是這幾十年來頭一個讓老夫連退三步的後生。第一個是左飲那小子，他的刀快得像燕子掠水，我到現在都還記得清清楚楚，忘也忘不掉，每次想起來手腕都隱隱作痛，真是個了不得的年輕人。」"
	var overflow_pages: Array = Layout.layout_pages(overflow, m, 966.0)
	_expect(overflow_pages.size() == 2 and "".join(overflow_pages).replace(String.chr(10), "") == overflow, "when the next sentence would overflow two lines, the page turns: %s" % str(overflow_pages))
	# 兩行平均斷行時，成本一樣就讓第一行排滿一點（不要第一行比第二行短）
	var even_text := "老翁：「如今你捨去外物，仍能守住拳意，這才是真正的武人胚子。」"
	var even_lines: PackedStringArray = String(Layout.layout_pages(even_text, m, 800.0)[0]).split(String.chr(10))
	_expect(even_lines.size() == 2 and m.width(even_lines[0]) >= m.width(even_lines[1]), "the first line is not shorter than the second: %s" % str(even_lines))
	var tiny := "劉語塵：「在下劉語塵。」"
	_expect(Layout.layout_pages(tiny, m, 966.0) == [tiny], "one short sentence stays one page, one line")

	if _failures.is_empty():
		print("PASS: dialog text layout")
		quit(0)
	else:
		for message: String in _failures:
			push_error("FAIL: " + message)
		quit(1)
