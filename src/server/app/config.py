from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """環境変数からアプリケーション設定を読み込む（Pydantic による型安全な設定）"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Azure AI Foundry のエンドポイント URL (必須)
    azure_ai_project_endpoint: str = Field(
        ...,
        min_length=1,
        description="Azure AI Foundry プロジェクトエンドポイント URL",
    )
    # 旧: connection_string（後方互換用、未使用）
    azure_ai_project_connection_string: str = ""
    azure_openai_deployment_vision: str = "gpt-5-mini"
    azure_openai_deployment_embedding: str = "text-embedding-3-small"
    api_key: str = ""
    embedding_dimensions: int = 512


settings = Settings()
