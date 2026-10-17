extends Node2D
class_name InteractionTarget

# ------------------------------------------------------------
# 可互動目標（探索模式）：掛在 NPC／機關／大型物件底下的一個元件。
#
# 互動有三層區域，責任完全分開（而且不必同心、同大小、同形狀）：
#   1. 碰撞區（Physical Collision）：NPC／物件自己的 CollisionShape2D，只負責物理阻擋。這個元件完全不看它。
#   2. 蛋黃區（Mouse Selection Zone）：滑鼠指到哪裡算「選中」它。預設是畫面上看到的角色外框；也可以用 selection_rect／selection_polygon
#      另外指定（獨立選取形狀）。滑鼠進入蛋黃區：游標變互動圖示、成為 Hover 目標；點擊才會建立互動意圖。Hover 本身不啟動對話。
#   3. 蛋白區（Interaction Range）：劉語塵「已經靠近到可以執行互動」的資格，不是觸發事件的 Area2D。三種模式見下。
#      劉語塵走進蛋白區不會自動對話；滑鼠進入蛋白區也不會變互動圖示。只有玩家明確提出互動命令（點蛋黃區、或按 Space）才會用到它。
#
# 蛋白區的三種距離模式（mode）：
#   SPECIAL_AREA（A）手工繪製的特殊互動位置（白箋居櫃檯前、隔窗、必須站在指定位置的機關）：劉語塵必須在 special_area 這個 Area2D 裡。
#   RADIUS（B）固定半徑：劉語塵腳底到目標的互動 Anchor（預設是畫面上看到的腳底）小於 interaction_radius。一般 NPC 用這個。
#   ZONE（C）Reference Zone 邊界距離：劉語塵腳底到 Reference Zone（矩形／多邊形）最近位置的距離小於 interaction_radius。
#            大型、長形的目標用；Reference Zone 只是蛋白區的幾何依據，不是蛋黃區，也不是戰鬥碰撞箱。
#
# 不需要特殊區域的 NPC 不用再畫 Area2D；需要特殊位置的場景保留原本的 Area2D（A）。這個元件不取代自動劇情觸發區或傳送入口。
# ------------------------------------------------------------

enum Mode { SPECIAL_AREA, RADIUS, ZONE }

## 互動被執行（handler 跑完之後）。
signal interacted(player: Node2D)

@export var mode: Mode = Mode.RADIUS
@export var display_name: String = ""
## 滑鼠指到時的游標種類（見 InteractionResolver.CURSOR_KINDS）。
@export var cursor_kind: String = "talk"
## 重疊時的優先權：距離相同（或滑鼠同時在兩個目標上）時，數字大的先。
@export var priority: int = 0
## B：腳底到 Anchor 的距離；C：腳底到 Reference Zone 的距離。單位是世界座標的像素。
@export var interaction_radius: float = 90.0
## 蛋黃區：滑鼠離蛋黃區多近還算「指到」（滑鼠在蛋黃區內時距離是 0；0 = 必須在蛋黃區裡）。這是滑鼠選取的範圍，跟蛋白區（interaction_radius）無關。
@export var hover_margin: float = 6.0
## 蛋黃區的獨立選取形狀（本元件的區域座標）。給 polygon 就用 polygon，否則給 rect 就用 rect；都沒給就用角色畫面上看到的外框。
@export var selection_rect: Rect2 = Rect2()
@export var selection_polygon: PackedVector2Array = PackedVector2Array()
## 互動 Anchor 的來源節點（預設是這個元件的父節點，也就是 NPC 本身）。
@export var anchor_node: NodePath
## 以節點的畫面腳底為 Anchor（NPC 的節點原點常常離腳底很遠）。關掉就用 anchor_node 的原點。
@export var use_sprite_feet: bool = true
@export var anchor_offset: Vector2 = Vector2.ZERO
## C：Reference Zone，本元件的區域座標。給 polygon 就用 polygon，否則用 rect。
@export var zone_rect: Rect2 = Rect2()
@export var zone_polygon: PackedVector2Array = PackedVector2Array()
## A：特殊互動區（Area2D）。
@export var special_area: NodePath
## 指定互動側（世界座標方向；零向量 = 不限）：劉語塵必須在目標中心的這一側。
@export var interaction_side: Vector2 = Vector2.ZERO
## 劉語塵腳底到最近位置之間不能被障礙擋住（防止隔著牆互動）。
@export var require_clear_path: bool = false
@export_flags_2d_physics var path_block_mask: int = 1
@export var enabled: bool = true
## Space 要求臉朝向蛋黃區：劉語塵的八方向面向，和「腳底到蛋黃區中心」的方向夾角不能超過 facing_max_angle_deg（八方向每格 45 度，所以預設 45）。
## 只管空白鍵；滑鼠點擊蛋黃區本來就表達了對象，不看面向。
@export var require_facing: bool = false
@export var facing_max_angle_deg: float = 45.0

## 互動時呼叫（可以是協程）：handler.call(player)。
var handler: Callable = Callable()
## 目前場景條件是否允許互動：availability.call() -> bool（沒設定 = 永遠允許）。
var availability: Callable = Callable()


func _ready() -> void:
	add_to_group("interaction_target")


func _anchor_owner() -> Node2D:
	if not anchor_node.is_empty():
		var node := get_node_or_null(anchor_node)
		if node is Node2D:
			return node
	var parent := get_parent()
	return parent if parent is Node2D else self


## 目標有效嗎（在場景裡、看得見、啟用、場景條件允許）。
func is_available() -> bool:
	if not enabled or not is_inside_tree() or not is_visible_in_tree():
		return false
	if availability.is_valid() and not bool(availability.call()):
		return false
	return true


## 互動 Anchor（世界座標）。
func anchor_point() -> Vector2:
	var owner_node := _anchor_owner()
	var base: Vector2 = InteractionGeometry.feet(owner_node) if use_sprite_feet else owner_node.global_position
	return base + anchor_offset


## 蛋黃區的預設形狀（世界座標）：NPC 的畫面外框；沒有 sprite 就用 Anchor 附近的小範圍。
func hover_rect() -> Rect2:
	var rect: Rect2 = InteractionGeometry.visible_rect(_anchor_owner())
	if rect.size == Vector2.ZERO:
		var anchor := anchor_point()
		return Rect2(anchor - Vector2(16, 48), Vector2(32, 48))
	return rect


## Reference Zone 的多邊形（世界座標）。
func zone_world_polygon() -> PackedVector2Array:
	var local_polygon: PackedVector2Array = zone_polygon
	if local_polygon.size() < 3:
		if zone_rect.size == Vector2.ZERO:
			return PackedVector2Array()
		local_polygon = InteractionGeometry.rect_polygon(zone_rect)
	var world := PackedVector2Array()
	for point in local_polygon:
		world.append(to_global(point))
	return world


## 蛋黃區的多邊形（世界座標）；沒有獨立選取形狀時回傳空的（用預設的角色外框）。
func selection_world_polygon() -> PackedVector2Array:
	var local_polygon: PackedVector2Array = selection_polygon
	if local_polygon.size() < 3:
		if selection_rect.size == Vector2.ZERO:
			return PackedVector2Array()
		local_polygon = InteractionGeometry.rect_polygon(selection_rect)
	var world := PackedVector2Array()
	for point in local_polygon:
		world.append(to_global(point))
	return world


## 滑鼠到蛋黃區的距離（用來決定滑鼠選誰）。只看蛋黃區：蛋白區（Reference Zone、互動半徑、特殊互動區）不算指得到的範圍。
func hover_distance(world_point: Vector2) -> float:
	var polygon: PackedVector2Array = selection_world_polygon()
	if polygon.size() >= 3:
		return InteractionGeometry.distance_to_polygon(world_point, polygon)
	return InteractionGeometry.distance_to_rect(world_point, hover_rect())


func is_hovered(world_point: Vector2) -> bool:
	return hover_distance(world_point) <= hover_margin


## 劉語塵腳底到這個目標的距離（用來決定空白鍵選誰、以及能不能互動）。A 型：在特殊互動區裡是 0，否則是 INF。
func interaction_distance(player: Node2D) -> float:
	var feet: Vector2 = InteractionGeometry.feet(player)
	match mode:
		Mode.SPECIAL_AREA:
			return 0.0 if _player_in_special_area(player) else INF
		Mode.ZONE:
			return InteractionGeometry.distance_to_polygon(feet, zone_world_polygon())
		_:
			return feet.distance_to(anchor_point())


## 畫面上的「前後」：蛋黃區最底下的 y（腳底那一側）。y 越大越靠近鏡頭、畫在前面。兩個蛋黃區重疊時，滑鼠點在重疊處選前面那個。
func depth_y() -> float:
	var polygon: PackedVector2Array = selection_world_polygon()
	if polygon.size() >= 3:
		var bottom: float = polygon[0].y
		for point in polygon:
			bottom = maxf(bottom, point.y)
		return bottom
	return hover_rect().end.y


## 蛋黃區的中心（世界座標）：獨立選取形狀的頂點平均；沒有就用角色外框的中心。面向判斷與空白鍵同距時的比較用它。
func selection_center() -> Vector2:
	var polygon: PackedVector2Array = selection_world_polygon()
	if polygon.size() >= 3:
		var sum := Vector2.ZERO
		for point in polygon:
			sum += point
		return sum / float(polygon.size())
	return hover_rect().get_center()


## 劉語塵目前的面向是不是對著蛋黃區（只在 require_facing 時檢查）。
func facing_ok(player: Node2D, facing: Vector2) -> bool:
	if not require_facing:
		return true
	if facing == Vector2.ZERO:
		return false
	var to_center: Vector2 = selection_center() - InteractionGeometry.feet(player)
	if to_center.length() < 1.0:
		return true
	return rad_to_deg(absf(facing.angle_to(to_center))) <= facing_max_angle_deg + 0.5


## 現在劉語塵能不能跟它互動（距離、互動側、障礙都通過）。
func in_interaction_range(player: Node2D) -> bool:
	if player == null:
		return false
	var feet: Vector2 = InteractionGeometry.feet(player)
	var distance: float = interaction_distance(player)
	if mode == Mode.SPECIAL_AREA:
		return distance == 0.0 and _side_ok(feet)
	if distance > interaction_radius or not _side_ok(feet):
		return false
	if require_clear_path:
		var nearest: Vector2 = _nearest_point(feet)
		if not _path_clear(feet, nearest, player):
			return false
	return true


func _player_in_special_area(player: Node2D) -> bool:
	if special_area.is_empty():
		return false
	var area := get_node_or_null(special_area) as Area2D
	return area != null and area.monitoring and area.overlaps_body(player)


func _nearest_point(feet: Vector2) -> Vector2:
	if mode == Mode.ZONE:
		return InteractionGeometry.closest_point_on_polygon(feet, zone_world_polygon())
	return anchor_point()


func _side_ok(feet: Vector2) -> bool:
	if interaction_side == Vector2.ZERO:
		return true
	var center: Vector2 = anchor_point()
	if mode == Mode.ZONE:
		var polygon := zone_world_polygon()
		if polygon.size() >= 3:
			var sum := Vector2.ZERO
			for p in polygon:
				sum += p
			center = sum / float(polygon.size())
	return (feet - center).dot(interaction_side.normalized()) > 0.0


## 物理射線：腳底到目標最近位置之間有沒有被擋住（只看 path_block_mask 的障礙，排除劉語塵自己）。
func _path_clear(from: Vector2, to: Vector2, player: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, path_block_mask)
	var excluded: Array[RID] = []
	if player is CollisionObject2D:
		excluded.append((player as CollisionObject2D).get_rid())
	# 目標自己的碰撞體（NPC 本身的 CollisionShape2D）不算「擋住」
	var owner_node := _anchor_owner()
	if owner_node is CollisionObject2D:
		excluded.append((owner_node as CollisionObject2D).get_rid())
	query.exclude = excluded
	return space.intersect_ray(query).is_empty()
