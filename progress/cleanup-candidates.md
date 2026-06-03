---
project_slug: hover-menu-preview
updated: 2026-06-02
updated_by: codex
status: migration_cleanup_pending
---

# Cleanup Candidates: hover-menu-preview

## 運用ルール

- 移行完了までは旧ログを削除しない。
- `progress/` で coverage 済みの重複進捗ログだけを削除対象にする。
- 削除対象は恒久削除せず、ゴミ箱へ移動する。
- 正本 state、根拠 artifact、receipt、journal、DB、build artifact は重複ログではない限り保持対象にする。
- secret、`.env` 値、token、API key、password、認証情報はこのファイルに書かない。

## 削除対象（coverage 検証後）

| path | 種別 | coverage 根拠 | 削除 gate |
|---|---|---|---|
| TODO | TODO | TODO | TODO |

## 保持対象（正本 / 根拠）

| path | 理由 |
|---|---|
| TODO | TODO |

## 要確認

| path | 確認点 |
|---|---|
| TODO | TODO |

## 実施ログ

- 2026-06-02: cleanup candidates を初期化。削除は未実施。
