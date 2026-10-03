extends Node
## 左飲「燕行破風斬」 as a full-screen animation video. On the left-drinker's turn the camera
## zooms into his portrait (the same picture the video starts on) until it fills the centre of
## the screen, the video plays from that frame, freezes on its last frame, the screen washes to
## white, and fades back to the battle. Presentation only: it never touches combat state.

const DEFAULT_VIDEO_PATH := "res://assets/presentation/video/yan_xing_po_feng_zhan.ogv"
const DEFAULT_VIDEO_SECONDS := 6.58
const ZOOM_SECONDS := 0.65
const FREEZE_BEFORE_END := 0.05
const WHITE_SECONDS := 0.9
const RETURN_SECONDS := 0.8

## The animation to play and how long it runs (the defaults are 燕行破風斬).
var video_path: String = DEFAULT_VIDEO_PATH
var video_seconds: float = DEFAULT_VIDEO_SECONDS
var _finished: bool = false


## `start_rect`: where the portrait picture is on screen right now (the card's art); `art`: the
## portrait picture the video begins with.
func play(host: Node, start_rect: Rect2, art: Texture2D, on_white: Callable = Callable()) -> void:
	var viewport_size: Vector2 = host.get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 90
	host.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.size = viewport_size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var side: float = minf(viewport_size.x, viewport_size.y)
	var end_rect := Rect2((viewport_size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var picture := TextureRect.new()
	picture.texture = art
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = start_rect.position
	picture.size = start_rect.size
	picture.modulate.a = 0.0
	layer.add_child(picture)

	# 1. Zoom in: the portrait grows to the middle of the screen while the stage goes dark.
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(dim, "color:a", 1.0, ZOOM_SECONDS * 0.8)
	zoom.tween_property(picture, "modulate:a", 1.0, ZOOM_SECONDS * 0.25)
	zoom.tween_property(picture, "position", end_rect.position, ZOOM_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(picture, "size", end_rect.size, ZOOM_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await zoom.finished

	# 2. The animation, from its first frame (the portrait itself, so the join is seamless).
	var stream: VideoStream = load(video_path) as VideoStream
	var video: VideoStreamPlayer = null
	if stream != null:
		video = VideoStreamPlayer.new()
		video.stream = stream
		# The animation plays silently (no music of its own).
		video.volume_db = -80.0
		video.expand = true
		video.position = end_rect.position
		video.size = end_rect.size
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		video.finished.connect(func() -> void: _finished = true)
		layer.add_child(video)
		video.play()
		var guard: int = 0
		while guard < 90 and video.stream_position < 0.04 and not _finished:
			await get_tree().process_frame
			guard += 1
		picture.hide()
		# 3. Freeze on the last frame.
		var watchdog: int = 0
		while not _finished and video.stream_position < video_seconds - FREEZE_BEFORE_END and watchdog < 60 * 12:
			await get_tree().process_frame
			watchdog += 1
		if not _finished:
			video.paused = true
	else:
		push_warning("燕行破風斬 video is missing: %s" % video_path)
		await get_tree().create_timer(0.4).timeout

	# 4. The screen washes to white, then fades back to the battle.
	var white := ColorRect.new()
	white.color = Color(1.0, 1.0, 1.0, 0.0)
	white.size = viewport_size
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(white)
	var wash := create_tween()
	wash.tween_property(white, "color:a", 1.0, WHITE_SECONDS).set_trans(Tween.TRANS_SINE)
	await wash.finished
	# Under the full white the battle is put back in order.
	if on_white.is_valid():
		on_white.call()
	if video != null:
		video.stop()
		video.queue_free()
	picture.queue_free()
	dim.queue_free()
	var back := create_tween()
	back.tween_property(white, "color:a", 0.0, RETURN_SECONDS).set_trans(Tween.TRANS_SINE)
	await back.finished
	layer.queue_free()
