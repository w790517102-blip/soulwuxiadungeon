extends RefCounted
class_name InteractionGeometry

# ------------------------------------------------------------
# 探索互動用的幾何小工具（純函式）：點到矩形／多邊形的距離、角色畫面上可見範圍與腳底、八方向量化。
# 互動距離一律用「點到有效幾何區域」，不是點到物件中心——大型、長形的目標（魚怪、石碑、車輛）才不會因為中心點太遠而互動不到。
# ------------------------------------------------------------

static var _bounds_cache: Dictionary = {}


## 點到矩形的距離（在矩形內回傳 0）。
static func distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy: float = maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return sqrt(dx * dx + dy * dy)


static func closest_point_on_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))


static func point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, polygon)


## 多邊形（至少 3 個點）上離 point 最近的位置；在多邊形內部時就是 point 本身（距離 0）。
static func closest_point_on_polygon(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	if polygon.size() == 0:
		return point
	if polygon.size() < 3:
		return polygon[0]
	if point_in_polygon(point, polygon):
		return point
	var best: Vector2 = polygon[0]
	var best_distance: float = INF
	for i in polygon.size():
		var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		var d: float = point.distance_to(candidate)
		if d < best_distance:
			best_distance = d
			best = candidate
	return best


static func distance_to_polygon(point: Vector2, polygon: PackedVector2Array) -> float:
	if polygon.size() == 0:
		return INF
	return point.distance_to(closest_point_on_polygon(point, polygon))


## 矩形四個角（世界座標）組成的多邊形（依序）。
static func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## 方向量化成八方向（與劉語塵的八方向動畫、WASD 組合出來的方向一致：斜向是單位向量）。零向量回傳零向量。
static func quantize_8(direction: Vector2) -> Vector2:
	if direction.length_squared() < 0.000001:
		return Vector2.ZERO
	var sector: int = int(roundf(direction.angle() / (PI / 4.0)))
	return Vector2.from_angle(float(sector) * PI / 4.0)


# ------------------------------------------------------------
# 角色畫面上的可見範圍（用目前這一格圖的不透明像素算出，AnimatedSprite2D 的縮放與位移都算進去）
# ------------------------------------------------------------
static func find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node == null:
		return null
	if node is AnimatedSprite2D:
		return node
	var direct := node.get_node_or_null("AnimatedSprite2D")
	if direct is AnimatedSprite2D:
		return direct
	for child in node.get_children():
		var found := find_animated_sprite(child)
		if found:
			return found
	return null


static func _opaque_bounds(texture: Texture2D) -> Rect2i:
	var key: String = "%s|%s" % [str(texture.get_rid().get_id()), str(texture.get_size())]
	if texture is AtlasTexture:
		key = "%d|%s" % [(texture as AtlasTexture).atlas.get_rid().get_id(), str((texture as AtlasTexture).region)]
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var image: Image = texture.get_image()
	var result := Rect2i(0, 0, int(texture.get_size().x), int(texture.get_size().y))
	if image != null:
		var used: Rect2i = image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			result = used
	_bounds_cache[key] = result
	return result


## 節點在畫面（世界座標）上看得到的範圍；找不到 sprite 時回傳以節點位置為點的空矩形。
static func visible_rect(node: Node2D) -> Rect2:
	var sprite: AnimatedSprite2D = find_animated_sprite(node)
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return Rect2(node.global_position, Vector2.ZERO)
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2(node.global_position, Vector2.ZERO)
	var used: Rect2i = _opaque_bounds(texture)
	var size: Vector2 = texture.get_size()
	var origin: Vector2 = -size * 0.5 if sprite.centered else Vector2.ZERO
	var local_rect := Rect2(origin + Vector2(used.position) + sprite.offset, Vector2(used.size))
	var corners := [
		sprite.to_global(local_rect.position),
		sprite.to_global(Vector2(local_rect.end.x, local_rect.position.y)),
		sprite.to_global(local_rect.end),
		sprite.to_global(Vector2(local_rect.position.x, local_rect.end.y)),
	]
	var min_p: Vector2 = corners[0]
	var max_p: Vector2 = corners[0]
	for c in corners:
		min_p = Vector2(minf(min_p.x, c.x), minf(min_p.y, c.y))
		max_p = Vector2(maxf(max_p.x, c.x), maxf(max_p.y, c.y))
	return Rect2(min_p, max_p - min_p)


## 畫面上看到的腳底中心（世界座標）。
static func feet(node: Node2D) -> Vector2:
	var rect: Rect2 = visible_rect(node)
	if rect.size == Vector2.ZERO:
		return node.global_position
	return Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)
