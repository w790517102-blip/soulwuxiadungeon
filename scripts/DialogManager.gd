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
	_clear_dialog_lane(dialog_box_1, headshot_1, label_1)
	_clear_dialog_lane(dialog_box_2, headshot_2, label_2)
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
			await _head_dialog(text, portrait, speaker)
			await _wait_for_continue()
		else:
			await _head_dialog(str(line_data), current_portrait, current_speaker)
			await _wait_for_continue()

func _head_dialog(text: String, portrait_path: String, speaker: int) -> void:
	# speaker 保留角色／旁白語意；UI lane 只由共用規則決定：
	# 0 = 旁白（上方、無頭像），2 = 劉語塵（下方），其餘對話角色 = 上方。
	var uses_top_lane := speaker != LIUYU_SPEAKER_ID
	if uses_top_lane:
		_clear_dialog_lane(dialog_box_2, headshot_2, label_2)
	else:
		_clear_dialog_lane(dialog_box_1, headshot_1, label_1)
	var dialog_box = dialog_box_1 if uses_top_lane else dialog_box_2
	var headshot = headshot_1 if uses_top_lane else headshot_2
	var label = label_1 if uses_top_lane else label_2
	var is_narration := speaker == NARRATION_SPEAKER_ID

	label.text = ""
	headshot.texture = null
	headshot.visible = false
	if not is_narration and portrait_path != "":
		headshot.texture = load(portrait_path)
		headshot.visible = headshot.texture != null

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
	_clear_dialog_lane(dialog_box_1, headshot_1, label_1)
	_clear_dialog_lane(dialog_box_2, headshot_2, label_2)
	dialog_active = false


func _clear_dialog_lane(dialog_box: CanvasItem, headshot: Sprite2D, label: Label) -> void:
	dialog_box.visible = false
	headshot.visible = false
	headshot.texture = null
	label.text = ""

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
