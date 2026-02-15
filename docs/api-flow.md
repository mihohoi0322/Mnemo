# API / 処理フロー定義（MVP）

## 1. 全体フロー
1. 画像取り込み
   - 初回は端末権限を要求
2. ローカル保存 + メタデータ作成（解析待ち）
3. クラウド解析リクエスト送信
4. 解析結果受領
5. ローカルDB更新 + インデックス更新
6. 検索・閲覧で利用

## 2. クラウド解析API（案）

### 2.1 画像解析リクエスト
- Method: POST
- Path: /analyze
- Body:
  - image (binary or base64)
  - image_id (UUID)
  - language_hint (optional)
- Response:
  - status: accepted
  - job_id

### 2.2 解析結果取得
- Method: GET
- Path: /analyze/{job_id}
- Response:
  - status: pending | processing | success | failed
  - ocr_text
  - tags: [{label, confidence}]
  - embedding: vector
  - error_message (optional)

### 2.3 コールバック方式（任意）
- Method: POST
- Path: /callback/analyze
- Body:
  - image_id
  - status
  - ocr_text
  - tags
  - embedding
  - error_message

## 3. ローカル処理
- 解析リクエスト送信後はAnalysisJobをpendingに
- 成功時:
  - OCRTextを保存
  - Tag（auto）を追加
  - Embeddingを保存
  - Screenshot.status = success
- 失敗時:
  - Screenshot.status = failed
  - error_messageを保存

## 4. 検索処理
- クエリを埋め込み化
- Embeddingベクトル検索で候補抽出
- OCR全文検索で補助
- スコア合成で並び替え

## 5. 失敗・再試行
- ネットワーク失敗はキュー保持
- 解析失敗はUIから再試行
- 自動再試行は最大3回（指数バックオフ: 30秒 / 2分 / 5分）
- 手動再試行は上限なし（ただし直近失敗後は10秒待機）
- 解析結果が到着したが画像が削除済みの場合は破棄

## 6. セキュリティ
- TLS必須
- 解析サービスは画像を永続化しない
