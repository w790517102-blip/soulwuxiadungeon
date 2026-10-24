extends Node
## 水墨大圖（物品詳情的大圖）的白色柔邊：只亮「外圍」，圖內部的半透明縫隙不透白。
## 做法：後面墊兩張模糊圖——外擴光暈（亮）與內部填滿遮罩（較糊，縫隙會被填滿）；shader 只在遮罩低的地方（圖的外面）出光。
## 用法：InkGlow.attach(texture_rect)。換圖時光暈自動跟著換。

## 整圈外擴輪廓（老闆選定的「first」）：把原圖的透明度往外擴 OUTLINE_PX 個像素，邊緣漸淡，畫成白色墊在圖後面，圖的外圍就多一圈比實體大的白邊。
const OUTLINE_PX := 9
const OUTLINE_SHADER := "shader_type canvas_item;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = texture(TEXTURE, UV).a;
	for (int i = 0; i < 16; i++) {
		float ang = float(i) * 0.3926991;
		vec2 d = vec2(cos(ang), sin(ang));
		for (int j = 1; j <= 6; j++) {
			float r = float(j) * 1.5;
			float w = 1.0 - r / 10.5;
			a = max(a, texture(TEXTURE, UV + d * r * px).a * w);
		}
	}
	COLOR = vec4(1.0, 1.0, 1.0, clamp(a * 1.6, 0.0, 1.0) * 0.95);
}"

const SHADER := "shader_type canvas_item;
uniform sampler2D fill_mask : filter_linear;
uniform float boost = 3.2;
uniform float inner_lo = 0.22;
uniform float inner_hi = 0.5;
void fragment() {
	float halo = clamp(texture(TEXTURE, UV).a * boost, 0.0, 1.0);
	float fill = texture(fill_mask, UV).a;
	float outside = 1.0 - smoothstep(inner_lo, inner_hi, fill);
	COLOR = vec4(1.0, 1.0, 1.0, halo * outside);
}"

## 測試用：環境變數 INK_GLOW_MODE（off／first／outer），沒設就是 first（整圈柔光，老闆選定）
static var mode := "first"
static var _cache: Dictionary = {}
static var _shader: Shader
static var _outline_shader: Shader

var target: TextureRect
var glow: TextureRect
var _last_id := 0
var _pad := 0.22

static func attach(r: TextureRect) -> void:
	if r == null or r.get_parent() == null:
		return
	var g = load("res://scripts/inventory/InkGlow.gd").new()
	g.target = r
	r.get_parent().add_child(g)
	g.name = "InkGlowCtl"

func _ready() -> void:
	var env := OS.get_environment("INK_GLOW_MODE")
	if env != "":
		mode = env
	glow = TextureRect.new()
	glow.name = "InkGlow"
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var p := target.get_parent()
	p.add_child(glow)
	p.move_child(glow, target.get_index())

func _process(_dt: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var tex := target.texture
	var id := tex.get_instance_id() if tex != null else 0
	if id != _last_id:
		_last_id = id
		_apply(tex)
	if mode == "first" and tex != null and glow.texture != null:
		# 補了透明邊的圖，依原圖在框內的實際縮放比例畫，輪廓才會剛好貼著實體外圍
		var src := tex.get_size()
		var s := Vector2(target.size.x / src.x, target.size.y / src.y)
		if target.stretch_mode != TextureRect.STRETCH_SCALE:
			s = Vector2.ONE * minf(s.x, s.y)
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.size = glow.texture.get_size() * s
		glow.position = target.position + (target.size - glow.size) / 2.0
	else:
		var ratio := 1.0 + 2.0 * _pad
		glow.size = target.size * ratio
		glow.position = target.position - target.size * _pad
	glow.visible = target.visible and glow.texture != null and mode != "off"
	glow.z_index = target.z_index
	glow.modulate.a = target.modulate.a

func _apply(tex: Texture2D) -> void:
	if tex == null:
		glow.texture = null
		return
	if mode == "first":
		glow.texture = _padded(tex)
		if _outline_shader == null:
			_outline_shader = Shader.new()
			_outline_shader.code = OUTLINE_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = _outline_shader
		glow.material = sm
		return
	_pad = 0.22
	glow.texture = _blur(tex, 0.22, 9)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("fill_mask", _blur(tex, 0.22, 22))
	glow.material = mat

static func _blur(tex: Texture2D, pad_frac: float, div: int) -> Texture2D:
	var key := "%d_%d_%d" % [tex.get_instance_id(), int(pad_frac * 100), div]
	if _cache.has(key):
		return _cache[key]
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var pad := int(maxf(w, h) * pad_frac)
	var big := Image.create(w + 2 * pad, h + 2 * pad, false, Image.FORMAT_RGBA8)
	big.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(pad, pad))
	big.resize(maxi(4, big.get_width() / div), maxi(4, big.get_height() / div), Image.INTERPOLATE_BILINEAR)
	big.resize(w + 2 * pad, h + 2 * pad, Image.INTERPOLATE_BILINEAR)
	var out := ImageTexture.create_from_image(big)
	_cache[key] = out
	return out


## 原圖四周補上透明邊（讓外擴的輪廓有地方畫）。
static func _padded(tex: Texture2D) -> Texture2D:
	var key := "pad_%d" % tex.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var big := Image.create(w + 2 * OUTLINE_PX, h + 2 * OUTLINE_PX, false, Image.FORMAT_RGBA8)
	big.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(OUTLINE_PX, OUTLINE_PX))
	var out := ImageTexture.create_from_image(big)
	_cache[key] = out
	return out
