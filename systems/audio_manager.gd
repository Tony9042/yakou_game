extends Node
## AudioManager — autoload 單例。
## 以程式合成音效（AudioStreamWAV），零外部素材即可有聲音。
## 日後要換成真音效檔：把 res://audio/sfx/<名稱>.wav 放進來，
## _build_sfx() 會優先載入檔案、沒有才用合成版（見 _register）。
##
## BGM 走檔案：play_bgm("res://audio/bgm/xxx.ogg")，檔案不存在則靜默。

const SR := 22050
const POOL := 10

var enabled := true
var _players: Array[AudioStreamPlayer] = []
var _rr := 0
var _sfx := {}
var _bgm_synth := {}
var _bgm: AudioStreamPlayer
var _bgm_key := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # 暫停時 UI 音效仍要能播
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm.volume_db = -14.0
	add_child(_bgm)
	_build_sfx()


func set_enabled(on: bool) -> void:
	enabled = on
	if _bgm:
		_bgm.stream_paused = not on


func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not enabled:
		return
	var entry: Variant = _sfx.get(name)
	if entry == null:
		return
	var s: AudioStream = entry.pick_random() if entry is Array else entry
	if s == null:
		return
	_rr = (_rr + 1) % _players.size()
	var p := _players[_rr]
	p.stop()
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.4, 2.4)
	p.volume_db = vol_db
	p.play()


## 依場景鍵播放 BGM（"hall" / "night" / "title"）。
## 有同名 .ogg 檔則優先，否則用程式合成的循環版。
func play_bgm(key: String, vol_db := -12.0) -> void:
	if _bgm_key == key and _bgm.playing:
		return
	_bgm_key = key
	var stream: AudioStream = null
	var path := "res://audio/bgm/%s.ogg" % key
	if ResourceLoader.exists(path):
		stream = load(path)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	else:
		stream = _bgm_synth.get(key)
	if stream == null:
		_bgm.stop()
		return
	_bgm.stream = stream
	_bgm.volume_db = vol_db
	_bgm.play()


func stop_bgm() -> void:
	_bgm.stop()
	_bgm_key = ""


# ============================================================
#  音效合成
# ============================================================
func _build_sfx() -> void:
	_register("click", _sfx_click())
	_register("swing", [_sfx_swing(560.0), _sfx_swing(680.0), _sfx_swing(460.0)])
	# 三種命中：深沉／緊實高音／金屬殘響——每次隨機挑一種＋音高微變
	_register("hit", [
		_hit(130.0, 34.0, 20.0, 0.0, 0.13),
		_hit(205.0, 40.0, 26.0, 0.0, 0.10),
		_hit(150.0, 30.0, 22.0, 520.0, 0.14),
	])
	_register("skill", _sfx_skill())
	_register("dash", _sfx_dash())
	_register("hurt", _sfx_hurt())
	_register("buy", _sfx_buy())
	_register("win", _sfx_win())
	_register("lose", _sfx_lose())

	# 程式合成 BGM（可循環）；有同名 .ogg 檔則由 play_bgm 優先使用
	_bgm_synth["hall"] = _bgm_hall()
	_bgm_synth["night"] = _bgm_night()
	_bgm_synth["title"] = _bgm_synth["hall"]


## 有同名檔案就用檔案，否則用合成版（可為單一 WAV 或多個變體的 Array）。
func _register(name: String, synthesized: Variant) -> void:
	var path := "res://audio/sfx/%s.wav" % name
	if ResourceLoader.exists(path):
		_sfx[name] = load(path)
	else:
		_sfx[name] = synthesized


func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	return w


func _n(dur: float) -> int:
	return int(dur * SR)


# ---- 各音效 ----
func _sfx_click() -> AudioStreamWAV:
	var n := _n(0.05)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		ph += TAU * 900.0 / SR
		var sq := 1.0 if sin(ph) >= 0.0 else -1.0
		buf[i] = sq * 0.18 * exp(-t * 60.0)
	return _wav(buf)


func _sfx_swing(start_freq: float) -> AudioStreamWAV:
	var n := _n(0.14)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var frac := t / 0.14
		var freq: float = lerp(start_freq, 150.0, frac)   # 下掃
		ph += TAU * freq / SR
		var white := randf() * 2.0 - 1.0
		lp += (white - lp) * 0.35
		var env := exp(-t * 16.0) * minf(1.0, t / 0.006)
		buf[i] = (lp * 0.5 + sin(ph) * 0.28) * env * 0.6
	return _wav(buf)


## 參數化命中音：thump 低頻＋噪音爆，ring_freq>0 時加金屬殘響。
func _hit(thump_freq: float, noise_decay: float, thump_decay: float, ring_freq: float, dur: float) -> AudioStreamWAV:
	var n := _n(dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var phr := 0.0
	for i in n:
		var t := float(i) / SR
		ph += TAU * thump_freq / SR
		var noise := (randf() * 2.0 - 1.0) * exp(-t * noise_decay)
		var thump := sin(ph) * exp(-t * thump_decay)
		var ring := 0.0
		if ring_freq > 0.0:
			phr += TAU * ring_freq / SR
			ring = sin(phr) * exp(-t * 40.0) * 0.25
		buf[i] = (noise * 0.5 + thump * 0.6 + ring) * 0.7
	return _wav(buf)


func _sfx_skill() -> AudioStreamWAV:
	var n := _n(0.30)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / SR
		var frac := t / 0.30
		var freq: float = lerp(320.0, 860.0, frac)
		ph += TAU * freq / SR
		ph2 += TAU * freq * 1.5 / SR
		var env := minf(1.0, t / 0.01) * exp(-t * 6.0)
		buf[i] = (sin(ph) * 0.5 + sin(ph2) * 0.22) * env * 0.5
	return _wav(buf)


func _sfx_dash() -> AudioStreamWAV:
	var n := _n(0.16)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var white := randf() * 2.0 - 1.0
		lp += (white - lp) * 0.5
		var hp := white - lp                          # 高通＝氣聲
		var env := exp(-t * 22.0) * minf(1.0, t / 0.004)
		buf[i] = hp * env * 0.5
	return _wav(buf)


func _sfx_hurt() -> AudioStreamWAV:
	var n := _n(0.22)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var frac := t / 0.22
		var freq: float = lerp(150.0, 70.0, frac)
		ph += TAU * freq / SR
		var saw: float = (ph / TAU) - floor(ph / TAU)
		saw = saw * 2.0 - 1.0
		var env := exp(-t * 9.0)
		buf[i] = (saw * 0.4 + (randf() * 2.0 - 1.0) * 0.15) * env * 0.55
	return _wav(buf)


func _sfx_buy() -> AudioStreamWAV:
	return _arp([660.0, 990.0], 0.09, 0.4)


func _sfx_win() -> AudioStreamWAV:
	return _arp([523.0, 659.0, 784.0, 1046.0], 0.11, 0.42)


func _sfx_lose() -> AudioStreamWAV:
	return _arp([392.0, 294.0, 196.0], 0.16, 0.42)


## 簡易琶音：依序播放幾個音，每個帶衰減。
func _arp(freqs: Array, note_dur: float, amp: float) -> AudioStreamWAV:
	var per := _n(note_dur)
	var buf := PackedFloat32Array()
	buf.resize(per * freqs.size())
	for k in freqs.size():
		var ph := 0.0
		for i in per:
			var t := float(i) / SR
			ph += TAU * float(freqs[k]) / SR
			var env := minf(1.0, t / 0.008) * exp(-t * 7.0)
			buf[k * per + i] = sin(ph) * env * amp
	return _wav(buf)


# ============================================================
#  BGM 合成（A 小調 · Am-F-C-G 的憂鬱霓虹感）
# ============================================================
const BGM_PROG := [
	{"notes": [220.0, 261.63, 329.63], "bass": 110.0},   # Am
	{"notes": [174.61, 220.0, 261.63], "bass": 87.31},   # F
	{"notes": [261.63, 329.63, 392.0], "bass": 130.81},  # C
	{"notes": [196.0, 246.94, 293.66], "bass": 98.0},    # G
]


## 疊一個帶柔和起收的音（本身淡入淡出到近零，確保循環點無爆音）。
func _add_note(buf: PackedFloat32Array, freq: float, start_s: float, dur_s: float, amp: float) -> void:
	var n0 := int(start_s * SR)
	var nd := int(dur_s * SR)
	var atk := minf(0.35, dur_s * 0.4)
	var rel := minf(0.5, dur_s * 0.45)
	var ph := 0.0
	for i in nd:
		var idx := n0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t := float(i) / SR
		var env := 1.0
		if t < atk:
			env = t / atk
		elif t > dur_s - rel:
			env = maxf(0.0, (dur_s - t) / rel)
		ph += TAU * freq / SR
		var s := sin(ph) + sin(ph * 2.0) * 0.28 + sin(ph * 3.0) * 0.12
		buf[idx] += s * env * amp


## 正規化到 0.6 峰值並設為可循環。
func _loop_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var mx := 0.0001
	for v in buf:
		mx = maxf(mx, absf(v))
	var k := 0.6 / mx
	for i in buf.size():
		buf[i] *= k
	var w := _wav(buf)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w


## 大廳：緩慢的和弦墊音＋低音，氛圍安靜。
func _bgm_hall() -> AudioStreamWAV:
	var slot := 2.0
	var buf := PackedFloat32Array()
	buf.resize(_n(slot * BGM_PROG.size()))
	for c in BGM_PROG.size():
		var ch: Dictionary = BGM_PROG[c]
		var st := c * slot
		for f in ch.notes:
			_add_note(buf, f, st, slot * 0.96, 0.16)
		_add_note(buf, ch.bass, st, slot * 0.96, 0.22)
	return _loop_wav(buf)


## 夜行：同和弦但加入低音脈動與八分琶音，較有推進感。
func _bgm_night() -> AudioStreamWAV:
	var slot := 1.8
	var buf := PackedFloat32Array()
	buf.resize(_n(slot * BGM_PROG.size()))
	for c in BGM_PROG.size():
		var ch: Dictionary = BGM_PROG[c]
		var st := c * slot
		for f in ch.notes:
			_add_note(buf, f, st, slot * 0.9, 0.10)
		_add_note(buf, ch.bass, st, 0.5, 0.22)
		_add_note(buf, ch.bass, st + slot * 0.5, 0.5, 0.20)
		var tones: Array = ch.notes
		var steps := 8
		for s in steps:
			var f: float = float(tones[s % tones.size()]) * 2.0
			_add_note(buf, f, st + slot * float(s) / steps, slot / steps * 0.9, 0.09)
	return _loop_wav(buf)
