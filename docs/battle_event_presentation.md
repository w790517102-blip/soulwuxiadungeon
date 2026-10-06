# Battle Event Presentation（戰場資訊演出層）

玩家不看底部戰報也能看懂戰場：傷害、治療、暴擊、相剋、MISS、格擋、攔截、狀態、回合開始。
遊戲邏輯只回報「發生了什麼」，演出層決定「怎麼跳、什麼顏色、何時消失」；Tween 細節不進 BattleController。

## 三種資訊，三種呈現
| 種類 | 內容 | 呈現 |
|---|---|---|
| Numeric | 傷害、治療 | 數字 popup（傷害會累加） |
| Status / Event | MISS、格擋、攔截、免疫、無效、狀態附加／解除（暴擊、相剋目前以數字顏色表現，事件類型已預留） | ICON（有圖才顯示）+ 短文字，貼在目標卡上 |
| Announcement | 第 X 回合開始 | 畫面上方中央、較大、無 ICON |

資訊分層（不變）：事件發生＝ICON+短文字；戰場常駐＝單字；Card Inspect＝ICON+完整名稱+效果+回合+來源。

## 檔案
- `scripts/presentation/BattleEvent.gd`：資料。`make()` 事件欄位 `event_type / icon_key / primary_text / value / target / source / priority / duration`；
  `damage_hit()`（`sequence_id, hit_index, hit_total, hit_value, cumulative_value, result_type, is_final_hit`）、`heal_event()`、`status()`、`announcement()`；`texture_for(icon_key)`。
- `scripts/presentation/BattleEventPresenter.gd`：渲染。`schedule_strikes()`／`schedule_run()` 把一招的每一擊排在各自的時間點；`show_damage / show_heal / show_event / announce`。
- 接點：`CardStageBattleUI`（`play_heal_number / play_status_event / play_battle_event / announce_round`，自帶 CanvasLayer 55）、
  `CardStage3D`（`_show_attack_popups`、`show_area_popups`、`_popup_timing`）、`BattleController`（只呼叫 UI：治療數字、`_present_status_event`、回合開始；範圍攻擊事件補上 `damage / element_advantage`）。

## ICON 與 fallback
- Status 事件直接用現有狀態圖：`status_<id>.png`（經 `StatusDisplayDB.icon_key`），不另做第二套。
- 其他事件圖放 `assets/UI/card_stage/event/event_<name>.png`（`event_miss / block / intercept / immune / nullified / critical / counter / status_removed`），**放進去就會自動出現**。
- 沒圖：只顯示文字；不報錯、不空白、不消失；演出與 gameplay 都不依賴貼圖是否存在。

## 傷害數字
- 同一招、同一目標＝一個 `sequence_id`＝一顆 popup：25 → 50 → 75 → 100（累加）。AoE 每個目標各自一顆，不合計。
- 第一擊：從受擊處被打上去、停住（scale punch）。之後每擊：只更新數字，小跳＋閃一下，不重播出現動畫。
- 只有最後一擊：停留約 0.34 秒讓玩家看清最終值 → 落下 → bounce → 抖動 → fade。落下的尾巴不鎖戰鬥流程。單段＝第一擊即最後一擊。
- 顏色：普通＝米黃；相剋＝金黃（淡金光）；暴擊＝紅（字較大、跳更高、punch 更強）；暴擊＋相剋＝紅字＋金黃外光。多段時以最新一擊的性質暫時改變外觀，不加額外統計文字。暴擊字尾加「!」。
- MISS／格擋／攔截／無效不顯示 0，而是顯示該詞。傷害為 0 且非被格擋者視為「無效」。
- 治療：`+45`，淡綠，從低處輕輕上升、小 bounce、fade，不用被打上去的重擊感。

## 時間點
各武器動畫是分開的程式路徑；popup 依 `CardStage3D._popup_timing()`（首擊到達時間、每擊間隔）排程，數字跟動畫大致同步。
劍／刀、筆有各自的數值，其他武器用預設值，**可在該函式調整**。範圍攻擊（拳雨、拳掌連擊、敵方範圍技）依各自的出手間隔排。

## 沒做
不改 StatusEffectManager、傷害／暴擊／相剋公式、戰場常駐狀態列，也沒重構 BattleController。狀態「解除」事件已有資料與渲染（`BattleEvent.status(id, false)`），尚未在遊戲邏輯接上（沒有統一的解除出口）。

測試：`tests/test_battle_event_popups.gd`（累加、單段、MISS/攔截/格擋、無 ICON fallback、公告、治療、AoE 各自累加、舞台接線）。
