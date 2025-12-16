# file: Game.tscn 的腳本修改
extends Control

var messages = [
	"本應該是太平盛世的當今, 卻被來路不明的卷軸打破了人世間的安寧",
	"凡是閱讀那些卷軸的人們, 無一不是發了瘋、著了魔...",
	"旁人勸也勸不聽, 拉也拉不開, 把手上的卷軸搶走, 那些人卻反而像是
	觸怒了逆鱗, 不管眼前的人是誰, 一股腦兒發狂似的大打出手, 只為了
	搶回那卷軸...",
	"就好像..那些卷軸控制了他們的魂魄一樣..",
	"世人稱那些不祥的卷軸為-邪典-",
	"為了消滅雨後春筍般出現的邪典, 並讓那些失了魂的受害者回復心智",
	"眾人絞盡了腦汁卻一籌莫展",
	"雪上加霜的是, 一種寄宿在言語之中的魍魎——『語魅』突然出現並
	大肆興風作浪",
	"正當無計可施之際, 一名年輕人悄悄到來..."
]

var current_index = 0
var char_index = 0
var is_typing = false
var full_text = ""

@onready var message_label = $MessageLabel
@onready var black_overlay = $BlackOverlay

func _ready():
	black_overlay.modulate.a = 1.0
	fade_out()
	await get_tree().create_timer(1.0).timeout
	show_next_message()

func _input(event):
	if (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		if is_typing:
			message_label.text = full_text
			is_typing = false
		else:
			current_index += 1
			if current_index < messages.size():
				show_next_message()
			else:
				await fade_in()
				load_game_root_with_intro_room()

func show_next_message():
	full_text = messages[current_index]
	message_label.text = ""
	char_index = 0
	is_typing = true
	type_letter()

func type_letter():
	if char_index < full_text.length() and is_typing:
		message_label.text += full_text[char_index]
		char_index += 1
		await get_tree().create_timer(0.1).timeout
		type_letter()
	else:
		is_typing = false

func fade_out():
	var tween = create_tween()
	tween.tween_property(black_overlay, "modulate:a", 0.0, 1.0)

func fade_in():
	var tween = create_tween()
	tween.tween_property(black_overlay, "modulate:a", 1.0, 1.0)
	await tween.finished

# ✅ 新增的函式：改為載入 GameRoot 並把 intro_room 放進去
func load_game_root_with_intro_room():
	var game_root = load("res://scenes/game_root.tscn").instantiate()
	var intro_room = load("res://scenes/intro_room.tscn").instantiate()

	# 把房間塞進 GameRoot 的 CurrentScene 之下
	game_root.get_node("CurrentScene").add_child(intro_room)

	# 最後切換整個 GameRoot 畫面
	get_tree().root.add_child(game_root)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game_root
