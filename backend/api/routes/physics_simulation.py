"""
API routes for physics-based structural simulation
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from typing import List, Dict, Optional
import json
import os
import logging
from datetime import datetime

from services.physics_simulation_service import PhysicsSimulationService
from services.simulation_video_service import SimulationVideoService
from models.schemas import PhysicsSimulationRequest, PhysicsSimulationResponse

logger = logging.getLogger(__name__)
router = APIRouter()

# Initialize services
physics_service = PhysicsSimulationService()
video_service = SimulationVideoService()

@router.post("/analyze", response_model=PhysicsSimulationResponse)
async def analyze_structural_damage(
    request: PhysicsSimulationRequest,
    background_tasks: BackgroundTasks
):
    """
    Perform physics-based structural analysis with simulation
    """
    try:
        logger.info(f"Starting physics analysis for building: {request.building_type}")
        
        # Convert request to analysis format
        building_data = {
            "building_type": request.building_type,
            "number_of_floors": request.number_of_floors,
            "primary_material": request.primary_material,
            "year_built": request.year_built,
            "damage_types": request.damage_types,
            "damage_description": request.damage_description,
            "latitude": request.latitude,
            "longitude": request.longitude,
        }
        
        # Run physics simulation
        analysis_result = await physics_service.analyze_structural_damage(
            building_data=building_data,
            annotations=request.annotations,
            photo_paths=request.photo_paths
        )
        
        # Generate simulation video in background
        simulation_id = f"sim_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        background_tasks.add_task(
            _generate_simulation_video,
            simulation_id,
            analysis_result["simulation_video_data"]
        )
        
        return PhysicsSimulationResponse(
            simulation_id=simulation_id,
            risk_level=analysis_result["risk_level"],
            engineering_analysis=analysis_result["engineering_analysis"],
            safety_factor=analysis_result["risk_metrics"]["safety_factor"],
            failure_probability=analysis_result["risk_metrics"]["failure_probability"],
            confidence=analysis_result["confidence"],
            fea_results=analysis_result["fea_results"],
            collapse_simulation=analysis_result["collapse_simulation"],
            video_url=f"http://192.168.1.5:8000/api/v1/simulation/video/{simulation_id}",
            generated_at=analysis_result["generated_at"]
        )
        
    except Exception as e:
        logger.error(f"Physics analysis error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@router.get("/video/{simulation_id}")
async def get_simulation_video(simulation_id: str):
    """
    Get generated simulation video
    """
    try:
        # Check if video file exists
        video_path = f"simulation_videos/{simulation_id}.mp4"
        if os.path.exists(video_path):
            return {
                "simulation_id": simulation_id,
                "video_url": f"http://192.168.1.5:8000/api/v1/simulation/video/file/{simulation_id}",
                "status": "completed",
                "generated_at": datetime.now().isoformat()
            }
        else:
            # Return a placeholder for now
            return {
                "simulation_id": simulation_id,
                "video_url": f"http://192.168.1.5:8000/api/v1/simulation/video/placeholder/{simulation_id}",
                "status": "generating",
                "generated_at": datetime.now().isoformat()
            }
    except Exception as e:
        logger.error(f"Video retrieval error: {str(e)}")
        raise HTTPException(status_code=404, detail="Video not found")

@router.get("/video/file/{simulation_id}")
async def serve_video_file(simulation_id: str):
    """
    Serve the actual video file
    """
    try:
        video_path = f"simulation_videos/{simulation_id}.mp4"
        if os.path.exists(video_path):
            from fastapi.responses import FileResponse
            return FileResponse(video_path, media_type="video/mp4")
        else:
            raise HTTPException(status_code=404, detail="Video file not found")
    except Exception as e:
        logger.error(f"Video file serving error: {str(e)}")
        raise HTTPException(status_code=500, detail="Error serving video file")

@router.get("/video/placeholder/{simulation_id}")
async def serve_placeholder_video(simulation_id: str):
    """
    Serve a real generated video for demonstration
    """
    try:
        # Create a real video file using OpenCV
        placeholder_path = f"simulation_videos/placeholder_{simulation_id}.mp4"
        if not os.path.exists(placeholder_path):
            os.makedirs("simulation_videos", exist_ok=True)
            
            # Generate a real MP4 video using OpenCV
            import cv2
            import numpy as np
            
            # Video settings
            width, height = 800, 600
            fps = 30
            duration = 5  # 5 seconds
            total_frames = duration * fps
            
            # Create video writer
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            out = cv2.VideoWriter(placeholder_path, fourcc, fps, (width, height))
            
            if not out.isOpened():
                raise Exception("Could not open video writer")
            
            # Generate frames with animation
            for frame in range(total_frames):
                # Create black frame
                frame_img = np.zeros((height, width, 3), dtype=np.uint8)
                
                # Calculate time
                time = frame / fps
                
                # Draw building with damage assessment
                building_x = width // 2
                building_width = 100
                building_height = 200  # Building stays standing
                
                if building_height > 0:
                    # Building (blue)
                    cv2.rectangle(frame_img, 
                                 (building_x - building_width//2, height - building_height),
                                 (building_x + building_width//2, height),
                                 (100, 100, 255), -1)
                    
                    # Building outline (white)
                    cv2.rectangle(frame_img, 
                                 (building_x - building_width//2, height - building_height),
                                 (building_x + building_width//2, height),
                                 (255, 255, 255), 2)
                
                # Draw damage indicators on building
                damage_color = (0, 255, 255) if time < 2.5 else (0, 100, 255)  # Yellow to red
                
                # Draw crack lines on building
                for i in range(3):
                    start_x = building_x - building_width//2 + (i+1) * building_width//4
                    start_y = height - building_height + 50
                    end_x = start_x + 20
                    end_y = start_y + 100
                    cv2.line(frame_img, (start_x, start_y), (end_x, end_y), damage_color, 3)
                
                # Draw safety zones around building
                cv2.circle(frame_img, (building_x, height - 50), 80, (0, 255, 0), 2)  # Green safety zone
                cv2.putText(frame_img, "SAFE ZONE", (building_x - 40, height - 100), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
                
                # Add text
                cv2.putText(frame_img, f"Time: {time:.1f}s", (10, 30), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
                cv2.putText(frame_img, "Structural Assessment", (10, height - 20), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                
                # Add risk level indicator
                risk_level = "LOW RISK" if time < 2.5 else "HIGH RISK"
                risk_color = (0, 255, 0) if time < 2.5 else (0, 0, 255)
                cv2.putText(frame_img, risk_level, (width - 200, 30), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, risk_color, 2)
                
                # Write frame
                out.write(frame_img)
            
            out.release()
            logger.info(f"Generated real video: {placeholder_path}")
        
        from fastapi.responses import FileResponse
        return FileResponse(placeholder_path, media_type="video/mp4")
    except Exception as e:
        logger.error(f"Placeholder video error: {str(e)}")
        raise HTTPException(status_code=500, detail="Error serving placeholder video")

@router.get("/status/{simulation_id}")
async def get_simulation_status(simulation_id: str):
    """
    Check simulation generation status
    """
    try:
        # In a real implementation, this would check actual status
        return {
            "simulation_id": simulation_id,
            "status": "completed",
            "progress": 100,
            "video_ready": True
        }
    except Exception as e:
        logger.error(f"Status check error: {str(e)}")
        raise HTTPException(status_code=404, detail="Simulation not found")

async def _generate_simulation_video(simulation_id: str, simulation_data: Dict):
    """
    Background task to generate simulation video
    """
    try:
        logger.info(f"Generating simulation video for {simulation_id}")
        
        # Generate video from physics data
        video_path = await video_service.generate_simulation_video(
            simulation_data=simulation_data,
            output_path=f"/tmp/simulation_{simulation_id}.mp4"
        )
        
        logger.info(f"Simulation video generated: {video_path}")
        
    except Exception as e:
        logger.error(f"Video generation error for {simulation_id}: {str(e)}")
