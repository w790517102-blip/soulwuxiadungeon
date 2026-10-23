extends Node2D
class_name YuhengSewerTrueRoom

# ------------------------------------------------------------
# 玉衡鎮｜藥師舊室：《渠燈補封》核心場景
# 掛載：yuheng_sewer_true_room.tscn 根節點
#
# 本場景功能：
# 1. 調查琴、寫字檯、藥櫃，補足「傳承藥師」的場景因果。
# 2. 調查牆符、獅頭水口、渠燈，完成三處補封。
# 3. 三處皆完成後，解鎖書眠技能：澄心落筆、清渠共印。
# 4. 回到 yuheng_sewer_true。
# ------------------------------------------------------------

@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮舊水道・藥師舊室"

@export_file("*.tscn") var yuheng_sewer_true: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true.tscn"
@export var return_spawn_point := "from_yuheng_sewer_true_room"

@export var interact_action := "interact"

@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/Shu_mian/ShuMian_headshot.png"

@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 4

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var to_yuheng_sewer_true: Area2D = get_node_or_null("to_yuheng_sewer_true")

signal dialog_closed

const F_QD_TALISMAN_FIXED := "shumian_qd_talisman_fixed"
const F_QD_WATERHEAD_CHECKED := "shumian_qd_waterhead_checked"
const F_QD_LAMPS_REFILLED := "shumian_qd_lamps_refilled"
const F_QD_DONE := "shumian_clean_sewer_done"

## 最後一道符完成後，各段之間的留白秒數。
const LAST_TALISMAN_PAUSE_SECONDS := 1.4

const F_SKILL_CHENGXIN := "shumian_skill_chengxin_luobi_unlocked"
const F_SKILL_QINGQU := "shumian_skill_qingqu_gongyin_unlocked"

## 已遷移到 InteractionZones（碰撞區／蛋黃區／蛋白區）的互動 ID：舊的 Area2D 退役，避免新舊兩套同時觸發。
## 兩盞燈是兩組區域（fix_channel_lamps、fix_channel_lamps_b），都對應同一個互動 ID。
const MIGRATED_INTERACTION_IDS := [
	"memory_room_qin", "memory_room_writing_desk", "memory_room_medicine_cabinet",
	"loot_old_herb_pouch", "loot_calm_pill",
	"fix_wall_talisman", "fix_lion_waterhead", "fix_channel_lamps",
]

## 滑鼠專用的出口：點蛋黃區，劉語塵走進蛋白區就切換場景，效果與踩進舊的 to_yuheng_sewer_true Area2D 相同（舊 Area2D 保留給鍵盤）。
const EXIT_TARGETS := {
	"exit_sewer_true": "_on_to_yuheng_sewer_true_body_entered",
}

const MEMORY_IDS := [
	"memory_room_qin",
	"memory_room_writing_desk",
	"memory_room_medicine_cabinet",
]

const LOOT_TABLE := {
	"loot_old_herb_pouch": {
		"item_id": "mat_herb_pouch",
		"amount": 1,
		"display_name": "草藥包",
		"lines": [
			"藥櫃下層收著一只小布包，裡頭是分門別類的常見草藥。",
			"書眠：看來藥師當年收得很仔細，連語魅都沒能把它們泡壞。"
		]
	},
	"loot_calm_pill": {
		"item_id": "med_calm_pill",
		"amount": 1,
		"display_name": "清心丸",
		"lines": [
			"琴案旁的小匣中，有一枚以蠟紙包好的藥丸。",
			"書眠：這是清心丸。以前有人心緒太亂，藥師才會取出來。"
		]
	},
}

const FIX_IDS := [
	"fix_wall_talisman",
	"fix_lion_waterhead",
	"fix_channel_lamps",
]

var current_interaction_id := ""
var interaction_locked := false
var transition_locked := false
var _waiting_for_dialog := false
var _space_was_down := false


func _ready() -> void:
	YuhengPrologueState.repair_sewer_loot_items()
	_connect_transition_area()
	_connect_interaction_areas()
	_bind_interaction_zones()

	# 進場黑幕淡出一結束就把操作還給玩家：離開舊水道時 _change_map 把 can_move 關掉了，這個場景沒有人再打開，進來就動不了。
	await _play_entry_fade()
	_set_player_movable(true)
	await show_map_name()


func get_map_display_name() -> String:
	return map_display_name


func _process(_delta: float) -> void:
	if current_interaction_id == "":
		return

	if interaction_locked or transition_locked:
		return

	if _is_interact_pressed():
		await _handle_interaction(current_interaction_id)


func _play_entry_fade() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 1.5

	var tween_in := overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished


func show_map_name() -> void:
	var map_popup := get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0

		await get_tree().create_timer(2.0).timeout

		var popup_tween := map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished

		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")


func _handle_interaction(interaction_id: String) -> void:
	interaction_locked = true
	_set_player_movable(false)

	if MEMORY_IDS.has(interaction_id):
		await _show_dialog(_build_memory_lines(interaction_id))
	elif LOOT_TABLE.has(interaction_id):
		await _handle_loot(interaction_id)
	elif FIX_IDS.has(interaction_id):
		await _handle_fix(interaction_id)
	else:
		await _show_dialog([
			_n("這裡似乎沒有特別可調查的東西。")
		])

	_set_player_movable(true)
	interaction_locked = false


func _build_memory_lines(memory_id: String) -> Array:
	match memory_id:
		"memory_room_qin":
			return [
				_n("房中舊琴置於案上，琴身保存良好，弦色卻顯得沉靜。"),
				_l("這張琴也是藥師留下的？", liuyu_speaker_id, liuyu_portrait_path),
				_l("嗯。", shumian_speaker_id, shumian_portrait_path),
				_l("藥師離開後，這裡的典籍、藥櫃、琴，便一併交給我看管。", shumian_speaker_id, shumian_portrait_path),
				_l("我偶爾興致來了會撥幾聲。", shumian_speaker_id, shumian_portrait_path),
				_l("可自從紅徽音來到玉衡鎮，我便很少再碰它。", shumian_speaker_id, shumian_portrait_path),
				_l("她的琴能入心，我的琴只是識音。", shumian_speaker_id, shumian_portrait_path),
				_l("後來語魅污染此處，我便幾乎沒有動過了。", shumian_speaker_id, shumian_portrait_path),
			]
		"memory_room_writing_desk":
			return [
				_n("寫字檯上收著舊墨、筆架與幾卷藥理札記。"),
				_l("這裡不像孩子們練字的地方。", liuyu_speaker_id, liuyu_portrait_path),
				_l("這裡是藥師研讀與記錄的房間。", shumian_speaker_id, shumian_portrait_path),
				_l("我和藥師共同的回憶不多在這裡。", shumian_speaker_id, shumian_portrait_path),
				_l("更多是他留下的東西，後來交到我手上。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠低頭看向自己手中的墨筆。"),
				_l("這支筆，也是他交給我的。", shumian_speaker_id, shumian_portrait_path),
				_l("原本只是寫字用的筆。", shumian_speaker_id, shumian_portrait_path),
				_l("後來我才明白，一筆落得穩，手也能穩；手能穩，心便不容易亂。", shumian_speaker_id, shumian_portrait_path),
				_l("於是它也成了我的武器。", shumian_speaker_id, shumian_portrait_path),
			]
		"memory_room_medicine_cabinet":
			return [
				_n("藥櫃抽屜密密排開，標籤清楚，藥香柔和而乾淨。"),
				_l("昨夜那些藥材明明已經被霉氣悶壞了。", liuyu_speaker_id, liuyu_portrait_path),
				_l("語魅退去後，它們便回到原本保存良好的樣子。", shumian_speaker_id, shumian_portrait_path),
				_l("這裡本就不是髒污之地。", shumian_speaker_id, shumian_portrait_path),
				_l("只是太多被壓住的話與心念，讓它看起來像病了一樣。", shumian_speaker_id, shumian_portrait_path),
				_l("現在病根暫退，藥氣也終於能透出來。", shumian_speaker_id, shumian_portrait_path),
			]
		_:
			return [_n("這裡似乎承著某段舊日記憶。")]


func _handle_loot(loot_id: String) -> void:
	var flag_name := "shumian_qd_loot_%s_taken" % loot_id
	if _get_flag(flag_name, false):
		await _show_dialog([
			_n("這裡已經沒有可取之物。")
		])
		return

	var data: Dictionary = LOOT_TABLE[loot_id]
	var item_id := str(data.get("item_id", ""))
	var amount := int(data.get("amount", 1))
	var display_name := str(data.get("display_name", item_id))
	var lines: Array = []

	for line in data.get("lines", []):
		lines.append(_n_or_speaker(str(line)))

	# 真正放進背包成功才算領取：領取旗標、背包實際變化、取得提示三者一致。失敗就不寫旗標、不顯示「獲得」，之後還能再拿。
	if not _add_item(item_id, amount):
		await _show_dialog([_n("（背包出了點問題，這件東西沒能收下。請回報。）")])
		return
	_set_flag(flag_name, true)

	lines.append(_n("獲得 %s ×%d。" % [display_name, amount]))
	await _show_dialog(lines)


func _handle_fix(fix_id: String) -> void:
	match fix_id:
		"fix_wall_talisman":
			if _get_flag(F_QD_TALISMAN_FIXED, false):
				await _show_dialog([_n("牆上的舊符已重新補穩。")])
				return

			_set_flag(F_QD_TALISMAN_FIXED, true)
			await _show_dialog([
				_n("牆上的舊符已不再滲出黑氣，但符尾仍有水漬暈開。"),
				_l("這裡先前撐得最苦。", shumian_speaker_id, shumian_portrait_path),
				_l("要重貼？", liuyu_speaker_id, liuyu_portrait_path),
				_l("不必重貼。", shumian_speaker_id, shumian_portrait_path),
				_l("它還認得原本的筆勢。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠以墨筆補上符尾斷線，筆鋒落下時，符紙微微一亮。"),
			])
		"fix_lion_waterhead":
			if _get_flag(F_QD_WATERHEAD_CHECKED, false):
				await _show_dialog([_n("獅頭水口的水聲已比方才順暢許多。")])
				return

			_set_flag(F_QD_WATERHEAD_CHECKED, true)
			await _show_dialog([
				_n("獅頭水口重新吐出清水，水聲比昨夜輕了許多。"),
				_l("這裡也是封印？", liuyu_speaker_id, liuyu_portrait_path),
				_l("是水脈的口。", shumian_speaker_id, shumian_portrait_path),
				_l("水若堵住，濁氣便會在底下打轉。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠俯身檢查水痕，又以筆尖點過石縫，將殘留濁氣引入渠中。"),
			])
		"fix_channel_lamps":
			if _get_flag(F_QD_LAMPS_REFILLED, false):
				await _show_dialog([_n("渠道旁兩盞舊燈已添過燈油，火光安穩。")])
				return

			_set_flag(F_QD_LAMPS_REFILLED, true)
			await _show_dialog([
				_n("渠道旁兩盞舊燈油芯已乾，燈座上仍留著藥草與松脂混成的香氣。"),
				_l("藥師說，水路要有燈。", shumian_speaker_id, shumian_portrait_path),
				_l("給人看路？", liuyu_speaker_id, liuyu_portrait_path),
				_l("也給水看路。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠重新添入燈油，火光映入渠水，水面像被輕輕扶正。"),
			])

	await _check_qudeng_completion()


## 《舊水道・最後一道符》：補符支線真正完成的最後一段。原本的完成流程（三處補封都完成才觸發、只觸發一次、書眠與劉語塵的對話）
## 都保留，這裡是把雙人領悟整合進同一個完成事件，不是另一條平行的完成事件。
##   第一至三幕：水聲、書眠的心境、澄心落筆（對話）
##   第四幕：留白（最後一道符平靜下來），然後才依「實際學會的結果」依序顯示三項領悟提示
## 劉語塵共鳴澄心落筆屬於這場劇情：只在這裡（透過 grant_qudeng_rewards(true)）習得，不會提早，也不會被其他機制先共鳴。
func _check_qudeng_completion() -> void:
	if _get_flag(F_QD_DONE, false):
		return

	if not (_get_flag(F_QD_TALISMAN_FIXED, false) \
		and _get_flag(F_QD_WATERHEAD_CHECKED, false) \
		and _get_flag(F_QD_LAMPS_REFILLED, false)):
		return

	_set_flag(F_QD_DONE, true)
	# 任務紀錄（SideQuestManager）一併標為完成；入隊狀態與啟程狀態互相獨立，這裡不動它們
	YuhengPrologueState.on_qudeng_completed()

	await _show_dialog(_build_last_talisman_lines())

	# 真正習得：書眠的武術與內功、劉語塵的共鳴（都是角色個人的永久武學資料，已學會的不重複）。旗標只是相容保留。
	var reward := YuhengPrologueState.grant_qudeng_rewards(true)

	# 第四幕：留白。先讓畫面安靜一會兒，不立刻跳出提示。
	await get_tree().create_timer(LAST_TALISMAN_PAUSE_SECONDS).timeout
	await _show_dialog([
		_n("牆符、渠燈、水口皆已重新穩住。"),
		_n("最後一道符的墨跡在石壁上安靜地沉了下去，不再顫動。"),
		_n("清水沿著石渠流過，聲音比方才更輕，也更遠。你與書眠並肩望著那道符，誰都沒有出聲。"),
	])
	await get_tree().create_timer(LAST_TALISMAN_PAUSE_SECONDS).timeout

	# 三項領悟提示，分別對應三筆永久學習結果。
	var learned_lines: Array = []
	learned_lines.append(_n("白書眠領悟武術——《澄心落筆》。") if bool(reward["skill_known"]) else _n("（白書眠沒有成功習得《澄心落筆》，請回報。）"))
	learned_lines.append(_n("劉語塵共鳴武術——《澄心落筆》。") if bool(reward["liuyu_known"]) else _n("（劉語塵沒有成功共鳴《澄心落筆》，請回報。）"))
	learned_lines.append(_n("白書眠領悟內功——《清渠共印》。") if bool(reward["inner_force_known"]) else _n("（白書眠沒有成功習得《清渠共印》，請回報。）"))
	await _show_dialog(learned_lines)

	await _show_dialog([
		_ls("劉語塵", "氣息變了。", liuyu_speaker_id, liuyu_portrait_path),
		_ls("書眠", "嗯。", shumian_speaker_id, shumian_portrait_path),
		_ls("書眠", "不是被壓下去。", shumian_speaker_id, shumian_portrait_path),
		_ls("書眠", "是有路可以走了。", shumian_speaker_id, shumian_portrait_path),
		_ls("劉語塵", "這樣，足夠等我們回來？", liuyu_speaker_id, liuyu_portrait_path),
		_ls("書眠", "足夠讓我相信，我不是逃走。", shumian_speaker_id, shumian_portrait_path),
		_ls("書眠", "我是去把風帶回來。", shumian_speaker_id, shumian_portrait_path),
	])


## 第一至三幕。對話格式沿用主遊戲：「角色：「台詞」」，名字與冒號在對話框裡；旁白用第二人稱「你」。
func _build_last_talisman_lines() -> Array:
	var su := func(text: String) -> Dictionary: return _ls("白書眠", text, shumian_speaker_id, shumian_portrait_path)
	var liu := func(text: String) -> Dictionary: return _ls("劉語塵", text, liuyu_speaker_id, liuyu_portrait_path)
	return [
		# 第一幕｜水聲
		_n("補封已近尾聲。最後一道符，只差收尾的一筆。"),
		_n("石室中原本紛亂的回響，漸漸弱了下去。"),
		_n("你聽見一道細微的流水聲。那聲音一直都在，只是先前混在那些嘈雜的殘響裡，幾乎無從分辨。"),
		su.call("……原來，這裡的水聲是這樣的。"),
		liu.call("書眠姑娘？"),
		su.call("我以前來這裡，只顧著聽那些不肯散去的聲音。"),
		su.call("總想著，再多補一道符，再多封住一處……"),
		su.call("鎮上的人，便能少受一點苦。"),
		su.call("可現在想想……有些事情，本來就不是封住了，就能當作沒有發生。"),
		# 第二幕｜白書眠的心境
		su.call("我以前一直怕自己做得不夠。"),
		su.call("怕有哪一道符沒補好，又害得誰在夜裡不得安寧。"),
		liu.call("……"),
		liu.call("原來如此。"),
		liu.call("妳一直想守住的，不只是這幾道符。"),
		su.call("嗯？"),
		liu.call("是那些妳未曾見過，卻仍盼望他們能安穩度日的人。"),
		_n("白書眠微微一怔，握著筆的手緩緩鬆了些。"),
		su.call("……劉少俠。"),
		su.call("謝謝你。"),
		# 第三幕｜澄心落筆
		_n("她再次望向石壁上的符紋。這一次，筆尖不再因猶疑而停頓。"),
		su.call("我想……我終於明白，這最後一筆該怎麼落了。"),
		_n("筆鋒輕輕掠過符紙，墨跡順勢舒展，沒有先前那般急促，也不再刻意收緊。"),
		_n("你望著那道筆勢，忽然想起一路上見過的鎮民，以及他們那些未曾說盡的話。"),
		_n("你不曾經歷書眠獨自守符的每一個夜晚，卻在這一刻，彷彿也能體會她落下這一筆時，心中終於卸去的重量。"),
		liu.call("……這一筆。"),
		su.call("怎麼了？"),
		liu.call("不是為了把什麼再壓下去。"),
		liu.call("而是讓原本紛亂的東西，能夠慢慢靜下來。"),
		_n("白書眠微微一笑。"),
		su.call("嗯。"),
		su.call("這便是……澄心落筆。"),
	]


## 一句「角色：「台詞」」。
func _ls(speaker_name: String, text: String, speaker_id: int, portrait: String) -> Dictionary:
	return _l("%s：「%s」" % [speaker_name, text], speaker_id, portrait)


func _n_or_speaker(text: String) -> Dictionary:
	if text.begins_with("書眠："):
		return _l(text.trim_prefix("書眠："), shumian_speaker_id, shumian_portrait_path)
	if text.begins_with("劉語塵："):
		return _l(text.trim_prefix("劉語塵："), liuyu_speaker_id, liuyu_portrait_path)
	return _n(text)


func _connect_transition_area() -> void:
	if to_yuheng_sewer_true and not to_yuheng_sewer_true.body_entered.is_connected(_on_to_yuheng_sewer_true_body_entered):
		to_yuheng_sewer_true.body_entered.connect(_on_to_yuheng_sewer_true_body_entered)


## 新互動系統（見 InteractionTarget）：InteractionZones 底下每個目標的名字就是互動 ID（結尾 _b 的是同一個互動的第二組區域）。
## 只有空白鍵（臉朝蛋黃區、人在蛋白區裡）或滑鼠點蛋黃區才會互動；走進蛋白區本身不會觸發任何事。
func _bind_interaction_zones() -> void:
	var zones := get_node_or_null("InteractionZones")
	if zones == null:
		return
	for child in zones.get_children():
		var target := child as InteractionTarget
		if target == null:
			continue
		var interaction_id := String(target.name).trim_suffix("_b")
		target.availability = _interaction_available
		if EXIT_TARGETS.has(interaction_id):
			var exit_method: String = EXIT_TARGETS[interaction_id]
			target.handler = func(player: Node2D) -> void:
				await call(exit_method, player)
			continue
		target.handler = func(_player: Node2D) -> void:
			await _handle_interaction(interaction_id)


func _interaction_available() -> bool:
	return not interaction_locked and not transition_locked


func _connect_interaction_areas() -> void:
	var containers := [
		get_node_or_null("InvestigationAreas"),
		get_node_or_null("LootAreas"),
		get_node_or_null("FixPoints"),
	]

	for container in containers:
		if container == null:
			continue

		for child in container.get_children():
			# 已經遷移到新互動系統的舊 Area2D 退役：不再監聽，也不再偵測。
			if MIGRATED_INTERACTION_IDS.has(String(child.name)):
				if child is Area2D:
					(child as Area2D).set_deferred("monitoring", false)
				continue
			if child is Area2D:
				_connect_interaction_area(child as Area2D, child.name)


func _connect_interaction_area(area: Area2D, interaction_id: String) -> void:
	if not area.body_entered.is_connected(_on_interaction_area_body_entered):
		area.body_entered.connect(_on_interaction_area_body_entered.bind(interaction_id))

	if not area.body_exited.is_connected(_on_interaction_area_body_exited):
		area.body_exited.connect(_on_interaction_area_body_exited.bind(interaction_id))


func _on_interaction_area_body_entered(body: Node, interaction_id: String) -> void:
	if _is_player(body):
		current_interaction_id = interaction_id


func _on_interaction_area_body_exited(body: Node, interaction_id: String) -> void:
	if _is_player(body) and current_interaction_id == interaction_id:
		current_interaction_id = ""


func _on_to_yuheng_sewer_true_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if not _map_transition_allowed(body):
		return
	await _change_map(yuheng_sewer_true, return_spawn_point)


func _change_map(scene_path: String, spawn_point_name: String) -> void:
	if transition_locked:
		return

	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = spawn_point_name
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(scene_path)
			return

	get_tree().change_scene_to_file(scene_path)


func _fade_out() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 0.0

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


func _add_item(item_id: String, amount: int) -> bool:
	return YuhengPrologueState.grant_item(item_id, amount)


func _is_interact_pressed() -> bool:
	var pressed_by_action := false
	if InputMap.has_action(interact_action):
		pressed_by_action = Input.is_action_just_pressed(interact_action)

	var space_down := Input.is_key_pressed(KEY_SPACE)
	var pressed_by_space := space_down and not _space_was_down
	_space_was_down = space_down

	return pressed_by_action or pressed_by_space


func _is_player(body: Node) -> bool:
	return body.name == "LiuYu" or body.name == "Player" or body.is_in_group("player")


func _set_player_movable(value: bool) -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")

	if player:
		player.set("can_move", value)


func _get_first_node(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if node:
			return node
	return null


func _show_dialog(lines: Array) -> void:
	var dialog_manager := _get_dialog_manager()

	if dialog_manager == null:
		for line in lines:
			print(line)
		return

	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(lines, self)
		await _wait_dialog_finished(dialog_manager)
		return

	if dialog_manager.has_method("start_dialog"):
		dialog_manager.start_dialog(_lines_to_text_array(lines))
		await _wait_dialog_finished(dialog_manager)
		return

	for line in lines:
		print(line)


func _get_dialog_manager() -> Node:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		return dialog_manager

	dialog_manager = get_node_or_null("/root/DialogManager")
	if dialog_manager:
		return dialog_manager

	return null


func _wait_dialog_finished(dialog_manager: Node) -> void:
	if dialog_manager.has_signal("dialog_sequence_finished"):
		await dialog_manager.dialog_sequence_finished
	elif _waiting_for_dialog:
		await dialog_closed

	_waiting_for_dialog = false


func reset_dialog_state() -> void:
	if _waiting_for_dialog:
		_waiting_for_dialog = false
		dialog_closed.emit()


func _lines_to_text_array(lines: Array) -> Array[String]:
	var result: Array[String] = []
	for line in lines:
		if line is Dictionary and line.has("text"):
			result.append(str(line["text"]))
		else:
			result.append(str(line))
	return result


func _l(text: String, speaker: int, portrait: String = "") -> Dictionary:
	return {
		"text": text,
		"speaker": speaker,
		"portrait": portrait if portrait != "" else empty_portrait_path,
	}


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": narration_speaker_id,
		"portrait": empty_portrait_path,
	}


func _get_flag(flag_name: String, default_value = null):
	var global_state := _get_global_state()
	if global_state == null:
		return default_value

	if global_state.has_method("get_flag"):
		var value = global_state.get_flag(flag_name)
		if value == null:
			return default_value
		return value

	var value = global_state.get(flag_name)
	if value == null:
		return default_value

	return value


func _set_flag(flag_name: String, value) -> void:
	var global_state := _get_global_state()
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
		return

	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)


func _get_global_state() -> Node:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state:
		return global_state

	global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state:
		return global_state

	return null


## 與其他場景的出口一致：交給 GameRoot 的出口防呆（剛換場景的冷卻時間、讀檔中、鎖定中都不能換）。
func _map_transition_allowed(body: Node) -> bool:
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root == null or not game_root.has_method("can_use_map_transition"):
		return true
	return bool(game_root.call("can_use_map_transition", body, null))
