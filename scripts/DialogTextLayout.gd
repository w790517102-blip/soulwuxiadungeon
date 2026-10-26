extends RefCounted
## 對話文字排版：依對話框實際可用寬度，把長句在自然語意處斷成平衡的幾行（人工斷行 + Label 自動換行當安全保障）。
##
## 規則（共邊國〈台詞系統大規模統一 PATCH〉四）：
##  - 放得下就保持單行，不為了整齊硬斷短句。
##  - 長句斷在逗號、句號等停頓之後，各行長度盡量平衡；不留一兩個字的孤行（尾行）。
##  - 不拆開 《…》 書名、「姓名：「」」開頭、已知專有名詞；標點不在行首，開括號不在行尾。
##  - 台詞自己已經帶 "\n"（作者手動斷行、詩詞）就原樣保留，只靠 Label 自動換行保底。詩詞另可用 "layout": "raw" 明確跳過。
##  - 超過行數上限時，在行界拆成相鄰的兩頁，不縮字、不改順序。

const MAX_LINES := 4

## 不可在其中斷開的詞（人名、專有名詞）
const PROTECTED_WORDS := [
	"劉語塵", "紅徽音", "白書眠", "白鳶橫天", "半弦銅釦", "銀屏語", "飲月山莊", "醉月茶坊", "醉月青魁",
	"玉衡鎮", "白箋居", "烈風寨", "鐘乳石洞", "舊水道", "（琴音）", "（心想）", "弦外之音", "左飲",
	"江湖", "情義", "義氣", "琴聲", "琴音", "山莊", "竹林", "山門", "通報", "女伶", "語魅", "邪典", "言靈", "詩稿", "詩集",
	"書墨坊", "茶坊", "市集", "鎮民", "武學", "內功", "心法", "莊主", "門衛", "阿婆", "家母", "兵器", "琴案", "銅釦",
]
const OPENERS := "「『（《〈【"
const CLOSERS := "」』）》〉】，。、！？；：…—·,.!?;:)"
const SOFT_BREAK_AFTER := "，。！？；：、…,;"

## 在 Label 的字型下量一段字串的寬度
class Measurer:
	var font: Font
	var size: int

	func _init(f: Font, s: int) -> void:
		font = f
		size = s

	func width(text: String) -> float:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 回傳排好版的頁面陣列（每頁一個字串，含 "\n"）。
## 一頁怎麼分（以句號 。！？ 為單位）：
##  - 一句不滿兩行：往下補句子，補到滿兩行為止（整段都不滿兩行就一頁）。
##  - 一句超過兩行：這一句自己一頁。
##  - 單句超過頁面行數上限：在行界拆成相鄰頁。
## 行內盡量填滿到文字區右緣（有立繪時就是快碰到立繪），不為了平衡而提早斷行。
static func layout_pages(text: String, measurer: Measurer, max_width: float, max_lines: int = MAX_LINES) -> Array:
	if text.contains("\n"):
		return [text]
	for gap in ["。 ", "， ", "！ ", "？ ", "。　", "，　"]:
		text = text.replace(gap, gap.substr(0, 1))
	var sentences := _split_sentences(text)
	var pages: Array = []
	var current := ""
	for sentence: String in sentences:
		var sentence_lines := _fill_lines(sentence, measurer, max_width).size()
		if current != "" and sentence_lines > 2:
			pages.append(current)
			current = ""
		current += sentence
		var current_lines := _fill_lines(current, measurer, max_width).size()
		if current_lines >= 2:
			pages.append(current)
			current = ""
	if current != "":
		# 尾巴不滿兩行：能併進上一頁（併完不超過三行）就併，不然自己一頁
		if not pages.is_empty():
			var merged: String = String(pages[-1]) + current
			if _fill_lines(merged, measurer, max_width).size() <= 3:
				pages[-1] = merged
				current = ""
		if current != "":
			pages.append(current)
	var result: Array = []
	for page: String in pages:
		var lines := _fill_lines(page, measurer, max_width)
		if lines.size() <= max_lines:
			result.append(_join(lines))
		else:
			result.append_array(_split_long_page(page, lines, measurer, max_width, max_lines))
	return result


## 依 。！？ 切句；句末的右引號、右括號跟著前一句
static func _split_sentences(text: String) -> Array:
	var out: Array = []
	var start := 0
	var i := 0
	var n := text.length()
	while i < n:
		if "。！？".contains(text[i]):
			var end := i + 1
			while end < n and "。！？」』）》".contains(text[end]):
				end += 1
			out.append(text.substr(start, end - start))
			start = end
			i = end
		else:
			i += 1
	if start < n:
		out.append(text.substr(start))
	return out


## 單一頁超過行數上限：在行界拆成相鄰頁，盡量落在逗號之後
static func _split_long_page(text: String, lines: Array, measurer: Measurer, max_width: float, max_lines: int) -> Array:
	var pages: Array = []
	var chunk_count := int(ceil(float(lines.size()) / float(max_lines)))
	var total := text.length()
	var start := 0
	for page_index in chunk_count:
		var remaining := chunk_count - page_index
		var target_chars := int(ceil(float(total - start) / float(remaining)))
		var end := _page_end(text, start, target_chars)
		pages.append(_join(_fill_lines(text.substr(start, end - start), measurer, max_width)))
		start = end
	return pages


static func _join(lines: Array) -> String:
	return "\n".join(lines)


## 頁尾盡量落在句末標點之後
static func _page_end(text: String, start: int, target_chars: int) -> int:
	var limit := mini(start + target_chars, text.length())
	if limit >= text.length():
		return text.length()
	var best := limit
	var lo := maxi(start + int(target_chars * 0.6), start + 1)
	for i in range(limit, lo, -1):
		if SOFT_BREAK_AFTER.contains(text[i - 1]) and _can_break(text, i, _forbidden(text)):
			best = i
			break
	return best


## 這個位置（0..n，表示「第 i 個字之前」）是否被禁止斷開
static func _forbidden(text: String) -> Dictionary:
	var blocked := {}
	for word: String in PROTECTED_WORDS:
		var from := 0
		while true:
			var at := text.find(word, from)
			if at < 0:
				break
			for k in range(at + 1, at + word.length()):
				blocked[k] = true
			from = at + 1
	# 《…》整個書名視為一個詞
	var i := 0
	while i < text.length():
		if text[i] == "《":
			var close := text.find("》", i)
			if close > 0:
				for k in range(i + 1, close + 1):
					blocked[k] = true
				i = close
		i += 1
	# 「名稱：「」開頭不拆（名稱、冒號、開引號）
	var colon := text.find("：「")
	if colon > 0 and colon <= 8:
		for k in range(1, colon + 2):
			blocked[k] = true
	return blocked


static func _can_break(text: String, pos: int, blocked: Dictionary) -> bool:
	if pos <= 0 or pos >= text.length():
		return false
	if blocked.has(pos):
		return false
	if CLOSERS.contains(text[pos]):
		return false
	if OPENERS.contains(text[pos - 1]):
		return false
	return true


## 平衡斷行：在「放得下」的前提下用最少的行數，行寬盡量平均，優先斷在停頓標點之後。
static func _balanced_lines(text: String, measurer: Measurer, max_width: float) -> Array:
	var total_width := measurer.width(text)
	if total_width <= max_width:
		return [text]
	var n := text.length()
	var blocked := _forbidden(text)
	var prefix: Array = [0.0]
	for i in n:
		prefix.append(measurer.width(text.substr(0, i + 1)))
	var min_lines := int(ceil(total_width / max_width))
	for line_count in range(min_lines, min_lines + 3):
		var result := _solve(text, n, prefix, blocked, max_width, line_count, total_width)
		if not result.is_empty():
			return result
	# 保底：貪婪斷行
	return _greedy(text, n, prefix, blocked, max_width)


static func _solve(text: String, n: int, prefix: Array, blocked: Dictionary, max_width: float, line_count: int, total_width: float) -> Array:
	var target := total_width / float(line_count)
	var soft_penalty := pow(max_width * 0.3, 2.0)
	var inf := 1.0e18
	# best[k][i]：用 k 行排完前 i 個字的最小成本
	var best: Array = []
	var from: Array = []
	for k in line_count + 1:
		best.append([])
		from.append([])
		for i in n + 1:
			best[k].append(inf)
			from[k].append(-1)
	best[0][0] = 0.0
	for k in range(1, line_count + 1):
		for i in range(1, n + 1):
			for j in range(0, i):
				if best[k - 1][j] >= inf:
					continue
				if j > 0 and not _can_break(text, j, blocked):
					continue
				var w: float = prefix[i] - prefix[j]
				if w > max_width:
					continue
				var cost: float = pow(w - target, 2.0)
				if i < n and not SOFT_BREAK_AFTER.contains(text[i - 1]):
					cost += soft_penalty
				if i == n and i - j <= 3:
					cost += pow(max_width, 2.0)   # 尾行只剩一兩個字：重罰
				var total: float = best[k - 1][j] + cost
				if total < best[k][i]:
					best[k][i] = total
					from[k][i] = j
	if best[line_count][n] >= inf:
		return []
	var cuts: Array = []
	var i := n
	for k in range(line_count, 0, -1):
		var j: int = from[k][i]
		cuts.push_front(text.substr(j, i - j))
		i = j
	return cuts


static func _greedy(text: String, n: int, prefix: Array, blocked: Dictionary, max_width: float) -> Array:
	var lines: Array = []
	var start := 0
	while start < n:
		var end := start + 1
		var last_ok := -1
		for i in range(start + 1, n + 1):
			if prefix[i] - prefix[start] > max_width:
				break
			end = i
			if i == n or _can_break(text, i, blocked):
				last_ok = i
		if end >= n:
			last_ok = n
		elif last_ok > start:
			for back in range(last_ok, maxi(start + 1, last_ok - 4), -1):
				if SOFT_BREAK_AFTER.contains(text[back - 1]) and _can_break(text, back, blocked):
					last_ok = back
					break
		var cut := last_ok if last_ok > start else end
		lines.append(text.substr(start, cut - start))
		start = cut
	return lines


## 貪婪填滿：每行盡量排到右緣；尾行太短（孤字）就和上一行重新平均
static func _fill_lines(text: String, measurer: Measurer, max_width: float) -> Array:
	if measurer.width(text) <= max_width:
		return [text]
	var n := text.length()
	var blocked := _forbidden(text)
	var prefix: Array = [0.0]
	for i in n:
		prefix.append(measurer.width(text.substr(0, i + 1)))
	var lines := _greedy(text, n, prefix, blocked, max_width)
	if lines.size() >= 2:
		var last_line: String = lines[-1]
		if measurer.width(last_line) < max_width * 0.2 or last_line.length() <= 3:
			var tail := String(lines[-2]) + last_line
			var pair := _balanced_lines(tail, measurer, max_width)
			if pair.size() == 2:
				lines.resize(lines.size() - 2)
				lines.append_array(pair)
	return lines
