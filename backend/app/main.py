from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: validate Supabase connection
    from app.db.supabase import get_supabase
    get_supabase()
    yield
    # Shutdown: nothing to clean up for now


app = FastAPI(
    title="Receiptor API",
    description="Fiscal compliance backend for cross-border workers",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.routers import auth, dashboard, holidays, receipts, report

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(receipts.router, prefix="/receipts", tags=["receipts"])
app.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
app.include_router(holidays.router, prefix="/holidays", tags=["holidays"])
app.include_router(report.router, prefix="/report", tags=["report"])


@app.get("/health")
async def health():
    return {"status": "ok"}
