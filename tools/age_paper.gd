extends SceneTree
# 宣紙泛黃＋水墨渲染的後製：把太白、太平的紙面做出層次（泛黃、邊緣燒焦、污漬、纖維、淡墨暈）。
# 只動「淺色的紙面」（亮度高的像素），深色的皮革底、墨線、軸桿、金邊都不動；透明度不變。
# 原圖放在 docs/system_menu/equipment_originals/，輸出寫回 assets/UI/equipment/（可重跑、可調參數）。
# 用法：AGE_IN=原圖 AGE_OUT=輸出 AGE_MODE=scroll|tile godot --headless --path . --script tools/age_paper.gd
#   AGE_MODE=scroll：整張大卷軸（2304×1297），只對左頁、右頁兩塊紙面做邊緣燒焦；tile：整張圖都算紙面（裝備格、卡片）。
#   強度可用 AGE_YELLOW、AGE_BURN、AGE_STAIN、AGE_GRAIN 覆蓋（0~1.5，預設 1）。

const PAGES := [Rect2(639, 176, 887, 962), Rect2(1553, 176, 652, 962)]   # 卷軸上的兩頁紙面（2× 像素，V2 placement.json）

var _low := FastNoiseLite.new()
var _mid := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _cloud := FastNoiseLite.new()

func _env_f(name: String, fallback: float) -> float:
	var v := OS.get_environment(name)
	return float(v) if v != "" else fallback

func _init() -> void:
	var src := OS.get_environment("AGE_IN")
	var dst := OS.get_environment("AGE_OUT")
	var mode := OS.get_environment("AGE_MODE")
	var k_yellow := _env_f("AGE_YELLOW", 1.0)
	var k_burn := _env_f("AGE_BURN", 1.0)
	var k_stain := _env_f("AGE_STAIN", 1.0)
	var k_grain := _env_f("AGE_GRAIN", 1.0)
	var img := Image.load_from_file(src)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for n: FastNoiseLite in [_low, _mid, _fine, _cloud]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
	_low.seed = 7;   _low.frequency = 0.0035; _low.fractal_octaves = 3
	_mid.seed = 19;  _mid.frequency = 0.012;  _mid.fractal_octaves = 4
	_fine.seed = 31; _fine.frequency = 0.45;  _fine.fractal_octaves = 2
	_cloud.seed = 43; _cloud.frequency = 0.0022; _cloud.fractal_octaves = 2
	var rects: Array = PAGES if mode == "scroll" else [Rect2(0, 0, w, h)]
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.02:
				continue
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var paper := smoothstep(0.55, 0.80, lum)
			if paper <= 0.0:
				continue
			# 1) 泛黃：往暖黃褐色乘上去（亮處也不再是純白）
			var tint := Color(1.0, 1.0, 1.0).lerp(Color(0.93, 0.80, 0.56), clampf(0.55 * k_yellow, 0.0, 1.0))
			var out := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
			# 2) 大片污漬與水墨暈：低頻雲（偏灰褐）＋中頻斑塊（偏黃褐），強度不一
			var low := (_low.get_noise_2d(x, y) + 1.0) * 0.5
			var mid := (_mid.get_noise_2d(x, y) + 1.0) * 0.5
			var cloud := (_cloud.get_noise_2d(x, y) + 1.0) * 0.5
			var stain := clampf((low - 0.42) * 1.6, 0.0, 1.0) * 0.30 + clampf((mid - 0.55) * 2.2, 0.0, 1.0) * 0.22
			var wash := clampf((cloud - 0.55) * 2.6, 0.0, 1.0) * 0.20
			out = out.lerp(Color(0.46, 0.34, 0.20, c.a), clampf(stain * k_stain, 0.0, 0.7))
			out = out.lerp(Color(0.38, 0.38, 0.36, c.a), clampf(wash * k_stain, 0.0, 0.5))
			# 3) 邊緣燒焦：離紙面邊越近越暗、越褐（每塊紙各自算）
			var burn := 0.0
			for r: Rect2 in rects:
				if r.has_point(Vector2(x, y)):
					var d := minf(minf(x - r.position.x, r.end.x - x), minf(y - r.position.y, r.end.y - y))
					var reach := minf(r.size.x, r.size.y) * 0.11
					var t := 1.0 - clampf(d / reach, 0.0, 1.0)
					# 邊緣不整齊：用中頻噪點把燒焦範圍扯成不規則
					t = clampf(t * (0.65 + 0.7 * mid), 0.0, 1.0)
					burn = maxf(burn, t * t)
			out = out.lerp(Color(0.30, 0.20, 0.10, c.a), clampf(burn * 0.55 * k_burn, 0.0, 0.8))
			# 4) 纖維顆粒：高頻細微明暗
			var grain := _fine.get_noise_2d(x, y) * 0.07 * k_grain
			out = Color(clampf(out.r * (1.0 + grain), 0.0, 1.0), clampf(out.g * (1.0 + grain), 0.0, 1.0), clampf(out.b * (1.0 + grain), 0.0, 1.0), c.a)
			# 只改紙面：依亮度權重混回原色（墨線、深色處不動）
			img.set_pixel(x, y, c.lerp(out, paper))
	img.save_png(dst)
	print("AGED ", src, " -> ", dst)
	quit()
