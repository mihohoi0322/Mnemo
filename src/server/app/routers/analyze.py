"""画像解析エンドポイント — POST /analyze"""

import logging

from fastapi import APIRouter, Depends, HTTPException

from app.auth import verify_api_key
from app.schemas.analyze import AnalyzeRequest, AnalyzeResponse, TagItem
from app.services.embedding import generate_embedding
from app.services.vision import analyze_image

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze(
    request: AnalyzeRequest, device_id: str = Depends(verify_api_key)
) -> AnalyzeResponse:
    """
    画像を AI で解析し、OCR テキスト・タグ・説明文・埋め込みベクトルを返す。

    処理フロー:
    1. gpt-5-mini で画像を解析（OCR + タグ + 説明文）
    2. 解析結果のテキストを結合し、text-embedding-3-small で埋め込みベクトルを生成
    """
    try:
        # Step 1: Vision API で画像解析
        logger.info("Analyzing image: %s", request.image_id)
        vision_result = await analyze_image(
            image_base64=request.image,
            language_hint=request.language_hint,
        )

        # Step 2: 埋め込みベクトル生成
        # OCR テキスト + 説明文 + タグラベルを結合
        tag_labels = " ".join(
            tag["label"] for tag in vision_result["tags"]
        )
        embedding_input = " ".join(
            filter(
                None,
                [
                    vision_result["ocr_text"],
                    vision_result["description"],
                    tag_labels,
                ],
            )
        )

        embedding: list[float] = []
        if embedding_input.strip():
            embedding = await generate_embedding(embedding_input)
        else:
            logger.warning(
                "No text content for embedding generation (image_id: %s)",
                request.image_id,
            )

        logger.info(
            "Analysis complete for image %s: ocr=%d chars, tags=%d, embedding=%d dims",
            request.image_id,
            len(vision_result["ocr_text"]),
            len(vision_result["tags"]),
            len(embedding),
        )

        return AnalyzeResponse(
            image_id=request.image_id,
            ocr_text=vision_result["ocr_text"],
            description=vision_result["description"],
            tags=[
                TagItem(label=t["label"], confidence=t["confidence"])
                for t in vision_result["tags"]
            ],
            embedding=embedding,
        )

    except ValueError as e:
        logger.error("Analysis validation error: %s", e)
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        error_msg = str(e)
        logger.error("Analysis failed for image %s: %s", request.image_id, error_msg)

        # Azure AI Foundry の一般的なエラーを分類
        if "rate limit" in error_msg.lower() or "429" in error_msg:
            raise HTTPException(
                status_code=429,
                detail="レート制限に達しました。しばらく待ってから再試行してください。",
                headers={"Retry-After": "60"},
            ) from e
        if "timeout" in error_msg.lower():
            raise HTTPException(
                status_code=503,
                detail="AI サービスがタイムアウトしました。しばらく待ってから再試行してください。",
            ) from e
        if "connection" in error_msg.lower() or "unavailable" in error_msg.lower():
            raise HTTPException(
                status_code=503,
                detail="AI サービスに接続できません。しばらく待ってから再試行してください。",
            ) from e

        raise HTTPException(
            status_code=500,
            detail="画像解析中に予期しないエラーが発生しました。時間をおいて再度お試しください。",
        ) from e
