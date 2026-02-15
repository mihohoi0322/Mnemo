# アーキテクチャ設計

## 1. 全体構成

```
┌─────────────────────────────────────────────┐
│                  iOS App                     │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │   View   │  │ ViewModel│  │ Repository │  │
│  │ (SwiftUI)│→ │  (MVVM)  │→ │           │  │
│  └──────────┘  └──────────┘  └─────┬─────┘  │
│                                    │         │
│                    ┌───────────────┼────┐    │
│                    ↓               ↓    ↓    │
│              ┌──────────┐  ┌─────────┐  │    │
│              │ SwiftData│  │ Search  │  │    │
│              │   (DB)   │  │ Engine  │  │    │
│              └──────────┘  └─────────┘  │    │
│                                         ↓    │
│                                  ┌──────────┐│
│                                  │ API      ││
│                                  │ Client   ││
│                                  └────┬─────┘│
└───────────────────────────────────────┼──────┘
                                        │ HTTPS
                                        ↓
                              ┌──────────────────┐
                              │  Azure Functions  │
                              │  (Python/FastAPI)  │
                              └────────┬─────────┘
                                       │
                                       ↓
                              ┌──────────────────┐
                              │  Azure AI Foundry │
                              │  ・gpt-5-mini     │
                              │  ・text-embedding  │
                              │   -3-small        │
                              └──────────────────┘
```

## 2. iOS アプリ レイヤー構成

### 2.1 View 層
- SwiftUI で画面を構成。
- ViewModel をバインドして状態を反映。
- ユーザー操作を ViewModel に委譲。

### 2.2 ViewModel 層
- 各画面ごとに ViewModel を用意（例: SearchViewModel, DetailViewModel）。
- Repository を通じてデータの取得・更新を行う。
- @Observable マクロを使用（iOS 17+）。

### 2.3 Repository 層
- データソースへのアクセスを抽象化。
- ViewModel はデータの取得元（ローカル DB / API）を意識しない。
- 主な Repository:
  - **ScreenshotRepository** — 画像の保存・取得・削除
  - **TagRepository** — タグの CRUD
  - **CollectionRepository** — コレクションの管理
  - **SearchRepository** — 検索処理（ベクトル + テキスト + タグ）
  - **AnalysisRepository** — クラウド解析のリクエスト・結果取得

### 2.4 データ層
- **SwiftData** — メタデータ永続化（Screenshot, Tag, Collection, OCRText, Embedding, AnalysisJob）。
- **ファイルシステム** — 画像ファイルの保存。アプリの Documents ディレクトリ内に格納。
- **SearchEngine** — ベクトル検索（コサイン類似度）+ 全文テキスト検索のローカル実行。

### 2.5 ネットワーク層
- **APIClient** — Azure Functions との通信。URLSession (async/await) を使用。
- リクエストのキューイング（オフライン時）。
- リトライロジック（指数バックオフ: 30 秒 / 2 分 / 5 分、最大 3 回）。

## 3. iOS ディレクトリ構成

```
Mnemo/
├── MnemoApp.swift                 # エントリーポイント
├── Models/                        # SwiftData モデル
│   ├── Screenshot.swift
│   ├── Tag.swift
│   ├── Collection.swift
│   ├── CollectionItem.swift
│   ├── OCRText.swift
│   ├── Embedding.swift
│   └── AnalysisJob.swift
├── Repositories/                  # データアクセス
│   ├── ScreenshotRepository.swift
│   ├── TagRepository.swift
│   ├── CollectionRepository.swift
│   ├── SearchRepository.swift
│   └── AnalysisRepository.swift
├── ViewModels/                    # 画面ロジック
│   ├── SearchViewModel.swift
│   ├── SearchResultsViewModel.swift
│   ├── DetailViewModel.swift
│   ├── LibraryViewModel.swift
│   ├── CollectionsViewModel.swift
│   └── SettingsViewModel.swift
├── Views/                         # SwiftUI 画面
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchResultsView.swift
│   ├── Detail/
│   │   ├── DetailView.swift
│   │   └── TagEditView.swift
│   ├── Library/
│   │   └── LibraryView.swift
│   ├── Collections/
│   │   ├── CollectionsView.swift
│   │   └── CollectionDetailView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/                # 共通コンポーネント
│       ├── ScreenshotThumbnail.swift
│       ├── TagChip.swift
│       ├── SearchBar.swift
│       └── BulkActionToolbar.swift
├── Services/                      # 外部通信・ユーティリティ
│   ├── APIClient.swift
│   ├── SearchEngine.swift
│   ├── ImageStorage.swift
│   └── AnalysisQueue.swift
└── Resources/
    └── Assets.xcassets
```

## 4. サーバーサイド構成（Azure Functions）

### 4.1 役割
- iOS アプリからの画像を受け取り、Azure AI Foundry に中継するステートレスプロキシ。
- サーバー側に DB は持たない。解析結果はそのまま iOS に返す。

### 4.2 エンドポイント

| Method | Path | 説明 |
|---|---|---|
| POST | /analyze | 画像を受け取り、gpt-5-mini で分析。OCR + タグ + 説明文を生成 |
| POST | /embed | テキスト（OCR + タグ）を受け取り、text-embedding-3-small で埋め込みベクトルを生成 |
| POST | /search/embed | 検索クエリテキストを埋め込みベクトルに変換 |
| GET | /health | ヘルスチェック |

### 4.3 処理フロー（同期方式）

MVP では Azure Functions の応答を同期的に待つ方式を採用する。
gpt-5-mini の画像分析は通常数秒で完了するため、ポーリングの複雑さを避ける。

```
iOS                    Azure Functions              Azure AI Foundry
 │                          │                              │
 │  POST /analyze           │                              │
 │  (image + image_id)      │                              │
 │ ────────────────────────→│                              │
 │                          │  chat.completions.create     │
 │                          │  (gpt-5-mini + image)        │
 │                          │ ────────────────────────────→│
 │                          │                              │
 │                          │  ←─ OCR + tags + description │
 │                          │                              │
 │                          │  embeddings.create           │
 │                          │  (text-embedding-3-small)    │
 │                          │ ────────────────────────────→│
 │                          │                              │
 │                          │  ←─ embedding vector         │
 │                          │                              │
 │  ←── JSON Response ─────│                              │
 │  (ocr, tags, embedding)  │                              │
 │                          │                              │
```

### 4.4 ディレクトリ構成

```
server/
├── function_app.py            # Azure Functions エントリーポイント + FastAPI マウント
├── app/
│   ├── main.py                # FastAPI アプリ定義
│   ├── routers/
│   │   ├── analyze.py         # /analyze エンドポイント
│   │   ├── embed.py           # /embed, /search/embed エンドポイント
│   │   └── health.py          # /health エンドポイント
│   ├── services/
│   │   ├── vision.py          # gpt-5-mini 呼び出しロジック
│   │   └── embedding.py       # text-embedding-3-small 呼び出しロジック
│   ├── schemas/
│   │   ├── analyze.py         # リクエスト/レスポンスの型定義
│   │   └── embed.py
│   └── config.py              # 環境変数・設定
├── requirements.txt
├── host.json
└── local.settings.json
```

## 5. データフロー

### 5.1 画像取り込み〜解析

1. ユーザーが PhotosPicker で画像を選択。
2. ImageStorage が Documents ディレクトリにコピー保存。
3. SwiftData に Screenshot レコード作成（status: pending）。
4. AnalysisQueue が API リクエストをキューに追加。
5. APIClient が Azure Functions `/analyze` に画像を送信。
6. Azure Functions が gpt-5-mini で分析 → text-embedding-3-small で埋め込み生成。
7. JSON レスポンスを iOS に返却。
8. Repository が SwiftData を更新（OCRText, Tag, Embedding 保存、status: success）。

### 5.2 検索

1. ユーザーがクエリを入力。
2. APIClient が `/search/embed` にクエリを送信 → 埋め込みベクトルを取得。
3. SearchEngine がローカルの Embedding テーブルとコサイン類似度を計算。
4. OCRText の全文検索を並行実行。
5. Tag の一致検索を並行実行。
6. 合成スコアで並び替え、結果を表示。

### 5.3 オフライン時

1. APIClient がネットワーク不通を検知。
2. AnalysisQueue にリクエストを保持（Screenshot.status は pending のまま）。
3. ネットワーク復帰時に自動送信。
4. 失敗時は指数バックオフで最大 3 回リトライ。

## 6. セキュリティ

- iOS → Azure Functions 間は TLS 必須。
- Azure Functions → Azure AI Foundry 間は Entra ID 認証。
- Azure Functions は画像を永続化しない（処理後は破棄）。
- iOS 側の画像はデバイスのファイル暗号化に依存。
