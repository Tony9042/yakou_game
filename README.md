# YAKOU 夜行 — 專案骨架

這是把《夜行 YAKOU》企劃文件轉成的 Godot 4 專案骨架。目前只有**系統架構**，還沒有場景、美術、戰鬥手感——目的是先把企劃文件裡的規則變成可以實際運作、之後能被場景呼叫的程式碼，不是一個能玩的 demo。

## 怎麼打開

1. 安裝 [Godot 4.x](https://godotengine.org/)（開源免費，見前面對話）
2. 開啟 Godot → Import → 選這個資料夾裡的 `project.godot`
3. 四個系統會自動以 Autoload 單例的形式載入（`Project > Project Settings > Autoload` 可以看到）

## 資料夾結構

```
yakou_game/
├── project.godot              # Godot 專案設定，已註冊四個 autoload
├── README.md                  # 這份文件
├── docs/
│   └── yakou_game_design.md   # 完整企劃文件，程式碼架構都是照這份寫的
├── data/
│   └── characters/
│       ├── character_data.gd  # 角色資料的 Resource 類別定義
│       ├── ren.tres            # 蓮
│       ├── akari.tres          # 灯
│       ├── jin.tres             # 迅
│       └── shizuku.tres        # 雫
└── systems/
    ├── soul_system.gd       # 第2章 魂魄系統（鎮壓／收容／殘留魂魄）
    ├── talent_system.gd     # 第3章 天賦系統（四棵樹、投點、重置）
    ├── run_manager.gd       # 第1章 核心循環（節點地圖、每日巷弄種子）
    └── streamer_hooks.gd    # 第8章 實況主友善設計（委託／殘影／投票介面）
```

## 企劃文件章節 ↔ 程式碼對照

| 企劃文件章節 | 對應程式碼 |
|---|---|
| 第1章 核心遊戲循環 | `systems/run_manager.gd` |
| 第2章 魂魄系統 | `systems/soul_system.gd` |
| 第3章 天賦系統 | `systems/talent_system.gd`、`data/characters/*.tres` |
| 第8章 實況主友善設計 | `systems/streamer_hooks.gd` |
| 第4、5、6章（多人／敘事／霓虹機制） | 尚未轉成程式碼，需要先有場景與戰鬥系統才能實作 |

## 建議的下一步

1. 在 Godot 裡建一個空場景，寫一小段測試腳本呼叫 `RunManager.generate_night()`，在輸出視窗確認節點序列有正確生成
2. 幫 `soul_system.gd` 的 `_apply_temporary_buff()` 接上實際的戰鬥數值系統
3. 把 `character_data.gd` 的四個 `.tres` 資料串進角色選擇畫面
4. `streamer_hooks.gd` 目前只是介面層，之後要接 Twitch 聊天室，需要另外寫一個外部 bot（Node.js 或 Python 都可以）呼叫這裡的方法——這部分等核心玩法穩定後再做，優先度最低

## 已知限制

- 這些系統目前完全沒有經過 Godot 編輯器實際跑過（本環境無法安裝/執行 Godot GUI），語法照 Godot 4.3 慣例撰寫，第一次開啟時建議留意 Godot 版本落差可能造成的小語法差異
- `soul_system.gd` 的魂魄轉換數值、`talent_system.gd` 的天賦花費都是企劃階段的示意數字，還沒經過實際遊戲測試平衡
