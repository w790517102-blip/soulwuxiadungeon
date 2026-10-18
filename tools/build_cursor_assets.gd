extends SceneTree
# 一次性工具：把切好的游標素材縮成遊戲用尺寸（2 倍解析度，遊戲裡再縮放 0.5）。
# 用法：Godot --headless --script tools/build_cursor_assets.gd -- <切圖資料夾> <輸出資料夾>
# 箭頭、流蘇、對話框用同一個縮放比，保持彼此的大小關係；手另外縮放到和箭頭差不多高。
const ARROW_SCALE := 0.271   # 箭頭（295px 高）→ 約 80px
const HAND_SCALE := 0.131    # 手（610px 高）→ 約 80px
const MAP := {
	"s12_1_1": ["cursor_idle", ARROW_SCALE],
	"s12_1_2": ["cursor_move", ARROW_SCALE],
	"s12_1_3": ["cursor_run", ARROW_SCALE],
	"s12_2_1": ["tassel_alt", ARROW_SCALE],
	"s12_2_2": ["tassel_move", ARROW_SCALE],
	"s12_2_3": ["tassel_run", ARROW_SCALE],
	"s12_3_1": ["cursor_talk_a", ARROW_SCALE],
	"s12_3_2": ["cursor_talk_b", ARROW_SCALE],
	"s12_3_3": ["cursor_hand_alt", ARROW_SCALE],
	"s11_1_1": ["cursor_inspect_a", HAND_SCALE],
	"s11_1_2": ["cursor_inspect_b", HAND_SCALE],
}
## 補洞：被去背誤傷、被不透明輪廓整圈包住的透明/半透明區域（例如對話框左上的高光）
## 從圖片邊界往內找「外面」的透明區，剩下沒被找到的透明點（洞）整片填成 fill 顏色並設成不透明。
func _fill_holes(im: Image, fill: Color) -> int:
	var w := im.get_width()
	var h := im.get_height()
	var outside := PackedByteArray()
	outside.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var p: int = stack.pop_back()
		if outside[p] != 0:
			continue
		if im.get_pixel(p % w, p / w).a >= 0.6:
			continue
		outside[p] = 1
		var px := p % w
		var py := p / w
		if px > 0: stack.append(p - 1)
		if px < w - 1: stack.append(p + 1)
		if py > 0: stack.append(p - w)
		if py < h - 1: stack.append(p + w)
	var hole := PackedByteArray()
	hole.resize(w * h)
	var hole_count := 0
	for p in w * h:
		if outside[p] == 0 and im.get_pixel(p % w, p / w).a < 0.6:
			hole[p] = 1
			hole_count += 1
	var frontier: Array[int] = []
	for p in w * h:
		if hole[p] == 1:
			continue
		if im.get_pixel(p % w, p / w).a < 0.6:
			continue
		var px2 := p % w
		var py2 := p / w
		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var nx: int = px2 + d[0]
			var ny: int = py2 + d[1]
			if nx >= 0 and ny >= 0 and nx < w and ny < h and hole[ny * w + nx] == 1:
				frontier.append(p)
				break
	while not frontier.is_empty():
		var next: Array[int] = []
		for p in frontier:
			var c := fill
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nx: int = p % w + d[0]
				var ny: int = p / w + d[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var np := ny * w + nx
					if hole[np] == 1:
						hole[np] = 2
						im.set_pixel(nx, ny, c)
						next.append(np)
		frontier = next
	return hole_count

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for src in MAP.keys():
		var im := Image.load_from_file("%s/%s.png" % [args[0], src])
		# 只補對話框與備用手：箭頭上的灰白點是刻意的高光，不能補成金色。洞用本體的奶油色填滿（指向的手 inspect_a/b 檢查過沒有洞）。
		if String(MAP[src][0]).begins_with("cursor_talk") or MAP[src][0] == "cursor_hand_alt":
			print("HOLES ", MAP[src][0], " filled=", _fill_holes(im, Color(0.99, 0.94, 0.86, 1.0)))
		var k: float = MAP[src][1]
		im.resize(maxi(1, int(round(im.get_width() * k))), maxi(1, int(round(im.get_height() * k))), Image.INTERPOLATE_LANCZOS)
		im.save_png("%s/%s.png" % [args[1], MAP[src][0]])
		print("BUILT ", MAP[src][0], " ", im.get_size())
	quit()
