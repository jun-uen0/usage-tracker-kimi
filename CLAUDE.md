# usage-tracker-kimi

Kimi CodeのquotaをmacOSのメニューバーに出すSwiftUIアプリ。機能・セットアップの正本はREADME.md。

## 常時適用

- 汎用ルール(表記・コミット規約等)は~/.ai-rulesのREADMEに従う
- 月次Totalと7日窓はWebセッション由来で、CLIのAPIには存在しない(調査済み)。月次の扱いを変えるときはREADMEの該当節を先に読む
- 公式5時間枠をshellから読むだけなら`~/.ai-rules/tools/kimi_official_usage.py`が既にある。重複実装しない

## ドキュメントマップ(いつ・どれを読むか)

| 状況 | 読むファイル |
|------|-------------|
| 機能・セットアップを知る | README.md |
| APIの仕様を確認する | Sources/KimiUsageTracker/UsageClient.swiftとUsageModels.swift |
