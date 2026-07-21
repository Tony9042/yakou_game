class_name CharacterData
extends Resource
## 角色資料容器。對應企劃文件《第3章 角色客製與流派系統》。
## 四名角色現為橫丁導師 NPC（§3.3、§5.5），同時作為以其命名的「預設流派模板」
## 起手式（§3.0）——下方數值即該模板的建議起始傾向。
## 之後可在 Godot 編輯器的 Inspector 直接調整數值，不需要改程式碼。

@export var id: String                     # 內部識別碼，例如 "ren"
@export var display_name: String           # 顯示名稱，例如 "蓮"
@export var romaji: String                 # 例如 "REN"
@export var role: String                   # 例如 "太刀使い / BLADE"
@export var title: String                  # 稱號，例如 "拔刀夜叉"
@export_multiline var blurb: String         # 角色簡介
@export var kanji: String                  # 卡片背景大漢字
@export var school_id: String               # 此導師所傳授的流派 id（對應 talent_system.gd 的 SCHOOLS）

@export_group("基礎數值")
@export_range(0, 100) var atk: int = 50
@export_range(0, 100) var spd: int = 50
@export_range(0, 100) var def: int = 50
