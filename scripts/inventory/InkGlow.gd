extends Node
## 水墨圖示的白色柔邊：在圖示後面墊一張「同形狀、白色、模糊放大」的光暈，圖示深色的筆觸不被紙紋與山水吃掉。
## 用法：InkGlow.attach(texture_rect)。圖示換圖時光暈自動跟著換（每格每幀只比對一次貼圖）。

const PAD := 0.16        # 光暈外擴（占圖示長邊的比例）
const BLUR_DIV := 7      # 模糊程度：縮小成幾分之一再放大
const SHADER := "shader_type canvas_item;
uniform float strength = 0.95;
void fragment() { COLOR = vec4(1.0, 1.0, 1.0, clamp(texture(TEXTURE, UV).a * 1.7, 0.0, 1.0) * strength); }"

static var _cache: Dictionary = {}
static var _mat: ShaderMaterial

var target: TextureRect
var glow: TextureRect
var _last_id := 0

static func attach(r: TextureRect) -> void:
	if r == null or r.get_parent() == null:
		return
	var g = load("res://scripts/inventory/InkGlow.gd").new()
	g.target = r
	r.get_parent().add_child(g)
	g.name = "InkGlowCtl"

func _ready() -> void:
	glow = TextureRect.new()
	glow.name = "InkGlow"
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	glow.material = _mat
	var p := target.get_parent()
	p.add_child(glow)
	p.move_child(glow, target.get_index())
	set_process(true)

func _process(_dt: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var tex := target.texture
	var id := tex.get_instance_id() if tex != null else 0
	if id != _last_id:
		_last_id = id
		glow.texture = _glow_for(tex) if tex != null else null
	var ratio := 1.0 + 2.0 * PAD
	glow.size = target.size * ratio
	glow.position = target.position - target.size * PAD
	glow.visible = target.visible and glow.texture != null
	glow.z_index = target.z_index
	glow.modulate.a = target.modulate.a

static func _glow_for(tex: Texture2D) -> Texture2D:
	var key := tex.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var pad := int(maxf(w, h) * PAD)
	var big := Image.create(w + 2 * pad, h + 2 * pad, false, Image.FORMAT_RGBA8)
	big.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(pad, pad))
	var sw := maxi(4, big.get_width() / BLUR_DIV)
	var sh := maxi(4, big.get_height() / BLUR_DIV)
	big.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	big.resize(w + 2 * pad, h + 2 * pad, Image.INTERPOLATE_BILINEAR)
	var out := ImageTexture.create_from_image(big)
	_cache[key] = out
	return out
