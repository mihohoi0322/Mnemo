from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """環境変数からアプリケーション設定を読み込む（Pydantic による型安全な設定）"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    azure_ai_project_connection_string: str = ""
    azure_openai_deployment_vision: str = "gpt-5-mini"
    azure_openai_deployment_embedding: str = "text-embedding-3-small"
    api_key: str = ""
    embedding_dimensions: int = 512


settings = Settings()
