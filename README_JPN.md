# OpenAI Status for Mac

[English](README.md) | 日本語

OpenAIの公式ステータスをmacOSで確認する、SwiftUI／WidgetKit製の非公式オープンソースアプリです。

- アプリ画面で全体状態・各サービス・進行中の障害を表示
- デスクトップ／通知センター用の小・中ウィジェット
- macOS 26以降のコントロールセンター用ControlWidget
- 新しい障害、サービス低下、復旧をmacOS通知
- 通知イベントと対象サービスを個別設定
- 同じ異常を繰り返し通知しない差分検知

> [!IMPORTANT]
> このプロジェクトは個人開発の非公式ツールです。OpenAIによる提供、承認、提携を示すものではありません。

## 解説記事

- [SwiftUI + WidgetKitでOpenAIの障害を見逃さないmacOSアプリを作った（Qiita）](https://qiita.com/KohN/items/42685192921c730d5f8b)

## Xcodeを使わずにインストール

Universal形式のビルド済みアプリは、macOS 14以上のAppleシリコンMacとIntel Macに対応します。コントロールセンター用ControlWidgetはmacOS 26以上でのみ表示されます。

### ブラウザからダウンロード

1. [最新のGitHub Release](https://github.com/koh-nakagawa/OpenAIStatusMac/releases/latest)を開きます。
2. `OpenAIStatusMac-unnotarized.zip`をダウンロードします。
3. ZIPを展開し、`OpenAI Status.app`を「アプリケーション」フォルダへ移動します。
4. アプリを一度開きます。
5. macOSに止められた場合は「システム設定 → プライバシーとセキュリティ」を開き、OpenAI Statusの「このまま開く」を押します。
6. アプリを起動し、通知の使用を許可します。

この無料版はApple Development証明書で署名していますが、Appleの公証は受けていません。そのため初回のみGatekeeperの手動許可が必要です。Gatekeeperを無効化したり、quarantine属性を削除したりしないでください。

Releaseにはチェックサム確認用の`OpenAIStatusMac-unnotarized.zip.sha256`も添付しています。

### Git経由でインストール

次のコマンドは同じRelease ZIPを検証して`~/Applications`へインストールします。

```sh
git clone https://github.com/koh-nakagawa/OpenAIStatusMac.git
cd OpenAIStatusMac
./scripts/install.sh
```

このインストーラーはGatekeeperを無効化せず、quarantine属性も削除しません。初回起動が止められた場合は、上記の「このまま開く」を使用してください。

アプリを一度起動した後、下記手順でデスクトップ、通知センター、コントロールセンターへ追加できます。ブラウザからインストールするだけなら、Xcode、Git、Apple IDはいずれも不要です。

## ソースからビルド

開発用ビルドには次が必要です。

- macOS 14.0以上
- Xcode 26.0以上（macOS 26 SDKのControlWidget APIをコンパイルするため）
- Git
- Widget Extension登録用にXcodeへ追加したApple ID

ターミナルで次を実行します。

```sh
git clone https://github.com/koh-nakagawa/OpenAIStatusMac.git
cd OpenAIStatusMac
./scripts/setup.sh
```

`setup.sh`は環境、テスト、公式APIへの接続、署名なしのDebugビルドを確認した後、Xcodeプロジェクトを開きます。

Xcodeが開いたら次の操作を行います。

1. 左側で青いプロジェクトアイコン `OpenAIStatusMac` を選びます。
2. `TARGETS` の `OpenAI Status` を選び、`Signing & Capabilities` を開きます。
3. `Team` に自分のApple IDのTeamを選びます。
4. `TARGETS` の `OpenAIStatusWidget` にも、同じTeamを設定します。
5. 上部のSchemeを `OpenAI Status`、実行先を `My Mac` にします。
6. ▶︎を押して起動します。
7. 初回の通知確認では「許可」を選びます。

Bundle Identifierが利用できないと表示された場合は、2つのTargetを自分用の一意な値へ変更してください。

```text
例:
com.yourname.OpenAIStatusMonitor
com.yourname.OpenAIStatusMonitor.Widget
```

親アプリとWidget Extensionは、必ず同じSigning Teamで署名してください。

## ウィジェットの追加

アプリを一度起動した後、次の手順で追加します。

1. デスクトップを右クリックします。
2. 「ウィジェットを編集」を選びます。
3. `OpenAI Status` を検索します。
4. 小または中サイズをデスクトップへ追加します。

macOS 26以降では、コントロールセンターの編集画面から `OpenAI Status` コントロールも追加できます。通常のデスクトップウィジェットとControlWidgetは別の実装です。

## 通知

アプリ右上のベル、またはアプリメニューの「設定」から変更できます。

| 通知項目 | デフォルト |
| --- | --- |
| 新しい障害 | ON |
| サービスの性能低下・停止 | ON |
| 障害・サービスの復旧 | ON |
| 障害情報の更新 | OFF |
| ステータス取得失敗 | OFF |
| 通知対象サービス | すべて |

アプリは起動中に約1分間隔で確認します。ウインドウを閉じてもアプリプロセスが動いていれば監視を続けますが、アプリを終了すると停止します。

ウィジェットは約15分後の更新をリクエストします。実際の更新時刻はmacOSが電力状況などを考慮して決定します。

## 検証だけ実行する

```sh
./scripts/verify.sh
```

このスクリプトは次を確認します。

- plist／entitlements／Xcode projectの構文
- SwiftPMの4テスト
- OpenAI公式ステータスAPIのライブデコード
- 署名を無効にしたホストアプリ＋Widget ExtensionのDebugビルド

実際のウィジェット登録には署名が必要なため、検証後はXcodeで両Targetに同じTeamを設定してください。

## 取得先

- `https://status.openai.com/api/v2/summary.json`
- `https://status.openai.com/api/v2/incidents.json`

APIキーやOpenAIアカウントへのログインは不要です。ステータス取得にはHTTPSを利用し、認証情報やレスポンス本文は保存しません。

## 構成

```text
OpenAIStatusMac.xcodeproj       macOSアプリ＋Widget Extension
OpenAIStatus/App               SwiftUI画面、監視、通知設定
OpenAIStatus/Shared            APIモデル、取得処理、差分通知ロジック
OpenAIStatus/Widget            WidgetKit／ControlWidget
Tests                          XCTest
Verification                   公式APIのライブ検証
scripts/setup.sh               初回セットアップ
scripts/verify.sh              再現可能な検証
scripts/install.sh             最新Release用のXcode不要インストーラー
scripts/build-release-zip.sh   メンテナー用Release作成スクリプト
```

## よくある問題

### `Embedded binary is not signed with the same certificate as the parent app.`

`OpenAI Status`と`OpenAIStatusWidget`のSigning Teamを同じものにしてください。

### ビルドは成功するがウィジェット一覧に出ない

次を確認してください。

- アプリを一度起動したか
- Widget Extensionも同じTeamで署名されているか
- `OpenAIStatusWidget.entitlements`のApp SandboxとOutgoing Connectionsが有効か
- 古いビルドではなく、現在のXcodeビルドを起動しているか

Debugビルドで表示される `not stripping binary because it is signed` は、署名済みバイナリをstripしなかったという警告で、今回の既知の非致命的警告です。

### 通知が来ない

1. アプリのベルボタンから通知設定を開きます。
2. macOSの通知許可が「許可済み」か確認します。
3. 「テスト通知を送る」を実行します。
4. macOSの「システム設定 → 通知」も確認します。

## 配布とセキュリティ

このプロジェクトの公式バイナリ配布先はGitHub Releasesだけです。現在のビルド済みアプリはApple Development署名・未公証のため、初回のみGatekeeperの手動許可が必要です。Developer ID署名・公証済み配布と同等ではありません。

メンテナーは`OPENAI_STATUS_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./scripts/build-release-zip.sh 1.1.0`で配布物を再現できます。スクリプトはKeychain内の有効なApple Development証明書を選択し、ホストアプリと内包Widget Extensionの署名、両者のTeam ID一致を確認してから、`ditto`でZIP化してSHA-256チェックサムを出力します。証明書が複数ある場合は`OPENAI_STATUS_CODE_SIGN_IDENTITY`で指定できます。

## ライセンス

[MIT License](LICENSE)

OpenAI、ChatGPTおよび関連名称は、それぞれの権利者に帰属します。
