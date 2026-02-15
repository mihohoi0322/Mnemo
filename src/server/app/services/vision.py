"""Vision API サービス — gpt-5-mini による画像解析（OCR + タグ + 説明文）"""

from __future__ import annotations

import json
import logging
from typing import Dict, List, Optional

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

from app.config import settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """\
あなたはスクリーンショット解析アシスタントです。
ユーザーが送信した画像（スクリーンショット）を分析し、以下の情報を JSON 形式で返してください。

## 出力フォーマット（厳密に従うこと）
```json
{
  "ocr_text": "画像内に表示されているテキストをすべて抽出（改行は \\n で表現）",
  "description": "この画像が何を表しているかの簡潔な説明（日本語、1〜3文）",
  "tags": [
    {"label": "タグ名", "confidence": 0.95},
    {"label": "タグ名", "confidence": 0.8}
  ]
}
```

## タグ付けのルール
- タグは 3〜10 個程度
- 画像の内容を的確に表す短いラベル（日本語または英語）
- confidence は 0.0〜1.0 の範囲
- 以下のカテゴリを考慮:
  - アプリ名やサービス名（例: "Twitter", "LINE", "Safari"）
  - コンテンツの種類（例: "チャット", "設定画面", "エラー", "コード"）
  - 主要なトピック（例: "天気", "ニュース", "プログラミング"）
  - UI 要素（例: "ダークモード", "通知", "ポップアップ"）

## 注意事項
- テキストが読み取れない場合は ocr_text を空文字列にする
- 必ず有効な JSON のみを返すこと（説明文やマークダウンは不要）
"""


def _get_openai_client():
    """Azure AI Foundry 経由で OpenAI 互換クライアントを取得する"""
    credential = DefaultAzureCredential()
    project_client = AIProjectClient(
        endpoint=settings.azure_ai_project_endpoint,
        credential=credential,
    )
    return project_client.get_openai_client()


async def analyze_image(
    image_base64: str, language_hint: Optional[str] = None
) -> Dict:
    """
    画像を gpt-5-mini で解析し、OCR テキスト・説明文・タグを返す。

    Args:
        image_base64: Base64 エンコードされた画像データ
        language_hint: 言語ヒント（例: "ja", "en"）

    Returns:
        dict: {"ocr_text": str, "description": str, "tags": [{"label": str, "confidence": float}]}

    Raises:
        ValueError: AI の応答が不正な JSON の場合
        Exception: Azure AI Foundry のエラー
    """
    openai_client = _get_openai_client()

    user_content: List[Dict] = []

    # 言語ヒントがある場合はテキストメッセージを追加
    if language_hint:
        user_content.append(
            {"type": "text", "text": f"言語ヒント: {language_hint}"}
        )

    # 画像データを追加
    user_content.append(
        {
            "type": "image_url",
            "image_url": {
                "url": f"data:image/jpeg;base64,{image_base64}",
                "detail": "high",
            },
        }
    )

    # OpenAI 互換クライアントで Chat Completion を呼び出す
    response = openai_client.chat.completions.create(
        model=settings.azure_openai_deployment_vision,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ],
        temperature=0.1,
        max_tokens=2000,
        response_format={"type": "json_object"},
    )

    # レスポンスのパース
    raw_content = response.choices[0].message.content
    if not raw_content:
        raise ValueError("AI からの応答が空です")

    logger.info("Vision API raw response: %s", raw_content[:200])

    try:
        result = json.loads(raw_content)
    except json.JSONDecodeError as e:
        raise ValueError(f"AI の応答が不正な JSON です: {e}") from e

    # 必須フィールドの検証とデフォルト値
    return {
        "ocr_text": result.get("ocr_text", ""),
        "description": result.get("description", ""),
        "tags": [
            {
                "label": tag.get("label", ""),
                "confidence": min(max(float(tag.get("confidence", 0.5)), 0.0), 1.0),
            }
            for tag in result.get("tags", [])
            if tag.get("label")
        ],
    }
