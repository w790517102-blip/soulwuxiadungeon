extends SceneTree
# 用法：Godot --headless --script tests/test_direction_hysteresis.gd
func _init() -> void:
	var G = load("res://scripts/interaction/InteractionGeometry.gd")
	var cur := Vector2.from_angle(deg_to_rad(45.0))  # 右下
	var fails := 0
	# 22.5°（正向／斜向交界）附近來回抖動：都應維持右下
	for a in [20.0, 23.0, 25.0, 30.0, 35.0, 22.0]:
		if G.quantize_8_sticky(Vector2.from_angle(deg_to_rad(a)), cur, 14.0) != cur:
			fails += 1; print("FAIL stay ", a)
	# 偏離夠遠（> 36.5° 差）才換成右
	var r: Vector2 = G.quantize_8_sticky(Vector2.from_angle(deg_to_rad(5.0)), cur, 14.0)
	if not r.is_equal_approx(Vector2.RIGHT):
		fails += 1; print("FAIL switch ", r)
	# 沒有目前方向時等同一般量化
	if not G.quantize_8_sticky(Vector2.from_angle(deg_to_rad(30.0)), Vector2.ZERO).is_equal_approx(G.quantize_8(Vector2.from_angle(deg_to_rad(30.0)))):
		fails += 1; print("FAIL zero")
	print("PASS" if fails == 0 else "FAILS=%d" % fails)
	quit(1 if fails else 0)
