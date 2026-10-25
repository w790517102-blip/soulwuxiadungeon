extends SceneTree
## 醉月茶坊台詞格式（試點）：NPC 發話一律「名稱：「…」」、不留半形冒號的姓名、不留手動斷行（斷行交給 DialogTextLayout）。
## Run: --headless --path . --script tests/test_teahouse_dialog_format.gd

const DIR := "res://scripts/yuheng/yuheng_market_east/zueyue_teashop/"
const FILES := [
	"tea_shop_keeper.gd", "tea_shop_servant.gd", "Hong_huei_yin.gd", "zuiyue_huiyin_first_talk_story.gd",
	"tea_customer_a.gd", "tea_customer_b.gd", "old_man.gd", "tea_house_guest_guard.gd", "tea_house_melody_recall.gd",
	"tea_house_night_dialog.gd",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for file_name: String in FILES:
		var src := FileAccess.get_file_as_string(DIR + file_name)
		var n := 0
		for line in src.split("\n"):
			n += 1
			if line.contains("劉語塵: ") or line.contains("單步雷: "):
				_failures.append("%s:%d half-width colon after a name" % [file_name, n])
			if line.contains('"text": "「'):
				_failures.append("%s:%d bare quoted line without a speaker name" % [file_name, n])
			if line.contains('"text":') and line.contains("\n"):
				_failures.append("%s:%d manual line break in dialogue text" % [file_name, n])
	if _failures.is_empty():
		print("PASS: tea house dialog format")
		quit(0)
	else:
		for message: String in _failures:
			push_error("FAIL: " + message)
		quit(1)
