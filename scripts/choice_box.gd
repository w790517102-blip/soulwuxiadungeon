# 小知的 ChoiceBox 開發規劃 - 第一步 🌱

# ✅ 專案目標：建立一個簡單、獨立的 ChoiceBox，可以被任何 NPC 呼叫，彈出選項框，並依選項執行 callback
# ✅ 約定：不動 DialogManager、保留原有結構，讓 NPC 可以自然擴充對話互動

# ✅ 這次會完成：
# - 新增 ChoiceBox.gd 腳本（掛在 VBoxContainer）
# - 支援新增選項、點擊後觸發 callback、hover 聚焦
# - 提供 show_choices() / hide_choices() 方法

# 🧱 你只需要：
# - 在 UI 上 CanvasLayer 下加入一個 VBoxContainer 命名為 `ChoiceBox`
# - 放在 DialogManager 的旁邊或下一層（但不包進 DialogBox 裡）
# - 將這段 Script 掛在 ChoiceBox 節點上，剩下交給我處理 😌

# 💡 實作腳本如下（會補上預設樣式、支援 hover 與 focus）
extends VBoxContainer

signal choice_selected

func clear():
	for child in get_children():
		child.queue_free()

func add_option(text: String, callback: Callable):
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(callback)
	btn.pressed.connect(func():
		emit_signal("choice_selected")
	)
	btn.mouse_entered.connect(func(): btn.grab_focus())
	btn.add_theme_color_override("font_color_hover", Color.YELLOW)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(btn)

func show_choices():
	visible = true
	grab_first_focus()

func hide_choices():
	visible = false
	clear()

func grab_first_focus():
	if get_child_count() > 0:
		get_child(0).grab_focus()
