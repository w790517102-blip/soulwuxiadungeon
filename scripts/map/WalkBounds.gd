class_name WalkBounds
extends StaticBody2D

# 地圖可走範圍：子節點 CollisionPolygon2D（Segments 模式）畫出的每個封閉圈就是一道牆的中心線。
# 在編輯器裡直接拖頂點就能修。外框內是可走，圈出來的竹叢／石頭是不可走，這是畫的人決定的，這裡不用判斷。
# 薄薄一條線擋不住會滑過去的角色（尖角處會鑽出去），所以執行時把每條邊加粗成兩端圓頭的實心牆，
# 原本的線圈只留給編輯器顯示。牆往兩側各長 WALL_RADIUS，畫邊界時把它當成「路的邊緣再往外一點」。

const WALL_RADIUS := 14.0

func _ready() -> void:
	var sources: Array[CollisionPolygon2D] = []
	for c in get_children():
		if c is CollisionPolygon2D and c.polygon.size() >= 3:
			sources.append(c)
	for s in sources:
		s.set_deferred("disabled", true)
		var pts := PackedVector2Array()
		for p in s.polygon:
			pts.append(s.transform * p)
		for i in pts.size():
			_add_wall(pts[i], pts[(i + 1) % pts.size()])

func _add_wall(a: Vector2, b: Vector2) -> void:
	if a.distance_to(b) < 0.5:
		return
	var bands := Geometry2D.offset_polyline(PackedVector2Array([a, b]), WALL_RADIUS, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	for band in bands:
		var shape := ConvexPolygonShape2D.new()
		shape.points = band
		var cs := CollisionShape2D.new()
		cs.shape = shape
		add_child(cs)
