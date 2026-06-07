---
project_slug: hover-menu-preview
date: 2026-06-07
updated_by: codex
status: active
---

# 2026-06-07 hover-menu-preview

## 実施内容

- Google Calendar provider に日付クリックで詳細日を固定する動きを追加。
- 日別詳細ペインに予定追加、編集、削除の UI を追加。
- 編集フォームで title、開始/終了、終日、location、notes を変更できるようにした。
- `GoogleCalendarEventOccurrence` に Google 側 event ID、書き込み可能状態、notes を保持するようにした。
- Calendar API client に event 作成、部分更新、削除を追加。
- OAuth scope を `calendar.events.readonly` から `calendar.events` へ変更し、古い read-only credential は `needsReconnect` として扱うようにした。
- Settings / Calendar 接続画面に再接続表示を追加。
- preview panel が TextField / DatePicker の入力を受けられるよう、preview 用 `NSPanel` の key focus を許可した。

## 検証

- `swift build`: 成功。
- `./script/check_google_calendar_setup.sh`: 成功。
- `git diff --check`: 成功。
- `./script/build_and_run.sh --verify`: 成功、`HoverMenuPreview launched` を確認。

## 未完了 / 注意

- 実 Google アカウントでの write scope 追加同意は、OAuth callback 待ちで停止したため未完了。アプリ側は `needsReconnect` を表示し、再接続後に書き込み API を使う。
- 実カレンダーへの一時イベント作成・削除テストは、追加同意完了後に実行する。

