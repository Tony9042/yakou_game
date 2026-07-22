extends Control
## 標題畫面 / 主選單。繼續（載入存檔）、新的一夜（重新開始）、離開。

const NIGHT := Color("0c0a15")
const INK := Color("efeaff")
const MUTED := Color("9c95bb")
const FAINT := Color("6a6590")
const ROSE := Color("ff3d81")
const CYAN := Color("38e1e8")
const VIOLET := Color("a97bff")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)

	var cn := Label.new()
	cn.text = "夜行"
	cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cn.add_theme_font_size_override("font_size", 96)
	cn.add_theme_color_override("font_color", ROSE)
	v.add_child(cn)

	var en := Label.new()
	en.text = "Y A K O U"
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.add_theme_font_size_override("font_size", 24)
	en.add_theme_color_override("font_color", MUTED)
	v.add_child(en)

	var tag := Label.new()
	tag.text = "都會奇幻 · 霓虹 · 魂魄 Roguelite"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", FAINT)
	v.add_child(tag)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	v.add_child(gap)

	if SaveSystem.has_save():
		v.add_child(_menu_button("繼續", CYAN, _on_continue))
	v.add_child(_menu_button("新的一夜", ROSE, _on_new_game))
	v.add_child(_menu_button("離開遊戲", FAINT, _on_quit))


func _menu_button(text: String, accent: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 50)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_stylebox_override("normal", _box(Color("17141f"), accent, 1, 10))
	b.add_theme_stylebox_override("hover", _box(Color("221c30"), accent, 2, 10))
	b.add_theme_stylebox_override("pressed", _box(Color("120f1a"), accent, 2, 10))
	b.pressed.connect(cb)
	return b


func _on_continue() -> void:
	SaveSystem.load_game()
	get_tree().change_scene_to_file("res://hall.tscn")


func _on_new_game() -> void:
	SaveSystem.new_game()
	get_tree().change_scene_to_file("res://hall.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	return s
