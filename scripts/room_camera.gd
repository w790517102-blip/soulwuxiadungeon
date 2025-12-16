extends Camera2D

@onready var area := get_parent() as Area2D
@onready var shape := area.get_node("CollisionShape2D").shape as RectangleShape2D

func _ready():
	# 計算限制區域的絕對位置
	var rect_position: Vector2 = area.global_position - shape.extents
	var rect_size: Vector2 = shape.extents * 2.0

	# 設定 Camera2D 的限制範圍
	limit_left = int(rect_position.x)
	limit_top = int(rect_position.y)
	limit_right = int(rect_position.x + rect_size.x)
	limit_bottom = int(rect_position.y + rect_size.y)

	# 啟用鏡頭跟隨
	make_current()

	# Debug 輸出
	print("[鏡頭] 限制已啟用：")
	print("  Left:", limit_left)
	print("  Right:", limit_right)
	print("  Top:", limit_top)
	print("  Bottom:", limit_bottom)
	print("  Camera position:", global_position)
