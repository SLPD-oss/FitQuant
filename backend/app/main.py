"""
FitQuant 后端 — FastAPI 主入口
"""
import sys
import os

# 确保 backend 目录在 Python 路径中
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, body, supplement, food, drug, workout, sync, meal, training, sleep, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理：启动时尝试初始化数据库，关闭时释放连接"""
    print("🌱 FitQuant 后端启动中...")
    try:
        from app.database import init_db, close_db
        await init_db()
        print("✅ 数据库表初始化完成")
    except Exception as e:
        print(f"⚠️  数据库未连接，仅 mock 模式可用: {e}")
    yield
    try:
        from app.database import close_db
        await close_db()
    except Exception:
        pass
    print("🌙 FitQuant 后端已关闭")


# ── 创建 FastAPI 应用 ──
app = FastAPI(
    title="FitQuant 后端 API",
    description="量化补充 App 后端服务 — 提供认证、身体数据、补剂方案、食物识别、药品查询、训练分类、数据同步等 8 组 API",
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS 跨域配置（允许 iOS 前端访问） ──
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── 健康检查 ──
@app.get("/health", tags=["系统"])
async def health_check():
    """服务健康检查"""
    return {"status": "ok", "service": "FitQuant API", "version": "1.0.0"}


# ── 注册路由 ──
app.include_router(auth.router)
app.include_router(body.router)
app.include_router(supplement.router)
app.include_router(food.router)
app.include_router(drug.router)
app.include_router(workout.router)
app.include_router(sync.router)
app.include_router(meal.router)
app.include_router(training.router)
app.include_router(sleep.router)
app.include_router(users.router)


# ── 直接运行入口 ──
if __name__ == "__main__":
    import uvicorn
    print("=" * 50)
    print("  FitQuant 后端服务")
    print("  启动方式: uvicorn app.main:app --reload")
    print("  本地地址: http://127.0.0.1:8000")
    print("  API 文档: http://127.0.0.1:8000/docs")
    print("=" * 50)
    uvicorn.run("app.main:app", host="127.0.0.1", port=8000, reload=True)
