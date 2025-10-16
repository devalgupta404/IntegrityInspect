"""
Test script for ParaView/VTK integration
Tests if VTK is installed and can generate simulation videos with GPT guidance
"""

import asyncio
import logging
import os
import sys
from services.paraview_service import ParaViewService
import openai
from dotenv import load_dotenv

load_dotenv()

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def test_vtk_installation():
    """Test if VTK is installed and working"""
    logger.info("="*60)
    logger.info("VTK INSTALLATION TEST")
    logger.info("="*60)

    # Initialize OpenAI client
    openai_api_key = os.getenv("OPENAI_API_KEY")
    openai_client = openai.AsyncOpenAI(api_key=openai_api_key) if openai_api_key else None

    paraview_service = ParaViewService(openai_client=openai_client)

    # Check if VTK is available
    if not paraview_service.is_available():
        logger.error("❌ VTK is NOT installed")
        logger.info("\nTo install VTK:")
        logger.info("  pip install vtk")
        return False

    logger.info(f"✅ VTK is installed and available")

    # Run test render
    logger.info("\n" + "="*60)
    logger.info("TESTING VTK RENDER...")
    logger.info("="*60)

    test_passed = await paraview_service.test_paraview()

    if test_passed:
        logger.info("✅ VTK test render PASSED!")
    else:
        logger.error("❌ VTK test render FAILED")

    return test_passed


async def test_simulation_video_generation():
    """Test generating a simulation video with real data and GPT instructions"""
    logger.info("\n" + "="*60)
    logger.info("TESTING PARAVIEW SIMULATION VIDEO GENERATION")
    logger.info("="*60)

    # Initialize OpenAI client
    openai_api_key = os.getenv("OPENAI_API_KEY")
    openai_client = openai.AsyncOpenAI(api_key=openai_api_key) if openai_api_key else None

    if openai_client:
        logger.info("✅ OpenAI API key found - will use GPT for simulation instructions")
    else:
        logger.warning("⚠️  OpenAI API key not found - will use default instructions")

    paraview_service = ParaViewService(openai_client=openai_client)

    if not paraview_service.is_available():
        logger.error("❌ Skipping - VTK not available")
        return False

    # Create test data (simulating a 5-floor residential building with damage)
    building_data = {
        "building_type": "residential",
        "number_of_floors": 5,
        "primary_material": "concrete",
        "year_built": 1995,
        "damage_types": ["cracks", "column_damage"],
        "damage_description": "Multiple cracks and column damage on 3rd floor"
    }

    annotations = [
        {
            "id": "test_1",
            "position": {"x": 512, "y": 600},  # Middle of building, mid-height
            "issueType": "crack",
            "description": "Structural crack on load-bearing wall",
            "color": "yellow",
            "timestamp": "2025-10-15T00:00:00"
        },
        {
            "id": "test_2",
            "position": {"x": 300, "y": 700},  # Left side, higher up
            "issueType": "column_damage",
            "description": "Damaged support column",
            "color": "red",
            "timestamp": "2025-10-15T00:00:00"
        }
    ]

    fea_results = {
        "safety_factor": 0.85,
        "failure_probability": 0.65,
        "critical_points": [
            {"location": {"x": 0, "y": 0, "z": 9}, "stress_level": 25.5}
        ]
    }

    collapse_simulation = {
        "collapse_sequence": [
            {"time": t, "positions": [[0, 0, 0]]}
            for t in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
        ],
        "failure_time": 4.5
    }

    output_path = os.path.abspath("test_paraview_simulation.mp4")

    logger.info("Generating test simulation video with ParaView/VTK...")
    logger.info(f"  Building: {building_data['number_of_floors']}-floor {building_data['building_type']}")
    logger.info(f"  Material: {building_data['primary_material']}")
    logger.info(f"  Damage: {len(annotations)} annotations")
    logger.info(f"  Output: {output_path}")

    try:
        video_path = await paraview_service.generate_simulation_video(
            building_data=building_data,
            annotations=annotations,
            fea_results=fea_results,
            collapse_simulation=collapse_simulation,
            output_path=output_path
        )

        logger.info(f"✅ Simulation video generated successfully!")
        logger.info(f"📹 Video saved to: {video_path}")

        # Check file size
        file_size = os.path.getsize(video_path)
        logger.info(f"📊 File size: {file_size / 1024:.1f} KB")

        return True

    except Exception as e:
        logger.error(f"❌ Simulation video generation FAILED: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


async def main():
    """Run all tests"""
    logger.info("\n" + "="*60)
    logger.info("PARAVIEW/VTK INTEGRATION TEST SUITE")
    logger.info("="*60 + "\n")

    # Test 1: Check installation
    test1_passed = await test_vtk_installation()

    if not test1_passed:
        logger.error("\n❌ VTK NOT INSTALLED - Please install VTK first")
        logger.info("Run: pip install vtk")
        sys.exit(1)

    # Test 2: Generate simulation video
    test2_passed = await test_simulation_video_generation()

    # Summary
    logger.info("\n" + "="*60)
    logger.info("TEST SUMMARY")
    logger.info("="*60)
    logger.info(f"Installation Test: {'✅ PASSED' if test1_passed else '❌ FAILED'}")
    logger.info(f"Video Generation Test: {'✅ PASSED' if test2_passed else '❌ FAILED'}")
    logger.info("="*60 + "\n")

    if test1_passed and test2_passed:
        logger.info("🎉 ALL TESTS PASSED! ParaView/VTK integration is working!")
        sys.exit(0)
    else:
        logger.error("❌ SOME TESTS FAILED - Check errors above")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
