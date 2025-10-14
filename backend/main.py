from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
from typing import List
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting Integrity Inspect API...")
    logger.info(f"OpenAI API Key: {'Set' if os.getenv('OPENAI_API_KEY') else 'Not Set'}")
    yield
    # Shutdown
    logger.info("Shutting down Integrity Inspect API...")

app = FastAPI(
    title="Integrity Inspect API",
    description="Emergency Structural Assessment API with GPT-5 and Sora Integration",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import routes after app initialization
from api.routes import assessments, analysis, physics_simulation

# Include routers
app.include_router(
    assessments.router,
    prefix="/api/v1/assessments",
    tags=["assessments"]
)
app.include_router(
    analysis.router,
    prefix="/api/v1/analysis",
    tags=["analysis"]
)

app.include_router(
    physics_simulation.router,
    prefix="/api/v1/simulation",
    tags=["physics-simulation"]
)

@app.get("/")
async def root():
    return {
        "name": "Integrity Inspect API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "services": {
            "openai": "configured" if os.getenv("OPENAI_API_KEY") else "not configured",
            "database": "not implemented",
            "storage": "configured" if os.getenv("AWS_ACCESS_KEY_ID") else "not configured"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
