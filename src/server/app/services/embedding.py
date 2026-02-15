"""Embedding サービス — text-embedding-3-small によるベクトル生成"""

import logging

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

from app.config import settings

logger = logging.getLogger(__name__)


def _get_openai_client():
    """Azure AI Foundry 経由で OpenAI 互換クライアントを取得する"""
    credential = DefaultAzureCredential()
    project_client = AIProjectClient(
        endpoint=settings.azure_ai_project_endpoint,
        credential=credential,
    )
    return project_client.get_openai_client()


async def generate_embedding(text: str) -> list[float]:
    """
    テキストから埋め込みベクトルを生成する。

    Args:
        text: 埋め込みベクトルを生成するテキスト

    Returns:
        list[float]: 512 次元の埋め込みベクトル

    Raises:
        Exception: Azure AI Foundry のエラー
    """
    openai_client = _get_openai_client()

    response = openai_client.embeddings.create(
        model=settings.azure_openai_deployment_embedding,
        input=[text],
        dimensions=settings.embedding_dimensions,
    )

    embedding = response.data[0].embedding
    logger.info(
        "Embedding generated: %d dimensions for text length %d",
        len(embedding),
        len(text),
    )
    return embedding
