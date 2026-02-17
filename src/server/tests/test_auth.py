"""API キー認証のテスト"""

from unittest.mock import patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.auth import verify_api_key
from app.routers import health


def _create_app() -> FastAPI:
    """認証付きテスト用 FastAPI アプリを作成する。"""
    from fastapi import Depends

    app = FastAPI()

    # /health — 認証なし
    app.include_router(health.router)

    # /protected — 認証あり（テスト用ダミー）
    @app.post("/protected")
    async def protected_endpoint(device_id: str = Depends(verify_api_key)):
        return {"device_id": device_id}

    return app


# --- API キーが設定されている場合 ---


class TestAuthWithApiKey:
    """API_KEY が設定されている場合のテスト。"""

    @pytest.fixture()
    def client(self):
        with patch("app.auth.settings") as mock_settings:
            mock_settings.api_key = "test-secret-key"
            app = _create_app()
            yield TestClient(app)

    def test_valid_api_key_and_device_id(self, client):
        """正しい API キーとデバイス ID で 200 が返る。"""
        response = client.post(
            "/protected",
            headers={
                "X-API-Key": "test-secret-key",
                "X-Device-ID": "device-123",
            },
        )
        assert response.status_code == 200
        assert response.json() == {"device_id": "device-123"}

    def test_missing_api_key(self, client):
        """API キーヘッダーがない場合は 401 が返る。"""
        response = client.post(
            "/protected",
            headers={"X-Device-ID": "device-123"},
        )
        assert response.status_code == 401
        assert "API キー" in response.json()["detail"]

    def test_invalid_api_key(self, client):
        """不正な API キーの場合は 401 が返る。"""
        response = client.post(
            "/protected",
            headers={
                "X-API-Key": "wrong-key",
                "X-Device-ID": "device-123",
            },
        )
        assert response.status_code == 401
        assert "無効" in response.json()["detail"]

    def test_missing_device_id(self, client):
        """デバイス ID ヘッダーがない場合は 401 が返る。"""
        response = client.post(
            "/protected",
            headers={"X-API-Key": "test-secret-key"},
        )
        assert response.status_code == 401
        assert "デバイス ID" in response.json()["detail"]


# --- API キーが未設定の場合（ローカル開発用） ---


class TestAuthWithoutApiKey:
    """API_KEY が空文字の場合のテスト（認証スキップ）。"""

    @pytest.fixture()
    def client(self):
        with patch("app.auth.settings") as mock_settings:
            mock_settings.api_key = ""
            app = _create_app()
            yield TestClient(app)

    def test_no_auth_required(self, client):
        """API キー未設定時はヘッダーなしでもアクセスできる。"""
        response = client.post("/protected")
        assert response.status_code == 200
        assert response.json() == {"device_id": "unknown"}

    def test_device_id_passthrough(self, client):
        """API キー未設定時でもデバイス ID は渡される。"""
        response = client.post(
            "/protected",
            headers={"X-Device-ID": "device-456"},
        )
        assert response.status_code == 200
        assert response.json() == {"device_id": "device-456"}


# --- /health は認証不要 ---


class TestHealthNoAuth:
    """/health エンドポイントは認証なしでアクセスできる。"""

    @pytest.fixture()
    def client(self):
        with patch("app.auth.settings") as mock_settings:
            mock_settings.api_key = "test-secret-key"
            app = _create_app()
            yield TestClient(app)

    def test_health_without_auth(self, client):
        """/health は API キーなしでも 200 が返る。"""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}
