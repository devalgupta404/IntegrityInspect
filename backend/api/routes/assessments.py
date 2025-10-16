from fastapi import APIRouter, HTTPException, UploadFile, File, BackgroundTasks
from typing import List, Optional
import uuid
from datetime import datetime
import logging

from services.gpt_service import GPTService
from services.sora_service import SoraService
from services.storage_service import StorageService
from models.schemas import AssessmentCreate, AssessmentResponse

logger = logging.getLogger(__name__)

router = APIRouter()

gpt_service = GPTService()
sora_service = SoraService()
storage_service = StorageService()


@router.post("/submit", response_model=AssessmentResponse)
async def submit_assessment(
    assessment: AssessmentCreate,
    background_tasks: BackgroundTasks
):


    assessment_id = str(uuid.uuid4())


    logger.info(f"Received assessment {assessment_id} - {assessment.building_type}")


    background_tasks.add_task(
        run_analysis,
        assessment_id,
        assessment.model_dump()
    )

    return {
        "assessment_id": assessment_id,
        "status": "processing",
        "message": "Assessment received. Analysis in progress."
    }


@router.post("/upload-photos/{assessment_id}")
async def upload_photos(
    assessment_id: str,
    files: List[UploadFile] = File(...)
):


    if not files:
        raise HTTPException(400, "No files provided")

    uploaded_urls: List[str] = []

    for file in files:
        if not file.content_type or not file.content_type.startswith('image/'):
            raise HTTPException(400, "Only image files allowed")

        filename = f"{assessment_id}/{uuid.uuid4()}.jpg"
        url = await storage_service.upload_file(file, filename)
        if url:
            uploaded_urls.append(url)

    return {
        "assessment_id": assessment_id,
        "photo_urls": uploaded_urls
    }


@router.get("/status/{assessment_id}")
async def get_analysis_status(assessment_id: str):


    return {
        "assessment_id": assessment_id,
        "status": "processing",
        "result": None
    }


async def run_analysis(assessment_id: str, assessment_data: dict):

    try:
        gpt_result = await gpt_service.analyze_structural_damage(
            building_data=assessment_data,
            image_urls=assessment_data.get('photo_urls', [])
        )

        video_url: Optional[str] = None
        if gpt_result.get('risk_level') in ['high', 'critical']:
            video_url = await sora_service.generate_collapse_simulation(
                prompt=gpt_result.get('sora_prompt', ''),
                reference_image_url=(assessment_data['photo_urls'][0]
                                     if assessment_data.get('photo_urls') else None)
            )

        analysis_record = {
            "assessment_id": assessment_id,
            "risk_level": gpt_result.get('risk_level'),
            "analysis": gpt_result.get('analysis'),
            "failure_mode": gpt_result.get('failure_mode'),
            "recommendations": gpt_result.get('recommendations', []),
            "video_url": video_url,
            "generated_at": datetime.utcnow().isoformat(),
            "confidence": gpt_result.get('confidence', 'medium')
        }

        logger.info(f"Analysis completed for {assessment_id}: {analysis_record['risk_level']}")

    except Exception as e:
        logger.error(f"Analysis failed for {assessment_id}: {str(e)}")



