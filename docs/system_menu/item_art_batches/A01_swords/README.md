# 道具專屬美術 A01：四把劍

木劍 wep_wood_sword、鐵劍 iron_sword、青銅劍 bronze_sword、青鋒劍 wep_qingfeng_sword。

共八張正式透明 RGBA PNG：每件 art 為380×560，icon為80×80。依需求檔名放在 assets/UI/inventory/dedicated/；將此 assets 目錄合併到專案同一路徑，即可供現有自動尋圖機制使用。

原始圖以內建 image_gen 製作；技術輸出僅做透明邊界取景、等比縮放、置中與無損 PNG 壓縮。小圖與大圖使用同一件原畫，沒有另外生成不同造型。圖內沒有名稱、數量、稀有度章或底卡；乾筆與宣紙紋理保留在主體材質中。

preview_A01.png 上方為大圖預覽，下方為兩種底色的實際80×80小圖，英文名稱只在預覽，沒有烤入素材。asset_check.json 列出尺寸、大小、RGBA、透明與雜湊資訊；每張PNG皆小於250000 bytes。PROMPTS.json 保留製圖提示。

此批只交道具詳情圖與圖示，未改動 Godot 程式，也未交付紙娃娃武器層。紙娃娃需對照劉語塵／白書眠母圖與既有武器掛點後另製。實機介面效果仍須接入驗證。

總清單79件，此批製作4件，尚有75件未製作；progress.csv 中「已製作」不代表老闆已完成美術驗收。
