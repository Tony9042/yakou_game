extends Node
## RunManager — autoload 單例
## 對應企劃文件《第1章 核心遊戲循環》
## 管理「一夜」的節點地圖生成與進程，一夜結束時交給 SoulSystem 結算。

enum NodeType { ENCOUNTER, BLACK_MARKET, SIGHTING, CONTRACT, BOSS }

## 依代（軀殼）範例——魂每夜附身的可客製身體（§3.4）。之後可改為讀取玩家客製資料。
const VESSELS := ["破傘之骸", "廢棄自販機", "斷線街燈", "無主招牌"]

var current_map: Array = []
var current_index: int = -1
var run_active: bool = false

## 本輪魂所附的依代（§3.4 客製展示層）。
var current_vessel: String = ""

signal night_started(map: Array)
signal node_entered(node_type: NodeType)
signal night_ended(success: bool, residual_souls_gained: int)


## seed_value >= 0 時使用固定種子，對應企劃文件第8章「每日巷弄」的每日挑戰模式。
## vessel 為本輪選用的依代；留空則依當前隨機狀態挑一具。
func generate_night(seed_value: int = -1, vessel: String = "") -> void:
	if seed_value >= 0:
		seed(seed_value)
	current_vessel = vessel if vessel in VESSELS else VESSELS[randi() % VESSELS.size()]
	current_map = _build_node_sequence()
	current_index = -1
	run_active = true
	emit_signal("night_started", current_map)


## 本輪身分＝依代 × 流派傾向 × 收容的付喪神（§3.4）。
## 把三個系統的當前狀態組成一份摘要，方便 UI 展示與「感受混搭 build」。
func run_identity() -> Dictionary:
	var schools: Array = []
	for school_id in TalentSystem.invested_schools():
		schools.append(TalentSystem.SCHOOLS[school_id]["name"])
	var contained: Array = []
	for soul in SoulSystem.satchel:
		contained.append(soul.get("id", "?"))
	return {
		"vessel": current_vessel,
		"schools": schools,
		"auras": TalentSystem.active_auras(),
		"composites": TalentSystem.unlocked_composites(),
		"contained_souls": contained,
	}


func _build_node_sequence() -> Array:
	var sequence: Array = []
	var pool: Array = [
		NodeType.ENCOUNTER, NodeType.ENCOUNTER,
		NodeType.BLACK_MARKET, NodeType.SIGHTING, NodeType.CONTRACT,
	]
	pool.shuffle()
	sequence.append_array(pool)
	sequence.append(NodeType.BOSS)  # 深夜案件固定在最後
	return sequence


## 前進到下一個節點；抵達地圖尾端（Boss 之後）視為撤離成功。
func advance() -> NodeType:
	if not run_active:
		return -1
	current_index += 1
	if current_index >= current_map.size():
		end_run(true)
		return -1
	var node_type: NodeType = current_map[current_index]
	emit_signal("node_entered", node_type)
	return node_type


func end_run(success: bool) -> void:
	run_active = false
	var gained := SoulSystem.settle_run(success)
	emit_signal("night_ended", success, gained)
