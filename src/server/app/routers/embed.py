"""埋め込みベクトル生成エンドポイント — POST /embed, POST /search/embed"""

import logging

from fastapi import APIRouter, HTTPException

from app.schemas.embed import (
    EmbedRequest,
    EmbedResponse,
    SearchEmbedRequest,
    SearchEmbedResponse,
)
from app.services.embedding import generate_embedding

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/embed", response_model=EmbedResponse)
async def embed(request: EmbedRequest) -> EmbedResponse:
    """テキストから埋め込みベクトルを生成する。"""
    try:
        logger.info("Generating embedding for text (%d chars)", len(request.text))
        embedding = await generate_embedding(request.text)
        return EmbedResponse(embedding=embedding)

    except Exception as e:
        error_msg = str(e)
        logger.error("Embedding generation failed: %s", error_msg)

        if "rate limit" in error_msg.lower() or "429" in error_msg:
            raise HTTPException(
                status_code=429,
                detail="レート制限に達しました。しばらく待ってから再試行してください。",
                headers={"Retry-After": "60"},
            ) from e
        if "timeout" in error_msg.lower():
            raise HTTPException(
                status_code=503,
                detail="AI サービスがタイムアウトしました。",
            ) from e
        if "connection" in error_msg.lower() or "unavailable" in error_msg.lower():
            raise HTTPException(
                status_code=503,
                detail="AI サービスに接続できません。",
            ) from e

        raise HTTPException(
            status_code=500,
            detail="埋め込みベクトル生成中に予期しないエラーが発生しました。時間をおいて再度お試しください。",
        ) from e


@router.post("/search/embed", response_model=SearchEmbedResponse)
async def search_embed(request: SearchEmbedRequest) -> SearchEmbedResponse:
    """検索クエリから埋め込みベクトルを生成する。"""
    try:
        logger.info("Generating search embedding for query (%d chars)", len(request.query))
        embedding = await generate_embedding(request.query)
        return SearchEmbedResponse(embedding=embedding)

    except Exception as e:
        error_msg = str(e)
        logger.error("Search embedding generation failed: %s", error_msg)

        if "rate limit" in error_msg.lower() or "429" in error_msg:
            raise HTTPException(
                status_code=429,
                detail="レート制限に達しました。しばらく待ってから再試行してください。",
                headers={"Retry-After": "60"},
            ) from e
        if "timeout" in error_msg.lower():
            raise HTTPException(
                status_code=503,
                detail="AI サービスがタイムアウトしました。",
            ) from e
        if "connection" in error_msg.lower() or "unavailable" in error_msg.lower():
            raise HTTPException(
                status_code=503,
                detail="AI サービスに接続できません。",
            ) from e

        raise HTTPException(
            status_code=500,
            detail="検索埋め込みベクトル生成中に予期しないエラーが発生しました。時間をおいて再度お試しください。",
        ) from e
