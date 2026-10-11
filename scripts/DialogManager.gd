extends CanvasLayer

signal dialog_sequence_finished(npc_node)
signal dialog_finished  # ✅ 新增這行

const NARRATION_SPEAKER_ID := 0
const LIUYU_SPEAKER_ID := 2

@onready var dialog_box_1 := $DialogBox1
@onready var dialog_box_2 := $DialogBox2
@onready var headshot_1 := $DialogBox1/HeadShot1
@onready var headshot_2 := $DialogBox2/HeadShot2
@onready var label_1 := $DialogBox1/Label
@onready var label_2 := $DialogBox2/Label
@onready var speaker_name_1 := $DialogBox1/SpeakerName
@onready var speaker_name_2 := $DialogBox2/SpeakerName
@onready var choice_box := $ChoiceBox

var is_typing := false
var skip_typing := false
var waiting_for_close := false
var dialog_active := false

var current_sequence := []
var current_index := 0
var current_speaker := 1
var current_portrait := ""

var last_npc: Node2D = null
var continue_emitted := false

func _ready():
	_clear_dialog_lane(dialog_box_1, headshot_1, label_1, speaker_name_1)
	_clear_dialog_lane(dialog_box_2, headshot_2, label_2, speaker_name_2)
	dialog_active = false

func show_main_story_dialog(text: String, portrait_path := "", speaker := 1, npc_node: Node2D = null) -> void:
	if dialog_active:
		print("[DialogManager] 對話進行中，忽略此次觸發")
		return
	dialog_active = true
	last_npc = npc_node
	await _head_dialog(text, portrait_path, speaker)
	dialog_active = false
	_reset_npc_state()
	emit_signal("dialog_finished")  # ✅ 這裡補 emit

func show_dialog_sequence(lines: Array, npc_node: Node2D = null) -> void:
	if dialog_active:
		print("[DialogManager] 對話進行中，忽略序列")
		return
	dialog_active = true
	current_sequence = lines
	current_index = 0
	last_npc = npc_node
	await _play_dialog_sequence()
	dialog_active = false
	current_sequence = []
	_reset_npc_state()
	hide_dialog()
	emit_signal("dialog_sequence_finished", npc_node)
	emit_signal("dialog_finished")  # ✅ 這裡補 emit


func show_synchronized_dialog_pair(lines: Array, npc_node: Node2D = null) -> void:
	if dialog_active:
		print("[DialogManager] 對話進行中，忽略 synchronized pair")
		return
	dialog_active = true
	last_npc = npc_node
	var lane_data: Dictionary = {1: null, 2: null}
	for line_data in lines:
		if typeof(line_data) != TYPE_DICTIONARY:
			continue
		var lane: int = int(line_data.get("dialog_lane", 0))
		if lane == 1 or lane == 2:
			lane_data[lane] = line_data

	var line_1: Dictionary = lane_data[1] if lane_data[1] is Dictionary else {}
	var line_2: Dictionary = lane_data[2] if lane_data[2] is Dictionary else {}
	_clear_dialog_lane(dialog_box_1, headshot_1, label_1, speaker_name_1)
	_clear_dialog_lane(dialog_box_2, headshot_2, label_2, speaker_name_2)
	_configure_synchronized_dialog_lane(
		dialog_box_1,
		headshot_1,
		label_1,
		speaker_name_1,
		line_1
	)
	_configure_synchronized_dialog_lane(
		dialog_box_2,
		headshot_2,
		label_2,
		speaker_name_2,
		line_2
	)

	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(dialog_box_1, "modulate:a", 1.0, 0.1)
	fade.tween_property(dialog_box_2, "modulate:a", 1.0, 0.1)
	fade.tween_property(headshot_1, "modulate:a", 1.0, 0.1)
	fade.tween_property(headshot_2, "modulate:a", 1.0, 0.1)
	await fade.finished

	is_typing = true
	skip_typing = false
	var text_1: String = str(line_1.get("text", ""))
	var text_2: String = str(line_2.get("text", ""))
	var max_length: int = maxi(text_1.length(), text_2.length())
	for index in range(max_length):
		if skip_typing:
			label_1.text = text_1
			label_2.text = text_2
			break
		if index < text_1.length():
			label_1.text += text_1[index]
		if index < text_2.length():
			label_2.text += text_2[index]
		await get_tree().create_timer(0.03).timeout
	label_1.text = text_1
	label_2.text = text_2
	is_typing = false
	waiting_for_close = true
	await _wait_for_continue()
	waiting_for_close = false
	dialog_active = false
	hide_dialog()
	_reset_npc_state()
	emit_signal("dialog_sequence_finished", npc_node)
	emit_signal("dialog_finished")


## 文字區：對話框內、頭像以外的範圍，文字自動換行在這裡面，不會超出框，也不會蓋到頭像。
## 上方欄（旁白與其他角色）頭像在右邊，文字從左邊起；下方欄（劉語塵）頭像在左邊，文字從頭像右邊起。
const TEXT_SIDE_PADDING := 61.0
const TEXT_PORTRAIT_GAP := 24.0
const TEXT_MIN_WIDTH := 160.0
var _label_home_x: Dictionary = {}


func _fit_label_to_lane(dialog_box: Control, headshot: Sprite2D, label: Label, top_lane: bool) -> void:
	if not _label_home_x.has(label):
		_label_home_x[label] = label.position.x
	var left: float = float(_label_home_x[label])
	var right: float = dialog_box.size.x - TEXT_SIDE_PADDING
	if headshot != null and headshot.visible and headshot.texture != null:
		var half_width: float = float(headshot.texture.get_width()) * absf(headshot.scale.x) * 0.5
		if top_lane:
			right = minf(right, headshot.position.x - half_width - TEXT_PORTRAIT_GAP)
		else:
			left = maxf(left, headshot.position.x + half_width + TEXT_PORTRAIT_GAP)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # CJK-aware: no line starts with a comma / full stop
	label.position.x = left
	label.custom_minimum_size.x = maxf(right - left, TEXT_MIN_WIDTH)
	label.size = Vector2(label.custom_minimum_size.x, 0.0)


func _configure_synchronized_dialog_lane(
	dialog_box: CanvasItem,
	headshot: Sprite2D,
	label: Label,
	name_label: Label,
	line_data: Dictionary
) -> void:
	label.text = ""
	name_label.text = ""
	name_label.visible = false
	headshot.texture = null
	headshot.visible = false
	var portrait_path: String = str(line_data.get("portrait", ""))
	if portrait_path != "":
		headshot.texture = load(portrait_path)
		headshot.visible = headshot.texture != null
	_fit_label_to_lane(dialog_box as Control, headshot, label, dialog_box == dialog_box_1)
	dialog_box.visible = true
	dialog_box.modulate.a = 0.0
	headshot.modulate.a = 0.0

func _play_dialog_sequence():
	while current_index < current_sequence.size():
		var line_data = current_sequence[current_index]
		current_index += 1

		if typeof(line_data) == TYPE_DICTIONARY:
			if line_data.has("choice"):
				await _handle_choice(line_data["choice"])
				continue
			elif line_data.has("action"):
				await _handle_action(line_data)
				continue
			elif line_data.has("wait"):
				await get_tree().create_timer(float(line_data.wait)).timeout
				continue

			var text = line_data.get("text", "")
			var speaker = line_data.get("speaker", 1)
			var portrait = line_data.get("portrait", "")
			var speaker_name = line_data.get("speaker_name", "")
			await _head_dialog(text, portrait, speaker, speaker_name)
			await _wait_for_continue()
		else:
			await _head_dialog(str(line_data), current_portrait, current_speaker)
			await _wait_for_continue()

func _head_dialog(
	text: String,
	portrait_path: String,
	speaker: int,
	speaker_name: String = ""
) -> void:
	# speaker 保留角色／旁白語意；UI lane 只由共用規則決定：
	# 0 = 旁白（上方、無頭像），2 = 劉語塵（下方），其餘對話角色 = 上方。
	var uses_top_lane := speaker != LIUYU_SPEAKER_ID
	if uses_top_lane:
		_clear_dialog_lane(dialog_box_2, headshot_2, label_2, speaker_name_2)
	else:
		_clear_dialog_lane(dialog_box_1, headshot_1, label_1, speaker_name_1)
	var dialog_box = dialog_box_1 if uses_top_lane else dialog_box_2
	var headshot = headshot_1 if uses_top_lane else headshot_2
	var label = label_1 if uses_top_lane else label_2
	var name_label = speaker_name_1 if uses_top_lane else speaker_name_2
	var is_narration := speaker == NARRATION_SPEAKER_ID

	label.text = ""
	# 本作目前不使用獨立 Speaker Name 欄位；名稱若需要顯示，直接寫在台詞文字中。
	name_label.text = ""
	name_label.visible = false
	headshot.texture = null
	headshot.visible = false
	if not is_narration and portrait_path != "":
		headshot.texture = load(portrait_path)
		headshot.visible = headshot.texture != null
	_fit_label_to_lane(dialog_box as Control, headshot, label, uses_top_lane)

	dialog_box.visible = true
	dialog_box.modulate.a = 0.0
	headshot.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(dialog_box, "modulate:a", 1.0, 0.1)
	tween.tween_property(headshot, "modulate:a", 1.0, 0.1)
	await tween.finished

	is_typing = true
	skip_typing = false

	for i in text.length():
		if skip_typing:
			label.text = text
			break
		label.text += text[i]
		await get_tree().create_timer(0.03).timeout

	label.text = text
	is_typing = false
	waiting_for_close = true

func _wait_for_continue():
	continue_emitted = false
	while not continue_emitted:
		await get_tree().process_frame
	waiting_for_close = false

func _unhandled_input(event):
	# 沒有對話時，Space 必須留給場景中的 Interact 節點。
	# ChoiceBox 的 Button 由 GUI input 自行消耗，不經此處處理。
	if not dialog_active:
		return

	var proceed = false
	if event.is_action_pressed("ui_accept"):
		proceed = true
	elif event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			proceed = true
	if not proceed:
		return
	get_viewport().set_input_as_handled()
	if is_typing:
		skip_typing = true
	elif waiting_for_close:
		continue_emitted = true

func hide_dialog():
	_clear_dialog_lane(dialog_box_1, headshot_1, label_1, speaker_name_1)
	_clear_dialog_lane(dialog_box_2, headshot_2, label_2, speaker_name_2)
	dialog_active = false


func _clear_dialog_lane(
	dialog_box: CanvasItem,
	headshot: Sprite2D,
	label: Label,
	name_label: Label
) -> void:
	dialog_box.visible = false
	headshot.visible = false
	headshot.texture = null
	label.text = ""
	name_label.visible = false
	name_label.text = ""

func _reset_npc_state():
	if last_npc and last_npc.has_method("reset_dialog_state"):
		last_npc.reset_dialog_state()
	last_npc = null

func show_choice(choices: Array) -> void:
	choice_box.clear()
	for item in choices:
		choice_box.add_option(item.text, item.callback)
	choice_box.show_choices()

func _handle_choice(choice_data: Array):
	show_choice(choice_data)
	await choice_box.choice_selected

func _handle_action(action_data: Dictionary):
	if not action_data.has("target") or not action_data.has("anim"):
		return
	var node = get_node_or_null(action_data["target"])
	if node and node.has_method("play"):
		node.play(action_data["anim"])
		await get_tree().process_frame

func show_safe_dialog_sequence(lines: Array, npc_node: Node2D = null) -> void:
	if dialog_active:
		print("[DialogManager] 對話進行中，忽略 safe sequence")
		return
	dialog_active = true
	current_sequence = lines
	current_index = 0
	last_npc = npc_node
	await _play_dialog_sequence()
	dialog_active = false
	current_sequence = []
	hide_dialog()
	_reset_npc_state()
	emit_signal("dialog_finished")  # ✅ 若需要安全模式下也通知結束
