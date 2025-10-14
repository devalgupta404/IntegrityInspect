# Emergency Structural Assessment System - Complete Implementation

## Project Overview
Build a comprehensive emergency structural assessment application for first responders to evaluate damaged buildings during disasters. The system consists of a Flutter mobile app (offline-first data collection), a cloud backend (data processing and AI orchestration), and integrations with GPT-5 for analysis and Sora for video visualization.

---

## Architecture Overview

```
Flutter App (Mobile) ←→ Backend API ←→ GPT-5 API
                                   ↓
                                Sora API
```

**Technology Stack:**
- Frontend: Flutter (iOS/Android)
- Backend: Node.js/Express or Python/FastAPI
- Database: PostgreSQL (cloud) + Hive/SQLite (local)
- AI Services: OpenAI GPT-5 API, OpenAI Sora API
- Storage: AWS S3 or Firebase Storage (images/videos)
- Maps: Google Maps Flutter plugin

---

## Part 1: Flutter Frontend

### Project Structure
```
lib/
├── main.dart
├── models/
│   ├── building_assessment.dart
│   ├── hazard.dart
│   └── analysis_result.dart
├── services/
│   ├── local_storage_service.dart
│   ├── sync_service.dart
│   ├── camera_service.dart
│   └── location_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── assessment_form_screen.dart
│   ├── photo_capture_screen.dart
│   ├── hazard_map_screen.dart
│   ├── results_screen.dart
│   └── history_screen.dart
├── widgets/
│   ├── building_parameter_form.dart
│   ├── damage_annotation_widget.dart
│   ├── hazard_pin_widget.dart
│   └── video_player_widget.dart
└── utils/
    ├── constants.dart
    └── validators.dart
```

### Required Flutter Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.0
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  
  # Networking
  http: ^1.1.0
  dio: ^5.4.0
  connectivity_plus: ^5.0.2
  
  # Maps
  google_maps_flutter: ^2.5.0
  geolocator: ^10.1.0
  
  # Camera & Media
  camera: ^0.10.5
  image_picker: ^1.0.5
  video_player: ^2.8.1
  photo_view: ^0.14.0
  
  # UI Components
  flutter_form_builder: ^9.1.1
  dropdown_search: ^5.0.6
  image_cropper: ^5.0.1
  
  # Utils
  intl: ^0.18.1
  uuid: ^4.2.1
  permission_handler: ^11.1.0

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.7
```

### Core Data Models

**1. BuildingAssessment Model** (`models/building_assessment.dart`):
```dart
import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class BuildingAssessment extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime timestamp;
  
  @HiveField(2)
  final String buildingType; // residential, commercial, industrial
  
  @HiveField(3)
  final int numberOfFloors;
  
  @HiveField(4)
  final String primaryMaterial; // concrete, brick, steel, wood
  
  @HiveField(5)
  final int yearBuilt;
  
  @HiveField(6)
  final List<String> damageTypes; // cracks, tilting, collapse, etc.
  
  @HiveField(7)
  final String damageDescription;
  
  @HiveField(8)
  final List<String> photoUrls; // local paths when offline
  
  @HiveField(9)
  final double latitude;
  
  @HiveField(10)
  final double longitude;
  
  @HiveField(11)
  final List<Hazard> hazards;
  
  @HiveField(12)
  final bool isSynced;
  
  @HiveField(13)
  final String? analysisResultId;
  
  // Constructor, toJson, fromJson methods
}
```

**2. Hazard Model** (`models/hazard.dart`):
```dart
@HiveType(typeId: 1)
class Hazard extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String type; // gas_leak, electrical, water, structural
  
  @HiveField(2)
  final double latitude;
  
  @HiveField(3)
  final double longitude;
  
  @HiveField(4)
  final String severity; // low, medium, high, critical
  
  @HiveField(5)
  final String description;
  
  @HiveField(6)
  final String? photoUrl;
}
```

**3. AnalysisResult Model** (`models/analysis_result.dart`):
```dart
@HiveType(typeId: 2)
class AnalysisResult extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String assessmentId;
  
  @HiveField(2)
  final String riskLevel; // low, medium, high, critical
  
  @HiveField(3)
  final String analysis;
  
  @HiveField(4)
  final String? failureMode;
  
  @HiveField(5)
  final List<String> recommendations;
  
  @HiveField(6)
  final String? videoUrl;
  
  @HiveField(7)
  final DateTime generatedAt;
  
  @HiveField(8)
  final Map<String, dynamic>? detailedMetrics;
}
```

### Key Services to Implement

**1. LocalStorageService** - Manages offline data persistence
- Initialize Hive database
- CRUD operations for assessments
- Queue management for unsynced data
- Cache management for results

**2. SyncService** - Handles cloud synchronization
- Monitor connectivity status
- Upload queued assessments when online
- Download analysis results
- Retry logic with exponential backoff
- Conflict resolution

**3. CameraService** - Photo/video capture and annotation
- Access device camera
- Save images locally
- Image compression
- Annotation overlay (draw on images)
- Batch upload preparation

**4. LocationService** - GPS and mapping
- Get current location
- Geocoding/reverse geocoding
- Distance calculations
- Map marker management

### Critical Screen Implementations

**Assessment Form Screen:**
- Multi-step form with validation
- Dynamic fields based on building type
- Auto-save drafts every 30 seconds
- Visual damage checklist with icons
- Material design dropdown selectors
- Date picker for construction year
- Save locally immediately, sync later

**Photo Capture Screen:**
- Camera preview with grid overlay
- Multiple photo capture with gallery
- Annotation tools (draw, mark, text)
- Photo metadata (timestamp, GPS)
- Compress before saving
- Preview before submission

**Hazard Map Screen:**
- Interactive Google Maps
- Custom markers for different hazard types
- Pin drop with long-press gesture
- Info window on marker tap
- Draw danger zones (polygons)
- Layer toggles for hazard types
- Offline map caching

**Results Screen:**
- Risk level banner (color-coded)
- Collapsible sections for analysis
- Video player for Sora visualization
- Downloadable PDF report
- Share functionality
- Expert contact button

### Offline-First Implementation Strategy

```dart
// Example sync logic
class SyncService {
  Future<void> syncAssessments() async {
    if (await checkConnectivity()) {
      final unsyncedAssessments = await getUnsyncedAssessments();
      
      for (var assessment in unsyncedAssessments) {
        try {
          // Upload photos first
          final photoUrls = await uploadPhotos(assessment.photoUrls);
          
          // Update assessment with cloud URLs
          assessment.photoUrls = photoUrls;
          
          // Send to backend
          final response = await apiService.submitAssessment(assessment);
          
          // Mark as synced
          assessment.isSynced = true;
          await assessment.save();
          
          // Listen for analysis results
          pollForResults(assessment.id);
        } catch (e) {
          // Log error, will retry on next sync attempt
        }
      }
    }
  }
  
  Future<void> pollForResults(String assessmentId) async {
    // Implement polling or WebSocket for real-time updates
  }
}
```

---

## Part 2: Backend API

### Technology Choice: Python/FastAPI (Recommended)

**Why FastAPI:**
- Async support for AI API calls
- Built-in request validation
- Automatic API documentation
- Easy integration with OpenAI SDK
- Great for rapid development

### Project Structure
```
backend/
├── main.py
├── requirements.txt
├── .env
├── api/
│   ├── __init__.py
│   ├── routes/
│   │   ├── assessments.py
│   │   ├── analysis.py
│   │   └── health.py
│   └── middleware/
│       ├── auth.py
│       └── cors.py
├── services/
│   ├── gpt_service.py
│   ├── sora_service.py
│   ├── storage_service.py
│   └── database_service.py
├── models/
│   ├── schemas.py
│   └── database_models.py
└── utils/
    ├── prompt_builder.py
    └── config.py
```

### Dependencies (`requirements.txt`)
```
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.3
sqlalchemy==2.0.25
psycopg2-binary==2.9.9
openai==1.12.0
python-dotenv==1.0.0
python-multipart==0.0.6
boto3==1.34.34
Pillow==10.2.0
aiohttp==3.9.3
redis==5.0.1
celery==5.3.6
```

### Environment Variables (`.env`)
```
# OpenAI
OPENAI_API_KEY=your_openai_api_key
GPT_MODEL=gpt-5-turbo
SORA_MODEL=sora-1.0

# Database
DATABASE_URL=postgresql://user:password@localhost/structural_db

# Storage
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
S3_BUCKET_NAME=structural-assessments

# Redis (for job queues)
REDIS_URL=redis://localhost:6379

# API
API_SECRET_KEY=your_secret_key
ALLOWED_ORIGINS=*
```

### Core Backend Implementation

**1. Main Application** (`main.py`):
```python
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from api.routes import assessments, analysis
from utils.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting up...")
    # Initialize database connection pool
    # Initialize Redis connection
    yield
    # Shutdown
    logger.info("Shutting down...")

app = FastAPI(
    title="Structural Assessment API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(assessments.router, prefix="/api/v1/assessments", tags=["assessments"])
app.include_router(analysis.router, prefix="/api/v1/analysis", tags=["analysis"])

@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0"}
```

**2. GPT Service** (`services/gpt_service.py`):
```python
import openai
from openai import AsyncOpenAI
import base64
import json
from typing import Dict, List
import logging

logger = logging.getLogger(__name__)

class GPTService:
    def __init__(self, api_key: str, model: str = "gpt-4-vision-preview"):
        self.client = AsyncOpenAI(api_key=api_key)
        self.model = model
    
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
        Returns risk assessment and Sora prompt
        """
        
        # Build the system message
        system_message = """You are an expert structural engineer specializing in disaster assessment.
Your role is to analyze damaged buildings and provide safety assessments for first responders.

Given building parameters and damage photos, provide:
1. Risk Level (low/medium/high/critical)
2. Detailed safety analysis
3. Most likely failure mode
4. Specific recommendations for safe entry/approach
5. A descriptive prompt for generating a simulation video of potential collapse

Be conservative in your assessment - prioritize responder safety.
Respond in JSON format."""

        # Build user message with building data
        user_content = [
            {
                "type": "text",
                "text": f"""Building Assessment Data:
- Type: {building_data.get('building_type')}
- Floors: {building_data.get('number_of_floors')}
- Primary Material: {building_data.get('primary_material')}
- Year Built: {building_data.get('year_built')}
- Reported Damage: {building_data.get('damage_description')}
- Damage Types: {', '.join(building_data.get('damage_types', []))}

Analyze the attached images and provide a comprehensive safety assessment."""
            }
        ]
        
        # Add images to the message
        for url in image_urls:
            user_content.append({
                "type": "image_url",
                "image_url": {"url": url}
            })
        
        try:
            # Call GPT-4 Vision
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_message},
                    {"role": "user", "content": user_content}
                ],
                response_format={"type": "json_object"},
                max_tokens=2000,
                temperature=0.3  # Lower temperature for more consistent analysis
            )
            
            # Parse the response
            result = json.loads(response.choices[0].message.content)
            
            logger.info(f"GPT analysis completed: {result.get('risk_level')}")
            
            return {
                "risk_level": result.get("risk_level"),
                "analysis": result.get("analysis"),
                "failure_mode": result.get("failure_mode"),
                "recommendations": result.get("recommendations", []),
                "sora_prompt": result.get("sora_prompt"),
                "confidence": result.get("confidence", "medium")
            }
            
        except Exception as e:
            logger.error(f"GPT analysis error: {str(e)}")
            raise
```

**3. Sora Service** (`services/sora_service.py`):
```python
import asyncio
import logging
from openai import AsyncOpenAI
from typing import Optional

logger = logging.getLogger(__name__)

class SoraService:
    def __init__(self, api_key: str):
        self.client = AsyncOpenAI(api_key=api_key)
    
    async def generate_collapse_simulation(
        self,
        prompt: str,
        reference_image_url: Optional[str] = None,
        duration: int = 5  # seconds
    ) -> str:
        """
        Generate a structural collapse simulation video using Sora
        Returns video URL
        """
        
        try:
            # Enhance the prompt for better simulation quality
            enhanced_prompt = f"""Realistic structural engineering simulation:
{prompt}

Style: Documentary disaster footage, realistic physics, professional camera angle,
dust and debris effects, slow-motion emphasis on critical failure points.
Duration: {duration} seconds."""

            logger.info(f"Generating Sora video with prompt: {enhanced_prompt[:100]}...")
            
            # Call Sora API
            # Note: API may change - adjust based on actual Sora API structure
            response = await self.client.videos.generate(
                model="sora-1.0",
                prompt=enhanced_prompt,
                duration=duration,
                image=reference_image_url if reference_image_url else None
            )
            
            # Poll for completion if async
            video_id = response.id
            video_url = await self._poll_video_completion(video_id)
            
            logger.info(f"Video generated successfully: {video_url}")
            return video_url
            
        except Exception as e:
            logger.error(f"Sora generation error: {str(e)}")
            # Return None or raise - app should handle gracefully
            return None
    
    async def _poll_video_completion(self, video_id: str, max_retries: int = 60) -> str:
        """Poll Sora API until video is ready"""
        for i in range(max_retries):
            try:
                status = await self.client.videos.retrieve(video_id)
                
                if status.status == "completed":
                    return status.url
                elif status.status == "failed":
                    raise Exception(f"Video generation failed: {status.error}")
                
                # Wait before next poll
                await asyncio.sleep(5)
                
            except Exception as e:
                logger.error(f"Polling error: {str(e)}")
                raise
        
        raise TimeoutError("Video generation timed out")
```

**4. Assessment Routes** (`api/routes/assessments.py`):
```python
from fastapi import APIRouter, HTTPException, UploadFile, File, BackgroundTasks
from typing import List
import uuid
from datetime import datetime

from services.gpt_service import GPTService
from services.sora_service import SoraService
from services.storage_service import StorageService
from models.schemas import AssessmentCreate, AssessmentResponse, AnalysisResponse
from utils.config import settings

router = APIRouter()

gpt_service = GPTService(settings.OPENAI_API_KEY)
sora_service = SoraService(settings.OPENAI_API_KEY)
storage_service = StorageService()

@router.post("/submit", response_model=AssessmentResponse)
async def submit_assessment(
    assessment: AssessmentCreate,
    background_tasks: BackgroundTasks
):
    """
    Receive assessment data from mobile app
    Trigger background analysis
    """
    
    assessment_id = str(uuid.uuid4())
    
    # Store assessment in database
    # ... database insertion logic ...
    
    # Trigger background analysis
    background_tasks.add_task(
        run_analysis,
        assessment_id,
        assessment.dict()
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
    """
    Handle photo uploads from mobile app
    Store in S3 and return URLs
    """
    
    uploaded_urls = []
    
    for file in files:
        # Validate file type
        if not file.content_type.startswith('image/'):
            raise HTTPException(400, "Only image files allowed")
        
        # Generate unique filename
        filename = f"{assessment_id}/{uuid.uuid4()}.jpg"
        
        # Upload to S3
        url = await storage_service.upload_file(file, filename)
        uploaded_urls.append(url)
    
    return {
        "assessment_id": assessment_id,
        "photo_urls": uploaded_urls
    }

@router.get("/status/{assessment_id}")
async def get_analysis_status(assessment_id: str):
    """
    Check analysis status
    Return results if completed
    """
    
    # Query database for analysis results
    # ... database query logic ...
    
    return {
        "assessment_id": assessment_id,
        "status": "completed",  # or "processing", "failed"
        "result": analysis_result if available else None
    }

async def run_analysis(assessment_id: str, assessment_data: dict):
    """
    Background task: Run GPT analysis and Sora generation
    """
    
    try:
        # 1. Get GPT-4 Vision analysis
        gpt_result = await gpt_service.analyze_structural_damage(
            building_data=assessment_data,
            image_urls=assessment_data.get('photo_urls', [])
        )
        
        # 2. Generate Sora video if high/critical risk
        video_url = None
        if gpt_result['risk_level'] in ['high', 'critical']:
            video_url = await sora_service.generate_collapse_simulation(
                prompt=gpt_result['sora_prompt'],
                reference_image_url=assessment_data['photo_urls'][0] if assessment_data.get('photo_urls') else None
            )
        
        # 3. Store results in database
        analysis_result = {
            "assessment_id": assessment_id,
            "risk_level": gpt_result['risk_level'],
            "analysis": gpt_result['analysis'],
            "failure_mode": gpt_result.get('failure_mode'),
            "recommendations": gpt_result.get('recommendations', []),
            "video_url": video_url,
            "generated_at": datetime.utcnow(),
            "confidence": gpt_result.get('confidence')
        }
        
        # ... save to database ...
        
        # 4. Optionally: Send push notification to mobile app
        # ... notification logic ...
        
    except Exception as e:
        logger.error(f"Analysis failed for {assessment_id}: {str(e)}")
        # Update status to failed in database
```

**5. Data Schemas** (`models/schemas.py`):
```python
from pydantic import BaseModel, Field, validator
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
    year_built: int = Field(ge=1800, le=2030)
    damage_types: List[str]
    damage_description: str
    photo_urls: List[str]
    latitude: float
    longitude: float
    hazards: List[HazardCreate] = []
    
    @validator('damage_types')
    def validate_damage_types(cls, v):
        valid_types = ['cracks', 'tilting', 'partial_collapse', 
                       'column_damage', 'wall_damage', 'foundation_issues']
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
```

---

## Part 3: Integration & Deployment

### Mobile App - Backend Integration

**API Service in Flutter** (`services/api_service.dart`):
```dart
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  final Dio _dio;
  final String baseUrl;
  
  ApiService(this.baseUrl) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  ));
  
  Future<Map<String, dynamic>> submitAssessment(
    BuildingAssessment assessment
  ) async {
    try {
      // First upload photos
      final photoUrls = await uploadPhotos(
        assessment.id,
        assessment.photoUrls
      );
      
      // Then submit assessment data
      final response = await _dio.post(
        '/api/v1/assessments/submit',
        data: {
          'building_type': assessment.buildingType,
          'number_of_floors': assessment.numberOfFloors,
          'primary_material': assessment.primaryMaterial,
          'year_built': assessment.yearBuilt,
          'damage_types': assessment.damageTypes,
          'damage_description': assessment.damageDescription,
          'photo_urls': photoUrls,
          'latitude': assessment.latitude,
          'longitude': assessment.longitude,
          'hazards': assessment.hazards.map((h) => h.toJson()).toList(),
        },
      );
      
      return response.data;
    } catch (e) {
      throw ApiException('Failed to submit assessment: $e');
    }
  }
  
  Future<List<String>> uploadPhotos(
    String assessmentId,
    List<String> localPaths
  ) async {
    List<String> uploadedUrls = [];
    
    for (final path in localPaths) {
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path),
      });
      
      final response = await _dio.post(
        '/api/v1/assessments/upload-photos/$assessmentId',
        data: formData,
      );
      
      uploadedUrls.add(response.data['url']);
    }
    
    return uploadedUrls;
  }
  
  Future<AnalysisResult?> pollForResults(
    String assessmentId,
    {int maxAttempts = 120, Duration interval = const Duration(seconds: 5)}
  ) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await _dio.get(
          '/api/v1/assessments/status/$assessmentId'
        );
        
        if (response.data['status'] == 'completed') {
          return AnalysisResult.fromJson(response.data['result']);
        } else if (response.data['status'] == 'failed') {
          throw ApiException('Analysis failed');
        }
        
        await Future.delayed(interval);
      } catch (e) {
        // Continue polling on errors
      }
    }
    
    return null; // Timeout
  }
}
```

### Deployment Checklist

**Backend Deployment (AWS/GCP/Azure):**
```bash
# 1. Set up cloud services
- PostgreSQL RDS instance
- Redis for job queues
- S3 bucket for media storage
- EC2 or Cloud Run for API hosting

# 2. Environment setup
- Configure environment variables
- Set up SSL certificates
- Configure CORS policies
- Set up monitoring (CloudWatch/Stackdriver)

# 3. Deploy API
docker build -t structural-assessment-api .
docker push your-registry/structural-assessment-api
# Deploy to cloud platform

# 4. Set up background workers
# For video generation (long-running task)
celery -A tasks worker --loglevel=info
```

**Mobile App Deployment:**
```bash
# Android
flutter build appbundle --release

# iOS
flutter build ipa --release

# Deploy to stores or internal distribution
```

### Performance Optimization

**Backend:**
- Use Redis for caching frequent queries
- Implement rate limiting to prevent abuse
- Use CDN for video delivery
- Compress images before GPT analysis
- Batch multiple assessments if possible

**Mobile:**
- Lazy load images in lists
- Implement pagination for history
- Compress photos before upload (target 2MB max)
- Use isolates for heavy computations
- Cache API responses locally

### Security Considerations

**Backend:**
```python
# Add authentication middleware
from fastapi import Security, HTTPException
from fastapi.security.api_key import APIKeyHeader

API_KEY_HEADER = APIKeyHeader(name="X-API-Key")

async def verify_api_key(api_key: str = Security(API_KEY_HEADER)):
    if api_key != settings.API_SECRET_KEY:
        raise HTTPException(403, "Invalid API key")
    return api_key

# Apply to protected routes
@router.post("/submit", dependencies=[Depends(verify_api_key)])
```

**Mobile:**
- Store API keys securely (flutter_secure_storage)
- Encrypt local database
- Validate all user inputs
- Implement certificate pinning
- Use HTTPS only

---

## Part 4: Testing & Validation

### Backend Testing
```python
# tests/test_gpt_service.py
import pytest
from services.gpt_service import GPTService

@pytest.mark.asyncio
async def test_structural_analysis():
    gpt_service = GPTService(api_key="test_key")
    
    building_data = {
        "building_type": "residential",
        "number_of_floors": 3,
        "primary_material": "concrete",
        "year_built": 1985,
        "damage_description": "Large cracks in support columns"
    }
    
    result = await gpt_service.analyze_structural_damage(
        building_data,
        ["http://example.com/photo1.jpg"]
    )
    
    assert result['risk_level'] in ['low', 'medium', 'high', 'critical']
    assert len(result['recommendations']) > 0
    assert result['sora_prompt'] is not None
```

### Mobile Testing
```dart
// test/services/sync_service_test.dart
void main() {
  group('SyncService', () {
    test('uploads unsynced assessments', () async {
      final syncService = SyncService();
      final result = await syncService.syncAssessments();
      expect(result, isTrue);
    });
  });
}
```

---

## Implementation Timeline

**Week 1-2: Foundation**
- Set up Flutter project structure
- Implement local data models (Hive)
- Create basic UI screens
- Set up backend FastAPI skeleton

**Week 3-4: Core Features**
- Implement assessment form with validation
- Add camera integration and photo management
- Build map integration for hazards
- Develop GPT integration service

**Week 5-6: AI Integration**
- Complete GPT-4 Vision analysis
- Integrate Sora API
- Build result display screens
- Implement video player

**Week 7-8: Sync & Polish**
- Build robust offline/online sync
- Add background tasks for analysis
- Implement polling/notifications
- Error handling and edge cases

**Week 9-10: Testing & Deployment**
- End-to-end testing
- Performance optimization
- Security audit
- Deploy to staging
- Beta testing with first responders

---

## Critical Implementation Notes

1. **GPT-4 Vision API Usage:**
   - Image size limit: 20MB
   - Optimize images before sending
   - Handle rate limits gracefully
   - Cost per request: Monitor usage

2. **Sora Considerations:**
   - Video generation can take 1-5 minutes
   - Implement proper polling mechanism
   - Handle timeouts gracefully
   - Cache generated videos

3. **Offline-First Strategy:**
   - Queue all operations when offline
   - Sync intelligently when online
   - Show clear sync status to users
   - Handle conflicts (rare but possible)

4. **Error Handling:**
   - Always provide fallback UI
   - Never lose user data
   - Log errors for debugging
   - Show user-friendly messages

5. **Scalability:**
   - Use Celery for background tasks
   - Implement proper database indexing
   - Monitor API costs
   - Set up auto-scaling for traffic spikes

---

## Next Steps

1. Initialize Flutter project and install dependencies
2. Set up Hive database and data models
3. Create basic UI screens (form, camera, map)
4. Set up FastAPI backend with basic routes
5. Integrate OpenAI SDK and test GPT-4 Vision
6. Build sync service for offline/online transition
7. Implement video generation and display
8. Add comprehensive error handling
9. Test end-to-end workflow
10. Deploy to staging for user testing

This architecture provides a solid foundation for a production-ready emergency structural assessment system that leverages cutting-edge AI while maintaining reliability through offline-first design.