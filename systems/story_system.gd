extends Node
## StorySystem — autoload 單例。
## 對應企劃《第5章 敘事結構》：幕次推進（§5.4）、目擊碎片（§5.0-1）、
## 導師對話（§5.5）、守夜人三層揭示（§5.2）、結局傾向（§5.6）。

## 幕＝正被拆除的街區。每存活一夜推進一幕，形成「城正一塊塊消失」的倒數。
const ACTS := [
	{
		"label": "序", "zone": "商店街",
		"intro": "第一塊街區已經圍起施工圍籬。鐵皮上噴著紅色的「拆」。\n你在黃昏醒來，不記得自己是誰，只知道今夜還有誰沒被帶回家。",
		"outro": "商店街的招牌一盞盞熄了。你伸手想扶住牆，指尖卻穿了過去。",
	},
	{
		"label": "一", "zone": "高架橋下",
		"intro": "怪手開進了高架橋下。橋墩的陰影裡，蜷著不肯走的東西。",
		"outro": "有人在橋下叫住你，話到嘴邊又嚥了回去——那眼神像是認錯了人，又像是沒認錯。",
	},
	{
		"label": "二", "zone": "地下道",
		"intro": "地下道封閉在即。牆上的塗鴉是孩童的身高刻痕，最後一道停在三年前。",
		"outro": "街區又少了一塊。你發現自己也淡了一分——你與這條街，是同一條命。",
	},
	{
		"label": "三", "zone": "廢棄公寓",
		"intro": "廢棄公寓今夜清空。開發者站在門口等你，手裡沒有武器，只有一紙公文。",
		"outro": "「你不能永遠收容過去。」他說得沒有錯，這才是最難受的地方。",
	},
	{
		"label": "終", "zone": "頂樓天台 · 橫丁核心",
		"intro": "只剩最後一塊了。頂樓天台上，由拆除令與遺忘凝成的「拆」之魂，正等著你。",
		"outro": "抹除與收容，在天台上照見了彼此。",
	},
]

## 守夜人三層揭示（§5.2），於指定幕結束時觸發。
const REVEALS := {
	0: "【無身之魂】你借的是遺棄之物的軀殼。魂沒有形體，卻仍會痛。\n——我到底是什麼？",
	2: "【與街同命】街被拆去一塊，你就虛弱一分。你離不開這裡，因為你本就屬於這裡。\n——我為何離不開這條街？",
	4: "【守夜人的遺願】你想起來了。\n生前你是這片橫丁的守夜人——徹夜修補舊物、收留流浪的人與物。\n正因這份溫柔，街上的東西才活得夠久，善良地化為付喪神。\n改造令下的那夜，你不肯離開，殞落在第一塊被拆的街區。\n未竟的執念化為這縷夜行之魂：「我還沒把大家都帶回家。」",
}

## 目擊碎片。act_min＝需推進到第幾幕才會出現。
const SIGHTINGS := [
	{"act_min": 0, "text": "捲門上噴著紅色的「拆」字。你看著它，胸口莫名發疼。"},
	{"act_min": 0, "text": "一隻提灯付喪神縮在拆除告示牌後。牠不兇，只是不想被撕下來。"},
	{"act_min": 0, "text": "自販機還亮著，投幣口塞著一張紙條：「謝謝你一直亮著。」"},
	{"act_min": 1, "text": "騎樓下的貓碗積了水。有人每天換水，換到某一天就停了。"},
	{"act_min": 1, "text": "傘架上還插著一把破傘。傘骨斷了三根，卻被人細心纏上了膠帶。"},
	{"act_min": 2, "text": "你想扶住牆，指尖穿了過去。你想起自己沒有身體——這件事每次想起都像第一次。"},
	{"act_min": 2, "text": "一隻付喪神跟了你半條街，最後停在自己原本待的騎樓下，不肯再走。"},
	{"act_min": 3, "text": "廢棄公寓的信箱裡有封沒寄出的信，收件人欄寫著一個你說不出口的名字。"},
	{"act_min": 3, "text": "牆角堆著修理工具，握柄被磨得發亮。你的手比你先認得它們。"},
]

## 導師對話（§5.5）：投該流派點數達門檻逐層解鎖。
## 四位導師都是守夜人生前收留、教養的人——他們比主角更早認出你是誰。
const MENTOR_LINES := {
	"blade": [
		"蓮：「你握刀的方式……算了，是我多心。」",
		"蓮：「以前有個人，總在打烊後替整條街修門鎖。他也是這樣，出手前先沉默三秒。」",
		"蓮：「那人沒能離開這條街。你說你不記得生前——那你記得為什麼非留在這裡不可嗎？」",
	],
	"ward": [
		"灯：「你身上有這條街的氣味。不是氣味，是……牽掛。」",
		"灯：「我學的是安撫而非消滅。是有人教的，他說『牠們只是太久沒被溫柔對待』。」",
		"灯：「我替他做過一場沒有遺體的法事。那一夜，第一個街區被拆了。」",
	],
	"rider": [
		"迅：「跑這麼快幹嘛，這條街又不會跑掉。……抱歉，我說錯話了。」",
		"迅：「我本來是逃出來的小孩。有人沒問我從哪來，就先給了我一碗熱的。」",
		"迅：「我一直在跑，是不敢停下來看這條街變成什麼樣。你呢？你為什麼不走？」",
	],
	"support": [
		"雫：「你撿東西的手勢……很像我認識的一個人。」",
		"雫：「他教我，壞掉的東西不是垃圾，是還沒被好好對待。這條街的付喪神，多半是他養出來的。」",
		"雫：「守夜人。大家都這麼叫他。他最後說的是——『我還沒把大家都帶回家』。」",
	],
}

## 導師對話的投點門檻（各流派最高可投 3～4 點）。
const MENTOR_TIERS := [1, 2, 3]

var act := 0                      # 目前幕次（0..4）
var seen_sightings: Array = []    # 已看過的目擊碎片索引
var seen_acts: Array = []         # 已播過進場演出的幕次（死亡重跑不再重播）
var contained_total := 0          # 收容累計（結局傾向，§5.6）
var suppressed_total := 0         # 鎮壓累計
var finished := false             # 是否已走完終幕

signal act_advanced(new_act: int)
signal reveal_shown(text: String)


func current_act() -> Dictionary:
	return ACTS[clampi(act, 0, ACTS.size() - 1)]


func act_title() -> String:
	var a := current_act()
	return "第%s幕 · %s" % [a.label, a.zone]


func is_final_act() -> bool:
	return act >= ACTS.size() - 1


## 抽一則尚未看過的目擊碎片；若當前幕的都看完了則允許重複。
func next_sighting() -> String:
	var pool: Array = []
	for i in SIGHTINGS.size():
		if SIGHTINGS[i].act_min <= act and not seen_sightings.has(i):
			pool.append(i)
	if pool.is_empty():
		for i in SIGHTINGS.size():
			if SIGHTINGS[i].act_min <= act:
				pool.append(i)
		if pool.is_empty():
			return SIGHTINGS[0].text
	var pick: int = pool[randi() % pool.size()]
	if not seen_sightings.has(pick):
		seen_sightings.append(pick)
	return SIGHTINGS[pick].text


## 存活一夜後推進幕次。回傳本次要顯示的揭示文字（沒有則為空字串）。
func advance_act() -> String:
	var reveal: String = REVEALS.get(act, "")
	if is_final_act():
		finished = true
	else:
		act += 1
		act_advanced.emit(act)
	if reveal != "":
		reveal_shown.emit(reveal)
	return reveal


func record_choice(is_contain: bool) -> void:
	if is_contain:
		contained_total += 1
	else:
		suppressed_total += 1


## 結局傾向（§5.6）：持有／放手／承接。
func ending() -> Dictionary:
	var total := contained_total + suppressed_total
	if total == 0:
		return {"name": "承接", "text": "你既未緊握，也未鬆手——這條街的故事還沒寫完。"}
	var ratio := float(contained_total) / float(total)
	if ratio >= 0.65:
		return {
			"name": "持有",
			"text": "你把一切都留下了。街區被記憶凍結，付喪神都有了歸處——\n只是這縷魂再也散不去，也無法安息。溫柔，而且悲傷。",
		}
	if ratio <= 0.35:
		return {
			"name": "放手",
			"text": "你讓該結束的結束。執念被鄭重送走，魂終於得以安息——\n街變了樣，但記憶被好好記住了。釋然，帶著一點惆悵。",
		}
	return {
		"name": "承接",
		"text": "你既不凍結，也不抹除。你帶著物與人的依附，一起遷向新的城——\n守夜人的溫柔，在別處繼續亮著。這是最難走的第三條路。",
	}


## 已解鎖的導師對話層數（0～3），依該流派投點決定。
func mentor_tier(school_id: String) -> int:
	var pts: int = TalentSystem.points_in(school_id)
	var tier := 0
	for i in MENTOR_TIERS.size():
		if pts >= MENTOR_TIERS[i]:
			tier = i + 1
	return tier


## 該流派目前可顯示的導師台詞（未投點則為空字串）。
func mentor_line(school_id: String) -> String:
	var tier := mentor_tier(school_id)
	if tier <= 0:
		return ""
	return MENTOR_LINES[school_id][tier - 1]


## 導師的顯示資訊（給對話演出用）。
const MENTOR_META := {
	"blade":   {"name": "蓮", "color": "ff3d81", "side": "left"},
	"ward":    {"name": "灯", "color": "ffb45a", "side": "right"},
	"rider":   {"name": "迅", "color": "38e1e8", "side": "left"},
	"support": {"name": "雫", "color": "a97bff", "side": "right"},
}


## 該流派目前已解鎖的全部導師台詞，轉成對話演出格式。
func mentor_dialogue(school_id: String) -> Array:
	var tier := mentor_tier(school_id)
	var meta: Dictionary = MENTOR_META[school_id]
	var out: Array = []
	for i in tier:
		var raw: String = MENTOR_LINES[school_id][i]
		var body := raw
		var sep := raw.find("：")
		if sep >= 0:
			body = raw.substr(sep + 1)
		out.append({
			"name": meta.name,
			"kanji": meta.name,
			"color": Color(meta.color),
			"side": meta.side,
			"text": body,
		})
	return out


## 本幕的進場演出是否還沒播過；回傳 true 並標記為已播（死亡重跑就不再重複）。
func consume_act_intro() -> bool:
	if seen_acts.has(act):
		return false
	seen_acts.append(act)
	return true


## 旁白行（幕次進場／收場／揭示）。
func narration(text: String) -> Array:
	var out: Array = []
	for para in text.split("\n"):
		var s := String(para).strip_edges()
		if s != "":
			out.append({"name": "", "text": s})
	return out


func reset() -> void:
	act = 0
	seen_sightings = []
	seen_acts = []
	contained_total = 0
	suppressed_total = 0
	finished = false
