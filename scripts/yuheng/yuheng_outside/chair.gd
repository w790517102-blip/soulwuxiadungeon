extends Sprite2D

@export var z_index_offset := 0
@export var sort_from_texture_bottom := false

func _process(_delta):
	var sort_position := global_position
	if sort_from_texture_bottom and texture:
		# Sprite2D 預設以圖片中心定位；俯視場景的遮擋線應落在家具接地的底緣。
		sort_position = to_global(Vector2(0.0, texture.get_height() * 0.5))
	z_index = int(sort_position.y + z_index_offset)
