extends Node2D
## 戰鬥手感原型（Phase 1 核心目標）。
## 3/4 斜俯視動作戰鬥：移動、疾走（無敵幀）、揮砍（扇形判定＋擊退＋頓幀）。
## 目前為獨立測試場景，手感調整完成後再接進節點地圖的「遭遇」。
##
## 操作：WASD／方向鍵 移動　J／空白 揮砍　K／Shift 疾走　1/2/3 換依代　R 重來
## 不使用 InputMap，直接讀鍵盤，避免更動專案設定。

# ---- 手感參數（想調手感就改這裡）----
const SPEED := 335.0
const ACCEL := 2900.0
const FRICTION := 2200.0

const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const DASH_CD := 0.55

const ATK_WINDUP := 0.05      # 起手
const ATK_ACTIVE := 0.10      # 判定生效
const ATK_RECOVER := 0.17     # 收招
const ATK_MOVE_MULT := 0.32   # 揮砍中的移動衰減
const ATK_RANGE := 132.0
const ATK_ARC := 115.0        # 扇形總角度（度）
const ATK_DAMAGE := 26
const ATK_KNOCKBACK := 460.0
const ATK_LUNGE := 430.0      # 揮砍瞬間向前墊步，大幅增加打擊感
const HITSTOP := 0.06         # 命中頓幀，手感關鍵
const SHAKE_MAG := 13.0       # 命中震動強度

const ENEMY_SPEED := 118.0
const ENEMY_HP := 70
const ENEMY_TOUCH_DMG := 12
const ENEMY_TOUCH_CD := 0.9
const ENEMY_RADIUS := 24.0
const PLAYER_RADIUS := 21.0
const PLAYER_MAX_HP := 100
const INVULN_AFTER_HIT := 0.5

## 角色整體放大倍率——角色太小時細節讀不出來，這是外觀辨識度的關鍵。
const VISUAL_SCALE := 1.6

# ---- 配色 ----
const NIGHT := Color("14121f")
const ROSE := Color("ff3d81")
const VIOLET := Color("a97bff")
const CYAN := Color("38e1e8")
const INK := Color("efeaff")
const MUTED := Color("9c95bb")

## 三連段：第三段更重、更廣、更頓。
const COMBO_DMG := [1.0, 1.05, 1.6]
const COMBO_ARC := [1.0, 1.0, 1.35]
const COMBO_LUNGE := [430.0, 450.0, 540.0]
const COMBO_WINDOW := 0.55        # 這段時間內再按 J 才接得上下一段

## 流派技能 —— 對應 TalentSystem 的天賦節點，投點後才可使用（§3.2）。
## 獨立執行 combat.tscn 時全部解鎖，方便單獨測試。
const SKILLS := [
	{"key": KEY_U, "label": "U", "school": "blade",   "node": "拔刀", "name": "拔刀",   "cd": 4.0},
	{"key": KEY_I, "label": "I", "school": "rider",   "node": "突進", "name": "突進斬", "cd": 3.0},
	{"key": KEY_O, "label": "O", "school": "ward",    "node": "封印", "name": "封印陣", "cd": 7.0},
	{"key": KEY_P, "label": "P", "school": "support", "node": "馴養", "name": "修復",   "cd": 10.0},
]

const SOUL_NAMES := ["提灯付喪神", "傘化生", "招牌の主"]

## 依代（軀殼）外觀預設 —— §3.4 的「可換客製層」。
## 用來驗證：3/4 斜俯視下，換依代能不能一眼看出差異。
const VESSEL_PRESETS := [
	{
		"name": "破傘之骸", "coat": "8e2350", "torso": "ff3d81", "scarf": "38e1e8",
		"hair": "241a2e", "blade": "dfe6ff", "blade_len": 50.0, "blade_w": 3.0, "width": 1.0,
	},
	{
		"name": "廢棄自販機", "coat": "1d4f66", "torso": "38e1e8", "scarf": "ffb45a",
		"hair": "3a2a12", "blade": "ffb45a", "blade_len": 40.0, "blade_w": 7.0, "width": 1.25,
	},
	{
		"name": "斷線街燈", "coat": "462f7d", "torso": "a97bff", "scarf": "fff0a8",
		"hair": "e8e4f5", "blade": "a97bff", "blade_len": 64.0, "blade_w": 2.0, "width": 0.85,
	},
]

## 嵌入模式設定 —— 由節點地圖在 instantiate 後、add_child 前設定。
signal finished(won: bool)
var embedded := false            # true：作為子場景嵌入，結束時發 finished 而非顯示重來
var cfg_enemy_count := 3
var cfg_enemy_hp := ENEMY_HP
var cfg_start_hp := PLAYER_MAX_HP
var cfg_vessel := 0

var player: CharacterBody2D
var swing: Polygon2D
var enemies: Array = []          # [{body, hp, kb:Vector2, flash, touch_cd, fill, vis}]

var facing := Vector2.RIGHT
var player_hp := PLAYER_MAX_HP
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var atk_t := 0.0
var atk_hit_done := false
var combo := 0
var combo_timer := 0.0
var skill_cd := [0.0, 0.0, 0.0, 0.0]
var dash_damage := false
var dash_hit: Array = []
var lunge := 0.0
var face_sign := 1.0
var vessel_idx := 0
var invuln := 0.0
var hitstop := 0.0
var shake := 0.0
var state := "fight"             # fight / win / lose

var arena := Rect2()
var _hp_bar: ProgressBar
var _info: Label
var _skills: RichTextLabel
var _banner: Label
var _actions: HBoxContainer
var _cam: Camera2D


func _ready() -> void:
	vessel_idx = cfg_vessel
	_build_world()
	_build_ui()
	_reset_fight()


# ============================================================
#  建場
# ============================================================
func _build_world() -> void:
	var bglayer := CanvasLayer.new()
	bglayer.layer = -10
	add_child(bglayer)
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bglayer.add_child(bg)

	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()

	player = CharacterBody2D.new()
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var pc := CollisionShape2D.new()
	var pcs := CircleShape2D.new()
	pcs.radius = PLAYER_RADIUS
	pc.shape = pcs
	player.add_child(pc)

	# 揮砍扇形（_build_player_visual 會把它移回最上層）
	swing = _poly(_wedge(ATK_RANGE, ATK_ARC), Color(1, 1, 1, 0.30))
	swing.visible = false
	player.add_child(swing)
	add_child(player)

	_build_player_visual(vessel_idx)


## 依「依代」預設重建角色外觀（§3.4：依代＝可換的客製層）。
## 身體只左右翻面、不旋轉，維持 3/4 視角的外觀辨識度。
func _build_player_visual(idx: int) -> void:
	var p: Dictionary = VESSEL_PRESETS[idx % VESSEL_PRESETS.size()]
	for n in ["Body", "Arm"]:
		if player.has_node(n):
			var old := player.get_node(n)
			player.remove_child(old)
			old.queue_free()

	var w: float = p.width
	var s := VISUAL_SCALE

	# 武器臂（隨面向旋轉）
	var arm := Node2D.new()
	arm.name = "Arm"
	arm.scale = Vector2(s, s)
	var bl: float = p.blade_len
	var bw: float = p.blade_w
	arm.add_child(_poly(PackedVector2Array([
		Vector2(12, -bw), Vector2(bl - 6.0, -bw * 0.7), Vector2(bl, 0),
		Vector2(bl - 6.0, bw * 0.7), Vector2(12, bw)
	]), Color(p.blade)))
	player.add_child(arm)

	# 身體
	var body_v := Node2D.new()
	body_v.name = "Body"
	body_v.scale = Vector2(s, s)
	# 外套／斗篷
	body_v.add_child(_poly(PackedVector2Array([
		Vector2(-11.0 * w, -3), Vector2(11.0 * w, -3), Vector2(8.0 * w, 16), Vector2(-8.0 * w, 16)
	]), Color(p.coat)))
	# 軀幹
	body_v.add_child(_poly(PackedVector2Array([
		Vector2(-8.0 * w, -4), Vector2(8.0 * w, -4), Vector2(6.0 * w, 12), Vector2(-6.0 * w, 12)
	]), Color(p.torso)))
	# 圍巾（霓虹點綴）
	body_v.add_child(_poly(PackedVector2Array([
		Vector2(-8.0 * w, -6), Vector2(8.0 * w, -6), Vector2(8.0 * w, -2), Vector2(-8.0 * w, -2)
	]), Color(p.scarf)))
	# 頭髮（先畫，露出後方輪廓）
	var hair := _poly(_circle(9.0, 12), Color(p.hair))
	hair.position = Vector2(0, -16)
	body_v.add_child(hair)
	# 頭（後畫，蓋在頭髮上，臉才看得見）
	var head := _poly(_circle(7.5, 12), Color("f3e2d4"))
	head.position = Vector2(0, -13)
	body_v.add_child(head)
	player.add_child(body_v)

	player.move_child(swing, -1)          # 揮砍特效保持最上層
	body_v.scale.x = s * face_sign


func _spawn_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e.body):
			e.body.queue_free()
	enemies.clear()
	var centre := arena.position + arena.size * 0.5
	for i in cfg_enemy_count:
		var body := CharacterBody2D.new()
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = ENEMY_RADIUS
		cs.shape = shape
		body.add_child(cs)
		var vis := _poly(_circle(ENEMY_RADIUS, 14), VIOLET)
		body.add_child(vis)
		# 血條
		var bar_bg := _poly(PackedVector2Array([
			Vector2(-22, -40), Vector2(22, -40), Vector2(22, -34), Vector2(-22, -34)
		]), Color(0, 0, 0, 0.55))
		body.add_child(bar_bg)
		# 從 0 起算並左移，讓 scale.x 由左端縮短（而非從中央往兩側縮）
		var fill := _poly(PackedVector2Array([
			Vector2(0, -40), Vector2(44, -40), Vector2(44, -34), Vector2(0, -34)
		]), ROSE)
		fill.position = Vector2(-22, 0)
		body.add_child(fill)
		var ang := TAU * float(i) / float(max(1, cfg_enemy_count))
		body.position = centre + Vector2(cos(ang), sin(ang)) * 230.0
		add_child(body)
		enemies.append({
			"body": body, "hp": cfg_enemy_hp, "kb": Vector2.ZERO,
			"flash": 0.0, "touch_cd": 0.0, "stun": 0.0, "fill": fill, "vis": vis,
			"name": SOUL_NAMES[i % SOUL_NAMES.size()],
		})


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + s, 22)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = PLAYER_MAX_HP
	_hp_bar.value = PLAYER_MAX_HP
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(300, 18)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hp_bar.add_theme_stylebox_override("background", _sb(Color("241d33"), Color("3a3352"), 1, 6))
	_hp_bar.add_theme_stylebox_override("fill", _sb(ROSE, ROSE, 0, 6))
	col.add_child(_hp_bar)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", MUTED)
	col.add_child(_info)

	_skills = RichTextLabel.new()
	_skills.bbcode_enabled = true
	_skills.fit_content = true
	_skills.scroll_active = false
	_skills.add_theme_font_size_override("normal_font_size", 14)
	col.add_child(_skills)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", INK)
	_banner.visible = false
	col.add_child(_banner)

	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 12)
	col.add_child(_actions)

	var hint := Label.new()
	hint.text = "WASD 移動　　J 連段揮砍(可三連)　　K/Shift 疾走　　U I O P 流派技能　　1 2 3 換依代"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("6a6590"))
	col.add_child(hint)


func _reset_fight() -> void:
	var vp := get_viewport_rect().size
	arena = Rect2(Vector2(60, 60), vp - Vector2(120, 120))
	_cam.position = arena.position + arena.size * 0.5
	player.position = arena.position + arena.size * 0.5
	player.velocity = Vector2.ZERO
	player_hp = clampi(cfg_start_hp, 1, PLAYER_MAX_HP)
	facing = Vector2.RIGHT
	dash_t = 0.0
	dash_cd = 0.0
	atk_t = 0.0
	combo = 0
	combo_timer = 0.0
	skill_cd = [0.0, 0.0, 0.0, 0.0]
	dash_damage = false
	dash_hit = []
	lunge = 0.0
	invuln = 0.0
	hitstop = 0.0
	shake = 0.0
	state = "fight"
	_banner.visible = false
	_clear(_actions)
	_spawn_enemies()
	_update_ui()


# ============================================================
#  輸入
# ============================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_R and not embedded:      # 嵌入夜行時不允許重來，避免破壞一夜流程
		_reset_fight()
		return
	# 換依代：隨時可切，用來檢視外觀客製的辨識度
	if k == KEY_1 or k == KEY_2 or k == KEY_3:
		vessel_idx = k - KEY_1
		_build_player_visual(vessel_idx)
		_update_ui()
		return
	if state != "fight":
		return
	if k == KEY_J or k == KEY_SPACE:
		_try_attack()
		return
	elif k == KEY_K or k == KEY_SHIFT:
		_try_dash()
		return
	for i in SKILLS.size():
		if k == SKILLS[i].key:
			_try_skill(i)
			return


func _move_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.normalized()


func _try_attack() -> void:
	if atk_t > 0.0 or dash_t > 0.0:
		return
	# 在連段視窗內再按，就接下一段；否則從第一段重來
	combo = (combo + 1) % 3 if combo_timer > 0.0 else 0
	combo_timer = 0.0                      # 收招後才重新開視窗
	atk_t = ATK_WINDUP + ATK_ACTIVE + ATK_RECOVER
	atk_hit_done = false
	lunge = COMBO_LUNGE[combo]


func _try_skill(i: int) -> void:
	if not _skill_ready(i) or atk_t > 0.0 or dash_t > 0.0:
		return
	skill_cd[i] = SKILLS[i].cd
	match i:
		0: _skill_iai()
		1: _skill_dash_slash()
		2: _skill_ward()
		3: _skill_mend()


## 該技能是否已由天賦解鎖（獨立測試時全開）。
func _skill_unlocked(i: int) -> bool:
	if not embedded:
		return true
	var s: Dictionary = SKILLS[i]
	return TalentSystem.nodes[s.school][s.node]["unlocked"]


func _skill_ready(i: int) -> bool:
	return _skill_unlocked(i) and skill_cd[i] <= 0.0


## 拔刀（刀語）：一記長距離高傷突刺。
func _skill_iai() -> void:
	lunge = 560.0
	_flash_line(300.0, Color(1, 1, 1, 0.55))
	if _cone_hit(300.0, 34.0, 58, 640.0):
		hitstop = 0.10
		shake = 1.6


## 突進斬（疾走）：帶傷害的衝刺，途中掃過的敵人受傷。
func _skill_dash_slash() -> void:
	dash_dir = facing
	dash_t = 0.24
	invuln = maxf(invuln, 0.30)
	dash_damage = true
	dash_hit = []


## 封印陣（結界）：以自身為中心的範圍控場，命中者定身。
func _skill_ward() -> void:
	_ring_burst(210.0, CYAN)
	if _radial_hit(210.0, 16, 150.0, 1.7):
		hitstop = 0.06
		shake = 1.0


## 修復（羈絆）：回復魂。
func _skill_mend() -> void:
	player_hp = mini(PLAYER_MAX_HP, player_hp + 32)
	_ring_burst(120.0, Color("8affc0"))
	_spawn_damage_number(player.position, -32)


func _try_dash() -> void:
	if dash_cd > 0.0 or dash_t > 0.0:
		return
	var d := _move_input()
	dash_dir = d if d != Vector2.ZERO else facing
	dash_t = DASH_TIME
	dash_cd = DASH_CD
	dash_damage = false                 # 一般疾走不帶傷害（突進斬才有）
	invuln = max(invuln, DASH_TIME + 0.05)


# ============================================================
#  主迴圈
# ============================================================
func _physics_process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
		return
	if state != "fight":
		return

	dash_cd = max(0.0, dash_cd - delta)
	invuln = max(0.0, invuln - delta)
	shake = max(0.0, shake - delta * 3.0)
	combo_timer = max(0.0, combo_timer - delta)
	if combo_timer <= 0.0 and atk_t <= 0.0:
		combo = 0                      # 視窗過期，下一次從第一段開始
	for i in skill_cd.size():
		skill_cd[i] = max(0.0, skill_cd[i] - delta)

	_update_player(delta)
	_update_attack(delta)
	_update_enemies(delta)
	_update_camera()
	_update_ui()
	_check_end()


func _update_player(delta: float) -> void:
	var input := _move_input()
	if input != Vector2.ZERO and dash_t <= 0.0:
		facing = input

	if dash_t > 0.0:
		dash_t -= delta
		player.velocity = dash_dir * DASH_SPEED
	elif lunge > 0.0:
		# 揮砍墊步：短暫前衝，收招前衰減掉
		lunge = move_toward(lunge, 0.0, 2400.0 * delta)
		player.velocity = facing * lunge
	else:
		var mult := ATK_MOVE_MULT if atk_t > 0.0 else 1.0
		if input != Vector2.ZERO:
			player.velocity = player.velocity.move_toward(input * SPEED * mult, ACCEL * delta)
		else:
			player.velocity = player.velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	player.move_and_slide()
	player.position = _clamp_arena(player.position, PLAYER_RADIUS)

	# 身體只左右翻面（維持外觀辨識度），武器臂才隨面向旋轉
	if absf(facing.x) > 0.01:
		face_sign = 1.0 if facing.x > 0.0 else -1.0
	player.get_node("Body").scale.x = VISUAL_SCALE * face_sign
	player.get_node("Arm").rotation = facing.angle()
	player.modulate = Color(1, 1, 1, 0.55) if invuln > 0.0 else Color(1, 1, 1, 1)


func _update_attack(delta: float) -> void:
	if atk_t <= 0.0:
		swing.visible = false
		return
	var total := ATK_WINDUP + ATK_ACTIVE + ATK_RECOVER
	var elapsed := total - atk_t
	atk_t -= delta

	swing.rotation = facing.angle()
	var active := elapsed >= ATK_WINDUP and elapsed < ATK_WINDUP + ATK_ACTIVE
	swing.visible = active
	if active and not atk_hit_done:
		atk_hit_done = true
		_do_swing()
	if atk_t <= 0.0:
		swing.visible = false
		combo_timer = COMBO_WINDOW      # 收招後開啟接段視窗


func _do_swing() -> void:
	var m: float = COMBO_DMG[combo]
	var dmg := int(round(ATK_DAMAGE * m))
	if _cone_hit(ATK_RANGE, ATK_ARC * COMBO_ARC[combo], dmg, ATK_KNOCKBACK * m):
		hitstop = HITSTOP * (1.5 if combo == 2 else 1.0)
		shake = 1.6 if combo == 2 else 1.0


## 扇形判定：以 facing 為中心、arc_deg 為總角度。回傳是否命中任一目標。
func _cone_hit(rng: float, arc_deg: float, dmg: int, kb: float, stun := 0.0) -> bool:
	var hit_any := false
	for e in enemies:
		if e.hp <= 0:
			continue
		var to: Vector2 = e.body.position - player.position
		var dist := to.length()
		if dist > rng + ENEMY_RADIUS:
			continue
		if abs(angle_difference(facing.angle(), to.angle())) > deg_to_rad(arc_deg) * 0.5:
			continue
		_damage_enemy(e, dmg, to.normalized() * kb, stun, dist)
		hit_any = true
	return hit_any


## 環形判定：以自身為圓心的範圍傷害。
func _radial_hit(radius: float, dmg: int, kb: float, stun := 0.0) -> bool:
	var hit_any := false
	for e in enemies:
		if e.hp <= 0:
			continue
		var to: Vector2 = e.body.position - player.position
		var dist := to.length()
		if dist > radius + ENEMY_RADIUS:
			continue
		_damage_enemy(e, dmg, to.normalized() * kb, stun, dist)
		hit_any = true
	return hit_any


func _damage_enemy(e: Dictionary, dmg: int, kb_vec: Vector2, stun: float, dist: float) -> void:
	e.hp -= dmg
	e.flash = 0.12
	e.kb = kb_vec
	if stun > 0.0:
		e.stun = stun
	var dir := kb_vec.normalized()
	var impact: Vector2 = player.position + dir * maxf(0.0, dist - ENEMY_RADIUS * 0.5)
	_spawn_spark(impact, dir.angle())
	_spawn_damage_number(e.body.position, dmg)
	_punch(e.vis)
	if e.hp <= 0:
		e.body.visible = false


## 拔刀的長條閃光。
func _flash_line(length: float, col: Color) -> void:
	var line := _poly(PackedVector2Array([
		Vector2(10, -9), Vector2(length, -3), Vector2(length, 3), Vector2(10, 9)
	]), col)
	line.rotation = facing.angle()
	line.position = player.position
	add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.22)
	t.tween_callback(line.queue_free)


## 範圍技的擴散光環。
func _ring_burst(radius: float, col: Color) -> void:
	var ring := _poly(_circle(radius, 24), Color(col.r, col.g, col.b, 0.22))
	ring.position = player.position
	ring.scale = Vector2(0.25, 0.25)
	add_child(ring)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, 0.22)
	t.tween_property(ring, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(ring.queue_free)


## 命中處炸開的星芒，快速放大並淡出。
func _spawn_spark(pos: Vector2, ang: float) -> void:
	var spark := _poly(PackedVector2Array([
		Vector2(0, -7), Vector2(30, 0), Vector2(0, 7), Vector2(-14, 0)
	]), Color(1, 1, 1, 0.95))
	spark.position = pos
	spark.rotation = ang
	add_child(spark)
	var t := spark.create_tween()
	t.set_parallel(true)
	t.tween_property(spark, "scale", Vector2(2.4, 2.4), 0.16)
	t.tween_property(spark, "modulate:a", 0.0, 0.16)
	t.chain().tween_callback(spark.queue_free)


## 飄浮的傷害數字。
func _spawn_damage_number(pos: Vector2, dmg: int) -> void:
	var l := Label.new()
	l.text = str(dmg)
	l.position = pos + Vector2(-10, -56)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color("fff0a8"))
	add_child(l)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position", l.position + Vector2(0, -34), 0.45)
	t.tween_property(l, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(l.queue_free)


## 被擊中時的擠壓回彈，讓打擊有「實體感」。
func _punch(node: Node2D) -> void:
	node.scale = Vector2(1.35, 0.72)
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_enemies(delta: float) -> void:
	for e in enemies:
		if e.hp <= 0:
			continue
		var body: CharacterBody2D = e.body
		e.flash = max(0.0, e.flash - delta)
		e.touch_cd = max(0.0, e.touch_cd - delta)
		e.stun = max(0.0, e.stun - delta)
		e.kb = e.kb.move_toward(Vector2.ZERO, 1400.0 * delta)

		# 被封印時只受擊退擺佈，無法追擊
		var chase := Vector2.ZERO
		if e.stun <= 0.0:
			chase = (player.position - body.position).normalized() * ENEMY_SPEED
		body.velocity = chase + e.kb

		# 突進斬：衝刺途中掃到的敵人各受一次傷
		if dash_damage and dash_t > 0.0 and not dash_hit.has(e.body.get_instance_id()):
			if body.position.distance_to(player.position) <= 72.0 + ENEMY_RADIUS:
				dash_hit.append(e.body.get_instance_id())
				_damage_enemy(e, 34, (body.position - player.position).normalized() * 300.0,
					0.0, body.position.distance_to(player.position))
				hitstop = 0.04
				shake = 1.0
		body.move_and_slide()
		body.position = _clamp_arena(body.position, ENEMY_RADIUS)

		body.modulate = Color(2.2, 2.2, 2.2) if e.flash > 0.0 else Color(1, 1, 1)
		e.fill.scale.x = clampf(float(e.hp) / float(max(1, cfg_enemy_hp)), 0.0, 1.0)

		if body.position.distance_to(player.position) <= PLAYER_RADIUS + ENEMY_RADIUS + 4.0:
			if e.touch_cd <= 0.0 and invuln <= 0.0:
				e.touch_cd = ENEMY_TOUCH_CD
				_hurt_player(ENEMY_TOUCH_DMG)


func _hurt_player(dmg: int) -> void:
	player_hp = max(0, player_hp - dmg)
	invuln = INVULN_AFTER_HIT
	shake = 1.0
	hitstop = 0.04


func _update_camera() -> void:
	var base := arena.position + arena.size * 0.5
	if shake > 0.0:
		_cam.position = base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * SHAKE_MAG * shake
	else:
		_cam.position = base


func _check_end() -> void:
	if player_hp <= 0:
		_end_fight(false)
		return
	for e in enemies:
		if e.hp > 0:
			return
	_end_fight(true)


func _end_fight(won: bool) -> void:
	state = "win" if won else "lose"
	swing.visible = false
	_banner.visible = true
	_clear(_actions)
	_banner.text = "付喪神已伏" if won else "依代毀去"
	_banner.add_theme_color_override("font_color", CYAN if won else ROSE)

	if embedded:
		# 嵌入模式：留一點餘韻後把結果交回節點地圖，由它處理鎮壓／收容與結算
		await get_tree().create_timer(0.9).timeout
		if is_instance_valid(self):
			finished.emit(won)
		return

	if won:
		_actions.add_child(_button("鎮壓", ROSE, _on_suppress))
		_actions.add_child(_button("收容", CYAN, _on_contain))
	else:
		_actions.add_child(_button("再戰一次（R）", VIOLET, _reset_fight))


func _on_suppress() -> void:
	SoulSystem.suppress_soul("付喪神", {})
	_after_choice("已鎮壓 → 本輪戰鬥增益")


func _on_contain() -> void:
	var ok: bool = SoulSystem.contain_soul("付喪神", 2)
	_after_choice("已收容入魂魄囊" if ok else "魂魄囊已滿，收容失敗")


func _after_choice(msg: String) -> void:
	_banner.text = msg
	_clear(_actions)
	_actions.add_child(_button("再戰一次（R）", VIOLET, _reset_fight))


# ============================================================
#  小工具
# ============================================================
func _update_ui() -> void:
	_hp_bar.value = player_hp
	var alive := 0
	for e in enemies:
		if e.hp > 0:
			alive += 1
	var dash_txt := "就緒" if dash_cd <= 0.0 else "%.1fs" % dash_cd
	var vessel: String = VESSEL_PRESETS[vessel_idx % VESSEL_PRESETS.size()].name
	_info.text = "魂 %d/%d　　付喪神剩餘 %d　　疾走：%s　　依代：%s" % [
		player_hp, PLAYER_MAX_HP, alive, dash_txt, vessel
	]

	# 技能列：未解鎖顯示灰字（需在橫丁投該流派天賦）
	var parts: Array = []
	for i in SKILLS.size():
		var s: Dictionary = SKILLS[i]
		if not _skill_unlocked(i):
			parts.append("[color=#4b4766][%s] %s 未習[/color]" % [s.label, s.name])
		elif skill_cd[i] > 0.0:
			parts.append("[color=#6a6590][%s] %s %.1fs[/color]" % [s.label, s.name, skill_cd[i]])
		else:
			parts.append("[color=#38e1e8][%s][/color] [color=#efeaff]%s[/color]" % [s.label, s.name])
	_skills.text = "　　".join(parts)


func _clamp_arena(p: Vector2, r: float) -> Vector2:
	return Vector2(
		clampf(p.x, arena.position.x + r, arena.position.x + arena.size.x - r),
		clampf(p.y, arena.position.y + r, arena.position.y + arena.size.y - r)
	)


func _poly(points: PackedVector2Array, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = col
	return p


func _circle(r: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## 以原點為頂點、朝 +X 展開的扇形（用於揮砍判定的視覺化）。
func _wedge(radius: float, arc_deg: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var half := deg_to_rad(arc_deg) * 0.5
	var steps := 10
	for i in steps + 1:
		var a := -half + (2.0 * half) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _button(text: String, accent: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_stylebox_override("normal", _sb(Color("221d33"), accent, 1, 9))
	b.add_theme_stylebox_override("hover", _sb(Color("2c2545"), accent, 2, 9))
	b.add_theme_stylebox_override("pressed", _sb(Color("1a1628"), accent, 2, 9))
	b.pressed.connect(cb)
	return b


func _sb(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
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
