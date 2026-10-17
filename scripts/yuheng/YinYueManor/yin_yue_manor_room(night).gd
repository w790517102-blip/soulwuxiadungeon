extends Node2D
class_name YinYueManorRoomNight

# ------------------------------------------------------------
# 飲月山莊・夜間會談
# 掛載：yin_yue_manor_room(night).tscn 根節點
#
# 流程：
# 1. 鐘乳石洞魚怪戰後進入本場景，踩到 trigger 後啟動會談。
# 2. 左飲說「坐」後，劉語塵與書眠沿 Path2D 移動到座位，播放 sit_right_up。
# 3. 會談結束，眾人起身；黑幕留宿一晚（旁白字幕），切換到飲月山莊白天場景。
# 4. 翌日白天的自由探索、書眠支線入口與左飲啟程入口都在 yin_yue_manor_room(day).gd；
#    狀態（旗標、入隊、支線）統一放在 YuhengPrologueState.gd。
# ------------------------------------------------------------

@export var music_tag := "yuheng"
@export var map_display_name: String = "飲月山莊・夜間"

## 留宿一晚之後的飲月山莊白天場景與出生點（沿用既有的白天場景資源）。
@export_file("*.tscn") var yin_yue_manor_room_day := "res://scenes/yuheng/YinYueManor/yin_yue_manor_room/yin_yue_manor_room(day).tscn"
@export var day_spawn_point_name := "from_YinYueManor"

# 對話頭像 / speaker id，若你專案 ID 不同可在 Inspector 調。
## 頭像規則：劉語塵固定用原本的頭像、固定走下方對話框（speaker id 2）。其他角色：在上方對話框（speaker id 不是 2，
## 這裡是 4 / 5 / 6）用原本的頭像；若改成下方對話框（speaker id 2，例如洞穴的戰後對話）則用結尾是 2 的那張（*_headshot2.png）。
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/NPC/Yuheng/Su_Mien_headshot.png"
@export var zuoyin_portrait_path := "res://assets/sprites/NPC/Yuheng/Zuo_Yin_headshot.png"
@export var huiyin_portrait_path := "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"

@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 4
@export var huiyin_speaker_id := 5
@export var zuoyin_speaker_id := 6

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var event_area: Area2D = get_node_or_null("yin_yue_manor_event_trigger/yin_yue_manor_event_trigger")

@onready var liuyu_go_path: Path2D = get_node_or_null("yin_yue_manor_event_trigger/Liu_yu_go_path")
@onready var shumian_go_path: Path2D = get_node_or_null("yin_yue_manor_event_trigger/Su_mien_go_path")
@onready var shumian_back_path: Path2D = get_node_or_null("yin_yue_manor_event_trigger/Su_mien_back_path")

@onready var liuyu_initial_point: Marker2D = get_node_or_null("SpawnPoints/Liu_yu_Initial_point")
@onready var zuoyin_initial_point: Marker2D = get_node_or_null("SpawnPoints/Zuo_yin_Initial_point")
@onready var shumian_initial_point: Marker2D = get_node_or_null("SpawnPoints/Su_mien_Initial_point")

@onready var shumian_npc: Node2D = get_node_or_null("Su_mien")
@onready var zuoyin_npc: Node2D = get_node_or_null("Zuo_yin")
@onready var huiyin_npc: Node2D = get_node_or_null("Hong_Huei_Yin")
@onready var huiyin_initial_point: Marker2D = get_node_or_null("SpawnPoints/hong_hui_yin_point")

## 紅徽音站著（idle_<方向>）與坐著（sit_<方向>）的動畫在 Hong_Huei_Yin.tscn；夜間會談她站在 hong_hui_yin_point，朝向座墊。
const HUIYIN_STAND_ANIMATION := "idle_right_down"
## 場景轉換（淡入與地圖名稱）之後，先等這麼久才開始劇情。
const SCENE_START_DELAY_SECONDS := 2.0
const HUIYIN_SIT_ANIMATION := "sit_right_down"
## 紅徽音的顏色比原圖淡一點（1.0 = 原色）；她的大小用醉月茶坊的比例（場景裡實例縮放 0.8）。
const HUIYIN_SATURATION := 0.62
const HUIYIN_DESATURATE_SHADER := """
shader_type canvas_item;
uniform float saturation : hint_range(0.0, 1.0) = 0.62;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(grey), c.rgb, saturation), c.a);
}
"""
## 入座的順序：兩人同時走向座墊，白書眠先坐，很快紅徽音再坐，頓一下之後劉語塵才坐。
const SHUMIAN_PATH_SECONDS := 1.0
const LIUYU_PATH_SECONDS := 1.25
const HUIYIN_SIT_DELAY_SECONDS := 0.4
const LIUYU_SIT_PAUSE_SECONDS := 0.6
## 夜談結束、大家起身之後，到黑幕留宿之前的停頓。
const MEETING_END_PAUSE_SECONDS := 1.0
## 留宿字幕（每段淡入、停留、淡出，之後的白天場景自己淡入）。
const OVERNIGHT_CAPTIONS := [
	"夜已深了。左飲命人收拾客房，留你與白書眠在飲月山莊歇息一晚。",
	"這一夜，山莊難得平靜。",
	"待你再次睜眼時，晨光已悄然透過窗紙。",
]
const OVERNIGHT_CAPTION_FADE_SECONDS := 0.3
const OVERNIGHT_CAPTION_HOLD_SECONDS := 1.8
const OVERNIGHT_CAPTION_GAP_SECONDS := 0.2

signal dialog_closed

# ------------------------------------------------------------
# Flags
# ------------------------------------------------------------
const F_AFTER_FISH_READY := YuhengPrologueState.F_AFTER_FISH_READY
const F_NIGHT_MEETING_DONE := YuhengPrologueState.F_NIGHT_MEETING_DONE
const F_OVERNIGHT_DONE := YuhengPrologueState.F_OVERNIGHT_DONE

var story_locked := false
var transition_locked := false
var _waiting_for_dialog := false


func _ready() -> void:
	if zuoyin_initial_point and zuoyin_npc:
		_play_anim(zuoyin_npc, "idle_left_down")
		_place_feet_on_marker(zuoyin_npc, zuoyin_initial_point)

	if huiyin_npc:
		_play_anim(huiyin_npc, HUIYIN_STAND_ANIMATION)
		_place_feet_on_marker(huiyin_npc, huiyin_initial_point)
		_desaturate_huiyin()

	if shumian_initial_point and shumian_npc and not _get_flag(F_NIGHT_MEETING_DONE, false):
		shumian_npc.global_position = shumian_initial_point.global_position
		# 夜談開始前，書眠站著、面向右上（Su_mien.tscn 的預設姿勢是共用的，不能靠它；隔天白天在日間場景才改成右下）
		_play_anim(shumian_npc, "idle_right_up")

	if event_area:
		if not event_area.body_entered.is_connected(_on_yin_yue_manor_event_trigger_body_entered):
			event_area.body_entered.connect(_on_yin_yue_manor_event_trigger_body_entered)
	else:
		push_warning("找不到 yin_yue_manor_event_trigger/yin_yue_manor_event_trigger。")

	await _play_entry_fade()
	await show_map_name()

	if _get_flag(F_NIGHT_MEETING_DONE, false):
		# 夜談已經結束：不重播夜談，也不重複留宿（留宿字幕只在尚未留宿時播一次）
		_disable_event_area()
		await _go_to_next_morning(not _get_flag(F_OVERNIGHT_DONE, false))
	else:
		# 場景轉換之後先等一下，才開始劇情（回訪這個場景時不用等）
		await get_tree().create_timer(SCENE_START_DELAY_SECONDS).timeout
		await _check_initial_overlap_for_event()


func get_map_display_name() -> String:
	return map_display_name


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


## 角色站在出生點（SpawnPoints 的 Marker2D）上，指的是「畫面上看到的腳底中心」對準 marker，而不是場景裡人物節點
## 的原點（各角色的節點原點與 sprite 位置不同）。由目前這一格圖的不透明像素算出腳底中心，再把節點平移到對得上。
var _feet_cache: Dictionary = {}


func _feet_offset_in_sprite(sprite: AnimatedSprite2D) -> Vector2:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(sprite.animation):
		return Vector2.ZERO
	var texture: Texture2D = frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Vector2.ZERO
	var key := "%s|%s" % [texture.get_rid().get_id(), str(texture.get_size())]
	if texture is AtlasTexture:
		key = "%d|%s" % [(texture as AtlasTexture).atlas.get_rid().get_id(), str((texture as AtlasTexture).region)]
	if not _feet_cache.has(key):
		var image := texture.get_image()
		var bottom := -1
		var left := 1 << 30
		var right := -1
		if image != null:
			for y in range(image.get_height() - 1, -1, -1):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a > 0.3:
						bottom = maxi(bottom, y)
						left = mini(left, x)
						right = maxi(right, x)
				if bottom >= 0 and y < bottom - 6:
					break
		var size := texture.get_size()
		_feet_cache[key] = Vector2(((left + right) * 0.5 + 0.5 - size.x * 0.5) if right >= 0 else 0.0, (bottom + 1.0 - size.y * 0.5) if bottom >= 0 else size.y * 0.5)
	var local: Vector2 = _feet_cache[key]
	return sprite.position + local * sprite.scale


## 把 node 平移到：畫面上的腳底中心正好落在 marker 上。
func _place_feet_on_marker(node: Node2D, marker: Marker2D) -> void:
	if node == null or marker == null:
		return
	var sprite := _find_animated_sprite(node)
	if sprite == null:
		node.global_position = marker.global_position
		return
	var foot_global: Vector2 = node.to_global(_feet_offset_in_sprite(sprite))
	node.global_position += marker.global_position - foot_global


## 前後遮擋：誰在畫面上站得比較低（腳底的 y 比較大），誰就畫在前面。劉語塵的腳本是 z_index = 他的原點 y + z_index_offset，
## 但各角色的節點原點離腳底的距離不同（白書眠、紅徽音、左飲的節點本身沒有腳本，z 一直是 0），所以這裡每一幀用「腳底」的 y
## 算出所有人的 z：NPC 直接設 z_index，劉語塵則調整他的 z_index_offset（離開場景時還原）。
func _process(_delta: float) -> void:
	_sync_depth_with_feet()


func _exit_tree() -> void:
	var player := _get_player()
	if player != null and is_instance_valid(player):
		player.set("z_index_offset", 0)
		_set_liuyu_sit_scale(player, false)


func _sync_depth_with_feet() -> void:
	for npc: Node2D in [zuoyin_npc, shumian_npc, huiyin_npc]:
		if npc == null or not is_instance_valid(npc):
			continue
		var sprite := _find_animated_sprite(npc)
		if sprite == null:
			continue
		npc.z_index = int(npc.to_global(_feet_offset_in_sprite(sprite)).y)
	var player := _get_player()
	if player != null and is_instance_valid(player):
		var player_sprite := _find_animated_sprite(player)
		if player_sprite != null:
			var feet_y: float = player.to_global(_feet_offset_in_sprite(player_sprite)).y
			player.set("z_index_offset", int(feet_y - player.global_position.y))


## 紅徽音的顏色壓低飽和度（只對這個場景的實例）。
func _desaturate_huiyin() -> void:
	var sprite := _find_animated_sprite(huiyin_npc)
	if sprite == null:
		return
	var shader := Shader.new()
	shader.code = HUIYIN_DESATURATE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("saturation", HUIYIN_SATURATION)
	sprite.material = material


func _check_initial_overlap_for_event() -> void:
	if event_area == null:
		return

	await get_tree().process_frame
	await get_tree().physics_frame

	for body in event_area.get_overlapping_bodies():
		if _is_player(body):
			await _start_night_meeting()
			return


# ------------------------------------------------------------
# 主事件：夜間會談
# ------------------------------------------------------------
func _on_yin_yue_manor_event_trigger_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if story_locked or _get_flag(F_NIGHT_MEETING_DONE, false):
		return

	# 只在魚怪戰後待會談狀態觸發。若你想 debug，可暫時註解這段。
	if not _get_flag(F_AFTER_FISH_READY, true):
		return

	await _start_night_meeting()


func _start_night_meeting() -> void:
	if story_locked:
		return

	story_locked = true
	_disable_event_area()
	_set_player_movable(false)

	var liuyu := _get_player()

	_play_anim(liuyu, "idle_right_up")
	_play_anim(shumian_npc, "idle_right_up")
	_play_anim(zuoyin_npc, "idle_left_down")

	await _show_dialog(_build_meeting_opening_lines())

	# 左飲說「坐」以後，角色真的移動到座位。
	await _move_liuyu_and_shumian_to_seats()

	await _show_dialog(_build_meeting_main_lines())

	# 會談結尾，大家起身。夜談到此結束：書眠的支線與烈風寨的啟程都留到翌日白天，由玩家自己選。
	_set_liuyu_sit_scale(liuyu, false)
	_play_anim(liuyu, "idle_right_up")
	_play_anim(shumian_npc, "idle_right_up")
	_play_anim(huiyin_npc, HUIYIN_STAND_ANIMATION)
	_place_feet_on_marker(huiyin_npc, huiyin_initial_point)

	await get_tree().create_timer(MEETING_END_PAUSE_SECONDS).timeout

	_set_flag(F_NIGHT_MEETING_DONE, true)
	_set_flag(YuhengPrologueState.F_READY_FOR_QINGFENG, true)
	_set_flag(YuhengPrologueState.F_SHUMIAN_SIDE_AVAILABLE, true)
	_set_flag(YuhengPrologueState.F_SHUMIAN_JOIN_PENDING, true)

	# 留宿一晚（黑幕＋旁白字幕）→ 飲月山莊白天。留宿只在這裡走一次。
	await _go_to_next_morning(true)


func _build_meeting_opening_lines() -> Array:
	return [
		_n("紅徽音坐在屏風旁，琴匣未開。屋中燈火不亮，卻足以映出每個人臉上的疲色。"),
		_l("你們回來了。", huiyin_speaker_id, huiyin_portrait_path),
		_l("徽音……", shumian_speaker_id, shumian_portrait_path),
		_l("你受傷了嗎？", huiyin_speaker_id, huiyin_portrait_path),
		_l("沒有。", shumian_speaker_id, shumian_portrait_path),
		_l("坐。", zuoyin_speaker_id, zuoyin_portrait_path),
	]


func _build_meeting_main_lines() -> Array:
	return [
		_l("墨鱗魘將已經退了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("退了，不代表結束。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("牠不是始作俑者。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("只是下面積的東西，先長成了牠。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……是我沒有把符補好。", shumian_speaker_id, shumian_portrait_path),
		_l("不是只有妳。", huiyin_speaker_id, huiyin_portrait_path),
		_l("那些符是我貼的。", shumian_speaker_id, shumian_portrait_path),
		_l("琴聲，是我壓的。", huiyin_speaker_id, huiyin_portrait_path),
		_l("外頭那些東西，是我沒斬乾淨。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……我不覺得這件事該由誰一個人負起全責。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你們幾個，都很在乎玉衡鎮。", liuyu_speaker_id, liuyu_portrait_path),
		_l("只是……你們各自守著的，似乎都只有其中一段。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……我以為，還有時間。", shumian_speaker_id, shumian_portrait_path),
		_l("至少在找到別的辦法以前……還能再撐一陣。", shumian_speaker_id, shumian_portrait_path),
		_l("我知道琴聲壓住的東西，並沒有真的消失。", huiyin_speaker_id, huiyin_portrait_path),
		_l("所以我一直以為……到了夜裡，人在夢裡，總還能慢慢把那些東西放出來。", huiyin_speaker_id, huiyin_portrait_path),
		_l("書眠。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯？", shumian_speaker_id, shumian_portrait_path),
		_l("妳先前在舊水道看到的那句話……", liuyu_speaker_id, liuyu_portrait_path),
		_l("『心亂則語生，語腐則水濁，水濁則夢驚。』", liuyu_speaker_id, liuyu_portrait_path),
		_l("……嗯。", shumian_speaker_id, shumian_portrait_path),
		_l("我在想……這句話，恐怕本來就不是一條走到底的路。", liuyu_speaker_id, liuyu_portrait_path),
		_n("眾人安靜了片刻。"),
		_l("而是一個圈。", liuyu_speaker_id, liuyu_portrait_path),
		_l("白日裡壓下去的東西……到了夜裡，又從夢裡翻上來。", huiyin_speaker_id, huiyin_portrait_path),
		_l("夢驚……便又使人心亂。", shumian_speaker_id, shumian_portrait_path),
		_l("心一亂，語魅便再生。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("然後又回到水裡。", liuyu_speaker_id, liuyu_portrait_path),
		_n("屋中一時無人開口。"),
		_n("那條藏在玉衡鎮地底、日復一日循環的路，直到此刻，才終於在幾人面前接成了完整的一圈。"),
		_l("而我只顧著外面。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("結果，我們都只守住了自己看得見的那一面。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲沉默了一會兒，忽然抬眼看向你。"),
		_l("說起來……你一路找我，總不會只是為了玉衡鎮。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("確實不是。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我在找一本秘笈。", liuyu_speaker_id, liuyu_portrait_path),
		_n("左飲看了你片刻。"),
		_l("……讖語破心訣？", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左莊主知道？", liuyu_speaker_id, liuyu_portrait_path),
		_l("知道些。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("至少知道，該去問誰。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("翼軫鎮。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("映火樓樓主，聞燈。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("他手上未必有《讖語破心訣》。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("但若論它的下落……他知道的，應該比我多。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("聞燈……", liuyu_speaker_id, liuyu_portrait_path),
		_l("本來，等這裡的事情結束，我可以帶你去一趟。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你替玉衡鎮做了這麼多，又護著書眠一路走到現在。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("這份情，我總該還。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲停了一下。"),
		_l("可現在看來……還不行。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("因為玉衡鎮？", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("墨鱗魘將沒了，只是眼前這一場停了。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("底下那個圈，還在。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我現在若走，沒人知道下一次會從哪裡冒出來。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("玉衡鎮不能再只靠壓。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("那要靠什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("疏。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("壓得住一時。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("疏得通，才撐得久。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("我的琴能壓心。", huiyin_speaker_id, huiyin_portrait_path),
		_l("可現在的曲，做不到讓那些情緒自己走完。", huiyin_speaker_id, huiyin_portrait_path),
		_l("我的詩能替人留一個出口。", shumian_speaker_id, shumian_portrait_path),
		_l("可光靠詩，也接不住整座鎮子。", shumian_speaker_id, shumian_portrait_path),
		_l("所以，要讓我真的離得開這裡——", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲看向紅徽音。"),
		_l("得先讓她換一首曲。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你知道有這樣的曲？", liuyu_speaker_id, liuyu_portrait_path),
		_l("知道。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("《白鳶橫天》。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("若能讓那些情緒真正有地方可去……", liuyu_speaker_id, liuyu_portrait_path),
		_l("至少，不會再像這次一樣，在地底養出第二頭墨鱗魘將。", liuyu_speaker_id, liuyu_portrait_path),
		_l("正是。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("你沉默片刻。"),
		_n("你原本只是想找到左飲，循著他的線索繼續追查《讖語破心訣》。"),
		_n("可走到如今，你已無法把玉衡鎮發生的一切，當成與自己無關的岔路。"),
		_l("好。", liuyu_speaker_id, liuyu_portrait_path),
		_l("《白鳶橫天》，我去找。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("你已經替玉衡鎮走了一趟。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("照理說，該是我還你的時候。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("結果現在，反倒還要再請你替我跑一趟。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左莊主不必算得這麼清。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我算。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("這一次，我再欠你。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("那等玉衡鎮真的穩下來。", liuyu_speaker_id, liuyu_portrait_path),
		_l("再勞煩左莊主陪我去一趟翼軫鎮。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("到時候，我帶你去見聞燈。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("《白鳶橫天》現在在哪裡？", liuyu_speaker_id, liuyu_portrait_path),
		_l("烈風寨。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("列霄手上。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("話音才落，紅徽音搭在琴匣上的手指便微微一頓。她沒有立刻抬頭，只是眉間極輕地收了一下。"),
		_l("……偏偏是他。", huiyin_speaker_id, huiyin_portrait_path),
		_l("妳認得列霄？", liuyu_speaker_id, liuyu_portrait_path),
		_l("認得。", huiyin_speaker_id, huiyin_portrait_path),
		_l("我師兄。", huiyin_speaker_id, huiyin_portrait_path),
		_n("她停了一下。"),
		_l("以前是。", huiyin_speaker_id, huiyin_portrait_path),
		_l("他們都是弦禪子的弟子。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左飲。", huiyin_speaker_id, huiyin_portrait_path),
		_l("總得讓他知道要去見誰。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("所以我才不想欠他。", huiyin_speaker_id, huiyin_portrait_path),
		_n("她頓了一下。"),
		_l("……但現在不是計較這些的時候。", huiyin_speaker_id, huiyin_portrait_path),
		_l("劉少俠，我也去。", shumian_speaker_id, shumian_portrait_path),
		_l("書眠，舊水道的那些符，妳還沒回去看。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……我知道。", shumian_speaker_id, shumian_portrait_path),
		_l("若還有放不下的事，就趁出發前去看一眼。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("但路要怎麼走，妳自己決定。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("……書眠。", huiyin_speaker_id, huiyin_portrait_path),
		_n("白書眠抬頭。"),
		_l("去看看吧。", huiyin_speaker_id, huiyin_portrait_path),
		_l("不是為了補給誰看。", huiyin_speaker_id, huiyin_portrait_path),
		_l("只是去看看。", huiyin_speaker_id, huiyin_portrait_path),
	]


# ------------------------------------------------------------
# 夜談之後：留宿一晚 → 飲月山莊白天
# ------------------------------------------------------------
## 黑幕遮住畫面 → （第一次才）旁白字幕 → 載入白天場景 → 白天場景自己淡入，並把控制權還給玩家。
## 留宿只走一次：F_OVERNIGHT_DONE 在載入白天場景之前才設定，之後再回到這個場景只會直接前往白天，不再播字幕。
func _go_to_next_morning(play_captions: bool) -> void:
	if transition_locked:
		return
	transition_locked = true
	_set_player_movable(false)

	await _fade_out()
	if play_captions:
		await _play_overnight_captions()

	_set_flag(F_OVERNIGHT_DONE, true)
	_advance_main_quest_after_night_meeting()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root and game_root.has_method("change_map_to"):
		game_root.spawn_point_name = day_spawn_point_name
		game_root.change_map_to(yin_yue_manor_room_day)
		return

	get_tree().change_scene_to_file(yin_yue_manor_room_day)


func _advance_main_quest_after_night_meeting() -> void:
	# 夜談結束時主線進到「準備前往烈風寨」；真正啟程（轉場成功）才會進到烈風寨章（左飲 NPC 那邊處理）。
	if QuestManager and QuestManager.get_main_stage() < QuestManager.STAGE_YH_NIGHT_MEETING + 1:
		QuestManager.advance_main_quest(
			QuestManager.STAGE_YH_NIGHT_MEETING,
			"準備前往烈風寨。可先與書眠談談，準備好了再與左飲對話出發。"
		)


## 黑幕上的旁白字幕（和鐘乳石洞戰後的返程字幕同一種做法：CanvasLayer 上的置中文字，逐段淡入、停留、淡出）。
func _play_overnight_captions() -> void:
	var canvas_layer := get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas_layer == null:
		push_warning("飲月山莊夜間場景找不到 CanvasLayer，留宿字幕將略過。")
		return

	var caption := Label.new()
	caption.name = "OvernightCaption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94, 1.0))
	caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_font_size_override("font_size", 24)
	caption.modulate.a = 0.0
	canvas_layer.add_child(caption)
	var viewport_size := get_viewport_rect().size
	caption.position = Vector2(viewport_size.x * 0.1, 0.0)
	caption.size = Vector2(viewport_size.x * 0.8, viewport_size.y)

	for caption_text in OVERNIGHT_CAPTIONS:
		caption.text = String(caption_text)
		caption.modulate.a = 0.0
		var caption_tween := caption.create_tween()
		caption_tween.tween_property(caption, "modulate:a", 1.0, OVERNIGHT_CAPTION_FADE_SECONDS)
		caption_tween.tween_interval(OVERNIGHT_CAPTION_HOLD_SECONDS)
		caption_tween.tween_property(caption, "modulate:a", 0.0, OVERNIGHT_CAPTION_FADE_SECONDS)
		await caption_tween.finished
		await get_tree().create_timer(OVERNIGHT_CAPTION_GAP_SECONDS).timeout

	caption.queue_free()


# ------------------------------------------------------------
# 移動 / 動畫
# ------------------------------------------------------------
func _move_liuyu_and_shumian_to_seats() -> void:
	var liuyu := _get_player()

	# 兩人同時走向座墊（到了才各自入座，所以這裡不帶結束動畫）
	var tween_liuyu := _create_move_tween_along_path(liuyu, liuyu_go_path, LIUYU_PATH_SECONDS, "walk_right_up", "")
	var tween_shumian := _create_move_tween_along_path(shumian_npc, shumian_go_path, SHUMIAN_PATH_SECONDS, "walk_right_up", "")

	# 白書眠先坐
	if tween_shumian:
		await tween_shumian.finished
	_play_anim(shumian_npc, "sit_right_up")

	# 很快，紅徽音再坐下
	await get_tree().create_timer(HUIYIN_SIT_DELAY_SECONDS).timeout
	_play_anim(huiyin_npc, HUIYIN_SIT_ANIMATION)
	_place_feet_on_marker(huiyin_npc, huiyin_initial_point)

	# 最後頓一下，劉語塵才坐（他先走到座墊，站著等一下）
	if tween_liuyu and tween_liuyu.is_running():
		await tween_liuyu.finished
	await get_tree().create_timer(LIUYU_SIT_PAUSE_SECONDS).timeout
	_set_liuyu_sit_scale(liuyu, true)
	_play_anim(liuyu, "sit_right_up")


## 劉語塵的坐下動畫（chibi sprite sheet）比其他姿勢小一圈，坐著時把 AnimatedSprite2D 放大一點，起身後還原。
const LIUYU_SIT_SPRITE_SCALE := 1.1


func _set_liuyu_sit_scale(liuyu: Node, sitting: bool) -> void:
	var sprite := _find_animated_sprite(liuyu)
	if sprite == null:
		return
	if not sprite.has_meta("stand_scale"):
		sprite.set_meta("stand_scale", sprite.scale)
	var stand_scale: Vector2 = sprite.get_meta("stand_scale")
	sprite.scale = stand_scale * (LIUYU_SIT_SPRITE_SCALE if sitting else 1.0)


func _move_node_along_path(node: Node2D, path: Path2D, duration: float, moving_anim := "", end_anim := "") -> void:
	var tween := _create_move_tween_along_path(node, path, duration, moving_anim, end_anim)
	if tween:
		await tween.finished


func _create_move_tween_along_path(node: Node2D, path: Path2D, duration: float, moving_anim := "", end_anim := "") -> Tween:
	if node == null or path == null:
		return null

	var follow := _get_path_follow(path)
	if follow == null:
		push_warning("Path2D 缺少 PathFollow2D：" + str(path.name))
		return null

	follow.progress_ratio = 0.0
	node.global_position = follow.global_position

	if moving_anim != "":
		_play_anim(node, moving_anim)

	var tween := create_tween()
	tween.tween_method(
		func(value):
			follow.progress_ratio = value
			node.global_position = follow.global_position,
		0.0,
		1.0,
		duration
	)

	tween.finished.connect(func():
		follow.progress_ratio = 1.0
		node.global_position = follow.global_position
		if end_anim != "":
			_play_anim(node, end_anim)
	, CONNECT_ONE_SHOT)

	return tween


func _get_path_follow(path: Path2D) -> PathFollow2D:
	if path == null:
		return null

	var follow := path.get_node_or_null("PathFollow2D")
	if follow is PathFollow2D:
		return follow

	for child in path.get_children():
		if child is PathFollow2D:
			return child

	return null


func _play_anim(node: Node, anim_name: String) -> void:
	if node == null or anim_name == "":
		return

	var sprite := _find_animated_sprite(node)
	if sprite == null:
		return

	# 白書眠的坐姿動畫叫 Sit_right_up（大寫 S），其他角色是 sit_right_up：名稱不分大小寫地找
	var resolved := _resolve_animation_name(sprite, anim_name)
	if resolved != "":
		sprite.play(resolved)
	else:
		# 動畫不存在時不報錯，只保留現狀。
		print("動畫不存在：", anim_name, " node=", node.name)


func _resolve_animation_name(sprite: AnimatedSprite2D, anim_name: String) -> String:
	if sprite.sprite_frames == null:
		return ""
	if sprite.sprite_frames.has_animation(anim_name):
		return anim_name
	for candidate in sprite.sprite_frames.get_animation_names():
		if String(candidate).to_lower() == anim_name.to_lower():
			return String(candidate)
	return ""


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node

	var direct := node.get_node_or_null("AnimatedSprite2D")
	if direct is AnimatedSprite2D:
		return direct

	for child in node.get_children():
		var found := _find_animated_sprite(child)
		if found:
			return found

	return null


# ------------------------------------------------------------
# 共用：淡出 / 玩家 / Trigger
# ------------------------------------------------------------
func _fade_out() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 0.0

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


func _get_player() -> Node2D:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player is Node2D:
		return player

	player = get_node_or_null("/root/Player")
	if player is Node2D:
		return player

	return null


func _is_player(body: Node) -> bool:
	return body.name == "LiuYu" or body.name == "Player" or body.is_in_group("player")


func _set_player_movable(value: bool) -> void:
	var player := _get_player()
	if player:
		player.set("can_move", value)


func _disable_event_area() -> void:
	if event_area == null:
		return

	for child in event_area.get_children():
		if child is CollisionShape2D:
			child.disabled = true


func _get_first_node(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if node:
			return node
	return null


# ------------------------------------------------------------
# Dialog helpers
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# GlobalState helpers
# ------------------------------------------------------------
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
