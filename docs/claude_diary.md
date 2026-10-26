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
- 2026-10-26（晚）：顧石頭像已 commit（37dd996，`Gu_Shi_headshot.png`，`make_hs2.py` 的 gushi 用 MINW 略過獨立槍頭）。**任務頁**新版 `scripts/inventory/QuestPage.gd`（開關 `USE_NEW_QUEST_UI`、`_update_quest_page` 在 system_menu.gd）：左分類（主線／支線／已完成，已錯過歸已完成）、中清單、右詳情；資料用 `menu._build_quest_entries()`；全用現成書房素材（狀態章暫用 status_usable／badge_equipped／status_disabled 頂替，分類圖示暫用 cat_icon_quest／book／all）。測試 `tests/test_quest_page.gd`；截圖腳本 scratchpad `quest_shot.gd`。
  下一步：老闆看過版面後，開精簡素材規格給共邊國（狀態印章三種、分類圖示、空狀態圖、可選新任務標記），素材交來放進資料夾即自動換。
- 2026-10-26（深夜）：老闆的一批雕琢：
  - 游標：系統選單開著時 `GameCursor` 一律待機樣式（`_menu_open()` 看 GlobalState meta menu_open）。
  - 見聞錄：豪傑圖貼齊畫框底邊（框內緣約 x57~293、y114~302）；神怪的圖改用戰鬥卡面（`CardStageArt.entry_for`）；欄位文字放不下時用跑馬燈（`scripts/ui/MarqueeLabel.gd`；左頁欄位用即時覆蓋節點 `_build_marquee_slots`，任務頁清單列用 `_marquee`）。
  - 說明文字改白字黑邊：`StudyPageBase._white_outline_rich`，用在道具頁（效果／使用條件／描述）、武術頁（內功心法、更換內功、技能詳情）、任務頁（描述／目標／筆記）。
  - 老翁頭像：寫了給共邊國的簡介 `docs/gongbian_old_man_headshot_brief.md`（腳本 `scripts/yuheng/yuheng_outside/old_man_a.gd`）。
  - **老闆要我提醒他的事**：①豪傑誌要加入**左飲**的條目（劇情上先解鎖他的人物誌）；②老翁頭像尚未有圖；③列霄新版／煙若頭像尚未做；④`Zuo_Yin_headshot2.png` 仍舊版；⑤任務頁專屬素材（狀態章、分類圖示、空狀態圖）要開規格給共邊國。
- 2026-10-27：老闆追加：①`Zuo_Yin_headshot2.png` 已刪、鐘乳石洞改用 `Zuo_Yin_headshot.png`；②見聞錄神怪卡面放大塞滿畫框（置中裁切），豪傑仍貼底；③大地圖招式內力不足 → 紅色圖章「內力不足」（用 badge_quest 頂替紅章），回復後變綠；做成 HOOK：`MartialInfo.cast_block_reason`／`register_cast_blocker`（招式資料 `cost_resource`："hp" ＋ `hp_cost` 會顯示「氣血不足」，給之後的魂體轉換）；④白字黑邊只留在「更換內功」彈出頁、道具頁說明、任務頁；**武術頁本身與招式詳情維持原本墨色**（老闆更正）。
  整理按鈕：`InventorySync.sort_inventory_by_id()` ＝ 依道具 id 字串順序排（不是名稱、不是類別）。
- 2026-10-27：老翁台詞（問「石破心法可練得如何」那組）改成老闆給的新版（掃帚吐槽）。對話分頁規則調整（`DialogTextLayout.layout_pages`）：一頁沒滿兩行時，下一句只要合計不超過三行就接上去，不急著換頁；已滿兩行、接上去會超過兩行才換頁；單句超過兩行自己一頁。測試 `tests/test_dialog_text_layout.gd` 已更新。
- 2026-10-27：**更正**：開場房間（`scenes/intro_room.tscn` 的獨立 Sprite2D）之前我為了「不變形」指向舊版備份，結果老闆在遊戲裡看到劉語塵頭像「換回舊的」。已改回新圖（縮放 0.729、底邊對齊原位），並刪掉 `LiuYu_headshot_legacy.png`。教訓：換圖時要找出所有獨立顯示頭像的地方（不只 DialogManager），不要留舊圖備份。
- 2026-10-27：老闆澄清「斷句太快」＝**同一頁兩行時第一行比第二行短**（老翁稱讚「武人胚子」那句）。原因：兩行平均斷行（`_solve`）成本相同時取了較早的斷點。已改成成本相同取較晚斷點（第一行排滿一點）；測試 `even_text` 涵蓋。僅剩的例外：在句號後斷行（自然的句尾斷點）在很窄的欄位可能第一行較短。
- 2026-10-27：**老翁美術**到了：去背版 `assets/Character/cutout/old_man.png`（→ 對話頭像 `Old_Man_headshot.png`，zoom-out 0.34，`old_man_a.gd` 的 portrait_path 已指向）；有背版 `assets/sprites/battle_cards/enemy_old_fighter.webp`（→ `CardStageArt` 條目 `yuheng_old_fighter`，focus 0.44/0.17；神怪誌「演武老翁」已顯示）。EnemyDB 早就有 `yuheng_old_fighter`（演武老翁），打過比試後（`lore_enemy_<id>` 旗標）出現在神怪誌。**豪傑誌的老翁條目還沒做**（老闆在討論要不要；我建議要，解鎖點＝第一次對話後）。
  見聞錄神怪圖現在支援 `art_focus`（卡面條目的 focus），直式插畫會以焦點（臉）置中裁切。
  排版：尾行太短重排最後兩行時改用 `_fill_pair`（第一行盡量排滿、第二行至少 6 字、優先逗號後斷），不再平均成兩行一樣長（老翁「外物盡去…」那句）。
- 2026-10-27：老翁美術換成第二版（水墨加工筆風：`cutout/old_man.png`、`enemy_old_fighter.webp`、`Old_Man_headshot.png` 已重做）。斷行：逗號優先斷點的視窗放寬到最後 5 字（貪婪斷行與 `_fill_pair`），避免「觸／及」被拆開；寫死 4→5 要留意 `test_dialog_text_layout` 的「第一行至少填到右緣前 5 字」。
- 2026-10-27：列霄新版頭像（覆蓋 `LieShao_headshot2.png`）、煙若頭像 `assets/sprites/NPC/YinHuo/Yan_Ruo_headshot.png`（尚無腳本引用，她登場時指向它）；神怪誌圖再放大 1% 並多出 1px 壓在框下，填滿左右縫隙。仍是舊圖的頭像：折簷翁、娜亞。
- 2026-10-27：道具「整理」改成先依種類（藥物、書籍、裝備、材料、任務、其他，同道具頁左邊分頁順序），同種類再依 id：`InventorySync.sort_inventory()`（種類看 ItemDB 資料，背包列本身只有 id／數量）、`ItemCategory.sort_rank`；測試 `tests/test_inventory_sort.gd`。舊的 `sort_inventory_by_id()` 保留。
- 2026-10-27：整理排序加強：裝備在種類內依部位（主武器、副武器、頭、身體、手、腳、飾品、機關）→ 稀有度（高在前）→ 名稱筆劃（少在前）→ id；其他種類仍依 id。筆劃表 `scripts/items/StrokeTable.gd`（老闆同意下載 Unicode Unihan，只抽出 79 個道具名稱用到的 172 字；新道具名稱出現新字要補進表，查不到算 0 筆）。測試 `tests/test_inventory_sort.gd` 用真實裝備驗證。
- 2026-10-27：「整理」每按一次輪流切換裝備稀有度方向（第一下高在前、第二下低在前…），方向只記在 `InventoryPage._sort_rarity_high_first`（記憶體）：離開道具分頁（頁面隱藏）會重置；關閉選單會釋放整個選單實例，下次一定是高在前。`InventorySync.sort_inventory(rarity_high_first)`。
- 2026-10-27：**動態豪傑誌**（共同開發組交接信）：`LoreDB.HERO_DEFS` 新增 `stages`（階段條件，`{"any":[{"flag":…}|{"quest_done":…}]}`）與 `sections`（`{"stage":N,"text":…}`）；`get_hero_stage`／`get_hero_paragraphs`／`is_hero_unlocked` 都是即時從 GlobalState 旗標與 SideQuestManager 判斷（不另存狀態、不快取）。左飲：`battle_stalactite_fish_boss_phase2`（或 `_won`、`main_yh_manor_after_fish_ready`）成立才收錄；比武老翁（id `old_fighter`）三階段＝`heard_oldman_zuoyin` → 兩種比武勝利旗標 → 支線 `yh_side_oldfighter_01` 完成。`LoreEntries` 的 `meta`（身分／地點／姓名）顯示在右頁圖下；左頁人物誌字太多會縮小（最小 12）。老翁跳級獲勝台詞：`old_man_a.gd` 沒有對應勝利旗標時不說「你先以兵器勝我／你再以空手勝我」。測試 `tests/test_lore_dynamic_heroes.gd`。**老闆還沒決定**：段落太多時用卷軸還是左邊書籤（其一 其二 其三）。信上要求本輪不 commit，等老闆確認。
- 2026-10-27：豪傑誌動態人物誌改用**書籤**（老闆決定）：書左側每段一枚「其一、其二…」（`LorePage._build_bookmarks`，現成素材頂替：深棕底＋金邊的簡單樣式，之後可換專屬書籤素材）；選到的書籤往外凸；左頁一次顯示一段（字級固定 17，不再縮字）；選擇只存記憶體（`_hero_section`）。`LoreEntries` 豪傑條目多了 `paragraphs`。尚未 commit（交接信要求等老闆確認）。
- 2026-10-27：老翁美術第三版（降低飽和度，與其他角色畫風一致）：cutout/old_man.png、enemy_old_fighter.webp、Old_Man_headshot.png 已重做。
- 2026-10-27：老翁對話頭像再 zoom out（裁切高 0.44、寬高比 1.05），露出胸口到腰帶。
- 2026-10-27：老翁頭像再調：裁切高 0.385、寬高比 1.08，剛好切在腰帶上方（老闆指示）。
- 2026-10-27：井身扣孔（白天／夜晚 `well_keyhole`）游標改成 `cursor_kind = "inspect"`（白色饅頭手）。**盤點：目前所有物件型互動目標仍是預設 "talk"（對話泡泡框）**：舊水道真實側（`yuheng_sewer_true.tscn`：memory_qin／memory_writing_desk／memory_medicine_cabinet、loot_herb_basket／loot_qi_box／loot_haste_scroll）、記憶室（`yuheng_sewer_true_room.tscn`：memory_room_*、loot_old_herb_pouch／loot_calm_pill、fix_wall_talisman／fix_lion_waterhead／fix_channel_lamps／fix_channel_lamps_b）。人物 NPC 用泡泡框是對的（含舊式 NPC 自動套用的預設）。老闆還沒決定那些要不要一併改成饅頭手。
