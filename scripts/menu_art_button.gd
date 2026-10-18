extends TextureButton
# 主選單用的立繪按鈕：平時暗沉；滑鼠移入／鍵盤聚焦時變亮並疊上發光版。
# 發光圖比本體略寬（光暈外擴），疊圖以按鈕為中心依寬度等比放大。

const DIM_COLOR := Color(0.55, 0.55, 0.55, 1.0)

@export var glow_texture: Texture2D
@export var placeholder := false   # 尚未開放的項目：外觀照舊，按下去只提示

var _glow: TextureRect
var _hover := false

func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modulate = DIM_COLOR
	_glow = TextureRect.new()
	_glow.texture = glow_texture
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate.a = 0.0
	_glow.z_index = 1
	add_child(_glow)
	resized.connect(_layout_glow)
	_layout_glow()
	mouse_entered.connect(func(): _hover = true; _refresh())
	mouse_exited.connect(func(): _hover = false; _refresh())
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	# 滑鼠點過就放掉焦點，免得按完之後一直亮著（鍵盤選取仍會亮）
	pressed.connect(release_focus)

func _layout_glow() -> void:
	if _glow == null or glow_texture == null:
		return
	var gw := size.x * (float(glow_texture.get_width()) / 1000.0)
	var gh := gw * float(glow_texture.get_height()) / float(glow_texture.get_width())
	_glow.size = Vector2(gw, gh)
	_glow.position = (size - _glow.size) * 0.5

func _refresh() -> void:
	var lit := _hover or has_focus()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate", Color.WHITE if lit else DIM_COLOR, 0.12)
	tw.tween_property(_glow, "modulate:a", 1.0 if lit else 0.0, 0.12)
