extends RefCounted
## Shared geometry for the substitute card's spatial slashes and the pieces they leave behind.
## Coordinates are centred on the card; the lines extend past its edges to cut the whole face.

const SLASHES: Array = [
	[Vector2(-0.51, -0.32), Vector2(0.51, 0.43)],
	[Vector2(-0.51, 0.42), Vector2(0.51, -0.36)],
	[Vector2(-0.20, -0.51), Vector2(0.27, 0.51)],
	[Vector2(-0.51, 0.02), Vector2(0.51, 0.17)],
	[Vector2(-0.51, -0.44), Vector2(0.51, 0.01)],
]


static func lines_on_card(card_size: Vector2) -> Array:
	var lines: Array = []
	for slash: Array in SLASHES:
		lines.append([
			Vector2(slash[0].x * card_size.x, slash[0].y * card_size.y),
			Vector2(slash[1].x * card_size.x, slash[1].y * card_size.y),
		])
	return lines


static func pieces_in_card_plane(card_size: Vector2) -> Array:
	var half: Vector2 = card_size * 0.5
	var pieces: Array = [[
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	]]
	for line: Array in lines_on_card(card_size):
		var next_pieces: Array = []
		for piece: Array in pieces:
			var left: Array = _clip_half_plane(piece, line[0], line[1], true)
			var right: Array = _clip_half_plane(piece, line[0], line[1], false)
			if left.size() >= 3 and right.size() >= 3:
				next_pieces.append(left)
				next_pieces.append(right)
			else:
				next_pieces.append(piece)
		pieces = next_pieces
	return pieces


static func _clip_half_plane(polygon: Array, a: Vector2, b: Vector2, keep_left: bool) -> Array:
	var result: Array = []
	var direction: Vector2 = b - a
	for index: int in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var following: Vector2 = polygon[(index + 1) % polygon.size()]
		var current_side: float = direction.cross(current - a)
		var next_side: float = direction.cross(following - a)
		var current_inside: bool = current_side >= -0.0001 if keep_left else current_side <= 0.0001
		var next_inside: bool = next_side >= -0.0001 if keep_left else next_side <= 0.0001
		if current_inside:
			result.append(current)
		if current_inside != next_inside:
			var fraction: float = current_side / (current_side - next_side)
			result.append(current.lerp(following, fraction))
	return result
