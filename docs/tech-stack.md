# 技術スタック

## 1. iOS アプリ

| 項目 | 選定 | 備考 |
|---|---|---|
| UI フレームワーク | SwiftUI | iOS 17+ 対象 |
| アーキテクチャ | MVVM + Repository | SwiftUI との相性重視。過度な抽象化を避ける |
| ローカル DB | SwiftData | Apple 純正。SwiftUI との統合が容易。SQLite 上に構築 |
| ベクトル検索 | オンデバイス コサイン類似度計算 | 1000 件規模では専用ライブラリ不要。将来的に拡張可 |
| ネットワーク | URLSession (async/await) | 標準 API で十分。外部依存なし |
| 画像取り込み | PhotosUI (PhotosPicker) | SwiftUI と直接統合可能 |
| パッケージ管理 | Swift Package Manager | Apple 標準。外部依存を最小限にする方針 |

## 2. サーバーサイド（Cloud API）

| 項目 | 選定 | 備考 |
|---|---|---|
| AI プラットフォーム | Azure AI Foundry | モデルカタログ・モニタリング・評価を統合した PaaS |
| 言語 | Python | AI 系ライブラリとの相性が良い |
| フレームワーク | FastAPI | 軽量・型安全・自動 API ドキュメント生成 |
| ホスティング | Azure Functions (Consumption Plan) | 従量課金でリクエストがない間はコストゼロ。ASGI 対応で FastAPI をそのまま載せられる |
| 画像分析モデル | gpt-5-mini | Vision 対応。OCR + タグ生成 + 画像理解を 1 回の API コールで実行。入力 $0.25/1M トークン、出力 $2.00/1M トークン |
| Embedding モデル | text-embedding-3-small | 低コスト（$0.000022/1K トークン）。次元数カスタマイズ対応。2027 年 4 月まで引退予定なし |
| Python SDK | azure-ai-projects + openai | Foundry SDK 経由で OpenAI 互換クライアントを取得 |
| 認証（Azure） | Microsoft Entra ID | DefaultAzureCredential() で安全に認証 |
| 認証（iOS → API） | API キー + デバイス ID | MVP ではシンプルに。将来的に Entra ID 等に拡張可 |
| サーバー側 DB | なし（MVP では不要） | サーバーはステートレスな分析プロキシ。データは iOS 側に保存 |

## 3. アーキテクチャ概要図

```
┌──────────────┐     HTTPS      ┌──────────────────┐     ┌──────────────────┐
│   iOS App    │ ──────────────→│  Azure Functions  │────→│  Azure AI Foundry│
│  (SwiftUI)   │                │  (Python/FastAPI)  │     │                  │
│              │←───────────────│                   │←────│ ・gpt-5-mini     │
│ ・SwiftData  │   JSON Response│ ・/analyze         │     │   (Vision+OCR)   │
│ ・ローカル検索│               │ ・/analyze/{id}    │     │ ・text-embedding  │
│ ・ベクトル検索│               │                   │     │   -3-small       │
└──────────────┘               └──────────────────┘     └──────────────────┘
```

## 4. 選定理由

### gpt-5-mini を選んだ理由
- GPT-4o は 2026 年 3 月〜10 月に段階的引退。新規プロジェクトでは非推奨。
- スクリーンショット分析（OCR + タグ付け）は複雑な推論を要求しないため、軽量モデルで十分。
- 入力コストが gpt-4.1-mini ($0.40) より安い ($0.25)。
- GPT-5 世代の推論能力が利用可能。
- 精度に不満があれば gpt-5 や gpt-5.1 への切り替えが容易。

### Azure Functions を選んだ理由
- 個人プロジェクトでリクエスト頻度が低いため、従量課金が最適。
- Consumption Plan は月あたり 100 万リクエスト + 40 万 GB-s が無料枠。
- コールドスタート（数秒）があるが、AI 分析は非同期処理のためユーザー体験への影響は小さい。
- 実行時間制限（最大 10 分）は画像分析（通常数秒）には十分。
- 将来の Web 展開時にも同じ Functions に API を追加可能。規模拡大時は Container Apps への移行も容易。

### Azure AI Foundry を選んだ理由
- Azure OpenAI Service のスーパーセットで、モデルカタログ・モニタリング・評価が統合。
- 既存の Azure OpenAI リソースからのアップグレードも可能。
- 11,000 以上のモデルカタログから将来的にモデルを切り替えやすい。

## 5. 将来の Web 展開時

| 項目 | 選定候補 | 備考 |
|---|---|---|
| フロントエンド | Next.js (TypeScript) | SSR/SSG 対応。React ベースで情報量が多い |
| バックエンド | FastAPI をそのまま流用 | iOS / Web 両方の API を統一 |

## 6. 未決定項目（tech-requirements.md からの引き継ぎ）
- ベクトルインデックスの具体的な実装方式（端末内ライブラリ選定 or 自前計算）。
- OCR 言語対応範囲（MVP: 日本語 / 英語）。
- Embedding の次元数（text-embedding-3-small のデフォルト 1536 or カスタム削減）。
