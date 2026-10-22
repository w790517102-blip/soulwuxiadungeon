extends Control
## 翻頁示範（純 2D，沒有 3D 模型）：頁面在 SubViewport 裡正常排版（文字、圖都是一般控制項），
## 貼到一張細分的網格上，用頂點 shader 讓整頁沿書脊彎曲翻過去；翻完攤平。背面看到的是下一頁的內容。
## 執行：用編輯器開 tools/book_flip_demo.tscn 按 F6，點滑鼠或按空白鍵翻頁。
## 截圖模式：環境變數 CAPTURE=輸出資料夾，會自動存翻頁過程的連拍。

const PAGE := Vector2(400, 540)
const SPINE := Vector2(576, 70)
const COLS := 64
const FONT := preload("res://assets/fonts/UIFontKaiti.tres")

const SHADER := "shader_type canvas_item;
uniform float t = 0.0;            // 0＝平放在右邊，1＝翻到左邊
uniform float curl = 1.5;         // 彎曲程度（弧度）：自由邊落後書脊多少
uniform vec2 page_size = vec2(400.0, 540.0);
uniform sampler2D back_tex : filter_linear;
varying float ang;
void vertex() {
	float s = VERTEX.x;
	float th = t * 3.14159265;
	float k = curl * sin(th) / page_size.x;
	float a = th - k * s;
	float x = s * cos(th);
	float z = s * sin(th);
	if (abs(k) > 0.00001) {
		x = (sin(th) - sin(a)) / k;
		z = (cos(a) - cos(th)) / k;
	}
	float cy = page_size.y * 0.5;
	VERTEX.x = x;
	VERTEX.y = cy + (VERTEX.y - cy) * (1.0 + z * 0.00035);   // 透視：離書脊越遠、翻得越高，頁面越大一點
	ang = a;
}
void fragment() {
	vec4 c;
	if (ang > 1.5707963) {
		c = texture(back_tex, vec2(1.0 - UV.x, UV.y));      // 翻過去之後看到背面（鏡像回來）
	} else {
		c = texture(TEXTURE, UV);
	}
	float shade = 0.72 + 0.28 * abs(cos(ang));              // 彎曲處與垂直處較暗，平放最亮
	c.rgb *= shade;
	COLOR = c;
}"

var _leaf: MeshInstance2D
var _mat: ShaderMaterial
var _t := 0.0
var _flipping := false
var _dir := 1.0

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2A1C12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 書本底（書皮與書頁厚度）
	var cover := ColorRect.new()
	cover.color = Color("#4A2A18")
	cover.position = SPINE - Vector2(PAGE.x + 22, 20)
	cover.size = Vector2(PAGE.x * 2 + 44, PAGE.y + 40)
	add_child(cover)
	var pages := [
		_make_page("第一頁", "奇物 · 其一", "青銅劍", "以青銅鍛造的尋常長劍，劍身略有歲月磨痕，仍足以伴隨初入江湖的俠客遠行。", "res://assets/UI/inventory/item_art_16.png"),
		_make_page("第二頁", "詳細資料", "青銅劍", "品類：劍類兵器\n品質：尋常\n重量：3\n攻擊力 +4\n速度 +1\n\n字也會跟著頁面一起彎曲，翻完之後攤平。", ""),
		_make_page("第三頁", "奇物 · 其二", "回氣丹", "以藥草煉成的小丹，服下後氣息回流，內力稍復。", "res://assets/UI/inventory/item_art_01.png"),
		_make_page("第四頁", "詳細資料", "回氣丹", "品類：消耗\n效果：回復 20 點內力\n\n這一頁是翻頁時看到的背面。", ""),
	]
	# 靜態：左頁（上一筆的詳細資料）、右頁底（下一筆的簡述）
	var left := _page_rect(pages[1], SPINE - Vector2(PAGE.x, 0))
	add_child(left)
	var right_under := _page_rect(pages[2], SPINE)
	add_child(right_under)
	# 書脊陰影
	var spine := ColorRect.new()
	spine.color = Color(0, 0, 0, 0.35)
	spine.position = SPINE + Vector2(-3, 0)
	spine.z_index = -1
	spine.size = Vector2(6, PAGE.y)
	add_child(spine)
	# 翻動的那一張：正面＝第一頁，背面＝第四頁（翻過去後落在左邊）
	_leaf = MeshInstance2D.new()
	_leaf.mesh = _grid_mesh()
	_leaf.position = SPINE
	_leaf.texture = pages[0]
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("back_tex", pages[3])
	_mat.set_shader_parameter("page_size", PAGE)
	_leaf.material = _mat
	add_child(_leaf)
	var hint := Label.new()
	hint.text = "點滑鼠或按空白鍵翻頁"
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_color_override("font_color", Color("#E8D8B0"))
	hint.position = Vector2(20, 610)
	add_child(hint)
	var cap := OS.get_environment("CAPTURE")
	if cap != "":
		_capture(cap)

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_start_flip()

func _start_flip() -> void:
	if _flipping:
		return
	_flipping = true
	var tw := create_tween()
	var from := _t
	var to := 0.0 if from > 0.5 else 1.0
	tw.tween_method(_set_t, from, to, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _flipping = false)

func _set_t(v: float) -> void:
	_t = v
	_mat.set_shader_parameter("t", v)

func _grid_mesh() -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in COLS + 1:
		var u := float(i) / float(COLS)
		for j in 2:
			verts.append(Vector2(u * PAGE.x, j * PAGE.y))
			uvs.append(Vector2(u, float(j)))
	for i in COLS:
		var a := i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _page_rect(tex: Texture2D, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.position = pos
	r.size = PAGE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return r

## 一頁的內容：一般的 2D 控制項畫在 SubViewport 裡，再當貼圖用（所以文字、圖都是正常排版，彎曲只發生在貼圖上）
func _make_page(_label: String, kind: String, title: String, body: String, art: String) -> ViewportTexture:
	var vp := SubViewport.new()
	vp.size = Vector2i(PAGE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var paper := ColorRect.new()
	paper.color = Color("#E9DAB5")
	paper.size = PAGE
	vp.add_child(paper)
	var border := ReferenceRect.new()
	border.position = Vector2(14, 14)
	border.size = PAGE - Vector2(28, 28)
	border.border_color = Color("#8A6A2E")
	border.border_width = 2.0
	border.editor_only = false
	vp.add_child(border)
	_vlabel(vp, kind, Vector2(30, 28), Vector2(340, 26), 16, Color("#7A4A12"))
	_vlabel(vp, title, Vector2(30, 56), Vector2(340, 44), 34, Color("#2B1B0E"))
	if art != "" and ResourceLoader.exists(art):
		var tr := TextureRect.new()
		tr.texture = load(art) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(60, 110)
		tr.size = Vector2(280, 250)
		vp.add_child(tr)
	var b := _vlabel(vp, body, Vector2(34, 380 if art != "" else 120), Vector2(332, 140 if art != "" else 380), 19, Color("#2B1B0E"))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return vp.get_texture()

func _vlabel(parent: Node, text: String, pos: Vector2, size: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.5).timeout
	var steps := [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
	for i in steps.size():
		_set_t(steps[i])
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/flip_%d.png" % [dir, i])
	get_tree().quit()
