from pydantic import BaseModel, Field


class TagItem(BaseModel):
    """自動タグ"""

    label: str = Field(..., description="タグラベル")
    confidence: float = Field(..., ge=0.0, le=1.0, description="信頼度 (0.0〜1.0)")


class AnalyzeRequest(BaseModel):
    """画像解析リクエスト"""

    image: str = Field(..., description="Base64 エンコードされた画像データ")
    image_id: str = Field(..., description="画像の一意識別子 (UUID)")
    language_hint: str | None = Field(
        None, description="言語ヒント (例: 'ja', 'en')"
    )


class AnalyzeResponse(BaseModel):
    """画像解析レスポンス"""

    image_id: str = Field(..., description="画像の一意識別子")
    ocr_text: str = Field(..., description="OCR で抽出されたテキスト")
    description: str = Field(..., description="AI が生成した画像の説明文")
    tags: list[TagItem] = Field(default_factory=list, description="自動生成されたタグ")
    embedding: list[float] = Field(
        default_factory=list, description="512 次元の埋め込みベクトル"
    )
