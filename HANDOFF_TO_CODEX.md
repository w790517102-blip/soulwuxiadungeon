# 交接信：給 Codex（第二版，2026-11-02）

Codex 你好，

這是第二次交接。上一版（戰鬥系統）的內容仍有效，戰鬥導覽請看 `README_CODEX.md`、`docs/stage_entities.md`。這一版交代：我最近做完了什麼、目前的程式狀態，以及使用者排定的下一階段四項工作。

工作區目前是乾淨的，最後一個 commit 是 `f9d4d51`（分支 `feature/card-stage`）。

## 一、使用者排定的下一階段（依序）
1. **精進戰鬥動畫**
2. **後續幾張地圖的摳圖、物件碰撞、Z/Y 圖層套用**
   - 2-1. 地圖邊界與碰撞點
3. **裝備及道具數值平衡性修改，以及寶箱系統實裝**
4. **等級與經驗值系統**

我沒有調查過 1、3、4，下面只記我讀過程式後確定的事實；細節請直接問使用者。

### 1. 戰鬥動畫
戰鬥動畫的現況與規格看 `README_CODEX.md`、`docs/card_stage.md`、`docs/combat_stage_25d.md`。使用者的慣例：**演出以即時示範視窗讓他驗收，他說「通過驗收」才算完成**；測試只保證邏輯，視覺全靠肉眼。使用者偏好「用做好的 Animation，沒有才用 Tween」。

### 3. 道具／裝備／寶箱
- `docs/item_audit.md`：道具交握稽核。注意這份是早期寫的，已過時（它說專案沒有 `ItemDB.gd`，但現在有 `scripts/db/ItemDB.gd`，裡面有任務道具等條目）。
- 道具效果由 `BattleController.use_item` 以 `effect` 字串分支處理，未實作的 effect 會落入預設分支（戰報顯示尚未實作）。
- 我在 `scripts/` 的 `.gd` 裡搜尋「chest／寶箱」沒有找到任何結果，所以寶箱系統看起來還沒有程式；場景裡有沒有擺寶箱我沒查。這是「沒搜到」，不是「確認沒有」。

### 4. 等級／經驗
- 戰鬥結算在 `scripts/battlescripts/InventorySync.gd`（約 440–490 行）呼叫 `TeamData.add_exp_to_actor_ids_with_growth`／`add_exp_to_active_party_with_growth`；升級事件與習得技能的結果顯示在 `BattleUI.gd`（約 1500–1545 行）。也就是說經驗與升級的雛形已存在，需要的是規格與數值設計。我沒有逐行驗證它現在的升級曲線。
- 存檔畫面（`ChronicleScreen`）會顯示隊伍名稱與等級；它的文字描邊曾因蓋章圖層而被我誤刪，已在 `7612c75` 修好，改版面時請保留 `_outlined(...)`。

## 二、第 2 項：地圖摳圖與碰撞——我建好的做法（請沿用）
已完成的地圖：玉衡鎮客棧房間、客棧、廣場、西市、東市、醉月茶坊白天、白箋居、藥鋪、武器店、**竹林郊區（Bamboo_Grove_Suburb）、竹林迷宮（yuheng_bamboo_outskirts）**（這兩張是我最近做完並 commit 的）。

**還沒做的（使用者原話）：** 飲月山莊外（沒有摳圖也沒有邊界）、飲月山莊內（日／夜）、醉月茶坊夜晚（目前拿白天場景頂替）、下水道、廢井。

### 邊界：`WalkBounds`
- `scripts/map/WalkBounds.gd`（`class_name WalkBounds`，StaticBody2D）。在場景裡放一個 `WalkBounds` 節點，底下放若干 `CollisionPolygon2D`（`build_mode = 1`，線段模式）當邊界線的迴圈。
- 執行時它會停用原多邊形，並在每一條邊的**不可走那一側**生成厚 60 的凸多邊形牆（用奇偶規則判斷哪一側可走；兩側同為可走或不可走的邊會略過）。牆再往外退 `11.2*|n.x| + 5.0`，讓玩家碰撞膠囊的**中心**剛好走到使用者畫的線上。所以多邊形的頂點座標 = 使用者畫的線，不要自己內縮或外擴。
- 外圈輪廓一個迴圈；島（竹叢、水池、房子）另畫迴圈，奇偶規則會自動把島內判為不可走。
- 竹林郊區的例子看 `scenes/yuheng/Bamboo_Grove_Suburb/Bamboo_Grove_Suburb.tscn`，竹林迷宮看 `scenes/yuheng/yuheng_bamboo_outskirts/yuheng_bamboo_outskirts.tscn`。

### 物件碰撞：`BaseCollision`
- 每個摳出來的物件貼圖底下放 `BaseCollision/BaseShape`（碰撞形狀的座標是貼圖本地座標）。使用者偏好**橢圓**，而且「上面要多一點」（不要只有底部一條薄片）。
- 摳圖後的物件要套 Z：玩家的 `z = int(global y + z_index_offset)`。玩家腳底在原點下 **55.5px**（不是 50）。NPC／物件的腳底離原點距離不同，必須量測貼圖底緣，再用 `z_index_offset` 補差，讓「腳同高時 Z 相等」。例：阿婆腳底在原點下 40.8（scale 0.85），所以 `z_index_offset = -15`。
- 驗收原則（使用者的原話）：**Y 比較下面的人，Z 一定要比較上面，身體要遮住上面的物件**；不可出現「腳在物件下方卻被物件蓋住」。竹林的竹子是使用者刻意只摳「不需要 Z 的部位」，再用邊界限制路徑，所以那兩張圖的竹子沒有套 Z，這是設計，不是漏做。

### 出入口（蛋白蛋黃）
場景根節點用 metadata：`exit_ids` 加上每個出口的 `exit_<id>_yolk`／`_white`／`_method`／`_name`，由 `scripts/interaction/ObjectInteractionAdapter.gd` 讀取。`tests/test_object_interaction_adapter.gd` 列出已接好的場景與出口，新增場景請一併登記。使用者會用手繪標出蛋黃（蛋白）範圍；沒特別說的 NPC 維持預設蛋白蛋黃。

### 驗收方式
我用過的方法（腳本不在 repo 裡，需要時重寫）：用真實 `liu_yu.gd` 的移動（WALK 160／RUN 400）往四個方向衝撞確認不出界、flood-fill 檢查所有 spawn 與出口彼此可達、在乾淨背景圖上疊邊界線截圖給使用者看。**使用者會直接拿他畫的圖對你的結果**，請用同一座標系逐點對照。

## 三、最近完成但你可能會碰到的劇情改動
- **醉月茶坊「特殊階段」**（《臨風寄影》壓情後、《銀屏語》完成前）：門口演出一次，加上找紅徽音時的 A／B 循環短對白。邏輯集中在 `scripts/yuheng/yuheng_market_east/zueyue_teashop/TeaHouseQinSuppress.gd`，測試 `tests/test_tea_house_qin_suppress.gd`。結束條件是旗標 `event_yinpingyu_done`（使用者今天明確決定）。壓情旗標 `event_linfeng_qin_suppressed` 由白箋居詩人那段落。
- **主線 stage 盤點**（`main_001`，常數在 `scripts/QuestManager.gd`，Gate 規格在 `docs/main_quest_gate_audit.md`）：1 客棧開場 → 2 白書眠首談 → 3 顧石周旋 → 4 暴發戶事件後進白箋居 → 5 《銀屏語》 → 7 紅徽音首談給銅釦 → 8 廢井開啟 → 10 山莊夜談 → 11 啟程烈風寨。**stage 6、stage 9 目前沒有程式真的推進**（6 只是 stage 5 上的目標文字；9 鐘乳石洞還沒有推進點，夜談用「小於 11」判斷直接 8→10）。使用者說不用補，但做到鐘乳石洞時要留意。我今天也把紅徽音「stage 4 對話後推到 5」的舊邏輯拿掉了。
- 對白用語：角色一律寫**白書眠**（id 仍是 `shumian`）；非角色卡叫**僚卡／支援卡**；茶坊歌女顯示名是**紅徽音**。

## 四、工作規則（使用者的明確要求，請遵守）
1. **只有使用者說「commit」才提交**；不要 `git add -A`，只選自己動過的檔案。commit 訊息用英文，結尾加 `Co-Authored-By: ...` 署名行（依你的平台規定）。
2. **每個批次在 `docs/claude_diary.md` 末尾追加一條**（日期＋改了什麼＋為什麼）。
3. **忽略 `docs/gongbian_claude_handoff.md`**，不要讀、不要改。給美術的文件不要提到那個名稱。
4. Godot 會自動重存 `scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/` 底下的 `yuheng_sewer_true.tscn`、`yuheng_sewer_true_room/yuheng_sewer_true_room.tscn`，它們不是我們的改動，提交前先 `git status` 確認，再用 `git checkout -- <該檔案>` 還原。
5. GDScript **警告視為錯誤**：不要用 `:=` 從 Variant 推型別，改寫明確型別；弱引用物件用 `weakref`。
6. 測試用 `godot --headless --path . --script tests/xxx.gd`（本機路徑見 `README_CODEX.md`）。需要 autoload（`GlobalState`、`QuestManager`）的測試，要在執行期用 `load()` 取腳本，不能 `preload`。**不要用 `taskkill` 殺所有 Godot**——使用者可能開著編輯器。
7. **不要找藉口。**這是使用者今天很在意的一點：出錯就承認、修好、附驗證；不要把原因推給「你的編輯器沒重載／截圖是舊的」之類。使用者畫了標記圖，就直接和專案資料逐點對照；他畫了完整新邊界，就把舊線整個刪掉，不要新舊混用。只陳述驗證過的事實，推測要標明是推測；數值要量測，不要估算。
8. 規則細節以使用者的例子為準，不確定就問，不要自行發明規則。

## 五、未解決／可以順手問使用者的事
- 其他 NPC 的「腳底離原點距離」尚未全面量測；玩家是 55.5，每個 NPC 若不同，Z 就會有誤差（阿婆是因此出錯的）。可在做後續地圖時順便量。
- 竹林郊區新邊界使用者還沒完整試走過，他回報時請照上面的方法對圖修。
- 對白規格尚未統一前（見記憶「台詞規格統一待辦」），不要補寫掌櫃／店小二夜晚台詞與紅徽音銅釦後台詞。

祝順利。
