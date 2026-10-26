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
		"yuheng_sewer_alchemy_room/yuheng_sewer_alchemy_room.tscn": 3,
		"yuheng_sewer_music_room/yuheng_sewer_music_room.tscn": 6,
		"yuheng_sewer_talisman_room/yuheng_sewer_talisman_room.tscn": 3,
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
			_check(white.encloses(yolk) and white.size.x >= yolk.size.x + 2.0 * ObjectInteractionAdapter.DEFAULT_EXPAND - 2.0, "%s: the interaction range is the Area2D grown outward" % target.get_parent().name)
			var area := target.get_parent().get_node_or_null("Area2D") as Area2D
			if area != null:
				_check(not area.monitoring, "%s: the old Area2D no longer triggers (no double interaction)" % target.get_parent().name)
		# 已經手畫過的物件不會被覆蓋
		var again: int = ObjectInteractionAdapter.adopt_scene(scene)
		_check(again == 0, "a second pass changes nothing (already adopted or hand-drawn)")
		scene.queue_free()
		await process_frame

	# 多邊形工具：矩形擴張後每邊多 distance
	var rect := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50), Vector2(0, 50)])
	var grown := _bounds(ObjectInteractionAdapter.expanded(rect, 30.0))
	_check(is_equal_approx(grown.position.x, -30.0) and is_equal_approx(grown.size.x, 160.0) and is_equal_approx(grown.size.y, 110.0), "a 100x50 rectangle grows to 160x110")
	print("PASS: object interaction adapter" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
