# 玉衡鎮第一章主線 Stage / Gate 規格

本文件先整理 `main_001` 目前主線 stage 與事件入口 gate 條件，避免後續串接劇情時只靠 stage 造成跳關。

## main_001 stage 對照表

| Stage | 常數 | 任務目標 |
| --- | --- | --- |
| 1 | `STAGE_YH_INVESTIGATE` | 初到玉衡鎮，打聽左飲消息。 |
| 2 | `STAGE_YH_GO_TO_MANOR` | 見過書眠，前往飲月山莊。 |
| 3 | `STAGE_YH_MANOR_GATE` | 飲月山莊守門／顧石三層攻防。 |
| 4 | `STAGE_YH_BAIJIANJU_OPEN` | 飲月山莊閉莊，回鎮尋線，白箋居事件開啟。 |
| 5 | `STAGE_YH_YINPINGYU_DONE` | 白箋居《銀屏語》完成，夜晚紅徽音弦外之音待觸發。 |
| 6 | `STAGE_YH_GO_TO_ZUIYUE` | 前往醉月茶坊找紅徽音。 |
| 7 | `STAGE_YH_SEWER_STARTED` | 紅徽音告知舊水道線索，前往舊井／舊水道。 |
| 8 | `STAGE_YH_SEWER_MECHANISMS` | 舊水道三機關與終端房。 |
| 9 | `STAGE_YH_STALACTITE_CAVE` | 鐘乳石洞，書眠與魚怪戰。 |
| 10 | `STAGE_YH_NIGHT_MEETING` | 飲月山莊夜會，準備前往清風竹林。 |
| 11 | `STAGE_YH_LIEFENG_STARTED` | 清風竹林／烈風寨章開始。 |

## Gate Audit

| 入口 | 目前觸發條件 | 必要 stage | 必要 flags | 完成後 flags / stage | 跳關風險與規格 |
| --- | --- | --- | --- | --- | --- |
| 書眠初期互動 `su_mien.gd` | 玩家與書眠互動；三位白箋居客人都遇過。 | `STAGE_YH_INVESTIGATE` | `met_bai_jian_jue_guestA/B/C` | `met_Su_Mien`; advance 到 `STAGE_YH_GO_TO_MANOR` | 合理；不可只因 stage 1 就推進，仍須三位客人 flags。 |
| 顧石／飲月山莊守門 `gu_shi.gd` | 與顧石互動，依便當與顧石攻防 flags 分段。 | 建議 `STAGE_YH_MANOR_GATE` | `main_yh_lunchbox_received` 或便當道具、後續顧石 flags | `main_yh_lunchbox_delivered`, `main_yh_gushi_stage_*_done`, `main_yh_manor_closed` | 目前主要靠 flags，安全；建議閉莊時同步 advance 到 stage 4。 |
| 白箋居暴發戶 `baijianju_richman_trigger.gd` | 玩家進入 Area2D。 | `STAGE_YH_BAIJIANJU_OPEN` | `main_yh_manor_closed`, not `event_baijianju_richman_done` | `event_baijianju_richman_done`, `main_yh_baijianju_open` | 目前有 flag gate；建議主線 stage 也至少到 4。 |
| 《銀屏語》事件 `baijianju_yinpingyu_story_shumian.gd` | 白箋居主線專用書眠存在且互動。 | `STAGE_YH_BAIJIANJU_OPEN` | `main_yh_baijianju_open`, not `event_yinpingyu_done` | `event_yinpingyu_done`, `item_yinpingyu_obtained`, `main_yh_ready_huiyin_voice` | 目前 flag gate 合理；建議完成時 advance 到 stage 5。 |
| 夜晚西市集紅徽音弦外之音 | ready 後自動或重疊檢查。 | `STAGE_YH_YINPINGYU_DONE` | `main_yh_ready_huiyin_voice`, not `event_huiyin_voice_done` | `event_huiyin_voice_done`, `main_yh_heard_huiyin_voice`, `main_yh_go_to_zuiyue_huiyin` | 目前靠 flags，安全；建議完成時 advance 到 stage 6。 |
| 醉月茶坊紅徽音主線 | 與紅徽音互動，依 stage 分流。 | `STAGE_YH_GO_TO_ZUIYUE` | `main_yh_go_to_zuiyue_huiyin`; 後續應新增 `event_huiyin_first_talk_done` 或 `main_yh_zhuoqu_xunzong_started` | 後續應設定舊水道線索 flag 並 advance 到 stage 7 | 目前 stage 分流偏多，後續不可只靠 stage >= 6 開地下水道。 |
| 夜晚禁止入口 | 玩家進入 forbidden Area2D。 | 不建議只看 stage | `main_yh_go_to_zuiyue_huiyin` | 無 | 目前用 required_flag，安全。 |
| 舊井／舊水道入口 | Area2D 切圖。 | `STAGE_YH_SEWER_STARTED` | 建議 `event_huiyin_first_talk_done` 或 `main_yh_zhuoqu_xunzong_started` | 進入舊水道後可標 `main_yh_sewer_entered` | 目前入口可能缺主線 gate；後續需補，避免未聽紅徽音就進主線水道。 |
| 舊水道三機關與終端房 | 水道房間互動與終端房封印。 | `STAGE_YH_SEWER_MECHANISMS` | `sewer_alchemy_solved`, `sewer_music_solved`, `sewer_talisman_solved` | `sewer_final_seal_opened` | 目前終端房有三機關 flags；建議解除封印時 advance 到 stage 9 前置。 |
| 鐘乳石洞魚怪戰 | 進入鐘乳石洞後 intro/battle。 | `STAGE_YH_STALACTITE_CAVE` | `sewer_final_seal_opened`; not `event_stalactite_shumian_intro_done` / not `battle_stalactite_fish_boss_won` | `battle_stalactite_fish_boss_*`, `main_yh_manor_after_fish_ready` | 必須要求終端房封印已開，不可只靠 stage >= 9。 |
| 飲月山莊夜間會談 | 夜間山莊 event_area / ready。 | `STAGE_YH_NIGHT_MEETING` | `main_yh_manor_after_fish_ready`, not `event_yin_yue_night_meeting_done` | `event_yin_yue_night_meeting_done`, `main_yh_ready_for_qingfeng`, `party_shumian_join_*` | 必須要求魚怪戰完成後旗標。 |
| 書眠《渠燈補封》支線入口 | 舊水道真房／書眠相關互動。 | 建議 stage 10 前後 | `shumian_pre_departure_available`, not `shumian_clean_sewer_done` | `shumian_clean_sewer_done` | 不應阻斷主線，但若影響夜會選項需以 flag 判斷。 |
| 左飲出發清風竹林事件 | 夜會後轉場。 | `STAGE_YH_LIEFENG_STARTED` | `event_yin_yue_night_meeting_done`, `main_yh_ready_for_qingfeng`, `main_yh_zuoyin_supplies_received` | `main_chapter_liefeng_started` | 不可只靠 stage >= 11；需確認夜會與補給完成。 |

## 目前優先跳關風險

1. 醉月茶坊紅徽音後續若只用 stage 推進，可能在未完成《銀屏語》或弦外之音前開啟舊水道線。
2. 舊井／舊水道入口目前偏向純 Area2D 切圖，後續主線版入口需要補 `main_yh_zhuoqu_xunzong_started` 等 flag gate。
3. 鐘乳石洞入口需要明確要求 `sewer_final_seal_opened`，不能只看 stage。
4. 飲月山莊夜會需要明確要求魚怪戰勝利後的 `main_yh_manor_after_fish_ready`。
