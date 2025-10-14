from pydantic import BaseModel, Field, field_validator
from typing import List, Optional
from datetime import datetime
from enum import Enum


class BuildingType(str, Enum):
    RESIDENTIAL = "residential"
    COMMERCIAL = "commercial"
    INDUSTRIAL = "industrial"
    MIXED_USE = "mixed_use"


class MaterialType(str, Enum):
    CONCRETE = "concrete"
    BRICK = "brick"
    STEEL = "steel"
    WOOD = "wood"
    MIXED = "mixed"


class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class HazardCreate(BaseModel):
    type: str
    latitude: float
    longitude: float
    severity: str
    description: str
    photo_url: Optional[str] = None


class AssessmentCreate(BaseModel):
    building_type: BuildingType
    number_of_floors: int = Field(ge=1, le=200)
    primary_material: MaterialType
    year_built: int = Field(ge=1800, le=2035)
    damage_types: List[str]
    damage_description: str
    photo_urls: List[str]
    latitude: float
    longitude: float
    hazards: List[HazardCreate] = []

    @field_validator('damage_types')
    @classmethod
    def validate_damage_types(cls, v: List[str]) -> List[str]:
        valid_types = {
            'cracks', 'tilting', 'partial_collapse',
            'column_damage', 'wall_damage', 'foundation_issues'
        }
        for damage in v:
            if damage not in valid_types:
                raise ValueError(f'Invalid damage type: {damage}')
        return v


class AssessmentResponse(BaseModel):
    assessment_id: str
    status: str
    message: str


class AnalysisResponse(BaseModel):
    assessment_id: str
    risk_level: RiskLevel
    analysis: str
    failure_mode: Optional[str]
    recommendations: List[str]
    video_url: Optional[str]
    generated_at: datetime
    confidence: str


