extends SceneTree
# 裝備格外輪廓的「墨暈」：黑框往外渲染一圈，讓格子的邊有重量（不要細細的、或根本沒有）。
# 做法：只產生「框外」的暈（原框範圍內是全透明，不會把框裡面蓋暗），疊在底框下面。
# 輸入：assets/UI/equipment/slots/slot_frame_<部位>.png；輸出：同資料夾 slot_bleed_<部位>.png（四邊各多 16 像素，2× 像素）。
# 用法：godot --headless --path . --script tools/slot_ink_bleed.gd     （強度 BLEED_K、範圍 BLEED_R 可用環境變數調）

const PARTS := ["main_weapon", "off_weapon", "head", "body", "hands", "feet", "accessory", "mechanism"]
const DIR := "res://assets/UI/equipment/slots/"
const PAD := 16

func _init() -> void:
	var k := float(OS.get_environment("BLEED_K")) if OS.get_environment("BLEED_K") != "" else 1.0
	var radius := int(OS.get_environment("BLEED_R")) if OS.get_environment("BLEED_R") != "" else 9
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.frequency = 0.09
	for part in PARTS:
		var src := Image.load_from_file(ProjectSettings.globalize_path(DIR + "slot_frame_%s.png" % part))
		src.convert(Image.FORMAT_RGBA8)
		var w := src.get_width() + PAD * 2
		var h := src.get_height() + PAD * 2
		var a := PackedFloat32Array()
		a.resize(w * h)
		for y in src.get_height():
			for x in src.get_width():
				a[(y + PAD) * w + (x + PAD)] = src.get_pixel(x, y).a
		var blurred := _box_blur(_box_blur(a, w, h, radius), w, h, radius)       # 兩次方框模糊＝柔和的衰減
		var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var inside := a[y * w + x]
				var halo := clampf(blurred[y * w + x] * 2.6, 0.0, 1.0)
				var n := 0.72 + 0.56 * (noise.get_noise_2d(x, y) * 0.5 + 0.5)          # 墨暈邊緣不均勻
				var alpha := clampf(halo * n * 0.85 * k, 0.0, 0.9) * (1.0 - inside)
				out.set_pixel(x, y, Color(0.05, 0.03, 0.02, alpha))
		out.save_png(ProjectSettings.globalize_path(DIR + "slot_bleed_%s.png" % part))
		print("BLEED ", part, " ", out.get_size())
	quit()

func _box_blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var inv := 1.0 / float(2 * r + 1)
	for y in h:
		var sum := 0.0
		for x in range(-r, r + 1):
			if x >= 0 and x < w:
				sum += src[y * w + x]
		for x in w:
			tmp[y * w + x] = sum * inv
			var add_x := x + r + 1
			var sub_x := x - r
			if add_x < w:
				sum += src[y * w + add_x]
			if sub_x >= 0:
				sum -= src[y * w + sub_x]
	for x in w:
		var sum := 0.0
		for y in range(-r, r + 1):
			if y >= 0 and y < h:
				sum += tmp[y * w + x]
		for y in h:
			out[y * w + x] = sum * inv
			var add_y := y + r + 1
			var sub_y := y - r
			if add_y < h:
				sum += tmp[add_y * w + x]
			if sub_y >= 0:
				sum -= tmp[sub_y * w + x]
	return out
