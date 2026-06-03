---
project_slug: hover-menu-preview
date: 2026-06-02
updated: 2026-06-02
updated_by: codex
---

# 2026-06-02 Progress Log: hover-menu-preview

## 概要

- 画面収録を元に作成した hover menu prototype を、開発継続用プロジェクトとして `/Users/shotaro/code/share/hover-menu-preview` へ移行した。

## 完了した作業

- 一時出力先 `outputs/hover-menu-preview` から、ソース、SwiftPM package、Codex Run 設定、起動スクリプト、README を移行。
- `.build/`、`dist/`、旧 `.git/` は移行対象から除外し、移行先で新しい Git repository を `main` branch として初期化。
- `progress/` を作成し、今後の作業入口を `progress/progress.md` に設定。
- 開発用 `.gitignore` を追加。

## 変更ファイル

- `Package.swift`
- `Sources/HoverMenuPreview/main.swift`
- `script/build_and_run.sh`
- `.codex/environments/environment.toml`
- `.gitignore`
- `README.md`
- `progress/progress.md`
- `progress/2026-06/2026-06-02_hover-menu-preview.md`
- `progress/cleanup-candidates.md`

## 検証

- 移行前 prototype は `./script/build_and_run.sh --verify` で build / `.app` staging / launch / process check 成功済み。
- 移行後プロジェクトでも `./script/build_and_run.sh --verify` を実行し、build / `.app` staging / launch / process check 成功。

## 決定事項

- プロジェクト root は `/Users/shotaro/code/share/hover-menu-preview`。
- SwiftPM + AppKit/SwiftUI mixed app として継続する。
- 標準 `MenuBarExtra` ではなく、上部中央の `NSPanel` pill + hover preview panel をベースにする。

## Blocker / Risk

- 署名、notarization、配布用 app bundle は未対応。現時点はローカル開発用 prototype。
- 複数ディスプレイではマウス位置のある画面に表示する実装。固定表示先が必要になったら設定化する。

## 引き継ぎ / 次

- 開発再開時は `/Users/shotaro/code/share/hover-menu-preview` で `./script/build_and_run.sh --verify` を実行してから編集する。
- 次はアプリ名、表示内容、常駐ステータスのデータソース、設定画面の有無を決める。

## 参照ログ

- 一時成果物: `/Users/shotaro/Documents/Codex/2026-06-02/files-mentioned-by-the-user-2026/outputs/hover-menu-preview`

## 削除候補

- なし。一時成果物はユーザー-facing output として当面保持。
