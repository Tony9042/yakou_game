extends Node3D
## 3D 戰鬥原型（試水溫）—— 用 Godot 內建 primitive，沿用 2D 版的手感邏輯。
## 獨立場景，不影響現有 2D 遊戲。單獨執行 combat3d.tscn（F6）。
##
## 操作：WASD 移動　J／空白 揮砍（前方扇形）　K／Shift 疾走（無敵）　R 重來
## 視角：3/4 斜俯視、鏡頭跟隨。

# ---- 手感（比照 2D 版）----
const SPEED := 7.2
const ACCEL := 70.0
const FRICTION := 60.0
const DASH_SPEED := 17.0
const DASH_TIME := 0.16
const DASH_CD := 0.55
const ATK_WINDUP := 0.05
const ATK_ACTIVE := 0.10
const ATK_RECOVER := 0.17
const ATK_RANGE := 3.4
const ATK_ARC := 115.0
const ATK_DAMAGE := 26
const ATK_KNOCKBACK := 9.0
const ATK_LUNGE := 9.5
const HITSTOP := 0.06

const ENEMY_SPEED := 3.0
const ENEMY_HP := 70
const ENEMY_TOUCH_DMG := 12
const ENEMY_TOUCH_CD := 0.9
const PLAYER_MAX_HP := 100
const INVULN_AFTER_HIT := 0.5
const ARENA := 26.0            # 半徑（方形場地半邊長）
const TERRAIN_STEP := 2.0      # 地形頂點間距
const TERRAIN_AMP := 2.8       # 起伏高度
const PLAYER_FOOT := 1.0       # 角色中心相對地面的高度
const ENEMY_FOOT := 0.9

const ROSE := Color("ff3d81")
const VIOLET := Color("a97bff")
const CYAN := Color("38e1e8")
const AMBER := Color("ffb45a")
const INK := Color("efeaff")

var player: CharacterBody3D
var pivot: Node3D
var swing: MeshInstance3D
var enemies: Array = []

var facing := Vector3(0, 0, -1)
var player_hp := PLAYER_MAX_HP
var vel := Vector3.ZERO
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector3(0, 0, -1)
var atk_t := 0.0
var atk_hit_done := false
var lunge := 0.0
var invuln := 0.0
var hitstop := 0.0
var state := "fight"

var _cam: Camera3D
var _hp_bar: ProgressBar
var _info: Label
var _banner: Label


func _ready() -> void:
	_build_world()
	_build_ui()
	_reset_fight()


# ============================================================
#  建場
# ============================================================
func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0b0a12")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("2a2740")
	e.ambient_light_energy = 0.45          # 壓低環境光，讓斜坡的明暗對比浮現
	e.glow_enabled = true                 # 讓自發光材質泛光＝霓虹感
	e.glow_intensity = 0.9
	e.glow_bloom = 0.25
	e.fog_enabled = true
	e.fog_light_color = Color("14121f")
	e.fog_density = 0.015
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_energy = 1.15                 # 主光加強，斜坡才有明暗
	sun.light_color = Color("cdd0ff")
	add_child(sun)
	# 反方向的青色補光，讓另一側坡面帶霓虹色、輪廓更立體
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 145, 0)
	fill.light_energy = 0.4
	fill.light_color = Color("38e1e8")
	add_child(fill)

	_build_terrain()
	# 霓虹邊界框（浮在地形上方，標示可行走範圍）
	for s in [Vector3(0, 0, -ARENA), Vector3(0, 0, ARENA), Vector3(-ARENA, 0, 0), Vector3(ARENA, 0, 0)]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		var along: bool = absf(s.z) > 0.1
		wm.size = Vector3(ARENA * 2.0 if along else 0.2, 0.2, 0.2 if along else ARENA * 2.0)
		wall.mesh = wm
		wall.material_override = _mat(ROSE, ROSE, 2.4)
		wall.position = s + Vector3(0, 11.0, 0)
		add_child(wall)

	# 玩家
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var pcol := CollisionShape3D.new()
	var pcap := CapsuleShape3D.new()
	pcap.radius = 0.45
	pcap.height = 1.9
	pcol.shape = pcap
	player.add_child(pcol)

	pivot = Node3D.new()          # 承載會轉向的視覺
	player.add_child(pivot)
	var pbody := MeshInstance3D.new()
	var pcapm := CapsuleMesh.new()
	pcapm.radius = 0.45
	pcapm.height = 1.9
	pbody.mesh = pcapm
	pbody.material_override = _mat(Color("2a1830"), ROSE, 1.6)
	pivot.add_child(pbody)
	# 面向指示（刀）
	var sword := MeshInstance3D.new()
	var swm := BoxMesh.new()
	swm.size = Vector3(0.12, 0.12, 1.5)
	sword.mesh = swm
	sword.material_override = _mat(Color("dfe6ff"), CYAN, 2.0)
	sword.position = Vector3(0.35, 0.2, -0.9)
	pivot.add_child(sword)
	# 揮砍扇形指示
	swing = MeshInstance3D.new()
	swing.mesh = _wedge_mesh(ATK_RANGE, ATK_ARC)
	var sw_mat := _mat(Color(1, 1, 1, 0.25), Color.WHITE, 1.4)
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 無法線的薄片也能正常顯示
	sw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED             # 雙面可見
	swing.material_override = sw_mat
	swing.visible = false
	pivot.add_child(swing)
	add_child(player)

	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)


## 地形高度函數——起伏丘陵＋一座明顯小丘＋一處低谷。
func _height(x: float, z: float) -> float:
	var h := sin(x * 0.2) * TERRAIN_AMP * 0.7
	h += cos(z * 0.17) * TERRAIN_AMP * 0.6
	h += sin((x + z) * 0.1) * TERRAIN_AMP * 0.45
	# 明顯的小丘（高斯隆起）
	var d := (Vector2(x, z) - Vector2(9.0, 7.0)).length()
	h += exp(-d * d / 70.0) * 4.5
	# 一處低谷
	var d2 := (Vector2(x, z) - Vector2(-10.0, -8.0)).length()
	h -= exp(-d2 * d2 / 95.0) * 3.0
	return h


## 生成低多邊形地形＋霓虹網格覆蓋。角色用高度貼合跟隨，不建物理碰撞。
func _build_terrain() -> void:
	# 實心地形
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := -ARENA
	while x < ARENA - 0.01:
		var z := -ARENA
		while z < ARENA - 0.01:
			var nx := x + TERRAIN_STEP
			var nz := z + TERRAIN_STEP
			var v00 := Vector3(x, _height(x, z), z)
			var v10 := Vector3(nx, _height(nx, z), z)
			var v01 := Vector3(x, _height(x, nz), nz)
			var v11 := Vector3(nx, _height(nx, nz), nz)
			# 纏繞方向讓法線朝上（否則上方的燈照不到、地形全黑）
			st.add_vertex(v00); st.add_vertex(v11); st.add_vertex(v01)
			st.add_vertex(v00); st.add_vertex(v10); st.add_vertex(v11)
			z += TERRAIN_STEP
		x += TERRAIN_STEP
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	var m := _mat(Color("423d63"), Color("1c1530"), 0.12)   # 提亮底色，靠打光顯出坡度
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED               # 保險：雙面都畫
	terrain.material_override = m
	add_child(terrain)

	# 霓虹網格覆蓋——直接把起伏「畫」出來（合成波風、超好辨識）
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_LINES)
	var a := -ARENA
	while a <= ARENA + 0.01:
		var b := -ARENA
		while b < ARENA - 0.01:
			var nb := b + TERRAIN_STEP
			gs.add_vertex(Vector3(b, _height(b, a) + 0.08, a))     # 沿 X
			gs.add_vertex(Vector3(nb, _height(nb, a) + 0.08, a))
			gs.add_vertex(Vector3(a, _height(a, b) + 0.08, b))     # 沿 Z
			gs.add_vertex(Vector3(a, _height(a, nb) + 0.08, nb))
			b += TERRAIN_STEP
		a += TERRAIN_STEP
	var grid := MeshInstance3D.new()
	grid.mesh = gs.commit()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = CYAN
	gm.emission_enabled = true
	gm.emission = CYAN
	gm.emission_energy_multiplier = 2.4
	grid.material_override = gm
	add_child(grid)


func _spawn_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e.body):
			e.body.queue_free()
	enemies.clear()
	for i in 3:
		var body := CharacterBody3D.new()
		body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.5
		cap.height = 1.7
		col.shape = cap
		body.add_child(col)
		var mesh := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.5
		cm.height = 1.7
		mesh.mesh = cm
		mesh.material_override = _mat(Color("241830"), VIOLET, 1.8)
		body.add_child(mesh)
		var ang := TAU * float(i) / 3.0
		var ex := cos(ang) * 9.0
		var ez := sin(ang) * 9.0
		body.position = Vector3(ex, _height(ex, ez) + ENEMY_FOOT, ez)
		add_child(body)
		enemies.append({"body": body, "mesh": mesh, "hp": ENEMY_HP,
			"kb": Vector3.ZERO, "flash": 0.0, "touch_cd": 0.0})


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = PLAYER_MAX_HP
	_hp_bar.value = PLAYER_MAX_HP
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(300, 18)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_hp_bar)

	_info = Label.new()
	_info.add_theme_color_override("font_color", INK)
	col.add_child(_info)

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

	var hint := Label.new()
	hint.text = "WASD 移動　J 揮砍　K/Shift 疾走　R 重來　（3D 試水溫原型）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("6a6590"))
	col.add_child(hint)


func _reset_fight() -> void:
	player.position = Vector3(0, _height(0, 0) + PLAYER_FOOT, 0)
	vel = Vector3.ZERO
	player_hp = PLAYER_MAX_HP
	facing = Vector3(0, 0, -1)
	dash_t = 0.0
	dash_cd = 0.0
	atk_t = 0.0
	lunge = 0.0
	invuln = 0.0
	hitstop = 0.0
	state = "fight"
	_banner.visible = false
	_spawn_enemies()
	_cam.position = player.position + Vector3(0, 13, 14)
	_cam.look_at(player.position + Vector3(0, 1.5, 0), Vector3.UP)


# ============================================================
#  輸入
# ============================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_R:
		_reset_fight()
		return
	if state != "fight":
		return
	if k == KEY_J or k == KEY_SPACE:
		_try_attack()
	elif k == KEY_K or k == KEY_SHIFT:
		_try_dash()


func _move_input() -> Vector3:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	return v.normalized()


func _try_attack() -> void:
	if atk_t > 0.0 or dash_t > 0.0:
		return
	atk_t = ATK_WINDUP + ATK_ACTIVE + ATK_RECOVER
	atk_hit_done = false
	lunge = ATK_LUNGE
	AudioManager.play("swing")


func _try_dash() -> void:
	if dash_cd > 0.0 or dash_t > 0.0:
		return
	var d := _move_input()
	dash_dir = d if d != Vector3.ZERO else facing
	dash_t = DASH_TIME
	dash_cd = DASH_CD
	invuln = maxf(invuln, DASH_TIME + 0.05)
	AudioManager.play("dash")


# ============================================================
#  主迴圈
# ============================================================
func _physics_process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
		return
	if state != "fight":
		return
	dash_cd = maxf(0.0, dash_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	_update_player(delta)
	_update_attack(delta)
	_update_enemies(delta)
	_update_camera(delta)
	_update_ui()
	_check_end()


func _update_player(delta: float) -> void:
	var input := _move_input()
	if input != Vector3.ZERO and dash_t <= 0.0:
		facing = input

	if dash_t > 0.0:
		dash_t -= delta
		vel = dash_dir * DASH_SPEED
	elif lunge > 0.0:
		lunge = move_toward(lunge, 0.0, 55.0 * delta)
		vel = facing * lunge
	else:
		var mult := 0.32 if atk_t > 0.0 else 1.0
		if input != Vector3.ZERO:
			vel = vel.move_toward(input * SPEED * mult, ACCEL * delta)
		else:
			vel = vel.move_toward(Vector3.ZERO, FRICTION * delta)

	player.velocity = Vector3(vel.x, 0.0, vel.z)
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -ARENA + 0.8, ARENA - 0.8)
	player.position.z = clampf(player.position.z, -ARENA + 0.8, ARENA - 0.8)
	player.position.y = _height(player.position.x, player.position.z) + PLAYER_FOOT   # 貼合地形

	pivot.look_at(player.global_position + facing, Vector3.UP)   # -Z 對準面向
	if invuln > 0.0:
		pivot.visible = int(Time.get_ticks_msec() / 60.0) % 2 == 0
	else:
		pivot.visible = true


func _update_attack(delta: float) -> void:
	if atk_t <= 0.0:
		swing.visible = false
		return
	var total := ATK_WINDUP + ATK_ACTIVE + ATK_RECOVER
	var elapsed := total - atk_t
	atk_t -= delta
	var active := elapsed >= ATK_WINDUP and elapsed < ATK_WINDUP + ATK_ACTIVE
	swing.visible = active
	if active and not atk_hit_done:
		atk_hit_done = true
		_do_swing()
	if atk_t <= 0.0:
		swing.visible = false


func _do_swing() -> void:
	var hit_any := false
	for e in enemies:
		if e.hp <= 0:
			continue
		var to: Vector3 = e.body.position - player.position
		to.y = 0.0
		if to.length() > ATK_RANGE + 0.5:
			continue
		if facing.angle_to(to) > deg_to_rad(ATK_ARC) * 0.5:
			continue
		e.hp -= ATK_DAMAGE
		e.flash = 0.12
		e.kb = to.normalized() * ATK_KNOCKBACK
		hit_any = true
		_dmg_popup(e.body.position, ATK_DAMAGE)
		AudioManager.play("hit", randf_range(0.94, 1.08), -3.0)
		if e.hp <= 0:
			e.body.visible = false
	if hit_any:
		hitstop = HITSTOP


func _update_enemies(delta: float) -> void:
	for e in enemies:
		if e.hp <= 0:
			continue
		var body: CharacterBody3D = e.body
		e.flash = maxf(0.0, e.flash - delta)
		e.touch_cd = maxf(0.0, e.touch_cd - delta)
		e.kb = e.kb.move_toward(Vector3.ZERO, 30.0 * delta)
		var chase: Vector3 = (player.position - body.position)
		chase.y = 0.0
		chase = chase.normalized() * ENEMY_SPEED
		body.velocity = Vector3(chase.x + e.kb.x, 0.0, chase.z + e.kb.z)
		body.move_and_slide()
		body.position.y = _height(body.position.x, body.position.z) + ENEMY_FOOT
		var mat: StandardMaterial3D = e.mesh.material_override
		mat.emission_energy_multiplier = 4.5 if e.flash > 0.0 else 1.8
		if body.position.distance_to(player.position) <= 1.4 and e.touch_cd <= 0.0 and invuln <= 0.0:
			e.touch_cd = ENEMY_TOUCH_CD
			_hurt_player(ENEMY_TOUCH_DMG)


func _hurt_player(dmg: int) -> void:
	player_hp = maxi(0, player_hp - dmg)
	invuln = INVULN_AFTER_HIT
	hitstop = 0.04
	AudioManager.play("hurt")


func _update_camera(delta: float) -> void:
	var target := player.position + Vector3(0, 13, 14)
	_cam.position = _cam.position.lerp(target, clampf(delta * 9.0, 0.0, 1.0))
	_cam.look_at(player.position + Vector3(0, 1.5, 0), Vector3.UP)


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
	_banner.text = ("付喪神已伏　（R 重來）" if won else "依代毀去　（R 重來）")
	_banner.add_theme_color_override("font_color", CYAN if won else ROSE)
	AudioManager.play("win" if won else "lose")


func _update_ui() -> void:
	_hp_bar.value = player_hp
	var alive := 0
	for e in enemies:
		if e.hp > 0:
			alive += 1
	var dash_txt := "就緒" if dash_cd <= 0.0 else "%.1fs" % dash_cd
	_info.text = "魂 %d/%d　　付喪神剩餘 %d　　疾走：%s" % [player_hp, PLAYER_MAX_HP, alive, dash_txt]


# ============================================================
#  小工具
# ============================================================
func _mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


## 扇形薄片（揮砍指示），朝 -Z 展開。
func _wedge_mesh(radius: float, arc_deg: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var half := deg_to_rad(arc_deg) * 0.5
	var steps := 12
	verts.append(Vector3.ZERO)
	for i in steps + 1:
		var a := -half + (2.0 * half) * float(i) / float(steps)
		verts.append(Vector3(sin(a) * radius, 0, -cos(a) * radius))
	var idx := PackedInt32Array()
	for i in steps:
		idx.append(0)
		idx.append(i + 1)
		idx.append(i + 2)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _dmg_popup(pos: Vector3, dmg: int) -> void:
	var l := Label3D.new()
	l.text = str(dmg)
	l.font_size = 64
	l.modulate = Color("fff0a8")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos + Vector3(0, 1.6, 0)
	l.no_depth_test = true
	add_child(l)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position", l.position + Vector3(0, 1.2, 0), 0.45)
	t.tween_property(l, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(l.queue_free)
