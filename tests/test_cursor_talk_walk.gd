extends SceneTree

# 游標：可對話目標「還沒走進蛋白區」顯示靴子走向對話框（兩格走路動畫），不論有沒有按住；
# 走進之後才是單純對話框；按在普通地面移動時不會被靴子游標取代。
# 執行：godot --headless --path . --script tests/test_cursor_talk_walk.gd

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)

func _run() -> void:
	await process_frame
	var gc = root.get_node("GameCursor")
	_check(gc.is_active(), "cursor art loads (including the walking boots frames)")
	gc.mouse_override = Vector2(300, 300)
	gc.intent_override = true

	gc.set_hover_kind("talk_walk")
	await process_frame
	await process_frame
	_check(gc._state == "icon", "talk_walk hover shows the icon state while idle")
	_check(gc.icon.texture == gc._tex["cursor_talk_walk_a"], "first frame is boots frame A")
	await create_timer(0.35).timeout
	_check(gc.icon.texture == gc._tex["cursor_talk_walk_b"], "boots animate to frame B")

	gc.left_override = true
	await process_frame
	await process_frame
	_check(gc._state == "icon", "still the boots icon while holding the mouse to chase the target")

	gc.set_hover_kind("talk")
	await process_frame
	await process_frame
	_check(gc._state == "move", "inside range with the plain bubble kind, holding = normal move cursor")
	gc.left_override = false
	await process_frame
	await process_frame
	_check(gc._state == "icon" and gc.icon.texture == gc._tex["cursor_talk_a"], "released inside range = plain talk bubble")

	gc.set_hover_kind("")
	gc.mouse_override = null
	gc.left_override = null
	gc.intent_override = null
	print("PASS test_cursor_talk_walk" if _failures == 0 else "FAILED test_cursor_talk_walk: %d" % _failures)
	quit(1 if _failures > 0 else 0)
