extends Node
# 版面快照工具：開啟系統選單，逐一切換每個分頁，記錄所有可見 Control 的位置與大小到 JSON。
# 用途：改選單外觀（皮膚、背景）前後各跑一次比對，確認「沒有任何元件位置或大小被改動」。
# 用法：Godot --path . res://tools/menu_layout_snapshot.tscn -- <輸出 json 路徑>
const TABS := ["TabStatus", "TabItem", "TabEquip", "TabSkill", "TabParty", "TabLore", "TabQuest", "TabSystem"]

func _collect(node: Node, out: Dictionary, prefix: String) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var c := node as Control
		var r := c.get_global_rect()
		out[prefix + str(c.get_path()).get_slice("SystemMenu", 1)] = [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]
	for child in node.get_children():
		_collect(child, out, prefix)

func _ready() -> void:
	var out_path := "user://menu_layout.json"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	var gr = load("res://scenes/game_root.tscn").instantiate()
	gr.name = "GameRoot"
	get_tree().root.add_child.call_deferred(gr)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	gr.change_map_to("res://scenes/test_room_left.tscn")
	await get_tree().create_timer(2.0).timeout
	gr.get_node("LiuYu").can_move = true
	var ctl = get_tree().root.get_node("SystemMenu")
	await ctl._open_system_menu()
	var menu = ctl.system_menu_instance
	var all := {}
	for t in TABS:
		var b = menu.get_node_or_null("CustomTabBar/" + t)
		if b == null:
			continue
		b.emit_signal("pressed")
		await get_tree().create_timer(0.5).timeout
		var snap := {}
		_collect(menu, snap, t + "|")
		all.merge(snap)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(all))
	f.close()
	print("LAYOUT saved ", all.size(), " controls -> ", out_path)
	get_tree().quit()
