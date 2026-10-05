# 武學的消耗與可用性（SkillView）

`scripts/battlescripts/SkillView.gd` 是戰鬥出招列表、Card Inspect 武學頁與 `BattleController.execute_action` 共用的唯一資料來源：

| 函式 | 用途 |
|---|---|
| `mp_cost(actor, skill)` | 這個角色現在實際要付的內力（含內功的消耗倍率） |
| `check(actor, skill, include_weapon=false)` | `{ok, code, text, need, have}`；目前原因：`mp`（內力不足）、`stance`（姿態禁止）、`weapon`（只在 `include_weapon` 時，給會列出無法裝備招式的畫面）。**新增原因＝在這裡加一個分支**，畫面只顯示 `text` |
| `can_use` / `disabled_reason` | `check` 的簡寫 |
| `strike_info(skill, inner_force)` | `{base, effective, delta, source}`：基礎／目前攻擊次數與修正來源 |
| `muted(color)` | 同色相、降低飽和度與亮度（不可用的招式） |
| `effect_summary(skill)` | 效果簡述 |

## 流程（兩層檢查）
1. **UI 預檢**：出招列表每項顯示「名稱　N MP」；內力不足的招式留在清單裡、仍可選取看說明，但以 `muted` 色顯示，說明最上面寫「內力不足：需要 N，目前 M」，確認鍵不可按（卡片舞台的選單足尾顯示「無法使用」，按了不會關閉選單）。
2. **執行前再驗證**：`BattleUI._on_PopupSkillSelect_skill_selected` 再看一次；`BattleController.execute_action` 在扣任何東西前再 `SkillView.check` 一次。
3. **被拒絕的招式不吃回合**：不扣內力、不設 `acted_this_turn`、ADB 不動；控制器設 `last_action_rejection`（`"mp"`／`"stance"`），`BattleUI._apply_skill_and_finish_turn` 看到就 `_reopen_skill_list_after_rejection()` 回到技能清單（卡片舞台版由 `StageBattleUI` 覆寫），**不**發 `player_action_complete`。

測試：`tests/test_skill_availability.gd`。
