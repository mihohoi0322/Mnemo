import azure.functions as func

from app.main import app as fastapi_app

# AuthLevel.FUNCTION: Requires function key (host key or function-specific key) for access
# This provides host-level protection for all FastAPI routes mounted via ASGI
app = func.AsgiFunctionApp(app=fastapi_app, http_auth_level=func.AuthLevel.FUNCTION)
