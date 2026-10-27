extends RefCounted
# 書房卷軸頁共用的「專屬前景」：武術頁的（左下、右下、右緣：念珠、墨壺、燭燈柱）、見聞頁的（左右兩側：墨筆、詩集）。
# 武術頁、見聞頁自己用，任務頁用武術的、系統頁用見聞的（老闆指定）。座標是邏輯 px（1152×648）；全部不吃滑鼠。

const MARTIAL_DIR := "res://assets/UI/martial/"
const LORE_DIR := "res://assets/UI/lore/"

## 武術頁前景（共邊國 martial_final_overlays）：圖已裁到內容邊界，依概念圖位置貼邊
const MARTIAL_DEFS := [
	["foreground_left", Vector2(0, 648), Vector2(365, 0), Vector2(0, 1)],        # 左下：寬 365，底貼畫布底、左貼畫布左
	["foreground_right", Vector2(1152, 648), Vector2(332, 0), Vector2(1, 1)],    # 右下：寬 332，右下角貼齊
	["foreground_edge_right", Vector2(1152, 0), Vector2(0, 561), Vector2(1, 0)], # 右緣：高 561，右上角貼齊
]

## 見聞頁前景：左右各一，右邊的卷軸原圖被上下拉長了：高度壓成 0.8 倍、橫向加寬 1.3 倍，右下角貼齊原本的位置
const LORE_DEFS := [
	["lore_fg_left", Vector2(0, 430), Vector2(1.0, 1.0)],
	["lore_fg_right", Vector2(960, 420), Vector2(1.3, 0.8)],
]


static func _tex(dir: String, name_: String) -> Texture2D:
	for ext in ["png", "webp"]:
		var p := "%s%s.%s" % [dir, name_, ext]
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null


static func _image(tex: Texture2D, pos: Vector2, size_: Vector2, parent: Node, name_: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = name_
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.position = pos
	r.size = size_
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## 武術頁的前景（念珠、墨壺、燭燈柱）
static func add_martial(page: Control) -> void:
	for d in MARTIAL_DEFS:
		var tex := _tex(MARTIAL_DIR, String(d[0]))
		if tex == null:
			continue
		var tsize := tex.get_size()
		var size_: Vector2 = d[2]
		if size_.x == 0.0:
			size_.x = size_.y * tsize.x / tsize.y
		elif size_.y == 0.0:
			size_.y = size_.x * tsize.y / tsize.x
		var anchor: Vector2 = d[3]
		var r := _image(tex, Vector2(d[1]) - size_ * anchor, size_, page, String(d[0]))
		r.z_index = 6 if String(d[0]) == "foreground_right" else 5      # 右下的墨壺要高過右緣燭燈柱


## 見聞頁的前景（墨筆、詩集），每件底下有一張陰影圖
static func add_lore(page: Control) -> void:
	for d in LORE_DEFS:
		var tex := _tex(LORE_DIR, String(d[0]))
		if tex == null:
			continue
		var sz: Vector2 = tex.get_size() * 0.5 * (d[2] as Vector2)
		var pos: Vector2 = Vector2(d[1]) + tex.get_size() * 0.5 - sz
		var shadow_tex := _tex(LORE_DIR, String(d[0]) + "_shadow")
		if shadow_tex != null:
			_image(shadow_tex, pos, sz, page, String(d[0]) + "_shadow").z_index = 6
		_image(tex, pos, sz, page, String(d[0])).z_index = 7
