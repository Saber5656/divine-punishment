class_name GameUi
extends RefCounted


static func theme() -> Theme:
	var result := Theme.new()
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Hiragino Mincho ProN", "Yu Mincho", "Noto Serif CJK JP", "serif"])
	var font: Font = system_font
	if ResourceLoader.exists("res://assets/fonts/NotoSerifJP.ttf"):
		var variation := FontVariation.new()
		variation.base_font = load("res://assets/fonts/NotoSerifJP.ttf") as Font
		variation.variation_opentype = {"wght": 450.0}
		font = variation
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", Color("e7dfcb"))
	result.set_color("font_color", "Button", Color("e7dfcb"))
	result.set_constant("separation", "VBoxContainer", 16)
	result.set_constant("separation", "HBoxContainer", 16)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("8e352c") if state == "hover" or state == "pressed" else Color("202421")
		style.border_color = Color("d2b582") if state == "focus" else Color("776b57")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		result.set_stylebox(state, "Button", style)
	return result
