extends Control
## The little tail of an OS speech box (like a comic balloon): a triangle from the box edge to
## the middle of the speaker's portrait. Drawn in the box's own style. Presentation only.

const FILL := Color(0.025, 0.037, 0.05, 0.94)
const BORDER := Color("96784d")
const BASE_HALF_HEIGHT: float = 11.0

var box_rect: Rect2 = Rect2()       ## the box, in global (screen) coordinates
var target: Vector2 = Vector2.ZERO  ## where the tail points, in global coordinates
var points_left: bool = true        ## true: the tail leaves the box's left edge


func _init() -> void:
	name = "Tail"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1


func aim(rect: Rect2, point: Vector2, left_side: bool) -> void:
	box_rect = rect
	target = point
	points_left = left_side
	queue_redraw()


## The tail polygon in global coordinates: base on the box edge (kept inside the box's height,
## following the target so a speaker standing higher or lower gets a tilted tail), tip at the target.
func polygon_global() -> PackedVector2Array:
	var edge_x: float = box_rect.position.x if points_left else box_rect.end.x
	var margin: float = BASE_HALF_HEIGHT + 4.0
	var base_y: float = clampf(target.y, box_rect.position.y + margin, box_rect.end.y - margin)
	return PackedVector2Array([
		Vector2(edge_x, base_y - BASE_HALF_HEIGHT),
		target,
		Vector2(edge_x, base_y + BASE_HALF_HEIGHT),
	])


func _draw() -> void:
	if box_rect.size == Vector2.ZERO:
		return
	var origin: Vector2 = global_position
	var global_points: PackedVector2Array = polygon_global()
	var local_points := PackedVector2Array()
	for point: Vector2 in global_points:
		local_points.append(point - origin)
	draw_colored_polygon(local_points, FILL)
	draw_polyline(PackedVector2Array([local_points[0], local_points[1], local_points[2]]), BORDER, 1.5, true)
	# Open the box border where the tail joins it.
	var edge: float = local_points[0].x + (1.0 if points_left else -1.0)
	draw_line(Vector2(edge, local_points[0].y + 1.0), Vector2(edge, local_points[2].y - 1.0), FILL, 3.0)
