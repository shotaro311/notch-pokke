---
project_slug: hover-menu-preview
date: 2026-06-08
updated_by: codex
status: active
---

# 2026-06-08 hover-menu-preview

## 実施内容

- パネルを開いたまま上部の provider アイコンを切り替えたとき、機能表示は切り替わるのにヘッダーのアイコン選択状態が更新されない問題を修正。
- 原因は `HoverPanelShell` が `HoverMenuStore` だけを監視し、ヘッダー内で参照している `ProviderStore.selectedPluginID` の変更を直接監視していなかったこと。
- `ProviderHeaderView` を追加し、ヘッダー部分が `ProviderStore` を `@ObservedObject` として直接監視するように変更。
- これにより、選択中タイトル、アイコンの選択ハイライト、provider 順序表示が `ProviderStore` の変更に合わせて更新される。
- GitHub Actions `Codex PR Router` を追加。PR作成/更新/レビュー時に変更ファイルを分類し、`origin:mac`、`codex-autofix`、`needs-human-merge`、`codex-automerge-safe` を自動付与する。
- docs/progress/Markdown だけの低リスクPRは `codex-automerge-safe` にし、trusted author の場合だけ auto-merge を有効化する。
- `github-codex-autofix` plugin を Mac 側に作成し、personal marketplace に登録。
- Mac 側 Codex Automation `GitHub Codex Autofix` を毎日 10:00 / 12:00 / 15:00 / 18:00 / 21:00 に設定。
- Windows peer 復旧後、同じ plugin を Windows 側へ展開し、Windows 側 Codex Automation `GitHub Codex Autofix Windows` を同じ時間帯で設定。
- Windows 側は現時点で対象 repo を空にし、PRがない間は `list-targets` の軽量チェックだけで終了する構成にした。
- 実PR `#1` を作って `Codex PR Router` のラベル付与を確認。検証後はマージせず閉じ、テストブランチを削除した。
- 実PR検証中に、helper 側の `classify` が `.github/*.md` を docs-only と誤判定する不整合を発見。GitHub Actions と同じく `.github/` 配下は自動マージ候補にしないよう修正し、Mac / Windows 両方へ反映した。

## 検証

- `swift build`: 成功。
- `git diff --check`: 成功。
- `./script/build_and_run.sh --verify`: 成功、`NotchPokke launched` を確認。
- `github-codex-autofix` helper の `list-targets --worker mac/windows`: 対象PRなしで即終了することを確認。
- GitHub labels: `codex-autofix`、`codex-automerge-safe`、`needs-human-merge`、`origin:mac`、`origin:windows`、`codex-claimed:mac`、`codex-claimed:windows` を作成/更新済み。
- Plugin validation: `validate_plugin.py /Users/shotaro/plugins/github-codex-autofix` 成功。
- Windows peer: plugin zip の SHA 一致、`C:\Users\shotaro\plugins\github-codex-autofix\scripts\codex_autofix.py` の存在、`list-targets --worker windows` が `targets: []` で正常終了することを確認。
- 転送用の一時 secret gist は Windows 側の取得後に削除済み。
- PR `#1`: GitHub Actions `Codex PR Router / route` 成功。`origin:mac`、`codex-autofix`、`needs-human-merge` が付くことを確認。
- Mac helper: PR `#1` を `list-targets --worker mac` で検出できること、`claim` / `release` で `codex-claimed:mac` を付け外しできることを確認。
- Windows helper: 修正版 plugin version `0.1.0+codex.20260608013156` で、PR `#1` の `classify` が `docs_only: false`、`worker: mac` になること、Windows worker の `list-targets` が `targets: []` になることを peer 経由で確認。
- 後片付け: PR `#1` は `CLOSED`、`mergedAt: null`。remote / local のテストブランチ削除済み。open PR は 0 件、Mac `list-targets` も `targets: []`。

## 未完了 / 注意

- 実画面での連続クリック確認はユーザー側の体感確認が必要。
- GitHub Actions と Mac / Windows helper の入口動作は実PRで確認済み。
- Codex review 本文を読んで実際に修正commitを積む動作は、次に本物のレビューコメント付きPRが出たタイミングで確認する。
