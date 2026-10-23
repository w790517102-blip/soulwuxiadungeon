extends SceneTree

# 淨化舊水道外層的滑鼠專用出口：三個 InteractionTarget（exit_*），蛋黃區都在鏡頭邊界內，蛋白區是出口的踩踏範圍。
# 執行：godot --headless --path . --script tests/test_sewer_exit_zones.gd

const SCENE := "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true.tscn"
var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)

func _run() -> void:
	await process_frame
	var scene := (load(SCENE) as PackedScene).instantiate()
	var bounds := Rect2(-572.0, -432.0, 1144.0, 864.0)   # CameraBounds
	for n in ["exit_old_well", "exit_stalactite_cave", "exit_sewer_true_room"]:
		var t := scene.get_node_or_null("InteractionZones/" + n)
		_check(t != null, n + " exists")
		if t == null:
			continue
		var yolk: PackedVector2Array = t.get("selection_polygon")
		var white: PackedVector2Array = t.get("zone_polygon")
		_check(yolk.size() >= 3 and white.size() >= 3, n + " has yolk and white polygons")
		var inside := 0
		for p in white:
			if bounds.grow(16.0).has_point(p):
				inside += 1
		_check(inside == white.size(), n + " white zone is inside the camera bounds (only the edge overhang past the border)")
		_check(int(t.get("mode")) == 2, n + " uses ZONE mode")
	scene.free()
	print("PASS test_sewer_exit_zones" if _failures == 0 else "FAILED test_sewer_exit_zones: %d" % _failures)
	quit(1 if _failures > 0 else 0)
