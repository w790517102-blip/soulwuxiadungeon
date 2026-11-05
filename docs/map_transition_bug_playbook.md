# 「剛進場就被傳走」類 BUG 的排查方法（給 Codex）

事件：從下水道調香室出來，回到中央房，**馬上被傳送到調音室**。調香室出口和調音室出口在中央房裡相距很遠，出生點也沒有壓到任何出口。這類 BUG 以前出現過，這次卡了一陣子，原因是排查只盯著「蛋白／蛋黃區有沒有重疊」。**這個 BUG 跟蛋白蛋黃無關。**

## 結論（這次的真正原因）
換場流程（`GameRoot.change_map_to`）的時序：

1. 舊場景 `queue_free`，新場景 `add_child`。
2. `await process_frame`，**之後**才把劉語塵搬到出生點。

步驟 1 到 2 之間，劉語塵**還站在上一張圖的出口位置**，而他是跨場景共用的同一個節點，座標是世界座標。這個座標套進新場景時，剛好壓在新場景另一個出口的 Area2D 上（調香室出口 ≈ (650, -300)，剛好落在中央房調音室出口的範圍內）。物理引擎在這一幀就發出 `body_entered`，而中央房的出口函式沒有防呆，直接淡出並換圖。等你被搬到出生點時，換圖已經在路上了。

## 該怎麼想（排查順序）
不要先問「這兩個出口的區域有沒有重疊」，而是問：**玩家在哪個時間點、站在哪個座標、被誰看見？**

1. **列出玩家座標的所有來源與先後。**換場時至少有三個：上一張圖離開時的座標（舊座標）、出生點、存檔或戰鬥回場還原的座標。哪一個在什麼時候生效？生效之前有沒有物理幀？
2. **用世界座標比對，不是區域座標。**場景根節點常有偏移（中央房根節點在 (-500, -1000)），出口 Area2D 又可能帶旋轉、傾斜（skew）、非等比縮放。人眼看編輯器很難判斷，要把每個 Area 的四個角算成世界座標，再把「舊座標」代進去。這次的算法在下一節。
3. **確認觸發的是哪一條路徑。**同一個出口可能有好幾條觸發路徑，每條的防呆不一樣：
   - `Area2D.body_entered`／`body_shape_entered`（舊式，寫在場景檔連線）；
   - `ObjectInteractionAdapter` 的手繪蛋白區（`activate_on_enter`）；
   - 滑鼠點擊移動的意圖。
   `ObjectInteractionAdapter` 會在 `adopt_scene` 時把舊的 `body_entered` 連線拔掉，但那是在 `await process_frame` **之後**。換場那一幀內，舊連線還在，所以可以被觸發。
4. **看每條路徑有沒有呼叫 `MapTransitionGuard.can_transition(body, area)`。**這是專案的標準防呆：換場期間上鎖、到達後有 1 秒寬限、出生點重疊的出口要先離開才重新啟用。出口函式只寫 `if body.name == "LiuYu":` 的，就是沒防呆。
5. **檢查防呆本身有沒有漏網。**`_collect_map_exit_areas` 以前只收 `to_` 小寫開頭的節點，`To_...` 被漏掉（已改成不分大小寫）。用名稱字串當條件的地方，都要懷疑大小寫、前後綴。

## 重現方法（寫腳本，比肉眼可靠）
不要只在編輯器裡看。用一個測試場景實際跑換場，並把玩家**放在舊場景的出口位置**：

```gdscript
extends Node
func _ready():
    var gr = load("res://scenes/game_root.tscn").instantiate()
    gr.name = "GameRoot"
    get_tree().root.add_child.call_deferred(gr)
    await get_tree().process_frame
    await get_tree().create_timer(1.0).timeout
    gr.change_map_to(ALCHEMY_ROOM)              # 先進來源房間
    await get_tree().create_timer(3.0).timeout
    var pl = gr.get_node("LiuYu")
    pl.global_position = Vector2(650, -300)     # 站在出口位置
    var room = gr.get_node("CurrentScene").get_child(0)
    room.call("_on_to_yuheng_sewer_center_body_entered", pl)   # 走出口
    # 每 0.25 秒印出 gr.current_map_path，看有沒有第二次換圖
```

- 用 `godot --path . <場景.tscn>`（不要 `--headless --script`，要有 autoload 和場景樹）。
- 玩家座標多試幾個（出口範圍的中心、邊緣）；這個 BUG 只在**某些**離開位置才會出現，所以玩家不一定每次遇到。
- 修好前後各跑一次：修前要能重現，修後 `[MapTransitionGuard] blocked while locked` 會出現。

## 世界座標怎麼算（Area2D 的形狀）
Godot 4 的 `CollisionShape2D` 變換：x 軸 = `(cos r, sin r)`，y 軸 = `(-sin(r+skew), cos(r+skew))`，再套上父節點的位置與縮放（縮放在最後）。矩形四個角 `(±w/2, ±h/2)` 代進去，加上場景根節點的位置，才是世界座標。也可以直接在場景裡讀 `shape_node.global_position`，但邊界要自己算。

## 這次的修法與原則
1. **根本修法：**換場時，`add_child` 之後**立刻**把玩家搬到出生點，不留舊座標給物理引擎看到（`game_root.gd`）。
2. **各出口再補防呆：**中央房六個出口函式都加 `MapTransitionGuard.can_transition(body, area)`。
3. **防呆的名稱比對不分大小寫。**

原則：**任何「玩家進入某區域就換圖」的邏輯，都要假設玩家的座標在換場瞬間是不可信的。**新增出口時照下面清單檢查：

- 出口函式有沒有呼叫 `MapTransitionGuard.can_transition`？
- 出口 Area 的節點名稱是不是被防呆認得（現在不分大小寫的 `to_` 開頭）？
- 回這個房間的出生點，有沒有壓在任何出口的範圍內？
- 從所有鄰接房間的出口位置進來，舊座標會不會落進這個房間的出口範圍？（這次漏掉的就是這一項。）

## 還沒確認的地方
下水道其他房間（調音室、符咒間、密室、終端室）回中央房的出口函式，我沒逐一檢查有沒有防呆。根本修法讓大多數情況不再發生，但新增或修改出口時請照上面清單走一次。
