# データモデル（MVP）

## 1. エンティティ一覧
- Screenshot（画像）
- Tag（タグ）
- Collection（コレクション）
- OCRText（OCR + 説明文）
- Embedding（埋め込み）

## 2. リレーション概要
- Screenshot 1:N Tag（自動/手動）
- Screenshot N:M Collection（多対多）
- Screenshot 1:1 OCRText
- Screenshot 1:1 Embedding

## 3. フィールド定義

### 3.1 Screenshot
- id (UUID)
- local_path (string) — 画像ファイルの相対パス（Documents ディレクトリ基準）
- created_at (datetime)
- updated_at (datetime)
- status (enum: pending | processing | success | failed)
- title (string, optional)
- error_message (string, optional) — 解析失敗時のエラー内容
- retry_count (int, default: 0) — リトライ回数

### 3.2 Tag
- id (UUID)
- screenshot_id (UUID)
- label (string)
- source (enum: auto | manual)
- confidence (float, optional) — auto の場合のみ。0.0〜1.0
- created_at (datetime)

### 3.3 Collection
- id (UUID)
- name (string)
- created_at (datetime)
- updated_at (datetime)

### 3.4 CollectionItem（中間テーブル）
- collection_id (UUID)
- screenshot_id (UUID)
- created_at (datetime)

### 3.5 OCRText
- screenshot_id (UUID)
- text (string) — OCR で抽出されたテキスト
- description (string) — AI が生成した画像の説明文（例: 「青い表紙の本が机の上に置かれている」）
- language (string, optional)
- created_at (datetime)

### 3.6 Embedding
- screenshot_id (UUID)
- vector ([Float], 512 次元) — text-embedding-3-small で生成。dimensions=512 を指定
- created_at (datetime)

※ AnalysisJob テーブルは廃止。同期方式の採用により、解析状態は Screenshot.status で管理する。
  リトライ回数は Screenshot.retry_count で記録する。

## 4. 検索用インデックス
- OCRText.text — 全文検索インデックス
- OCRText.description — 全文検索インデックス
- Embedding.vector — コサイン類似度によるベクトル検索（オンデバイス計算）

## 5. Embedding 仕様
- モデル: text-embedding-3-small
- 次元数: 512（dimensions パラメータで指定）
- 入力テキスト: OCR テキスト + description + タグラベルを結合した文字列
- 保存形式: [Float] 配列（SwiftData では Data 型にエンコードして保存）
- ストレージ目安: 1000 件 × 512 次元 × 4 bytes = 約 2MB

## 6. 削除（完全削除）方針
- is_deleted は使わず、完全削除時に物理削除
- 削除対象: 画像ファイル + DB レコード（Screenshot + 関連する Tag, OCRText, Embedding, CollectionItem）
- SwiftData の @Relationship で cascade 削除を設定

## 7. 未確定
- タグの正規化（同義語）
- OCR の言語対応範囲（MVP: 日本語/英語）
