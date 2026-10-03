extends Node3D
## PunchHitFX: the controller that fires the punch-impact pieces in order, at the contact point:
##   core flash -> (a hair later) shock ring + white sparks -> a few ink drops.
## It only draws; hit-stop and the cards' recoil are handled by the stage that calls it.
## All the knobs below can be tuned by hand. `heavy_preset` and `light_preset` are the two presets.

const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")
const Ring = preload("res://scripts/presentation/punch_fx/PunchShockRing.gd")
const Spark = preload("res://scripts/presentation/punch_fx/PunchWhiteSpark.gd")
const Debris = preload("res://scripts/presentation/punch_fx/PunchInkDebris.gd")
const Mark = preload("res://scripts/presentation/punch_fx/PunchInkMark.gd")
const Warp = preload("res://scripts/presentation/punch_fx/SpaceWarpFX.gd")

# --- Tunable parameters (`size` is the stage's hit scale; the rest scale with it) ----------------
var impact_scale: float = 1.0       # the core flash
var ring_scale: float = 1.0         # the shock ring
var spark_count: int = 14           # white spark streaks
var ink_amount: int = 4             # ink drops
var mark_scale: float = 1.0         # the black ink mark left on the spot (0 = none)
var mark_life: float = 0.9          # seconds the mark takes to fade away (long after the white light is gone)
var hit_stop_time: float = 0.07     # real seconds the game stands almost still on contact (read by the stage)
var recoil_distance: float = 0.55   # how far the struck card is knocked back, world units (read by the stage)
var flash_intensity: float = 3.4    # how far above white the core glows
var size: float = 1.8
var direction: float = 1.0          # +1: the fist came from the left, -1: from the right (for the afterimages)
var critical: bool = false          # a critical hit: the white light trembles at the end and the space warps harder
var warp_strength: float = 0.010    # the mirage ripple of the space around the hit (0 = none)


## The heavy blow: bigger core, a full ring, more sparks.
static func heavy_preset(size_value: float = 1.8) -> Dictionary:
	return {"impact_scale": 1.0, "ring_scale": 2.7, "spark_count": 16, "ink_amount": 5, "mark_scale": 3.4, "mark_life": 1.3, "hit_stop_time": 0.075, "recoil_distance": 0.6, "flash_intensity": 3.6, "size": size_value}


## The light blow (a quick jab): smaller core, a short ring, few sparks; a faster beat.
static func light_preset(size_value: float = 1.8) -> Dictionary:
	return {"impact_scale": 0.6, "ring_scale": 1.15, "spark_count": 7, "ink_amount": 2, "mark_scale": 1.9, "mark_life": 0.8, "hit_stop_time": 0.03, "recoil_distance": 0.3, "flash_intensity": 2.8, "size": size_value}


## Plays one hit at `centre` (world position). `params` overrides any of the knobs above.
static func play_at(host: Node, centre: Vector3, params: Dictionary) -> Node3D:
	var fx := new()
	host.add_child(fx)
	fx.position = centre
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.play()
	return fx


func play() -> void:
	var core := Core.new()
	core.impact_scale = impact_scale * size * 0.55
	core.flash_intensity = flash_intensity
	core.travel_dir = direction
	core.tremble = critical
	add_child(core)
	core.play()
	if warp_strength > 0.0:
		Warp.play_at(self, Vector3(0.0, 0.0, 0.4), size * (3.0 if critical else 2.4), warp_strength * (2.2 if critical else 1.0), 0.45 if critical else 0.36)
	if mark_scale > 0.0:
		var mark := Mark.new()
		mark.mark_scale = mark_scale * size
		mark.life = mark_life
		add_child(mark)
		mark.play()
	# The ring and the sparks burst out in the very next instant.
	get_tree().create_timer(0.025, true, false, true).timeout.connect(_burst)
	get_tree().create_timer(maxf(1.2, mark_life + 0.3)).timeout.connect(queue_free)


func _burst() -> void:
	var ring := Ring.new()
	ring.ring_scale = ring_scale * size * 0.85
	ring.life = 0.3 + 0.05 * ring_scale
	add_child(ring)
	ring.play()
	var spark := Spark.new()
	spark.spark_count = spark_count
	spark.spark_size = size
	add_child(spark)
	spark.play()
	if ink_amount > 0:
		var debris := Debris.new()
		debris.ink_amount = ink_amount
		debris.debris_size = size
		add_child(debris)
		debris.play()
