"""API キー認証の依存関数"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader

from app.config import settings

logger = logging.getLogger(__name__)

_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
_device_id_header = APIKeyHeader(name="X-Device-ID", auto_error=False)


async def verify_api_key(
    api_key: Optional[str] = Security(_api_key_header),
    device_id: Optional[str] = Security(_device_id_header),
) -> str:
    """
    X-API-Key ヘッダーを config の api_key と照合し、X-Device-ID の存在を確認する。

    api_key が未設定（空文字）の場合は認証をスキップする（ローカル開発用）。
    認証成功時は device_id を返す。
    """
    configured_key = settings.api_key

    # API キーが未設定の場合は認証スキップ
    if not configured_key:
        return device_id or "unknown"

    if not api_key:
        logger.warning("Missing X-API-Key header")
        raise HTTPException(
            status_code=401,
            detail="認証エラー: API キーが必要です。",
        )

    if api_key != configured_key:
        logger.warning("Invalid API key attempt")
        raise HTTPException(
            status_code=401,
            detail="認証エラー: API キーが無効です。",
        )

    if not device_id:
        logger.warning("Missing X-Device-ID header (api_key valid)")
        raise HTTPException(
            status_code=401,
            detail="認証エラー: デバイス ID が必要です。",
        )

    return device_id
