# 開発ロードマップ（MVP）

## フェーズ概要

```
Phase 0          Phase 1          Phase 2          Phase 3          Phase 4
プロジェクト      ローカル基盤      クラウド連携      検索機能         仕上げ
セットアップ      画像取り込み      AI 分析          セマンティック    コレクション
                 ローカル保存                       検索             一括操作
                                                                   設定
```

---

## Phase 0: プロジェクトセットアップ

### iOS
- [ ] Xcode プロジェクト作成（SwiftUI, iOS 17+）
- [ ] ディレクトリ構成の作成（Models / Views / ViewModels / Repositories / Services）
- [ ] SwiftData のモデル定義（Screenshot, Tag, Collection, CollectionItem, OCRText, Embedding, AnalysisJob）
- [ ] タブナビゲーション（検索 / ライブラリ / コレクション / 設定）のスケルトン

### サーバー
- [ ] Azure Functions プロジェクト作成（Python v2）
- [ ] FastAPI マウント構成
- [ ] Azure AI Foundry リソース作成（gpt-5-mini, text-embedding-3-small のデプロイ）
- [ ] ローカル開発環境の構築（local.settings.json, Azure Functions Core Tools）

### 完了条件
- iOS アプリが空のタブ画面で起動する。
- Azure Functions がローカルで `/health` に応答する。

---

## Phase 1: ローカル基盤（画像取り込み + 保存）

### iOS
- [ ] PhotosPicker による画像選択 UI
- [ ] ImageStorage: 画像を Documents ディレクトリに保存
- [ ] ScreenshotRepository: SwiftData への保存・取得・削除
- [ ] ライブラリ画面: 保存済み画像のグリッド表示
- [ ] 詳細画面: 画像プレビュー（ズーム対応）
- [ ] 削除機能（確認ダイアログ + 物理削除）

### 完了条件
- 画像を選択 → ローカル保存 → ライブラリに表示 → 詳細表示 → 削除が一通り動作する。

---

## Phase 2: クラウド連携（AI 分析）

### サーバー
- [ ] `/analyze` エンドポイント実装（画像 → gpt-5-mini → OCR + タグ + 説明文）
- [ ] `/embed` エンドポイント実装（テキスト → text-embedding-3-small → ベクトル）
- [ ] `/search/embed` エンドポイント実装（クエリ → ベクトル変換）
- [ ] Azure Functions へデプロイ
- [ ] エラーハンドリング（AI Foundry のエラー → 適切な HTTP レスポンス）

### iOS
- [ ] APIClient: Azure Functions との通信（async/await）
- [ ] AnalysisRepository: 解析リクエスト送信 + 結果保存
- [ ] AnalysisQueue: オフライン時のキューイング + リトライ（指数バックオフ）
- [ ] Screenshot.status の状態遷移管理（pending → processing → success / failed）
- [ ] 詳細画面に OCR テキスト・自動タグ表示
- [ ] 解析キュー画面（pending / processing / success / failed の一覧 + 手動リトライ）

### 完了条件
- 画像を取り込むと自動で AI 分析が実行され、OCR テキストと自動タグが付与される。
- 解析失敗時に手動リトライができる。
- オフライン時はキューに溜まり、復帰後に自動送信される。

---

## Phase 3: 検索機能

### iOS
- [ ] SearchEngine: コサイン類似度によるベクトル検索
- [ ] SearchEngine: OCR テキスト全文検索
- [ ] SearchEngine: タグ一致検索（完全一致 + 前方一致）
- [ ] SearchRepository: 合成スコアによるランキング
- [ ] 検索画面 UI（検索バー + サジェスト）
- [ ] 検索結果画面（2 カラムグリッド + フィルター + ソート）
- [ ] 検索結果から詳細画面への遷移

### 完了条件
- 自然文で検索すると、関連する画像が類似度順に表示される。
- タグ検索・フィルタリングが動作する。
- 1000 件のデータで検索が 1 秒以内に完了する。

---

## Phase 4: 仕上げ（コレクション + 一括操作 + 設定）

### iOS
- [ ] CollectionRepository: コレクションの CRUD
- [ ] コレクション画面: 一覧 + 作成 + 名前変更 + 削除
- [ ] コレクション詳細画面: コレクション内の画像一覧
- [ ] 詳細画面からコレクションに追加
- [ ] 手動タグの追加・削除（TagEditView）
- [ ] 一括選択モード（ライブラリ / 検索結果）
- [ ] 一括操作: タグ追加・コレクション追加・削除
- [ ] 設定画面: クラウド解析 ON/OFF、Wi-Fi のみ設定
- [ ] 初回起動フロー: クラウド解析の同意モーダル + 写真アクセス許可

### 完了条件
- acceptance-criteria.md の全項目をクリア。
- コレクション管理、タグ編集、一括操作が動作する。
- 設定でクラウド解析の ON/OFF が切り替えられる。

---

## 推奨開発順序の理由

1. **Phase 0 → 1（ローカル基盤）を最初に**: AI 連携なしでも画像の保存・表示・削除が動くようにする。ここで SwiftData / SwiftUI の基本パターンを確立。
2. **Phase 2（クラウド連携）を次に**: サーバーと iOS の通信パイプラインを構築。ここが技術的に最もリスクが高い部分。
3. **Phase 3（検索）がコア機能**: ベクトル検索のオンデバイス実装。ここがアプリの差別化ポイント。
4. **Phase 4（仕上げ）は最後**: コレクション・一括操作・設定は Phase 1-3 の基盤の上に載せるだけ。
