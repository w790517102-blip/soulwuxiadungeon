extends RefCounted
## The seven-piece tangram cut of a card (替身符 breaking): two large triangles, one medium triangle, two small
## triangles, one square and one parallelogram, laid out on a 4 x 4 unit square (x right, y DOWN, like card art) and
## stretched over the card. The same data gives the pieces that fly apart and the cut lines the light shines through.
## Presentation only.

const UNIT := 4.0

## Counter-clockwise-free simple polygons; every piece is convex.
const PIECES: Array = [
	[Vector2(0, 0), Vector2(4, 0), Vector2(2, 2)],                       # large triangle (top)
	[Vector2(0, 0), Vector2(0, 4), Vector2(2, 2)],                       # large triangle (left)
	[Vector2(4, 2), Vector2(4, 4), Vector2(2, 4)],                       # medium triangle
	[Vector2(4, 0), Vector2(3, 1), Vector2(4, 2)],                       # small triangle (right)
	[Vector2(2, 2), Vector2(3, 1), Vector2(4, 2), Vector2(3, 3)],        # square
	[Vector2(2, 2), Vector2(3, 3), Vector2(1, 3)],                       # small triangle (middle)
	[Vector2(0, 4), Vector2(2, 4), Vector2(3, 3), Vector2(1, 3)],        # parallelogram
]

## The straight cuts between the pieces: [from, to] in unit coordinates.
const CUTS: Array = [
	[Vector2(0, 0), Vector2(2, 2)],
	[Vector2(4, 0), Vector2(0, 4)],
	[Vector2(4, 2), Vector2(2, 4)],
	[Vector2(3, 1), Vector2(4, 2)],
	[Vector2(2, 2), Vector2(3, 3)],
	[Vector2(3, 3), Vector2(1, 3)],
]


## A unit point on a rectangle (x right, y down).
static func to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return rect.position + Vector2(point.x / UNIT * rect.size.x, point.y / UNIT * rect.size.y)


## A unit point in the card's own plane (centre origin, x right, y UP) for a card of `card_size`.
static func to_card_plane(point: Vector2, card_size: Vector2) -> Vector2:
	return Vector2((point.x / UNIT - 0.5) * card_size.x, (0.5 - point.y / UNIT) * card_size.y)


static func cuts_in(rect: Rect2) -> Array:
	var out: Array = []
	for cut: Array in CUTS:
		out.append([to_rect(cut[0], rect), to_rect(cut[1], rect)])
	return out


static func pieces_in_card_plane(card_size: Vector2) -> Array:
	var out: Array = []
	for piece: Array in PIECES:
		var polygon: Array = []
		for point: Vector2 in piece:
			polygon.append(to_card_plane(point, card_size))
		out.append(polygon)
	return out


## Sum of the areas of the pieces in unit space (16 when they tile the square exactly).
static func total_area() -> float:
	var total: float = 0.0
	for piece: Array in PIECES:
		var area: float = 0.0
		for index: int in range(piece.size()):
			var a: Vector2 = piece[index]
			var b: Vector2 = piece[(index + 1) % piece.size()]
			area += a.x * b.y - b.x * a.y
		total += absf(area) * 0.5
	return total
