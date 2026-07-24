extends SceneTree

const DialogManagerScript = preload("res://scripts/DialogManager.gd")
const PORTRAIT_PATH := "res://icon.svg"
const STORY_NARRATION_SCRIPTS := [
	"res://scripts/yuheng/yuheng_marekt_west/Bai_Jian_Jue/baijianju_yinpingyu_story_shumian.gd",
	"res://scripts/yuheng/YinYueManor/gu_shi.gd",
	"res://scripts/yuheng/Bamboo_Grove_Suburb/yuheng_grand_ma.gd",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := _build_dialog_manager()
	root.add_child(manager)
	await process_frame

	await _show(manager, 1, PORTRAIT_PATH)
	_expect(_top_visible(manager) and _top_has_portrait(manager), "NPC 必須顯示於上方且保留頭像")
	await _show(manager, 0, "")
	_expect(_top_visible(manager) and not _top_has_portrait(manager), "NPC → 旁白必須清除上方頭像")
	_expect(_bottom_cleared(manager), "NPC → 旁白時下方框必須隱藏並清空")

	await _show(manager, 1, PORTRAIT_PATH)
	_expect(_top_visible(manager) and _top_has_portrait(manager), "旁白 → NPC 必須恢復上方 NPC 頭像")

	await _show(manager, 2, PORTRAIT_PATH)
	_expect(_bottom_visible(manager) and _bottom_has_portrait(manager), "劉語塵必須顯示於下方且保留頭像")
	_expect(_top_cleared(manager), "切換至劉語塵時上方框必須隱藏並清空")
	await _show(manager, 0, "")
	_expect(_top_visible(manager) and not _top_has_portrait(manager), "劉語塵 → 旁白必須切至上方無頭像")
	_expect(_bottom_cleared(manager), "劉語塵 → 旁白必須清除下方內容與頭像")

	await _show(manager, 2, PORTRAIT_PATH)
	_expect(_bottom_visible(manager) and _bottom_has_portrait(manager), "旁白 → 劉語塵必須回到下方")
	_expect(_top_cleared(manager), "旁白 → 劉語塵必須清除上方旁白")

	await _show(manager, 0, "")
	await _show(manager, 0, "")
	_expect(_top_visible(manager) and not _top_has_portrait(manager), "連續旁白必須持續使用上方且不產生殘留頭像")

	await _show(manager, 4, PORTRAIT_PATH)
	_expect(_top_visible(manager) and _top_has_portrait(manager), "非 1 的 NPC speaker ID 仍必須使用上方")
	await _show(manager, 0, "")
	await _show(manager, 5, PORTRAIT_PATH)
	_expect(_top_visible(manager) and _top_has_portrait(manager), "有頭像 NPC → 旁白 → 有頭像 NPC 必須正確重建頭像")

	for script_path in STORY_NARRATION_SCRIPTS:
		await _verify_story_narration(manager, script_path)

	manager.hide_dialog()
	_expect(_top_cleared(manager) and _bottom_cleared(manager), "對話結束必須清空兩側 lane")
	manager.free()

	if _failures.is_empty():
		print("PASS: DialogManager 旁白上方路由與 lane 清理全部通過")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_dialog_manager() -> CanvasLayer:
	var manager := CanvasLayer.new()
	manager.name = "DialogManager"
	var top_box := TextureRect.new()
	top_box.name = "DialogBox1"
	manager.add_child(top_box)
	var top_label := Label.new()
	top_label.name = "Label"
	top_box.add_child(top_label)
	var top_headshot := Sprite2D.new()
	top_headshot.name = "HeadShot1"
	top_box.add_child(top_headshot)
	var bottom_box := TextureRect.new()
	bottom_box.name = "DialogBox2"
	manager.add_child(bottom_box)
	var bottom_label := Label.new()
	bottom_label.name = "Label"
	bottom_box.add_child(bottom_label)
	var bottom_headshot := Sprite2D.new()
	bottom_headshot.name = "HeadShot2"
	bottom_box.add_child(bottom_headshot)
	var choice_box := Node.new()
	choice_box.name = "ChoiceBox"
	manager.add_child(choice_box)
	manager.set_script(DialogManagerScript)
	return manager


func _show(manager: CanvasLayer, speaker: int, portrait: String) -> void:
	await manager.call("_head_dialog", "", portrait, speaker)


func _verify_story_narration(manager: CanvasLayer, script_path: String) -> void:
	var story_script := load(script_path) as Script
	_expect(story_script != null, "Cannot load story script: %s" % script_path)
	if story_script == null:
		return
	var story_actor: Object = story_script.new()
	_expect(story_actor.has_method("_n"), "Story script has no _n(): %s" % script_path)
	if not story_actor.has_method("_n"):
		story_actor.free()
		return
	var narration: Dictionary = story_actor.call("_n", "narration regression")
	_expect(int(narration.get("speaker", -1)) == 0, "_n() must retain narration speaker 0: %s" % script_path)
	await _show(manager, int(narration.get("speaker", -1)), str(narration.get("portrait", "")))
	_expect(_top_visible(manager), "Story narration must use top lane: %s" % script_path)
	_expect(not _top_has_portrait(manager), "Story narration must not show or inherit portrait: %s" % script_path)
	_expect(_bottom_cleared(manager), "Story narration must clear bottom lane: %s" % script_path)
	story_actor.free()


func _top_visible(manager: CanvasLayer) -> bool:
	return manager.get_node("DialogBox1").visible and not manager.get_node("DialogBox2").visible


func _bottom_visible(manager: CanvasLayer) -> bool:
	return manager.get_node("DialogBox2").visible and not manager.get_node("DialogBox1").visible


func _top_has_portrait(manager: CanvasLayer) -> bool:
	var headshot := manager.get_node("DialogBox1/HeadShot1") as Sprite2D
	return headshot.visible and headshot.texture != null


func _bottom_has_portrait(manager: CanvasLayer) -> bool:
	var headshot := manager.get_node("DialogBox2/HeadShot2") as Sprite2D
	return headshot.visible and headshot.texture != null


func _top_cleared(manager: CanvasLayer) -> bool:
	var box := manager.get_node("DialogBox1")
	var headshot := manager.get_node("DialogBox1/HeadShot1") as Sprite2D
	var label := manager.get_node("DialogBox1/Label") as Label
	return not box.visible and not headshot.visible and headshot.texture == null and label.text == ""


func _bottom_cleared(manager: CanvasLayer) -> bool:
	var box := manager.get_node("DialogBox2")
	var headshot := manager.get_node("DialogBox2/HeadShot2") as Sprite2D
	var label := manager.get_node("DialogBox2/Label") as Label
	return not box.visible and not headshot.visible and headshot.texture == null and label.text == ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
