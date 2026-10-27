class_name ObjectInteractionAdapter
extends RefCounted

# 舊式「物件」（調香室的煉藥桌／藥櫃／配方、琴室的古琴與發聲石板、符咒室的三張符咒）：
# 原本是「空白鍵 + Area2D 進出」，沒有滑鼠游標也不能點著走過去互動。這裡自動替它們接上三層互動：
#   蛋黃區（滑鼠選取）  ＝ 物件自己的 Area2D 形狀
#   蛋白區（有效互動）  ＝ 蛋黃區往外擴張 EXPAND 像素
#   游標               ＝ 白色饅頭手（inspect）
# 滑鼠點一下 → 走進蛋白區 → 互動；空白鍵也走中央的 InteractionResolver。舊的 Area2D 不再當觸發範圍
# （monitoring 關掉，不會空白鍵被新舊兩套各處理一次）。
#
# 場景裡手畫了 InteractionTarget 的物件不會被這裡覆蓋（手畫優先）。
# 之後要調整某個物件的蛋白區大小：在物件節點上 set_meta("interaction_expand", 像素)。

const DEFAULT_EXPAND := 40.0
const EXPAND_META := "interaction_expand"
const OPT_OUT_META := "custom_interaction_zone"
const YOLK_META := "zone_yolk"        # 手畫蛋黃（PackedVector2Array，物件區域座標）；沒畫就用 Area2D 外框
const WHITE_META := "zone_white"      # 手畫蛋白；沒有就把蛋黃往外擴張
# 場景根節點上手畫的出口：exit_yolk／exit_white 多邊形、exit_method（走進蛋白區時呼叫的出口函式，參數是玩家）、exit_name（游標提示）
const EXIT_YOLK_META := "exit_yolk"
const EXIT_WHITE_META := "exit_white"
const EXIT_METHOD_META := "exit_method"
const EXIT_NAME_META := "exit_name"
const EXIT_NODE_NAME := "ExitInteractionTarget"
const EXIT_IDS_META := "exit_ids"
const EXIT_BUSY_META := "exit_busy"
const CIRCLE_SEGMENTS := 20

## 物件腳本（檔名）→ 互動函式名稱
const OBJECT_SCRIPTS := {
	"alchemy_table.gd": "_interact",
	"medicine_cabinet.gd": "_interact",
	"alchemy_recipe.gd": "_interact",
	"Gu_qin_Interactable.gd": "interact",
	"Music_Plate.gd": "interact",
}

const TALISMAN_ROOM_SCRIPT := "yuheng_sewer_talisman_room.gd"


## 掃一個場景底下所有符合的物件，回傳這次套用的數量。
static func adopt_scene(scene_root: Node) -> int:
	var count := 0
	for node in _collect(scene_root):
		if _adopt_object(node):
			count += 1
	if _script_file(scene_root) == TALISMAN_ROOM_SCRIPT:
		count += _adopt_talisman_room(scene_root)
	count += _adopt_room_exits(scene_root)
	return count


static func _script_file(node: Node) -> String:
	var script: Script = node.get_script() as Script
	return String(script.resource_path).get_file() if script != null else ""


static func _collect(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if OBJECT_SCRIPTS.has(_script_file(child)):
			out.append(child)
		out.append_array(_collect(child))
	return out


static func _has_hand_drawn_target(node: Node) -> bool:
	for child in node.get_children():
		if child is InteractionTarget:
			return true
	return false


static func _adopt_object(obj: Node) -> bool:
	if obj.has_meta(OPT_OUT_META) or _has_hand_drawn_target(obj):
		return false
	var area := obj.get_node_or_null("Area2D") as Area2D
	if area == null:
		return false
	var method: String = String(OBJECT_SCRIPTS[_script_file(obj)])
	var handler := func(_player: Node2D) -> void:
		if not is_instance_valid(obj) or bool(obj.get("interaction_locked")):
			return
		obj.set("player_inside", true)      # 舊腳本有些會檢查「玩家在範圍內」；走進蛋白區才會跑到這裡，所以是真的
		await obj.call(method)
		# 互動結束就放掉：舊腳本的 _process／_unhandled_input 看到 player_inside 為 true 會自己再被空白鍵觸發一次（新舊各跑一次）
		if is_instance_valid(obj):
			obj.set("player_inside", false)
	return _attach(obj, area, handler, String(obj.name))


## 符咒室：三張符咒各有一個 Area2D，互動由房間腳本統一處理（current_target_id + _interact_talisman）。
static func _adopt_talisman_room(room: Node) -> int:
	var paths: Dictionary = room.get("TALISMAN_AREA_PATHS") if room.get("TALISMAN_AREA_PATHS") != null else {}
	var count := 0
	for id in paths.keys():
		var area := room.get_node_or_null(String(paths[id])) as Area2D
		if area == null:
			continue
		var holder: Node = area.get_parent()
		if holder.has_meta(OPT_OUT_META) or _has_hand_drawn_target(holder):
			continue
		var talisman_id := String(id)
		var handler := func(_player: Node2D) -> void:
			if not is_instance_valid(room) or bool(room.get("interaction_locked")):
				return
			room.set("current_target_id", talisman_id)
			await room.call("_interact_talisman", talisman_id)
			if is_instance_valid(room):
				room.set("current_target_id", "")
		if _attach(holder, area, handler, "%s_talisman" % talisman_id):
			count += 1
	return count


## 場景根節點上手畫的出口（游標是出口箭頭）。出口原本的 Area2D 照舊（走進去一樣會離開），這裡只多一層滑鼠點擊＋走到蛋白區才離開。
## 一個出口：exit_yolk／exit_white／exit_method／exit_name。多個出口：exit_ids（PackedStringArray）＋每個 id 一組 exit_<id>_yolk／_white／_method／_name。
static func _adopt_room_exits(room: Node) -> int:
	var ids: Array = [""]
	if room.has_meta(EXIT_IDS_META):
		ids = Array(room.get_meta(EXIT_IDS_META))
	var count := 0
	for id in ids:
		if _adopt_room_exit(room, String(id)):
			count += 1
	return count


static func _exit_key(base: String, id: String) -> String:
	return base if id == "" else base.replace("exit_", "exit_%s_" % id)


static func _adopt_room_exit(room: Node, id: String) -> bool:
	var node_name := EXIT_NODE_NAME if id == "" else "%s_%s" % [EXIT_NODE_NAME, id]
	if not room.has_meta(_exit_key(EXIT_YOLK_META, id)) or room.has_node(node_name):
		return false
	var method := String(room.get_meta(_exit_key(EXIT_METHOD_META, id), ""))
	if method == "" or not room.has_method(method):
		return false
	var handler := func(player: Node2D) -> void:
		if not is_instance_valid(room) or bool(room.get("interaction_locked")) or bool(room.get_meta(EXIT_BUSY_META, false)):
			return
		room.set_meta(EXIT_BUSY_META, true)      # 出口一旦觸發就不再重複（淡出途中再點、或又走進原本的出口 Area2D）
		if Callable(room, method).get_argument_count() == 4:
			await room.call(method, RID(), player, 0, 0)      # body_shape_entered 版本
		else:
			await room.call(method, player)
	var target := _make_target(room, room.get_meta(_exit_key(EXIT_YOLK_META, id)), room.get_meta(_exit_key(EXIT_WHITE_META, id), PackedVector2Array()), handler, String(room.get_meta(_exit_key(EXIT_NAME_META, id), "出口")), "exit")
	if target == null:
		return false
	target.name = node_name
	return true


static func _attach(owner_node: Node, area: Area2D, handler: Callable, display_name: String) -> bool:
	var yolk := PackedVector2Array()
	var white := PackedVector2Array()
	# 場景裡手畫的蛋黃／蛋白（物件節點的 metadata，座標是物件的區域座標）；各自沒畫的就用預設：
	# 蛋黃＝Area2D 外框、蛋白＝蛋黃往外擴張
	if owner_node.has_meta(YOLK_META):
		yolk = owner_node.get_meta(YOLK_META)
	else:
		yolk = yolk_polygon(owner_node, area)
	if owner_node.has_meta(WHITE_META):
		white = owner_node.get_meta(WHITE_META)
	if _make_target(owner_node, yolk, white, handler, display_name, "inspect", float(owner_node.get_meta(EXPAND_META, DEFAULT_EXPAND))) == null:
		return false
	area.set_deferred("monitoring", false)
	return true


## 沒給蛋白（少於 3 點）就把蛋黃往外擴張 expand 像素。
static func _make_target(owner_node: Node, yolk: PackedVector2Array, white: PackedVector2Array, handler: Callable, display_name: String, cursor_kind: String, expand: float = DEFAULT_EXPAND) -> InteractionTarget:
	if yolk.size() < 3:
		return null
	if white.size() < 3:
		white = expanded(yolk, expand)
	var target := InteractionTarget.new()
	target.name = "InteractionTarget"
	target.mode = InteractionTarget.Mode.ZONE
	target.display_name = display_name
	target.cursor_kind = cursor_kind
	target.selection_polygon = yolk
	target.zone_polygon = white
	target.interaction_radius = 0.0
	target.hover_margin = 2.0
	target.use_sprite_feet = false
	target.handler = handler
	owner_node.add_child(target)
	return target


## 物件自己的 Area2D 形狀（所有 CollisionShape2D／CollisionPolygon2D 合起來的外框），座標是 owner_node 的區域座標。
static func yolk_polygon(owner_node: Node, area: Area2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var to_owner: Transform2D = _relative_transform(owner_node, area)
	for child in area.get_children():
		var local_points := PackedVector2Array()
		var xf: Transform2D = to_owner
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			xf = to_owner * (child as CollisionShape2D).transform
			local_points = _shape_points((child as CollisionShape2D).shape)
		elif child is CollisionPolygon2D:
			xf = to_owner * (child as CollisionPolygon2D).transform
			local_points = (child as CollisionPolygon2D).polygon
		for p in local_points:
			points.append(xf * p)
	if points.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)      # convex_hull 會把第一個點在最後重複一次
	return hull


static func _relative_transform(owner_node: Node, area: Node2D) -> Transform2D:
	# area 相對於 owner_node 的變換（area 通常是 owner_node 的直接子節點，也可能更深）
	var xf := Transform2D.IDENTITY
	var cur: Node = area
	while cur != null and cur != owner_node:
		if cur is Node2D:
			xf = (cur as Node2D).transform * xf
		cur = cur.get_parent()
	return xf


static func _shape_points(shape: Shape2D) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if shape is RectangleShape2D:
		var half: Vector2 = (shape as RectangleShape2D).size * 0.5
		pts = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	elif shape is CircleShape2D:
		var r: float = (shape as CircleShape2D).radius
		for i in CIRCLE_SEGMENTS:
			var a := TAU * float(i) / float(CIRCLE_SEGMENTS)
			pts.append(Vector2(cos(a), sin(a)) * r)
	elif shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		var hh: float = cap.height * 0.5
		var rr: float = cap.radius
		for i in 8:
			var a := PI * float(i) / 7.0
			pts.append(Vector2(cos(a) * rr, -hh + rr - sin(a) * rr))
		for i in 8:
			var a := PI * float(i) / 7.0
			pts.append(Vector2(-cos(a) * rr, hh - rr + sin(a) * rr))
	elif shape is ConvexPolygonShape2D:
		pts = (shape as ConvexPolygonShape2D).points
	elif shape is ConcavePolygonShape2D:
		pts = (shape as ConcavePolygonShape2D).segments
	return pts


## 蛋白區：蛋黃區往外擴張 distance 像素（圓角，取最大的一塊）
static func expanded(polygon: PackedVector2Array, distance: float) -> PackedVector2Array:
	var result: Array = Geometry2D.offset_polygon(polygon, distance, Geometry2D.JOIN_ROUND)
	var best := PackedVector2Array()
	var best_area := -1.0
	for poly in result:
		var a := absf(_area(poly))
		if a > best_area:
			best_area = a
			best = poly
	return best if best.size() >= 3 else polygon


static func _area(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		total += a.x * b.y - b.x * a.y
	return total * 0.5
