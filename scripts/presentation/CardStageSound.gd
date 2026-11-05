extends RefCounted
## Presentation cues use an independent voice so footsteps/voices do not cut off hit sounds.

static func play(parent: Node, key: String, gain_db: float = 0.0) -> float:
	var stream: AudioStream = load("res://assets/sound/%s.ogg" % key) as AudioStream
	if stream == null:
		return 0.0
	var player := AudioStreamPlayer.new()
	var scene: Node = parent.get_tree().current_scene
	var primary: Node = scene.find_child("SEPlayer", true, false) if scene != null else null
	player.volume_db = -5.302
	if primary is AudioStreamPlayer:
		player.bus = primary.bus
		player.volume_db = primary.volume_db
	player.volume_db += gain_db
	parent.add_child(player)
	player.stream = stream
	player.finished.connect(player.queue_free)
	player.play()
	return stream.get_length()
