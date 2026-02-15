# Mnemo

スマホで撮ったスクリーンショットを AI で自動タグ付けし、自然文で検索できる iOS アプリ。

## 概要

Mnemo は、スクリーンショットを保存するだけで AI が内容を理解しタグを付与し、後から「青い表紙の本」「料理のレシピが写ってるやつ」のように自然文で探せるメモ整理アプリです。

- 画像はローカル保存（プライバシー重視）
- AI 解析のみクラウド（Azure AI Foundry）を利用
- セマンティック検索でスクリーンショットを瞬時に発見

## 技術スタック

### iOS アプリ

| 項目 | 技術 |
|---|---|
| UI | SwiftUI (iOS 17+) |
| アーキテクチャ | MVVM + Repository |
| ローカル DB | SwiftData |
| ベクトル検索 | オンデバイス コサイン類似度 |
| ネットワーク | URLSession (async/await) |
| 画像取り込み | PhotosUI (PhotosPicker) |

### サーバーサイド

| 項目 | 技術 |
|---|---|
| AI プラットフォーム | Azure AI Foundry |
| 言語 | Python |
| フレームワーク | FastAPI |
| ホスティング | Azure Functions (Consumption Plan) |
| 画像分析 | gpt-5-mini |
| Embedding | text-embedding-3-small (512 次元) |

## アーキテクチャ

```
┌──────────────┐     HTTPS      ┌──────────────────┐     ┌──────────────────┐
│   iOS App    │ ──────────────→│  Azure Functions  │────→│  Azure AI Foundry│
│  (SwiftUI)   │                │  (Python/FastAPI)  │     │                  │
│              │←───────────────│                   │←────│ ・gpt-5-mini     │
│ ・SwiftData  │   JSON Response│ ・/analyze         │     │   (Vision+OCR)   │
│ ・ローカル検索│               │ ・/embed           │     │ ・text-embedding  │
│ ・ベクトル検索│               │ ・/search/embed    │     │   -3-small       │
└──────────────┘               └──────────────────┘     └──────────────────┘
```

## ディレクトリ構成

```
Mnemo/
├── README.md
├── CLAUDE.md              # Claude Code 用プロジェクト指示
├── AGENTS.md
├── docs/                  # 設計ドキュメント
│   ├── INDEX.md           # ドキュメント目次
│   ├── requirements.md    # 要件定義
│   ├── tech-stack.md      # 技術スタック
│   ├── architecture.md    # アーキテクチャ設計
│   ├── data-model.md      # データモデル
│   ├── api-flow.md        # API フロー
│   ├── development-roadmap.md  # 開発ロードマップ
│   ├── mvp-scope.md       # MVP スコープ
│   └── UI/                # UI 設計ドキュメント
├── src/                   # ソースコード（実装予定）
│   ├── Mnemo/             # iOS アプリ
│   └── server/            # Azure Functions（Phase 1+ で実装予定）
└── .github/
    ├── prompts/
    └── skills/
```

## 開発ロードマップ

| Phase | 内容 | 状態 |
|---|---|---|
| 0 | プロジェクトセットアップ | 進行中 |
| 1 | ローカル基盤（画像取り込み + 保存） | 未着手 |
| 2 | クラウド連携（AI 分析） | 未着手 |
| 3 | 検索機能（セマンティック検索） | 未着手 |
| 4 | 仕上げ（コレクション + 一括操作 + 設定） | 未着手 |

詳細は [docs/development-roadmap.md](docs/development-roadmap.md) を参照。

## セットアップ

### 前提条件

- Xcode 15+ (iOS 17 SDK)
- Python 3.11+
- Azure Functions Core Tools v4
- Azure サブスクリプション（AI Foundry リソース）

### iOS アプリ

```bash
# Xcode でプロジェクトを開く（Phase 0 完了後）
open src/Mnemo/Mnemo.xcodeproj
```

### サーバー（Azure Functions）

> **注**: Phase 0 ではサーバー実装（`src/server`、`requirements.txt` など）はまだ含まれていません。  
> この節は Phase 1 以降で実装予定のバックエンドのプレースホルダです。

```bash
# サーバー実装は Phase 1 以降で追加予定です。
# 現時点（Phase 0）では以下のディレクトリ／ファイルは存在しません:
#   - src/server/
#   - src/server/requirements.txt
#   - src/server/local.settings.json.example
#
# 実装が追加されたタイミングで、具体的なセットアップ手順をここに記載します。

cd src/server

# Python 仮想環境
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# ローカル設定
cp local.settings.json.example local.settings.json
# local.settings.json に Azure AI Foundry の接続情報を設定

# ローカル起動
func start
```

### 環境変数（サーバー）

| 変数名 | 説明 |
|---|---|
| `AZURE_AI_PROJECT_CONNECTION_STRING` | Azure AI Foundry プロジェクト接続文字列 |
| `AZURE_OPENAI_DEPLOYMENT_VISION` | gpt-5-mini のデプロイ名 |
| `AZURE_OPENAI_DEPLOYMENT_EMBEDDING` | text-embedding-3-small のデプロイ名 |
| `API_KEY` | iOS アプリからの認証用 API キー |

## ドキュメント

設計ドキュメントは [docs/INDEX.md](docs/INDEX.md) に一覧があります。

| ドキュメント | 概要 |
|---|---|
| [要件定義](docs/requirements.md) | ユーザーストーリー、機能要件 |
| [技術スタック](docs/tech-stack.md) | 技術選定と理由 |
| [アーキテクチャ](docs/architecture.md) | レイヤー構成、処理フロー |
| [データモデル](docs/data-model.md) | エンティティ、リレーション |
| [API フロー](docs/api-flow.md) | エンドポイント、処理フロー |
| [MVP スコープ](docs/mvp-scope.md) | やること / やらないこと |
| [開発ロードマップ](docs/development-roadmap.md) | Phase 0〜4 の計画 |
| [UI 設計](docs/UI/) | ワイヤーフレーム、スタイルガイド |

## ライセンス

Private
