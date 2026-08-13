# Security

## Reporting a vulnerability

公開Issueへ認証情報や個人情報を記載しないでください。GitHubのPrivate vulnerability reportingが利用できる場合は、リポジトリのSecurityタブから報告してください。

## Data handling

このアプリはOpenAI公式ステータスの公開JSONだけを取得します。APIキーは使用せず、認証情報やステータスレスポンス本文を保存しません。通知設定と差分判定用の最小限の状態は、macOSの`UserDefaults`へ保存します。
