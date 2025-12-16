extends Camera2D

var _world_bounds: Rect2
var _target: Node2D
var _bounds_ready: bool = false

@export var target_path: NodePath = "/root/GameRoot/LiuYu"
@export var debug_draw_bounds: bool = false

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame

	_target = get_node_or_null(target_path)
	if _target == null:
		print("[Camera DEBUG] 嘗試備援從 GameRoot 內抓 LiuYu...")
		var game_root := get_tree().get_root().get_node_or_null("GameRoot")
		if game_root:
			_target = game_root.get_node_or_null("LiuYu")
			if _target:
				print("[Camera DEBUG] 從 GameRoot 抓到劉語塵！")

	if _target:
		print("[Camera] 追蹤對象設定成功：", _target.name)
	else:
		push_warning("[Camera] 無法找到追蹤對象：" + str(target_path))

func set_bounds_from_area(area: Area2D):
	if not area:
		push_warning("[Camera] 傳入的 Area2D 無效！")
		return

	var shape := area.get_node("CollisionShape2D").shape as RectangleShape2D
	var rect_position: Vector2 = area.get_global_transform().origin - shape.extents
	var rect_size: Vector2 = shape.extents * 2.0

	limit_left = int(rect_position.x)
	limit_top = int(rect_position.y)
	limit_right = int(rect_position.x + rect_size.x)
	limit_bottom = int(rect_position.y + rect_size.y)

	set_world_bounds(Rect2(rect_position, rect_size))
	make_current()
	print("[Camera] 新場景邊界設定完成:", Rect2(rect_position, rect_size))

func set_world_bounds(r: Rect2) -> void:
	_world_bounds = r
	_bounds_ready = _world_bounds != Rect2()
	if _bounds_ready:
		print("[Camera] world bounds set:", _world_bounds)
	queue_redraw()

func _process(_delta):
	if not is_current() or _target == null or not _bounds_ready:
		return

	var desired := _target.global_position
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half_view: Vector2 = vp_size * 0.5 * zoom

	var left   := _world_bounds.position.x
	var top    := _world_bounds.position.y
	var right  := left + _world_bounds.size.x
	var bottom := top  + _world_bounds.size.y

	var final_pos := desired

	if _world_bounds.size.x <= 2.0 * half_view.x:
		final_pos.x = (left + right) * 0.5
	else:
		final_pos.x = clamp(desired.x, left + half_view.x, right - half_view.x)

	if _world_bounds.size.y <= 2.0 * half_view.y:
		final_pos.y = (top + bottom) * 0.5
	else:
		final_pos.y = clamp(desired.y, top + half_view.y, bottom - half_view.y)

	global_position = final_pos
	queue_redraw()

func _draw() -> void:
	if not debug_draw_bounds or not _bounds_ready:
		return

	var tl_local: Vector2 = to_local(_world_bounds.position)
	var br_local: Vector2 = to_local(_world_bounds.position + _world_bounds.size)
	var rect_local := Rect2(tl_local, br_local - tl_local)
	rect_local.position -= global_position

	var c := Color(0.2, 0.8, 1.0, 0.6)
	draw_rect(rect_local, c, false, 2.0)

	var vp := get_viewport().get_visible_rect().size
	var hv := vp * 0.5
	draw_rect(Rect2(-hv, vp), Color(1, 1, 1, 0.15), false, 1.0)
