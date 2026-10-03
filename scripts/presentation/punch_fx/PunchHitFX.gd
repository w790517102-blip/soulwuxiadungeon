extends Node3D
## PunchHitFX: the controller that fires the punch-impact pieces in order, at the contact point:
##   core flash -> (a hair later) shock ring + white sparks -> a few ink drops.
## It only draws; hit-stop and the cards' recoil are handled by the stage that calls it.
## All the knobs below can be tuned by hand. `heavy_preset` and `light_preset` are the two presets.

const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")
const Ring = preload("res://scripts/presentation/punch_fx/PunchShockRing.gd")
const Spark = preload("res://scripts/presentation/punch_fx/PunchWhiteSpark.gd")
const Debris = preload("res://scripts/presentation/punch_fx/PunchInkDebris.gd")

# --- Tunable parameters (`size` is the stage's hit scale; the rest scale with it) ----------------
var impact_scale: float = 1.0       # the core flash
var ring_scale: float = 1.0         # the shock waves (overall size)
var ring_count: int = 3             # how many waves, each on its own plane with its own speed and reach
var ring_life: float = 0.4          # seconds until every wave has vanished (they all vanish together)
var spark_count: int = 14           # white spark streaks
var ink_amount: int = 4             # ink drops
var hit_stop_time: float = 0.07     # real seconds the game stands almost still on contact (read by the stage)
var recoil_distance: float = 0.55   # how far the struck card is knocked back, world units (read by the stage)
var flash_intensity: float = 3.4    # how far above white the core glows
var size: float = 1.8

var _rings: Array[Node3D] = []
var _ring_clock: float = -1.0


## The heavy blow: bigger core, a full ring, more sparks.
static func heavy_preset(size_value: float = 1.8) -> Dictionary:
	return {"impact_scale": 1.0, "ring_scale": 3.0, "ring_count": 3, "spark_count": 16, "ink_amount": 5, "hit_stop_time": 0.075, "recoil_distance": 0.6, "flash_intensity": 3.6, "size": size_value}


## The light blow (a quick jab): smaller core, a short ring, few sparks; a faster beat.
static func light_preset(size_value: float = 1.8) -> Dictionary:
	return {"impact_scale": 0.6, "ring_scale": 1.5, "ring_count": 2, "spark_count": 7, "ink_amount": 2, "hit_stop_time": 0.03, "recoil_distance": 0.3, "flash_intensity": 2.8, "size": size_value}


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
	add_child(core)
	core.play()
	# The ring and the sparks burst out in the very next instant.
	get_tree().create_timer(0.025, true, false, true).timeout.connect(_burst)
	get_tree().create_timer(1.2).timeout.connect(queue_free)


func _burst() -> void:
	_rings.clear()
	for index: int in range(maxi(ring_count, 1)):
		var ring := Ring.new()
		ring.ring_scale = ring_scale * size * 0.85
		# Each wave: its own plane (tilted about x and y), its own reach and its own speed.
		ring.plane = Vector3(randf_range(-1.0, 1.0) * (0.0 if index == 0 else 0.95), randf_range(-1.0, 1.0) * (0.0 if index == 0 else 0.95), randf() * TAU)
		ring.max_radius = randf_range(0.55, 0.98) if index > 0 else 0.9
		ring.speed = randf_range(1.8, 4.2)
		ring.centre_dim = 0.55 if index == 0 else 0.0
		add_child(ring)
		_rings.append(ring)
	_ring_clock = 0.0
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


func _process(delta: float) -> void:
	# One clock for every wave, so they all vanish at the same moment.
	if _ring_clock < 0.0:
		return
	_ring_clock += delta / maxf(ring_life, 0.05)
	var t: float = clampf(_ring_clock, 0.0, 1.0)
	for ring: Node3D in _rings:
		if is_instance_valid(ring):
			ring.set_clock(t)
	if _ring_clock >= 1.0:
		for ring: Node3D in _rings:
			if is_instance_valid(ring):
				ring.queue_free()
		_rings.clear()
		_ring_clock = -1.0
