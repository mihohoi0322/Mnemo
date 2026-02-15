from fastapi import FastAPI

from app.routers import analyze, embed, health

app = FastAPI(
    title="Mnemo API",
    description="スクリーンショット AI 解析 API",
    version="0.1.0",
)

app.include_router(health.router)
app.include_router(analyze.router)
app.include_router(embed.router)
