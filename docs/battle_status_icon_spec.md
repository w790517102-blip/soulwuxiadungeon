# 戰鬥狀態 Status Icon：現況調查與美術製作規格

調查範圍：目前實際存在的程式與資料（`scripts/battle/StatusEffectManager.gd`、`scripts/battlescripts/BattleUI.gd`、`BattleController.gd`、`ItemEffectDispatcher.gd`、`scripts/db/SkillDB.gd`、`ItemDB.gd`、`scripts/presentation/CardStage*.gd`）。
只列程式裡確實存在的內容，沒有依推測補項目。本輪**沒有**畫 ICON、沒有改現有文字顯示、沒有動 `StatusEffectManager` 與任何數值。

> 名詞：「戰場顯示字」＝ Card Stage 角色卡下方現在顯示的單字（`BattleUI.DEBUFF_ABBREV` / `BUFF_ABBREV`，debuff 紅 `#ff6b6b`、buff 綠 `#67e08a`）。

---

## 1. 目前實際存在的戰鬥狀態（Canonical Item List）

狀態存在 `actor["status_effects"][effect_id] = {payload, turns_left, decrement_timing}`。
一個 id 同時只有一筆；重複施加是「刷新」（覆蓋回合數與 payload），**沒有疊層、沒有 stack**。
別名：`buff_speed → speed_buff`；`speed_debuff / debuff_speed → slow`。

### 1.1 異常／控制（Control / Debuff）

| internal id | 顯示名稱 | 類型 | 戰場顯示字 | 效果簡述 | duration | 遞減時機 | 可疊加 | 需顯示 stack | 有相反版本 |
|---|---|---|---|---|---|---|---|---|---|
| `stun` | 暈眩 | Control | 暈 | 該角色的回合被跳過 | 有（技能資料多為 1） | 擁有者行動後 | 否（刷新） | 否 | 無 |
| `confuse` | 混亂 | Control | 亂 | 單體行動可能誤擊敵我 | 有（多為 2） | 回合結束 | 否 | 否 | 無 |
| `poison` | 中毒 | Debuff | 毒 | 每個回合結束損失 max(10, 最大生命 5%) | 有（多為 3） | 回合結束 | 否 | 否 | 無（有解毒道具移除） |
| `slow` | 速度下降 | Debuff | 緩 | 速度 −N（預設 10，技能資料 3–20） | 有（2–3） | 擁有者行動後 | 否（重施會先移除再套） | 否 | 是：`speed_buff` |
| `weaken` | 無力 | Debuff | 弱 | 攻擊 −N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`atk_up` |
| `break_def` | 破防 | Debuff | 破 | 防禦 −N（預設 10） | 有（2–3） | 回合結束 | 否 | 否 | 是：`def_up` |
| `weak` | 虛弱 | Debuff | 衰 | 最大生命 −N（預設 30） | 有（3） | 回合結束 | 否 | 否 | 無 |
| `seal_mp` | 封穴 | Debuff | 損 | 最大內力 −N（預設 15） | 有（3） | 回合結束 | 否 | 否 | 無 |
| `blind` | 目盲 | Debuff | 盲 | 命中 −N（預設 15） | 有（2–3） | 回合結束 | 否 | 否 | 是：`focus` |
| `root` | 定身 | Debuff | 困 | 閃避 −N（預設 20） | 有（2–3） | 回合結束 | 否 | 否 | 是：`evasion_boost` |
| `stat_debuff_str` | 壓勁 | Debuff | 力 | 力量 −N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`stat_buff_str` |
| `stat_debuff_agi` | 亂弦 | Debuff | 敏 | 敏捷 −N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`stat_buff_agi` |
| `stat_debuff_int` | 惑思 | Debuff | 智 | 智慧 −N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`stat_buff_int` |
| `stat_debuff_con` | 奪息 | Debuff | 體 | 體能 −N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`stat_buff_con` |
| `stat_debuff_luck` | 厄運 | Debuff | 幸 | 幸運 −N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`stat_buff_luck` |

> 目前資料裡實際施加的 `stat_debuff` 只有「敏捷」一種（`SkillDB.gd:714`）；其餘四種屬性版是系統支援、資料尚未使用。

### 1.2 增益（Buff）

| internal id | 顯示名稱 | 類型 | 戰場顯示字 | 效果簡述 | duration | 遞減時機 | 可疊加 | 需顯示 stack | 有相反版本 |
|---|---|---|---|---|---|---|---|---|---|
| `speed_buff` | 速度提升 | Buff | 速 | 速度 +N | 有（2–3） | 回合結束 | 否 | 否 | 是：`slow` |
| `atk_up` | 昂勢 | Buff | 攻 | 攻擊 +N（預設 10） | 有（2–3） | 回合結束 | 否 | 否 | 是：`weaken` |
| `def_up` | 護脈 | Buff | 防 | 防禦 +N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`break_def` |
| `focus` | 凝神 | Buff | 命 | 命中 +N（預設 15） | 有（3） | 回合結束 | 否 | 否 | 是：`blind` |
| `evasion_boost` | 輕身 | Buff | 閃 | 閃避 +N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`root` |
| `stat_buff_str` | 強身 | Buff | 力 | 力量 +N（預設 10） | 有（3） | 回合結束 | 否 | 否 | 是：`stat_debuff_str` |
| `stat_buff_agi` | 敏捷 | Buff | 敏 | 敏捷 +N | 有（3） | 回合結束 | 否 | 否 | 是：`stat_debuff_agi` |
| `stat_buff_int` | 啟慧 | Buff | 智 | 智慧 +N | 有（3） | 回合結束 | 否 | 否 | 是：`stat_debuff_int` |
| `stat_buff_con` | 健體 | Buff | 體 | 體能 +N | 有（3） | 回合結束 | 否 | 否 | 是：`stat_debuff_con` |
| `stat_buff_luck` | 聚福 | Buff | 幸 | 幸運 +N | 有（3） | 回合結束 | 否 | 否 | 是：`stat_debuff_luck` |

> `stat_buff_*` 系統支援，但**目前沒有任何技能／道具資料施加**（`SkillDB`、`ItemDB` 都沒有 `stat_buff`）。
> 注意：「護脈」是 `def_up` 的顯示名，與 ADB 的「護脈符」僚卡是兩回事，美術命名時要避免混淆。

### 1.3 同時含增減益、特殊

| internal id | 顯示名稱 | 類型 | 戰場顯示字 | 效果簡述 | duration | 遞減時機 | 可疊加 | 備註 |
|---|---|---|---|---|---|---|---|---|
| `warm_wine_buff` | 暖身酒 | Special（同時 Buff＋Debuff） | 攻（BUFF_ABBREV）＋盲（命中 −5 時額外補一個「盲」） | 速度 +10、命中 −5 | 有（道具 3） | 回合結束 | 否 | 現在的字「攻」與實際效果（加速）對不上，是既有行為，不是本輪調整項 |
| `force_element` | 元素變化 | Special | **無（不顯示）** | 把該角色屬性改成快／柔／遲／剛，到期還原 | 有（2–3） | 回合結束 | 否 | payload 有 `element`，ICON 可能需要四種屬性變體 |
| `yumei_entanglement` | 語魅纏身 | Special | **無（不顯示）** | 護住該角色：玩家造成的生命傷害歸零 | 無回合數顯示（手動移除） | 手動 | 否 | 墨鱗魘將階段機制（`BattlePhaseProfileDB`） |

### 1.4 不在 `status_effects`、但現在也以單字顯示的狀態

| 來源 | 顯示字 | 效果簡述 | duration | 備註 |
|---|---|---|---|---|
| `battle_modifiers.pen_damage_up` | 攻 | 筆系傷害提升（書籍道具，值 0.2） | 整場戰鬥 | 無回合數 |
| `battle_modifiers.pen_damage_resist` | 防 | 受筆系傷害降低（值 0.1） | 整場戰鬥 | 無回合數 |
| 屬性補值（沒有對應效果 id 時的保底） | 命／盲／閃／困 | `accuracy_mod` > 0 → 命；< 0 → 盲；`evasion_mod` > 0 → 閃；< 0 → 困 | 無 | 來源可能是內功等，不一定有狀態 id |

另外：`defending`（防禦姿態）不是狀態文字，現在以防禦薄膜 FX 表現，**不在單字列**。

### 1.5 現況的已知歧義（給美術與企劃參考）
- 同一字多義：「攻」＝ `atk_up` / `warm_wine_buff` / 筆傷害提升；「力敏智體幸」增益與減益共用同一字，只靠紅綠底色區分。
- 「弱」＝ `weaken`，「衰」＝ `weak`，名稱相近容易混。
- 每種「會同時存在正負版本」的屬性，ICON 必須能一眼分出增減（見第 4 節建議）。

---

## 2. 目前已有資料 hook、但**不是**戰鬥狀態的項目（與第 1 節分開）

程式／資料裡找不到「已有 hook、將來一定會出現」的**新狀態 id**：`ToneMap` 的 `status_apply_tones` / `status_suffer_tones`、`ItemDB` 的 `cure_status`（毒／暈／亂）都只用到上面已有的 id。以下是和「狀態圖示」相關、但屬於別的系統，列出供企劃決定是否也要 ICON：

| 項目 | 現況 | 是否屬於 `status_effects` |
|---|---|---|
| ADB 僚卡鄰接效果家族 `StageAdjacency.FAMILIES`：`DEFENSE_UP`、`ATTACK_UP`、`STRENGTH_UP`、`CONSTITUTION_UP`、`AGILITY_UP`、`INTELLECT_UP`、`LUCK_UP`、`RALLY_ATTACK_UP`（戰鼓用，僚卡尚未製作）、`DAMAGE_REDUCTION`、`PARRY_UP`、`STATUS_RESIST` | 由僚卡依牌陣位置即時計算，不寫進 `status_effects`；`DAMAGE_REDUCTION`、`PARRY_UP`、`STATUS_RESIST` 目前沒有任何資料使用 | 否（現在護脈符等以卡面光暈表現「被護持」） |
| 站姿 `HOLDING_SHEATH`（`actor.stance`） | 劉語塵持鞘時存在，影響可用技能；由持鞘僚卡表現，無單字 | 否 |
| 僚卡 READY／已行動 | 已行動的卡立繪變暗＋紅字「行動結束」（`set_standby`） | 否 |

---

## 3. Card Stage Status UI 技術限制（現況）

| 項目 | 現況 |
|---|---|
| 實作 | 每張角色卡一個 `RichTextLabel`（節點名 `StatusWords`，`CardStageActorCard.gd:142`），BBCode 單行文字，**目前完全沒有貼圖／ICON 節點** |
| 更新頻率 | `StageBattleUI._process` 每 0.15 秒用 `_build_status_abbrev_text(actor)` 重寫文字（`StageBattleUI.gd:299-305`） |
| 繪製座標系 | 卡面是 `SubViewport`，版面座標一律用「模板畫布」：角色／敵人／野獸／江湖／山賊／朝廷 = 1024×1536；Boss = 1507×1044。Viewport 實際解析度 = 畫布 × 0.75，再貼在 3D 卡面上 |
| 狀態區位置（畫布像素） | 角色卡：`Rect2(140, 1366, 746, 76)`，在 MP 條下方、卡片底部；一般敵人／野獸／江湖／山賊／朝廷：`Rect2(100, 1212, 824, 150)`，在屬性／種族／血條下方；Boss：`Rect2(480, 786, 496, 130)` |
| 字級 | 角色與一般敵人 40；Boss 28 |
| 排列 | 單行、不換行（`autowrap_mode = OFF`）、`clip_contents = true`，向左對齊；debuff 在前、buff 在後，中間一個空白 |
| 一張卡最多同時顯示幾個 | **沒有程式上限**。實際受寬度限制：字級 40 時約 18–20 個字；超過會被裁切（`clip_contents`），不會換行、不會折疊、不會顯示「+N」。理論上一個角色可同時有 25 以上種狀態 |
| duration | **不顯示數字**。只有「剩 1 回合」時該字與「·」交替閃爍（正弦，約 0.36 秒週期；`BattleUI._build_status_abbrev_text`） |
| stack | 不存在（沒有疊層概念），不顯示 |
| 玩家／敵人共用尺寸 | 共用同一份程式與同樣字級；但**狀態區矩形不同**（角色 746×76，敵人 824×150，Boss 496×130） |
| Stage Entity（僚卡）是否共用 | **否**。`CardStageTokenCard` 沒有狀態列，只有一個印章徽記（剩餘次數／倒數，如「×3」）；僚卡本身不是 `status_effects` |
| 舊版 UI | 舊 `StageActorCard`（CombatStage25D 原型）有自己的 `StatusWords`（敵 `(218,248) 380×42`、我 `(332,66) 245×42`，字級 34）；舊 2D `BattleUI` 有 120×28 的右對齊 `StatusAbbrev_*` 疊層。三條路徑都共用同一個 `_build_status_abbrev_text`，因此日後 ICON 化可在這一個函式分流 |
| 顯示色 | debuff `#ff6b6b`、buff `#67e08a`；`·` 為閃爍時的占位字 |

### 3.1 建議的 ICON 尺寸（供美術）
實際螢幕大小：以 1920×1080、卡片約 700 px 高估算，畫布 1536 px 高 ≈ 0.45 倍縮放，所以 **畫布上 64 px 的 ICON 約等於螢幕 29 px**。

| 項目 | 建議 |
|---|---|
| 畫布上的顯示尺寸 | 角色卡 **64×64**（狀態區高度 76）；一般敵人 64×64，可排兩行（區高 150）；Boss **56×56**，可排兩行（區高 130） |
| 建議素材原始尺寸 | **256×256 px**（母檔）；程式讀取可用 **128×128**。兩者皆為正方形 |
| 透明背景 | **需要**（PNG，8-bit RGBA；邊緣預乘或留 2 px 透明 padding） |
| Atlas | 目前**沒有**使用 atlas；建議第一版單檔 PNG 逐張載入（約 30 張），之後效能需要再打包 |
| 必須在 24–32 px 螢幕尺寸下仍可辨識 | 輪廓優先、避免細線；增益／減益需有統一的「底板／邊框色」（綠／紅）作區別，不要只靠圖案 |
| 增減益成對的屬性 | 見 1.1／1.2 的「有相反版本」：建議同一個基礎圖形＋上／下箭頭或不同底色，畫成成對兩張 |

---

## 4. 建議檔名規格

放置路徑建議：`res://assets/UI/card_stage/status/`。檔名 = `status_` + internal id（全小寫、底線）+ `.png`。別名 id 不另做圖。

| internal id | 建議檔名 | 備註 |
|---|---|---|
| `stun` | `status_stun.png` | |
| `confuse` | `status_confuse.png` | |
| `poison` | `status_poison.png` | |
| `slow`（含別名 `speed_debuff`、`debuff_speed`） | `status_slow.png` | |
| `weaken` | `status_weaken.png` | 攻擊下降 |
| `break_def` | `status_break_def.png` | |
| `weak` | `status_weak.png` | 最大生命下降，避免與 `weaken` 混淆 |
| `seal_mp` | `status_seal_mp.png` | |
| `blind` | `status_blind.png` | |
| `root` | `status_root.png` | |
| `stat_debuff_str` / `agi` / `int` / `con` / `luck` | `status_stat_debuff_str.png` 等五張 | |
| `speed_buff`（含別名 `buff_speed`） | `status_speed_buff.png` | |
| `atk_up` | `status_atk_up.png` | |
| `def_up` | `status_def_up.png` | 顯示名「護脈」，勿與護脈符僚卡混用圖 |
| `focus` | `status_focus.png` | |
| `evasion_boost` | `status_evasion_boost.png` | |
| `stat_buff_str` / `agi` / `int` / `con` / `luck` | `status_stat_buff_str.png` 等五張 | |
| `warm_wine_buff` | `status_warm_wine_buff.png` | 同時有增減益，需設計成混合 |
| `force_element` | `status_force_element.png`（可另加 `status_force_element_fast.png` / `_soft.png` / `_slow.png` / `_hard.png`） | 目前不顯示；是否要顯示由企劃決定 |
| `yumei_entanglement` | `status_yumei_entanglement.png` | 目前不顯示；Boss 階段機制 |
| `battle_modifiers.pen_damage_up` | `status_pen_damage_up.png` | 非 `status_effects`，整場有效 |
| `battle_modifiers.pen_damage_resist` | `status_pen_damage_resist.png` | 同上 |

合計：`status_effects` 內 28 個 id（不含別名）＋ 2 個戰鬥修正 ＝ **30 張**（`force_element` 變體不計）。

---

## 5. Fallback 要求（下一輪實作時遵守）
- 現有單字（毒／暈／緩／亂／弱／破／衰／損／盲／困／力敏智體幸／速／攻／防／命／閃）**必須持續可用**，不得刪除。
- 查貼圖的 key 用 canonical id（先做別名正規化）；`ResourceLoader.exists()` 為假或載入失敗時，**該狀態單獨退回單字**，其他有圖的狀態照常顯示 ICON；整列不得空白、不得報錯。
- 單字與 ICON 可同一列混排。
- 最後一回合的閃爍行為需要在 ICON 版保留（目前是字與「·」交替）。

## 6. 本輪沒做的事
沒有生成任何 placeholder 美術；沒有刪除或改動現有文字顯示；沒有重構 `StatusEffectManager`；沒有改任何狀態的遊戲數值。
