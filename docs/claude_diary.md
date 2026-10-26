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
- 2026-10-26：**頭像整合（進行中，樣本階段）**。老闆決定：對話立繪自成一套（不併入卡面／紙娃娃）；見聞錄「豪傑」也用文戲立繪；來源原檔在 `assets/Character/`（1024×1536 全身圖，紙紋背景，要去背）。
  - 已裝 `rembg`（pip）＋ isnet-anime 模型（老闆同意下載，在 `~/.u2net/`）。流程腳本在 scratchpad：`matte.py`（去背）→ `make_headshots.py`（裁頭肩、邊緣收 1px、左右淡出、保留底邊切線、輸出 `*_headshot_v2.png`）。
  - 書眠用 `Su_mien.jpg`（最新，墨潑風格；`Su_mien1.jpg` 是舊版別用）。**列霄先不做**（只是早期測三人團戰），先做**左飲**。
  - 新規格：檔案＝實際美術大小（無外圈留白），底邊中心對齊對話框底緣、顯示高度 245（`DialogManager.HEADSHOT_TIGHT_HEIGHT`），肩膀完整；舊 200×280 檔案照舊行為（`_place_headshot` 以尺寸判斷）。
  - 樣本：劉語塵／書眠／左飲 `_v2.png`，對照圖 `docs/system_menu/headshot_v2_dialog_samples.png`。**尚未替換遊戲內引用，待老闆驗收。**
  - 後續：驗收後批次處理其他有原檔的角色（紅徽音、顧石、單步雷、折簷翁…）、更新引用（TeamData portrait_path、各 NPC 腳本、intro_room 場景），再處理見聞錄頁面的豪傑／怪物圖。
- 2026-10-26（晚）：**頭像高清化 第一批**。老闆改提供自己去背好的 8 張圖，已存 `assets/Character/cutout/`（lie_shao、hong_huei_yin、liu_yu、xan_bu_lay、gu_shi、yan_ruo、zuo_yin、shumian；列霄是新版、煙若後續才登場）。
  - 用 scratchpad `make_hs2.py` 裁成頭肩（高=全身×0.27、寬高比1.15；紅徽音特例 0.46/1.15/右移95），直接覆蓋原路徑：`LiuYu_headshot.png`、`Hong_Huei_Yin_headshot.png`、`Zuo_Yin_headshot.png`（引用都不用改）。舊的 `rembg` 樣本與 `_v2` 檔已刪。
  - `LiuYu_headshot_legacy.png` ＝舊版 200×280，`intro_room.tscn` 的獨立 Sprite2D 改指向它（那裡自己縮放 1.25）。
  - `Zuo_Yin_headshot2.png`（鐘乳石洞用的第二表情）還是舊版，等老闆給第二個姿勢再換。
  - 待做：書眠、顧石、單步雷、折簷翁…批次套用（原檔：cutout 資料夾；舊來源 `assets/Character/*.jpg` 不要用）、見聞錄豪傑／怪物圖。
- 2026-10-26（晚，續）：頭像第二批：紅徽音改成露出整隻手（`make_hs2.py` 特例 0.46/1.38/右移160）；**書眠**（`Su_Mien_headshot.png`／`1`／`2` 三個檔名都換成同一張新圖，表情只有一個）、**單步雷**（`Xan_Bu_Lay_headshot.png`）換新圖。
  老闆指示：**折簷翁與客棧老闆的頭像撤下**（`zhe_yen_won.gd`、`inn_boss.gd` 的 portrait_path 設成空字串）；**豪傑誌拿掉客棧老闆**（`LoreDB.HERO_DEFS` 的 inn_boss 已刪；折簷翁豪傑條目保留，art 仍指向舊檔）。
  還沒做：顧石、列霄（新版）、煙若（後續登場）的頭像；`Zuo_Yin_headshot2.png` 仍舊版；見聞錄怪物圖。
