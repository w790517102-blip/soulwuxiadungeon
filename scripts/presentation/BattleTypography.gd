extends RefCounted
## One font contract for both battle presentations, including popup Windows.
const FONT = preload("res://assets/fonts/UIFontKaiti.tres")

static func apply(root: Node) -> void:
	if root is Control or root is Window:
		root.add_theme_font_override("font", FONT)
		if root is RichTextLabel:
			for key in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
				root.add_theme_font_override(key, FONT)
	for child in root.get_children():
		apply(child)
