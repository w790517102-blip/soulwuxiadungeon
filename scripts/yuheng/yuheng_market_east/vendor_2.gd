extends Sprite2D

@export var z_index_offset := 0

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)
