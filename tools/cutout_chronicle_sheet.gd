extends SceneTree
# 一次性工具：把美術的《江湖行跡錄》素材總覽圖（白底、一張圖含全部元件）去背、切開、縮放成規格尺寸。
# 用法：Godot --headless --script tools/cutout_chronicle_sheet.gd -- <sheet> <輸出資料夾>
# 每個元件以「裁切範圍（目視座標）」＋「選配的內部種子點（鏤空畫框的中央）」定義；
# 從範圍邊緣（及種子點）往內洗掉接近白／中性淺灰的背景，只保留最大的連通區塊（排除下方的檔名標籤），邊緣做半透明處理。

# name: [rect(x0,y0,x1,y1), target_width, seed(x,y) 或 null]
const ITEMS := {
	"chronicle_frame": [[12, 2, 810, 400], 2176, null],
	"chronicle_title": [[905, 6, 1556, 132], 900, null],
	"thumb_frame_small": [[814, 240, 986, 346], 232, [900, 295]],
	"preview_frame": [[990, 186, 1326, 380], 768, [1160, 285]],
	"thumb_placeholder": [[1336, 201, 1656, 375], 752, null],
	"slot_bg_normal": [[30, 452, 412, 545], 624, null],
	"slot_bg_hover": [[420, 452, 804, 545], 624, null],
	"slot_bg_selected": [[806, 448, 1196, 545], 624, null],
	"slot_bg_empty": [[30, 583, 412, 675], 624, null],
	"slot_bg_corrupt": [[420, 583, 804, 675], 624, null],
	"confirm_panel": [[1226, 452, 1648, 736], 880, null],
	"btn_normal": [[30, 716, 310, 776], 368, null],
	"btn_hover": [[333, 716, 613, 776], 368, null],
	"btn_pressed": [[645, 716, 925, 776], 368, null],
	"btn_disabled": [[946, 716, 1220, 776], 368, null],
	"btn_primary_normal": [[30, 814, 310, 874], 368, null],
	"btn_primary_hover": [[333, 814, 613, 874], 368, null],
	"btn_primary_pressed": [[645, 814, 925, 874], 368, null],
	"btn_primary_disabled": [[946, 814, 1220, 874], 368, null],
}

## 第二套（dark_b）總覽圖的元件範圍（目視座標）。這張圖本身是透明底（包含畫框中央鏤空），所以背景判斷看透明度。
const ITEMS_B := {
	"chronicle_frame": [[14, 2, 856, 424], 2176, null],
	"chronicle_title": [[948, 48, 1590, 163], 900, null],
	"thumb_frame_small": [[858, 270, 1034, 394], 232, [945, 333]],
	"preview_frame": [[1038, 228, 1362, 414], 768, [1200, 320]],
	"thumb_placeholder": [[1366, 232, 1664, 402], 752, null],
	"slot_bg_normal": [[14, 468, 342, 574], 624, null],
	"slot_bg_hover": [[348, 468, 672, 574], 624, null],
	"slot_bg_selected": [[678, 466, 1000, 576], 624, null],
	"slot_bg_empty": [[1006, 468, 1334, 574], 624, null],
	"slot_bg_corrupt": [[1340, 468, 1664, 574], 624, null],
	"confirm_panel": [[1212, 618, 1660, 862], 880, null],
	"btn_normal": [[14, 648, 306, 722], 368, null],
	"btn_hover": [[312, 648, 606, 722], 368, null],
	"btn_pressed": [[611, 648, 903, 722], 368, null],
	"btn_disabled": [[908, 648, 1202, 722], 368, null],
	"btn_primary_normal": [[14, 776, 306, 848], 368, null],
	"btn_primary_hover": [[312, 776, 606, 848], 368, null],
	"btn_primary_pressed": [[611, 776, 903, 848], 368, null],
	"btn_primary_disabled": [[908, 776, 1202, 848], 368, null],
}

func _is_bg(r: int, g: int, b: int) -> bool:
	return r >= 205 and g >= 205 and b >= 205 and (maxi(r, maxi(g, b)) - mini(r, mini(g, b))) <= 14

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var sheet := Image.load_from_file(args[0])
	sheet.convert(Image.FORMAT_RGBA8)
	var items: Dictionary = ITEMS_B if args.size() > 2 and args[2] == "b" else ITEMS
	var sheet_has_alpha: bool = sheet.get_data()[3] < 10   # 左上角是透明的 = 透明底總覽圖
	DirAccess.make_dir_recursive_absolute(args[1])
	for item_name in items.keys():
		var spec: Array = items[item_name]
		var r: Array = spec[0]
		var crop := sheet.get_region(Rect2i(r[0], r[1], r[2] - r[0], r[3] - r[1]))
		var w := crop.get_width()
		var h := crop.get_height()
		var data := crop.get_data()
		var bg := PackedByteArray()
		bg.resize(w * h)
		var stack: Array[int] = []
		for x in w:
			stack.append(x)
			stack.append((h - 1) * w + x)
		for y in h:
			stack.append(y * w)
			stack.append(y * w + w - 1)
		if spec[2] != null:
			stack.append((int(spec[2][1]) - int(r[1])) * w + (int(spec[2][0]) - int(r[0])))
		while not stack.is_empty():
			var p: int = stack.pop_back()
			if bg[p] != 0:
				continue
			var is_bg_px := (data[p * 4 + 3] < 25) if sheet_has_alpha else _is_bg(data[p * 4], data[p * 4 + 1], data[p * 4 + 2])
			if not is_bg_px:
				continue
			bg[p] = 1
			var px := p % w
			var py := p / w
			if px > 0: stack.append(p - 1)
			if px < w - 1: stack.append(p + 1)
			if py > 0: stack.append(p - w)
			if py < h - 1: stack.append(p + w)
		# 最大連通的「前景」區塊（排除檔名標籤等零碎）
		var label := PackedInt32Array()
		label.resize(w * h)
		var best_id := 0
		var best_size := 0
		var next_id := 1
		for start in w * h:
			if bg[start] != 0 or label[start] != 0:
				continue
			var q: Array[int] = [start]
			label[start] = next_id
			var size := 0
			while not q.is_empty():
				var p2: int = q.pop_back()
				size += 1
				var x2 := p2 % w
				var y2 := p2 / w
				for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
					var nx: int = x2 + d[0]
					var ny: int = y2 + d[1]
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var np := ny * w + nx
					if bg[np] == 0 and label[np] == 0:
						label[np] = next_id
						q.append(np)
			if size > best_size:
				best_size = size
				best_id = next_id
			next_id += 1
		# 輸出：背景與零碎透明；前景邊緣（緊鄰背景）依「離白色多遠」做半透明
		var out := PackedByteArray()
		out.resize(w * h * 4)
		var min_x := w
		var min_y := h
		var max_x := 0
		var max_y := 0
		for p3 in w * h:
			var keep := label[p3] == best_id
			var rr: int = data[p3 * 4]
			var gg: int = data[p3 * 4 + 1]
			var bb: int = data[p3 * 4 + 2]
			var a := 255
			if not keep:
				a = 0
			else:
				var x3 := p3 % w
				var y3 := p3 / w
				var near_bg := false
				for d2 in [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]]:
					var nx2: int = x3 + d2[0]
					var ny2: int = y3 + d2[1]
					if nx2 >= 0 and ny2 >= 0 and nx2 < w and ny2 < h and bg[ny2 * w + nx2] != 0:
						near_bg = true
						break
				if sheet_has_alpha:
					a = data[p3 * 4 + 3]
				elif near_bg:
					var m := mini(rr, mini(gg, bb))
					a = int(clampf((255.0 - float(m)) / 110.0, 0.0, 1.0) * 255.0)
					a = maxi(a, 90)
			out[p3 * 4] = rr
			out[p3 * 4 + 1] = gg
			out[p3 * 4 + 2] = bb
			out[p3 * 4 + 3] = a
			if a > 0:
				var xx := p3 % w
				var yy := p3 / w
				min_x = mini(min_x, xx); max_x = maxi(max_x, xx)
				min_y = mini(min_y, yy); max_y = maxi(max_y, yy)
		var cut := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
		cut = cut.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
		var tw: int = spec[1]
		var th := int(round(float(cut.get_height()) * float(tw) / float(cut.get_width())))
		cut.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		# 同一組狀態圖必須完全同尺寸：按鈕統一 368×72；欄位底統一 624×164（選中版的金色光暈佔掉上下 13px，其他四張上下補透明）
		if item_name.begins_with("btn_"):
			cut.resize(368, 72, Image.INTERPOLATE_LANCZOS)
			th = 72
		elif item_name.begins_with("slot_bg_"):
			# 欄位底只留「板子本體」（不透明度 ≥ 230 的範圍）：陰影與選中版的金色光暈不留透明邊，欄位上下緊貼時才不會透出底圖。五張統一 624×140。
			var x0 := 624
			var y0 := cut.get_height()
			var x1 := 0
			var y1 := 0
			for yy in cut.get_height():
				for xx in 624:
					if cut.get_pixel(xx, yy).a >= 0.9:
						x0 = mini(x0, xx); x1 = maxi(x1, xx)
						y0 = mini(y0, yy); y1 = maxi(y1, yy)
			cut = cut.get_region(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
			cut.resize(624, 140, Image.INTERPOLATE_LANCZOS)
			th = 140
		var path := "%s/%s.png" % [args[1], item_name]
		cut.save_png(path)
		print("CUT ", item_name, " native=", Vector2i(max_x - min_x + 1, max_y - min_y + 1), " -> ", Vector2i(tw, th), " fg=", best_size)
	quit()
