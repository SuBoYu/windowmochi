# WindowMochi

![WindowMochi mascot](assets/branding/windowmochi-mascot-v1.png)

Mac 選單列視窗配置工具。支援 macOS 13 以上；目前建置產物適用 Apple Silicon。

## 使用

1. 開啟 `dist/WindowMochi.app`，右上角選單列會出現視窗圖示。
2. 點「授予輔助使用權限」，在系統設定中允許 WindowMochi。
3. 手動把視窗排在各個螢幕上，點「儲存目前配置」，輸入名稱。
4. 把視窗移開後，點「還原」驗證位置與大小。
5. 可分別儲存工作、開會等不同配置；同名配置需確認後才覆蓋。

設定保存在 `~/Library/Application Support/WindowHabit/layouts.json`。內容包含 App 識別碼及視窗標題，僅存本機；可從選單開啟資料夾，刪除檔案後重啟即可清空配置。

## 行為與限制

- 只處理已開啟、未最小化、非全螢幕的一般視窗；不自動啟動 App。
- 以螢幕 UUID 辨識螢幕，依相對座標與尺寸恢復；外接螢幕缺席時回到內建螢幕。
- 同一 App 優先匹配視窗標題與順序；標題變更時退回順序匹配。相同標題或順序變更時，可能無法精確辨認原視窗。
- 不會切換 Spaces 或重建瀏覽器分頁；部分 App 限制最小視窗尺寸或不允許輔助使用操作。
- 尚未提供自動偵測接上螢幕或登入自動啟動。
- 本機採 ad-hoc 簽章，沒有 Apple 公證；重新建置後可能需要重新授權輔助使用。

## 建置

需要 Apple Command Line Tools（Swift 6）。在專案目錄執行：

```sh
./scripts/build.sh
```

產物位於 `dist/WindowMochi.app`。

## 手動驗證

- 同時開啟兩個不同 App，移到不同螢幕，儲存配置。
- 改變位置與尺寸，再還原，確認兩者都回復。
- 同一 App 開啟兩個不同標題的視窗，驗證匹配。
- 拔掉外接螢幕後還原，確認視窗留在內建螢幕可見範圍。
- 關閉其中一個視窗後還原，確認報告未找到的數量。
- 取消或拒絕權限，確認顯示授權說明且不修改視窗。

## 多國語言（i18n）

提供英文、繁體中文、簡體中文與日文；預設跟隨系統偏好語言，未支援的語言回退到英文。從選單的「語言」可立即切換，選擇會保留到下次啟動。配置名稱由使用者命名，不會被翻譯。

所有 App 文案集中在 `Sources/WindowMochi/Resources/*.json`，以穩定 key 存取，支援帶參數的訊息。新增語言時請新增同樣 key 的 JSON，並在 `Localization.swift`、語言選單與建置腳本的 `CFBundleLocalizations` 加入語系。

驗證翻譯覆蓋與參數：

```sh
python3 tests/check_localizations.py
```

## 全域快捷鍵

| 快捷鍵 | 動作 |
| --- | --- |
| Control + Option + Command + 1–9 | 還原第 1–9 組配置 |
| Control + Option + Command + → | 下一組，最後一組後回到第一組 |
| Control + Option + Command + ← | 上一組，第一組前回到最後一組 |

App 運行時即可使用，無須將其切到前景。選單顯示配置順序與目前選取的配置；同名覆蓋不改變順序。成功時快捷鍵操作不顯示對話框，缺少視窗或 App 拒絕操作時會顯示結果。首次使用方向鍵，→ 從第一組開始，← 從最後一組開始。前九組之後的配置仍可透過方向鍵或選單還原。

快捷鍵目前固定，尚未提供自訂介面。如果註冊失敗，啟動時會提示可能的衝突，選單還原仍可使用。透過 Carbon 註冊指定快捷鍵，不擷取一般打字內容。

## GitHub

Repository：[SuBoYu/windowmochi](https://github.com/SuBoYu/windowmochi)。建庫欄位與首次上傳指令見 [GitHub 建庫說明](docs/GITHUB_SETUP.md)。

## 本次驗證狀態

已通過 release 編譯、App 簽章及多語系 key / 格式參數檢查。全域快捷鍵、語言選單持久化及雙螢幕實際移動仍需在桌面環境授權後手動驗證。

新增手動驗證項目：

- 分別切換四種語言，確認選單、儲存、覆蓋、授權與還原訊息，再重啟驗證語言保留。
- 儲存兩組不同配置，切換到其他 App 後按 ⌃⌥⌘1、⌃⌥⌘2 及左右方向鍵。
- 循環切換至頭尾邊界，確認順序；覆蓋第一組後確認快捷鍵對應不變。
- 對無對應配置的數字按鍵確認無動作；無任何配置時按方向鍵確認無動作。
- 使用其他程式佔用其中一組快捷鍵，再啟動本工具，確認衝突提示與選單還原功能。

## 品牌與升級

WindowMochi 的麻糬吉祥物已用於 App 圖示、選單列及「關於」視窗。建置腳本會從 `assets/branding/windowmochi-mascot-v1.png` 產生完整 macOS iconset 與 ICNS，不需要額外安裝圖像套件。

本機專案資料夾仍叫 `WindowHabit`；Swift target 與 App 已改名為 `WindowMochi`。為沿用既有語言偏好與配置，bundle ID 保持 `local.windowhabit.app`，資料位置保持 `~/Library/Application Support/WindowHabit/layouts.json`。新版重新簽章後仍可能需要重新授予輔助使用權限。升級時先從舊版選單點「結束」，再開啟 `dist/WindowMochi.app`，避免兩個版本同時註冊快捷鍵。
