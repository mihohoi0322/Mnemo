import os


class Settings:
    """環境変数からアプリケーション設定を読み込む"""

    @property
    def azure_ai_project_connection_string(self) -> str:
        return os.environ.get("AZURE_AI_PROJECT_CONNECTION_STRING", "")

    @property
    def azure_openai_deployment_vision(self) -> str:
        return os.environ.get("AZURE_OPENAI_DEPLOYMENT_VISION", "gpt-5-mini")

    @property
    def azure_openai_deployment_embedding(self) -> str:
        return os.environ.get(
            "AZURE_OPENAI_DEPLOYMENT_EMBEDDING", "text-embedding-3-small"
        )

    @property
    def api_key(self) -> str:
        return os.environ.get("API_KEY", "")

    @property
    def embedding_dimensions(self) -> int:
        return int(os.environ.get("EMBEDDING_DIMENSIONS", "512"))


settings = Settings()
