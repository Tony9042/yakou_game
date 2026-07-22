extends Control
## 橫丁 · 日間養成畫面 — 花殘留魂魄投流派點（§3），與夜行節點地圖組成核心迴圈。
## 混搭兩條流派達門檻會自動解鎖跨流派複合技。UI 全程以程式建立。

const NIGHT := Color("14121f")
const INK := Color("efeaff")
const MUTED := Color("9c95bb")
const FAINT := Color("6a6590")
const ROSE := Color("ff3d81")
const CYAN := Color("38e1e8")
const AMBER := Color("ffb45a")
const VIOLET := Color("a97bff")

const SCHOOL_ORDER := ["blade", "ward", "rider", "support"]
const RESPEC_COST := 2

var _school_col := {}
var _status: RichTextLabel
var _cols_row: HBoxContainer
var _event := ""


func _ready() -> void:
	_school_col = {"blade": ROSE, "ward": AMBER, "rider": CYAN, "support": VIOLET}
	# 正常流程由標題畫面的新遊戲／繼續發放資源；此處僅為「直接執行 hall.tscn」
	# 的開發便利：全新且無存檔時給一點起始魂魄，不會蓋掉載入的進度。
	if SoulSystem.residual_souls == 0 and TalentSystem.invested_schools().is_empty() and not SaveSystem.has_save():
		SoulSystem.residual_souls = 10
	if not TalentSystem.composite_unlocked.is_connected(_on_composite):
		TalentSystem.composite_unlocked.connect(_on_composite)
	_build_ui()
	_refresh()


func _on_composite(cid: String) -> void:
	_event = "★ 解鎖複合技：%s" % cid
	_refresh()


# ============================================================
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 34)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var title := Label.new()
	title.text = "橫丁 · 日間"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "花殘留魂魄投流派點。同時投兩條流派達門檻，會自動解鎖跨流派複合技。"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", MUTED)
	col.add_child(sub)

	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.add_theme_font_size_override("normal_font_size", 16)
	col.add_child(_status)

	_cols_row = HBoxContainer.new()
	_cols_row.add_theme_constant_override("separation", 14)
	_cols_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_cols_row)

	var go := Button.new()
	go.text = "出發夜行  →"
	go.custom_minimum_size = Vector2(0, 48)
	go.add_theme_font_size_override("font_size", 18)
	go.add_theme_color_override("font_color", INK)
	go.add_theme_color_override("font_hover_color", ROSE)
	go.add_theme_stylebox_override("normal", _box(Color("2a1c28"), ROSE, 1, 10))
	go.add_theme_stylebox_override("hover", _box(Color("3a2436"), ROSE, 2, 10))
	go.add_theme_stylebox_override("pressed", _box(Color("241620"), ROSE, 2, 10))
	go.pressed.connect(_go_night)
	col.add_child(go)


func _refresh() -> void:
	# 狀態列
	var auras := TalentSystem.active_auras()
	var comps := TalentSystem.unlocked_composites()
	var aura_txt := "—" if auras.is_empty() else ", ".join(auras)
	var comp_txt := "—" if comps.is_empty() else ", ".join(comps)
	var line := "[color=#9c95bb]殘留魂魄[/color] [color=#38e1e8]%d[/color]    [color=#9c95bb]隊伍光環[/color] [color=#ffb45a]%s[/color]    [color=#9c95bb]複合技[/color] [color=#a97bff]%s[/color]" % [
		SoulSystem.residual_souls, aura_txt, comp_txt
	]
	# 主線進度（§5.4）
	if StorySystem.finished:
		line += "\n[color=#6a6590]主線[/color] [color=#38e1e8]已走完全部街區 · 結局：%s[/color]" % StorySystem.ending().name
	else:
		line += "\n[color=#6a6590]今夜將前往[/color] [color=#ffb45a]%s[/color]" % StorySystem.act_title()
	if _event != "":
		line += "\n[color=#ff3d81]%s[/color]" % _event
	_status.text = line

	# 流派欄
	_clear(_cols_row)
	for sid in SCHOOL_ORDER:
		_cols_row.add_child(_make_school_column(sid))


func _make_school_column(sid: String) -> Control:
	var accent: Color = _school_col[sid]
	var meta: Dictionary = TalentSystem.SCHOOLS[sid]
	var pts: int = TalentSystem.points_in(sid)
	var aura: bool = TalentSystem.aura_ready(sid)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("1a1730"), accent if aura else FAINT, 2 if aura else 1, 12))

	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 14)
	panel.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pad.add_child(v)

	var head := Label.new()
	head.text = "%s　%s" % [meta.name, meta.mentor]
	head.add_theme_font_size_override("font_size", 19)
	head.add_theme_color_override("font_color", accent)
	v.add_child(head)

	var info := Label.new()
	info.text = "%s ·  %d 點%s" % [meta.role, pts, "  ✦光環" if aura else ""]
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", MUTED if not aura else accent)
	v.add_child(info)

	# 節點按鈕
	var nodes: Dictionary = TalentSystem.nodes[sid]
	for node_name in nodes:
		var nd: Dictionary = nodes[node_name]
		v.add_child(_make_node_button(sid, node_name, nd, accent))

	# 導師對話（§5.5）：投該流派愈深，導師透露愈多守夜人的過去
	var quote := RichTextLabel.new()
	quote.bbcode_enabled = true
	quote.fit_content = true
	quote.scroll_active = false
	quote.add_theme_font_size_override("normal_font_size", 12)
	quote.custom_minimum_size = Vector2(0, 54)
	var line: String = StorySystem.mentor_line(sid)
	if line == "":
		quote.text = "[color=#4b4766]（投點後，%s 會與你說話）[/color]" % meta.mentor
	else:
		quote.text = "[color=#b9b1d6]%s[/color]" % line
	v.add_child(quote)

	# 重置
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	v.add_child(sp)
	var respec := Button.new()
	respec.text = "重置（花 %d）" % RESPEC_COST
	respec.disabled = pts == 0 or SoulSystem.residual_souls < RESPEC_COST
	respec.add_theme_font_size_override("font_size", 12)
	respec.add_theme_color_override("font_color", MUTED)
	respec.add_theme_stylebox_override("normal", _box(Color("161324"), FAINT, 1, 7))
	respec.add_theme_stylebox_override("hover", _box(Color("201b30"), MUTED, 1, 7))
	respec.add_theme_stylebox_override("disabled", _box(Color("131120"), Color("2a2740"), 1, 7))
	respec.pressed.connect(_on_respec.bind(sid))
	v.add_child(respec)

	return panel


func _make_node_button(sid: String, node_name: String, nd: Dictionary, accent: Color) -> Button:
	var b := Button.new()
	var unlocked: bool = nd.unlocked
	var cost: int = nd.cost
	var affordable: bool = SoulSystem.residual_souls >= cost
	b.text = ("✓ " if unlocked else "") + "%s　花%d" % [node_name, cost]
	b.tooltip_text = nd.desc
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 14)
	b.disabled = unlocked or not affordable
	if unlocked:
		b.add_theme_color_override("font_color", accent)
		b.add_theme_color_override("font_disabled_color", accent)
		b.add_theme_stylebox_override("disabled", _box(Color("241d33"), accent, 1, 8))
	else:
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", accent)
		b.add_theme_color_override("font_disabled_color", FAINT)
		b.add_theme_stylebox_override("normal", _box(Color("1e1a2e"), FAINT, 1, 8))
		b.add_theme_stylebox_override("hover", _box(Color("262038"), accent, 1, 8))
		b.add_theme_stylebox_override("disabled", _box(Color("15121f"), Color("2a2740"), 1, 8))
		b.pressed.connect(_on_unlock.bind(sid, node_name))
	return b


# ============================================================
func _on_unlock(sid: String, node_name: String) -> void:
	_event = ""                              # 先清舊事件；若本次投點觸發複合技，
	TalentSystem.unlock_node(sid, node_name) # _on_composite 會在此期間重設 _event
	SaveSystem.save_game()
	_refresh()


func _on_respec(sid: String) -> void:
	TalentSystem.respec(sid, RESPEC_COST)
	_event = ""
	SaveSystem.save_game()
	_refresh()


func _go_night() -> void:
	SaveSystem.save_game()
	get_tree().change_scene_to_file("res://night_map.tscn")


# ---- 小工具 ----
func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	return s


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
