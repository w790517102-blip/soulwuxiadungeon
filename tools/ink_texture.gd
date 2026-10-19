extends SceneTree
# 筆畫圖章（墨色標籤、稀有度章、類別章、使用狀態章、紅印章）的紋理處理：
# 讓平滑的色塊有毛筆的質感——邊緣飛白（乾筆的缺口與細絲）、墨色濃淡不均、纖維顆粒。
# 原圖備份在 docs/system_menu/ink_originals/，輸出寫回 assets/UI/inventory/（可重跑、可調強度）。
# 用法：godot --headless --path . --script tools/ink_texture.gd        （強度可用 INK_K=0.5~1.5 調）
# 跑完要 godot --headless --path . --import

const FILES := ["label_ink_s", "label_ink_m", "rarity_1", "rarity_2", "rarity_3", "rarity_4", "seal_type",
	"status_usable", "status_battle", "status_disabled",
	"badge_book", "badge_consumable", "badge_equipment", "badge_equipped", "badge_material", "badge_other", "badge_quest"]
const SRC_DIR := "res://docs/system_menu/ink_originals/"
const DST_DIR := "res://assets/UI/inventory/"

var _fine := FastNoiseLite.new()
var _mid := FastNoiseLite.new()
var _streak := FastNoiseLite.new()

func _init() -> void:
	var k := 1.0
	if OS.get_environment("INK_K") != "":
		k = float(OS.get_environment("INK_K"))
	for n: FastNoiseLite in [_fine, _mid, _streak]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
	_fine.seed = 3;   _fine.frequency = 0.55; _fine.fractal_octaves = 2
	_mid.seed = 11;   _mid.frequency = 0.09;  _mid.fractal_octaves = 3
	_streak.seed = 23; _streak.frequency = 0.05; _streak.fractal_octaves = 2
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SRC_DIR))
	for f in FILES:
		var src_abs := ProjectSettings.globalize_path(SRC_DIR + f + ".png")
		var dst_abs := ProjectSettings.globalize_path(DST_DIR + f + ".png")
		if not FileAccess.file_exists(src_abs):
			DirAccess.copy_absolute(dst_abs, src_abs)            # 第一次：先備份原圖
		_texture_one(src_abs, dst_abs, k)
	quit()

func _alpha_at(img: Image, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return 0.0
	return img.get_pixel(x, y).a

func _texture_one(src: String, dst: String, k: float) -> void:
	var img := Image.load_from_file(src)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.02:
				out.set_pixel(x, y, c)
				continue
			# 離邊多近：往四個方向看 3 像素，有透明的就是邊
			var edge := 0.0
			for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2), Vector2i(-2, -2)]:
				edge = maxf(edge, 1.0 - _alpha_at(img, x + d.x, y + d.y))
			var fine := _fine.get_noise_2d(x, y)
			var mid := _mid.get_noise_2d(x, y)
			var streak := _streak.get_noise_2d(x * 0.35, y * 2.2)       # 橫向拉長：像一筆掃過去的絲
			# 1) 飛白：邊緣處，依絲狀噪點把 alpha 咬掉一些缺口
			var bite := clampf((streak - 0.1) * 2.4, 0.0, 1.0) * edge * 0.85 * k
			var a := c.a * (1.0 - bite)
			a *= 1.0 - clampf((fine - 0.55) * 3.0, 0.0, 0.5) * edge * k          # 邊緣的細碎缺口
			# 2) 墨色濃淡：內部乘上緩慢變化的明暗
			var tone := 1.0 + mid * 0.16 * k + fine * 0.05 * k
			# 3) 紙纖維透出：零星淡點讓墨色看得到紙紋
			var fleck := clampf((fine - 0.62) * 4.0, 0.0, 1.0) * 0.28 * k
			var col := Color(clampf(c.r * tone, 0.0, 1.0), clampf(c.g * tone, 0.0, 1.0), clampf(c.b * tone, 0.0, 1.0), a)
			col = col.lerp(Color(0.85, 0.80, 0.68, a), fleck)
			out.set_pixel(x, y, col)
	out.save_png(dst)
	print("INK ", src.get_file())
