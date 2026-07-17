extends Node
## RunManager — autoload 單例
## 對應企劃文件《第1章 核心遊戲循環》
## 管理「一夜」的節點地圖生成與進程，一夜結束時交給 SoulSystem 結算。

enum NodeType { ENCOUNTER, BLACK_MARKET, SIGHTING, CONTRACT, BOSS }

var current_map: Array = []
var current_index: int = -1
var run_active: bool = false

signal night_started(map: Array)
signal node_entered(node_type: NodeType)
signal night_ended(success: bool, residual_souls_gained: int)


## seed_value >= 0 時使用固定種子，對應企劃文件第8章「每日巷弄」的每日挑戰模式。
func generate_night(seed_value: int = -1) -> void:
	if seed_value >= 0:
		seed(seed_value)
	current_map = _build_node_sequence()
	current_index = -1
	run_active = true
	emit_signal("night_started", current_map)


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
