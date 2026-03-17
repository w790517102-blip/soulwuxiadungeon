extends RichTextLabel
class_name LogPanel

var _queue: Array[String] = []      # 文字佇列，每項是一行（可以含 [color] / [b] 標籤）
var _typing: bool = false
var _chars_per_sec: float = 30.0
var _waiting_for_continue: bool = false
var _lines_since_checkpoint: int = 0
var _continue_hint_label: Label

func _ready() -> void:
	# 我們自己處理標籤，不靠內建 BBCode parser
	bbcode_enabled = false
	clear()
	set_process_input(true)
	_continue_hint_label = Label.new()
	_continue_hint_label.name = "ContinueHint"
	_continue_hint_label.text = "▶ 按空白鍵/確認鍵/滑鼠左鍵繼續"
	_continue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_continue_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_hint_label.size_flags_horizontal = Control.SIZE_FILL
	_continue_hint_label.modulate = Color(0.85, 0.9, 1.0, 0.9)
	_continue_hint_label.z_index = 1000
	_continue_hint_label.set_as_top_level(true)
	_continue_hint_label.add_theme_font_size_override("font_size", 20)
	_continue_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_continue_hint_label.add_theme_constant_override("outline_size", 3)
	_continue_hint_label.visible = false
	add_child(_continue_hint_label)
	_sync_continue_hint_layout()

# ========== 對外 API ==========

# 白色敘事用
func log_narration(text: String) -> void:
	_enqueue_line(text)

# 系統藍字用（自動包 color 標籤）
func log_system(text: String) -> void:
	var wrapped = "[color=#7fd0ff]%s[/color]" % text
	_enqueue_line(wrapped)

# 通用，BattleController 直接呼叫（裡面可以塞自己的 [color] / [b] 標籤）
func log(text: String) -> void:
	_enqueue_line(text)

# BattleController / 敵人回合在結束前 call 這個，確保戰報打完再換人
func wait_for_all_logs() -> void:
	while _typing or not _queue.is_empty():
		await get_tree().process_frame



func wait_for_continue() -> void:
	await wait_for_all_logs()
	if _lines_since_checkpoint <= 0:
		return
	_waiting_for_continue = true
	if _continue_hint_label:
		_sync_continue_hint_layout()
		_continue_hint_label.visible = true
	while _waiting_for_continue:
		await get_tree().process_frame
	if _continue_hint_label:
		_continue_hint_label.visible = false
	_lines_since_checkpoint = 0


func _input(event: InputEvent) -> void:
	if not _waiting_for_continue:
		return
	if event.is_action_pressed("ui_accept"):
		_waiting_for_continue = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_waiting_for_continue = false
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_continue_hint_layout()


func _sync_continue_hint_layout() -> void:
	if _continue_hint_label == null:
		return
	if not is_inside_tree():
		return
	var hint_height := 24.0
	var rect := get_global_rect()
	_continue_hint_label.position = Vector2(rect.position.x, rect.position.y + rect.size.y + 4.0)
	_continue_hint_label.size = Vector2(rect.size.x, hint_height)


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
	_lines_since_checkpoint += 1
	# ✅ 每打一行，請 RichTextLabel 在下一幀把卷軸捲到底
	call_deferred("_scroll_to_bottom")
	_typing = false
	_start_next()

func _scroll_to_bottom() -> void:
	var line_count = get_line_count()
	if line_count > 0:
		scroll_to_line(line_count - 1)

# 解析 [color=#xxxxxx]...[/color] + [b]...[/b]，逐字顯示
func _type_line_with_tags(line: String) -> void:
	var segments: Array = []
	var current_text = ""
	var current_color: Color = Color(1, 1, 1)
	var has_color = false
	var bold = false

	var i = 0
	while i < line.length():
		var ch = line[i]
		if ch == "[":
			var end_tag = line.find("]", i)
			if end_tag == -1:
				# 標籤不完整就直接當普通文字吃掉
				current_text += line.substr(i)
				i = line.length()
				break

			var tag_content = line.substr(i + 1, end_tag - i - 1)

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

				var col_str = tag_content.substr(6, tag_content.length() - 6)
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

		var j = 0
		while j < seg_text.length():
			append_text(seg_text.substr(j, 1))
			j += 1
			await get_tree().create_timer(1.0 / _chars_per_sec).timeout

		if seg_bold:
			pop() # pop bold
		if seg_color != null:
			pop() # pop color
