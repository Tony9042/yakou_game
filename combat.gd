extends Node2D
## 戰鬥場景（Phase 1～2）。
## 3/4 斜俯視動作戰鬥：移動、疾走（無敵幀）、三連段揮砍、流派技能。
## 大型場地＋鏡頭跟隨；敵人分化為追擊／遠程／衝刺／Boss 四種行為。
##
## 操作：WASD 移動　J 連段揮砍　K／Shift 疾走　U I O P 流派技能　1/2/3 換依代
## 不使用 InputMap，直接讀鍵盤，避免更動專案設定。

# ---- 手感參數（想調手感就改這裡）----
const SPEED := 335.0
const ACCEL := 2900.0
const FRICTION := 2200.0

const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const DASH_CD := 0.55

const ATK_WINDUP := 0.05
const ATK_ACTIVE := 0.10
const ATK_RECOVER := 0.17
const ATK_MOVE_MULT := 0.32
const ATK_RANGE := 132.0
const ATK_ARC := 115.0
const ATK_DAMAGE := 26
const ATK_KNOCKBACK := 460.0
const ATK_LUNGE := 430.0
const HITSTOP := 0.06
const SHAKE_MAG := 13.0

const PLAYER_RADIUS := 21.0
const PLAYER_MAX_HP := 100
const INVULN_AFTER_HIT := 0.5
const VISUAL_SCALE := 1.6

## 場地大小（遠大於視窗，鏡頭跟隨玩家）。
const ARENA_W := 2100.0
const ARENA_H := 1400.0
const GRID_STEP := 210.0

## 三連段
const COMBO_DMG := [1.0, 1.05, 1.6]
const COMBO_ARC := [1.0, 1.0, 1.35]
const COMBO_LUNGE := [430.0, 450.0, 540.0]
const COMBO_WINDOW := 0.55

## 流派技能 —— 對應 TalentSystem 天賦，投點後才可用（獨立測試時全開）。
const SKILLS := [
	{"key": KEY_U, "label": "U", "school": "blade",   "node": "拔刀", "name": "拔刀",   "cd": 4.0},
	{"key": KEY_I, "label": "I", "school": "rider",   "node": "突進", "name": "突進斬", "cd": 3.0},
	{"key": KEY_O, "label": "O", "school": "ward",    "node": "封印", "name": "封印陣", "cd": 7.0},
	{"key": KEY_P, "label": "P", "school": "support", "node": "馴養", "name": "修復",   "cd": 10.0},
]

## 敵人分化：各自的行為模式與數值。
const ETYPES := {
	"chaser": {
		"label": "追擊", "color": "a97bff", "radius": 24.0, "speed": 122.0,
		"hp_mult": 1.0, "touch": 12,
	},
	"ranged": {
		"label": "遠程", "color": "38e1e8", "radius": 21.0, "speed": 84.0,
		"hp_mult": 0.7, "touch": 8,
	},
	"charger": {
		"label": "衝刺", "color": "ffb45a", "radius": 27.0, "speed": 96.0,
		"hp_mult": 1.15, "touch": 16,
	},
	"boss": {
		"label": "拆之魂", "color": "ff3d81", "radius": 44.0, "speed": 92.0,
		"hp_mult": 1.0, "touch": 20,
	},
}

const ENEMY_TOUCH_CD := 0.9
const KEEP_DIST := 330.0        # 遠程敵偏好的距離
const SHOOT_CD := 2.1
const BULLET_SPEED := 330.0
const BULLET_DMG := 10

# ---- 配色 ----
const NIGHT := Color("14121f")
const ROSE := Color("ff3d81")
const VIOLET := Color("a97bff")
const CYAN := Color("38e1e8")
const AMBER := Color("ffb45a")
const INK := Color("efeaff")
const MUTED := Color("9c95bb")

const SOUL_NAMES := ["提灯付喪神", "傘化生", "招牌の主", "自販機禍", "街燈守"]

## 依代（軀殼）外觀預設 —— §3.4 的可換客製層。
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
var embedded := false
var cfg_enemy_count := 3
var cfg_enemy_hp := 70
var cfg_start_hp := PLAYER_MAX_HP
var cfg_vessel := 0
var cfg_types: Array = []        # 例：["chaser","ranged"]；留空則全為追擊型

var player: CharacterBody2D
var swing: Polygon2D
var enemies: Array = []
var bullets: Array = []          # [{node, vel, life}]

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
var state := "fight"

var arena := Rect2()
var _hp_bar: ProgressBar
var _info: Label
var _skills: RichTextLabel
var _banner: Label
var _actions: HBoxContainer
var _cam: Camera2D
var _world: Node2D


func _ready() -> void:
	vessel_idx = cfg_vessel
	arena = Rect2(Vector2.ZERO, Vector2(ARENA_W, ARENA_H))
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

	_world = Node2D.new()
	add_child(_world)
	_draw_arena()

	_cam = Camera2D.new()
	_cam.limit_left = int(arena.position.x)
	_cam.limit_top = int(arena.position.y)
	_cam.limit_right = int(arena.position.x + arena.size.x)
	_cam.limit_bottom = int(arena.position.y + arena.size.y)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 9.0
	add_child(_cam)
	_cam.make_current()

	player = CharacterBody2D.new()
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var pc := CollisionShape2D.new()
	var pcs := CircleShape2D.new()
	pcs.radius = PLAYER_RADIUS
	pc.shape = pcs
	player.add_child(pc)

	swing = _poly(_wedge(ATK_RANGE, ATK_ARC), Color(1, 1, 1, 0.30))
	swing.visible = false
	player.add_child(swing)
	add_child(player)

	_build_player_visual(vessel_idx)


## 地面格線與邊界——大場地需要參照物，否則感覺不到自己在移動。
func _draw_arena() -> void:
	var grid_col := Color(1, 1, 1, 0.045)
	var x := arena.position.x
	while x <= arena.position.x + arena.size.x:
		_world.add_child(_line([Vector2(x, arena.position.y),
			Vector2(x, arena.position.y + arena.size.y)], grid_col, 2.0))
		x += GRID_STEP
	var y := arena.position.y
	while y <= arena.position.y + arena.size.y:
		_world.add_child(_line([Vector2(arena.position.x, y),
			Vector2(arena.position.x + arena.size.x, y)], grid_col, 2.0))
		y += GRID_STEP
	# 邊界
	var p := arena.position
	var s := arena.size
	_world.add_child(_line([p, p + Vector2(s.x, 0), p + s, p + Vector2(0, s.y), p],
		Color(1, 0.24, 0.51, 0.30), 4.0))


func _build_player_visual(idx: int) -> void:
	var p: Dictionary = VESSEL_PRESETS[idx % VESSEL_PRESETS.size()]
	for n in ["Body", "Arm"]:
		if player.has_node(n):
			var old := player.get_node(n)
			player.remove_child(old)
			old.queue_free()

	var w: float = p.width
	var s := VISUAL_SCALE

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

	var body_v := Node2D.new()
	body_v.name = "Body"
	body_v.scale = Vector2(s, s)
	body_v.add_child(_poly(PackedVector2Array([
		Vector2(-11.0 * w, -3), Vector2(11.0 * w, -3), Vector2(8.0 * w, 16), Vector2(-8.0 * w, 16)
	]), Color(p.coat)))
	body_v.add_child(_poly(PackedVector2Array([
		Vector2(-8.0 * w, -4), Vector2(8.0 * w, -4), Vector2(6.0 * w, 12), Vector2(-6.0 * w, 12)
	]), Color(p.torso)))
	body_v.add_child(_poly(PackedVector2Array([
		Vector2(-8.0 * w, -6), Vector2(8.0 * w, -6), Vector2(8.0 * w, -2), Vector2(-8.0 * w, -2)
	]), Color(p.scarf)))
	var hair := _poly(_circle(9.0, 12), Color(p.hair))
	hair.position = Vector2(0, -16)
	body_v.add_child(hair)
	var head := _poly(_circle(7.5, 12), Color("f3e2d4"))
	head.position = Vector2(0, -13)
	body_v.add_child(head)
	player.add_child(body_v)

	player.move_child(swing, -1)
	body_v.scale.x = s * face_sign


func _spawn_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e.body):
			e.body.queue_free()
	enemies.clear()

	var types := cfg_types.duplicate()
	while types.size() < cfg_enemy_count:
		types.append("chaser")

	for i in cfg_enemy_count:
		var tname: String = types[i]
		var td: Dictionary = ETYPES.get(tname, ETYPES["chaser"])
		var radius: float = td.radius

		var body := CharacterBody2D.new()
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = radius
		cs.shape = shape
		body.add_child(cs)

		var vis := _poly(_circle(radius, 16), Color(td.color))
		body.add_child(vis)
		# 遠程敵加一圈內環、衝刺敵加一個尖角，讓類型一眼可辨
		if tname == "ranged":
			var core := _poly(_circle(radius * 0.45, 10), Color(1, 1, 1, 0.5))
			vis.add_child(core)
		elif tname == "charger" or tname == "boss":
			var spike := _poly(PackedVector2Array([
				Vector2(radius * 0.2, -radius * 0.5), Vector2(radius * 1.5, 0),
				Vector2(radius * 0.2, radius * 0.5)
			]), Color(1, 1, 1, 0.45))
			spike.name = "Spike"
			vis.add_child(spike)

		var bw := radius + 14.0
		var by := -radius - 14.0
		body.add_child(_poly(PackedVector2Array([
			Vector2(-bw, by), Vector2(bw, by), Vector2(bw, by + 6), Vector2(-bw, by + 6)
		]), Color(0, 0, 0, 0.55)))
		var fill := _poly(PackedVector2Array([
			Vector2(0, by), Vector2(bw * 2.0, by), Vector2(bw * 2.0, by + 6), Vector2(0, by + 6)
		]), Color(td.color))
		fill.position = Vector2(-bw, 0)
		body.add_child(fill)

		body.position = _spawn_point(i)
		add_child(body)
		enemies.append({
			"body": body, "type": tname, "radius": radius,
			"hp": int(round(cfg_enemy_hp * float(td.hp_mult))),
			"max_hp": int(round(cfg_enemy_hp * float(td.hp_mult))),
			"speed": float(td.speed), "touch": int(td.touch),
			"kb": Vector2.ZERO, "flash": 0.0, "touch_cd": 0.0, "stun": 0.0,
			"shoot_cd": randf_range(0.6, SHOOT_CD), "phase": "idle", "timer": 0.0,
			"charge_dir": Vector2.RIGHT, "fill": fill, "vis": vis,
			"name": SOUL_NAMES[i % SOUL_NAMES.size()],
		})


## 在場地內、離玩家夠遠的位置生成。
func _spawn_point(i: int) -> Vector2:
	var centre := arena.position + arena.size * 0.5
	for _try in 24:
		var pos := Vector2(
			randf_range(arena.position.x + 120.0, arena.position.x + arena.size.x - 120.0),
			randf_range(arena.position.y + 120.0, arena.position.y + arena.size.y - 120.0)
		)
		if pos.distance_to(player.position) > 420.0:
			return pos
	var ang := TAU * float(i) / float(maxi(1, cfg_enemy_count))
	return centre + Vector2(cos(ang), sin(ang)) * 460.0


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
	_clear_bullets()
	_spawn_enemies()
	_cam.position = player.position
	_cam.reset_smoothing()
	_update_ui()


# ============================================================
#  輸入
# ============================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_R and not embedded:
		_reset_fight()
		return
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
	combo = (combo + 1) % 3 if combo_timer > 0.0 else 0
	combo_timer = 0.0
	atk_t = ATK_WINDUP + ATK_ACTIVE + ATK_RECOVER
	atk_hit_done = false
	lunge = COMBO_LUNGE[combo]


func _try_dash() -> void:
	if dash_cd > 0.0 or dash_t > 0.0:
		return
	var d := _move_input()
	dash_dir = d if d != Vector2.ZERO else facing
	dash_t = DASH_TIME
	dash_cd = DASH_CD
	dash_damage = false
	invuln = max(invuln, DASH_TIME + 0.05)


func _try_skill(i: int) -> void:
	if not _skill_ready(i) or atk_t > 0.0 or dash_t > 0.0:
		return
	skill_cd[i] = SKILLS[i].cd
	match i:
		0: _skill_iai()
		1: _skill_dash_slash()
		2: _skill_ward()
		3: _skill_mend()


func _skill_unlocked(i: int) -> bool:
	if not embedded:
		return true
	var s: Dictionary = SKILLS[i]
	return TalentSystem.nodes[s.school][s.node]["unlocked"]


func _skill_ready(i: int) -> bool:
	return _skill_unlocked(i) and skill_cd[i] <= 0.0


func _skill_iai() -> void:
	lunge = 560.0
	_flash_line(300.0, Color(1, 1, 1, 0.55))
	if _cone_hit(300.0, 34.0, 58, 640.0):
		hitstop = 0.10
		shake = 1.6


func _skill_dash_slash() -> void:
	dash_dir = facing
	dash_t = 0.24
	invuln = maxf(invuln, 0.30)
	dash_damage = true
	dash_hit = []


func _skill_ward() -> void:
	_ring_burst(210.0, CYAN)
	if _radial_hit(210.0, 16, 150.0, 1.7):
		hitstop = 0.06
		shake = 1.0


func _skill_mend() -> void:
	player_hp = mini(PLAYER_MAX_HP, player_hp + 32)
	_ring_burst(120.0, Color("8affc0"))
	_spawn_damage_number(player.position, -32)


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
		combo = 0
	for i in skill_cd.size():
		skill_cd[i] = max(0.0, skill_cd[i] - delta)

	_update_player(delta)
	_update_attack(delta)
	_update_enemies(delta)
	_update_bullets(delta)
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
		combo_timer = COMBO_WINDOW


func _do_swing() -> void:
	var m: float = COMBO_DMG[combo]
	var dmg := int(round(ATK_DAMAGE * m))
	if _cone_hit(ATK_RANGE, ATK_ARC * COMBO_ARC[combo], dmg, ATK_KNOCKBACK * m):
		hitstop = HITSTOP * (1.5 if combo == 2 else 1.0)
		shake = 1.6 if combo == 2 else 1.0


# ============================================================
#  敵人行為
# ============================================================
func _update_enemies(delta: float) -> void:
	for e in enemies:
		if e.hp <= 0:
			continue
		var body: CharacterBody2D = e.body
		e.flash = max(0.0, e.flash - delta)
		e.touch_cd = max(0.0, e.touch_cd - delta)
		e.stun = max(0.0, e.stun - delta)
		e.kb = e.kb.move_toward(Vector2.ZERO, 1400.0 * delta)

		var to_player: Vector2 = player.position - body.position
		var dist := to_player.length()
		var move := Vector2.ZERO

		if e.stun <= 0.0:
			match e.type:
				"ranged":
					move = _behave_ranged(e, to_player, dist, delta)
				"charger", "boss":
					move = _behave_charger(e, to_player, dist, delta)
				_:
					move = to_player.normalized() * float(e.speed)

		body.velocity = move + e.kb
		body.move_and_slide()
		body.position = _clamp_arena(body.position, e.radius)

		body.modulate = Color(2.2, 2.2, 2.2) if e.flash > 0.0 else Color(1, 1, 1)
		e.fill.scale.x = clampf(float(e.hp) / float(maxi(1, e.max_hp)), 0.0, 1.0)
		# 衝刺型的尖角指向前進方向
		if e.vis.has_node("Spike"):
			e.vis.get_node("Spike").rotation = (e.charge_dir as Vector2).angle()

		# 接觸傷害
		if dist <= PLAYER_RADIUS + float(e.radius) + 4.0:
			if e.touch_cd <= 0.0 and invuln <= 0.0:
				e.touch_cd = ENEMY_TOUCH_CD
				_hurt_player(int(e.touch))

		# 突進斬：衝刺途中掃到的敵人各受一次傷
		if dash_damage and dash_t > 0.0 and not dash_hit.has(body.get_instance_id()):
			if dist <= 72.0 + float(e.radius):
				dash_hit.append(body.get_instance_id())
				_damage_enemy(e, 34, (-to_player).normalized() * 300.0, 0.0, dist)
				hitstop = 0.04
				shake = 1.0


## 遠程型：維持距離並射擊。
func _behave_ranged(e: Dictionary, to_player: Vector2, dist: float, delta: float) -> Vector2:
	e.shoot_cd = max(0.0, e.shoot_cd - delta)
	if e.shoot_cd <= 0.0 and dist < 620.0:
		e.shoot_cd = SHOOT_CD
		_spawn_bullet(e.body.position, to_player.normalized())
	var speed: float = e.speed
	if dist > KEEP_DIST + 60.0:
		return to_player.normalized() * speed
	if dist < KEEP_DIST - 60.0:
		return -to_player.normalized() * speed
	return to_player.orthogonal().normalized() * speed * 0.5   # 側移繞圈


## 衝刺型：接近 → 蓄力預警 → 高速衝刺 → 硬直。
func _behave_charger(e: Dictionary, to_player: Vector2, dist: float, delta: float) -> Vector2:
	e.timer = max(0.0, e.timer - delta)
	match e.phase:
		"idle":
			if dist < 360.0:
				e.phase = "tell"
				e.timer = 0.6
				e.charge_dir = to_player.normalized()
			return to_player.normalized() * float(e.speed)
		"tell":
			e.charge_dir = (e.charge_dir as Vector2).lerp(to_player.normalized(), 0.06)
			e.vis.modulate = Color(1.8, 1.4, 1.4)      # 預警：發亮
			if e.timer <= 0.0:
				e.phase = "charge"
				e.timer = 0.38
			return Vector2.ZERO
		"charge":
			e.vis.modulate = Color(1, 1, 1)
			if e.timer <= 0.0:
				e.phase = "rest"
				e.timer = 0.75
			return (e.charge_dir as Vector2) * 640.0
		_:
			e.vis.modulate = Color(1, 1, 1)
			if e.timer <= 0.0:
				e.phase = "idle"
			return Vector2.ZERO


# ============================================================
#  投射物
# ============================================================
func _spawn_bullet(from: Vector2, dir: Vector2) -> void:
	var b := _poly(_circle(7.0, 10), CYAN)
	b.position = from
	add_child(b)
	bullets.append({"node": b, "vel": dir * BULLET_SPEED, "life": 4.0})


func _update_bullets(delta: float) -> void:
	var keep: Array = []
	for b in bullets:
		var node: Polygon2D = b.node
		if not is_instance_valid(node):
			continue
		b.life -= delta
		node.position += (b.vel as Vector2) * delta
		var hit := node.position.distance_to(player.position) <= PLAYER_RADIUS + 7.0
		var outside := not arena.has_point(node.position)
		if hit and invuln <= 0.0:
			_hurt_player(BULLET_DMG)
			node.queue_free()
			continue
		if hit or outside or b.life <= 0.0:
			node.queue_free()
			continue
		keep.append(b)
	bullets = keep


func _clear_bullets() -> void:
	for b in bullets:
		if is_instance_valid(b.node):
			b.node.queue_free()
	bullets = []


# ============================================================
#  傷害與特效
# ============================================================
func _cone_hit(rng: float, arc_deg: float, dmg: int, kb: float, stun := 0.0) -> bool:
	var hit_any := false
	for e in enemies:
		if e.hp <= 0:
			continue
		var to: Vector2 = e.body.position - player.position
		var dist := to.length()
		if dist > rng + float(e.radius):
			continue
		if abs(angle_difference(facing.angle(), to.angle())) > deg_to_rad(arc_deg) * 0.5:
			continue
		_damage_enemy(e, dmg, to.normalized() * kb, stun, dist)
		hit_any = true
	return hit_any


func _radial_hit(radius: float, dmg: int, kb: float, stun := 0.0) -> bool:
	var hit_any := false
	for e in enemies:
		if e.hp <= 0:
			continue
		var to: Vector2 = e.body.position - player.position
		var dist := to.length()
		if dist > radius + float(e.radius):
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
		e.phase = "idle"          # 定身也打斷衝刺蓄力
	var dir := kb_vec.normalized()
	var impact: Vector2 = player.position + dir * maxf(0.0, dist - float(e.radius) * 0.5)
	_spawn_spark(impact, dir.angle())
	_spawn_damage_number(e.body.position, dmg)
	_punch(e.vis)
	if e.hp <= 0:
		e.body.visible = false


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


func _punch(node: Node2D) -> void:
	node.scale = Vector2(1.35, 0.72)
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


func _hurt_player(dmg: int) -> void:
	player_hp = max(0, player_hp - dmg)
	invuln = INVULN_AFTER_HIT
	shake = 1.0
	hitstop = 0.04


func _update_camera() -> void:
	_cam.position = player.position
	if shake > 0.0:
		_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * SHAKE_MAG * shake
	else:
		_cam.offset = Vector2.ZERO


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
	_clear_bullets()
	_banner.visible = true
	_clear(_actions)
	_banner.text = "付喪神已伏" if won else "依代毀去"
	_banner.add_theme_color_override("font_color", CYAN if won else ROSE)

	if embedded:
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
	var kinds := {}
	for e in enemies:
		if e.hp > 0:
			alive += 1
			var lbl: String = ETYPES[e.type].label
			kinds[lbl] = int(kinds.get(lbl, 0)) + 1
	var kind_txt: Array = []
	for k in kinds:
		kind_txt.append("%s×%d" % [k, kinds[k]])
	var dash_txt := "就緒" if dash_cd <= 0.0 else "%.1fs" % dash_cd
	var vessel: String = VESSEL_PRESETS[vessel_idx % VESSEL_PRESETS.size()].name
	_info.text = "魂 %d/%d　　剩餘 %d（%s）　　疾走：%s　　依代：%s" % [
		player_hp, PLAYER_MAX_HP, alive, "、".join(kind_txt) if kind_txt else "—", dash_txt, vessel
	]

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


func _line(points: Array, col: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array(points)
	l.default_color = col
	l.width = width
	return l


func _circle(r: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


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
