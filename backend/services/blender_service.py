"""
Blender Integration Service for Physics-Based Structural Collapse Simulation
Converts assessment data to Blender format and generates high-quality 3D videos
"""

import json
import os
import subprocess
import tempfile
import logging
from typing import Dict, List, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

class BlenderService:
    """Service for generating physics-based collapse simulations using Blender"""

    def __init__(self):
        self.blender_path = self._find_blender_executable()
        self.temp_dir = tempfile.mkdtemp()

    def _find_blender_executable(self) -> Optional[str]:
        """Find Blender executable on the system"""
        possible_paths = [
            "blender",
            "blender.exe",
            "/usr/bin/blender",
            "/usr/local/bin/blender",
            "/Applications/Blender.app/Contents/MacOS/Blender",
            r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe",
            r"C:\Program Files\Blender Foundation\Blender 4.0\blender.exe",
            r"C:\Program Files\Blender Foundation\Blender 3.6\blender.exe",
            r"C:\Program Files\Blender Foundation\Blender 3.3\blender.exe",
        ]

        for path in possible_paths:
            try:
                result = subprocess.run(
                    [path, "--version"],
                    capture_output=True,
                    timeout=5,
                    text=True
                )
                if result.returncode == 0:
                    logger.info(f"Found Blender at: {path}")
                    logger.info(f"Blender version: {result.stdout.split()[0]}")
                    return path
            except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
                continue

        logger.warning("Blender not found on system")
        return None

    def is_available(self) -> bool:
        """Check if Blender is available"""
        return self.blender_path is not None

    async def generate_simulation_video(
        self,
        building_data: Dict,
        annotations: List[Dict],
        fea_results: Dict,
        collapse_simulation: Dict,
        output_path: str
    ) -> str:
        """
        Generate physics-based simulation video using Blender

        Args:
            building_data: Building parameters (type, floors, material, age, etc.)
            annotations: List of damage annotations with coordinates
            fea_results: Finite element analysis results
            collapse_simulation: Collapse simulation data from PyChrono
            output_path: Path to save the generated video

        Returns:
            Path to generated video file
        """
        if not self.is_available():
            raise Exception("Blender is not available. Please install Blender.")

        try:
            logger.info("Preparing data for Blender...")

            # Convert our data format to Blender-compatible format
            blender_data = self._convert_to_blender_format(
                building_data,
                annotations,
                fea_results,
                collapse_simulation
            )

            # Save data to JSON file
            data_file = os.path.join(self.temp_dir, "simulation_data.json")
            with open(data_file, 'w') as f:
                json.dump(blender_data, f, indent=2)

            logger.info(f"Saved simulation data to: {data_file}")

            # Generate Blender Python script
            script_content = self._generate_blender_script(data_file, output_path)
            script_file = os.path.join(self.temp_dir, "blender_script.py")

            with open(script_file, 'w') as f:
                f.write(script_content)

            logger.info(f"Generated Blender script: {script_file}")

            # Run Blender
            return await self._run_blender(script_file, output_path)

        except Exception as e:
            logger.error(f"Blender video generation failed: {str(e)}")
            raise

    def _convert_to_blender_format(
        self,
        building_data: Dict,
        annotations: List[Dict],
        fea_results: Dict,
        collapse_simulation: Dict
    ) -> Dict:
        """Convert our data format to Blender-compatible format"""

        # Extract building parameters
        building_type = building_data.get("building_type", "residential")
        floors = building_data.get("number_of_floors", 5)
        material = building_data.get("primary_material", "concrete")
        year_built = building_data.get("year_built", 2000)
        age = 2025 - year_built

        # Calculate building dimensions based on type
        if building_type == "residential":
            length, width = 20.0, 15.0
        elif building_type == "commercial":
            length, width = 30.0, 25.0
        elif building_type == "industrial":
            length, width = 40.0, 30.0
        else:
            length, width = 20.0, 15.0

        # Convert annotations to Blender damage locations
        damage_locations = []
        for ann in annotations:
            position = ann.get("position", {})
            issue_type = ann.get("issueType", "unknown")

            # Normalize coordinates (assuming image coords are 0-1024)
            # Convert to 3D building coordinates
            x = (position.get("x", 512) / 1024.0 - 0.5) * length
            y = (position.get("y", 512) / 1024.0 - 0.5) * width
            z = (position.get("y", 512) / 1024.0) * (floors * 3.0)  # Height based on y coord

            damage_locations.append({
                "position": {"x": x, "y": y, "z": z},
                "type": issue_type,
                "severity": self._get_damage_severity(issue_type),
                "description": ann.get("description", "")
            })

        # Extract collapse sequence from simulation
        collapse_sequence = collapse_simulation.get("collapse_sequence", [])
        failure_time = collapse_simulation.get("failure_time", 5.0)

        # Get safety factor and failure probability
        safety_factor = fea_results.get("safety_factor", 1.0)
        failure_probability = fea_results.get("failure_probability", 0.5)

        return {
            "building": {
                "type": building_type,
                "floors": floors,
                "material": material,
                "age": age,
                "dimensions": {
                    "length": length,
                    "width": width,
                    "height": floors * 3.0,
                    "floor_height": 3.0
                }
            },
            "damage": {
                "locations": damage_locations,
                "types": building_data.get("damage_types", []),
                "description": building_data.get("damage_description", "")
            },
            "analysis": {
                "safety_factor": safety_factor,
                "failure_probability": failure_probability,
                "failure_time": failure_time,
                "critical_points": fea_results.get("critical_points", [])
            },
            "simulation": {
                "collapse_sequence": collapse_sequence[:100],  # Limit to 100 frames
                "duration": 5.0,  # Reduced to 5 seconds for faster rendering
                "fps": 30
            }
        }

    def _get_damage_severity(self, issue_type: str) -> float:
        """Get damage severity multiplier (0.0 to 1.0)"""
        severity_map = {
            "crack": 0.3,
            "cracks": 0.3,
            "tilting": 0.6,
            "partial_collapse": 0.9,
            "foundation_issues": 0.8,
            "column_damage": 0.7,
            "wall_damage": 0.5,
            "deformation": 0.4,
            "spalling": 0.3,
            "corrosion": 0.4,
            "roof_damage": 0.5
        }
        return severity_map.get(issue_type.lower(), 0.5)

    def _generate_blender_script(self, data_file: str, output_path: str) -> str:
        """Generate Blender Python script"""

        # Use forward slashes for paths (works on Windows and Unix)
        data_file = data_file.replace("\\", "/")
        output_path = output_path.replace("\\", "/")

        script = f'''
import bpy
import json
import math
import mathutils
from pathlib import Path

# Load simulation data
with open("{data_file}", "r") as f:
    data = json.load(f)

# Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# Scene setup
scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = int(data["simulation"]["duration"] * data["simulation"]["fps"])
scene.render.fps = data["simulation"]["fps"]
# Use lower resolution for faster rendering (720p)
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100

# Set output path
output_file = "{output_path}"
output_dir = Path(output_file).parent
output_dir.mkdir(parents=True, exist_ok=True)

# For animation, Blender needs the path without extension
# It will add the extension based on format
scene.render.filepath = str(Path(output_file).with_suffix(''))

# Material definitions
def create_material(name, color, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

# Create materials
concrete_mat = create_material("Concrete", (0.7, 0.7, 0.7, 1.0), 0.0, 0.8)
steel_mat = create_material("Steel", (0.5, 0.5, 0.5, 1.0), 1.0, 0.2)
damaged_mat = create_material("Damaged", (0.8, 0.2, 0.1, 1.0), 0.0, 0.9)

# Building parameters
building = data["building"]
floors = building["floors"]
length = building["dimensions"]["length"]
width = building["dimensions"]["width"]
floor_height = building["dimensions"]["floor_height"]

# Create building structure
components = []

# Create floor slabs
for floor in range(floors):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, floor * floor_height))
    floor_obj = bpy.context.active_object
    floor_obj.name = f"Floor_{{floor}}"
    floor_obj.scale = (length / 2, width / 2, 0.1)
    floor_obj.data.materials.append(concrete_mat)
    components.append(floor_obj)

# Create columns (4x4 grid)
column_spacing = 5.0
for i in range(-1, 2):
    for j in range(-1, 2):
        x = i * column_spacing
        y = j * column_spacing
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.3,
            depth=floors * floor_height,
            location=(x, y, (floors * floor_height) / 2)
        )
        column_obj = bpy.context.active_object
        column_obj.name = f"Column_{{i}}_{{j}}"
        column_obj.data.materials.append(steel_mat)
        components.append(column_obj)

# Apply damage to components
damage_locations = data["damage"]["locations"]
for damage in damage_locations:
    pos = damage["position"]
    severity = damage["severity"]

    # Find closest component
    closest_comp = None
    min_dist = float('inf')

    for comp in components:
        loc = comp.location
        dist = math.sqrt((loc.x - pos["x"])**2 + (loc.y - pos["y"])**2 + (loc.z - pos["z"])**2)
        if dist < min_dist:
            min_dist = dist
            closest_comp = comp

    if closest_comp and min_dist < 5.0:
        # Apply damage material
        if len(closest_comp.data.materials) > 0:
            closest_comp.data.materials[0] = damaged_mat

        # Reduce scale slightly to show damage
        closest_comp.scale *= (1.0 - severity * 0.3)

# Animate collapse
failure_time = data["analysis"]["failure_time"]
failure_frame = int(failure_time * data["simulation"]["fps"])

# Set keyframes for collapse
for comp in components:
    # Initial position (frame 1)
    comp.keyframe_insert(data_path="location", frame=1)
    comp.keyframe_insert(data_path="rotation_euler", frame=1)

    # Start collapse at failure_frame
    if "Floor" in comp.name:
        floor_num = int(comp.name.split("_")[1])
        # Floors fall progressively
        fall_delay = floor_num * 5
        fall_frame = failure_frame + fall_delay

        comp.location.z -= (floors - floor_num) * floor_height * 0.8
        comp.rotation_euler.x += math.radians(10)
        comp.keyframe_insert(data_path="location", frame=fall_frame + 30)
        comp.keyframe_insert(data_path="rotation_euler", frame=fall_frame + 30)

    elif "Column" in comp.name:
        # Columns fail and tilt
        comp.location.z -= floor_height * 0.5
        comp.rotation_euler.x += math.radians(45)
        comp.rotation_euler.y += math.radians(30)
        comp.keyframe_insert(data_path="location", frame=failure_frame + 20)
        comp.keyframe_insert(data_path="rotation_euler", frame=failure_frame + 20)

# Add camera
bpy.ops.object.camera_add(location=(length * 1.5, -width * 1.5, floors * floor_height * 0.8))
camera = bpy.context.active_object
camera.rotation_euler = (math.radians(65), 0, math.radians(45))
scene.camera = camera

# Animate camera to follow collapse
camera.location.z *= 0.7
camera.keyframe_insert(data_path="location", frame=failure_frame + 60)

# Lighting setup
# Sun light
bpy.ops.object.light_add(type='SUN', location=(10, 10, 20))
sun = bpy.context.active_object
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(45), math.radians(30), 0)

# Area light for fill
bpy.ops.object.light_add(type='AREA', location=(0, 0, floors * floor_height + 5))
area_light = bpy.context.active_object
area_light.data.energy = 500
area_light.data.size = 15

# Add ground plane
bpy.ops.mesh.primitive_plane_add(size=100, location=(0, 0, -0.5))
ground = bpy.context.active_object
ground_mat = create_material("Ground", (0.3, 0.4, 0.3, 1.0), 0.0, 0.9)
ground.data.materials.append(ground_mat)

# Render settings - use EEVEE_NEXT for faster rendering (real-time engine)
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples = 16  # Reduce samples for speed
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'HIGH'
scene.render.ffmpeg.ffmpeg_preset = 'GOOD'

# EEVEE uses GPU automatically, no additional configuration needed

print("Starting render...")
print(f"Output will be saved to: {{scene.render.filepath}}")

# Render animation
bpy.ops.render.render(animation=True, write_still=True)

print("Render complete!")
'''

        return script

    async def _run_blender(self, script_file: str, output_path: str) -> str:
        """Run Blender with the generated script"""

        try:
            logger.info(f"Running Blender in background mode...")
            logger.info(f"Script: {script_file}")
            logger.info(f"Output: {output_path}")

            cmd = [
                self.blender_path,
                "--background",
                "--python", script_file
            ]

            logger.info(f"Command: {' '.join(cmd)}")

            # Run Blender with extended timeout
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=600  # 10 minute timeout
            )

            # Log output
            if result.stdout:
                logger.info(f"Blender stdout: {result.stdout[-500:]}")  # Last 500 chars
            if result.stderr:
                logger.warning(f"Blender stderr: {result.stderr[-500:]}")

            if result.returncode != 0:
                raise Exception(f"Blender rendering failed with code {result.returncode}")

            # Check if output file was created
            output_dir = Path(output_path).parent
            output_name = Path(output_path).stem

            # Blender creates files with format: name.mp4 (no frame numbers for video output)
            expected_output = str(Path(output_path).with_suffix('.mp4'))

            # Also check for files with frame numbers (name0001-0300.mp4)
            possible_outputs = [
                expected_output,
                *list(output_dir.glob(f"{output_name}*.mp4"))
            ]

            final_output = None
            for path in possible_outputs:
                if os.path.exists(path):
                    final_output = path
                    break

            if not final_output:
                logger.error(f"Output directory contents: {list(output_dir.glob('*'))}")
                raise Exception(f"Output video file not created: {output_path}")

            logger.info(f"Blender rendering complete: {final_output}")
            return str(final_output)

        except subprocess.TimeoutExpired:
            raise Exception("Blender rendering timed out (10 minutes)")
        except Exception as e:
            logger.error(f"Blender execution error: {str(e)}")
            raise

    async def test_blender(self) -> bool:
        """Test if Blender is working correctly"""

        if not self.is_available():
            logger.error("Blender not available")
            return False

        try:
            logger.info("Testing Blender installation...")

            # Create simple test script
            test_script = os.path.join(self.temp_dir, "test_blender.py")
            test_output = os.path.join(self.temp_dir, "test_render.png")

            with open(test_script, 'w') as f:
                f.write(f'''
import bpy

# Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# Add cube
bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0))

# Add light
bpy.ops.object.light_add(type='SUN', location=(5, 5, 5))

# Add camera
bpy.ops.object.camera_add(location=(5, -5, 5))
camera = bpy.context.active_object
camera.rotation_euler = (1.1, 0, 0.8)
bpy.context.scene.camera = camera

# Render settings
bpy.context.scene.render.filepath = "{test_output.replace(chr(92), '/')}"
bpy.context.scene.render.resolution_x = 640
bpy.context.scene.render.resolution_y = 480

# Render
bpy.ops.render.render(write_still=True)
print("Test render complete!")
''')

            # Run test
            result = subprocess.run(
                [self.blender_path, "--background", "--python", test_script],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode == 0 and os.path.exists(test_output):
                logger.info("✅ Blender test passed!")
                return True
            else:
                logger.error(f"❌ Blender test failed: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"❌ Blender test error: {str(e)}")
            return False
