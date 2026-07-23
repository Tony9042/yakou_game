extends Control
## 節點地圖畫面 — 可玩原型（Phase 1）。
## 把 RunManager 生成的一夜路線做成可點擊 UI：橫丁 → 逐節點前進 →
## 深夜案件 → 黎明結算，過程中串接 SoulSystem（鎮壓/收容）與本輪身分。
## UI 全程以程式建立，方便迭代；美術/動畫留待後續。

# ---- 調色盤（對應企劃霓虹主題）----
const NIGHT := Color("14121f")
const PANEL := Color("1c1930")
const INK := Color("efeaff")
const MUTED := Color("9c95bb")
const FAINT := Color("6a6590")
const ROSE := Color("ff3d81")
const CYAN := Color("38e1e8")
const AMBER := Color("ffb45a")
const VIOLET := Color("a97bff")

const SOUL_NAMES := ["提灯付喪神", "傘化生", "招牌の主", "自販機禍", "街燈守", "硬幣精", "郵筒翁"]
const SIGHTING_LINES := [
	"牆上斑駁的塗鴉，依稀是孩童的塗鴉——這條巷子曾經有人住。",
	"一隻付喪神縮在拆除告示牌後，牠只是不想被忘記。",
	"你想起了什麼……又像是別人的記憶。",
]

var _msg: RichTextLabel
var _node_row: HBoxContainer
var _action_bar: HBoxContainer
var _status: RichTextLabel
var _identity: RichTextLabel
var _pending := {}          # 當前遭遇待處理的付喪神
var _night_hp := 100        # 魂的體力，跨節點保留；戰死即結束一夜
var _combat: Node = null
var _ui_root: MarginContainer


func _ready() -> void:
	_build_ui()
	if not RunManager.night_ended.is_connected(_on_night_ended):
		RunManager.night_ended.connect(_on_night_ended)
	_start_night()


# ============================================================
#  流程
# ============================================================
func _start_night() -> void:
	_pending = {}
	_night_hp = 100
	RunManager.generate_night()          # 隨機種子＋隨機依代
	_log_clear()
	var a := StorySystem.current_act()
	_log("[color=#ffb45a]— %s —[/color]" % StorySystem.act_title())
	_log("[color=#c9c1e6]%s[/color]" % a.intro)
	_log("\n魂附上了「[color=#a97bff]%s[/color]」。今夜的路線已在眼前。" % RunManager.current_vessel)
	_refresh_nodes()
	_refresh_status()
	_set_actions([["出發夜行", _advance, ROSE]])
	if StorySystem.consume_act_intro():               # 同一幕只演一次（死亡重跑不重播）
		_play_dialogue(StorySystem.narration(a.intro))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_open_menu()
		get_viewport().set_input_as_handled()


func _open_menu() -> void:
	if get_tree().paused:
		return
	var m: Control = load("res://system_menu.tscn").instantiate()
	# 夜行中多一個放棄選項；戰鬥中不提供，避免中途脫離戰鬥的怪狀態
	if RunManager.run_active and _combat == null:
		m.extra = [{"text": "放棄今夜（視為戰死）", "color": ROSE, "cb": _abandon_night}]
	add_child(m)


func _abandon_night() -> void:
	_log("\n[color=#ff6b6b]你選擇提前退出這一夜。[/color]")
	RunManager.end_run(false)


## 以對話演出播放一段內容；播完自動移除。
func _play_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	var d: Control = load("res://dialogue.tscn").instantiate()
	add_child(d)
	d.play(lines)


func _advance() -> void:
	var t: int = RunManager.advance()
	if t == RunManager.NodeType.NONE:
		return                            # 已抵達終點：由 night_ended 接手
	_refresh_nodes()
	_present_node(t)


func _present_node(t: int) -> void:
	var info := _node_info(t)
	match t:
		RunManager.NodeType.ENCOUNTER, RunManager.NodeType.CONTRACT:
			var is_contract := t == RunManager.NodeType.CONTRACT
			var q := (randi() % 2) + (2 if is_contract else 1)   # 契約品質較高
			_pending = {"id": SOUL_NAMES[randi() % SOUL_NAMES.size()], "q": q}
			_log("\n[color=#ff3d81]▶ %s[/color]：一隻「%s」擋住去路（品質 %d）。" % [info.name, _pending.id, q])
			_set_actions([["應戰", _start_combat.bind(t), ROSE]])
		RunManager.NodeType.BLACK_MARKET:
			_log("\n[color=#38e1e8]▶ 黑市[/color]：暗處有人兜售道具，也能在此稍作休整。")
			var acts: Array = []
			if _night_hp < 100:
				acts.append(["休整（回復 25 魂）", _on_rest, CYAN])
			acts.append(["離開黑市", _advance, MUTED])
			_set_actions(acts)
		RunManager.NodeType.SIGHTING:
			_log("\n[color=#ffb45a]▶ 目擊[/color]：%s" % StorySystem.next_sighting())
			_set_actions([["繼續前行", _advance, AMBER]])
		RunManager.NodeType.BOSS:
			_pending = {"id": "「拆」之魂", "q": 4}
			if StorySystem.is_final_act():
				_log("\n[color=#ff3d81]☠ 深夜案件[/color]：由拆除令與遺忘凝成的「拆」之魂，擋在天台盡頭。")
				_log("[color=#9c95bb]抹除，是溫柔收容的完全反面——牠是你的鏡像。[/color]")
			else:
				_log("\n[color=#ff3d81]☠ 深夜案件[/color]：抹除一切的「拆」之魂現身了。")
			_set_actions([["決戰", _start_combat.bind(t), ROSE]])


func _on_rest() -> void:
	_night_hp = mini(100, _night_hp + 25)
	_log("你在暗巷角落喘了口氣。（魂 %d/100）" % _night_hp)
	_refresh_status()
	_set_actions([["離開黑市", _advance, MUTED]])


# ============================================================
#  戰鬥（以子場景嵌入，避免切場景導致本夜路線重新生成）
# ============================================================
func _start_combat(t: int) -> void:
	var count := 2
	var hp := 60
	var types: Array = ["chaser", "chaser"]
	match t:
		RunManager.NodeType.ENCOUNTER:
			# 一般遭遇隨機挑一種組合，讓每場感覺不同
			types = [["chaser", "chaser"], ["chaser", "ranged"], ["charger", "chaser"]].pick_random()
			count = types.size()
		RunManager.NodeType.CONTRACT:
			types = ["chaser", "ranged", "charger"]
			count = 3
			hp = 78
		RunManager.NodeType.BOSS:
			# 拆之魂＋兩隻護衛，愈後期的幕護衛愈硬
			types = ["boss", "ranged", "charger"]
			count = 3
			hp = 150

	var scene: PackedScene = load("res://combat.tscn")
	_combat = scene.instantiate()
	_combat.embedded = true
	_combat.cfg_enemy_count = count
	_combat.cfg_enemy_hp = hp
	_combat.cfg_types = types
	_combat.cfg_start_hp = _night_hp
	_combat.cfg_vessel = maxi(0, RunManager.VESSELS.find(RunManager.current_vessel))
	_combat.finished.connect(_on_combat_finished)
	_ui_root.visible = false          # 收起地圖 UI，讓戰鬥畫面獨佔
	add_child(_combat)


func _on_combat_finished(won: bool) -> void:
	if is_instance_valid(_combat):
		_night_hp = maxi(0, int(_combat.player_hp))
		_combat.queue_free()
	_combat = null
	_ui_root.visible = true
	_refresh_status()

	if not won:
		_log("\n[color=#ff6b6b]依代在夜裡毀去。[/color]")
		RunManager.end_run(false)     # 戰死：結算走半數轉換率
		return

	_log("「%s」已伏。（魂 %d/100）" % [_pending.id, _night_hp])
	_log("[color=#9c95bb]鎮壓＝本輪增益；收容＝納入魂魄囊、日後可成夥伴。[/color]")
	_set_actions([
		["鎮壓", _on_suppress, ROSE],
		["收容", _on_contain, CYAN],
	])


func _on_suppress() -> void:
	SoulSystem.suppress_soul(_pending.id, {})
	StorySystem.record_choice(false)
	_log("你[color=#ff3d81]鎮壓[/color]了「%s」，化為本輪戰鬥增益。" % _pending.id)
	_after_action()


func _on_contain() -> void:
	var ok: bool = SoulSystem.contain_soul(_pending.id, _pending.q)
	if ok:
		StorySystem.record_choice(true)
		_log("你[color=#38e1e8]收容[/color]了「%s」，納入魂魄囊。" % _pending.id)
	else:
		_log("[color=#ff6b6b]魂魄囊已滿（%d/%d），收容失敗！[/color]" % [SoulSystem.satchel.size(), SoulSystem.MAX_SATCHEL_CAPACITY])
	_after_action()


func _after_action() -> void:
	_pending = {}
	_refresh_status()
	_set_actions([["前進", _advance, ROSE]])


func _on_night_ended(success: bool, gained: int) -> void:
	SaveSystem.save_game()          # 結算後（殘留魂魄已變動）立即存檔
	_refresh_nodes()
	_refresh_status()
	var head := "黎明撤離" if success else "戰死"
	_log("\n[color=#ffb45a]— %s —[/color]" % head)
	_log("本夜收容轉為殘留魂魄 [color=#38e1e8]+%d[/color]（已保留供橫丁養成）。" % gained)
	_log("[color=#9c95bb]魂魄囊已結算清空；殘留魂魄與流派永久保留。[/color]")

	if success:
		var was_final := StorySystem.is_final_act()
		var outro: String = StorySystem.current_act().outro
		_log("\n[color=#c9c1e6]%s[/color]" % outro)
		var reveal := StorySystem.advance_act()      # 推進幕次，回傳本次揭示

		# 收場與揭示以對話演出呈現，日誌同步保留一份可回顧
		var scene_lines: Array = StorySystem.narration(outro)
		if reveal != "":
			_log("\n[color=#ffb45a]%s[/color]" % reveal)
			scene_lines.append_array(StorySystem.narration(reveal))
		if was_final:
			var e := StorySystem.ending()
			_log("\n[color=#38e1e8]— 結局：%s —[/color]" % e.name)
			_log("[color=#c9c1e6]%s[/color]" % e.text)
			scene_lines.append({"name": "", "text": "— 結局：%s —" % e.name})
			scene_lines.append_array(StorySystem.narration(e.text))
		else:
			_log("\n[color=#6a6590]下一夜：%s[/color]" % StorySystem.act_title())
		_play_dialogue(scene_lines)
	else:
		_log("[color=#6a6590]這一夜沒能走完，街區的拆除仍在繼續。[/color]")

	SaveSystem.save_game()          # 幕次／結局傾向也要存
	_set_actions([["返回橫丁", _return_to_hall, VIOLET]])


func _return_to_hall() -> void:
	get_tree().change_scene_to_file("res://hall.tscn")


# ============================================================
#  UI 建構
# ============================================================
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	add_child(margin)
	_ui_root = margin

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	# 標題
	var head := HBoxContainer.new()
	col.add_child(head)

	var title := Label.new()
	title.text = "夜行 · 今夜路線"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var menu_btn := Button.new()
	menu_btn.text = "≡ 選單（ESC）"
	menu_btn.add_theme_font_size_override("font_size", 13)
	menu_btn.add_theme_color_override("font_color", MUTED)
	menu_btn.add_theme_stylebox_override("normal", _box(Color("17141f"), Color("3a3352"), 1, 8))
	menu_btn.add_theme_stylebox_override("hover", _box(Color("221c30"), MUTED, 1, 8))
	menu_btn.pressed.connect(_open_menu)
	head.add_child(menu_btn)

	# 狀態列
	_status = _make_rich(15)
	col.add_child(_status)

	# 節點列
	var nodes_wrap := PanelContainer.new()
	nodes_wrap.add_theme_stylebox_override("panel", _box(PANEL, FAINT, 1, 14))
	col.add_child(nodes_wrap)
	var nm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		nm.add_theme_constant_override("margin_" + side, 14)
	nodes_wrap.add_child(nm)
	_node_row = HBoxContainer.new()
	_node_row.add_theme_constant_override("separation", 10)
	nm.add_child(_node_row)

	# 訊息日誌（可捲動）
	var log_wrap := PanelContainer.new()
	log_wrap.add_theme_stylebox_override("panel", _box(Color("110f1c"), FAINT, 1, 14))
	log_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(log_wrap)
	var lm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		lm.add_theme_constant_override("margin_" + side, 16)
	log_wrap.add_child(lm)
	_msg = _make_rich(15)
	# 關鍵：fit_content 會讓日誌隨內容無限長高，把下方按鈕擠出視窗而點不到。
	# 關掉它並開啟捲動，日誌就會固定在容器內、自動捲到最新一行。
	_msg.fit_content = false
	_msg.scroll_active = true
	_msg.scroll_following = true
	_msg.custom_minimum_size = Vector2(0, 150)
	_msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lm.add_child(_msg)

	# 本輪身分
	_identity = _make_rich(14)
	col.add_child(_identity)

	# 行動列
	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 12)
	col.add_child(_action_bar)


func _refresh_nodes() -> void:
	_clear(_node_row)
	_node_row.add_child(_make_card("橫丁", AMBER, RunManager.current_index < 0, false))
	for i in RunManager.current_map.size():
		var t: int = RunManager.current_map[i]
		var info := _node_info(t)
		var is_current := i == RunManager.current_index
		var is_past := i < RunManager.current_index
		_node_row.add_child(_make_card(info.name, info.col, is_current, is_past))


func _make_card(card_name: String, col: Color, current: bool, past: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(102, 62)
	var border_col := col if current else FAINT
	var border_w := 2 if current else 1
	p.add_theme_stylebox_override("panel", _box(PANEL if current else Color("161324"), border_col, border_w, 10))
	if past:
		p.modulate = Color(1, 1, 1, 0.4)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var dot := Label.new()
	dot.text = "●"
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.add_theme_color_override("font_color", col)
	dot.add_theme_font_size_override("font_size", 12)
	v.add_child(dot)
	var l := Label.new()
	l.text = card_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", INK if current else MUTED)
	l.add_theme_font_size_override("font_size", 14)
	v.add_child(l)
	return p


func _set_actions(actions: Array) -> void:
	_clear(_action_bar)
	for a in actions:
		var b := Button.new()
		b.text = a[0]
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 16)
		var accent: Color = a[2]
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", accent)
		b.add_theme_stylebox_override("normal", _box(Color("221d33"), accent, 1, 9))
		b.add_theme_stylebox_override("hover", _box(Color("2c2545"), accent, 2, 9))
		b.add_theme_stylebox_override("pressed", _box(Color("1a1628"), accent, 2, 9))
		b.pressed.connect(a[1])
		_action_bar.add_child(b)


func _refresh_status() -> void:
	_status.text = "[color=#9c95bb]魂[/color] [color=#ff3d81]%d/100[/color]    [color=#9c95bb]殘留魂魄[/color] [color=#38e1e8]%d[/color]    [color=#9c95bb]魂魄囊[/color] [color=#ff3d81]%d/%d[/color]    [color=#9c95bb]依代[/color] [color=#a97bff]%s[/color]" % [
		_night_hp, SoulSystem.residual_souls, SoulSystem.satchel.size(), SoulSystem.MAX_SATCHEL_CAPACITY, RunManager.current_vessel
	]
	var id := RunManager.run_identity()
	var schools := "—" if id.schools.is_empty() else ", ".join(id.schools)
	var souls := "—" if id.contained_souls.is_empty() else ", ".join(id.contained_souls)
	var comps := "—" if id.composites.is_empty() else ", ".join(id.composites)
	_identity.text = "[color=#6a6590]本輪身分[/color]　流派：[color=#38e1e8]%s[/color]　複合技：[color=#ffb45a]%s[/color]　收容：[color=#ff3d81]%s[/color]" % [schools, comps, souls]


# ---- 小工具 ----
func _node_info(t: int) -> Dictionary:
	match t:
		RunManager.NodeType.ENCOUNTER: return {"name": "遭遇", "col": ROSE}
		RunManager.NodeType.BLACK_MARKET: return {"name": "黑市", "col": CYAN}
		RunManager.NodeType.SIGHTING: return {"name": "目擊", "col": AMBER}
		RunManager.NodeType.CONTRACT: return {"name": "契約", "col": VIOLET}
		RunManager.NodeType.BOSS: return {"name": "深夜案件", "col": ROSE}
	return {"name": "?", "col": MUTED}


func _make_rich(font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_color_override("default_color", MUTED)
	return r


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


func _log_clear() -> void:
	if _msg:
		_msg.text = ""


func _log(line: String) -> void:
	if _msg:
		_msg.append_text(line + "\n")
