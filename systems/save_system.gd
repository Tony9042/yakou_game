extends Node
## SaveSystem — autoload 單例。
## 將 meta 進度（殘留魂魄、流派投點、已解鎖複合技）存到 user:// 的 JSON。
## 本輪魂魄囊（satchel）屬單夜暫存，不寫入存檔。

const SAVE_PATH := "user://yakou_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var talents := {}
	for sid in TalentSystem.nodes:
		var unlocked: Array = []
		for node_name in TalentSystem.nodes[sid]:
			if TalentSystem.nodes[sid][node_name]["unlocked"]:
				unlocked.append(node_name)
		talents[sid] = unlocked
	var data := {
		"residual_souls": SoulSystem.residual_souls,
		"talents": talents,
		"composites": TalentSystem.unlocked_composites(),
		"story": {
			"act": StorySystem.act,
			"seen_sightings": StorySystem.seen_sightings,
			"contained_total": StorySystem.contained_total,
			"suppressed_total": StorySystem.suppressed_total,
			"finished": StorySystem.finished,
		},
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false

	_reset()
	SoulSystem.residual_souls = int(data.get("residual_souls", 0))

	var talents: Variant = data.get("talents", {})
	if typeof(talents) == TYPE_DICTIONARY:
		for sid in talents:
			if not TalentSystem.nodes.has(sid):
				continue
			for node_name in talents[sid]:
				if TalentSystem.nodes[sid].has(node_name):
					TalentSystem.nodes[sid][node_name]["unlocked"] = true

	var comps: Variant = data.get("composites", [])
	if typeof(comps) == TYPE_ARRAY:
		for cid in comps:
			if TalentSystem.composite_skills.has(cid):
				TalentSystem.composite_skills[cid]["unlocked"] = true

	var story: Variant = data.get("story", {})
	if typeof(story) == TYPE_DICTIONARY:
		StorySystem.act = int(story.get("act", 0))
		StorySystem.contained_total = int(story.get("contained_total", 0))
		StorySystem.suppressed_total = int(story.get("suppressed_total", 0))
		StorySystem.finished = bool(story.get("finished", false))
		var seen: Variant = story.get("seen_sightings", [])
		if typeof(seen) == TYPE_ARRAY:
			StorySystem.seen_sightings = []
			for v in seen:
				StorySystem.seen_sightings.append(int(v))
	return true


func new_game() -> void:
	_reset()
	SoulSystem.residual_souls = 10


## 把所有 meta 進度歸零（新遊戲／載入前清空）。
func _reset() -> void:
	SoulSystem.satchel.clear()
	SoulSystem.residual_souls = 0
	StorySystem.reset()
	for sid in TalentSystem.nodes:
		for node_name in TalentSystem.nodes[sid]:
			TalentSystem.nodes[sid][node_name]["unlocked"] = false
	for cid in TalentSystem.composite_skills:
		TalentSystem.composite_skills[cid]["unlocked"] = false
