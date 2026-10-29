class_name WalkBounds
extends StaticBody2D

# 地圖可走範圍：子節點 CollisionPolygon2D（Segments 模式）畫出的每個封閉圈就是邊界線，線本身就是「能走到哪」的極限。
# 在編輯器裡直接拖頂點就能修。哪一側可走由「被幾圈包住」的奇偶決定：外框內可走、框裡再圈出來的竹叢／石頭不可走。
# 薄薄一條線擋不住會滑過去的角色（尖角處會鑽出去），所以執行時把每條邊往「不可走」那一側加厚成實心牆，
# 牆完全在線的外側，不會把可走範圍往內吃；原本的線圈只留給編輯器顯示。

const WALL_THICKNESS := 60.0
const END_EXTEND := 6.0
# 劉語塵的腳碰撞是橫躺的膠囊（Liu_Yu.tscn：半徑 16.6、高 107.9、旋轉約 90°、角色縮放 0.3）：
# 橫向半長約 11.2、半徑約 5。牆如果貼著線，碰撞中心會停在線內 16px（橫向）／5px（縱向），看起來像邊界縮進去。
# 所以牆往不可走那側再退一個「角色在該方向的半寬」，讓腳的碰撞中心剛好能走到畫的那條線上。
const PLAYER_HALF_LENGTH := 11.2
const PLAYER_RADIUS := 5.0

func _ready() -> void:
	var loops: Array[PackedVector2Array] = []
	var sources: Array[CollisionPolygon2D] = []
	for c in get_children():
		if c is CollisionPolygon2D and c.polygon.size() >= 3:
			var pts := PackedVector2Array()
			for p in c.polygon:
				pts.append(c.transform * p)
			loops.append(pts)
			sources.append(c)
	for s in sources:
		s.set_deferred("disabled", true)
	for pts in loops:
		for i in pts.size():
			_add_wall(pts[i], pts[(i + 1) % pts.size()], loops)

func _walkable_at(p: Vector2, loops: Array[PackedVector2Array]) -> bool:
	var inside := 0
	for l in loops:
		if Geometry2D.is_point_in_polygon(p, l):
			inside += 1
	return inside % 2 == 1

func _add_wall(a: Vector2, b: Vector2, loops: Array[PackedVector2Array]) -> void:
	var d := b - a
	if d.length() < 0.5:
		return
	var dir := d.normalized()
	var n := Vector2(-dir.y, dir.x)
	var mid := (a + b) * 0.5
	var walk_plus := _walkable_at(mid + n * 2.0, loops)
	var walk_minus := _walkable_at(mid - n * 2.0, loops)
	if walk_plus == walk_minus:
		return   # 兩側同樣可走（或同樣不可走，例如線重疊在別的線上）：這條邊不用牆
	var out := -n if walk_plus else n
	var shift := PLAYER_HALF_LENGTH * absf(n.x) + PLAYER_RADIUS
	var a2 := a - dir * END_EXTEND + out * shift
	var b2 := b + dir * END_EXTEND + out * shift
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([a2, b2, b2 + out * WALL_THICKNESS, a2 + out * WALL_THICKNESS])
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
