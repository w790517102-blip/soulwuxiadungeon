extends SceneTree

# 探索互動：幾何距離、A／B／C 三種距離模式、滑鼠選目標與空白鍵選目標（唯一目標）、單次互動。
# 執行：godot --headless --path . --script tests/test_interaction_resolver.gd

var _failures := 0
var _resolver_script: GDScript
var _world: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_resolver_script = load("res://scripts/interaction/InteractionResolver.gd")
	_world = Node2D.new()
	root.add_child(_world)

	_test_geometry()
	_test_radius_targets()
	_test_hover_selection()
	_test_keyboard_selection()
	_test_zone_target()
	await _test_special_area()
	await _test_clear_path_and_side()
	await _test_single_interaction()
	await _test_intents()
	_test_three_layers_and_facing()
	await _test_overlapping_real_zones()

	_world.queue_free()
	if _failures == 0:
		print("PASS test_interaction_resolver")
		quit(0)
	else:
		print("FAIL test_interaction_resolver failures=%d" % _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


# ------------------------------------------------------------
func _npc(name: String, position: Vector2) -> Node2D:
	var npc := Node2D.new()
	npc.name = name
	npc.position = position
	_world.add_child(npc)
	return npc


func _target(npc: Node2D, mode: int = 1, radius: float = 90.0, priority: int = 0) -> InteractionTarget:
	var target := InteractionTarget.new()
	target.name = "InteractionTarget"
	target.mode = mode
	target.interaction_radius = radius
	target.hover_margin = 20.0
	target.priority = priority
	npc.add_child(target)
	return target


func _player(position: Vector2) -> Node2D:
	var player := Node2D.new()
	player.name = "FakePlayer"
	player.position = position
	_world.add_child(player)
	return player


func _clear_world() -> void:
	for child in _world.get_children():
		_world.remove_child(child)
		child.free()


# ------------------------------------------------------------
func _test_geometry() -> void:
	var geo: GDScript = InteractionGeometry
	var rect := Rect2(0, 0, 200, 40)
	_expect(is_equal_approx(geo.distance_to_rect(Vector2(100, 20), rect), 0.0), "inside a rect is distance 0")
	_expect(is_equal_approx(geo.distance_to_rect(Vector2(-30, 20), rect), 30.0), "left of the rect: the edge distance")
	_expect(is_equal_approx(geo.distance_to_rect(Vector2(100, 70), rect), 30.0), "below the rect: the edge distance")
	_expect(is_equal_approx(geo.distance_to_rect(Vector2(230, 80), rect), 50.0), "diagonal from a corner: the corner distance (30,40 -> 50)")
	# 寬 200、高 40 的矩形：站在最右端旁邊，距離只有幾像素，雖然離中心有一百多
	_expect(geo.distance_to_rect(Vector2(205, 20), rect) < 6.0 and Vector2(205, 20).distance_to(rect.get_center()) > 100.0, "a wide zone is measured from its edge, not its center")
	var polygon := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	_expect(is_equal_approx(geo.distance_to_polygon(Vector2(50, 50), polygon), 0.0), "inside a polygon is 0")
	_expect(is_equal_approx(geo.distance_to_polygon(Vector2(130, 50), polygon), 30.0), "outside a polygon: distance to the nearest edge")
	_expect(geo.closest_point_on_rect(Vector2(250, -10), rect) == Vector2(200, 0), "closest point on a rect is clamped")
	# 八方向量化
	_expect(geo.quantize_8(Vector2(1, 0.2)) == Vector2(1, 0), "mostly right -> right")
	_expect(geo.quantize_8(Vector2(1, 0.9)).is_equal_approx(Vector2(1, 1).normalized()), "down-right diagonal is a unit vector (like WASD)")
	_expect(geo.quantize_8(Vector2(0.1, -1)).is_equal_approx(Vector2(0, -1)), "mostly up -> up")
	_expect(geo.quantize_8(Vector2.ZERO) == Vector2.ZERO, "zero stays zero")


func _test_radius_targets() -> void:
	_clear_world()
	var a_npc := _npc("A", Vector2(0, 0))
	var a := _target(a_npc)
	var near := _player(Vector2(60, 0))
	var far := _player(Vector2(300, 0))
	_expect(a.in_interaction_range(near), "B: inside the radius can interact")
	_expect(not a.in_interaction_range(far), "B: outside the radius cannot")
	_expect(a.is_hovered(Vector2(0, -20)), "hover: the mouse over the target counts")
	_expect(a.is_hovered(Vector2(0, -20)) and not a.in_interaction_range(far), "hover range and interaction range are separate")
	a.availability = func() -> bool: return false
	_expect(not a.is_available(), "an unavailable target (scene condition) is not selectable")


func _test_hover_selection() -> void:
	_clear_world()
	var a := _target(_npc("A", Vector2(0, 0)))
	var b := _target(_npc("B", Vector2(60, 0)))
	var targets := [a, b]
	var picked: InteractionTarget = _resolver_script.pick_hover(Vector2(0, -20), targets)
	_expect(picked == a, "the mouse on A selects A")
	picked = _resolver_script.pick_hover(Vector2(60, -20), targets)
	_expect(picked == b, "the mouse on B selects B")
	_expect(_resolver_script.pick_hover(Vector2(500, 500), targets) == null, "the mouse on the ground selects nothing")
	# 兩個目標的互動範圍重疊、滑鼠靠近 B 一點：選 B（不是依誰先註冊）
	picked = _resolver_script.pick_hover(Vector2(40, -20), targets)
	_expect(picked == b, "overlapping targets: the one closer to the mouse wins")
	# 滑鼠同時在兩個目標的範圍內（距離都是 0）：依優先權，再依固定順序
	var overlap_a := _target(_npc("OverlapA", Vector2(300, 0)), 1, 90.0, 0)
	var overlap_b := _target(_npc("OverlapB", Vector2(300, 0)), 1, 90.0, 5)
	_expect(_resolver_script.pick_hover(Vector2(300, -20), [overlap_a, overlap_b]) == overlap_b, "both hit: the higher priority wins")
	overlap_b.priority = 0
	var first: InteractionTarget = _resolver_script.pick_hover(Vector2(300, -20), [overlap_a, overlap_b])
	var second: InteractionTarget = _resolver_script.pick_hover(Vector2(300, -20), [overlap_b, overlap_a])
	_expect(first == second and first != null, "same priority: a stable fixed order, independent of the list order")
	# 不閃爍：已選中的 A，游標移到比較靠近 B 一點點（差距在 hysteresis 內）仍然是 A
	var midpoint := Vector2(30, -20)
	var keep: InteractionTarget = _resolver_script.pick_hover(midpoint + Vector2(1.5, 0), targets, a)
	_expect(keep == a, "a small cursor move does not flip the selection")
	var flip: InteractionTarget = _resolver_script.pick_hover(Vector2(60, -20), targets, a)
	_expect(flip == b, "a clear move to B changes the selection")


func _test_keyboard_selection() -> void:
	_clear_world()
	var a := _target(_npc("A", Vector2(0, 0)))
	var b := _target(_npc("B", Vector2(60, 0)))
	var targets := [a, b]
	var player := _player(Vector2(20, 0))
	_expect(_resolver_script.pick_keyboard(player, Vector2.ZERO, targets) == a, "Space: the nearer target wins")
	player.position = Vector2(45, 0)
	_expect(_resolver_script.pick_keyboard(player, Vector2.ZERO, targets) == b, "Space: moving closer to B selects B")
	# 一樣近：臉朝向的那個
	player.position = Vector2(30, 0)
	_expect(_resolver_script.pick_keyboard(player, Vector2(1, 0), targets) == b, "equal distance: the one the player faces")
	_expect(_resolver_script.pick_keyboard(player, Vector2(-1, 0), targets) == a, "equal distance: facing the other way")
	# 只有一個，絕不會同時回兩個
	player.position = Vector2(-80, 0)
	_expect(_resolver_script.pick_keyboard(player, Vector2.ZERO, targets) == a, "only A is in range")
	player.position = Vector2(500, 0)
	_expect(_resolver_script.pick_keyboard(player, Vector2.ZERO, targets) == null, "nothing in range: nothing is selected")


func _test_zone_target() -> void:
	_clear_world()
	var holder := _npc("BigFish", Vector2(0, 0))
	var target := _target(holder, 2, 30.0)
	target.zone_rect = Rect2(0, 0, 200, 40)
	target.use_sprite_feet = false
	_expect(target.in_interaction_range(_player(Vector2(-20, 20))), "C: near the left end")
	_expect(target.in_interaction_range(_player(Vector2(222, 20))), "C: near the right end (far from the center)")
	_expect(target.in_interaction_range(_player(Vector2(100, -25))), "C: near the top edge")
	_expect(target.in_interaction_range(_player(Vector2(100, 65))), "C: near the bottom edge")
	_expect(not target.in_interaction_range(_player(Vector2(100, 100))), "C: too far below")
	_expect(not target.in_interaction_range(_player(Vector2(300, 20))), "C: too far to the right")
	_expect(target.in_interaction_range(_player(Vector2(100, 20))), "C: standing inside the zone is fine too")
	# 蛋白區（Reference Zone）不是蛋黃區：滑鼠在 Reference Zone 上不算指到；要用獨立的選取形狀（蛋黃區）
	_expect(not target.is_hovered(Vector2(195, 20)), "C: the mouse over the Reference Zone alone does not select it (that is the interaction range, not the selection zone)")
	target.selection_rect = Rect2(0, -40, 200, 80)
	_expect(target.is_hovered(Vector2(5, 20)) and target.is_hovered(Vector2(195, 20)) and not target.is_hovered(Vector2(100, 120)), "C: a separate selection shape defines where the mouse selects")
	target.selection_polygon = PackedVector2Array([Vector2(0, 0), Vector2(60, 0), Vector2(30, 40)])
	_expect(target.is_hovered(Vector2(30, 10)) and not target.is_hovered(Vector2(150, 20)), "C: a selection polygon overrides the rect")
	target.selection_polygon = PackedVector2Array()
	# 兩個重疊的區域：滑鼠永遠只選一個
	var other := _target(_npc("Other", Vector2(0, 0)), 2, 30.0)
	other.zone_rect = Rect2(100, 0, 200, 40)
	other.use_sprite_feet = false
	var chosen: InteractionTarget = _resolver_script.pick_hover(Vector2(150, 20), [target, other])
	_expect(chosen != null, "overlapping zones still select exactly one target")


func _test_special_area() -> void:
	_clear_world()
	var npc := _npc("Counter", Vector2(0, 0))
	var area := Area2D.new()
	area.name = "CounterArea"
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(120, 40)
	shape.shape = rect_shape
	area.add_child(shape)
	npc.add_child(area)
	var target := _target(npc, 0)
	target.special_area = NodePath("../CounterArea")
	var inside := CharacterBody2D.new()
	inside.name = "Inside"
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	body_shape.shape = circle
	inside.add_child(body_shape)
	inside.position = Vector2(10, 0)
	_world.add_child(inside)
	var outside := CharacterBody2D.new()
	outside.name = "Outside"
	var outside_shape := CollisionShape2D.new()
	outside_shape.shape = circle
	outside.add_child(outside_shape)
	outside.position = Vector2(400, 0)
	_world.add_child(outside)
	await physics_frame
	await physics_frame
	_expect(target.in_interaction_range(inside), "A: standing in the hand-drawn area can interact")
	_expect(not target.in_interaction_range(outside), "A: outside the area cannot, however the radius is set")
	_expect(target.is_hovered(Vector2(0, 0)) or target.hover_distance(Vector2(0, -10)) <= 20.0, "A: hover still uses the character, not the area")


func _test_clear_path_and_side() -> void:
	_clear_world()
	var holder := _npc("Monument", Vector2(0, 0))
	var target := _target(holder, 2, 120.0)
	target.zone_rect = Rect2(0, 0, 100, 40)
	target.use_sprite_feet = false
	target.require_clear_path = true
	var player := CharacterBody2D.new()
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	body_shape.shape = circle
	player.add_child(body_shape)
	player.position = Vector2(50, 100)
	_world.add_child(player)
	await physics_frame
	await physics_frame
	_expect(target.in_interaction_range(player), "an open path to the zone: can interact")
	# 中間隔一道牆：不能穿牆互動
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(300, 10)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	wall.position = Vector2(50, 70)
	_world.add_child(wall)
	await physics_frame
	await physics_frame
	_expect(not target.in_interaction_range(player), "a wall between the player and the zone blocks the interaction")
	wall.free()
	await physics_frame
	# 指定互動側：只能從南側（y 變大的方向）互動
	target.require_clear_path = false
	target.interaction_side = Vector2(0, 1)
	_expect(target.in_interaction_range(player), "the required side: from the south is fine")
	player.position = Vector2(50, -60)
	_expect(not target.in_interaction_range(player), "the required side: from the north is refused")


func _test_single_interaction() -> void:
	_clear_world()
	var resolver: Node = _resolver_script.new()
	_world.add_child(resolver)
	var a := _target(_npc("A", Vector2(0, 0)))
	var b := _target(_npc("B", Vector2(10, 0)))
	var calls := {"a": 0, "b": 0}
	a.handler = func(_player: Node2D) -> void:
		calls["a"] += 1
		await create_timer(0.3).timeout
	b.handler = func(_player: Node2D) -> void:
		calls["b"] += 1
		await create_timer(0.3).timeout
	# 同一時間只會有一個互動在跑：第二個要求（不管是誰）被擋下
	resolver.call("_run_interaction", a)
	resolver.call("_run_interaction", b)
	resolver.call("_run_interaction", a)
	await create_timer(0.6).timeout
	_expect(int(calls["a"]) == 1 and int(calls["b"]) == 0, "while one interaction runs, no second one starts (a=%d b=%d)" % [int(calls["a"]), int(calls["b"])])
	# 結束之後可以再互動
	resolver.call("_run_interaction", b)
	await create_timer(0.6).timeout
	_expect(int(calls["b"]) == 1, "after it finished, the next interaction works")
	# 互動途中目標被移除：裁決器不會卡在「互動進行中」
	var c_npc := _npc("C", Vector2(0, 0))
	var c := _target(c_npc)
	var done := {"c": false}
	c.handler = func(_player: Node2D) -> void:
		await create_timer(0.2).timeout
		done["c"] = true
	resolver.call("_run_interaction", c)
	await create_timer(0.05).timeout
	c_npc.free()
	await create_timer(0.5).timeout
	_expect(bool(done["c"]), "the handler finished although its target was removed")
	resolver.call("_run_interaction", a)
	await create_timer(0.1).timeout
	_expect(int(calls["a"]) == 2, "the resolver is not stuck after the target was removed")
	resolver.free()


# ------------------------------------------------------------
# 意圖：MOVE 不會因為走進蛋白區或滑進蛋黃區而變成互動；點蛋黃區才建立互動意圖
# ------------------------------------------------------------
var _fake_root: Node = null
var _fake_player: CharacterBody2D = null


func _make_game_stage() -> Node:
	_clear_world()
	if _fake_root != null and is_instance_valid(_fake_root):
		_fake_root.free()
	_fake_root = Node2D.new()
	_fake_root.name = "GameRoot"
	root.add_child(_fake_root)
	_fake_player = CharacterBody2D.new()
	_fake_player.name = "LiuYu"
	_fake_player.set_script(_player_script())
	_fake_root.add_child(_fake_player)
	_fake_player.global_position = Vector2(0, 300)
	var resolver: Node = _resolver_script.new()
	_fake_root.add_child(resolver)
	return resolver


func _player_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends CharacterBody2D\nvar can_move := true\nvar last_direction := Vector2(1, 1).normalized()\nvar mouse_move_direction := Vector2.ZERO\n"
	script.reload()
	return script


## 走一步（和 liu_yu.gd 一樣：沒有鍵盤時用滑鼠方向，每秒 160 px）。
func _step(resolver: Node, frames: int = 1) -> void:
	for i in frames:
		resolver.call("_physics_process", 1.0 / 60.0)
		var direction: Vector2 = _fake_player.mouse_move_direction
		if direction != Vector2.ZERO:
			_fake_player.global_position += direction * 160.0 / 60.0


func _test_intents() -> void:
	var resolver: Node = _make_game_stage()
	# 兩個 NPC 站在路上，蛋白區（半徑 90）蓋住整條路；蛋黃區是他們的外框（沒有 sprite 時的小範圍）
	var a_npc := _npc("A", Vector2(150, 300))
	var b_npc := _npc("B", Vector2(300, 300))
	var a := _target(a_npc, 1, 90.0)
	var b := _target(b_npc, 1, 90.0)
	a.use_sprite_feet = false
	b.use_sprite_feet = false
	var calls := {"a": 0, "b": 0}
	a.handler = func(_p: Node2D) -> void: calls["a"] += 1
	b.handler = func(_p: Node2D) -> void: calls["b"] += 1
	_expect(resolver.call("current_intent") == "IDLE", "no input: IDLE")

	# 1. 普通地面按下 = MOVE；一路走過 A、B 的蛋白區，一次互動都不會有
	resolver.mouse_world_override = Vector2(600, 300)
	resolver.call("_on_left_pressed")
	_expect(resolver.call("current_intent") == "MOVE", "pressing on plain ground is MOVE")
	var entered_a := false
	var entered_b := false
	for i in 400:
		_step(resolver)
		if a.in_interaction_range(_fake_player):
			entered_a = true
		if b.in_interaction_range(_fake_player):
			entered_b = true
	_expect(entered_a and entered_b, "fixture: the player did walk through both interaction ranges")
	_expect(int(calls["a"]) == 0 and int(calls["b"]) == 0, "walking through interaction ranges never starts a conversation")
	# 2. MOVE 按住後，滑鼠滑進 B 的蛋黃區：仍然只是 MOVE（不會變成互動）
	_fake_player.global_position = Vector2(30, 300)
	resolver.mouse_world_override = Vector2(300, 290)
	_expect(b.is_hovered(resolver.mouse_world_override), "fixture: the mouse is over B's selection zone")
	for i in 200:
		_step(resolver)
	_expect(resolver.call("current_intent") == "MOVE" and int(calls["a"]) == 0 and int(calls["b"]) == 0, "sliding the held mouse into a selection zone keeps it MOVE")
	resolver.call("_on_left_released")
	_expect(_fake_player.mouse_move_direction == Vector2.ZERO and resolver.call("current_intent") == "IDLE", "releasing stops immediately")

	# 3. 蛋黃區內按下 = 鎖定該 NPC；在蛋白區外就持續靠近，經過 A 的蛋白區也只互動被選的 B
	_fake_player.global_position = Vector2(-100, 300)
	resolver.mouse_world_override = Vector2(300, 290)
	resolver.call("_on_left_pressed")
	_expect(resolver.call("current_intent") == "INTERACT_APPROACH", "pressing on B's selection zone locks B (approaching)")
	var passed_a := false
	for i in 600:
		_step(resolver)
		if a.in_interaction_range(_fake_player):
			passed_a = true
		if int(calls["b"]) > 0:
			break
	_expect(passed_a, "fixture: the approach went through A's range")
	_expect(int(calls["a"]) == 0 and int(calls["b"]) == 1, "only the selected B interacts (a=%d b=%d)" % [int(calls["a"]), int(calls["b"])])
	# 互動之後仍然按著左鍵：不會再互動、不會再走
	var rest_position: Vector2 = _fake_player.global_position
	await create_timer(0.05).timeout
	for i in 200:
		_step(resolver)
	_expect(int(calls["b"]) == 1 and _fake_player.global_position.distance_to(rest_position) < 1.0, "holding on after the interaction: no second interaction, no more walking")
	resolver.call("_on_left_released")

	# 4. 已經在蛋白區內按下 NPC 的蛋黃區：立即互動（一個物理影格內）
	_fake_player.global_position = Vector2(290, 300)
	calls["b"] = 0
	resolver.mouse_world_override = Vector2(300, 290)
	resolver.call("_on_left_pressed")
	_step(resolver)
	_expect(int(calls["b"]) == 1, "already in range: clicking the selection zone interacts at once")
	await create_timer(0.05).timeout
	resolver.call("_on_left_released")

	# 5. 還沒靠近就放開左鍵：停止、取消互動（不追蹤）
	_fake_player.global_position = Vector2(-300, 300)
	calls["b"] = 0
	resolver.mouse_world_override = Vector2(300, 290)
	resolver.call("_on_left_pressed")
	for i in 30:
		_step(resolver)
	resolver.call("_on_left_released")
	var stopped_at: Vector2 = _fake_player.global_position
	for i in 600:
		_step(resolver)
	_expect(int(calls["b"]) == 0 and _fake_player.global_position.distance_to(stopped_at) < 0.5, "released early: stops and the interaction is cancelled for good")

	# 6. 靠近途中目標被移除：取消鎖定，不互動（變成單純的 MOVE）
	_fake_player.global_position = Vector2(-300, 300)
	resolver.mouse_world_override = Vector2(300, 290)
	resolver.call("_on_left_pressed")
	for i in 20:
		_step(resolver)
	b_npc.free()
	for i in 600:
		_step(resolver)
	_expect(int(calls["b"]) == 0 and int(calls["a"]) == 0, "the target removed mid-approach: no interaction at all")
	resolver.call("_on_left_released")

	# 7. 鍵盤優先：按著滑鼠時再按 WASD，取消滑鼠移動與靠近互動
	_fake_player.global_position = Vector2(-300, 300)
	var c_npc := _npc("C", Vector2(300, 300))
	var c := _target(c_npc, 1, 90.0)
	c.use_sprite_feet = false
	var c_calls := {"n": 0}
	c.handler = func(_p: Node2D) -> void: c_calls["n"] += 1
	resolver.mouse_world_override = Vector2(300, 290)
	resolver.call("_on_left_pressed")
	_expect(resolver.call("current_intent") == "INTERACT_APPROACH", "fixture: approaching C")
	Input.action_press("move_up")
	_step(resolver)
	Input.action_release("move_up")
	_expect(resolver.call("current_intent") == "IDLE" and _fake_player.mouse_move_direction == Vector2.ZERO, "pressing WASD cancels the mouse move and the pending interaction")
	resolver.call("_on_left_released")

	# 8. 互動進行中不接受新的探索輸入（對話／劇情）：INTERACTION_LOCKED
	_fake_player.can_move = false
	resolver.call("_on_left_pressed")
	_expect(resolver.call("current_intent") == "INTERACTION_LOCKED", "a locked player (dialog/cutscene) takes no exploration input")
	_fake_player.can_move = true
	resolver.call("_on_left_released")

	# 9. 蛋黃區邊緣：剛好在邊界內／外
	var edge_npc := _npc("Edge", Vector2(800, 300))
	var edge := _target(edge_npc, 1, 90.0)
	edge.use_sprite_feet = false
	edge.hover_margin = 0.0
	edge.selection_rect = Rect2(-20, -40, 40, 40)
	_expect(edge.is_hovered(Vector2(819.5, 280)) and not edge.is_hovered(Vector2(820.5, 280)), "the selection zone edge is exact (margin 0)")
	# 蛋白區不影響蛋黃區：劉語塵站在蛋白區裡，滑鼠沒碰蛋黃區 → 沒有 Hover
	_fake_player.global_position = Vector2(800, 330)
	_expect(edge.in_interaction_range(_fake_player) and _resolver_script.pick_hover(Vector2(800, 380), [edge]) == null, "inside the interaction range with the mouse off the selection zone: no hover")
	_fake_root.free()
	_fake_root = null


# ------------------------------------------------------------
# 三層區域：蛋白區（半徑 0 的多邊形 = 站進去才算）、蛋黃區（獨立多邊形）、空白鍵要面向蛋黃區（45 度內）
# ------------------------------------------------------------
func _test_three_layers_and_facing() -> void:
	_clear_world()
	var holder := _npc("Table", Vector2.ZERO)
	var target := _target(holder, 2, 0.0)
	target.use_sprite_feet = false
	target.hover_margin = 0.0
	target.require_facing = true
	# 蛋白區：大平行四邊形；蛋黃區：偏上方的小平行四邊形（不在蛋白區正中心）
	target.zone_polygon = PackedVector2Array([Vector2(0, 100), Vector2(220, -10), Vector2(400, 70), Vector2(190, 190)])
	target.selection_polygon = PackedVector2Array([Vector2(110, 50), Vector2(230, -10), Vector2(300, 25), Vector2(180, 85)])
	var inside := _player(Vector2(150, 110))
	var outside := _player(Vector2(150, 260))
	_expect(target.in_interaction_range(inside), "inside the interaction polygon: in range (radius 0)")
	_expect(not target.in_interaction_range(outside), "outside the polygon: not in range, even close to it (radius 0)")
	_expect(target.is_hovered(Vector2(200, 40)) and not target.is_hovered(Vector2(150, 150)), "the mouse selects on the yolk polygon only, not on the rest of the white zone")
	# 空白鍵：要面向蛋黃區（八方向；夾角不超過 45 度）
	var center: Vector2 = target.selection_center()
	var toward: Vector2 = (center - inside.position).normalized()
	_expect(_resolver_script.pick_keyboard(inside, toward, [target]) == target, "facing the yolk: Space picks it")
	_expect(_resolver_script.pick_keyboard(inside, -toward, [target]) == null, "facing away: Space does nothing")
	_expect(_resolver_script.pick_keyboard(inside, toward.rotated(deg_to_rad(40)), [target]) == target, "40 degrees off: still fine")
	_expect(_resolver_script.pick_keyboard(inside, toward.rotated(deg_to_rad(60)), [target]) == null, "60 degrees off: refused")
	_expect(_resolver_script.pick_keyboard(inside, Vector2.ZERO, [target]) == null, "no facing: refused")
	# 在蛋白區外：不論面向，空白鍵都不行
	_expect(_resolver_script.pick_keyboard(outside, (center - outside.position).normalized(), [target]) == null, "outside the white zone: never")
	# 沒有 require_facing 的目標（舊的 NPC）不受面向限制
	target.require_facing = false
	_expect(_resolver_script.pick_keyboard(inside, -toward, [target]) == target, "targets without require_facing ignore facing")


# ------------------------------------------------------------
# 舊水道外層 6（藥櫃）與 7（竹籃）：真實座標，蛋白區與蛋黃區互相重疊
# ------------------------------------------------------------
const CABINET_YOLK := [Vector2(-541.2, -161.5), Vector2(-447.2, -190.9), Vector2(-420.3, -174.2), Vector2(-416.4, -27.8), Vector2(-496.9, 6.4), Vector2(-530.1, -11.1)]
const CABINET_WHITE := [Vector2(-531.7, -11.1), Vector2(-449.5, 36.6), Vector2(-363.4, -4.8), Vector2(-445.6, -45.3)]
const HERB_YOLK := [Vector2(-571.0, -57.4), Vector2(-535.0, -72.6), Vector2(-518.7, -64.4), Vector2(-513.3, 23.1), Vector2(-556.2, 37.8), Vector2(-569.0, 34.1)]
const HERB_WHITE := [Vector2(-571.0, -36.6), Vector2(-458.4, 11.1), Vector2(-457.4, 44.4), Vector2(-571.0, 86.2)]


func _zone_target(node_name: String, yolk: Array, white: Array) -> InteractionTarget:
	var holder := _npc(node_name, Vector2.ZERO)
	var target := _target(holder, 2, 0.0)
	target.use_sprite_feet = false
	target.hover_margin = 2.0
	target.require_facing = true
	target.selection_polygon = PackedVector2Array(yolk)
	target.zone_polygon = PackedVector2Array(white)
	return target


func _test_overlapping_real_zones() -> void:
	var resolver: Node = _make_game_stage()
	var herb := _zone_target("loot_herb_basket", HERB_YOLK, HERB_WHITE)
	var cabinet := _zone_target("memory_medicine_cabinet", CABINET_YOLK, CABINET_WHITE)
	var both: Array = [herb, cabinet]
	var both_reversed: Array = [cabinet, herb]

	# 兩個蛋黃區重疊的位置、一個只在藥櫃蛋黃區、一個只在竹籃蛋黃區
	var in_both_yolk := Vector2(-522, -20)
	var only_cabinet_yolk := Vector2(-480, -100)
	var only_herb_yolk := Vector2(-560, 20)
	_expect(Geometry2D.is_point_in_polygon(in_both_yolk, herb.selection_polygon) and Geometry2D.is_point_in_polygon(in_both_yolk, cabinet.selection_polygon), "fixture: the point is inside both yolk zones")
	_expect(Geometry2D.is_point_in_polygon(only_cabinet_yolk, cabinet.selection_polygon) and not Geometry2D.is_point_in_polygon(only_cabinet_yolk, herb.selection_polygon), "fixture: only the cabinet's yolk")
	_expect(Geometry2D.is_point_in_polygon(only_herb_yolk, herb.selection_polygon) and not Geometry2D.is_point_in_polygon(only_herb_yolk, cabinet.selection_polygon), "fixture: only the basket's yolk")
	# 也在對方的蛋白區裡（蛋白區不是蛋黃區，不影響滑鼠選取）
	_expect(Geometry2D.is_point_in_polygon(only_herb_yolk, herb.zone_polygon), "fixture: that yolk point is also inside the basket's own interaction zone")

	# 滑鼠：重疊處選畫面上在前面的（竹籃的底邊比藥櫃低），不論清單順序，結果一樣
	var picked_a: InteractionTarget = _resolver_script.pick_hover(in_both_yolk, both)
	var picked_b: InteractionTarget = _resolver_script.pick_hover(in_both_yolk, both_reversed)
	_expect(picked_a == picked_b and picked_a == herb, "both yolk zones under the mouse: the one in front (lower base) wins, independent of list order")
	_expect(_resolver_script.pick_hover(only_cabinet_yolk, both) == cabinet, "the mouse on the cabinet's own yolk selects the cabinet")
	_expect(_resolver_script.pick_hover(only_herb_yolk, both) == herb, "the mouse on the basket's own yolk selects the basket")
	# 明確的優先權還是最優先
	cabinet.priority = 5
	_expect(_resolver_script.pick_hover(in_both_yolk, both) == cabinet, "an explicit priority beats the depth rule")
	cabinet.priority = 0

	# 空白鍵：站在兩個蛋白區重疊的地方，看臉朝哪個蛋黃區
	var overlap_feet := Vector2(-480, 5)
	var player := _player(overlap_feet)
	_expect(herb.in_interaction_range(player) and cabinet.in_interaction_range(player), "fixture: standing inside both interaction zones")
	var toward_cabinet: Vector2 = InteractionGeometry.quantize_8(cabinet.selection_center() - overlap_feet)
	var toward_herb: Vector2 = InteractionGeometry.quantize_8(herb.selection_center() - overlap_feet)
	_expect(_resolver_script.pick_keyboard(player, toward_cabinet, both) == cabinet, "Space facing the cabinet's yolk opens the cabinet")
	_expect(_resolver_script.pick_keyboard(player, toward_herb, both) == herb, "Space facing the basket's yolk opens the basket")
	_expect(_resolver_script.pick_keyboard(player, toward_cabinet, both_reversed) == _resolver_script.pick_keyboard(player, toward_cabinet, both), "the list order never changes the answer")
	_expect(_resolver_script.pick_keyboard(player, -toward_cabinet, both) != cabinet, "facing away from the cabinet never opens it")

	# 滑鼠點藥櫃的蛋黃區，但人站在竹籃的蛋白區裡：只會往藥櫃走，到了藥櫃的蛋白區才開藥櫃，竹籃一次都不會開
	var calls := {"herb": 0, "cabinet": 0}
	herb.handler = func(_p: Node2D) -> void: calls["herb"] += 1
	cabinet.handler = func(_p: Node2D) -> void: calls["cabinet"] += 1
	_fake_player.global_position = Vector2(-540, 60)
	_expect(herb.in_interaction_range(_fake_player) and not cabinet.in_interaction_range(_fake_player), "fixture: standing in the basket's zone only")
	resolver.mouse_world_override = only_cabinet_yolk
	resolver.call("_on_left_pressed")
	_expect(resolver.call("current_intent") == "INTERACT_APPROACH", "clicking the cabinet's yolk locks the cabinet")
	for i in 600:
		_step(resolver)
		if int(calls["cabinet"]) > 0:
			break
	_expect(int(calls["herb"]) == 0 and int(calls["cabinet"]) == 1, "only the cabinet opens (herb=%d cabinet=%d)" % [int(calls["herb"]), int(calls["cabinet"])])
	await create_timer(0.05).timeout
	resolver.call("_on_left_released")

	# 反過來：點竹籃的蛋黃區，人站在藥櫃的蛋白區裡，只開竹籃
	calls["herb"] = 0
	calls["cabinet"] = 0
	_fake_player.global_position = Vector2(-400, -20)
	_expect(cabinet.in_interaction_range(_fake_player) and not herb.in_interaction_range(_fake_player), "fixture: standing in the cabinet's zone only")
	resolver.mouse_world_override = only_herb_yolk
	resolver.call("_on_left_pressed")
	for i in 900:
		_step(resolver)
		if int(calls["herb"]) > 0:
			break
	_expect(int(calls["cabinet"]) == 0 and int(calls["herb"]) == 1, "only the basket opens (herb=%d cabinet=%d)" % [int(calls["herb"]), int(calls["cabinet"])])
	await create_timer(0.05).timeout
	resolver.call("_on_left_released")
	_fake_root.free()
	_fake_root = null
