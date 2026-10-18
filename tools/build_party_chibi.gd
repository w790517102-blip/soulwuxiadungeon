extends SceneTree
# 一次性工具：從角色場景的 AnimatedSprite2D 取出「左下 idle」第一格，裁掉透明邊，存成存檔畫面隊伍陣容用的小人圖。
# 不需要實例化場景（場景腳本依賴 autoload），直接讀 PackedScene 的節點屬性。
# 用法：Godot --headless --script tools/build_party_chibi.gd
const SOURCES := {
	"liuyu": "res://scenes/Liu_Yu.tscn",
	"shumian": "res://scenes/yuheng/yuheng_market_west/Bai_Jian_Jue/Su_mien.tscn",
}
const ANIM_CANDIDATES := ["idle_left_down", "idle_down", "idle_right_down"]
const OUT_DIR := "res://assets/UI/chronicle_party/"
## 探索畫面上的角色根節點縮放（GameRoot 裡劉語塵 0.3；NPC 場景擺在地圖時也是 0.3）。
const WORLD_ROOT_SCALE := 0.3

func _init() -> void:
	var scales := {}
	for id in SOURCES.keys():
		var packed := load(SOURCES[id]) as PackedScene
		if packed == null:
			print("PARTY skip ", id, " (scene not found)")
			continue
		var state := packed.get_state()
		var frames: SpriteFrames = null
		for i in state.get_node_count():
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == "sprite_frames":
					frames = state.get_node_property_value(i, j) as SpriteFrames
		if frames == null:
			print("PARTY skip ", id, " (no sprite_frames)")
			continue
		var anim := ""
		for a in ANIM_CANDIDATES:
			if frames.has_animation(a):
				anim = a
				break
		if anim == "":
			print("PARTY skip ", id, " (no idle animation)")
			continue
		# 這個角色在遊戲畫面上的實際縮放 = 根節點縮放 × 該 AnimatedSprite2D 自己的縮放
		var sprite_scale := 1.0
		for i in state.get_node_count():
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == "sprite_frames":
					for k in state.get_node_property_count(i):
						if state.get_node_property_name(i, k) == "scale":
							sprite_scale = (state.get_node_property_value(i, k) as Vector2).x
		scales[id] = WORLD_ROOT_SCALE * sprite_scale
		var tex := frames.get_frame_texture(anim, 0)
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		# 只算「實心」像素（不透明度 > 0.5）：淡淡的地面影子不算，腳底才會是真正的腳底
		var minx := img.get_width()
		var miny := img.get_height()
		var maxx := 0
		var maxy := 0
		for yy in img.get_height():
			for xx in img.get_width():
				if img.get_pixel(xx, yy).a > 0.5:
					minx = mini(minx, xx); maxx = maxi(maxx, xx)
					miny = mini(miny, yy); maxy = maxi(maxy, yy)
		img = img.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))
		img.save_png("%s%s.png" % [OUT_DIR, id])
		print("PARTY ", id, " anim=", anim, " size=", img.get_size())
	var f := FileAccess.open(OUT_DIR + "scales.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(scales, "  "))
	f.close()
	print("PARTY scales=", scales)
	quit()
