# Mnemo - Project Instructions

## Project Overview

スクリーンショットを AI で自動タグ付けし、自然文で検索できる iOS アプリ。
ローカルファースト設計で、AI 解析のみ Azure AI Foundry を利用する。

## Key Design Documents

実装前に必ず該当する設計ドキュメントを確認すること。

- `docs/architecture.md` — レイヤー構成、ディレクトリ構成、処理フロー
- `docs/data-model.md` — エンティティ定義、リレーション
- `docs/tech-stack.md` — 技術選定と理由
- `docs/api-flow.md` — API エンドポイント、エラーハンドリング
- `docs/development-roadmap.md` — Phase 0〜4 の開発計画
- `docs/UI/` — UI 仕様、レイアウト、スタイルガイド

## Architecture

### iOS (SwiftUI)

- **アーキテクチャ**: MVVM + Repository パターン
- **ターゲット**: iOS 17+
- **DB**: SwiftData（SQLite ベース）
- **ViewModel**: `@Observable` マクロ使用
- **ネットワーク**: `URLSession` (async/await)、外部ライブラリ不使用
- **パッケージ管理**: Swift Package Manager（外部依存最小限）

### Server (Azure Functions)

- **言語**: Python
- **フレームワーク**: FastAPI（ASGI で Azure Functions にマウント）
- **AI**: Azure AI Foundry 経由（gpt-5-mini, text-embedding-3-small）
- **認証**: Azure → Entra ID / iOS → API キー + デバイス ID
- **サーバー DB なし**: ステートレスプロキシとして動作

## Code Style

### Swift

- SwiftUI のイディオムに従う
- `@Observable` で ViewModel を定義（`ObservableObject` は使わない）
- Repository パターンでデータアクセスを抽象化
- async/await を使用（Combine は避ける）
- 過度な抽象化を避け、シンプルに保つ

### Python

- FastAPI のルーター構成に従う
- Pydantic で型安全なスキーマ定義
- `azure-ai-projects` SDK + `openai` SDK を使用
- `DefaultAzureCredential()` で Azure 認証

## Data Model

主要エンティティ（詳細は `docs/data-model.md`）:

- **Screenshot** — 画像メタデータ。status: pending → processing → success | failed
- **Tag** — 自動 (auto) / 手動 (manual) を区別。confidence は auto のみ
- **OCRText** — OCR テキスト + AI 生成の説明文
- **Embedding** — 512 次元ベクトル ([Float])。SwiftData では Data 型にエンコード
- **Collection** — ユーザー作成のグループ。Screenshot と多対多

## API Endpoints

| Method | Path | 用途 |
|---|---|---|
| POST | /analyze | 画像 → OCR + タグ + 説明文 + 埋め込みベクトル |
| POST | /embed | テキスト → 埋め込みベクトル |
| POST | /search/embed | 検索クエリ → 埋め込みベクトル |
| GET | /health | ヘルスチェック |

## Directory Structure

### iOS App (`src/Mnemo/`)

```
Mnemo/
├── MnemoApp.swift
├── Models/          # SwiftData モデル
├── Repositories/    # データアクセス層
├── ViewModels/      # 画面ロジック (@Observable)
├── Views/           # SwiftUI 画面
│   ├── Search/
│   ├── Detail/
│   ├── Library/
│   ├── Collections/
│   ├── Settings/
│   └── Components/  # 共通コンポーネント
├── Services/        # APIClient, SearchEngine, ImageStorage
└── Resources/
```

### Server (`src/server/`)

> **注**: Phase 0 ではサーバー実装はまだ含まれていません。  
> 以下の構成は Phase 1 以降で実装予定です。

```
server/
├── function_app.py  # Azure Functions エントリーポイント
├── app/
│   ├── main.py      # FastAPI 定義
│   ├── routers/     # エンドポイント
│   ├── services/    # AI 呼び出しロジック
│   ├── schemas/     # リクエスト/レスポンス型
│   └── config.py    # 環境変数
├── requirements.txt
└── host.json
```

## Important Conventions

- 画像はデバイスの Documents ディレクトリにローカル保存。クラウドには送らない（解析時のみ一時的に送信）
- 削除は物理削除（論理削除なし）。SwiftData の `@Relationship` で cascade 設定
- オフライン時は解析リクエストをキューに保持し、復帰後に自動送信
- リトライは指数バックオフ（30 秒 / 2 分 / 5 分、最大 3 回）
- Embedding は 512 次元（text-embedding-3-small の dimensions パラメータで指定）
- 検索は ベクトル類似度 + OCR 全文検索 + タグ一致 の合成スコアでランキング

## Git Workflow

- Issue に着手する際は、必ず `feature/<issue番号>-<簡潔な説明>` ブランチを `main` から作成する
  - 例: `feature/3-image-import`, `feature/5-server-ai-api`
- 作業完了後は PR を作成し、`Closes #<issue番号>` を本文に含める
- `main` ブランチに直接コミットしない

## Inkdrop 連携

- Issue に着手する際、Inkdrop の `03-PlanCode` ノートブックにプランノートを作成する
- ノート末尾の Status チェックリストは、各ステップ完了時に即座にチェックを入れて更新する
- 作業完了時は Outcome セクションを追記し、ノートの status を `completed` に変更する

## Development Phases

現在のフェーズを確認し、そのフェーズの完了条件に集中すること。

1. **Phase 0**: プロジェクトセットアップ — iOS アプリの空のタブ画面起動
2. **Phase 1**: ローカル基盤 — 画像の保存・表示・削除 + サーバー基盤（`/health` エンドポイント）
3. **Phase 2**: クラウド連携 — AI 分析 + 結果保存 + リトライ
4. **Phase 3**: 検索 — セマンティック検索 + タグ検索
5. **Phase 4**: 仕上げ — コレクション + 一括操作 + 設定
