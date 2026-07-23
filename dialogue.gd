extends Control
## 對話演出 —— 左右立繪位置＋逐字顯示＋點擊推進。
## 用於導師對話（§5.5）、幕次進場與守夜人揭示（§5.2 / §5.4）。
##
## 用法：
##   var d = load("res://dialogue.tscn").instantiate()
##   add_child(d)
##   d.finished.connect(_on_done)
##   d.play([{ "name": "雫", "kanji": "雫", "color": Color("a97bff"),
##             "side": "left", "text": "……" }])
## name 留空 = 旁白模式（無立繪，文字置中）。

signal finished

const INK := Color("efeaff")
const MUTED := Color("9c95bb")
const FAINT := Color("6a6590")
const CHARS_PER_SEC := 46.0

var _lines: Array = []
var _idx := -1
var _typed := 0.0
var _typing := false

var _backdrop: ColorRect
var _portrait: PanelContainer
var _kanji: Label
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _box: PanelContainer
var _row: HBoxContainer
var _spacer_l: Control
var _spacer_r: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	set_process(false)


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.03, 0.02, 0.06, 0.82)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# 立繪列：用左右兩個彈性空白決定立繪靠左或靠右
	_row = HBoxContainer.new()
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row)

	_spacer_l = Control.new()
	_spacer_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_spacer_l)

	_portrait = PanelContainer.new()
	_portrait.custom_minimum_size = Vector2(210, 260)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_END
	_row.add_child(_portrait)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	_portrait.add_child(pv)
	_kanji = Label.new()
	_kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kanji.add_theme_font_size_override("font_size", 104)
	pv.add_child(_kanji)

	_spacer_r = Control.new()
	_spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_spacer_r)

	# 對話框
	_box = PanelContainer.new()
	col.add_child(_box)
	var bm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		bm.add_theme_constant_override("margin_" + s, 22)
	_box.add_child(bm)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bm.add_child(bv)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 19)
	bv.add_child(_name)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 96)
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.add_theme_color_override("default_color", INK)
	bv.add_child(_text)

	var foot := HBoxContainer.new()
	bv.add_child(foot)

	_hint = Label.new()
	_hint.text = "點擊或按空白鍵繼續 ▾"
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", FAINT)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_hint)

	var skip := Button.new()
	skip.text = "跳過（ESC）"
	skip.add_theme_font_size_override("font_size", 12)
	skip.add_theme_color_override("font_color", MUTED)
	skip.add_theme_stylebox_override("normal", _sb(Color("1a1730"), Color("3a3352"), 1, 6))
	skip.add_theme_stylebox_override("hover", _sb(Color("241f3c"), MUTED, 1, 6))
	skip.pressed.connect(_close)
	foot.add_child(skip)


func play(lines: Array) -> void:
	_lines = lines
	_idx = -1
	if _lines.is_empty():
		_close()
		return
	_next()


# ============================================================
func _next() -> void:
	_idx += 1
	if _idx >= _lines.size():
		_close()
		return
	var l: Dictionary = _lines[_idx]
	var speaker: String = l.get("name", "")
	var accent: Color = l.get("color", Color("ff3d81"))

	if speaker == "":
		# 旁白：不顯示立繪
		_portrait.visible = false
		_name.text = ""
		_name.visible = false
	else:
		_portrait.visible = true
		_name.visible = true
		_name.text = speaker
		_name.add_theme_color_override("font_color", accent)
		_kanji.text = l.get("kanji", speaker.substr(0, 1))
		_kanji.add_theme_color_override("font_color", accent)
		_portrait.add_theme_stylebox_override("panel",
			_sb(Color(accent.r * 0.18, accent.g * 0.16, accent.b * 0.22, 0.95), accent, 2, 14))
		# 左右站位
		var on_left: bool = String(l.get("side", "left")) == "left"
		_spacer_l.size_flags_horizontal = 0 if on_left else Control.SIZE_EXPAND_FILL
		_spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on_left else 0

	_box.add_theme_stylebox_override("panel",
		_sb(Color("14111f"), accent if speaker != "" else Color("3a3352"), 2, 14))

	_text.text = "[color=#%s]%s[/color]" % [
		INK.to_html(false) if speaker != "" else "c9c1e6", l.get("text", "")
	]
	_text.visible_characters = 0
	_typed = 0.0
	_typing = true
	_hint.visible = false
	set_process(true)


func _process(delta: float) -> void:
	if not _typing:
		return
	_typed += delta * CHARS_PER_SEC
	_text.visible_characters = int(_typed)
	if _text.visible_ratio >= 1.0:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_hint.visible = true
	set_process(false)


func _advance() -> void:
	if _typing:
		_finish_typing()       # 第一次點擊：立刻顯示完整句子
	else:
		_next()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close()                       # ESC：整段跳過
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance()
			get_viewport().set_input_as_handled()


func _close() -> void:
	set_process(false)
	finished.emit()
	queue_free()


func _sb(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	return s
