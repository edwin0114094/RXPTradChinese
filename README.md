# RXP 繁體化（顯示轉換）

把 **RestedXP Guides** 顯示的簡體中文，在畫到畫面前轉成繁體中文。

不修改 RXP 的任何檔案，也不碰攻略資料。RXP 更新後不需要重裝。

## 安裝

1. 下載並解壓縮（右上角 **Code → Download ZIP**，或到 [Releases](../../releases) 取得）
2. 把裡面的 `RXPTradChinese` 資料夾整個放進：

```
World of Warcraft\<版本>\Interface\AddOns\
```

`<版本>` 是你玩的客戶端資料夾，例如 `_retail_`、`_classic_era_`、`_forever_`。

3. 完全重開遊戲（不是 `/reload`）
4. 進遊戲後輸入 `/rxptc` 確認狀態

需要先安裝 [RestedXP Guides](https://www.curseforge.com/wow/addons/restedxp-guide)，本插件會在它之後載入。

## 什麼情況下有效果

RXP 的內建簡體攻略只在 `GetLocale()` 回傳 `zhCN` 時才載入。

| 你的情況 | RXP 內建攻略 | 本插件 |
| --- | --- | --- |
| 簡體中文客戶端 | 顯示簡體 | 轉成繁體 |
| 繁體客戶端，但有插件強制 `GetLocale()` 為 `zhCN` | 顯示簡體 | 轉成繁體 |
| 繁體客戶端，沒有上述插件 | 顯示英文 | 無作用 |

匯入的簡體攻略（存在 SavedVariables 的）不受語言限制，一律會被轉換。

## 運作方式

RXP 照常產生文字，本插件在文字送到畫面前攔下來做簡轉繁。掛鉤四個地方：

| 掛鉤 | 轉換的內容 |
| --- | --- |
| `RXP.ReplaceNpcIds` | 攻略步驟全文、地圖提示 |
| `RXP.GuideNames` | 右鍵選單的攻略名稱 |
| `RXP.GetGuideName` | 攻略顯示名 |
| `RXPFrame.GuideName.text` | 視窗頂端的標題 |

前三個是 RXP 自己提供的查表點，不是硬改它的程式碼。

## 指令

| 指令 | 作用 |
| --- | --- |
| `/rxptc` | 顯示字典筆數與四個掛鉤的狀態 |
| `/rxptc <文字>` | 測試某段文字的轉換結果 |

RXP 更新後建議打一次 `/rxptc`。四個掛鉤都顯示 OK 就正常。若出現「未掛」，代表 RXP 改了內部函式名稱，需要更新 `Core.lua`。

## 轉換表

| 項目 | 筆數 |
| --- | --- |
| 單字 | 3,980 |
| 台灣變體 | 39 |
| 詞組 | 49,051 |

資料取自 OpenCC 的 `s2tw`（簡體轉繁體，台灣標準）。詞組優先做最長匹配，所以「公里」「王后」「斗篷」「占卜」「岩漿」這類兩岸通用的詞不會被誤轉。

另有 7 組人工修正，補 OpenCC 字典的缺口：

| 原文 | 轉換後 |
| --- | --- |
| 蜡燭 | 蠟燭 |
| 東西后 | 東西後 |
| 永恒 | 永恆 |
| 几率 | 機率 |
| ·杰特 | ·傑特 |
| 納杰特 | 納傑特 |
| 幸存者 | 倖存者 |

轉換結果會快取，同一段文字只算一次。

## 已知限制

攻略裡 `.target` 和 `.mob` 的自動選取可能找不到怪。那些名字原本是大陸服譯名，字體轉換後是繁體，但台服官方譯名有時用的是不同的詞而非只是不同的字（例如 Burning Blade 大陸服叫「火刃」、台服叫「燃刃」）。這只影響自動選取與標記，不影響照步驟自己點怪；座標箭頭和任務接取用的是數字 ID，完全正常。

## 驗證

以 147,243 行真實攻略文字測試，與參考實作 0 筆不一致。載入耗時約 0.1 秒。

## 內容與授權

本插件**不包含任何 RestedXP 的攻略內容**，只有轉換邏輯與字典資料。

`Data.lua` 的字典資料衍生自 [OpenCC](https://github.com/BYVoid/OpenCC)，採用 Apache License 2.0，授權條文見 [`RXPTradChinese/LICENSE-OpenCC.txt`](RXPTradChinese/LICENSE-OpenCC.txt)。

`Core.lua` 與 `RXPTradChinese.toc` 可自由使用與修改。
