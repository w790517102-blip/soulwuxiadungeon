extends Node
## 水墨大圖（物品詳情的大圖）的白色柔邊：只亮「外圍」，圖內部的半透明縫隙不透白。
## 做法：後面墊兩張模糊圖——外擴光暈（亮）與內部填滿遮罩（較糊，縫隙會被填滿）；shader 只在遮罩低的地方（圖的外面）出光。
## 用法：InkGlow.attach(texture_rect)。換圖時光暈自動跟著換。

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
## 光暈整體往下平移的像素（投影的感覺）
const SHADOW_DROP := 3.0
## 先把實體的範圍往外擴這麼多（原圖縮成 1/4 之後的像素），再用原本的方式糊開
const DILATE_PX := 3

static var mode := "first"
static var _cache: Dictionary = {}
static var _shader: Shader

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
	var ratio := 1.0 + 2.0 * _pad
	glow.size = target.size * ratio
	glow.position = target.position - target.size * _pad
	if mode == "first" and tex != null and glow.texture != null:
		# 光暈圖四周補了透明邊：依原圖在框內的實際縮放比例畫（框可能是拉伸或等比），再整體往下平移一點當投影
		var src := tex.get_size()
		var s := Vector2(target.size.x / src.x, target.size.y / src.y)
		if target.stretch_mode != TextureRect.STRETCH_SCALE:
			s = Vector2.ONE * minf(s.x, s.y)
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.size = glow.texture.get_size() * s
		glow.position = target.position + (target.size - glow.size) / 2.0 + Vector2(0, SHADOW_DROP)
	glow.visible = target.visible and glow.texture != null and mode != "off"
	glow.z_index = target.z_index
	glow.modulate.a = target.modulate.a

func _apply(tex: Texture2D) -> void:
	if tex == null:
		glow.texture = null
		return
	if mode == "first":
		_pad = 0.16
		glow.texture = _halo(tex, 0.16, 7)
		var m := CanvasItemMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(1.0, 1.0, 1.0, clamp(texture(TEXTURE, UV).a * 1.7, 0.0, 1.0) * 0.95); }"
		var sm := ShaderMaterial.new()
		sm.shader = sh
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


## 先把不透明的範圍往外擴（圓形），再用 _blur 一樣的降解析度糊法暈開：光暈比實體大，邊緣仍保留水墨不規則暈開的感覺。
static func _halo(tex: Texture2D, pad_frac: float, div: int) -> Texture2D:
	var key := "halo_%d_%d_%d" % [tex.get_instance_id(), int(pad_frac * 100), div]
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
	var bw := big.get_width()
	var bh := big.get_height()
	var sw := maxi(4, bw / 4)
	var sh := maxi(4, bh / 4)
	var small := big.duplicate() as Image
	small.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	var data := small.get_data()
	var alpha := PackedByteArray()
	alpha.resize(sw * sh)
	for i in sw * sh:
		alpha[i] = data[i * 4 + 3]
	var offsets: Array[Vector2i] = []
	for dy in range(-DILATE_PX, DILATE_PX + 1):
		for dx in range(-DILATE_PX, DILATE_PX + 1):
			if dx * dx + dy * dy <= DILATE_PX * DILATE_PX:
				offsets.append(Vector2i(dx, dy))
	var grown := PackedByteArray()
	grown.resize(sw * sh)
	for y in sh:
		for x in sw:
			var m := 0
			for o in offsets:
				var nx := x + o.x
				var ny := y + o.y
				if nx >= 0 and ny >= 0 and nx < sw and ny < sh:
					var v: int = alpha[ny * sw + nx]
					if v > m:
						m = v
			grown[y * sw + x] = m
	var out_data := PackedByteArray()
	out_data.resize(sw * sh * 4)
	for i in sw * sh:
		out_data[i * 4] = 255
		out_data[i * 4 + 1] = 255
		out_data[i * 4 + 2] = 255
		out_data[i * 4 + 3] = grown[i]
	var grown_img := Image.create_from_data(sw, sh, false, Image.FORMAT_RGBA8, out_data)
	grown_img.resize(maxi(4, bw / div), maxi(4, bh / div), Image.INTERPOLATE_BILINEAR)
	grown_img.resize(bw, bh, Image.INTERPOLATE_BILINEAR)
	var out := ImageTexture.create_from_image(grown_img)
	_cache[key] = out
	return out
