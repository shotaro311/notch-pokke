---
project_slug: hover-menu-preview
date: 2026-06-04
updated: 2026-06-04
updated_by: codex
---

# 2026-06-04 Progress Log: hover-menu-preview

## 概要

- 一つ目の実機能として、MacBook camera を使う `Mirror` provider を追加した。
- ノッチ handle へ hover すると preview panel が素早く開き、panel active 中だけカメラを起動する。

## 完了した作業

- `MirrorProvider` を built-in provider として登録。
- `MirrorPreviewView` と `CameraPreviewView` を追加し、AVFoundation camera session を SwiftUI / AppKit view に表示。
- プレビュー映像を左右反転し、鏡として自然に使える表示にした。
- panel の open / close animation を `0.22s` に短縮し、content reveal delay を `0.03s` に短縮。
- mirror 用に preview panel size を `520 x 372pt` に拡大。
- `NSCameraUsageDescription` を generated app bundle の `Info.plist` に追加。
- provider actions に `isPreviewActive` を追加し、panel active 中だけ camera session を start / stop するようにした。
- README に current feature と camera permission 挙動を追記。
- ユーザー検証で hover 時に落ちたため、直近 unified log と DiagnosticReports を確認。原因は `AVCaptureSession.startRunning()` 中に `AVCaptureVideoPreviewLayer` が session へ追加される race による `NSGenericException`。
- `CameraPreviewView` を条件付き生成から常駐 layer に変更し、preview layer attach 完了後に camera session を起動するように修正。
- close 時に即 stop せず、4秒の warm grace を入れて hover の細かい出入りで camera start / stop を連発しないように変更。
- `sessionPreset` を `.high` / `.medium` 相当から `.vga640x480` へ下げ、mirror panel 用に軽量化。
- mirror camera の permission / start / stop を `OSLog` で追えるようにした。
- close 時にカメラ映像が一瞬点滅・残像化する問題に対応。window close animation 中は `contentVisible` を維持し、`orderOut` 後に内部 content / camera active state を落とす順序へ変更。
- close 中に delayed content hide する `hidePreviewContent` と `contentHideLeadTime` を削除。
- `contentVisible` と provider active state を分離。panel open intent が出た時点で Mirror provider を active にし、window が `orderOut` された後に inactive へ戻すようにした。この段階では見た目の animation / blur / scale / shadow は維持した。
- `MirrorCameraModel.shared` を追加し、camera access が既に許可済みの場合だけ app launch 時に `AVCaptureSession` の構成を prewarm。`startRunning()` は hover active 時だけに限定し、カメラを常時稼働させない。
- `ProviderStore` が `RefreshPolicy` を尊重するように変更。`MirrorProvider` は `.eventDriven` のため、panel open 時の不要な loading / ready publish を skip する。
- README に、許可済みの場合は camera session を事前構成するが、カメラ稼働は mirror active 中だけであることを追記。
- Mirror 表示のカクつき / ちらつき対策として、`AVCaptureVideoPreviewLayer` の layout 時に `CATransaction.setDisableActions(true)` を使い、bounds 変更に伴う暗黙 animation を止めた。
- window open / close animation 中だけ preview window shadow を off にし、completion / reset 後に shadow を戻して `invalidateShadow()` するようにした。
- 閉じかけから再 hover した時に collapsed frame へ戻してから開き直す動きをやめ、現在の frame / alpha から final frame へ戻すようにした。
- live camera preview に SwiftUI blur をかけないようにし、content reveal は opacity / scale / offset のみにした。
- Mirror が UI 枠より遅れて追従して見える問題に対応。preview window animation 開始前に `contentVisible=true` を非アニメーションで反映し、ミラー映像が枠の clip と同時に広がるようにした。
- close 時に camera preview の残像が panel 内に残る問題を抑えるため、close animation 開始時点で `providerActive=false` にし、panel 本体より先に camera preview を fade out するようにした。content / shell は close animation 中も維持する。
- camera preview の opacity animation を `0.12s` から `0.06s` に短縮し、close 中に映像が長く残らないようにした。
- 繰り返し open / close 後にもっさりする体感への処理系対策として、close fallback 用 `resetTask` を単一管理し、open / close / reset completion 時に古い task を cancel するようにした。
- `contentVisible` / `providerActive` / camera `status` は同じ値なら publish しないようにし、SwiftUI の余計な再描画を抑制。
- `MirrorCameraModel.setActive(_:)` は同じ active state の再通知では stop task を再予約しないようにした。
- `ProviderStore.select(_:)` は同一 provider ID の選択を no-op にした。
- close delay の `DispatchWorkItem` は実行後に `closeTask=nil` として参照を残さないようにした。
- `GoogleCalendarProvider` を built-in provider として追加し、既存ヘッダーの provider 切替で `Mirror / Calendar` を切り替えられるようにした。
- Google 公式の installed app OAuth flow に沿って、loopback redirect + PKCE の OAuth 実装を追加した。外部 GoogleSignIn SDK は使わず、SwiftPM `.app` 生成時の framework 埋め込み問題を避けた。loopback listener は `127.0.0.1` に bind する BSD socket 方式にした。
- OAuth 設定は `GOOGLE_CLIENT_ID` / 任意の `GOOGLE_CLIENT_SECRET` を環境変数または `.env.local` から generated `Info.plist` へ注入する方式にした。機密値はコードや progress に書かない。
- OAuth token は Keychain 保存にし、access token は必要時に refresh token から更新するようにした。
- Google Calendar API client を追加し、`calendarList.list` と `events.list` で表示対象 calendar と月グリッド範囲の予定を取得するようにした。
- 月表示は左カラム、hover / selected day の予定詳細は右カラムに表示する `GoogleCalendarPreviewView` を追加した。
- 日付 hover 時はネットワーク通信をせず、取得済み snapshot のイベントをローカルで絞り込むようにした。
- Settings window に Google Calendar の connect / disconnect 導線を追加した。
- `.env.example` を追加し、`.env` / OAuth credential / token cache 系ファイルを `.gitignore` に追加した。
- README に Google Calendar provider の OAuth 設定手順を追記した。

## 変更ファイル

- `Sources/HoverMenuPreview/Providers/MirrorProvider.swift`
- `Sources/HoverMenuPreview/Views/MirrorPreviewView.swift`
- `Sources/HoverMenuPreview/Views/CameraPreviewView.swift`
- `Sources/HoverMenuPreview/Providers/GoogleCalendarProvider.swift`
- `Sources/HoverMenuPreview/Views/GoogleCalendarPreviewView.swift`
- `Sources/HoverMenuPreview/Models/GoogleCalendarModels.swift`
- `Sources/HoverMenuPreview/State/GoogleCalendarStore.swift`
- `Sources/HoverMenuPreview/Services/GoogleOAuthService.swift`
- `Sources/HoverMenuPreview/Services/GoogleOAuthKeychainStore.swift`
- `Sources/HoverMenuPreview/Services/GoogleCalendarAPIClient.swift`
- `Sources/HoverMenuPreview/Services/LoopbackOAuthReceiver.swift`
- `Sources/HoverMenuPreview/Models/ProviderModels.swift`
- `Sources/HoverMenuPreview/Providers/NotchProvider.swift`
- `Sources/HoverMenuPreview/Providers/ProviderRegistry.swift`
- `Sources/HoverMenuPreview/State/HoverMenuStore.swift`
- `Sources/HoverMenuPreview/Views/PluginHostView.swift`
- `Sources/HoverMenuPreview/Views/HoverPanelShell.swift`
- `Sources/HoverMenuPreview/Windowing/PanelAnimationTiming.swift`
- `Sources/HoverMenuPreview/Windowing/PanelGeometry.swift`
- `Sources/HoverMenuPreview/Windowing/SettingsWindowController.swift`
- `script/build_and_run.sh`
- `.env.example`
- `.gitignore`
- `README.md`
- `progress/progress.md`
- `progress/2026-06/2026-06-04_hover-menu-preview.md`

## 検証

- `swift build` 成功。
- `./script/build_and_run.sh --verify` 成功。
- `plutil -p dist/HoverMenuPreview.app/Contents/Info.plist` で `NSCameraUsageDescription` を確認。
- `CGWindowListCopyWindowInfo` で hover 後の preview panel が `520 x 372pt`、pill が `239 x 33pt` で onscreen になることを確認。
- カメラ映像そのもののスクリーンショット確認は、ユーザーの顔が写るため実施しない。初回利用時は macOS の camera permission prompt が出る可能性がある。
- crash 再現ログ: `HoverMenuPreview-2026-06-04-162807.ips` と `/usr/bin/log show --predicate 'process == "HoverMenuPreview"' --last 60m` で `Collection <__NSArrayM> was mutated while being enumerated` を確認。
- 修正後、hover in/out を 6〜8 cycle 自動実行しても process は生存し、直近ログに `NSGenericException` / `mutated while being enumerated` / `Terminating app` は出ていない。
- 修正後、panel active 中の process は確認時 `CPU 1.0% / RSS 53936KB`、close して warm grace 後は `CPU 0.0% / RSS 51440KB`。
- close animation 修正後、hover open で preview window `onscreen=1`、mouse out 後 `onscreen=false`、process 生存を確認。直近ログに crash 例外なし。
- `git diff --check` 成功。
- prewarm / refresh skip 修正後、`swift build` 成功。
- prewarm / refresh skip 修正後、`./script/build_and_run.sh --verify` 成功。
- 自動 hover in/out で、open 後 preview window `520 x 372pt` が onscreen、mouse out 後 pill window のみ onscreen へ戻ることを確認。
- 直近ログに `NSGenericException` / `mutated while being enumerated` / `Terminating app` は出ていない。
- この検証環境では camera permission が未決定扱いで、hover 時に `camera permission requested` まで確認。ユーザーの顔が写る可能性があるため、permission prompt の自動クリックと camera 映像スクリーンショットは実施していない。
- close 後の process は確認時 `CPU 0.0% / RSS 51568KB`。
- ちらつき対策後、`swift build` 成功。
- ちらつき対策後、`./script/build_and_run.sh --verify` 成功。
- ちらつき対策後、`git diff --check` 成功。
- ちらつき対策後、bundle 起動 3 秒後の idle process は `CPU 0.0% / RSS 49184KB`。
- ちらつき対策後、直近ログに `NSGenericException` / `mutated while being enumerated` / `Terminating app` は出ていない。
- content 同期修正後、`swift build` 成功。
- content 同期修正後、`./script/build_and_run.sh --verify` 成功。
- content 同期修正後、window metadata で open 途中 `505 x 360pt / alpha 0.996`、open 完了 `520 x 372pt / alpha 1`、close 後 pill のみ onscreen を確認。
- content 同期修正後、bundle 起動後 idle process は `CPU 0.0% / RSS 52128KB`。
- content 同期修正後、直近ログに `NSGenericException` / `mutated while being enumerated` / `Terminating app` は出ていない。
- camera close timing 修正後、`swift build` 成功。
- camera close timing 修正後、`./script/build_and_run.sh --verify` 成功。
- camera close timing 修正後、open で preview window `520 x 372pt / alpha 1`、close 後 pill のみ onscreen を確認。
- camera close timing 修正後、bundle 起動後 idle process は `CPU 0.0% / RSS 51712KB`。
- camera close timing 修正後、直近ログに `NSGenericException` / `mutated while being enumerated` / `Terminating app` は出ていない。
- 繰り返し開閉の処理系改善後、`swift build` 成功。
- 繰り返し開閉の処理系改善後、`git diff --check` 成功。
- 繰り返し開閉の処理系改善後、`./script/build_and_run.sh --verify` 成功。
- 自動 hover open / close を 25 cycle 実行。実行前 `windows=1 / CPU 0.0% / RSS 49184KB`、cycle 直後 `windows=1 / CPU 1.6% / RSS 52080KB`、warm grace 後 `windows=1 / CPU 0.0% / RSS 51936KB`。
- 繰り返し開閉の処理系改善後、直近ログに `NSGenericException` / `mutated while being enumerated` / `Terminating app` は出ていない。
- Google Calendar 実装後、`swift build` 成功。
- Google Calendar 実装後、`./script/build_and_run.sh --verify` 成功。
- OAuth loopback listener の検証として、BSD socket で `127.0.0.1` のランダム port を bind / listen / getsockname できることを確認。
- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` に dummy 値を入れた状態で `./script/build_and_run.sh --verify` を実行し、generated `Info.plist` に `GoogleOAuthClientID` / `GoogleOAuthClientSecret` / `NSAllowsLocalNetworking` が入ることを確認。
- dummy 検証後、OAuth 値なしで再起動し、generated `Info.plist` に OAuth 値が残っていないことを確認。
- 起動後 process は確認時 `CPU 0.0% / RSS 50608KB`。
- Google Calendar 実装後、直近ログに `NSGenericException` / `mutated while being enumerated` / `Terminating app` / `Fatal error` は出ていない。
- Google Calendar 実装後、`git diff --check` 成功。
- OAuth loopback listener 修正後、`swift build`、`./script/build_and_run.sh --verify`、起動後 `CPU 0.0% / RSS 52976KB`、直近 crash 例外なし、`git diff --check` 成功。
- ローカル確認時点で `.env.local` / `.env` / `GOOGLE_CLIENT_ID` 環境変数は未設定だったため、実Googleアカウントでの OAuth consent / calendarList / events.list 取得は未検証。
- goal continuation で再監査し、OAuth callback が `waitForCallback()` より先に届いた場合でも結果を保持する `pendingResult` を追加。
- `.env.local` が存在するが対象keyが空/未定義の場合に `.env` へフォールバックするよう `script/build_and_run.sh` の env 読み込みを修正。
- `.env.local` 空 + `.env` に dummy OAuth値を置いた状態で `./script/build_and_run.sh --verify` を実行し、generated `Info.plist` に dummy `GoogleOAuthClientID` / `GoogleOAuthClientSecret` が入ることを確認。その後 OAuth値なしで再起動し、generated `Info.plist` に OAuth値が残らないことを確認。
- continuation 修正後、`swift build`、`git diff --check`、`./script/build_and_run.sh --verify` 成功。起動後 `CPU 0.0% / RSS 50752KB`、直近 crash 例外なし。
- `script/check_google_calendar_setup.sh` を追加。OAuth値を表示せず、`GOOGLE_CLIENT_ID`、`.env.local` ignore、gcloud active account、gcloud project、Calendar API enabled を確認できるようにした。
- setup check 実行結果: `gcloud_active_account=set`、`gcloud_project=set`、`calendar_api=enabled`、`env_local_gitignore=ok`、`google_client_id=missing`。
- setup check 追加後、`swift build`、`git diff --check`、`./script/build_and_run.sh --verify` 成功。起動後 `CPU 0.0% / RSS 52992KB`、直近 crash 例外なし。
- `gcloud iam oauth-clients` を確認したが、許可scopeが `cloud-platform/openid/email/groups` 系に限定されており、Google Calendar のユーザーOAuth clientとしては使えないことを確認。
- 既存gcloud access tokenで Calendar API `calendarList` をHTTPステータスのみ確認したが、`403 PERMISSION_DENIED`。現在のgcloud tokenではアプリOAuthの代替検証不可。
- `script/open_google_oauth_console.sh` を追加。active gcloud project の Google Auth Platform clients 画面を開き、Desktop app OAuth client 作成へ進める補助にした。
- `script/check_google_calendar_setup.sh` に、`GOOGLE_CLIENT_ID` missing 時の next action を表示するよう追記。
- 再検証結果: setup check は `gcloud_active_account=set`、`gcloud_project=set`、`calendar_api=enabled`、`env_local_gitignore=ok`、`google_client_id=missing`。`swift build`、`git diff --check`、`./script/build_and_run.sh --verify` 成功。起動後 `CPU 0.0% / RSS 53168KB`、直近 crash 例外なし。
- `shotaro.matsu0311@gmail.com` のChrome `Default` profileを使い、Google Auth Platform の Desktop OAuth client `HoverMenuPreview 2` を作成。client ID / secret は `.env.local` に保存し、値はログに記録していない。
- `GoogleOAuthService` に Chrome profile / user data dir / remote debugging port 指定のURL openerを追加。通常利用では `GOOGLE_OAUTH_CHROME_PROFILE=Default` で指定Chrome profileを開ける。検証時だけ一時Chrome user data dir + DevTools portを環境変数で注入した。
- `GoogleCalendarVerificationCommand` と `script/verify_google_calendar.sh` を追加。同じOAuth / Calendar API client / 日付別抽出ロジックを使って、UIクリックに依存せず login / token refresh / calendar fetch を確認できるようにした。
- 実OAuth consent検証: account chooser、未確認app警告、再ログイン確認、Calendar scope選択、callback `Google Calendar connected` まで到達。
- 実Calendar API検証: `./script/verify_google_calendar.sh --force-google-sign-in` は `google_calendar_verify=ok`、`used_login_flow=true`、`calendar_sources=5`、`events_in_visible_grid=53`、`days_with_events=37`、`today_events=3`、`range_start=2026-05-31`、`range_end=2026-07-12`。
- 保存済み認証検証: `./script/verify_google_calendar.sh` は `used_login_flow=false` で同じ件数を再取得。Keychain refresh token と Calendar API client が再利用できることを確認。
- 通常起動検証: `./script/build_and_run.sh --verify` 成功。起動後 process は `CPU 0.0% / MEM 0.2%`。`git diff --check` 成功。直近5分の crash / fatal / exception 検索では crash 例外なし。

## 決定事項

- `Mirror` は snapshot data ではなく、provider view 側で AVFoundation session を持つ。
- カメラは panel active で起動し、閉じた後は4秒だけ warm state を保ってから停止する。短時間の再 hover での重い再起動を避けるため。
- close 中は映像 content を先に消さない。window が完全に隠れてから `contentVisible=false` にする。
- live camera preview と blur の組み合わせはちらつき / 合成負荷の原因になりやすいため、Mirror panel では blur を使わず、opacity / scale / offset で reveal する。
- mirror content は window animation 完了後ではなく開始前に表示状態へ切り替える。遅延 reveal は使わない。
- close では content shell を維持しつつ、camera preview だけ先に hide する。`contentVisible` は window `orderOut` 後に落とす。
- `contentVisible` は見た目の reveal / hide 専用、`providerActive` は provider lifecycle 専用として分離する。
- 高速な繰り返し開閉では、見た目の timing を変えずに、古い fallback task の cancel と同値 publish 抑制を優先する。
- `.eventDriven` provider は panel open 時に snapshot refresh しない。手動 refresh は引き続き許可する。
- `MenuBarExtra` ではなく既存の `NSPanel` notch shell を継続する。
- Google Calendar provider も `.eventDriven` とし、panel open / date hover のタイミングでは通信を同期実行しない。Calendar view が active 時に必要な月だけ refresh する。
- OAuth は外部 SDK ではなく、Google installed app OAuth の loopback redirect + PKCE を採用する。
- OAuth client ID / secret は generated `Info.plist` へ注入するが、実値は repo に入れない。

## Blocker / Risk

- 初回 camera permission はユーザー操作が必要。
- 署名、notarization、自動起動は未対応。
- Camera permission の denied / restricted / unavailable は UI 表示を実装済みだが、全状態の実機再現は未実施。
- 自動検証では顔が写る映像確認は避けている。ユーザー側で許可後の見え方を確認する必要あり。
- `.env.local` に Google OAuth client ID / secret が入っているため、値を表示しない。repo には含めない。
- Google OAuth consent screen が Testing の場合、登録済み test user のみログイン可能。一般公開には Google OAuth app verification が必要になる可能性がある。

## 引き継ぎ / 次

- 次の実装候補: Calendar provider の初回表示UX、日付hover詳細の見た目、タブ切り替え/ provider切り替え導線を実画面で詰める。
- 再開時は `./script/build_and_run.sh --verify` で起動し、ノッチ handle に hover、Calendar provider へ切り替えて予定表示と日付hover詳細を確認する。

## 参照ログ

- `progress/progress.md`
- `progress/2026-06/2026-06-03_hover-menu-preview.md`

## 削除候補

- なし。
