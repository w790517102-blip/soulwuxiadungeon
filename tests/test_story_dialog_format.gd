extends SceneTree
## 支線（大寶、四季豆、拳骨未老、炭火裡的紙灰）與主線（顧石、暴發戶、白箋居離席）台詞格式：
## NPC 發話寫成「名稱：「…」」、劉語塵內心想法用（心想）、旁白用第二人稱、不留手動斷行（詩詞除外）。
## Run: --headless --path . --script tests/test_story_dialog_format.gd

const DIR := "res://scripts/yuheng/"
const FILES := [
	"yuheng_marekt_west/dreaming_kid.gd", "yuheng_market_east/running_woman.gd", "yuheng_market_east/store_keeper_a.gd",
	"yuheng_outside/old_man_a.gd", "yuheng_marekt_west/yuheng_pharmacy/do_yar.gd", "YinYueManor/gu_shi.gd",
	"yuheng_marekt_west/baijianju_richman_trigger.gd", "yuheng_marekt_west/Bai_Jian_Jue/baijianju_scene1_guest_dialog.gd",
	"yuheng_marekt_west/scene1_witness_dialog.gd", "yuheng_marekt_west/Bai_Jian_Jue/baijianju_yinpingyu_story_shumian.gd",
]
# 詩詞與路過者的環境泡泡不套用「名稱：」規則
const SKIP_NAME_CHECK := {"yuheng_market_east/running_woman.gd": [58]}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for rel: String in FILES:
		var src := FileAccess.get_file_as_string(DIR + rel)
		var n := 0
		for line in src.split("\n"):
			n += 1
			var skip: Array = SKIP_NAME_CHECK.get(rel, [])
			if not line.strip_edges().begins_with("#") and (line.strip_edges().ends_with(")，") or line.strip_edges().ends_with("\"，")):
				_failures.append("%s:%d full-width comma where GDScript needs an ASCII one" % [rel, n])
			if line.contains('"text": "「') and not skip.has(n):
				_failures.append("%s:%d bare quoted line without a speaker name" % [rel, n])
			if line.contains("劉語塵心想") or line.contains("劉語塵: ") or line.contains("劉語塵:「"):
				_failures.append("%s:%d old thought / half-width colon format" % [rel, n])
			if line.contains('_n("劉語塵') or line.contains('_n("他'):
				_failures.append("%s:%d third-person narration about the player" % [rel, n])
			if line.contains('"text": "') and line.contains("\n") and not rel.contains("shumian"):
				_failures.append("%s:%d manual line break in dialogue text" % [rel, n])
			if line.contains('_l("(') or line.contains('_l("（') and not line.contains("（心想）"):
				_failures.append("%s:%d parenthesised action left inside a spoken line" % [rel, n])
		if load(DIR + rel) == null:
			_failures.append("%s fails to load" % rel)
	if _failures.is_empty():
		print("PASS: story dialog format")
		quit(0)
	else:
		for message: String in _failures:
			push_error("FAIL: " + message)
		quit(1)
