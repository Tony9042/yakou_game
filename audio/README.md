# 音效 / 音樂

目前所有音效由 `systems/audio_manager.gd` **程式合成**，不需任何檔案即可有聲音。
想換成真素材時，把檔案放到對應路徑即可自動覆蓋，**不必改程式**。

## 音效（SFX）

放到 `res://audio/sfx/<名稱>.wav`，有同名檔就優先使用：

| 名稱 | 觸發時機 |
|---|---|
| `click.wav` | UI 按鈕 |
| `swing.wav` | 揮砍（音高隨連段升高） |
| `hit.wav` | 命中敵人 |
| `skill.wav` | 施放流派技能 |
| `dash.wav` | 疾走 |
| `hurt.wav` | 玩家受擊 |
| `buy.wav` | 黑市購買 / 橫丁投點 |
| `win.wav` | 戰鬥勝利 |
| `lose.wav` | 戰敗 |

## 音樂（BGM）

BGM 預設由程式合成（A 小調 Am-F-C-G，可循環）。放到以下路徑（建議 `.ogg`，會自動循環）即可覆蓋：

| 路徑 | 場景 |
|---|---|
| `res://audio/bgm/title.ogg` | 標題畫面 |
| `res://audio/bgm/hall.ogg` | 橫丁 |
| `res://audio/bgm/night.ogg` | 夜行 / 戰鬥 |

## 授權注意

若採用外部素材，請使用 CC0／可商用授權（如 freesound.org、itch.io 的 CC0 音效包），
並在此記錄來源與授權，避免日後上架的版權問題。

## 開關

遊戲內「≡ 選單」有「音效：開/關」可即時切換。
