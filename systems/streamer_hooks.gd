extends Node
## StreamerHooks — autoload 單例
## 對應企劃文件《第8章 實況主友善設計》
##
## 這裡只定義「遊戲端」要暴露出來的介面。實際連上 Twitch／YouTube 聊天室
## 需要另外寫一個外部服務（例如 Node.js 或 Python 的聊天機器人），
## 由那個外部服務呼叫這裡的 submit_commission() / run_chat_vote() 等方法，
## 或是透過 Godot 的 WebSocket / HTTP 節點自行接上聊天室 API。

signal commission_received(commission: Dictionary)
signal viewer_afterimage_spawned(afterimage: Dictionary)
signal vote_result(options: Array, winning_index: int)

## 直播模式開關，關閉時不會觸發觀眾殘影／投票等機制。
var streamer_mode_enabled: bool = false

## 觀眾殘影出現機率，企劃文件建議偏低，避免每輪都出現而失去新鮮感。
var viewer_afterimage_chance: float = 0.08


## 委託節點：觀眾用頻道點數提交委託（指定敵人／追加詛咒／追加祝福）。
## 主播端仍可選擇是否接受，不強制生效。
func submit_commission(viewer_name: String, request_type: String, payload: Dictionary) -> void:
	var commission := {
		"viewer": viewer_name,
		"type": request_type,
		"payload": payload,
	}
	emit_signal("commission_received", commission)


## 觀眾殘影：從觀眾提交的配置池中，依機率抽出一位客串援軍。
func try_spawn_viewer_afterimage(afterimage_pool: Array) -> void:
	if not streamer_mode_enabled or afterimage_pool.is_empty():
		return
	if randf() < viewer_afterimage_chance:
		var chosen = afterimage_pool[randi() % afterimage_pool.size()]
		emit_signal("viewer_afterimage_spawned", chosen)


## 岔路投票：訂閱者權重較高，避免免費帳號灌票亂投。
## votes 格式： { option_index: {"normal": int, "subscriber": int} }
func run_chat_vote(options: Array, votes: Dictionary, subscriber_weight: float = 2.0) -> int:
	var best_index := 0
	var best_score := -1.0
	for i in options.size():
		var v: Dictionary = votes.get(i, {"normal": 0, "subscriber": 0})
		var score: float = v.get("normal", 0) + v.get("subscriber", 0) * subscriber_weight
		if score > best_score:
			best_score = score
			best_index = i
	emit_signal("vote_result", options, best_index)
	return best_index
