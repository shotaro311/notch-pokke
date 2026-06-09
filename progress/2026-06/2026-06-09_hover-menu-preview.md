---
project_slug: hover-menu-preview
date: 2026-06-09
updated_by: codex
status: active
---

# 2026-06-09 hover-menu-preview

## 実施内容

- 上部ヘッダー右端の電源アイコンを削除。
- provider アイコン群と設定ボタンの間に、薄い縦線の仕切りを追加。
- `ProviderSwitchingMode` を追加し、provider アイコンの切り替え方式を `Click` / `Hover` から選べるようにした。
- Settings の `Panels` セクションに `Icon switching` segmented picker を追加。
- `Click` では従来通りアイコンクリックで provider を切り替える。
- `Hover` では provider アイコンにポインタを重ねた時点で自動的に provider を切り替える。
- 切り替え方式は `UserDefaults` に保存し、次回起動後も維持する。

## 検証

- `swift build`: 成功。
- `git diff --check`: 成功。
- `./script/build_and_run.sh --verify`: 成功、`NotchPokke launched` を確認。
- `rg -n "power|terminate\\(|providerSwitchingMode|Icon switching|HeaderIconDivider" Sources/HoverMenuPreview`: 上部ヘッダーの `power` / `terminate` 残存なし、追加設定と仕切りの参照のみ確認。

## 未完了 / 注意

- 実画面でのホバー切り替えの体感速度は、ユーザー側の操作感確認が必要。
