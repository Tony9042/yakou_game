extends Node
## 混搭流派 Demo — 驗證 §3 流派系統與 §3.4「本輪身分」是否如設計運作。
## 這是開發用的臨時測試場景，不屬於正式遊戲流程。
## 執行後，結果會印在編輯器下方的「輸出」面板。

func _ready() -> void:
	print("======== YAKOU 夜行 · 混搭流派 Demo ========")

	# 1) 先給一些殘留魂魄（正式遊戲由 SoulSystem.settle_run 產出，這裡直接塞值）
	SoulSystem.residual_souls = 20
	print("殘留魂魄：", SoulSystem.residual_souls)

	# 監聽複合技解鎖，投點時會即時印出
	TalentSystem.composite_unlocked.connect(func(cid): print("  ★ 自動解鎖複合技：", cid))

	# 2) 混搭投點：同時投「刀語」與「疾走」兩條流派
	print("\n--- 投點（刀語 × 疾走）---")
	TalentSystem.unlock_node("blade", "拔刀")   # 刀語 +1
	TalentSystem.unlock_node("blade", "残心")   # 刀語 +2（共 3 點）
	TalentSystem.unlock_node("rider", "突進")   # 疾走 +1
	TalentSystem.unlock_node("rider", "極速")   # 疾走 +2（共 3 點）

	print("流派傾向：", TalentSystem.invested_schools())
	print("刀語點數：", TalentSystem.points_in("blade"),
		"　疾走點數：", TalentSystem.points_in("rider"))
	print("觸發隊伍光環：", TalentSystem.active_auras())
	print("已解鎖複合技：", TalentSystem.unlocked_composites())

	# 3) 開始一夜，讓魂附身某具依代
	print("\n--- 開始一夜 ---")
	RunManager.generate_night(-1, "破傘之骸")
	print("本夜依代：", RunManager.current_vessel)

	# 4) 收容幾隻付喪神（納入魂魄囊）
	SoulSystem.contain_soul("提灯付喪神", 2)
	SoulSystem.contain_soul("傘化生", 1)

	# 5) 印出本輪身分＝依代 × 流派 × 付喪神（§3.4）
	print("\n======== 本輪身分 run_identity() ========")
	var identity: Dictionary = RunManager.run_identity()
	for key in identity:
		print("  ", key, "：", identity[key])

	print("\n（Demo 結束，可關閉此執行視窗）")
