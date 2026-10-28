extends SceneTree

# 舊式物件（調香室、琴室、符咒室）自動接上三層互動：Area2D＝蛋黃區、往外擴張＝蛋白區、游標＝饅頭手。
# 執行：godot --headless --path . --script tests/test_object_interaction_adapter.gd

var _failures := 0
const BASE := "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/"


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _bounds(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p:
		r = r.expand(v)
	return r


func _run() -> void:
	await process_frame
	var cases := {
		"yuheng_sewer_alchemy_room/yuheng_sewer_alchemy_room.tscn": 4,      # 三個物件＋一個出口
		"yuheng_sewer_music_room/yuheng_sewer_music_room.tscn": 7,      # 古琴＋五塊石板＋出口
		"yuheng_sewer_talisman_room/yuheng_sewer_talisman_room.tscn": 4,      # 三張符咒＋一個出口
		"yuheng_sewer_secret_room/yuheng_sewer_secret_room.tscn": 1,      # 只有一個出口
		"yuheng_sewer_final_room/yuheng_sewer_final_room.tscn": 2,      # 往鐘乳石洞（封印邏輯在出口函式裡）＋往中央水道
		"yuheng_sewer_final_room/yuheng_stalactite_cave/yuheng_stalactite_cave.tscn": 1,      # 離開鐘乳石洞
	}
	for path in cases.keys():
		var scene = load(BASE + path).instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		var n: int = ObjectInteractionAdapter.adopt_scene(scene)
		await process_frame      # monitoring 是 set_deferred，下一幀才生效
		_check(n == int(cases[path]), "%s adopts %d objects (got %d)" % [path.get_file(), int(cases[path]), n])
		for t in scene.find_children("InteractionTarget", "", true, false):
			var target := t as InteractionTarget
			_check(target.cursor_kind == "inspect", "%s uses the white hand" % target.get_parent().name)
			_check(target.mode == InteractionTarget.Mode.ZONE and target.interaction_radius == 0.0, "%s is a zone target" % target.get_parent().name)
			var yolk := _bounds(target.selection_polygon)
			var white := _bounds(target.zone_polygon)
			var owner_node := target.get_parent()
			if owner_node.has_meta(ObjectInteractionAdapter.WHITE_META):
				# 場景手畫的蛋黃／蛋白：照畫的用（蛋白不一定包住蛋黃，例如蛋黃在牆上、蛋白在牆前地板）
				_check(target.zone_polygon == owner_node.get_meta(ObjectInteractionAdapter.WHITE_META) and (not owner_node.has_meta(ObjectInteractionAdapter.YOLK_META) or target.selection_polygon == owner_node.get_meta(ObjectInteractionAdapter.YOLK_META)), "%s: uses the hand-drawn yolk and white" % owner_node.name)
			else:
				_check(white.encloses(yolk) and white.size.x >= yolk.size.x + 2.0 * ObjectInteractionAdapter.DEFAULT_EXPAND - 2.0, "%s: the interaction range is the Area2D grown outward" % owner_node.name)
			var area := target.get_parent().get_node_or_null("Area2D") as Area2D
			if area != null:
				_check(not area.monitoring, "%s: the old Area2D no longer triggers (no double interaction)" % target.get_parent().name)
		var exit_target := scene.get_node_or_null(ObjectInteractionAdapter.EXIT_NODE_NAME) as InteractionTarget
		if scene.has_meta(ObjectInteractionAdapter.EXIT_YOLK_META):
			_check(exit_target != null and exit_target.cursor_kind == "exit" and exit_target.selection_polygon.size() >= 3 and exit_target.zone_polygon.size() >= 3, "%s: the hand-drawn exit is a zone target with the exit cursor" % path.get_file())
		# 已經手畫過的物件不會被覆蓋
		var again: int = ObjectInteractionAdapter.adopt_scene(scene)
		_check(again == 0, "a second pass changes nothing (already adopted or hand-drawn)")
		scene.queue_free()
		await process_frame

	# 汙染舊水道中央：六個出入口都是手畫的出口目標；終端室門上的符咒（Door_sealed）已拿掉
	var center = load("res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn").instantiate()
	root.add_child(center)
	await process_frame
	_check(ObjectInteractionAdapter.adopt_scene(center) == 6, "the sewer hub adopts its six hand-drawn exits")
	for id in ["old_well", "alchemy_room", "final_room", "talisman_room", "secret_room", "music_room"]:
		var exit_node := center.get_node_or_null("%s_%s" % [ObjectInteractionAdapter.EXIT_NODE_NAME, id]) as InteractionTarget
		_check(exit_node != null and exit_node.cursor_kind == "exit" and exit_node.selection_polygon.size() >= 3 and exit_node.zone_polygon.size() >= 3, "hub exit %s is a zone target with the exit cursor" % id)
	_check(center.get_node_or_null("Door_sealed") == null, "the talisman sticker on the final-room door is gone")
	center.queue_free()
	await process_frame

	# 飲月山莊：外部兩個出口（進屋、往竹林郊區），內部白天一個出口；夜晚沒有出口（劇情鎖定），不套用
	var manor := {
		"res://scenes/yuheng/YinYueManor/yin_yue_manor.tscn": ["door", "bamboo"],
		"res://scenes/yuheng/YinYueManor/yin_yue_manor_room/yin_yue_manor_room(day).tscn": [""],
	}
	for mp in manor.keys():
		var ms = load(mp).instantiate()
		root.add_child(ms)
		await process_frame
		var exits: Array = manor[mp]
		_check(ObjectInteractionAdapter.adopt_scene(ms) >= exits.size(), "%s adopts its hand-drawn exits" % mp.get_file())
		for id in exits:
			var nm: String = ObjectInteractionAdapter.EXIT_NODE_NAME if id == "" else "%s_%s" % [ObjectInteractionAdapter.EXIT_NODE_NAME, id]
			var et := ms.get_node_or_null(nm) as InteractionTarget
			_check(et != null and et.cursor_kind == "exit" and et.selection_polygon.size() >= 3 and et.zone_polygon.size() >= 3, "%s exit %s is a zone target with the exit cursor" % [mp.get_file(), id])
		ms.queue_free()
		await process_frame

	# 多邊形工具：矩形擴張後每邊多 distance
	var rect := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50), Vector2(0, 50)])
	var grown := _bounds(ObjectInteractionAdapter.expanded(rect, 30.0))
	_check(is_equal_approx(grown.position.x, -30.0) and is_equal_approx(grown.size.x, 160.0) and is_equal_approx(grown.size.y, 110.0), "a 100x50 rectangle grows to 160x110")
	print("PASS: object interaction adapter" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
