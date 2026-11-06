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
- 2026-10-27：舊水道真實側＋記憶室共 15 個物件目標改 `cursor_kind = "inspect"`（饅頭手）。**語魅汙染舊水道**（`yuheng_sewer_center` 一帶）的物件（調香室 alchemy_table／medicine_cabinet／alchemy_recipe、琴室 guqin／Music_Plate 發聲石板、符咒室三張符 heart／mouth／water talisman 等）**還是舊式 Space＋Area2D，沒有 InteractionTarget，所以沒有滑鼠游標與點選**——要改成饅頭手得先替它們補蛋黃／蛋白區（屬於「蛋白蛋黃區補完」工作），待老闆決定做法（等他手畫，或先由程式用現有 Area2D 形狀自動產生預設區）。
- 2026-10-27：**舊式物件自動三層互動** `scripts/interaction/ObjectInteractionAdapter.gd`（老闆糾正：**Area2D 當蛋黃區，往外擴張 40px 當蛋白區**，游標饅頭手）：套用於語魅汙染舊水道的調香室（alchemy_table／medicine_cabinet／alchemy_recipe）、琴室（guqin＋5 塊發聲石板 Music_Plate）、符咒室（心／口／水三張符咒，互動走房間腳本 `_interact_talisman`），共 12 個；舊 Area2D 的 monitoring 關掉避免新舊雙觸發；互動結束把 `player_inside` 放掉。接線在 `game_root.gd` 換場景後（緊接 `NpcInteractionAdapter.adopt_scene`）。要調某物件蛋白區大小：物件節點 `set_meta("interaction_expand", 像素)`；手畫 InteractionTarget 優先、不覆蓋。測試 `tests/test_object_interaction_adapter.gd`。注意：這些 Area2D 原本是「互動範圍」，比物件本體大很多，蛋黃區因此偏大，之後要精修就手畫。
- 2026-10-27：老翁美術第四版（更老態龍鍾）：cutout/old_man.png、enemy_old_fighter.webp、Old_Man_headshot.png 已換。修 BUG：老翁比武／茶樓護衛等劇情戰鬥進戰鬥畫面時劉語塵 chibi 留在畫面中央（隨機遭遇與下水道戰鬥自己會藏、劇情戰鬥沒藏）→ `GameRoot.change_map_to` 進 battle_scene 一律 `$LiuYu.visible = false`，回場由 `battle_restore` 恢復。未實機驗證。
- 2026-10-27：調香室蛋黃／蛋白改成老闆手畫（藥櫃、配方櫃檯、煉藥桌）：座標存在場景物件的 metadata（`zone_yolk`／`zone_white`，物件區域座標），`ObjectInteractionAdapter` 有 metadata 就用手畫的、沒有才用 Area2D 外框往外擴張。圖→場景換算：scene = (-828+1.15*px, -607.2+1.15*py)（背景 jpg 1448x1086、TileMapLayer 縮放 1.15）。戰鬥轉場：`LiuYu._play_encounter_transition` 一開始呼叫 `_freeze_world_for_battle`（鎖角色與滑鼠自動走路、目前地圖 process_mode=DISABLED），避免轉場期間角色繼續走、路人繼續動、誤觸出口或劇情。進戰鬥場景時戰鬥畫面本身沒有大地圖物件（實測只剩 Background）。未 commit。
- 2026-10-27：符咒間蛋黃／蛋白改成老闆手畫（心、口、水三張符咒：蛋黃在牆上、蛋白在牆前地板；另有左下出口「往舊水道」）。圖→場景：scene = (-1080+1.5*px, -792+1.5*py)。出口座標放在場景根節點 metadata（`exit_yolk`／`exit_white`／`exit_method`／`exit_name`），`ObjectInteractionAdapter._adopt_room_exit` 建出口目標（游標 exit，走進蛋白區呼叫 `_on_to_yuheng_sewer_center_body_entered`；原本的出口 Area2D 照舊）。出口蛋黃被圖片邊緣截斷，只到 x=0。未 commit。
- 2026-10-27：調音室只換古琴的手畫蛋黃／蛋白（metadata 在 guqin 節點，圖→物件座標：x-718、y-547）；五塊石板照舊用 Area2D 擴張 40px 的預設。蛋黃＝兩條長琴身併上左下圓凳，蛋白＝琴前一塊平行四邊形。未 commit。
- 2026-10-27：**顏色約定更正**：老闆的圖上「亮紅＝蛋黃、深紅＝碰撞區、粉紅＝蛋白」。調香室改成：藥櫃蛋黃＝亮紅六邊形、蛋白＝櫃前地板；配方櫃檯蛋黃＝亮紅長條、蛋白＝粉色；煉藥桌圖上只有深紅（碰撞）和粉色，沒有亮紅蛋黃 → 暫只放蛋白、蛋黃用 Area2D 外框（待老闆補畫）。古琴蛋黃改成亮紅的上方長條（深紅的琴身＋圓凳是碰撞區，尚未實作碰撞）。符咒間（三張符咒＋出口）的紅線是亮紅，不變。`ObjectInteractionAdapter` 的 zone_yolk／zone_white 現在可單獨提供，沒提供的那個用預設。未 commit。
- 2026-10-27：深紅範圍做成碰撞區（StaticBody2D＋CollisionPolygon2D，放在場景根節點底下，預設碰撞層與 sewer_true 的 *_collision 一致）：調香室 `counter_collision`／`table_top_collision`／`table_body_collision`，調音室 `qin_body_collision`（琴身＋圓凳）。符咒間沒有深紅。測試 `tests/test_sewer_collision_zones.gd`（物理查詢點得到）；另用劉語塵實際的膠囊碰撞形狀取樣，各蛋白區都有站得到的位置（煉藥桌蛋白約一半被碰撞佔掉，仍可站）。未 commit。
- 2026-10-27：調香室更正：煉藥桌蛋黃＝內縮的亮紅六邊梯形（原本被我當成碰撞區，已移除 `table_top_collision`，只剩 `table_body_collision`）；右上拱門補了出口「往舊水道」（根節點 metadata exit_*，走進蛋白區呼叫 `_on_to_yuheng_sewer_center_body_entered`）。未 commit。
- 2026-10-27：調音室左側拱門補了出口「往舊水道」（根節點 metadata exit_*；注意此場景根節點位置 x=1.69，根節點區域座標＝場景座標−1.69，圖→區域座標 x−721.38、y−544）。調香室煉藥桌蛋黃更正與右上出口也在同批。未 commit。
- 2026-10-27：汙染舊水道中央（yuheng_sewer_center）六個出入口手畫蛋黃／蛋白：老井、調香室、終端室、符咒間、密室、調音室（根節點 metadata：`exit_ids` 加每個 id 一組 `exit_<id>_yolk／_white／_method／_name`；圖→根節點區域座標 x=-1080+1.5px、y=-816+1.5py，此場景根節點位置 (-500,-1000) 不影響）。`ObjectInteractionAdapter` 支援多出口，出口觸發一次後不重複（`exit_busy`），也能呼叫 body_shape_entered 版本的出口函式（調香室出口）。終端室門上的符咒（`Door_sealed` 節點＋ talisman Area2D，腳本沒引用）已移除，圖檔 Door_sealed.png 留在 assets。密室與調音室出口的蛋黃被圖邊截斷。未 commit。
- 2026-10-27：汙染舊水道中央：符咒間（左邊緣）與密室（下方中間）出口依老闆新圖改大（蛋黃延伸出圖邊的部分仍被截斷在圖邊）；其餘四個不變。未 commit。
- 2026-10-27：密室（往中央水道）、終端室（往鐘乳石洞）、鐘乳石洞（離開，依夜談旗標回終端室或淨化後水道）的出口手畫蛋黃／蛋白（根節點 metadata exit_*，圖→區域座標：密室與終端室 x=-1080+1.5px、y=-816+1.5py；鐘乳石洞 x-720、y-544）。終端室維持封印設計：滑鼠出口呼叫原本的出口函式，沒解三機關／沒撕符咒就只會跳封印提示、不換場景（出口函式裡的閘門）；`exit_busy` 改成出口函式回來後就放掉，被封印擋下後還能再點。終端室往中央水道的出口（圖下緣，老闆沒畫）、鐘乳石洞的魘將 NPC（執行時才生成）尚未處理。未 commit。
- 2026-10-27：終端室補上往中央水道的出口（圖下緣；蛋黃被圖邊截斷）。終端室現在兩個出口：exit_ids = ("", "center")，空字串是往鐘乳石洞（舊的單出口鍵）。未 commit。
- 2026-10-27：江湖行跡錄右下的隊伍名稱與等級底下墊黑色墨筆圖章（沿用道具頁稀有度章第一款 rarity_1.png，壓深 0.6、字改米色 #F6EEDC、拿掉黑框；常數 NAME_STAMP_* 在 ChronicleScreen.gd 開頭）。未 commit。
- 2026-10-27：選單前景對調：任務頁改用武術頁的前景（念珠、墨壺、燭燈柱），系統頁改用見聞頁的前景（墨筆、詩集、花）。兩套前景抽成共用的 `scripts/inventory/StudyForegrounds.gd`（`add_martial`／`add_lore`，無 class_name，用 preload 引用）；武術頁、見聞頁改呼叫它，行為不變。任務頁、系統頁的 `_foreground_preset` 改 "none"。未 commit。
- 2026-10-28：任務頁右上紅色類型章（主線／支線）字放大到 22、一字一行上下排（SEAL_* 常數在 QuestPage.gd 開頭）。
- 2026-10-28：任務頁、道具頁的黑色墨章標題字改成跟裝備頁一樣「置中＋整體偏左 2~3px」（墨章圖片不動）。未 commit。
- 2026-10-28：道具頁區塊標題兩個字（效果）改用窄的 label_ink_s 墨章（80 寬），四個字的仍用 label_ink_m（100 寬）。未 commit。
- 2026-10-28：玉衡鎮廣場（yuheng_outside）背景換成老闆手寫字的新版（旗幡「一夫當關」、客棧招牌、酒宿燈籠）：新圖 1254×1254 縮成 1024×1024 覆蓋 yuheng_outside1.jpg（保持原本的圖塊對位）；六張遮擋前景圖（chair、corner_east／east2／north／south、umbrella）依原本的透明度形狀、位置（用模板比對求出在背景上的位置）重新從新圖取色，避免新舊背景色差出現接縫。未 commit。
- 2026-10-28：飲月山莊內部（白天、夜晚）背景換成降解析的像素風新版（1448×1086，跟舊圖同尺寸、同位置，沒有前景遮擋圖，場景不需改）。第三張白天圖左下角有老闆畫了一半的出口紅線（往山莊外），等老闆畫完再做。未 commit。
- 2026-10-28：淨化後水道兩張背景換新版（降解析像素風）：yuheng_sewer_true.jpg（洞窟河道）與 yuheng_sewer_true_room.jpg（藥師舊室，獅頭噴泉）；尺寸、擺設位置跟舊圖相同，場景不需改。未 commit。
- 2026-10-28：飲月山莊出口手畫蛋黃／蛋白：外部「進屋」（呼叫 _on_to_yin_yue_manor_roomday_body_entered，仍受 _can_enter_manor_room 閘門）與下緣「往竹林郊區」（_on_to_yuheng_bamboo_jungle_body_entered）；內部白天「離開屋子」。外部座標：local = (-676+1.5px, -1308+1.5py)（根節點位置 (500,-1000)）；內部白天：(-601.2+0.835px, -440.88+0.835py)。夜晚內部沒有出口（劇情鎖定、無出口函式），沒套用。外部下緣出口兩條折線顏色相同，內側當蛋黃、外側當蛋白（依內部那張的規則推的）。未 commit。
- 2026-10-29：竹林兩張圖（yuheng_bamboo_outskirts、Bamboo_Grove_Suburb）加地圖邊界：場景根下新增 `WalkBounds`（StaticBody2D，腳本 scripts/map/WalkBounds.gd），子節點 `walk_N` 是 CollisionPolygon2D（Segments 模式）畫出的封閉圈＝牆的中心線，編輯器裡直接拖頂點修改；執行時腳本把每條邊加粗成半徑 14 的圓頭實心牆（單薄的線會被斜著滑的角色從尖角鑽出去）。竹林郊外由底圖顏色分割出土黃小徑＋石階，再依老闆標記補被竹冠蓋住的路（補了六處）並放寬；老婆婆那張手畫外框（泥地、石板路、屋前空地）＋三顆石頭小碰撞。尚未做：竹子／灌木個別碰撞、蛋白蛋黃（兩張都還沒有）。未 commit。
- 2026-10-29：《臨風寄影》壓情後、白書眠解釋前先去醉月茶坊的特殊階段（劇情補完）：白箋居詩人 bookstore_guest_a 壓情演出結束落旗 `event_linfeng_qin_suppressed`；階段＝該旗標已落、`met_Su_Mien` 沒落、主線 stage≤1。
  階段內還沒跟紅徽音說過話（`event_tea_house_first_met` 沒落）者進白天茶坊：門口 `tea_house_qin_suppress_entry` 播一次特殊演出（兩聲琴音壓平怒氣與驚訝），完成落 `event_tea_house_qin_suppress_entry_done`，並補 `event_tea_house_melody_recall`（舊的「循聲而來」演出讓位）。已說過話者不播門口演出。
  階段內找紅徽音：循環播 A（說過話）／B（沒說過）短對白，不落 first_met（真正的初次交談階段結束後照播）。階段在白書眠談話後（met_Su_Mien）結束。資料與條件集中在 `scripts/yuheng/yuheng_market_east/zueyue_teashop/TeaHouseQinSuppress.gd`，測試 `tests/test_tea_house_qin_suppress.gd`。未做：書眠談話裡的「想起茶坊」旁白（等老闆確認位置）。未 commit。
- 2026-10-29：竹林兩張圖出入口手畫蛋黃／蛋白（老闆畫的紅／粉框，多邊形超出圖邊的部分延伸到圖外）：郊區（老婆婆那張）北邊「往郊外竹林」與南邊「往西市」，郊外竹林叢上方「往飲月山莊」與下方「往竹林郊區」，用房間根節點 metadata（exit_ids／exit_<id>_yolk／_white／_method／_name），沿用 ObjectInteractionAdapter。老婆婆維持預設蛋白蛋黃。測試 test_object_interaction_adapter 加入這兩張圖。未 commit。
- 2026-10-29：竹林兩張圖物件底部碰撞：量測摳出來的物件「底部 20% 不透明像素」落在可走範圍內的比例，對有重疊的 18 個物件（郊外竹子 10 棵：bamboo_9/10/12/13/15/17/19/20/23/1；郊區 Bush_2/3/4、stone_1/2/3、house_1/2）各加子節點 `BaseCollision`（StaticBody2D）＋`BaseShape`（CollisionPolygon2D，貼圖底部凸包，跟著物件走，可在編輯器微調）。郊區原本手畫的三顆石頭橢圓拿掉，改用石頭貼圖自帶碰撞。郊區北邊 `Bamboo` 沒加（壓在往郊外竹林的出口路上）。驗證：格點連通分析（腳寬＋牆厚留邊）兩張圖的出生點與出口仍全部連通；實際走路測試四方向猛衝都出不去。未 commit。
- 2026-10-29：竹林郊區碰撞與深度修正：Bush_2 碰撞橢圓、stone_2 碰撞橢圓改成老闆畫的位置（藍色橢圓）；三顆石頭碰撞改橢圓（蓋住石頭下面約六成）。深度檢查（劉語塵站遍 4322 個可走站位，物件 z 應為「地面接觸線 y − 50」）：Bush_4 `z_index_offset=82`、stone_1 `z_index_offset=-44` 修正，重測兩者畫反站位為 0；其餘（stone_2/3 各 2、Bush_3 1、北邊 Bamboo 16）老闆決定 PASS。竹林郊外的竹子是刻意摳出不需套 Z 的部位、靠路徑限制避開前後問題，不動。
- 2026-10-30：竹林郊區右半邊可走範圍修正：屋子前的上緣邊界原本在屋子底線下方約 45px（穿過阿婆身體），改成貼著 house_1／house_2／Bush_3 碰撞底緣外一點（照碰撞盒位置反推），阿婆現在整個在可走範圍內；連通分析仍全通。存檔（編年）畫面隊伍名字／等級恢復黑色描邊（墨章 commit 時順手拿掉了，已補回）。
- 2026-10-30：竹林郊區依老闆畫的黃線改邊界：左上獅子旁可走範圍往上推（沿獅子腳到竹牆下緣）、屋子右前沿牆底斜線往右上到水缸、水缸輪廓獨立一圈牆、右下灌木區改成可走到貼圖邊緣（右邊線 x≈1515、下邊線 y≈1675 就是地圖邊界）；阿婆 Z 修正：實測劉語塵腳在原點下 55.5px、阿婆腳只在原點下 40.8px，原本腳比阿婆低 ~15px 內仍被阿婆蓋住，阿婆 `z_index_offset=-15`（腳同高時 Z 相等）。教訓：Z 以原點排序時，每個 NPC／物件要用「貼圖底緣相對原點的距離」跟玩家（55.5）比，不能假設 50。
- 2026-10-30：WalkBounds 改版：牆完全放在線的「不可走」那一側（依奇偶判斷），並再往外退「角色在該方向的半寬」（橫向 11.2＋半徑 5、縱向 5），讓劉語塵腳的碰撞中心剛好走到畫的線上（實測右邊界 1489.03／下邊界 1676.3，線在 1489／1677）。竹林郊區右半邊整個改成老闆乾淨圖上畫的黃線（左水罈→門前→菱形（內部可走）→屋前下緣→右水罈→右邊界 x=1533／下邊界 y=1021），舊紅線全部刪除；右邊界先前誤抓成 1511（水罈右側短線）少 22px，已改。老闆圖與專案邊界逐點比對：黃線 99% 落在我的線 4px 內。
- 2026-10-30：醉月茶坊「特殊階段」（臨風寄影壓情後的門口演出＋紅徽音 A/B 循環）結束時機改成《銀屏語》事件完成（`event_yinpingyu_done`），不再是第一次跟白書眠談完（`met_Su_Mien`）或主線離開第 1 階段。只改旗標時間點，對白內容不動；`TeaHouseQinSuppress.is_window_open()` 改為「已壓情且銀屏語未完成」，測試同步更新（PASS）。
- 2026-10-30：拿掉 `Hong_huei_yin.gd` 裡「主線 stage 4 時與紅徽音對話結束就推到 5」的舊邏輯（連同 `_advance_main_quest_to_5()`）。stage 4→5 現在只由《銀屏語》事件收尾推進（`baijianju_yinpingyu_story_shumian.gd`）。主線 stage 流程盤點：1 客棧開場 → 2 書眠首談 → 3 顧石周旋 → 4 暴發戶事件後進白箋居 → 5 銀屏語 → （6 只當目標文字，沒有程式真的推進）→ 7 紅徽音首談給銅釦 → 8 廢井開啟 → （9 鐘乳石洞目前沒有程式推進）→ 10 山莊夜談 → 11 啟程烈風寨。
- 2026-11-02：改寫 `HANDOFF_TO_CODEX.md` 為第二版交接信：下一階段四項（戰鬥動畫、後續地圖摳圖／碰撞／Z、道具裝備平衡＋寶箱、等級經驗），附 WalkBounds／BaseCollision／Z 量測做法、主線 stage 盤點（6、9 無程式推進）、醉月茶坊特殊階段、工作規則。
- 2026-11-02：修正僚卡格擋後受保護角色誤播閃避：BattleController 只在真正 `dodged` 時派發角色閃避，多段攻擊須全部落空才播一次；格擋仍由原本傷害邏輯處理。新增獨立派發回歸測試，避免既有替身符測試的武器夾具問題混淆結果；未改命中、傷害與僚卡攔截演出。
- 2026-11-02：修正敵方全體攻擊時「攔截」字樣錯掛在受保護角色卡：CardStage3D 轉交全體事件給 BattleEventPresenter 時保留 `blocker_entity_id`，沿用既有僚卡畫面座標作 popup 錨點；補全體攔截回歸檢查。未改格擋判定、傷害或僚卡飛行動畫。
- 2026-11-02：替身符破裂從七巧板七塊切法改為交錯的空間斬痕與錯位碎裂；碎片保留原卡面圖像及紙／墨色，原卡面在碎裂時淡去。沿用原本一秒停頓、兩秒紅焰與 action blocking；未改攔截或傷害判定。
- 2026-11-03：替身符空間碎裂時直接隱藏完整卡面與背面的 Mesh，只留下被斬開的碎片；後續紅焰只繪焦痕與火光。預覽發現單靠 3D transparency=1 仍看得見原圖，因此改用明確 hide，並補碎裂與燃燒階段的可見性回歸檢查。
- 2026-11-03：修正手繪地圖出口的蛋白區通行：角色從外走進出口蛋白區即觸發一次，無須滑鼠先點出口蛋黃；普通 NPC／物件仍需明確點選。Adapter 接管出口後解除同函式的舊 Area2D 進入連線，保留 Area2D 監測供 MapTransitionGuard 使用；出口 handler 不再對缺少 interaction_locked 的房間呼叫 bool(null)。補普通地面按住進出口、出生點防折返、已站在蛋白區點出口與缺欄位場景的測試。
- 2026-11-03：微調 Card Stage 僚卡演出：替身符空間斬碎裂後直接等待碎片全部消散，不再接紅焰與重建卡面的 burn sheet；僚卡攔截由兩段起步即快的 Tween 改為單段帶弧線的立方加速飛行；角色卡的面／畫／墨層距 0.05→0.03、背板厚 0.04→0.025，僚卡背板厚 0.04→0.02 並移近卡面。攔截及 Card Stage 測試通過，未改傷害與 ADB 邏輯。
- 2026-11-03：戰鬥事件的「攔截／閃避／格擋」等大圖示與小標籤共用 0.2 秒上滑淡入，移除原本 0.06 秒突顯與放大彈出；保留原定位、停留與淡出，讓結果提示更容易被看清。補事件圖示入場測試，未改戰鬥判定。
- 2026-11-03：修正替身符攔截站位與特效穿卡：單體／全體受擊時替身符飛到我方最前角色卡迎擊側，不再停在兩名隊友之間；空間斬與碎片改按深度排序，防禦護罩縮回卡面內並移除強制蓋過鄰卡的繪製優先權。只改舞台演出座標與材質，ADB 卡序與格擋判定不動。
- 2026-11-03：精修 Card Stage 防禦與卡列移動：角色卡護罩的立繪區增加可見的冷光薄膜（保留立繪辨識度），開戰首次同步與替身符離場後都以 0.5 秒緩入緩出滑到新位置，不再因空白 order signature 直接跳位；僚卡攔截飛行延長並加強起速慣性、弧線與抽牌幅度。Godot 預覽檢查前列護罩，攔截測試 45 項、Phase 1 測試 813 項通過。
- 2026-11-03：針對劉語塵深色立繪上護罩難辨，Godot 雙角色預覽確認兩人的立繪共用同層，改護罩 Shader 讓薄膜中央也有微弱流動冷光；分別預覽劉語塵與白書眠守備。飲月山莊白書眠 NPC 的裝飾影子 TextureRect 原本攔截滑鼠，改為忽略輸入，讓 DialogManager 的 `_unhandled_input` 能收到左鍵推進。未改對話內容或戰鬥判定。
- 2026-11-04：完成劉語塵護罩與山莊對話點擊後續修正：護罩畫面除了薄膜之外，立繪本身隨守備同步受冷光染色，避免透明 3D 排序讓深色立繪看似浮在護罩前；一般對白左鍵改在 `_input` 消耗，選項仍交給 GUI，解決局部 Control 吃掉點擊。老闆實機確認兩者已正常。另修正白天飲月山莊的讀檔回退：場景建立時旗標已還原、TeamData 名冊尚未還原，原本會用上一個存檔的入隊資料提前刪除白書眠 NPC；改為讀檔完成訊號後才裁定出場，並以定向 Godot 測試驗證未入隊與已入隊兩種存檔。
- 2026-11-04：回合標題加入行動排程屏障：Card Stage 播放「第 X 回合／開始」期間，TurnManager 不發出下一位角色回合，UI 清除舊行動卡與指令狀態；標題按鍵／點擊只推進標題並消耗輸入。標題及回合起始演出完成後才放行，另補首輪、次輪、跳過與點擊穿透的定向測試。
- 2026-11-04：Card Stage 的「開始」標題結束後加入 0.45 秒刻意留白，期間繼續鎖住敵我回合與玩家指令，避免敵方先手緊貼字幕消失瞬間發動；等待仍以標題 `finished` 為起點，定向測試驗證留白期間無行動與可點指令。
- 2026-11-04：Card Stage 我方閃避演出延後 0.25 秒起動，移出後停留 0.75 秒，回位平均速度為去程的 0.65 倍；敵方閃避時間不變，回歸測試檢查停頓、位移及回位。
- 2026-11-04：我方閃避起動延遲縮至 0.15 秒；GameRoot 進戰鬥時統一鎖住並靜音地圖 BGM，阻擋晚到的場景切歌，避免地圖與戰鬥音樂重疊，戰後回地圖仍可恢復。定向測試涵蓋尚未開播、已播放及切歌途中三種時機。
- 2026-11-04：Card Stage 預設攻擊與墨鱗魘將水彈改在實際接觸時播放拳系命中／閃避音；格擋優先於閃避，疊放既有 guard 音與攻擊者武器命中音。補定向音效測試並通過 Phase 1 戰鬥回歸，未改傷害與命中判定。
- 2026-11-05：Card Stage「開始」字幕後的行動等待從 0.45 秒縮為 0.20 秒；回合標題出現時清除舊懸停，直到等待結束前禁止卡片懸停彈出與指令點擊。補回合屏障測試覆蓋等待期間懸停鎖，未改標題動畫本身。
- 2026-11-05：拳系真正閃避時的 SE_fist_miss 單獨提高 4 dB；使用一次性音效聲道，不改共用 SEPlayer 音量，拳系命中、其他武器閃避與 guard 音量保持原值。定向音效測試通過。
- 2026-11-06：修「從調香室回中央房馬上被傳到調音室」。原因：換場時新場景先加進來、下一幀才把玩家搬到出生點，這段空檔玩家還站在調香室出口座標，剛好壓在中央房調音室出口 Area 上，出口函式沒有 MapTransitionGuard 就直接換圖。修法：`game_root.gd` 加進新場景後立刻搬到出生點；中央房六個出口函式加 `MapTransitionGuard.can_transition`；出口收集改成不分大小寫（`To_` 之前被漏掉）。排查方法寫在 `docs/map_transition_bug_playbook.md`。
- 2026-11-06：擷取使用者提供的五段 MP4 音軌，接入角色指令開啟、招式確認、獼猴退場、持鞘旋轉插入、劉語塵攻擊前進；前進第一版配合 1.973 秒腳步／吆喝，傷害數字同步延後。持鞘改用專屬音取代通用滑入落位音，待使用者實機調整聲畫節奏。
- 2026-11-06：依使用者實聽將角色指令展開與招式確認音各加 10 dB；劉語塵前進改為 0–0.18 秒後退蓄勢、0.18–1.11 秒前進，於抵達訊號播放攻擊聲（含普攻與流塵四連擊），不再等待整段 1.973 秒音軌結束。
- 2026-11-06：劉語塵攻擊前進增加慣性感：後退以 cubic ease-out 煞住，向前位置與傾身同步使用 cubic ease-in 加速；仍於 0.18 秒完成蓄勢、1.11 秒抵達並觸發攻擊聲。
- 2026-11-06：依使用者重新安排恢復劉語塵原攻擊動畫／0.12+0.17 秒節奏；移除腳步音接法，改普通／爆擊短吆喝在卡片開始前頂時播放。替換角色點選與招式確認音軌，保留先前要求的 +10 dB；正式我方角色輪到操作時加入提示音。
- 2026-11-06：接入使用者新剪的技能點選、取消、劉語塵單次劍擊與獼猴受擊音。技能選中音移除約 2.63 秒片頭靜音，猴子受擊音移除約 0.73 秒片頭靜音；UI 選中／取消採 +10 dB。普通單次劍擊改在實際接觸播放新音，四連擊音保持。
- 2026-11-06：獼猴受擊音單獨加 6 dB；角色卡點選與技能選中音互換，兩者維持 +10 dB。從使用者影片擷取替身符攔截音，移除片頭約 0.75 秒與片尾靜音，接在替身符實際碰撞擋傷時播放，持鞘不共用此音。
- 2026-11-06：依替身卡擋傷影片補金色亮框、碰撞後短暫撐住的受力節奏；斬痕與碎片保留既有空間斬。單體／全體攔截改在同一演出內等待碎裂散盡，後續邏輯扣次數／移除不重播動畫，擋招聲提高 10 dB。
- 2026-11-06：提交前依使用者要求將替身符擋傷聲再降 2 dB，最終為戰鬥 SE 基準 +8 dB，並同步更新音量驗證。
- 2026-11-06：替身符專屬擋招聲回到 +10 dB，Card Stage 替身攔截結果不再疊舊武器／guard 音；多段結果保留逐擊來源供音效判讀。依使用者最終配置，原我方回合提示音移至點角色展開行動 UI，原展開音移至出招／防禦／道具等指令按鈕，滑鼠懸停不出聲。
- 2026-11-06：依使用者回饋收近替身卡攔截落點，改依傾斜卡面的可見寬度留距，不再用兩張未旋轉卡片的完整寬度把替身推得過右；亮框、受力、空間斬與聲音節奏保留。
- 2026-11-06：依使用者要求恢復劉語塵單次劍擊的原武器命中音，與新增劍攻擊錄音在接觸時疊放；替身攔截仍由專屬擋招聲單獨負責。
- 2026-11-06：替身攔截斬痕／碎裂分別對齊音檔約 1.26／1.46 秒（原影片約 2.01／2.21 秒）的撞擊節點；使用音效開始後實際時間，不讓 0.3 秒碰撞慢動作推遲聲畫對位。第一聲出既有空間斬刀痕，第二聲才隱藏卡面並生成碎片。
- 2026-11-06：替換為使用者新提供「新替身卡擋刀」完整音軌，依指定時間線 0.18–0.27 秒快速出卡撞擊、0.27–1.0 秒漸現既有空間斬、1.0 秒開始碎裂。音效時鐘改從出卡前開始，敵方攻擊 FX 與僚卡並行到達；斬痕與碎裂不受碰撞慢動作拖延，位置與 +10 dB 保留。
