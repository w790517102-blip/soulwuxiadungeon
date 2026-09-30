# 戰鬥舞台原型（第一階段）

這是文字戰報戰鬥的替代演出層，不是 isometric 戰鬥，也不新增戰術位置或另一套傷害公式。

## 開啟與切換

- 獨立場景：`res://scenes/presentation/combat_stage_prototype.tscn`，可在 Godot 4.4.1 開啟後按 F6。
- 一名劉語塵對一名測試敵人，沿用正式 Controller、SkillDB、Executor、TurnManager 與狀態／戰報；角色使用複本。演武勝負不發獎勵、不返回劇情、不儲存角色。
- 演武場禁用道具以免消耗正式背包，正式戰鬥則沿用原本 ruleset。
- 新戰鬥預設舞台版；F8／右上角按鈕可在非演出期間切回原本的文字版，再切回舞台。
- 要直接使用原始 Legacy scripts 啟動，傳入 `-- --legacy-battle`，或設定 `BattleScene.presentation_mode = LEGACY`。也可由 battle context 的 `presentation_mode` 整數（0／1）選擇。
- 指令僅有 **出招／內功／道具／防禦**，沒有逃跑按鈕或新增逃跑邏輯。
- 滑鼠操作 3D 主指令。出招／內功／道具共用 `ActionItemListPanel`：左側正式 ItemList、右側可捲動說明、上一頁／下一頁與確認／取消。頁鈕每次移到八筆區段，不改原始選項索引或資料。只有確認才交回既有 action callback；內功不要求選敌人，道具單體目標使用同一分層目標流程，自身／全體保留原有直接派送。
- 目標選取顯示頂部提示、由出招者卡片延伸的拋物線箭頭與有效目標高亮；點擊卡片後在滑鼠附近再次確認。確認框取消／右鍵 → 選目標；再次取消 → 原招式清單（保留選項）；清單取消 → 主指令。單一目標與全體技能也不略過確認。
- Space／ESC／左鍵首次輸入立即補完目前逐字訊息並保留下一則，第二次再前進；未手動補完的文字維持既有正常播放。正在逐字顯示時優先 consume input，包含嵌入式 Popup 的 Window input；補完後恢復 Popup／目標／選單優先權，避免穿透。L／「紀錄」開關完整原始戰報，以原生 RichTextLabel 捲軸支援滾輪、拖曳與軌道點擊。開啟或按「回到最新」才捲到底；抽屜開啟期間新增戰報不搶走閱讀位置。

## 責任邊界

| 檔案 | 責任 |
| --- | --- |
| `BattleScene.gd` | child ready 之前選擇演出 adapter；原始 battle context 啟動不變 |
| `StageBattleController.gd` | 僅覆寫單體攻擊 cinematic，等待舞台完成後交回原有流程 |
| `StageBattleUI.gd` | 正式 ItemList 的可用技能與說明、分層選取接線、OS 舞台卡片錨點；維持結果視窗 |
| `StageTargetPicker.gd` | 目標選取／確認 presentation state；只在最後確認交回既有 target callback |
| `BattleTypography.gd` | 舞台／文字版、Popup、戰報及結果視窗的 DotGothic16 字體契約 |
| `ActionItemListPanel.gd` | 三種行動選單共用排版、字體、選取樣式与分頁導覽；不替代資料／執行 Authority |
| `BattleMessageInput.gd` | 根 Viewport 與 Popup Window 的訊息輸入優先路由；消耗首次補完事件 |
| `StageLogPanel.gd` | 保留完整原始 log queue，只分隔舞台／紀錄抽屜的確認輸入 |
| `CombatStage25D.gd` | Perspective Camera、深度層、演出協調、滑鼠邊缘視差 |
| `StageActorCard.gd` | SubViewport → QuadMesh 卡片，唯讀 actor 欄位與局部動畫 |
| `StageCommandTray.gd` | 獨立 3D 指令、hover、彈回、ray picking、深度子選單 |
| `SwordTrail3D.gd` | 交叉 ribbon volume；MISS 穿越目標平面繼續往後飛，絕不套傷害 |

我方顯示目前內功屬性、內功名稱、LV 同列狀態縮字、runtime HP／MP。敵方顯示姓名、肖像、HP、production 屬性／種族及狀態；沒有自創弱點或火雷圖示。固定空槽保留框，Guest 使用同一卡片的客座 presentation，不製造正式玩家 actor。

## 第一輪調整參數

`CombatStage25D` Inspector：yaw 22°（左右鏡像）、FOV 34°、中心 dead zone 66%、視差幅度 (0.20, 0.10)、我方 Z=1／敵方 Z=-1／背景 Z=-8。Camera Z=18、指令 Z=2.5，子選單約 Z=3.15。

角色卡以 640×300 邏輯畫布、1280×600 SubViewport 渲染。多人 occupied cards 保持 scale=1，以排版和 font_size 定義文字；不再把多人卡片縮成 0.7。底部為左侧「指令」主牌＋四個主指令，右側固定最近戰報／紀錄。

角色卡的突進、pitch／roll、局部 hit-stop 與回彈在 `StageActorCard.gd`；各卡獨立 Tween，不改 Engine.time_scale。SwordTrail 命中飛行 0.32 秒，MISS 0.57 秒，再淡出 0.24 秒。

本階段使用簡化框／按鈕与使用者提供的魚怪背景。只驗證 1v1 舞台、一種劍氣，未宣告多人卡片尺寸、全部技能 FX、Guest 動作或完整 Boss 流程已目視驗收；這些留待玩家確認第一版手感後再擴充。原本 Legacy scene、UI、Controller、數值／獎勵與劇情腳本保留。

## 可重跑檢查

```powershell
& '<Godot 4.4.1 console executable>' --headless --disable-crash-handler --log-file "$env:TEMP\stage_test.log" --path . --script res://tests/test_combat_stage_25d.gd
```

測試包含真實 3D picking、hover 位移、XZ 突進、pitch／roll／回位、MISS 深度、runtime HP／MP、內功欄位、原始 Executor 命中／MISS、三個完整指令回合交接及正式 TeamData／背包資源不變。合法 MISS 不會被當作傷害公式錯誤。

可選畫面檢查（必須使用正常 renderer，不能使用 headless dummy renderer）：開啟原型場景，命令尾端加 `-- --stage-capture=<absolute.png>`；可再加 `--stage-capture-menu=skill`、`target`、`confirm`、`os`、`multi`、`legacy` 或 `inner_force`。僅建立畫面快照，不開始戰鬥，完成後退出。`multi` 使用演示複本，未新增 production 角色／敵人資料。

本輪結果：Godot 4.4.1 共 67 項 assertion 通過，包括透過 Viewport 正常 GUI／unhandled input 路徑點擊三個指令、各自交接一次回合。Compatibility／OpenGL 與專案預設 Mobile／Vulkan 均已渲染並檢視截圖，未出現 GDScript 執行錯誤。環境仍回報 Wacom 設定檔、shader cache、憑證存取警告，以及退出時 ObjectDB／資源未釋放訊息；本輪沒有擴大改動共用戰鬥的資源生命週期。完整章節、全部技能與正式 Boss 戰回歸仍待後續驗收。

第二輪追加檢查：ItemList 選項與說明保留、單一目標也需確認、同種敵人的 battle_uid picking、死亡目標排除、AoE／我方／自身候選、右鍵逐層返回、取消不扣資源、OS 安全區與不遮卡片、雙倍 source resolution／多人不縮字，以及目標確認途中 F8 切換。已用正常 renderer 檢视主指令、ItemList、目標箭頭、確認框、OS、三對三與 Legacy 截圖。這些是獨立演武檢查，正式 Boss 的操作手感仍交玩家實機驗收。

第二輪結果：Godot 4.4.1 共 95 項 assertion 通過；沒有 GDScript 執行錯誤。環境憑證與退出時 ObjectDB／資源釋放警告仍在，未擴大至共用資源生命週期。修改範圍的 whitespace check 無問題；整個工作樹的 diff check 仍指出既存 `gu_shi.gd:209` 尾端空白，未處理該無關檔案。

## 共同選單／紀錄／訊息輸入驗收

新增 `tests/test_battle_message_and_menus.gd`，54 項 assertion 通過；原有舞台回歸 95 項仍通過。檢查三種選單共用结构、字體／行距／Highlight、12 筆選項分頁、內功狀態、道具說明與目標取消返回、無目標派送邊界、原生紀錄滾輪／拖曳／軌道點擊、閱讀位置保留／重開回最新、三種訊息補完輸入、開場兩段式確認、目標與 Popup 防穿透，以及正式背包不變。

測試經 Godot 4.4.1 的 Viewport input 執行，不等同玩家逐項人工驗收；正式章節手感仍待玩家遊玩。正常 renderer 已產出并檢視內功、道具與紀錄截圖。道具截圖只向演示 Popup 放入既有繃帶的複本，不增加／消耗背包；演武本身仍禁用道具。可用 `--stage-capture-menu=item` 或 `archive` 取得這兩種畫面。

沒有新增戰鬥特效，也未修改傷害、獎勵、角色永久資料或故事流程。環境憑證與退出資源警告仍在。
