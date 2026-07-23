extends Control
## 系統選單（暫停）。開啟時暫停整棵樹，因此戰鬥中也能安全叫出。
##
## 用法：
##   var m = load("res://system_menu.tscn").instantiate()
##   m.extra = [{"text": "放棄今夜", "color": Color("ff3d81"), "cb": _on_abandon}]
##   add_child(m)

signal closed

const INK := Color("efeaff")
const MUTED := Color("9c95bb")
const FAINT := Color("6a6590")
const ROSE := Color("ff3d81")
const CYAN := Color("38e1e8")
const VIOLET := Color("a97bff")

## 額外選項：[{text, color, cb}]，由呼叫端依情境提供（例如夜行中的「放棄今夜」）。
var extra: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # 暫停中仍要能操作
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_tree().paused = true


func _build() -> void:
	var bd := ColorRect.new()
	bd.color = Color(0.03, 0.02, 0.06, 0.86)
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bd)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)

	var title := Label.new()
	title.text = "選單"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	v.add_child(title)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	v.add_child(gap)

	v.add_child(_btn("繼續遊戲", CYAN, _resume))
	for e in extra:
		v.add_child(_btn(e.text, e.get("color", VIOLET), _run_extra.bind(e.cb)))
	v.add_child(_btn("存檔並回標題", VIOLET, _to_title))
	v.add_child(_btn("存檔並離開遊戲", ROSE, _save_quit))

	var note := Label.new()
	note.text = "進度會自動存檔（橫丁投點、出發前、每夜結算後）"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", FAINT)
	v.add_child(note)


func _btn(text: String, accent: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 46)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_stylebox_override("normal", _sb(Color("17141f"), accent, 1, 9))
	b.add_theme_stylebox_override("hover", _sb(Color("221c30"), accent, 2, 9))
	b.add_theme_stylebox_override("pressed", _sb(Color("120f1a"), accent, 2, 9))
	b.pressed.connect(cb)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_resume()
		get_viewport().set_input_as_handled()


func _resume() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


## 執行呼叫端提供的動作前，先解除暫停並關閉選單。
func _run_extra(cb: Callable) -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
	cb.call()


func _to_title() -> void:
	SaveSystem.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://title.tscn")


func _save_quit() -> void:
	SaveSystem.save_game()
	get_tree().paused = false
	get_tree().quit()


func _sb(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	return s
