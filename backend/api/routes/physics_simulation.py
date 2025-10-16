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
from services.paraview_service import ParaViewService
from models.schemas import PhysicsSimulationRequest, PhysicsSimulationResponse
import openai
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)
router = APIRouter()

# Initialize services
physics_service = PhysicsSimulationService()
video_service = SimulationVideoService()

# Initialize OpenAI client for GPT-based simulation instructions
openai_api_key = os.getenv("OPENAI_API_KEY")
openai_client = openai.AsyncOpenAI(api_key=openai_api_key) if openai_api_key else None

# Initialize ParaView service with OpenAI client
paraview_service = ParaViewService(openai_client=openai_client)

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
        
        # Convert annotations to dictionaries
        annotations_dict = [
            {
                "id": ann.id,
                "position": ann.position,
                "issueType": ann.issueType,
                "description": ann.description,
                "color": ann.color,
                "timestamp": ann.timestamp
            }
            for ann in request.annotations
        ]

        logger.info(f"Converted {len(annotations_dict)} annotations to dictionaries")
        logger.info(f"First annotation type: {type(annotations_dict[0]) if annotations_dict else 'None'}")
        if annotations_dict:
            logger.info(f"First annotation: {annotations_dict[0]}")

        # Run physics simulation
        analysis_result = await physics_service.analyze_structural_damage(
            building_data=building_data,
            annotations=annotations_dict,
            photo_paths=request.photo_paths
        )
        
        # Generate simulation video in background
        simulation_id = f"sim_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        background_tasks.add_task(
            _generate_simulation_video,
            simulation_id,
            building_data,
            annotations_dict,
            analysis_result
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
            video_url=f"http://192.168.1.20:8000/api/v1/simulation/video/placeholder/{simulation_id}",
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
                "video_url": f"http://192.168.1.20:8000/api/v1/simulation/video/file/{simulation_id}",
                "status": "completed",
                "generated_at": datetime.now().isoformat()
            }
        else:
            # Return a placeholder for now
            return {
                "simulation_id": simulation_id,
                "video_url": f"http://192.168.1.20:8000/api/v1/simulation/video/placeholder/{simulation_id}",
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
    Serve ParaView video if available, otherwise generate placeholder
    """
    try:
        # FIRST: Check if ParaView video exists
        paraview_video_path = f"simulation_videos/{simulation_id}.mp4"
        if os.path.exists(paraview_video_path):
            logger.info(f"Serving ParaView video: {paraview_video_path}")
            from fastapi.responses import FileResponse
            return FileResponse(paraview_video_path, media_type="video/mp4")

        # SECOND: Create a placeholder if ParaView video doesn't exist yet
        placeholder_path = f"simulation_videos/placeholder_{simulation_id}.mp4"
        if not os.path.exists(placeholder_path):
            os.makedirs("simulation_videos", exist_ok=True)
            
            # Generate a real MP4 video using OpenCV
            import cv2
            import numpy as np
            
            # Video settings - Full HD for engineering overlays
            width, height = 1920, 1080
            fps = 30
            duration = 10  # 10 seconds - full demonstration
            total_frames = duration * fps

            # Create video writer with H.264 codec
            fourcc = cv2.VideoWriter_fourcc(*'avc1')  # H.264 codec for better mobile compatibility
            out = cv2.VideoWriter(placeholder_path, fourcc, fps, (width, height))

            if not out.isOpened():
                raise Exception("Could not open video writer")

            # Engineering video phases
            PHASE_1_DURATION = 3.0  # Show damage
            PHASE_2_DURATION = 3.0  # Show heatmap
            PHASE_3_START = PHASE_1_DURATION + PHASE_2_DURATION  # Collapse

            # Generate frames with engineering-focused visualization
            for frame in range(total_frames):
                # Dark background
                frame_img = np.zeros((height, width, 3), dtype=np.uint8)
                frame_img[:] = (20, 20, 20)

                time = frame / fps
                building_x = width // 2
                building_width = 300
                building_height = 500
                num_floors = 5
                floor_height = building_height // num_floors

                # PHASE 1: Initial condition with damage highlighted
                if time < PHASE_1_DURATION:
                    # Draw intact building
                    for floor in range(num_floors):
                        y_pos = height - 150 - (floor * floor_height)
                        cv2.rectangle(frame_img,
                                     (building_x - building_width//2, y_pos),
                                     (building_x + building_width//2, y_pos + floor_height),
                                     (100, 100, 100), -1)
                        cv2.rectangle(frame_img,
                                     (building_x - building_width//2, y_pos),
                                     (building_x + building_width//2, y_pos + floor_height),
                                     (200, 200, 200), 2)

                    # Highlight damage in yellow (blinking)
                    if int(time * 2) % 2:
                        cv2.rectangle(frame_img,
                                     (building_x - 60 - 15, height - 150 - floor_height * 3),
                                     (building_x - 60 + 15, height - 150 - floor_height * 2),
                                     (0, 255, 255), 5)
                        cv2.putText(frame_img, "DAMAGED COLUMN",
                                   (building_x - 140, height - 150 - floor_height * 3 - 10),
                                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)

                    cv2.putText(frame_img, "PHASE 1: INITIAL CONDITION",
                               (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3)

                # PHASE 2: Stress analysis heatmap
                elif time < PHASE_1_DURATION + PHASE_2_DURATION:
                    # Draw heatmap
                    for floor in range(num_floors):
                        y_pos = height - 150 - (floor * floor_height)
                        stress = 0.3 + (num_floors - floor) * 0.15  # Higher stress at bottom

                        # Color based on stress
                        if stress < 0.5:
                            color = (0, 255, int(255 * (1 - stress * 2)))  # Green to yellow
                        else:
                            color = (0, int(255 * (1 - (stress - 0.5) * 2)), 255)  # Yellow to red

                        cv2.rectangle(frame_img,
                                     (building_x - building_width//2, y_pos),
                                     (building_x + building_width//2, y_pos + floor_height),
                                     color, -1)

                    # Critical point marker
                    cv2.circle(frame_img, (building_x - 60, height - 150 - floor_height * 3), 30, (0, 0, 255), 3)
                    cv2.putText(frame_img, "CRITICAL POINT",
                               (building_x - 140, height - 150 - floor_height * 3 - 40),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

                    cv2.putText(frame_img, "PHASE 2: STRESS ANALYSIS (FEA)",
                               (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 255), 3)

                # PHASE 3: Collapse simulation
                else:
                    collapse_time = time - PHASE_3_START
                    collapse_progress = min(1.0, collapse_time / 4.0)

                    # Pancake collapse animation
                    for floor in range(num_floors):
                        fall_distance = collapse_progress * (floor * 100)
                        y_pos = height - 150 - (floor * floor_height) + fall_distance
                        alpha = max(0, 1.0 - collapse_progress * (num_floors - floor) / num_floors)
                        color = tuple(int(c * alpha) for c in (80, 80, 80))

                        cv2.rectangle(frame_img,
                                     (building_x - building_width//2, int(y_pos)),
                                     (building_x + building_width//2, int(y_pos + floor_height)),
                                     color, -1)

                    cv2.putText(frame_img, "PHASE 3: PREDICTED COLLAPSE - PANCAKE COLLAPSE",
                               (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 3)

                # Draw safety zones (always visible)
                ground_y = height - 150
                cv2.circle(frame_img, (building_x, ground_y), 200, (0, 0, 255), 3)  # Danger
                cv2.circle(frame_img, (building_x, ground_y), 350, (0, 255, 255), 2)  # Caution
                cv2.circle(frame_img, (building_x, ground_y), 500, (0, 255, 0), 2)  # Safe

                # Add all informational overlays
                cv2.putText(frame_img, f"T+{time:.1f}s", (50, height - 50),
                           cv2.FONT_HERSHEY_SIMPLEX, 1.5, (255, 255, 255), 3)
                cv2.putText(frame_img, "PREDICTED: PANCAKE COLLAPSE", (width - 700, height - 50),
                           cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2)

                # Safety instruction (semi-transparent background)
                overlay = frame_img.copy()
                cv2.rectangle(overlay, (30, height - 150), (width - 30, height - 100), (0, 0, 0), -1)
                cv2.addWeighted(overlay, 0.7, frame_img, 0.3, 0, frame_img)
                cv2.putText(frame_img, "RISK: HIGH - AVOID BUILDING AND ADJACENT STRUCTURES",
                           (50, height - 115), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)

                # Risk indicator box
                cv2.rectangle(frame_img, (width - 300, 20), (width - 50, 80), (0, 0, 255), -1)
                cv2.rectangle(frame_img, (width - 300, 20), (width - 50, 80), (255, 255, 255), 2)
                cv2.putText(frame_img, "RISK: HIGH", (width - 280, 60),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

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

async def _generate_simulation_video(
    simulation_id: str,
    building_data: Dict,
    annotations: List[Dict],
    analysis_result: Dict
):
    """
    Background task to generate simulation video using ParaView with GPT-guided instructions
    """
    try:
        logger.info(f"Generating simulation video for {simulation_id}")

        # Output path
        output_dir = "simulation_videos"
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, f"{simulation_id}.mp4")

        # USE FALLBACK ONLY - ParaView overlays are not working reliably
        # Generate enhanced video using OpenCV with overlays
        logger.info("Using OpenCV for video generation with enhanced overlays...")

        # Create enhanced simulation_video_data with all required information
        enhanced_data = analysis_result.get("simulation_video_data", {})
        enhanced_data.update({
            "building_data": building_data,
            "annotations": annotations,
            "fea_results": analysis_result["fea_results"],
            "collapse_simulation": analysis_result["collapse_simulation"],
            "risk_level": analysis_result["risk_level"],
            "safety_factor": analysis_result["risk_metrics"]["safety_factor"],
            "failure_probability": analysis_result["risk_metrics"]["failure_probability"]
        })

        video_path = await video_service.generate_simulation_video(
            simulation_data=enhanced_data,
            output_path=output_path
        )
        logger.info(f"✅ Enhanced OpenCV video generated: {video_path}")

    except Exception as e:
        logger.error(f"Video generation error for {simulation_id}: {str(e)}")
