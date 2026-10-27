# GitHub 建庫與首次上傳

## 建立空白 repository

開啟 [建立 WindowMochi repository](https://github.com/new?name=windowmochi&description=A+macOS+menu+bar+app+to+snapshot+and+restore+multi-monitor+window+layouts%2C+with+global+shortcuts+and+multilingual+support.&visibility=private)，已預填名稱、簡介與 Private，確認後建立：

| 欄位 | 建議值 |
| --- | --- |
| Owner | 你的個人 GitHub 帳號 |
| Repository name | `windowmochi` |
| Description | `A macOS menu bar app to snapshot and restore multi-monitor window layouts, with global shortcuts and multilingual support.` |
| Visibility | 個人開發可先選 Private；準備公開分享時選 Public |
| README | 不勾選，本機已有 |
| .gitignore | 不新增，本機已有 |
| License | 先不新增，待選定授權後加入 |

按 Create repository 後，複製 HTTPS URL。

## 首次上傳

在 Terminal 進入本機的 `WindowHabit` 專案根目錄（App 名稱已更新為 WindowMochi）。以下適用尚未初始化 Git 的專案；把 YOUR_USERNAME 換成你的帳號。

```sh
git init -b main
git add .gitignore Package.swift README.md Sources scripts tests docs assets
git diff --cached --stat
git commit -m "Initial WindowMochi app with localization and global shortcuts"
git remote add origin https://github.com/YOUR_USERNAME/windowmochi.git
git push -u origin main
```

推送前需先設定 GitHub 驗證；可用已登入的 GitHub CLI（`gh auth login`、`gh auth setup-git`），或你已設定的 SSH / HTTPS 認證。

## 上傳內容

- `Sources/WindowMochi/`：Swift 程式與四語系 JSON 資源。
- `scripts/build.sh`、`scripts/build-icon.sh`：編譯、吉祥物圖示封裝與本機簽章。
- `assets/branding/`：吉祥物 PNG 與生成提示詞。
- `tests/`：翻譯覆蓋率與格式參數驗證。
- `README.md`、`docs/`、`Package.swift`、`.gitignore`。
- `.build/`、`dist/`、`.DS_Store` 已排除。
- 使用者視窗標題與配置保存在 Application Support，不在專案內。

公開原始碼前可自行選定授權。分享可安裝 App 可另用 GitHub Releases；目前產物為 Apple Silicon、本機 ad-hoc 簽章，尚未公證。

參考：
- https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
- https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github

建議建立後加入 Topics：`macos`、`swift`、`window-manager`、`multi-monitor`、`productivity`、`mochi`。專案 repository：https://github.com/SuBoYu/windowmochi 。上述首次初始化步驟供新專案參考；已有 checkout 時直接使用正常的 commit / push 流程。
