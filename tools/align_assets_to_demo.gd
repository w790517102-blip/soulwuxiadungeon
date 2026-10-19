extends SceneTree
# 把「真正的前景素材」對位到使用者 DEMO 的位置與大小（不是用摳圖）：
# 以 extract_overlay_from_demo 取出的前景遮罩當量測用的目標，搜尋每件素材的（縮放、位置），讓它蓋住目標遮罩且不超出遮罩。
# 輸出的是 1916×1078 畫面上的左上角與縮放；StudyShell 會換算成邏輯座標。只用來量測，量完不用遮罩。
# 用法：Godot --headless --script tools/align_assets_to_demo.gd

const OV := "res://assets/UI/inventory/fg_demo_overlay.png"
const W := 1916
const H := 1078
## 被按鈕蓋住的區域：素材不透明但遮罩透明，是正常的，不扣分（按鈕在前景之上）
const HIDDEN := [Rect2(500, 970, 1260, 75)]
## 劍向後延伸，可以被框（卷軸、分類欄）遮住：這些區域內素材不透明但遮罩透明，不扣分（只用在劍）
const FRAME_HIDDEN := [Rect2(255, 120, 1630, 818), Rect2(40, 125, 215, 730)]
## 名稱 → [素材, ROI 方塊們, 縮放範圍 [最小, 最大]（目標像素／素材像素）, 位置搜尋範圍 Rect2 (左上角 x 範圍)]
const JOBS := {
	"book": ["res://assets/UI/inventory/fg_ours_v3/fg_book.png", [Rect2(0, 840, 470, 170)], [0.55, 1.4], Rect2(-300, 700, 700, 500)],
	"sword": ["res://assets/UI/inventory/fg_ours_v3/fg_sword.png", [Rect2(100, 990, 460, 88), Rect2(500, 925, 840, 75)], [0.9, 1.9], Rect2(-250, 800, 800, 400), true],
	"teapot": ["res://assets/UI/inventory/fg_ours_v3/fg_teapot.png", [Rect2(1640, 900, 276, 178)], [0.8, 2.2], Rect2(1300, 700, 700, 500)],
	"lantern": ["res://assets/UI/inventory/fg_ours_v3/fg_candle.png", [Rect2(1840, 100, 76, 830)], [0.55, 1.1], Rect2(1700, -100, 300, 300)],
}

var tmask: PackedByteArray
var _frame_hide := false

func _init() -> void:
	var ov := Image.load_from_file(OV); ov.convert(Image.FORMAT_RGBA8)
	tmask = PackedByteArray(); tmask.resize(W * H)
	for y in H:
		for x in W:
			if ov.get_pixel(x, y).a > 0.5: tmask[y * W + x] = 1
	for name in JOBS.keys():
		var job: Array = JOBS[name]
		var asset := Image.load_from_file(job[0]); asset.convert(Image.FORMAT_RGBA8)
		_frame_hide = job.size() > 4 and bool(job[4])
		var best := _search(asset, job[1], job[2], job[3])
		print("ALIGN ", name, " scale=", snappedf(best[0], 0.001), " x=", best[1], " y=", best[2], " score=", snappedf(best[3], 0.001), " asset=", asset.get_size())
	quit()

func _score(apx: Array, s: float, ox: int, oy: int, rois: Array, roi_total: float) -> float:
	# apx: [[ax, ay], ...] 素材不透明像素（已抽樣）；s：縮放；(ox, oy)：左上角
	var hit := 0; var tot := 0
	for p in apx:
		var x := int(ox + p[0] * s); var y := int(oy + p[1] * s)
		if x < 0 or y < 0 or x >= W or y >= H: continue    # 超出畫面不扣分（前景可以只入鏡一部分）
		var hidden := false
		for r in HIDDEN:
			if r.has_point(Vector2(x, y)): hidden = true
		if _frame_hide:
			for r in FRAME_HIDDEN:
				if r.has_point(Vector2(x, y)): hidden = true
		if hidden: continue
		tot += 1
		if tmask[y * W + x] == 1: hit += 1
	if tot < 30: return -1.0
	var precision := float(hit) / float(tot)
	# 覆蓋率：ROI 內的目標像素有多少被素材蓋到（用素材抽樣點粗估）
	var covered := {}
	for p in apx:
		var x := int(ox + p[0] * s); var y := int(oy + p[1] * s)
		if x < 0 or y < 0 or x >= W or y >= H: continue
		if tmask[y * W + x] == 1:
			for r in rois:
				if r.has_point(Vector2(x, y)):
					covered[(y / 6) * 1000 + (x / 6)] = true
	var coverage := minf(float(covered.size()) / roi_total, 1.0)
	return 0.6 * precision + 0.4 * coverage

func _search(asset: Image, rois: Array, srange: Array, prange: Rect2) -> Array:
	var step := 4
	var apx: Array = []
	for y in range(0, asset.get_height(), step):
		for x in range(0, asset.get_width(), step):
			if asset.get_pixel(x, y).a > 0.6: apx.append([x, y])
	# ROI 內目標像素總數（以 6×6 格計）
	var cells := {}
	for r in rois:
		for y in range(int(r.position.y), int(r.end.y), 6):
			for x in range(int(r.position.x), int(r.end.x), 6):
				if tmask[y * W + x] == 1: cells[(y / 6) * 1000 + (x / 6)] = true
	var roi_total := maxf(float(cells.size()), 1.0)
	var best := [1.0, 0, 0, -9.0]
	var s: float = srange[0]
	while s <= srange[1]:
		var y := int(prange.position.y)
		while y < int(prange.end.y):
			var x := int(prange.position.x)
			while x < int(prange.end.x):
				var sc := _score(apx, s, x, y, rois, roi_total)
				if sc > best[3]: best = [s, x, y, sc]
				x += 16
			y += 16
		s += 0.06
	# 精修
	var s0: float = best[0]; var x0: int = best[1]; var y0: int = best[2]
	for ds in range(-6, 7):
		var s2 := s0 + ds * 0.01
		for dy in range(-12, 13, 2):
			for dx in range(-12, 13, 2):
				var sc := _score(apx, s2, x0 + dx, y0 + dy, rois, roi_total)
				if sc > best[3]: best = [s2, x0 + dx, y0 + dy, sc]
	return best
