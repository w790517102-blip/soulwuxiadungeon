# Claude 工作日誌（給未來的我自己看）

> 對話被壓縮後會失去細節；每完成一段工作就在最上面追加一筆。老闆說「commit」＝「先commit」才提交，不要自動 commit。
> 老闆用繁體中文。協作者：共邊國／小知（美術、文本），CODEX（舊的工程）。

## 專案速記
- Godot 4.4.1，執行檔：`C:\Users\user\Desktop\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe`
  - 測試：`--headless --path . --script tests/xxx.gd`，看 PASS／FAIL。載入檢查：`--headless --path . --quit`。
- Windows Git Bash：`python` 是商店殼，用 `py`；heredoc 會吃掉反斜線，含 `\n` 的檔案用 Write 工具寫。
- 詞彙：「蛋黃」＝滑鼠點選區（Mouse Selection Zone）、「蛋白」＝有效互動距離（Interaction Range），細節看 `docs/exploration_interaction.md`。
- 選單頁面：`scripts/inventory/*Page.gd`（StudyShell 風格書房卷軸）；`scripts/system_menu.gd` 管分頁。美術規格在 `docs/system_menu/`。

## 對話格式統一（已大致完成，2026-10-25～26）
- 角色：`名稱：「…」`；劉語塵心想：`劉語塵：「（心想）…」`；私下動作 `（你…）`。
- 旁白：上方框（speaker 0）= 紅徽音／NPC 的動作、環境、系統提示。
  下方框（劉語塵同側，speaker 2、無頭像）= 第二人稱（你想起／你發現…）與劉語塵內心。
  `DialogTextLayout.is_second_person_narration()` 會自動判斷「你」當主語的句子；沒有「你」字的內心句要用各腳本的 `_y()` 手動指定。
- 分頁排版在 `scripts/DialogTextLayout.gd`；手動 `\n` 只留給詩詞。
- 茶坊：掌櫃初見旗標 `met_yuheng_teahouse_boss` 不可再由客棧老闆腳本設定（已修）。
- 尚未做：谷影入藥(herb_seller)、渠燈補封的格式轉換；「（動作）「台詞」」混合句沒拆；書眠／白書眠命名一致性（正式名稱寫「白書眠」，id 仍是 shumian）。
- 老闆說舊存檔無所謂，只要新遊戲正確。

## 目前的待辦順序（老闆定的）
1. 選單美術：只剩 **隊伍頁**、**任務頁**（狀態頁還在等共邊國的數值圖示等素材）。**先做隊伍頁**。
2. 回頭補完蛋白蛋黃區：客棧、廣場、市集、醉月茶坊（含夜晚）每個 NPC 與傳送點的手畫點選區與有效互動區。

## 日誌
- 2026-10-26：commit b70bc34 等；對話旁白分上下框、紅徽音情緒銜接與銅釦段落改寫（銅釦說明改放 ItemDB）。開始準備隊伍頁。
- 2026-10-26：**隊伍頁**新版 `scripts/inventory/PartyPage.gd`（開關 `USE_NEW_PARTY_UI` 在 system_menu.gd，掛接函式 `_update_party_page`）。
  左＝上陣三格（沿用 rebuild_roster）、中＝候補清單、右＝詳情＋移入／移出。隊伍已滿時先點一位上陣隊員當換下對象。
  測試 `tests/test_party_page.gd`；截圖腳本在 scratchpad（party_shot.gd，非 headless 跑，1600×900 輸出）。素材全用現有書房套件，共邊國還沒交隊伍頁專用圖。
  備註：`tests/test_battle_message_and_menus.gd` 的「share window dimensions」會失敗，是戰鬥彈窗，與選單無關（先前就在，沒查）。
  下一步：任務頁（舊頁節點 `VBoxContainer/任務`，邏輯在 system_menu.gd `_refresh_quest_tab`、`_build_quest_entries`）。
  （同日追加）隊伍頁右頁下方加了八格裝備（只顯示）；移入／移出按鈕移到中頁底部。待討論：頭像要怎麼處理（老闆說等等談）。
