import openai
from openai import AsyncOpenAI
import base64
import json
from typing import Dict, List, Optional
import logging
import os

logger = logging.getLogger(__name__)

class GPTService:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            logger.warning("OpenAI API key not provided - using mock responses")
            self.client = None
        else:
            self.client = AsyncOpenAI(api_key=self.api_key)
        self.model = os.getenv("GPT_MODEL", "gpt-4-vision-preview")

    def encode_image(self, image_path: str) -> str:
        """Encode image to base64 for GPT-4 Vision"""
        with open(image_path, "rb") as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')

    async def analyze_structural_damage(
        self,
        building_data: Dict,
        image_urls: List[str]
    ) -> Dict:
        """
        Analyze building damage using GPT-4 Vision
        Returns comprehensive safety assessment and Sora prompt
        """

        # Build the system message
        system_message = """You are an expert structural engineer and disaster assessment specialist.
Your role is to analyze damaged buildings and provide critical safety assessments for emergency first responders.

Given building parameters and damage photos, you MUST provide a detailed JSON response with:
1. risk_level: One of "low", "medium", "high", or "critical"
2. analysis: Comprehensive safety analysis (200-400 words)
3. failure_mode: Most likely structural failure mechanism
4. recommendations: Array of 5-8 specific actionable safety recommendations
5. sora_prompt: Detailed prompt for generating a realistic collapse simulation video (100-150 words)
6. confidence: Your confidence level in the assessment ("low", "medium", "high")
7. immediate_actions: Array of 3-5 immediate actions responders should take

Be conservative in your assessment - prioritize responder safety above all.
Consider:
- Building age and construction standards of that era
- Material properties and degradation
- Load distribution and failure patterns
- Environmental factors (seismic, weather, etc.)
- Progressive collapse potential

Respond ONLY in valid JSON format."""

        # Build user message with building data
        damage_types_text = ", ".join(building_data.get('damage_types', []))

        user_content = [
            {
                "type": "text",
                "text": f"""## Building Assessment Data

**Building Type:** {building_data.get('building_type', 'Unknown')}
**Number of Floors:** {building_data.get('number_of_floors', 'Unknown')}
**Primary Material:** {building_data.get('primary_material', 'Unknown')}
**Year Built:** {building_data.get('year_built', 'Unknown')}
**Reported Damage Types:** {damage_types_text}

**Damage Description:**
{building_data.get('damage_description', 'No description provided')}

**Location:**
Latitude: {building_data.get('latitude', 'N/A')}
Longitude: {building_data.get('longitude', 'N/A')}

Please analyze the attached images and provide a comprehensive safety assessment for emergency responders.
Focus on:
1. Structural integrity assessment
2. Risk of imminent collapse
3. Safe approach routes
4. Hazards to avoid
5. Recommended safety measures"""
            }
        ]

        # Add images to the message
        for idx, url in enumerate(image_urls[:5]):  # Limit to 5 images
            user_content.append({
                "type": "image_url",
                "image_url": {
                    "url": url,
                    "detail": "high"  # Request high detail analysis
                }
            })

        try:
            logger.info(f"Analyzing building: {building_data.get('building_type')} with {len(image_urls)} images")

            # Check if client is available (API key provided)
            if not self.client:
                logger.info("Using mock GPT analysis response (no API key)")
                return {
                    "risk_level": "high",
                    "analysis": "Mock analysis: Structure shows significant damage with multiple crack patterns indicating potential progressive collapse. Immediate evacuation recommended.",
                    "failure_mode": "Progressive collapse due to column damage",
                    "recommendations": [
                        "Immediate evacuation of all occupants",
                        "Structural engineer assessment required",
                        "Temporary shoring may be necessary"
                    ],
                    "sora_prompt": "Simulate progressive collapse of damaged building with crack propagation and structural failure",
                    "confidence": "medium"
                }

            # Call GPT-4 Vision
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_message},
                    {"role": "user", "content": user_content}
                ],
                response_format={"type": "json_object"},
                max_tokens=2500,
                temperature=0.3  # Lower temperature for more consistent analysis
            )

            # Parse the response
            result = json.loads(response.choices[0].message.content)

            logger.info(f"GPT analysis completed: Risk Level = {result.get('risk_level')}, Confidence = {result.get('confidence')}")

            # Validate required fields
            required_fields = ['risk_level', 'analysis', 'recommendations', 'sora_prompt']
            for field in required_fields:
                if field not in result:
                    logger.warning(f"Missing required field in GPT response: {field}")
                    result[field] = self._get_default_value(field)

            # Ensure recommendations is a list
            if isinstance(result.get('recommendations'), str):
                result['recommendations'] = [result['recommendations']]

            # Ensure immediate_actions is present
            if 'immediate_actions' not in result:
                result['immediate_actions'] = self._generate_default_actions(result.get('risk_level', 'medium'))

            return {
                "risk_level": result.get("risk_level", "medium"),
                "analysis": result.get("analysis", "Analysis unavailable"),
                "failure_mode": result.get("failure_mode", "Unable to determine"),
                "recommendations": result.get("recommendations", []),
                "immediate_actions": result.get("immediate_actions", []),
                "sora_prompt": result.get("sora_prompt", ""),
                "confidence": result.get("confidence", "medium"),
                "model_used": self.model,
                "images_analyzed": len(image_urls)
            }

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse GPT response as JSON: {str(e)}")
            return self._create_fallback_response(building_data, "JSON parsing error")

        except Exception as e:
            logger.error(f"GPT analysis error: {str(e)}")
            return self._create_fallback_response(building_data, str(e))

    def _get_default_value(self, field: str) -> any:
        """Provide default values for missing fields"""
        defaults = {
            'risk_level': 'medium',
            'analysis': 'Unable to complete full analysis. Manual inspection recommended.',
            'recommendations': ['Conduct thorough manual inspection', 'Establish safe perimeter', 'Consult structural engineer'],
            'sora_prompt': 'Generate a simulation showing potential structural failure',
            'confidence': 'low'
        }
        return defaults.get(field, 'Unknown')

    def _generate_default_actions(self, risk_level: str) -> List[str]:
        """Generate default immediate actions based on risk level"""
        base_actions = [
            "Establish a safety perimeter",
            "Alert all personnel to potential hazards",
            "Document all observations with photos"
        ]

        if risk_level in ['high', 'critical']:
            base_actions.insert(0, "EVACUATE IMMEDIATELY - Do not enter structure")
            base_actions.append("Contact structural engineer for emergency assessment")
        elif risk_level == 'medium':
            base_actions.insert(0, "Proceed with extreme caution")
            base_actions.append("Monitor for changes in structural condition")
        else:
            base_actions.append("Continue standard safety protocols")

        return base_actions

    def _create_fallback_response(self, building_data: Dict, error: str) -> Dict:
        """Create a conservative fallback response in case of errors"""
        return {
            "risk_level": "high",  # Conservative default
            "analysis": f"Automated analysis unavailable due to technical error: {error}. "
                       f"This {building_data.get('building_type', 'building')} requires immediate manual inspection by a qualified structural engineer. "
                       f"Do not enter without proper safety assessment.",
            "failure_mode": "Unable to determine - manual inspection required",
            "recommendations": [
                "DO NOT ENTER the structure until inspected by a structural engineer",
                "Establish a wide safety perimeter around the building",
                "Document all visible damage with photos and notes",
                "Contact local building department for emergency inspection",
                "Monitor the structure for any changes or movement",
                "Evacuate adjacent structures if necessary"
            ],
            "immediate_actions": [
                "STOP - Do not proceed with entry",
                "Establish minimum 50-foot safety perimeter",
                "Contact structural engineering support immediately",
                "Notify incident command of high-risk structure"
            ],
            "sora_prompt": f"Generate a realistic structural collapse simulation of a {building_data.get('number_of_floors', 'multi')}-story "
                          f"{building_data.get('primary_material', 'concrete')} {building_data.get('building_type', 'building')} "
                          f"showing progressive failure, debris field, and dust cloud. Documentary style, professional camera angle.",
            "confidence": "low",
            "model_used": self.model,
            "images_analyzed": 0,
            "error": error
        }

    async def generate_report_summary(self, assessment_data: Dict, analysis_result: Dict) -> str:
        """Generate a concise summary for reports"""
        try:
            response = await self.client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {
                        "role": "system",
                        "content": "You are a technical writer. Create a concise 2-3 sentence executive summary."
                    },
                    {
                        "role": "user",
                        "content": f"Assessment: {assessment_data}\nAnalysis: {analysis_result['analysis']}"
                    }
                ],
                max_tokens=150,
                temperature=0.5
            )

            return response.choices[0].message.content

        except Exception as e:
            logger.error(f"Error generating summary: {str(e)}")
            return f"Assessment of {assessment_data.get('building_type', 'structure')} - Risk Level: {analysis_result.get('risk_level', 'Unknown')}"
