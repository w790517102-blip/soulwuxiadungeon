# 探索互動系統（滑鼠八方向移動 × 距離互動 × 唯一互動目標）

檔案：`scripts/interaction/`（`InteractionGeometry.gd`、`InteractionTarget.gd`、`InteractionResolver.gd`，後者是 Autoload `InteractionResolver`），
測試：`tests/test_interaction_resolver.gd`。

## 分工
- **InteractionTarget**（掛在 NPC／物件底下的元件）：告訴裁決器「滑鼠指到哪裡算選中它」「劉語塵站在哪裡才能互動」「互動時做什麼」。
- **InteractionResolver**（Autoload）：唯一的輸入與裁決者。一次輸入最多一個互動；對話、選項、劇情、黑幕、選單中不接受新的互動。
- **liu_yu.gd**：只多一個 `mouse_move_direction`（由裁決器每個物理影格設定）。沒按 WASD 才用它；鍵盤永遠優先。

## 三種距離模式（`InteractionTarget.mode`）
| 模式 | 用在 | 能不能互動 |
|---|---|---|
| A `SPECIAL_AREA` | 白箋居櫃檯、隔窗、必須站在指定位置的機關 | 劉語塵在 `special_area`（手畫的 Area2D）裡 |
| B `RADIUS` | 一般 NPC（飲月山莊的書眠、左飲） | 腳底到 Anchor（預設畫面上的腳底）< `interaction_radius` |
| C `ZONE` | 大型魚怪、長形 NPC、石碑、車輛 | 腳底到 Reference Zone（`zone_rect`／`zone_polygon`）**最近位置**的距離 < `interaction_radius` |

C 的 Reference Zone 只是距離的幾何依據，不是要踩進去的觸碰區，也不是戰鬥碰撞箱。可選：`require_clear_path`（腳底到最近位置之間不能被障礙擋住，防止穿牆）、`interaction_side`（指定互動側）。

## Hover 距離與互動距離是兩個參數
- `hover_margin`：滑鼠離目標可見範圍多近算「指到」（在範圍內是 0）。劉語塵不必在旁邊。
- `interaction_radius`：劉語塵實際能互動的距離。

## 選目標
- **滑鼠**：比較滑鼠到各目標可見範圍的距離；距離一樣時依 `priority`，再依節點路徑（固定順序）。已選中的目標要被超過 4 px 才會換掉（不閃爍）。
- **空白鍵**：只看現在「能互動」的目標；比較劉語塵腳底到各目標有效區域的距離；一樣近時依面向、`priority`、固定順序。

## 滑鼠操作
- 左鍵按住：朝滑鼠方向移動（八方向量化，和 WASD 同一套方向與動畫），放開立刻停止；滑鼠在腳底 14 px 內不動。
- 按下時若滑鼠指著目標：鎖定它，靠近到互動距離就停下互動一次；途中經過別的目標的互動範圍也不會改跟別人說話；提早放開就取消。
- 同一次按住最多互動一次；互動結束後要放開再按。
- 一按 WASD 就取消滑鼠移動與尚未完成的靠近互動。
- 點在介面（CanvasLayer 上的 Control）、對話中、選單中、轉場鎖定、`can_move` 為 false（劇情鎖定）時都不產生移動或互動。
- **手繪地圖出口例外**：劉語塵從外走進出口蛋白區時即通行，不要求這次滑鼠按下始於出口蛋黃；蛋黃仍可點擊尋路。首次出現時若角色已站在出口蛋白區，需先離開再進入，避免進場立即折返。普通 NPC／物件維持「先點蛋黃才互動」。

## 游標
`InteractionResolver.CURSOR_KINDS`：`talk`、`inspect`。圖檔放 `assets/UI/cursor/cursor_talk.png`、`cursor_inspect.png`（目前專案沒有這些圖，沒圖就用內建的手指游標）。

## 遷移方式
在場景腳本裡替 NPC 加一個 `InteractionTarget`（設定 `handler`、`availability`），並刪掉該 NPC 自己監聽 Space 的程式碼——**同一個 NPC 不能新舊兩套同時回應**。
目前只有飲月山莊白天的白書眠與左飲（`yin_yue_manor_room(day).gd`）遷移；其他 NPC 與自動劇情觸發區仍維持原樣。場景 metadata 手繪的地圖出口由 `ObjectInteractionAdapter` 建立 `InteractionTarget`，並以蛋白區進入事件為通行入口；舊出口 `Area2D` 保留偵測但不再重複呼叫同一個出口函式。
