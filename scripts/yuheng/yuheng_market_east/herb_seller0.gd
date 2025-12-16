extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 60.0
@export var use_path_patrol := true
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D
var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var last_direction := Vector2.DOWN
var last_idle_direction := Vector2.DOWN
var is_talking: bool = false
var has_recently_talked: bool = false
var patrol_progress := 0.0
var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO

# ---- 旗標鍵 ----
const FLAG_MET := "met_apothecary"
const FLAG_HERB_COUNT := "got_valley_herb"        # Int
const FLAG_REWARD := "herb_reward_claimed"        # Bool

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[Apothecary] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[Apothecary] PathFollow2D 沒有設定或找不到：" + str(path_node))

	previous_position = global_position

	var main_stage := _get_main_stage_safely()
	dialog_lines = _build_lines_for_stage(main_stage)

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

	if is_talking or has_recently_talked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if use_path_patrol and path_ref:
		patrol_progress += wander_speed * delta
		path_ref.progress = patrol_progress
		var new_position = path_ref.global_position
		var movement_dir = (new_position - previous_position).normalized()
		global_position = new_position
		_play_directional_anim(movement_dir)
		previous_position = new_position
		return
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = wander_interval
			wander_target = global_position + Vector2(
				randi_range(-wander_range, wander_range),
				randi_range(-wander_range, wander_range))
		var dir = (wander_target - global_position).normalized()
		velocity = dir * wander_speed
		if velocity.length() > 1:
			_play_directional_anim(dir)
		else:
			velocity = Vector2.ZERO
			if last_direction.distance_to(last_idle_direction) > 0.1:
				last_idle_direction = last_direction
			var idle_anim = _get_anim_by_vector(last_idle_direction, "idle")
			if animated_sprite.sprite_frames.has_animation(idle_anim):
				animated_sprite.play(idle_anim)
		move_and_slide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func _unhandled_input(event):
	if not can_interact:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true

		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)

		# 播放本輪對話
		dialog_manager.show_dialog_sequence(dialog_lines, self)
		await dialog_manager.dialog_sequence_finished

		# 首次談完 → 落旗、重建為循環短句
		if not GlobalState.get_flag(FLAG_MET):
			GlobalState.set_flag(FLAG_MET, true)
			dialog_lines = _build_lines_for_stage(_get_main_stage_safely())

		# 若已集滿 3 朵且尚未領過回饋 → 給一次性折扣提示
		var herb_count := int(GlobalState.triggered_flags.get(FLAG_HERB_COUNT, 0))
		if herb_count >= 3 and not GlobalState.get_flag(FLAG_REWARD):
			await _process_valley_herb_reward()

		# 提供商店進入選項（可選）
		await _offer_shop_choice()

		liuyu.can_move = true
		is_talking = false

func reset_dialog_state():
	var liuyu := get_node("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true
	is_talking = false

# ---------------- 台詞組裝 ----------------

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag(FLAG_MET)

	# 首次長篇
	if not met:
		return [
			{ "text": "我是在這裡行腳賣藥的，背上這一籃，都是山裡風月熬出來的藥。", "speaker": 1 },
			{ "text": "這鎮上氣息倒是奇——風不起，心也不起，每個人的情緒像被薄紗罩著", "speaker": 1 },
			{ "text": "平靜的不正常，看是那茶坊裡的琴音所致。", "speaker": 1 },
			{ "text": "(!!!)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "老爺爺,難道你也察覺到鎮上的異常了?)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "(賣藥翁伸出食指做勢比出禁聲的動作)別大聲嚷嚷。\n少俠, 你我都不是常駐在玉衡鎮的人,自然能發現其中違和之處,\n然,吾今以醫者的角度分析這裡的狀態,你儘管聽就是了\n這世道正在流行一種『瘟疫』,一種透過言語傳染的病\n玉衡鎮啊,為了避免感染瘟疫而下了猛藥", "speaker": 1 },
			{ "text": "既然此病,是靠言者說話時激起的情緒傳染, 那麼只要當言語快到動情之時加以壓制, 必定能阻止傳染途徑", "speaker": 1 },
			{ "text": "然而如同河流, 若一昧的建壩築堤, 將本來該流入大海的江水堵住, 而不做出適當的洩洪,那麼潰堤也只是遲早的事...", "speaker": 1 },
			{ "text": "真要安神，藥得慢，氣得順；若一味壓住，久了也傷。", "speaker": 1 },
			{ "text": "果然，縱使獲得內心平靜，但情緒長期受抑", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "對內心神智而言已經造成極大的負擔了", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "老爺爺, 你想講的就是這個吧? 現在玉衡鎮有些話不能講得太清楚,特別是那些會激起情緒的話語, 所以你才以醫藥之道藉彼玉此, 我懂了", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "少俠你是聰明人, 聽得懂我的言外之意, 我本來是想要給你點『安神不滯散』，讓你不悶心，不滯口…", "speaker": 1 },
			{ "text": "可惜少了一味『谷影草』，藥性才算全，唉。", "speaker": 1 },
			{ "text": "(嗯，現在這種節骨眼，如果身上能多點良方妙藥未必是一件壞事)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "(也許我可以幫助他找到那缺少的藥材?)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		]

	# 循環短句（主線前期）
	if main_stage <= 2:
		return [
			{ "text": "少俠我本來是想要給你點『安神不滯散』", "speaker": 1 },
			{ "text": "可惜少了一味『谷影草』，藥性才算全，唉。", "speaker": 1 },
			{ "text": "(也許我可以幫助他找到那缺少的藥材?)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "老先生，若我幫您尋得那谷影草，您當真能將那『安神不滯散』熬出來?", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "醫者仁心，我不騙你。", "speaker": 1 },
			{ "text": "日頭偏西時，廣場石牆根下陰影最足，能見三朵。若你肯幫我摘來——這方子半價賣你一次。", "speaker": 1 }
			
		]

	# 主線中期：評琴與氣
	if main_stage <= 6:
		return [
			{ "text": "琴聲善，善亦有度。善若過度，亦成執。", "speaker": 1 },
			{ "text": "此地群情雖平，卻像風停於谷，久之易悶。", "speaker": 1 },
		]

	# 主線後期：白鳶橫天後
	return [
		{ "text": "白鳶橫天，似給谷口開了風眼。", "speaker": 1 },
		{ "text": "願君持衡：弦不傷人，心不傷己。", "speaker": 1 },
	]

# 谷影草回饋（一次性折扣）
func _process_valley_herb_reward() -> void:
	dialog_manager.show_dialog_sequence([
		{ "text": "這谷影草……你居然找齊了。", "speaker": 1 },
		{ "text": "我守一諾：『安神不滯散』半價一次。記在你名下。", "speaker": 1 }
	], self)
	await dialog_manager.dialog_sequence_finished
	GlobalState.set_flag(FLAG_REWARD, true)

# 商店選項（依你現有 UI 取代 open_shop）
func _offer_shop_choice() -> void:
	dialog_manager.show_choice([
		{ "text": "看看藥材", "callback": Callable(self, "_open_shop_now") },
		{ "text": "下次再買", "callback": Callable(self, "_close_choice_only") },
	])

func _open_shop_now():
	dialog_manager.choice_box.hide_choices()
	# TODO: 這裡接你的商店系統；可讀取 FLAG_REWARD 判斷一次性折扣
	open_shop()  # 先留空實作

func _close_choice_only():
	dialog_manager.choice_box.hide_choices()

func open_shop():
	# 你的商店 UI 打開邏輯；若要測試，先 print 代替
	print("[Shop] 開店啦（可讀取 GlobalState.get_flag('%s') 作折扣）" % FLAG_REWARD)

# ---------------- 工具函式 ----------------

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

func _play_directional_anim(dir: Vector2):
	if dir.length() < 0.1: return
	last_direction = dir
	var anim_name = _get_anim_by_vector(dir, "walk")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		animated_sprite.play("idle_down")

func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle = dir.angle()
	if angle >= -PI * 7/8 and angle < -PI * 5/8: return "%s_left_up" % prefix
	elif angle >= -PI * 5/8 and angle < -PI * 3/8: return "%s_up" % prefix
	elif angle >= -PI * 3/8 and angle < -PI * 1/8: return "%s_right_up" % prefix
	elif angle >= -PI * 1/8 and angle < PI * 1/8: return "%s_right" % prefix
	elif angle >= PI * 1/8 and angle < PI * 3/8: return "%s_right_down" % prefix
	elif angle >= PI * 3/8 and angle < PI * 5/8: return "%s_down" % prefix
	elif angle >= PI * 5/8 and angle < PI * 7/8: return "%s_left_down" % prefix
	else: return "%s_left" % prefix

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
	last_idle_direction = direction
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
