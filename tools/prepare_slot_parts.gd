extends SceneTree
# 裝備格 V3 的零件整理：把「部位文字」與「灰色空槽剪影」各自裁到不透明範圍，輸出到 assets/UI/equipment/slots/。
# 原因：共邊國的文字大小不一、剪影位置不一，裁緊之後程式才能統一縮放與置中。
# 原檔在 docs/system_menu/equipment_originals/slots_v3/；用法：godot --headless --path . --script tools/prepare_slot_parts.gd

const SRC := "res://docs/system_menu/equipment_originals/slots_v3/"
const OUT := "res://assets/UI/equipment/slots/"
const PARTS := ["main_weapon", "off_weapon", "head", "body", "hands", "feet", "accessory", "mechanism"]

func _tight(path: String, save_to: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	var bb := Rect2i()
	var first := true
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.04:
				if first:
					bb = Rect2i(x, y, 1, 1)
					first = false
				else:
					bb = bb.expand(Vector2i(x, y))
	if first:
		push_error("empty image: " + path)
		return
	var out := img.get_region(bb)
	out.save_png(ProjectSettings.globalize_path(save_to))
	print("TIGHT ", path.get_file(), " -> ", save_to.get_file(), " ", out.get_size())

func _init() -> void:
	for p in PARTS:
		_tight(SRC + "slot_label_%s.png" % p, OUT + "label_%s.png" % p)
		_tight(SRC + "slot_empty_%s.png" % p, OUT + "ghost_%s.png" % p)
	quit()
