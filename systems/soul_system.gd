extends Node
## SoulSystem — autoload 單例
## 對應企劃文件《第2章 魂魄系統》
## 管理「鎮壓／收容」選擇、魂魄囊容量、以及跑完一夜後的殘留魂魄結算。

signal soul_suppressed(soul_id: String)
signal soul_contained(soul_id: String)
signal satchel_full()
signal residual_souls_changed(new_total: int)

const MAX_SATCHEL_CAPACITY := 5

## 本輪收容中的魂魄： [{ id, quality, buff_type }]
var satchel: Array[Dictionary] = []

## 黑市「魂囊符」給的本夜額外容量（結算後歸零）。
var bonus_capacity := 0

## 永久貨幣，橫丁天賦樹／解鎖用
var residual_souls: int = 0


## 本夜有效的魂魄囊容量。
func capacity() -> int:
	return MAX_SATCHEL_CAPACITY + bonus_capacity


## 鎮壓：立即轉為本輪戰鬥增益，不佔容量、不會轉為殘留魂魄。
func suppress_soul(soul_id: String, buff: Dictionary) -> void:
	emit_signal("soul_suppressed", soul_id)
	_apply_temporary_buff(buff)


## 收容：納入魂魄囊，成為可切換隨行被動。若容量已滿則收容失敗。
func contain_soul(soul_id: String, quality: int) -> bool:
	if satchel.size() >= capacity():
		emit_signal("satchel_full")
		return false
	satchel.append({"id": soul_id, "quality": quality})
	emit_signal("soul_contained", soul_id)
	return true


func _apply_temporary_buff(buff: Dictionary) -> void:
	# TODO: 串接戰鬥系統的即時 buff 管理器（目前為介面預留）
	pass


## 一夜結束時呼叫（無論成功或戰死）。魂魄囊內容轉換為殘留魂魄。
## 戰死時只給一半轉換率，維持「輸掉一夜不等於歸零，但仍有代價」的手感。
func settle_run(run_success: bool) -> int:
	var multiplier := 1.0 if run_success else 0.5
	var gained := 0.0
	for soul in satchel:
		gained += float(soul.get("quality", 1)) * multiplier
	var gained_int := int(round(gained))
	residual_souls += gained_int
	emit_signal("residual_souls_changed", residual_souls)
	satchel.clear()
	bonus_capacity = 0          # 黑市加成僅限本夜
	return gained_int


func spend_residual_souls(amount: int) -> bool:
	if residual_souls < amount:
		return false
	residual_souls -= amount
	emit_signal("residual_souls_changed", residual_souls)
	return true
