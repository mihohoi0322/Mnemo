# UIプロトタイプ遷移定義（MVP）

## 1. メインフロー
- 検索（ホーム）
  - 初回表示 → クラウド解析同意モーダル
  - 初回の取り込み操作 → 端末権限リクエスト
  - 検索バー入力 → 検索結果
  - 最近見た/最近取り込んだのサムネ → 詳細
  - 解析待ち/失敗バナー → 解析キュー
  - 設定アイコン → 設定
  - タブ: ライブラリ / コレクション / 設定

- 検索結果
  - サムネ → 詳細
  - フィルタチップ → 同画面で絞り込み
  - 並び替え → 同画面で並び替え
  - 複数選択バー → アクションシート（タグ付与/コレクション追加/削除）

- 詳細
  - タグ編集 → タグ編集モーダル
  - コレクション追加 → コレクション選択モーダル
  - 削除 → 確認ダイアログ → 削除完了で前画面へ

- ライブラリ
  - サムネ → 詳細
  - 複数選択 → 下部バー表示 → アクション

- コレクション
  - コレクションカード → コレクション詳細
  - コレクション詳細のサムネ → 詳細

- 解析キュー
  - 失敗カード → 再試行（ステータス更新）

- 設定
  - トグル操作 → 状態反映のみ

## 2. モーダル / ダイアログ
- クラウド解析同意
  - Allow → 設定ON、ホームに戻る
  - Not Now → 設定OFF、ホームに戻る
- タグ編集
  - Save → 詳細に反映
  - Cancel → 閉じる
- コレクション選択
  - 選択 → 詳細に反映
  - 新規作成 → コレクション作成モーダル
- 削除確認ダイアログ
  - Delete → 完全削除
  - Cancel → 閉じる

## 3. 画面遷移ラベル（Figmaプロトタイプ用）
- SearchHome -> SearchResults
- SearchHome -> Detail
- SearchHome -> AnalysisQueue
- SearchHome -> Settings
- SearchHome -> CloudConsentModal
- SearchResults -> Detail
- Detail -> TagEditModal
- Detail -> CollectionPicker
- Detail -> DeleteConfirm
- Library -> Detail
- Collections -> CollectionDetail
- CollectionDetail -> Detail
- AnalysisQueue -> (Retry)
- Settings -> (Toggle only)
