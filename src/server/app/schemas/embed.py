from pydantic import BaseModel, Field


class EmbedRequest(BaseModel):
    """テキスト埋め込みリクエスト"""

    text: str = Field(..., min_length=1, description="埋め込みベクトルを生成するテキスト")


class EmbedResponse(BaseModel):
    """テキスト埋め込みレスポンス"""

    embedding: list[float] = Field(
        ..., description="512 次元の埋め込みベクトル"
    )


class SearchEmbedRequest(BaseModel):
    """検索クエリ埋め込みリクエスト"""

    query: str = Field(..., min_length=1, description="検索クエリ文字列")


class SearchEmbedResponse(BaseModel):
    """検索クエリ埋め込みレスポンス"""

    embedding: list[float] = Field(
        ..., description="512 次元の埋め込みベクトル"
    )
