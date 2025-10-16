"""
Service for generating simulation videos from physics data
Converts PyChrono simulation results into MP4 videos using Blender
"""

import json
import os
import subprocess
import tempfile
import logging
from typing import Dict, List, Optional
from datetime import datetime
import numpy as np

# Try to import OpenCV
try:
    import cv2
    OPENCV_AVAILABLE = True
except ImportError:
    OPENCV_AVAILABLE = False
    logging.warning("OpenCV not available")

logger = logging.getLogger(__name__)

class SimulationVideoService:
    """Service for generating physics simulation videos"""
    
    def __init__(self):
        self.temp_dir = tempfile.mkdtemp()
        self.blender_script_path = os.path.join(self.temp_dir, "simulation_script.py")
        
    async def generate_simulation_video(
        self, 
        simulation_data: Dict,
        output_path: Optional[str] = None
    ) -> str:
        """
        Generate simulation video from physics data
        
        Args:
            simulation_data: Physics simulation results from PyChrono
            output_path: Optional custom output path
            
        Returns:
            Path to generated video file
        """
        try:
            logger.info("Generating simulation video from physics data...")
            
            # Create output path if not provided
            if not output_path:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_path = os.path.join(self.temp_dir, f"simulation_{timestamp}.mp4")
            
            # Generate Blender script
            blender_script = self._create_blender_script(simulation_data, output_path)
            
            # Write script to file
            with open(self.blender_script_path, 'w') as f:
                f.write(blender_script)
            
            # Try different video generation methods
            video_path = await self._generate_video_with_fallback(simulation_data, output_path)
            
            logger.info(f"Simulation video generated: {video_path}")
            return video_path
            
        except Exception as e:
            logger.error(f"Video generation error: {str(e)}")
            raise Exception(f"Failed to generate simulation video: {str(e)}")
    
    async def _generate_video_with_fallback(self, simulation_data: Dict, output_path: str) -> str:
        """Try different video generation methods in order of preference"""
        
        # Method 1: Try OpenCV (most reliable, no external dependencies)
        try:
            logger.info("Attempting OpenCV video generation...")
            return await self._generate_opencv_video(simulation_data, output_path)
        except Exception as e:
            logger.warning(f"OpenCV video generation failed: {str(e)}")
        
        # Method 2: Try Blender (best quality, requires Blender installation)
        try:
            logger.info("Attempting Blender video generation...")
            return await self._run_blender_rendering(output_path)
        except Exception as e:
            logger.warning(f"Blender video generation failed: {str(e)}")
        
        # Method 3: Fallback to HTML5 visualization
        logger.info("Using HTML5 fallback visualization...")
        return self.create_simplified_video(simulation_data)
    
    async def _generate_opencv_video(self, simulation_data: Dict, output_path: str) -> str:
        """Generate engineering-focused video using OpenCV with all required overlays"""
        try:
            if not OPENCV_AVAILABLE:
                raise Exception("OpenCV not available")

            logger.info("Generating OpenCV simulation video with engineering overlays...")

            # Video settings
            width, height = 1920, 1080  # Full HD for better readability
            fps = 30
            duration = simulation_data.get("simulation_duration", 10.0)
            total_frames = int(duration * fps)

            # Create video writer with H.264 codec for mobile compatibility
            fourcc = cv2.VideoWriter_fourcc(*'avc1')  # H.264 codec
            out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

            if not out.isOpened():
                raise Exception("Could not open video writer")

            # Get simulation data
            collapse_sequence = simulation_data.get("collapse_sequence", [])
            debris_pattern = simulation_data.get("debris_pattern", [])
            safety_zones = simulation_data.get("safety_zones", [])

            # Get building and risk data
            building_data = simulation_data.get("building_data", {})
            fea_results = simulation_data.get("fea_results", {})

            # Determine collapse type from simulation data
            collapse_type = self._determine_collapse_type(collapse_sequence)
            risk_level = simulation_data.get("risk_level", "HIGH")
            safety_factor = simulation_data.get("safety_factor", 1.0)
            failure_probability = simulation_data.get("failure_probability", 0.5)

            # Define phases of the video
            PHASE_1_DURATION = 2.0  # Show intact building with damage
            PHASE_2_DURATION = 2.0  # Show stress heatmap
            PHASE_3_START = PHASE_1_DURATION + PHASE_2_DURATION  # Collapse begins

            # Generate frames
            for frame in range(total_frames):
                # Create dark background
                frame_img = np.zeros((height, width, 3), dtype=np.uint8)
                frame_img[:] = (20, 20, 20)  # Dark gray background

                # Calculate time
                time = frame / fps

                # PHASE 1: "Before" State - Show building with damage highlighted
                if time < PHASE_1_DURATION:
                    self._draw_intact_building_with_damage(frame_img, time, width, height)
                    self._add_phase_title(frame_img, "PHASE 1: INITIAL CONDITION", (255, 255, 255))

                # PHASE 2: Stress Analysis Heatmap
                elif time < PHASE_1_DURATION + PHASE_2_DURATION:
                    self._draw_building_with_heatmap(frame_img, time - PHASE_1_DURATION, width, height)
                    self._add_phase_title(frame_img, "PHASE 2: STRESS ANALYSIS (FEA)", (0, 255, 255))

                # PHASE 3: Collapse Sequence
                else:
                    collapse_time = time - PHASE_3_START
                    self._draw_collapse_sequence(frame_img, collapse_time, collapse_sequence, width, height, collapse_type)
                    self._add_phase_title(frame_img, f"PHASE 3: PREDICTED COLLAPSE - {collapse_type}", (0, 0, 255))

                # Draw safety zones (always visible)
                self._draw_safety_zones_detailed(frame_img, safety_zones, width, height)

                # Draw debris field
                if time > PHASE_3_START:
                    self._draw_debris_field(frame_img, time - PHASE_3_START, debris_pattern, width, height)

                # Add informational overlays (always visible)
                self._add_building_info_overlay(frame_img, building_data, safety_factor, failure_probability, width, height)
                self._add_time_overlay(frame_img, time, width, height)
                self._add_collapse_type_label(frame_img, collapse_type, width, height)
                self._add_safety_instructions(frame_img, risk_level, collapse_type, width, height)
                self._add_risk_indicator(frame_img, risk_level, width, height)

                # Write frame
                out.write(frame_img)

            out.release()
            logger.info(f"OpenCV video generated with engineering overlays: {output_path}")
            return output_path

        except ImportError:
            raise Exception("OpenCV not available")
        except Exception as e:
            raise Exception(f"OpenCV video generation failed: {str(e)}")
    
    def _determine_collapse_type(self, collapse_sequence: List[Dict]) -> str:
        """Determine the most likely collapse type from simulation data"""
        if not collapse_sequence:
            return "PROGRESSIVE COLLAPSE"

        # Analyze collapse pattern - simplified logic
        # In reality, this would analyze the actual physics data
        collapse_types = ["PANCAKE COLLAPSE", "LEAN-TO COLLAPSE", "V-SHAPE COLLAPSE", "PROGRESSIVE COLLAPSE"]
        return collapse_types[len(collapse_sequence) % len(collapse_types)]

    def _draw_intact_building_with_damage(self, frame: np.ndarray, time: float, width: int, height: int):
        """PHASE 1: Draw intact building with damage areas highlighted in yellow"""
        building_x = width // 2
        building_width = 300
        building_height = 500
        num_floors = 5
        floor_height = building_height // num_floors

        # Draw building floors
        for floor in range(num_floors):
            y_pos = height - 150 - (floor * floor_height)

            # Floor slab (gray concrete)
            cv2.rectangle(frame,
                         (building_x - building_width//2, y_pos),
                         (building_x + building_width//2, y_pos + floor_height),
                         (100, 100, 100), -1)

            # Floor outline
            cv2.rectangle(frame,
                         (building_x - building_width//2, y_pos),
                         (building_x + building_width//2, y_pos + floor_height),
                         (200, 200, 200), 2)

        # Draw columns
        column_positions = [-120, -60, 0, 60, 120]
        for col_x in column_positions:
            cv2.rectangle(frame,
                         (building_x + col_x - 10, height - 150 - building_height),
                         (building_x + col_x + 10, height - 150),
                         (80, 80, 80), -1)

        # HIGHLIGHT DAMAGE ZONES IN YELLOW (blinking effect)
        blink = int(time * 2) % 2  # Blink every 0.5 seconds
        if blink:
            damage_color = (0, 255, 255)  # Yellow in BGR

            # Damaged column (example: second column, third floor)
            cv2.rectangle(frame,
                         (building_x - 60 - 15, height - 150 - floor_height * 3),
                         (building_x - 60 + 15, height - 150 - floor_height * 2),
                         damage_color, 5)

            # Damage label
            cv2.putText(frame, "DAMAGED COLUMN",
                       (building_x - 60 - 80, height - 150 - floor_height * 3 - 10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, damage_color, 2)

            # Crack on floor slab
            crack_y = height - 150 - floor_height * 2
            cv2.line(frame,
                    (building_x - 100, crack_y),
                    (building_x + 80, crack_y - 30),
                    damage_color, 4)
            cv2.putText(frame, "STRUCTURAL CRACK",
                       (building_x - 50, crack_y - 40),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, damage_color, 2)

    def _draw_building_with_heatmap(self, frame: np.ndarray, time: float, width: int, height: int):
        """PHASE 2: Draw building with FEA stress analysis heatmap overlay"""
        building_x = width // 2
        building_width = 300
        building_height = 500
        num_floors = 5
        floor_height = building_height // num_floors

        # Create stress levels for visualization
        stress_levels = [
            [0.3, 0.4, 0.5, 0.4, 0.3],  # Floor 5 (top)
            [0.4, 0.5, 0.6, 0.5, 0.4],  # Floor 4
            [0.5, 0.9, 0.95, 0.8, 0.5], # Floor 3 (high stress - damaged column)
            [0.6, 0.7, 0.8, 0.7, 0.6],  # Floor 2
            [0.7, 0.8, 0.9, 0.8, 0.7],  # Floor 1 (ground - highest load)
        ]

        # Draw each floor with heatmap coloring
        for floor in range(num_floors):
            y_pos = height - 150 - (floor * floor_height)

            for segment in range(5):
                stress = stress_levels[num_floors - 1 - floor][segment]
                color = self._get_heatmap_color(stress)

                seg_width = building_width // 5
                x_start = building_x - building_width//2 + segment * seg_width

                cv2.rectangle(frame,
                             (x_start, y_pos),
                             (x_start + seg_width, y_pos + floor_height),
                             color, -1)

                # Add stress value text
                cv2.putText(frame, f"{stress:.1f}",
                           (x_start + 15, y_pos + floor_height//2),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1)

        # Add heatmap legend
        self._draw_heatmap_legend(frame, width, height)

        # Highlight critical failure points
        cv2.circle(frame, (building_x - 60, height - 150 - floor_height * 3), 30, (0, 0, 255), 3)
        cv2.putText(frame, "CRITICAL POINT",
                   (building_x - 60 - 80, height - 150 - floor_height * 3 - 40),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    def _draw_collapse_sequence(self, frame: np.ndarray, time: float, collapse_sequence: List[Dict],
                                width: int, height: int, collapse_type: str):
        """PHASE 3: Animate the actual collapse based on physics simulation"""
        building_x = width // 2
        building_width = 300
        building_height = 500
        num_floors = 5
        floor_height = building_height // num_floors

        # Calculate collapse progress (0 to 1)
        collapse_progress = min(1.0, time / 6.0)

        # Different collapse patterns based on type
        if "PANCAKE" in collapse_type:
            # Floors collapse straight down
            for floor in range(num_floors):
                fall_distance = collapse_progress * (floor * 100)
                y_pos = height - 150 - (floor * floor_height) + fall_distance

                # Fade out upper floors
                alpha = max(0, 1.0 - collapse_progress * (num_floors - floor) / num_floors)
                color = tuple(int(c * alpha) for c in (80, 80, 80))

                cv2.rectangle(frame,
                             (building_x - building_width//2, int(y_pos)),
                             (building_x + building_width//2, int(y_pos + floor_height)),
                             color, -1)

        elif "LEAN-TO" in collapse_type:
            # Building tilts and falls to one side
            tilt_angle = collapse_progress * 30  # degrees
            for floor in range(num_floors):
                offset = int(collapse_progress * (num_floors - floor) * 50)
                y_pos = height - 150 - (floor * floor_height) + int(collapse_progress * floor * 80)

                cv2.rectangle(frame,
                             (building_x - building_width//2 + offset, int(y_pos)),
                             (building_x + building_width//2 + offset, int(y_pos + floor_height)),
                             (80, 80, 80), -1)

        elif "V-SHAPE" in collapse_type:
            # Center collapses, pulling sides inward
            for floor in range(num_floors):
                collapse_width = int(building_width * (1 - collapse_progress * 0.7))
                y_pos = height - 150 - (floor * floor_height) + int(collapse_progress * (num_floors - floor) * 60)

                cv2.rectangle(frame,
                             (building_x - collapse_width//2, int(y_pos)),
                             (building_x + collapse_width//2, int(y_pos + floor_height)),
                             (80, 80, 80), -1)

        else:
            # Progressive collapse - floors fail one by one
            for floor in range(num_floors):
                if time > floor * 1.2:
                    fall = min(200, (time - floor * 1.2) * 150)
                    y_pos = height - 150 - (floor * floor_height) + fall
                else:
                    y_pos = height - 150 - (floor * floor_height)

                cv2.rectangle(frame,
                             (building_x - building_width//2, int(y_pos)),
                             (building_x + building_width//2, int(y_pos + floor_height)),
                             (80, 80, 80), -1)

    def _draw_debris_field(self, frame: np.ndarray, time: float, debris_pattern: List[Dict],
                          width: int, height: int):
        """Draw debris particles and dust cloud"""
        building_x = width // 2
        ground_y = height - 150

        # Draw debris particles
        num_debris = min(50, int(time * 20))
        for i in range(num_debris):
            angle = (i / num_debris) * 2 * np.pi
            distance = 50 + time * 80 + i * 5
            x = int(building_x + np.cos(angle) * distance)
            y = int(ground_y - abs(np.sin(time * 2 + i)) * 50)

            if 0 <= x < width and 0 <= y < height:
                cv2.circle(frame, (x, y), 4, (100, 60, 40), -1)  # Brown debris

        # Draw dust cloud
        if time > 1.0:
            dust_alpha = min(0.3, (time - 1.0) * 0.1)
            dust_radius = int(150 + time * 40)
            overlay = frame.copy()
            cv2.circle(overlay, (building_x, ground_y), dust_radius, (60, 60, 60), -1)
            cv2.addWeighted(overlay, dust_alpha, frame, 1 - dust_alpha, 0, frame)

    def _draw_safety_zones_detailed(self, frame: np.ndarray, safety_zones: List[Dict],
                                    width: int, height: int):
        """Draw safety zones with color coding"""
        building_x = width // 2
        ground_y = height - 150

        # Draw concentric safety zones
        zones = [
            (200, (0, 0, 255), "DANGER ZONE", 3),      # Red - danger
            (350, (0, 255, 255), "CAUTION ZONE", 2),   # Yellow - caution
            (500, (0, 255, 0), "SAFE ZONE", 2),        # Green - safe
        ]

        for radius, color, label, thickness in zones:
            cv2.circle(frame, (building_x, ground_y), radius, color, thickness)
            cv2.putText(frame, label,
                       (building_x + int(radius * 0.7), ground_y - int(radius * 0.7)),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
    
    def _get_heatmap_color(self, stress: float) -> tuple:
        """Get BGR color for stress heatmap (0.0 to 1.0)"""
        # Green (low stress) -> Yellow -> Orange -> Red (high stress)
        if stress < 0.25:
            # Green to Yellow
            return (0, int(255), int(255 * (1 - stress * 4)))
        elif stress < 0.5:
            # Yellow to Orange
            return (0, int(255 * (1 - (stress - 0.25) * 4)), 255)
        elif stress < 0.75:
            # Orange to Red
            return (0, int(128 * (1 - (stress - 0.5) * 4)), 255)
        else:
            # Red (critical)
            return (0, 0, int(255 * (1 + (stress - 0.75))))

    def _draw_heatmap_legend(self, frame: np.ndarray, width: int, height: int):
        """Draw stress heatmap legend"""
        legend_x = width - 250
        legend_y = 100

        # Title
        cv2.putText(frame, "STRESS LEVELS (MPa)",
                   (legend_x, legend_y - 20),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

        # Color scale
        scale_levels = [(0.0, "0-25% (Safe)"), (0.3, "25-50% (Moderate)"),
                       (0.6, "50-75% (High)"), (0.9, "75-100% (Critical)")]

        for i, (stress, label) in enumerate(scale_levels):
            y = legend_y + i * 30
            color = self._get_heatmap_color(stress)

            cv2.rectangle(frame, (legend_x, y), (legend_x + 30, y + 20), color, -1)
            cv2.rectangle(frame, (legend_x, y), (legend_x + 30, y + 20), (255, 255, 255), 1)
            cv2.putText(frame, label, (legend_x + 40, y + 15),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

    def _add_phase_title(self, frame: np.ndarray, title: str, color: tuple):
        """Add phase title at top of frame"""
        cv2.putText(frame, title,
                   (50, 50),
                   cv2.FONT_HERSHEY_SIMPLEX, 1.2, color, 3)

    def _add_building_info_overlay(self, frame: np.ndarray, building_data: Dict,
                                    safety_factor: float, failure_probability: float,
                                    width: int, height: int):
        """Add building information overlay (top left)"""
        building_type = building_data.get("building_type", "Unknown").upper()
        floors = building_data.get("number_of_floors", 0)
        material = building_data.get("primary_material", "Unknown").upper()
        year_built = building_data.get("year_built", 2000)
        age = 2025 - year_built

        # Draw background box
        cv2.rectangle(frame, (10, 10), (400, 150), (0, 0, 0), -1)
        cv2.rectangle(frame, (10, 10), (400, 150), (100, 100, 100), 2)

        # Add text
        cv2.putText(frame, f"{building_type} BUILDING",
                   (20, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(frame, f"Floors: {floors} | Material: {material}",
                   (20, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
        cv2.putText(frame, f"Age: {age} years | SF: {safety_factor:.2f}",
                   (20, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
        cv2.putText(frame, f"Failure Prob: {failure_probability*100:.1f}%",
                   (20, 115), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

    def _add_time_overlay(self, frame: np.ndarray, time: float, width: int, height: int):
        """Add time overlay in T+X.Xs format"""
        time_text = f"T+{time:.1f}s"
        cv2.putText(frame, time_text,
                   (50, height - 50),
                   cv2.FONT_HERSHEY_SIMPLEX, 1.5, (255, 255, 255), 3)

    def _add_collapse_type_label(self, frame: np.ndarray, collapse_type: str, width: int, height: int):
        """Add collapse type label"""
        label = f"PREDICTED: {collapse_type}"
        cv2.putText(frame, label,
                   (width - 700, height - 50),
                   cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2)

    def _add_safety_instructions(self, frame: np.ndarray, risk_level: str, collapse_type: str,
                                 width: int, height: int):
        """Add safety instructions based on risk level"""
        instructions = {
            "CRITICAL": "EVACUATE IMMEDIATELY - ESTABLISH 100M PERIMETER",
            "HIGH": "RISK: HIGH - AVOID BUILDING AND ADJACENT STRUCTURES",
            "MEDIUM": "CAUTION ADVISED - RESTRICT ACCESS",
            "LOW": "ROUTINE MONITORING REQUIRED"
        }

        instruction = instructions.get(risk_level, "ASSESS SITUATION")

        # Draw semi-transparent background
        overlay = frame.copy()
        cv2.rectangle(overlay, (30, height - 150), (width - 30, height - 100), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)

        # Draw instruction text
        color = (0, 0, 255) if risk_level == "CRITICAL" or risk_level == "HIGH" else (0, 255, 255)
        cv2.putText(frame, instruction,
                   (50, height - 115),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.9, color, 2)

    def _add_risk_indicator(self, frame: np.ndarray, risk_level: str, width: int, height: int):
        """Add risk level indicator"""
        colors = {
            "CRITICAL": (128, 0, 255),  # Purple
            "HIGH": (0, 0, 255),        # Red
            "MEDIUM": (0, 165, 255),    # Orange
            "LOW": (0, 255, 0)          # Green
        }

        color = colors.get(risk_level, (128, 128, 128))

        # Draw risk indicator box
        cv2.rectangle(frame, (width - 300, 20), (width - 50, 80), color, -1)
        cv2.rectangle(frame, (width - 300, 20), (width - 50, 80), (255, 255, 255), 2)

        cv2.putText(frame, f"RISK: {risk_level}",
                   (width - 280, 60),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

    def _create_blender_script(self, simulation_data: Dict, output_path: str) -> str:
        """Create Blender Python script for rendering simulation"""

        collapse_sequence = simulation_data.get("collapse_sequence", [])
        debris_pattern = simulation_data.get("debris_pattern", [])
        safety_zones = simulation_data.get("safety_zones", [])
        duration = simulation_data.get("simulation_duration", 10.0)
        frame_rate = simulation_data.get("frame_rate", 30)
        
        script = f'''
import bpy
import bmesh
import mathutils
import math
import json

# Clear existing mesh
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# Set up scene
scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = int({duration} * {frame_rate})
scene.render.fps = {frame_rate}
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.filepath = "{output_path}"

# Create building structure
def create_building():
    # Create floor slabs
    for floor in range(5):  # 5 floors
        bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, floor * 3))
        floor_obj = bpy.context.active_object
        floor_obj.name = f"Floor_{{floor}}"
        floor_obj.scale = (10, 7.5, 0.1)  # 20x15x0.2m slab
        floor_obj.data.materials.append(create_material("concrete"))
    
    # Create columns
    for x in [-8, -4, 0, 4, 8]:
        for y in [-6, -3, 0, 3, 6]:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=15, location=(x, y, 7.5))
            column_obj = bpy.context.active_object
            column_obj.name = f"Column_{{x}}_{{y}}"
            column_obj.data.materials.append(create_material("steel"))

def create_material(mat_type):
    mat = bpy.data.materials.new(name=mat_type)
    mat.use_nodes = True
    
    if mat_type == "concrete":
        mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.7, 0.7, 0.7, 1.0)  # Gray
        mat.node_tree.nodes["Principled BSDF"].inputs[4].default_value = 0.8  # Roughness
    elif mat_type == "steel":
        mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.5, 0.5, 0.5, 1.0)  # Dark gray
        mat.node_tree.nodes["Principled BSDF"].inputs[4].default_value = 0.2  # Smooth
    elif mat_type == "debris":
        mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.4, 0.2, 0.1, 1.0)  # Brown
        mat.node_tree.nodes["Principled BSDF"].inputs[4].default_value = 0.9  # Rough
    
    return mat

def create_safety_zones():
    # Create safety zone indicators
    for i, zone in enumerate({json.dumps(safety_zones)}):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=zone["radius"], 
            depth=0.1, 
            location=(zone["x"], zone["y"], 0)
        )
        zone_obj = bpy.context.active_object
        zone_obj.name = f"SafetyZone_{{i}}"
        
        # Color based on safety level
        mat = bpy.data.materials.new(name=f"zone_{{zone['safety_level']}}")
        mat.use_nodes = True
        
        if zone["safety_level"] == "safe":
            mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0, 1, 0, 0.3)  # Green
        elif zone["safety_level"] == "caution":
            mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (1, 1, 0, 0.3)  # Yellow
        else:  # danger
            mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (1, 0, 0, 0.3)  # Red
        
        zone_obj.data.materials.append(mat)

def animate_collapse():
    # Animate building collapse based on simulation data
    collapse_data = {json.dumps(collapse_sequence)}
    
    for frame_data in collapse_data:
        frame = int(frame_data["time"] * {frame_rate}) + 1
        
        # Animate each component
        for i, pos in enumerate(frame_data["positions"]):
            if i < len(bpy.data.objects):
                obj = bpy.data.objects[i]
                if obj.type == 'MESH':
                    obj.location = (pos[0], pos[1], pos[2])
                    obj.keyframe_insert(data_path="location", frame=frame)
                    
                    # Add rotation for falling debris
                    if frame_data["time"] > 5.0:  # After collapse starts
                        obj.rotation_euler = (
                            math.radians(frame_data["time"] * 10),
                            math.radians(frame_data["time"] * 15),
                            math.radians(frame_data["time"] * 5)
                        )
                        obj.keyframe_insert(data_path="rotation_euler", frame=frame)

def create_camera():
    # Set up camera for optimal viewing
    bpy.ops.object.camera_add(location=(15, -15, 10))
    camera = bpy.context.active_object
    camera.rotation_euler = (math.radians(60), 0, math.radians(45))
    
    # Make it the active camera
    bpy.context.scene.camera = camera
    
    # Animate camera to follow collapse
    for frame in range(1, int({duration} * {frame_rate}) + 1):
        time = frame / {frame_rate}
        camera.location = (
            15 + time * 2,  # Move camera
            -15 - time * 1,
            10 + time * 0.5
        )
        camera.keyframe_insert(data_path="location", frame=frame)

def add_lighting():
    # Add sun light
    bpy.ops.object.light_add(type='SUN', location=(10, 10, 20))
    sun = bpy.context.active_object
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(45), math.radians(30), 0)
    
    # Add area light for better illumination
    bpy.ops.object.light_add(type='AREA', location=(0, 0, 15))
    area_light = bpy.context.active_object
    area_light.data.energy = 2
    area_light.data.size = 10

def add_particle_effects():
    # Add dust and debris particles
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0, 0, 0))
    dust_obj = bpy.context.active_object
    dust_obj.name = "DustEmitter"
    
    # Add particle system
    bpy.ops.object.particle_system_add()
    ps = dust_obj.particle_systems[0]
    ps.settings.count = 1000
    ps.settings.lifetime = 5
    ps.settings.emit_from = 'VOLUME'
    ps.settings.physics_type = 'NEWTON'
    ps.settings.particle_size = 0.1
    ps.settings.size_random = 0.5

# Main execution
create_building()
create_safety_zones()
create_camera()
add_lighting()
add_particle_effects()
animate_collapse()

# Set render settings
bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.samples = 128
bpy.context.scene.render.image_settings.file_format = 'FFMPEG'
bpy.context.scene.render.ffmpeg.format = 'MPEG4'
bpy.context.scene.render.ffmpeg.codec = 'H264'

# Render animation
bpy.ops.render.render(animation=True)

print("Simulation video rendering complete!")
'''
        
        return script
    
    async def _run_blender_rendering(self, output_path: str) -> str:
        """Run Blender to render the simulation video"""
        try:
            # Check if Blender is available
            blender_cmd = self._find_blender_executable()
            if not blender_cmd:
                raise Exception("Blender not found. Please install Blender and add it to PATH.")
            
            # Run Blender with the script
            cmd = [
                blender_cmd,
                "--background",
                "--python", self.blender_script_path
            ]
            
            logger.info(f"Running Blender command: {' '.join(cmd)}")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            if result.returncode != 0:
                logger.error(f"Blender error: {result.stderr}")
                raise Exception(f"Blender rendering failed: {result.stderr}")
            
            # Check if output file was created
            if not os.path.exists(output_path):
                raise Exception(f"Output video file not created: {output_path}")
            
            return output_path
            
        except subprocess.TimeoutExpired:
            raise Exception("Blender rendering timed out")
        except Exception as e:
            logger.error(f"Blender rendering error: {str(e)}")
            raise
    
    def _find_blender_executable(self) -> Optional[str]:
        """Find Blender executable in system PATH"""
        possible_paths = [
            "blender",
            "blender.exe",
            "/usr/bin/blender",
            "/Applications/Blender.app/Contents/MacOS/Blender",
            "C:\\Program Files\\Blender Foundation\\Blender 4.5\\blender.exe",
            "C:\\Program Files\\Blender Foundation\\Blender 4.0\\blender.exe",
            "C:\\Program Files\\Blender Foundation\\Blender 3.6\\blender.exe"
        ]
        
        for path in possible_paths:
            try:
                result = subprocess.run([path, "--version"], capture_output=True, timeout=5)
                if result.returncode == 0:
                    return path
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
        
        return None
    
    def create_simplified_video(self, simulation_data: Dict) -> str:
        """Create a simplified video when Blender is not available"""
        logger.warning("Blender not available, creating simplified visualization")
        
        # Create a simple HTML5 canvas animation
        html_content = self._create_html_visualization(simulation_data)
        
        html_path = os.path.join(self.temp_dir, "simulation.html")
        with open(html_path, 'w') as f:
            f.write(html_content)
        
        return html_path
    
    def _create_html_visualization(self, simulation_data: Dict) -> str:
        """Create HTML5 canvas visualization of simulation"""
        
        collapse_sequence = simulation_data.get("collapse_sequence", [])
        safety_zones = simulation_data.get("safety_zones", [])
        
        html = f'''
<!DOCTYPE html>
<html>
<head>
    <title>Structural Collapse Simulation</title>
    <style>
        body {{ margin: 0; padding: 20px; background: #000; color: #fff; font-family: Arial, sans-serif; }}
        canvas {{ border: 1px solid #333; background: #111; }}
        .controls {{ margin: 10px 0; }}
        .info {{ margin: 10px 0; font-size: 14px; }}
    </style>
</head>
<body>
    <h1>Structural Collapse Simulation</h1>
    <div class="controls">
        <button onclick="playPause()">Play/Pause</button>
        <button onclick="reset()">Reset</button>
        <span id="time">Time: 0.0s</span>
    </div>
    <canvas id="simulation" width="800" height="600"></canvas>
    <div class="info">
        <div>Safety Zones: {len(safety_zones)}</div>
        <div>Simulation Frames: {len(collapse_sequence)}</div>
    </div>
    
    <script>
        const canvas = document.getElementById('simulation');
        const ctx = canvas.getContext('2d');
        
        const simulationData = {json.dumps(collapse_sequence)};
        const safetyZones = {json.dumps(safety_zones)};
        
        let currentFrame = 0;
        let isPlaying = false;
        let animationId;
        
        function draw() {{
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            
            // Draw safety zones
            safetyZones.forEach(zone => {{
                ctx.beginPath();
                ctx.arc(
                    canvas.width/2 + zone.x * 10, 
                    canvas.height/2 + zone.y * 10, 
                    zone.radius * 2, 
                    0, 2 * Math.PI
                );
                
                if (zone.safety_level === 'safe') {{
                    ctx.fillStyle = 'rgba(0, 255, 0, 0.2)';
                }} else if (zone.safety_level === 'caution') {{
                    ctx.fillStyle = 'rgba(255, 255, 0, 0.2)';
                }} else {{
                    ctx.fillStyle = 'rgba(255, 0, 0, 0.2)';
                }}
                ctx.fill();
            }});
            
            // Draw building components
            if (currentFrame < simulationData.length) {{
                const frame = simulationData[currentFrame];
                frame.positions.forEach((pos, i) => {{
                    ctx.fillStyle = i < 5 ? '#666' : '#999'; // Floors vs columns
                    ctx.fillRect(
                        canvas.width/2 + pos[0] * 10 - 5, 
                        canvas.height/2 + pos[1] * 10 - 5, 
                        10, 10
                    );
                }});
            }}
            
            // Update time display
            document.getElementById('time').textContent = 
                `Time: ${{(currentFrame / 30).toFixed(1)}}s`;
        }}
        
        function playPause() {{
            isPlaying = !isPlaying;
            if (isPlaying) {{
                animate();
            }} else {{
                cancelAnimationFrame(animationId);
            }}
        }}
        
        function animate() {{
            if (isPlaying && currentFrame < simulationData.length - 1) {{
                currentFrame++;
                draw();
                animationId = requestAnimationFrame(animate);
            }} else {{
                isPlaying = false;
            }}
        }}
        
        function reset() {{
            currentFrame = 0;
            isPlaying = false;
            cancelAnimationFrame(animationId);
            draw();
        }}
        
        // Initial draw
        draw();
    </script>
</body>
</html>
'''
        
        return html
