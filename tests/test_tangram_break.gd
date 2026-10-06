extends SceneTree
## 替身符 breaking: unseen tangram cuts show as light, then the card falls apart along them into its seven pieces.
## Run: --headless --path . --script tests/test_tangram_break.gd

const Tangram = preload("res://scripts/presentation/CardStageTangram.gd")
const Seams = preload("res://scripts/presentation/CardStageTangramSeams.gd")
const Burst = preload("res://scripts/presentation/CardStageTangramBurst.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	# the pieces: seven of them, tiling the square exactly, with the tangram's mix of shapes
	_expect(Tangram.PIECES.size() == 7, "seven pieces")
	_expect(is_equal_approx(Tangram.total_area(), 16.0), "the pieces tile the 4 x 4 square exactly (area %f)" % Tangram.total_area())
	var triangles: int = 0
	var quads: int = 0
	for piece: Array in Tangram.PIECES:
		if piece.size() == 3:
			triangles += 1
		elif piece.size() == 4:
			quads += 1
	_expect(triangles == 5 and quads == 2, "five triangles and two four-sided pieces (the square and the parallelogram)")
	_expect(Tangram.CUTS.size() == 6, "six straight cuts")
	var rect := Rect2(10, 10, 280, 470)
	var cuts: Array = Tangram.cuts_in(rect)
	for cut: Array in cuts:
		for point: Vector2 in cut:
			_expect(rect.grow(0.01).has_point(point), "every cut stays on the card")
	# the seams: nothing without light, cuts open one after another
	var seams: Node3D = Seams.new()
	root.add_child(seams)
	seams.setup(Vector2(1.5, 2.25))
	_expect(seams.get_child_count() == 6, "one beam per cut")
	_expect(seams.get_child(0).get_child_count() == 4, "a beam is three light quads and a bead")
	var material: Material = (seams.get_child(0).get_child(0) as MeshInstance3D).material_override
	_expect(material is StandardMaterial3D and (material as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD and (material as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "the light is additive and unshaded, like the meteor light")
	seams.progress = 0.3
	_expect(seams.cut_progress(0) > seams.cut_progress(3) and seams.cut_progress(5) == 0.0, "cuts open one after another")
	seams.progress = 1.0
	_expect(seams.cut_progress(5) == 1.0, "all cuts are open at the end")
	seams.queue_free()
	# the burst: one 3D piece per tangram piece
	var card := Node3D.new()
	root.add_child(card)
	var burst: Node3D = Burst.new()
	root.add_child(burst)
	var palette: Array[Color] = [Color(0.9, 0.8, 0.66, 0.9), Color(0.05, 0.04, 0.04, 0.9)]
	burst.setup_tangram(card, Vector2(1.5, 2.25), -2.0, palette)
	_expect(burst.piece_count() == 7, "seven pieces fly apart (%d)" % burst.piece_count())
	for frame: int in range(20):
		await process_frame
	var moved: int = 0
	for child: Node in burst.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).global_position.length() > 0.05:
			moved += 1
	_expect(moved == 7, "they all leave their place")
	burst.queue_free()
	card.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: tangram break")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)
