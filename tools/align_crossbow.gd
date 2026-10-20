extends SceneTree
# 把美術（GPT）給的完整連弩圖（360×220，橫放）擺到老闆手擺的參考位置（參考只拿來對位，不用它的像素）。
# 老闆的指示：連弩圖先轉 90°，再水平翻轉，方向才對。
# 做法：裁掉透明留白 → 順時針轉 90° → 水平翻轉 → 在（旋轉角、縮放、位置）上搜尋，讓美術圖蓋住參考的不透明範圍 →
#       用最佳參數把美術圖合成到 508×972 全畫布。圖的像素全部來自美術的原圖，參考只提供位置。
# 用法：godot --headless --path . --script tools/align_crossbow.gd

const REF := "res://docs/system_menu/doll_pack_v1/crossbow_ref_boss.png"
const ART := "res://docs/system_menu/doll_pack_v1/crossbow_local_artist.png"
const OUT := "res://assets/UI/equipment/doll/doll_mech_tool_zhuge_crossbow.png"
const W := 508
const H := 972

var ref_mask := PackedByteArray()
var ref_count := 0

func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img

func _used(img: Image, threshold := 0.3) -> Rect2i:
	var bb := Rect2i()
	var first := true
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > threshold:
				if first:
					bb = Rect2i(x, y, 1, 1)
					first = false
				else:
					bb = bb.expand(Vector2i(x, y))
	return bb

## 美術圖點 p（以圖中心為原點）→ 全畫布座標：先縮放、再順時針轉 deg、再平移到 (cx, cy)
func _map(p: Vector2, sc: float, deg: float, cx: float, cy: float) -> Vector2:
	var r := deg_to_rad(deg)
	var q := p * sc
	return Vector2(cx + q.x * cos(r) - q.y * sin(r), cy + q.x * sin(r) + q.y * cos(r))

func _score(pts: Array, sc: float, deg: float, cx: float, cy: float) -> float:
	var hit := 0
	var tot := 0
	var covered := {}
	for p: Vector2 in pts:
		var m := _map(p, sc, deg, cx, cy)
		var x := int(m.x)
		var y := int(m.y)
		if x < 0 or y < 0 or x >= W or y >= H:
			continue
		tot += 1
		if ref_mask[y * W + x] == 1:
			hit += 1
			covered[(y / 4) * 1000 + (x / 4)] = true
	if tot < 30:
		return -1.0
	return 0.5 * (float(hit) / float(tot)) + 0.5 * minf(float(covered.size()) * 16.0 / float(ref_count), 1.0)

func _init() -> void:
	var ref := _load(REF)
	ref.resize(W, H, Image.INTERPOLATE_BILINEAR)
	ref_mask.resize(W * H)
	for y in H:
		for x in W:
			if ref.get_pixel(x, y).a > 0.5:
				ref_mask[y * W + x] = 1
				ref_count += 1
	var box := _used(ref, 0.5)
	var art := _load(ART)
	art = art.get_region(_used(art))
	art.rotate_90(CLOCKWISE)
	art.flip_x()
	var aw := art.get_width()
	var ah := art.get_height()
	var pts: Array = []
	for y in range(0, ah, 2):
		for x in range(0, aw, 2):
			if art.get_pixel(x, y).a > 0.5:
				pts.append(Vector2(x - aw * 0.5, y - ah * 0.5))
	var base_sc := float(box.size.y) / float(ah)
	var ref_c := Vector2(box.position) + Vector2(box.size) * 0.5
	var best := -1.0
	var bp := {}
	for deg in range(0, 41, 2):
		for s in range(80, 126, 5):
			var sc := base_sc * s / 100.0
			for dy in range(-30, 31, 6):
				for dx in range(-30, 31, 6):
					var v := _score(pts, sc, float(deg), ref_c.x + dx, ref_c.y + dy)
					if v > best:
						best = v
						bp = {"deg": float(deg), "sc": sc, "cx": ref_c.x + dx, "cy": ref_c.y + dy}
	var b2 := bp.duplicate()
	for dd in range(-2, 3):
		for ds in range(-4, 5, 2):
			for dy in range(-6, 7, 2):
				for dx in range(-6, 7, 2):
					var v := _score(pts, float(bp["sc"]) * (1.0 + ds / 100.0), float(bp["deg"]) + dd * 0.5, float(bp["cx"]) + dx, float(bp["cy"]) + dy)
					if v > best:
						best = v
						b2 = {"deg": float(bp["deg"]) + dd * 0.5, "sc": float(bp["sc"]) * (1.0 + ds / 100.0), "cx": float(bp["cx"]) + dx, "cy": float(bp["cy"]) + dy}
	print("ALIGN ", b2, " score=", snappedf(best, 0.001))
	# 反向取樣合成（美術原圖，雙線性）
	var out := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var r := deg_to_rad(float(b2["deg"]))
	var sc2: float = b2["sc"]
	var cx: float = b2["cx"]
	var cy: float = b2["cy"]
	for y in H:
		for x in W:
			var dx2 := x - cx
			var dy2 := y - cy
			var ux := (dx2 * cos(r) + dy2 * sin(r)) / sc2 + aw * 0.5
			var uy := (-dx2 * sin(r) + dy2 * cos(r)) / sc2 + ah * 0.5
			if ux < 0.0 or uy < 0.0 or ux >= aw - 1 or uy >= ah - 1:
				continue
			var x0 := int(ux)
			var y0 := int(uy)
			var fx := ux - x0
			var fy := uy - y0
			var c := art.get_pixel(x0, y0).lerp(art.get_pixel(x0 + 1, y0), fx).lerp(art.get_pixel(x0, y0 + 1).lerp(art.get_pixel(x0 + 1, y0 + 1), fx), fy)
			if c.a > 0.01:
				out.set_pixel(x, y, c)
	out.save_png(ProjectSettings.globalize_path(OUT))
	print("ALIGN saved")
	quit()
