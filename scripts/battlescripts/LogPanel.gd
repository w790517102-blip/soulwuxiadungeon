extends RichTextLabel
class_name LogPanel

var _queue: Array[String] = []      # 文字佇列，每項是一行（可以含 [color] / [b] 標籤）
var _typing: bool = false
var _chars_per_sec: float = 30.0

func _ready() -> void:
	# 我們自己處理標籤，不靠內建 BBCode parser
	bbcode_enabled = false
	clear()

# ========== 對外 API ==========

# 白色敘事用
func log_narration(text: String) -> void:
	_enqueue_line(text)

# 系統藍字用（自動包 color 標籤）
func log_system(text: String) -> void:
	var wrapped := "[color=#7fd0ff]%s[/color]" % text
	_enqueue_line(wrapped)

# 通用，BattleController 直接呼叫（裡面可以塞自己的 [color] / [b] 標籤）
func log(text: String) -> void:
	_enqueue_line(text)

# BattleController / 敵人回合在結束前 call 這個，確保戰報打完再換人
func wait_for_all_logs() -> void:
	while _typing or not _queue.is_empty():
		await get_tree().process_frame


# ========== 內部實作 ==========

func _enqueue_line(text: String) -> void:
	_queue.append(text)
	if not _typing:
		_start_next()

func _start_next() -> void:
	if _queue.is_empty():
		_typing = false
		return

	_typing = true
	var line: String = _queue.pop_front()
	await _type_line_with_tags(line)
	append_text("\n")
	# ✅ 每打一行，請 RichTextLabel 在下一幀把卷軸捲到底
	call_deferred("_scroll_to_bottom")
	_typing = false
	_start_next()

func _scroll_to_bottom() -> void:
	var line_count := get_line_count()
	if line_count > 0:
		scroll_to_line(line_count - 1)

# 解析 [color=#xxxxxx]...[/color] + [b]...[/b]，逐字顯示
func _type_line_with_tags(line: String) -> void:
	var segments: Array = []
	var current_text := ""
	var current_color: Color = Color(1, 1, 1)
	var has_color := false
	var bold := false

	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == "[":
			var end_tag := line.find("]", i)
			if end_tag == -1:
				# 標籤不完整就直接當普通文字吃掉
				current_text += line.substr(i)
				i = line.length()
				break

			var tag_content := line.substr(i + 1, end_tag - i - 1)

			if tag_content.begins_with("color="):
				# 先把之前累積的文字丟進 segments
				if current_text != "":
					var seg_color1 = null
					if has_color:
						seg_color1 = current_color
					segments.append({
						"text": current_text,
						"color": seg_color1,
						"bold": bold
					})
					current_text = ""

				var col_str := tag_content.substr(6, tag_content.length() - 6)
				current_color = Color(col_str)
				has_color = true

			elif tag_content == "/color":
				if current_text != "":
					var seg_color2 = null
					if has_color:
						seg_color2 = current_color
					segments.append({
						"text": current_text,
						"color": seg_color2,
						"bold": bold
					})
					current_text = ""
				has_color = false

			elif tag_content == "b":
				if current_text != "":
					var seg_color3 = null
					if has_color:
						seg_color3 = current_color
					segments.append({
						"text": current_text,
						"color": seg_color3,
						"bold": bold
					})
					current_text = ""
				bold = true

			elif tag_content == "/b":
				if current_text != "":
					var seg_color4 = null
					if has_color:
						seg_color4 = current_color
					segments.append({
						"text": current_text,
						"color": seg_color4,
						"bold": bold
					})
					current_text = ""
				bold = false

			else:
				# 不是 color / b 標籤，原樣輸出
				current_text += line.substr(i, end_tag - i + 1)

			i = end_tag + 1
		else:
			current_text += ch
			i += 1

	# 把最後一段收進 segments
	if current_text != "":
		var seg_color5 = null
		if has_color:
			seg_color5 = current_color
		segments.append({
			"text": current_text,
			"color": seg_color5,
			"bold": bold
		})

	# 實際逐字顯示
	for seg in segments:
		var seg_text: String = seg["text"]
		var seg_color = seg["color"]
		var seg_bold: bool = seg["bold"]

		if seg_color != null:
			push_color(seg_color)
		if seg_bold:
			push_bold()

		var j := 0
		while j < seg_text.length():
			append_text(seg_text.substr(j, 1))
			j += 1
			await get_tree().create_timer(1.0 / _chars_per_sec).timeout

		if seg_bold:
			pop() # pop bold
		if seg_color != null:
			pop() # pop color
