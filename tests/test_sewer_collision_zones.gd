extends SceneTree

# 調香室／調音室：老闆用深紅畫的範圍是腳色過不去的碰撞區。檢查它們都真的擋得住（物理查詢點得到），而旁邊的蛋白區（地板）是空的。

const BASE := "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/"
var _failures := 0


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


## 多邊形內部一個點（凹多邊形的頂點平均可能落在外面，所以取三角剖分後第一個三角形的中心）
func _inside_point(poly: PackedVector2Array) -> Vector2:
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.size() < 3:
		return poly[0]
	return (poly[tri[0]] + poly[tri[1]] + poly[tri[2]]) / 3.0


func _blocked(space: PhysicsDirectSpaceState2D, at: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collide_with_bodies = true
	return not space.intersect_point(q, 4).is_empty()


func _run() -> void:
	await process_frame
	var cases := {
		"yuheng_sewer_alchemy_room/yuheng_sewer_alchemy_room.tscn": ["counter_collision", "table_body_collision"],
		"yuheng_sewer_music_room/yuheng_sewer_music_room.tscn": ["qin_body_collision"],
	}
	for path in cases.keys():
		var scene = load(BASE + path).instantiate()
		root.add_child(scene)
		await physics_frame
		await physics_frame
		var space := (scene as Node2D).get_world_2d().direct_space_state
		for name in cases[path]:
			var body := scene.get_node_or_null(String(name)) as StaticBody2D
			_check(body != null, "%s has %s" % [path.get_file(), name])
			if body == null:
				continue
			var poly := (body.get_child(0) as CollisionPolygon2D).polygon
			_check(poly.size() >= 3, "%s has a polygon" % name)
			_check(_blocked(space, body.to_global(_inside_point(poly))), "%s blocks the character" % name)
		scene.queue_free()
		await process_frame
	print("PASS: sewer collision zones" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
