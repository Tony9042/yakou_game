extends Node
## TalentSystem — autoload 單例
## 對應企劃文件《第3章 角色客製與流派系統》
##
## 主角採「魂＋依代」雙層（§3.4）：流派不再綁定角色，任何主角皆可自由投點
## 並「同時投多棵樹混搭」（§3.2）。四棵樹改為由四位導師傳授的流派。
##
## 目前用 Dictionary 直接定義節點與複合技，之後想在編輯器裡調整數值，
## 可以改成讀取 data/talents/*.tres 這類 Resource 檔案，介面不需要變。

## 四種流派的靜態資料（導師見 §3.3，角色轉為橫丁 NPC）。
const SCHOOLS := {
	"blade":   {"name": "刀語", "mentor": "蓮", "role": "輸出"},
	"ward":    {"name": "結界", "mentor": "灯", "role": "控場輔助"},
	"rider":   {"name": "疾走", "mentor": "迅", "role": "機動"},
	"support": {"name": "羈絆", "mentor": "雫", "role": "續航"},
}

## 投入某流派達此點數即觸發隊伍光環（§4.1 以流派光環做軟性分工）。
const AURA_THRESHOLD := 2

## 各流派可投點的節點。cost 以殘留魂魄計。
var nodes := {
	"blade": {  # 蓮 / 刀語
		"拔刀": {"cost": 1, "unlocked": false, "desc": "單體爆發、高暴擊"},
		"居合": {"cost": 1, "unlocked": false, "desc": "反擊架勢，格擋後觸發強化攻擊"},
		"残心": {"cost": 2, "unlocked": false, "desc": "擊殺目標後延遲觸發範圍傷害"},
	},
	"ward": {  # 灯 / 結界
		"封印": {"cost": 1, "unlocked": false, "desc": "控場但不擊殺"},
		"加護": {"cost": 1, "unlocked": false, "desc": "隊伍護盾／持續治療"},
		"視":   {"cost": 1, "unlocked": false, "desc": "顯示隱藏節點與寶物位置"},
	},
	"rider": {  # 迅 / 疾走
		"突進": {"cost": 1, "unlocked": false, "desc": "位移技能可連段銜接"},
		"尾氣": {"cost": 1, "unlocked": false, "desc": "移動路徑留下範圍傷害"},
		"極速": {"cost": 2, "unlocked": false, "desc": "減防換取指數級加速與爆發"},
	},
	"support": {  # 雫 / 羈絆
		"馴養": {"cost": 1, "unlocked": false, "desc": "提升收容成功率與魂魄囊容量"},
		"修復": {"cost": 1, "unlocked": false, "desc": "多人模式下的復活與續航技能"},
		"拾荒": {"cost": 1, "unlocked": false, "desc": "戰利品與殘留魂魄產出提升"},
	},
}

## 跨流派複合技（§3.2 交會節點）：需同時在兩條流派各投入 req_points 點才解鎖，
## 鼓勵混搭而非單線深投。達標時自動解鎖並發出 composite_unlocked。
var composite_skills := {
	"刹那尾刃": {
		"schools": ["blade", "rider"], "req_points": 2, "unlocked": false,
		"desc": "刀語×疾走：突進終點觸發拔刀斬，位移即爆發",
	},
	"守燈之陣": {
		"schools": ["ward", "support"], "req_points": 2, "unlocked": false,
		"desc": "結界×羈絆：結界範圍內隊友額外回復並提升收容成功率",
	},
	"疾風拾遺": {
		"schools": ["rider", "support"], "req_points": 2, "unlocked": false,
		"desc": "疾走×羈絆：高速移動時自動拾取沿途殘留魂魄",
	},
	"居合封魂": {
		"schools": ["blade", "ward"], "req_points": 2, "unlocked": false,
		"desc": "刀語×結界：居合命中被封印目標時必定收容成功",
	},
}

signal node_unlocked(school_id: String, node_name: String)
signal school_reset(school_id: String)
signal composite_unlocked(composite_id: String)
signal aura_state_changed(active_auras: Array)


func unlock_node(school_id: String, node_name: String) -> bool:
	if not nodes.has(school_id) or not nodes[school_id].has(node_name):
		return false
	var node: Dictionary = nodes[school_id][node_name]
	if node["unlocked"]:
		return false
	if not SoulSystem.spend_residual_souls(node["cost"]):
		return false
	node["unlocked"] = true
	emit_signal("node_unlocked", school_id, node_name)
	_refresh_composites()
	emit_signal("aura_state_changed", active_auras())
	return true


## 用殘留魂魄重置單一流派（避免玩家因試錯而卡死一條線）。
func respec(school_id: String, respec_cost: int) -> bool:
	if not nodes.has(school_id):
		return false
	if not SoulSystem.spend_residual_souls(respec_cost):
		return false
	for node_name in nodes[school_id]:
		nodes[school_id][node_name]["unlocked"] = false
	emit_signal("school_reset", school_id)
	_refresh_composites()
	emit_signal("aura_state_changed", active_auras())
	return true


## 該流派已投入的點數（已解鎖節點的 cost 總和）。
func points_in(school_id: String) -> int:
	if not nodes.has(school_id):
		return 0
	var total := 0
	for node_name in nodes[school_id]:
		if nodes[school_id][node_name]["unlocked"]:
			total += int(nodes[school_id][node_name]["cost"])
	return total


## 目前有投點的流派 id 陣列——這就是本輪 build 的「流派傾向」（§3.4）。
func invested_schools() -> Array:
	var result: Array = []
	for school_id in nodes:
		if points_in(school_id) > 0:
			result.append(school_id)
	return result


## 該流派是否已達光環門檻（§4.1）。
func aura_ready(school_id: String) -> bool:
	return points_in(school_id) >= AURA_THRESHOLD


## 目前已觸發的隊伍光環（達門檻的流派 id 陣列）。
func active_auras() -> Array:
	var result: Array = []
	for school_id in nodes:
		if aura_ready(school_id):
			result.append(school_id)
	return result


## 檢查所有複合技，將新達標者標記為已解鎖並發出訊號。
func _refresh_composites() -> void:
	for composite_id in composite_skills:
		var c: Dictionary = composite_skills[composite_id]
		if c["unlocked"]:
			continue
		var met := true
		for school_id in c["schools"]:
			if points_in(school_id) < int(c["req_points"]):
				met = false
				break
		if met:
			c["unlocked"] = true
			emit_signal("composite_unlocked", composite_id)


## 目前已解鎖的複合技 id 陣列。
func unlocked_composites() -> Array:
	var result: Array = []
	for composite_id in composite_skills:
		if composite_skills[composite_id]["unlocked"]:
			result.append(composite_id)
	return result
