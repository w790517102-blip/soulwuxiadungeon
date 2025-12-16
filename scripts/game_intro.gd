extends Control

var dialogues = [
	"某一天, 來路不明的卷軸打破了凡世間的安寧",
	"凡是閱讀那些卷軸的人們, 無一不是發了瘋著了魔...",
	"旁人勸也勸不聽, 拉也拉不開, 把手上的卷軸搶走, 那些人卻抓了狂...",
	"就好像..那些卷軸是他們的命一樣..",
	"世人稱它們為-邪典-; 為了消滅雨後春筍般出現的邪典, 並讓那些失了魂的受害者回復心智",
	"眾人絞盡了腦汁卻一籌莫展",
	"雪上加霜的是, 一種寄宿在言語之中的魍魎——『語魅』突然出現並大肆興風作浪",
	"正當無計可施之際, 一名年輕人悄悄到來..."
]

var current_index = 0
var is_typing = false
var full_text = ""
var typing_speed = 0.04 # 每字秒數
var typing_timer = 0.0
var current_char_index = 0

@onready var label = $Panel/RichTextLabel

func _ready():
	show_next_dialogue()

func show_next_dialogue():
	if current_index >= dialogues.size():
		get_tree().change_scene_to_file("res://scenes/first_stage.tscn") # ⚠️換成你正式遊戲場景名稱
		return
	full_text = dialogues[current_index]
	current_char_index = 0
	label.text = ""
	is_typing = true
	current_index += 1

func _process(delta):
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0
			if current_char_index < full_text.length():
				label.text += full_text[current_char_index]
				current_char_index += 1
			else:
				is_typing = false

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if is_typing:
			label.text = full_text
			is_typing = false
		else:
			show_next_dialogue()
