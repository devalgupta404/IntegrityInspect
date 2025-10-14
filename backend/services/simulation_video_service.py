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
            
            # Run Blender to generate video
            video_path = await self._run_blender_rendering(output_path)
            
            logger.info(f"Simulation video generated: {video_path}")
            return video_path
            
        except Exception as e:
            logger.error(f"Video generation error: {str(e)}")
            raise Exception(f"Failed to generate simulation video: {str(e)}")
    
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
            "C:\\Program Files\\Blender Foundation\\Blender 4.0\\blender.exe"
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
