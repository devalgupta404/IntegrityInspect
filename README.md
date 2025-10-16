# Integrity Inspect - Emergency Structural Assessment System

AI-Powered Building Safety Assessment for First Responders

A comprehensive mobile and cloud-based system for emergency responders to rapidly assess damaged buildings during disasters, featuring GPT-4 Vision analysis, physics-based video simulations, and a smooth mobile interface.

## Highlights

- **Beautiful, Smooth UI** - Material Design 3 with Flutter Animate
- **Offline-First** - Work without internet, sync later
- AI-Powered Analysis - GPT-4 Vision structural assessment
- Video Simulations - Physics-based collapse predictions (downloadable)
- **Optimized Performance** - Image compression, lazy loading, smooth animations
- **Comprehensive Backend** - FastAPI with async processing

## Mobile App Features

### Implemented 

1. **Flutter Project Structure** - Complete folder organization
2. **Data Models** - Hive-based offline storage (BuildingAssessment, AnalysisResult, Hazard)
3. **Local Storage Service** - Fast, encrypted local database
4. **Camera Service** - Auto-compress images to < 2MB
5. **Video Simulations** - Physics-based collapse predictions (downloadable)
6. **Beautiful UI Screens**:
   - Splash Screen (animated gradient, smooth transitions)
   - Home Screen (dashboard with stats, quick actions, recent assessments)
   - Smooth animations throughout (fade, slide, scale, shimmer)
7. **Theme System** - Complete Material Design 3 theming

### File Structure

```
structural_assessment_app/
├── lib/
│   ├── models/
│   │   ├── building_assessment.dart (Hive model)
│   │   ├── hazard.dart (Hive model)
│   │   └── analysis_result.dart (Hive model + video download tracking)
│   ├── services/
│   │   ├── local_storage_service.dart (Complete CRUD)
│   │   ├── camera_service.dart (Auto-compress, watermark)
│   │   └── video_service.dart (Download, share, storage mgmt)
│   ├── screens/
│   │   ├── splash_screen.dart (Beautiful animations)
│   │   └── home_screen.dart (Dashboard with smooth UI)
│   ├── theme/
│   │   └── app_theme.dart (Complete Material 3 theme)
│   ├── utils/
│   │   └── constants.dart (All app constants)
│   └── main.dart (App initialization)
```

## Backend API

### Implemented 

1. FastAPI Structure - Modern async Python backend
2. GPT-4 Service - Comprehensive structural analysis with fallbacks
3. Physics Simulation Service - Video generation with OpenCV/ParaView
4. Main Application - CORS, health checks, error handling

### File Structure

```
backend/
├── api/
│   └── routes/ (ready for implementation)
├── services/
│   ├── gpt_service.py (GPT-4 Vision integration)
│   └── simulation_video_service.py (Video generation)
├── main.py (FastAPI app)
└── requirements.txt (All dependencies)
```

## Quick Start

### Prerequisites

```bash
flutter --version  # >= 3.0.0
python --version   # >= 3.9
```

### Run Mobile App

```bash
cd structural_assessment_app
flutter pub get
flutter run
```

### Run Backend

```bash
cd backend
pip install -r requirements.txt

# Create .env
echo "OPENAI_API_KEY=your-key-here" > .env

python main.py
# API runs on http://localhost:8000
```

## UI/UX Excellence

### Smooth Animations

Every screen features:
- **Fade In/Out** - Smooth element appearances
- **Slide Transitions** - Natural movement
- **Scale Animations** - Engaging micro-interactions
- **Shimmer Effects** - Beautiful loading states
- **Staggered Lists** - Professional list animations

### Performance

- **Image Compression**: Automatic resize to < 2MB
- **Lazy Loading**: On-demand content loading
- **Cached Images**: Network image caching
- **60 FPS**: Buttery smooth animations
- **Optimized Builds**: Tree-shaking and minification

## AI Integration

### GPT-4 Vision Analysis

The backend provides comprehensive structural assessments:

```python
{
  "risk_level": "high",
  "analysis": "Detailed 200-400 word analysis...",
  "failure_mode": "Progressive column failure",
  "recommendations": [
    "DO NOT ENTER structure",
    "Establish 50-foot perimeter",
    "Contact structural engineer",
    ...
  ],
  "immediate_actions": [...],
  "sora_prompt": "Detailed simulation prompt...",
  "confidence": "high"
}
```

### Physics-Based Video Generation

Creates realistic collapse simulations using OpenCV and ParaView:
- Engineering-focused visualizations
- Stress analysis heatmaps
- Progressive collapse sequences
- Safety zone overlays
- Downloadable for offline viewing

## Data Flow

```
1. User captures assessment (offline) → Local Hive DB
2. Images auto-compressed → < 2MB each
3. When online → Syncs to backend
4. Backend → GPT-4 analyzes photos
5. If high risk → Physics simulation generates video
6. Results → Synced back to app
7. User downloads video → Local storage
8. Available offline forever
```

## Security

- ✅ Secure key storage (flutter_secure_storage)
- ✅ Encrypted local database
- ✅ HTTPS only
- ✅ Input validation
- ✅ Conservative AI fallbacks

## What's Built

### Mobile (Flutter)
- [x] Project structure & dependencies
- [x] Data models with Hive
- [x] Local storage service
- [x] Camera service (with compression)
- [x] Video download service
- [x] Beautiful splash screen
- [x] Dashboard home screen
- [x] Smooth animations
- [x] Complete theming
- [ ] Assessment form screen
- [ ] Photo capture screen
- [ ] Results screen with video player
- [ ] Sync service
- [ ] API integration

### Backend (Python)
- [x] FastAPI structure
- [x] GPT-4 Vision service
- [x] Physics simulation video service
- [x] Health endpoints
- [ ] Assessment routes
- [ ] Analysis routes
- [ ] File upload handling
- [ ] Database integration
- [ ] S3 storage
