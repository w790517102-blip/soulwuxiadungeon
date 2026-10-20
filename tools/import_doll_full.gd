extends SceneTree
# 整張人物立繪（老闆提供的 webp，已去背）→ 縮成紙娃娃畫布 508×972，輸出 assets/UI/equipment/doll/<名稱>.png。
# 母圖（凡品）與沒有分層的衣裝都是整張圖，劍與機關疊在它上面。
# 用法：godot --headless --path . --script tools/import_doll_full.gd
const JOBS := [
	["res://docs/system_menu/doll_pack_v1/liu_tier2_plain.webp", "doll_liuyu_r2"],
	["res://docs/system_menu/doll_pack_v1/liu_tier3_bracer.webp", "doll_liuyu_r3"],
	["res://docs/system_menu/doll_pack_v1/shumian_master_boss.webp", "doll_shumian_master"],
]

func _init() -> void:
	for job in JOBS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(job[0]))
		img.convert(Image.FORMAT_RGBA8)
		print("DOLL ", job[1], " source ", img.get_size(), " corner alpha ", img.get_pixel(2, 2).a)
		img.resize(508, 972, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://assets/UI/equipment/doll/%s.png" % job[1]))
	quit()
