extends Node
## TalentSystem — autoload 單例
## 對應企劃文件《第3章 天賦系統》
## 目前用 Dictionary 直接定義四棵樹的節點，之後想在編輯器裡調整數值，
## 可以改成讀取 data/talents/*.tres 這類 Resource 檔案，介面不需要變。

var trees := {
	"blade_tree": {  # 蓮 / 刀語
		"拔刀": {"cost": 1, "unlocked": false, "desc": "單體爆發、高暴擊"},
		"居合": {"cost": 1, "unlocked": false, "desc": "反擊架勢，格擋後觸發強化攻擊"},
		"残心": {"cost": 2, "unlocked": false, "desc": "擊殺目標後延遲觸發範圍傷害"},
	},
	"ward_tree": {  # 灯 / 結界
		"封印": {"cost": 1, "unlocked": false, "desc": "控場但不擊殺"},
		"加護": {"cost": 1, "unlocked": false, "desc": "隊伍護盾／持續治療"},
		"視":   {"cost": 1, "unlocked": false, "desc": "顯示隱藏節點與寶物位置"},
	},
	"rider_tree": {  # 迅 / 疾走
		"突進": {"cost": 1, "unlocked": false, "desc": "位移技能可連段銜接"},
		"尾氣": {"cost": 1, "unlocked": false, "desc": "移動路徑留下範圍傷害"},
		"極速": {"cost": 2, "unlocked": false, "desc": "減防換取指數級加速與爆發"},
	},
	"support_tree": {  # 雫 / 羈絆
		"馴養": {"cost": 1, "unlocked": false, "desc": "提升收容成功率與魂魄囊容量"},
		"修復": {"cost": 1, "unlocked": false, "desc": "多人模式下的復活與續航技能"},
		"拾荒": {"cost": 1, "unlocked": false, "desc": "戰利品與殘留魂魄產出提升"},
	},
}

signal node_unlocked(tree_id: String, node_name: String)
signal tree_reset(tree_id: String)


func unlock_node(tree_id: String, node_name: String) -> bool:
	if not trees.has(tree_id) or not trees[tree_id].has(node_name):
		return false
	var node: Dictionary = trees[tree_id][node_name]
	if node["unlocked"]:
		return false
	if not SoulSystem.spend_residual_souls(node["cost"]):
		return false
	node["unlocked"] = true
	emit_signal("node_unlocked", tree_id, node_name)
	return true


## 用殘留魂魄重置整棵樹（避免玩家因試錯而卡死一條線）。
func respec(tree_id: String, respec_cost: int) -> bool:
	if not trees.has(tree_id):
		return false
	if not SoulSystem.spend_residual_souls(respec_cost):
		return false
	for node_name in trees[tree_id]:
		trees[tree_id][node_name]["unlocked"] = false
	emit_signal("tree_reset", tree_id)
	return true
