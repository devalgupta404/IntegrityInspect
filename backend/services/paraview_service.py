

import json
import os
import subprocess
import tempfile
import logging
from typing import Dict, List, Optional
from pathlib import Path
import numpy as np

logger = logging.getLogger(__name__)

class ParaViewService:


    def __init__(self, openai_client=None):
        self.paraview_path = self._find_paraview_executable()
        self.temp_dir = tempfile.mkdtemp()
        self.openai_client = openai_client

    def _find_paraview_executable(self) -> Optional[str]:

        possible_paths = [
            "pvpython",
            "pvpython.exe",
            "/usr/bin/pvpython",
            "/usr/local/bin/pvpython",
            r"C:\Program Files\ParaView 5.11.0\bin\pvpython.exe",
            r"C:\Program Files\ParaView 5.12.0\bin\pvpython.exe",
            r"C:\Program Files\ParaView\bin\pvpython.exe",
            r"C:\ParaView\bin\pvpython.exe",
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
                    logger.info(f"Found ParaView at: {path}")
                    logger.info(f"ParaView version: {result.stdout.strip()}")
                    return path
            except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
                continue

        logger.warning("ParaView not found on system - using VTK standalone")
        return "python" 

    def is_available(self) -> bool:

        try:
            import vtk
            return True
        except ImportError:
            return False

    async def generate_simulation_video(
        self,
        building_data: Dict,
        annotations: List[Dict],
        fea_results: Dict,
        collapse_simulation: Dict,
        output_path: str
    ) -> str:

        if not self.is_available():
            raise Exception("VTK/ParaView is not available. Please install: pip install vtk")

        try:
            logger.info("Preparing data for ParaView/VTK simulation...")


            simulation_instructions = await self._generate_simulation_instructions(
                building_data,
                annotations,
                fea_results,
                collapse_simulation
            )

            logger.info(f"GPT-5 simulation instructions: {simulation_instructions[:200]}...")


            vtk_data = self._convert_to_vtk_format(
                building_data,
                annotations,
                fea_results,
                collapse_simulation,
                simulation_instructions
            )

            vtk_files = self._save_vtk_datasets(vtk_data)

            logger.info(f"Saved {len(vtk_files)} VTK datasets")

            script_content = self._generate_paraview_script(
                vtk_files,
                output_path,
                simulation_instructions,
                vtk_data
            )
            script_file = os.path.join(self.temp_dir, "paraview_simulation.py")

            with open(script_file, 'w', encoding='utf-8') as f:
                f.write(script_content)

            logger.info(f"Generated ParaView script: {script_file}")


            return await self._run_paraview(script_file, output_path)

        except Exception as e:
            logger.error(f"ParaView video generation failed: {str(e)}")
            raise

    async def _generate_simulation_instructions(
        self,
        building_data: Dict,
        annotations: List[Dict],
        fea_results: Dict,
        collapse_simulation: Dict
    ) -> str:

        if not self.openai_client:
            logger.warning("OpenAI client not available, using default instructions")
            return self._get_default_simulation_instructions(building_data, annotations)

        try:

            building_type = building_data.get('building_type', 'residential')
            floors = building_data.get('number_of_floors', 5)
            material = building_data.get('primary_material', 'concrete')
            age = 2025 - building_data.get('year_built', 2000)
            damage_types = building_data.get('damage_types', [])
            damage_desc = building_data.get('damage_description', 'Multiple structural issues')

            annotation_details = []
            for i, ann in enumerate(annotations[:5]):  
                annotation_details.append(
                    f"  Location {i+1}: {ann.get('issueType', 'unknown')} at "
                    f"({ann.get('position', {}).get('x', 0):.1f}, {ann.get('position', {}).get('y', 0):.1f}) - "
                    f"{ann.get('description', 'No description')}"
                )

            prompt = f"""You are a senior structural engineer specializing in collapse analysis and failure prediction. Analyze this building comprehensively and provide detailed simulation instructions.

===========================================================
BUILDING SPECIFICATIONS:
===========================================================
Type: {building_type.upper()}
Number of Floors: {floors}
Primary Material: {material.upper()}
Year Built: {building_data.get('year_built', 2000)}
Current Age: {age} years
Location: {building_data.get('latitude', 'N/A')}, {building_data.get('longitude', 'N/A')}

===========================================================
DAMAGE ASSESSMENT:
===========================================================
Damage Types Identified: {', '.join(damage_types) if damage_types else 'Multiple issues'}
Description: {damage_desc}

Damage Locations ({len(annotations)} total):
{chr(10).join(annotation_details) if annotation_details else '  No specific locations marked'}

===========================================================
STRUCTURAL ANALYSIS RESULTS:
===========================================================
Safety Factor: {fea_results.get('safety_factor', 1.0):.2f} (1.0 = critical threshold)
Failure Probability: {fea_results.get('failure_probability', 0.5)*100:.1f}%
Critical Stress Points: {len(fea_results.get('critical_points', []))}
Predicted Failure Time: {collapse_simulation.get('failure_time', 5.0):.1f} seconds

===========================================================
REQUIRED SIMULATION DETAILS:
===========================================================
Provide a comprehensive, technically accurate analysis for 3D visualization:

1. COLLAPSE MECHANISM (be specific):
   - Primary failure mode: [Pancake / Progressive / Lean-To / V-Shape / Combination]
   - Why this mechanism occurs for THIS specific building
   - Initiating failure point(s)

2. FAILURE SEQUENCE (step-by-step, 0-10 seconds):
   - T+0s to T+2s: What fails first and why
   - T+2s to T+5s: Propagation of failure
   - T+5s to T+10s: Final collapse state
   - Consider: {material} degradation, {floors}-floor weight distribution, {age} years of aging

3. STRUCTURAL ELEMENTS (prioritize by failure order):
   - Which columns fail first (exterior, interior, corner?)
   - Floor slab behavior (crack, separate, pancake?)
   - Wall failure patterns
   - Foundation response

4. VISUAL INDICATORS for simulation:
   - Color coding: Initial damage (yellow), high stress (orange), failure (red)
   - Displacement magnitude ranges
   - Crack propagation paths
   - Debris trajectory patterns

5. CAMERA CHOREOGRAPHY (for dramatic effect):
   - Starting angle and height
   - Movement during collapse
   - Key moments to focus on
   - Final overview position

6. RISK ASSESSMENT TEXT (for overlay):
   - Risk Level: [LOW / MEDIUM / HIGH / CRITICAL]
   - Immediate Action Required
   - Safety Perimeter Distance
   - Evacuation Recommendation

7. BUILDING-SPECIFIC CHARACTERISTICS:
   - How does a {floors}-floor {building_type} building typically fail?
   - {material} behavior under stress
   - Age-related degradation effects ({age} years old)
   - Typical {building_type} vulnerabilities

8. REALISM FACTORS:
   - Dust cloud generation
   - Debris scatter pattern
   - Sound of collapse (for reference)
   - Time to complete collapse

Provide your analysis in clear, structured format. Be specific about numbers, timings, and technical details. This will guide a physics-based 3D simulation."""

            response = await self.openai_client.chat.completions.create(
                model="gpt-4o",  
                messages=[
                    {"role": "system", "content": "You are a senior structural engineer with 20+ years of experience in collapse analysis, finite element analysis, and structural failure prediction. Provide detailed, technically accurate guidance for physics-based simulations."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=2000,  
                temperature=0.4 
            )

            instructions = response.choices[0].message.content
            logger.info("Generated GPT-5 simulation instructions")
            return instructions

        except Exception as e:
            logger.error(f"Failed to generate GPT instructions: {str(e)}")
            return self._get_default_simulation_instructions(building_data, annotations)

    def _get_default_simulation_instructions(self, building_data: Dict, annotations: List[Dict]) -> str:
        """Fallback simulation instructions based on simple heuristics"""
        floors = building_data.get('number_of_floors', 5)
        material = building_data.get('primary_material', 'concrete')
        damage_types = building_data.get('damage_types', [])

        instructions = f"""Default Simulation Instructions:

1. Collapse Mechanism: Pancake collapse (progressive floor failure)
2. Initial Failure: Bottom floors due to accumulated stress
3. Progression: Floor-by-floor collapse from bottom to top
4. Camera: 45-degree angle, slowly zooming out
5. Visualization: Stress heatmap transitioning to displacement vectors
6. Highlight: Damaged columns and critical stress points"""

        return instructions

    def _convert_to_vtk_format(
        self,
        building_data: Dict,
        annotations: List[Dict],
        fea_results: Dict,
        collapse_simulation: Dict,
        simulation_instructions: str
    ) -> Dict:
        """Convert assessment data to VTK-compatible format"""


        building_type = building_data.get("building_type", "residential")
        floors = building_data.get("number_of_floors", 5)
        material = building_data.get("primary_material", "concrete")
        year_built = building_data.get("year_built", 2000)
        age = 2025 - year_built


        if building_type == "residential":
            length, width = 20.0, 15.0
        elif building_type == "commercial":
            length, width = 30.0, 25.0
        elif building_type == "industrial":
            length, width = 40.0, 30.0
        else:
            length, width = 20.0, 15.0

        floor_height = 3.0
        total_height = floors * floor_height


        mesh_data = self._create_structural_mesh(
            length, width, total_height, floors
        )


        damage_points = []
        for ann in annotations:
            pos = ann.get("position", {})
            issue_type = ann.get("issueType", "unknown")

            x = (pos.get("x", 512) / 1024.0 - 0.5) * length
            y = (pos.get("y", 512) / 1024.0 - 0.5) * width
            z = (pos.get("y", 512) / 1024.0) * total_height

            damage_points.append({
                "position": [x, y, z],
                "type": issue_type,
                "severity": self._get_damage_severity(issue_type),
                "description": ann.get("description", "")
            })


        collapse_sequence = collapse_simulation.get("collapse_sequence", [])
        failure_time = collapse_simulation.get("failure_time", 5.0)

        return {
            "building": {
                "type": building_type,
                "floors": floors,
                "material": material,
                "age": age,
                "dimensions": {
                    "length": length,
                    "width": width,
                    "height": total_height,
                    "floor_height": floor_height
                }
            },
            "mesh": mesh_data,
            "damage": {
                "points": damage_points,
                "types": building_data.get("damage_types", [])
            },
            "analysis": {
                "safety_factor": fea_results.get("safety_factor", 1.0),
                "failure_probability": fea_results.get("failure_probability", 0.5),
                "failure_time": failure_time,
                "critical_points": fea_results.get("critical_points", [])
            },
            "simulation": {
                "collapse_sequence": collapse_sequence[:200],
                "duration": 10.0,
                "fps": 30,
                "instructions": simulation_instructions
            }
        }

    def _create_structural_mesh(self, length: float, width: float, height: float, floors: int) -> Dict:
        """Create VTK structural mesh grid with realistic structural elements"""


        nx = max(8, min(15, int(length / 2)))  
        ny = max(8, min(15, int(width / 2)))   
        nz = floors * 4  

        points = []
        cells = []

        for k in range(nz + 1):
            for j in range(ny + 1):
                for i in range(nx + 1):
                    x = (i / nx - 0.5) * length
                    y = (j / ny - 0.5) * width
                    z = (k / nz) * height


                    if i > 0 and i < nx and j > 0 and j < ny and k > 0 and k < nz:
                        import random
                        random.seed(i * 1000 + j * 100 + k)  
                        x += random.uniform(-0.1, 0.1)
                        y += random.uniform(-0.1, 0.1)

                    points.append([x, y, z])

        for k in range(nz):
            for j in range(ny):
                for i in range(nx):

                    idx = i + j * (nx + 1) + k * (nx + 1) * (ny + 1)
                    cells.append([
                        idx,
                        idx + 1,
                        idx + 1 + (nx + 1),
                        idx + (nx + 1),
                        idx + (nx + 1) * (ny + 1),
                        idx + 1 + (nx + 1) * (ny + 1),
                        idx + 1 + (nx + 1) + (nx + 1) * (ny + 1),
                        idx + (nx + 1) + (nx + 1) * (ny + 1)
                    ])

        return {
            "points": points,
            "cells": cells,
            "dimensions": [nx + 1, ny + 1, nz + 1]
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

    def _save_vtk_datasets(self, vtk_data: Dict) -> List[str]:
        """Save VTK datasets to files"""
        vtk_files = []


        mesh_file = os.path.join(self.temp_dir, "structure_mesh.vtk")
        self._write_vtk_unstructured_grid(
            mesh_file,
            vtk_data["mesh"]["points"],
            vtk_data["mesh"]["cells"]
        )
        vtk_files.append(mesh_file)


        data_file = os.path.join(self.temp_dir, "simulation_data.json")
        with open(data_file, 'w') as f:
            json.dump(vtk_data, f, indent=2)
        vtk_files.append(data_file)

        return vtk_files

    def _write_vtk_unstructured_grid(self, filename: str, points: List, cells: List):
        """Write VTK unstructured grid file (legacy format)"""
        with open(filename, 'w') as f:

            f.write("# vtk DataFile Version 3.0\n")
            f.write("Structural mesh\n")
            f.write("ASCII\n")
            f.write("DATASET UNSTRUCTURED_GRID\n")


            f.write(f"POINTS {len(points)} float\n")
            for point in points:
                f.write(f"{point[0]} {point[1]} {point[2]}\n")

            total_size = sum(len(cell) + 1 for cell in cells)
            f.write(f"\nCELLS {len(cells)} {total_size}\n")
            for cell in cells:
                f.write(f"{len(cell)} " + " ".join(map(str, cell)) + "\n")

            f.write(f"\nCELL_TYPES {len(cells)}\n")
            for _ in cells:
                f.write("12\n")

        logger.info(f"Wrote VTK file: {filename}")

    def _generate_paraview_script(
        self,
        vtk_files: List[str],
        output_path: str,
        simulation_instructions: str,
        vtk_data: Dict
    ) -> str:
        """Generate Python script for ParaView/VTK visualization"""

        vtk_files_str = [f.replace("\\", "/") for f in vtk_files]
        output_path_fixed = output_path.replace("\\", "/")


        building = vtk_data["building"]
        simulation = vtk_data["simulation"]
        damage_points = vtk_data["damage"]["points"]

        script = f'''
import vtk
import json
import numpy as np
from pathlib import Path

# Load simulation data
with open("{vtk_files_str[1]}", "r") as f:
    sim_data = json.load(f)

# Video settings
width, height = 1280, 720
fps = {simulation["fps"]}
duration = {simulation["duration"]}
total_frames = int(duration * fps)

# Create renderer and render window
renderer = vtk.vtkRenderer()
render_window = vtk.vtkRenderWindow()
render_window.AddRenderer(renderer)
render_window.SetSize(width, height)
render_window.SetOffScreenRendering(1)

# Load structural mesh
reader = vtk.vtkUnstructuredGridReader()
reader.SetFileName("{vtk_files_str[0]}")
reader.Update()

# Create mapper and actor for structure
mapper = vtk.vtkDataSetMapper()
mapper.SetInputConnection(reader.GetOutputPort())

structure_actor = vtk.vtkActor()
structure_actor.SetMapper(mapper)

# Set building appearance based on material and type
building_type = sim_data["building"]["type"]
material = sim_data["building"]["material"]
age = sim_data["building"]["age"]

# Material-specific colors and properties
if material == "concrete":
    # Concrete: Gray with slight weathering based on age
    base_color = 0.7 - (age / 200.0)  # Darker with age
    structure_actor.GetProperty().SetColor(base_color, base_color, base_color + 0.05)
    structure_actor.GetProperty().SetOpacity(0.85)
elif material == "steel":
    # Steel: Metallic gray-blue
    structure_actor.GetProperty().SetColor(0.6, 0.65, 0.7)
    structure_actor.GetProperty().SetOpacity(0.75)
    structure_actor.GetProperty().SetMetallic(0.8)
    structure_actor.GetProperty().SetRoughness(0.3)
elif material == "brick":
    # Brick: Reddish-brown
    structure_actor.GetProperty().SetColor(0.7, 0.4, 0.3)
    structure_actor.GetProperty().SetOpacity(0.9)
elif material == "wood":
    # Wood: Brown tones
    structure_actor.GetProperty().SetColor(0.6, 0.45, 0.3)
    structure_actor.GetProperty().SetOpacity(0.8)
else:
    # Default: neutral gray
    structure_actor.GetProperty().SetColor(0.7, 0.7, 0.7)
    structure_actor.GetProperty().SetOpacity(0.8)

# Building type affects visual style
if building_type == "commercial":
    # Commercial buildings: cleaner, more uniform
    structure_actor.GetProperty().SetSpecular(0.3)
    structure_actor.GetProperty().SetSpecularPower(20)
elif building_type == "industrial":
    # Industrial: rougher appearance
    structure_actor.GetProperty().SetSpecular(0.1)
    structure_actor.GetProperty().SetSpecularPower(5)
else:  # residential
    # Residential: moderate specular
    structure_actor.GetProperty().SetSpecular(0.2)
    structure_actor.GetProperty().SetSpecularPower(10)

renderer.AddActor(structure_actor)

# Add damage markers
damage_points = {json.dumps(damage_points)}
for damage in damage_points:
    sphere = vtk.vtkSphereSource()
    sphere.SetCenter(damage["position"])
    sphere.SetRadius(0.5)

    damage_mapper = vtk.vtkPolyDataMapper()
    damage_mapper.SetInputConnection(sphere.GetOutputPort())

    damage_actor = vtk.vtkActor()
    damage_actor.SetMapper(damage_mapper)
    severity = damage["severity"]
    damage_actor.GetProperty().SetColor(1.0, 1.0 - severity, 0.0)
    renderer.AddActor(damage_actor)

# Add ground plane
plane = vtk.vtkPlaneSource()
plane.SetOrigin(-50, -50, -1)
plane.SetPoint1(50, -50, -1)
plane.SetPoint2(-50, 50, -1)

plane_mapper = vtk.vtkPolyDataMapper()
plane_mapper.SetInputConnection(plane.GetOutputPort())

plane_actor = vtk.vtkActor()
plane_actor.SetMapper(plane_mapper)
plane_actor.GetProperty().SetColor(0.3, 0.4, 0.3)
renderer.AddActor(plane_actor)

# Camera setup
camera = renderer.GetActiveCamera()
camera.SetPosition({building["dimensions"]["length"]} * 1.5,
                   -{building["dimensions"]["width"]} * 1.5,
                   {building["dimensions"]["height"]} * 0.8)
camera.SetFocalPoint(0, 0, {building["dimensions"]["height"]} / 2)
camera.SetViewUp(0, 0, 1)

# Lighting
light = vtk.vtkLight()
light.SetPosition(20, -20, 30)
light.SetIntensity(1.5)
renderer.AddLight(light)

renderer.SetBackground(0.1, 0.1, 0.1)

# Setup video writer
output_dir = Path("{output_path_fixed}").parent
output_dir.mkdir(parents=True, exist_ok=True)

window_to_image = vtk.vtkWindowToImageFilter()
window_to_image.SetInput(render_window)

# Use PNG writer and then convert to video with OpenCV
import cv2
temp_frames = []

print("Rendering frames...")
failure_frame = int({vtk_data["analysis"]["failure_time"]} * fps)

for frame in range(total_frames):
    progress = frame / total_frames
    time = frame / fps

    # Animate collapse after failure time
    if frame > failure_frame:
        collapse_progress = (frame - failure_frame) / (total_frames - failure_frame)

        # Animate structure collapse (translate downward)
        position = structure_actor.GetPosition()
        structure_actor.SetPosition(
            position[0],
            position[1],
            -collapse_progress * {building["dimensions"]["height"]} * 0.8
        )

        # Fade opacity
        structure_actor.GetProperty().SetOpacity(0.8 * (1.0 - collapse_progress * 0.5))

        # Rotate slightly
        structure_actor.RotateX(collapse_progress * 10)

    # Animate camera
    camera.Azimuth(0.2)
    camera.Elevation(0.05 * np.sin(progress * 3.14159))

    # Render frame
    render_window.Render()

    # Capture frame
    window_to_image.Modified()
    window_to_image.Update()

    image_data = window_to_image.GetOutput()
    dims = image_data.GetDimensions()

    # Convert VTK image to numpy array
    vtk_array = image_data.GetPointData().GetScalars()
    numpy_array = np.frombuffer(vtk_array, dtype=np.uint8)
    numpy_array = numpy_array.reshape((dims[1], dims[0], 3))
    numpy_array = np.flip(numpy_array, axis=0)  # Flip vertically
    numpy_array = cv2.cvtColor(numpy_array, cv2.COLOR_RGB2BGR)

    # ===========================================================
    # ADD TEXT OVERLAYS WITH ALL INFORMATION
    # ===========================================================

    # Extract analysis data
    safety_factor = sim_data["analysis"]["safety_factor"]
    failure_prob = sim_data["analysis"]["failure_probability"]
    building_type = sim_data["building"]["type"]
    floors = sim_data["building"]["floors"]
    material = sim_data["building"]["material"]
    age = sim_data["building"]["age"]

    # Determine risk level based on safety factor and failure probability
    if safety_factor < 0.8 or failure_prob > 0.7:
        risk_level = "CRITICAL"
        risk_color = (0, 0, 255)  # Red
    elif safety_factor < 1.0 or failure_prob > 0.5:
        risk_level = "HIGH"
        risk_color = (0, 100, 255)  # Orange
    elif safety_factor < 1.2 or failure_prob > 0.3:
        risk_level = "MEDIUM"
        risk_color = (0, 255, 255)  # Yellow
    else:
        risk_level = "LOW"
        risk_color = (0, 255, 0)  # Green

    # Extract collapse mechanism from GPT instructions
    instructions = sim_data["simulation"]["instructions"]
    collapse_type = "PANCAKE COLLAPSE"  # Default
    if "pancake" in instructions.lower():
        collapse_type = "PANCAKE COLLAPSE"
    elif "progressive" in instructions.lower():
        collapse_type = "PROGRESSIVE COLLAPSE"
    elif "lean-to" in instructions.lower() or "lean to" in instructions.lower():
        collapse_type = "LEAN-TO COLLAPSE"
    elif "v-shape" in instructions.lower() or "v shape" in instructions.lower():
        collapse_type = "V-SHAPE COLLAPSE"

    # Simulation phase
    if time < {vtk_data["analysis"]["failure_time"]}:
        phase = "INITIAL CONDITION"
        phase_color = (255, 255, 255)
    else:
        phase = f"COLLAPSE IN PROGRESS - {{collapse_type}}"
        phase_color = (0, 0, 255)

    # ===========================================================
    # OVERLAY 1: RISK LEVEL (Top Right)
    # ===========================================================
    cv2.rectangle(numpy_array, (width - 300, 10), (width - 10, 100), (0, 0, 0), -1)
    cv2.rectangle(numpy_array, (width - 300, 10), (width - 10, 100), risk_color, 3)
    cv2.putText(numpy_array, f"RISK: {{risk_level}}",
                (width - 280, 45), cv2.FONT_HERSHEY_SIMPLEX, 0.9, risk_color, 3)
    cv2.putText(numpy_array, f"SF: {{safety_factor:.2f}}",
                (width - 280, 75), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)

    # ===========================================================
    # OVERLAY 2: BUILDING INFORMATION (Top Left)
    # ===========================================================
    cv2.rectangle(numpy_array, (10, 10), (400, 150), (0, 0, 0), -1)
    cv2.rectangle(numpy_array, (10, 10), (400, 150), (100, 100, 100), 2)
    cv2.putText(numpy_array, f"{{building_type.upper()}} BUILDING",
                (20, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 3)
    cv2.putText(numpy_array, f"Floors: {{floors}} | Material: {{material.upper()}}",
                (20, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(numpy_array, f"Age: {{age}} years | SF: {{safety_factor:.2f}}",
                (20, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(numpy_array, f"Failure Prob: {{failure_prob*100:.1f}}%",
                (20, 115), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    cv2.putText(numpy_array, f"Damage Points: {{len(damage_points)}}",
                (20, 140), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

    # ===========================================================
    # OVERLAY 3: SIMULATION PHASE (Center Top)
    # ===========================================================
    text_size = cv2.getTextSize(phase, cv2.FONT_HERSHEY_SIMPLEX, 0.9, 3)[0]
    text_x = (width - text_size[0]) // 2
    cv2.rectangle(numpy_array, (text_x - 15, 10), (text_x + text_size[0] + 15, 60), (0, 0, 0), -1)
    cv2.putText(numpy_array, phase,
                (text_x, 45), cv2.FONT_HERSHEY_SIMPLEX, 0.9, phase_color, 3)

    # ===========================================================
    # OVERLAY 4: COLLAPSE MECHANISM (Center - during collapse)
    # ===========================================================
    if time >= {vtk_data["analysis"]["failure_time"]}:
        collapse_text = f"{{collapse_type}}"
        text_size = cv2.getTextSize(collapse_text, cv2.FONT_HERSHEY_SIMPLEX, 1.2, 4)[0]
        text_x = (width - text_size[0]) // 2
        text_y = height // 2 - 100

        # Semi-transparent background
        overlay = numpy_array.copy()
        cv2.rectangle(overlay, (text_x - 20, text_y - 40), (text_x + text_size[0] + 20, text_y + 10), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, numpy_array, 0.3, 0, numpy_array)

        cv2.putText(numpy_array, collapse_text,
                    (text_x, text_y), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 255), 4)

    # ===========================================================
    # OVERLAY 5: TIMESTAMP (Bottom Left)
    # ===========================================================
    cv2.putText(numpy_array, f"T+{{time:.2f}}s / {{duration:.1f}}s",
                (20, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

    # ===========================================================
    # OVERLAY 6: SAFETY WARNING (Bottom - semi-transparent banner)
    # ===========================================================
    warning_text = f"! {{risk_level}} RISK - AVOID BUILDING AND SURROUNDINGS"
    if risk_level in ["HIGH", "CRITICAL"]:
        overlay = numpy_array.copy()
        cv2.rectangle(overlay, (0, height - 80), (width, height - 40), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, numpy_array, 0.3, 0, numpy_array)
        cv2.putText(numpy_array, warning_text,
                    (50, height - 52), cv2.FONT_HERSHEY_SIMPLEX, 0.9, risk_color, 3)

    # ===========================================================
    # OVERLAY 7: IntegrityInspect Watermark (Bottom Right)
    # ===========================================================
    cv2.putText(numpy_array, "IntegrityInspect AI",
                (width - 250, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (150, 150, 150), 1)

    temp_frames.append(numpy_array)

    if frame % 30 == 0:
        print(f"  Frame {{frame}}/{{total_frames}} ({{progress*100:.1f}}%)")

print("Writing video file...")
# Use H.264 codec for better compatibility with mobile devices
fourcc = cv2.VideoWriter_fourcc(*'avc1')  # H.264 codec
out = cv2.VideoWriter("{output_path_fixed}", fourcc, fps, (width, height))

for frame in temp_frames:
    out.write(frame)

out.release()

print(f"Video saved to: {output_path_fixed}")
print("Simulation complete!")
'''

        return script

    async def _run_paraview(self, script_file: str, output_path: str) -> str:
        """Run ParaView/VTK script"""

        try:
            logger.info(f"Running VTK simulation script...")
            logger.info(f"Script: {script_file}")
            logger.info(f"Output: {output_path}")

            cmd = ["python", script_file]

            logger.info(f"Command: {' '.join(cmd)}")


            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=600  
            )


            if result.stdout:
                logger.info(f"VTK stdout: {result.stdout[-1000:]}")
            if result.stderr:
                logger.warning(f"VTK stderr: {result.stderr[-1000:]}")

            if result.returncode != 0:
                raise Exception(f"VTK rendering failed with code {result.returncode}")


            if not os.path.exists(output_path):
                raise Exception(f"Output video file not created: {output_path}")

            file_size = os.path.getsize(output_path)
            logger.info(f"ParaView/VTK rendering complete: {output_path} ({file_size / 1024:.1f} KB)")

            return output_path

        except subprocess.TimeoutExpired:
            raise Exception("VTK rendering timed out (10 minutes)")
        except Exception as e:
            logger.error(f"VTK execution error: {str(e)}")
            raise

    async def test_paraview(self) -> bool:
        """Test if ParaView/VTK is working correctly"""

        if not self.is_available():
            logger.error("VTK not available")
            return False

        try:
            logger.info("Testing VTK installation...")
            import vtk


            renderer = vtk.vtkRenderer()
            render_window = vtk.vtkRenderWindow()
            render_window.AddRenderer(renderer)
            render_window.SetSize(640, 480)
            render_window.SetOffScreenRendering(1)


            cube = vtk.vtkCubeSource()
            mapper = vtk.vtkPolyDataMapper()
            mapper.SetInputConnection(cube.GetOutputPort())
            actor = vtk.vtkActor()
            actor.SetMapper(mapper)
            renderer.AddActor(actor)


            render_window.Render()

            logger.info("✅ VTK test passed!")
            return True

        except Exception as e:
            logger.error(f"❌ VTK test error: {str(e)}")
            return False
