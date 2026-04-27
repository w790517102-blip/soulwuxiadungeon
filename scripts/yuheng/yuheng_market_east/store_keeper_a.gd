extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var use_path_patrol := false
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D
var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var is_talking: bool = false
var _mark_flag_after_close := false

const QUEST_ID := "yuheng_green_beans"
const QUEST_TITLE := "一把四季豆"
const QUEST_STAGE_2_DESC := "將四季豆帶回給秋嬸。"
const BEAN_RAW_ITEM_ID := "quest_green_beans_raw"
const BEAN_FRIED_ITEM_ID := "quest_green_beans_fried"

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

	var main_stage := _get_main_stage_safely()
	dialog_lines = _build_lines_for_stage(main_stage)

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_yuheng_store_keeper_a")
	var event_market_choice_observe := GlobalState.get_flag("event_market_choice_observe")
	var event_yuheng_market_melody := GlobalState.get_flag("event_yuheng_market_melody")
	if event_market_choice_observe and event_yuheng_market_melody and not met:
		return [
			{ "text": "「青菜新鮮，今早摘的！少俠要不要瞧一瞧？」", "speaker": 1, "portrait": portrait_path },
			{ "text": "劉語塵：「老闆，這街沒有想像中熱鬧，倒是琴聲不小」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "「哎呀~拜那琴聲所賜，大家的脾氣都小了些，吵不太起來，清淨的很」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「但那琴聲與其說是清幽，不如說比較像是…把心火壓住，不能說全好…」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「罷了，多想也是煩惱，如何？少俠要不要來點新鮮的青菜？尤其是韭菜，左飲最好這味」", "speaker": 1, "portrait": portrait_path },
		]
	if main_stage <= 2:
		if event_market_choice_observe and event_yuheng_market_melody and met:
			return [
				{ "text": "「少俠，買菜啊？咱家的菜新鮮得很，早上剛挑來的。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「要青菜、蘿蔔、茄子，還是四季豆？別看我攤小，火候跟刀工都有講究！」", "speaker": 1, "portrait": portrait_path },
			]
		return [
			{ "text": "「咱的菜鮮的很，尤其是韭菜，左飲最好這味」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「韭菜是最不怕剪斷的菜，剪一茬又長一茬，正像我等江湖客之氣節。」", "speaker": 1, "portrait": portrait_path },
		]
	if main_stage <= 6:
		return [
			{ "text": "琴聲善，善亦有度。善若過度，亦成執。", "speaker": 1, "portrait": portrait_path },
			{ "text": "此地群情雖平，卻像風停於谷，久之易悶。", "speaker": 1, "portrait": portrait_path },
		]
	return [
		{ "text": "白鳶橫天，像給谷口開了一道風眼。", "speaker": 1, "portrait": portrait_path },
		{ "text": "願君持衡，弦不傷人，心不傷己。", "speaker": 1, "portrait": portrait_path },
	]

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)

func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle = dir.angle()
	if angle >= -PI * 7/8 and angle < -PI * 5/8:
		return "%s_left_up" % prefix
	elif angle >= -PI * 5/8 and angle < -PI * 3/8:
		return "%s_up" % prefix
	elif angle >= -PI * 3/8 and angle < -PI * 1/8:
		return "%s_right_up" % prefix
	elif angle >= -PI * 1/8 and angle < PI * 1/8:
		return "%s_right" % prefix
	elif angle >= PI * 1/8 and angle < PI * 3/8:
		return "%s_right_down" % prefix
	elif angle >= PI * 3/8 and angle < PI * 5/8:
		return "%s_down" % prefix
	elif angle >= PI * 5/8 and angle < PI * 7/8:
		return "%s_left_down" % prefix
	else:
		return "%s_left" % prefix

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func _unhandled_input(event):
	if not can_interact:
		return
	if dialog_manager.dialog_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true
		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)
		_handle_store_keeper_interact()
		_mark_flag_after_close = not GlobalState.get_flag("met_yuheng_store_keeper_a")

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_store_keeper_a", true)
		_mark_flag_after_close = false

func _handle_store_keeper_interact() -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if not quest.has("quest_id"):
		_show_normal_dialog(false)
		return
	if bool(quest.get("is_finished", false)):
		_show_normal_dialog(true)
		return
	var stage := int(quest.get("stage", 0))
	if stage <= 1:
		_start_green_beans_purchase_flow()
		return
	dialog_manager.show_dialog_sequence([
		{ "text": "「少俠，豆子帶回去給秋嬸了嗎？她剛剛還在廣場邊打轉呢。」", "speaker": 1, "portrait": portrait_path },
	], self)

func _show_normal_dialog(with_quest_epilogue: bool) -> void:
	dialog_lines = _build_lines_for_stage(_get_main_stage_safely())
	var lines := dialog_lines.duplicate(true)
	if with_quest_epilogue:
		lines.append({
			"text": "「少俠，又來買菜？生熟要分清啊。菜是如此，人心也是如此。半熟不熟的，最容易吃壞肚子。」",
			"speaker": 1,
			"portrait": portrait_path,
		})
	dialog_manager.show_dialog_sequence(lines, self)

func _start_green_beans_purchase_flow() -> void:
	dialog_manager.show_dialog_sequence([
		{ "text": "劉語塵：「老闆，我想買一把四季豆。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「唷，少俠識貨！咱家的四季豆脆甜得很，生的拿回去清炒，熟的回去拌蒜鹽，都好吃。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「不過我先說清楚，四季豆這東西可不能馬虎。我這邊也有先炸過一遍的熟豆。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「你要買生的，還是炸過一遍的熟豆？」", "speaker": 1, "portrait": portrait_path },
	], self)
	await dialog_manager.dialog_sequence_finished
	dialog_manager.show_choice([
		{ "text": "買生的四季豆", "callback": Callable(self, "_buy_raw_green_beans") },
		{ "text": "買炸過一遍的熟豆", "callback": Callable(self, "_buy_fried_green_beans") },
	])

func _buy_raw_green_beans() -> void:
	dialog_manager.choice_box.hide_choices()
	dialog_manager.show_dialog_sequence([
		{ "text": "劉語塵：「給我一把生的四季豆。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「好嘞！生的最青脆，回去記得煮熟，別貪那一口爽脆。來，少俠拿好。」", "speaker": 1, "portrait": portrait_path },
	], self)
	if InventorySync:
		InventorySync.add_item_stack(BEAN_RAW_ITEM_ID, 1)
	_set_green_beans_quest_purchase("raw")

func _buy_fried_green_beans() -> void:
	dialog_manager.choice_box.hide_choices()
	dialog_manager.show_dialog_sequence([
		{ "text": "劉語塵：「給我一把炸過一遍的熟豆。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「好選擇！這豆剛炸好沒多久，回去撒點蒜鹽，再滴兩滴醬油，配飯正香。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "劉語塵：「你也察覺琴聲有異？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「嗐，察覺歸察覺，日子還是要過。菜要賣，飯要吃，客人問價還得笑。」", "speaker": 1, "portrait": portrait_path },
	], self)
	if InventorySync:
		InventorySync.add_item_stack(BEAN_FRIED_ITEM_ID, 1)
	_set_green_beans_quest_purchase("fried")

func _set_green_beans_quest_purchase(bean_type: String) -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if quest.is_empty():
		return
	quest["title"] = QUEST_TITLE
	quest["description"] = QUEST_STAGE_2_DESC
	quest["objective"] = QUEST_STAGE_2_DESC
	quest["current_objective"] = QUEST_STAGE_2_DESC
	quest["stage"] = 2
	quest["bean_type"] = bean_type
	quest["notes"] = ["已向阿茂買到四季豆，該回廣場找秋嬸。"]
	quest["note"] = "已向阿茂買到四季豆，該回廣場找秋嬸。"
	SideQuestManager.side_quests[QUEST_ID] = quest

func _get_main_stage_safely() -> int:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s: Dictionary = qm.get_main_quest_state()
		return int(s.get("stage", 1))
	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s2: Dictionary = qm.get_main_quest_state()
		return int(s2.get("stage", 1))
	return 1
