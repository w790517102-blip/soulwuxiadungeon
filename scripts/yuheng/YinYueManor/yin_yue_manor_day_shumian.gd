extends CharacterBody2D

# 飲月山莊白天的書眠：Su_mien.tscn 的 Area2D 訊號會呼叫根節點的這兩個函式（白箋居的 su_mien.gd 有，
# 這個場景沒有那份腳本）。互動（Space）由 yin_yue_manor_room(day).gd 統一處理，這裡只吃掉訊號。


func _on_area_2d_body_entered(_body: Node2D) -> void:
	pass


func _on_area_2d_body_exited(_body: Node2D) -> void:
	pass
