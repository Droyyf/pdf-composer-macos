# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building
```bash
# Open project in Xcode
open PDF.xcodeproj

# Build from command line
xcodebuild -project PDF.xcodeproj -scheme PDF -configuration Release clean build
```

### Testing
```bash
# Run all tests
xcodebuild test -scheme PDF -destination 'platform=macOS'
```

### Distribution (CI/CD)
```bash
# Build, codesign, notarize and staple using Fastlane
fastlane run mac_notarize \
  app_path:"/path/to/PDF.app" \
  apple_id:"your@appleid.com" \
  team_id:"YOUR_TEAM_ID" \
  api_key_path:"/path/to/AuthKey.p8"
```

## Project Structure and Architecture

This is a macOS-native PDF composer app built with Swift 5.9, SwiftUI, PDFKit, and Metal. The app follows a brutalist design aesthetic with custom window management and visual effects.

### Core Architecture
- **Domain Layer**: Business logic for PDF operations, composition, caching, and settings
- **UI Layer**: SwiftUI views organized by feature with shared components  
- **Metal Rendering**: Custom background shaders and visual effects
- **Custom Window Management**: Borderless window with draggable areas and visual effects

### Key Components

#### Domain (`PDF/Domain/`)
- `PDFService.swift`: Actor-based PDF operations with memory-efficient thumbnail caching (100MB limit)
- `Composer.swift`: PDF merging and composition with cover placement options
- `ThumbnailCache.swift`: LRU cache for PDF page thumbnails with async generation
- `SettingsStore.swift`: JSON-backed persistent settings using Observable pattern

#### UI (`PDF/UI/`)
- `AppShell.swift`: Main app coordinator with scene management and state
- `BrutalistAppShell.swift`: Primary PDF editing interface
- `BrutalistPreviewView.swift`: Preview interface for composed PDFs
- `MainMenuView.swift`: Landing screen with file selection
- `PageSelectionView.swift`: Multi-select interface for citation pages
- `AppCommands.swift`: Menu bar and keyboard shortcut handlers

#### Shared UI Components (`PDF/UI/Shared/`)
- Brutalist design system with custom shapes, textures, and typography
- Glass background effects and noise overlays
- Toast notification system
- Custom draggable window areas

#### Custom Window System (`PDFApp.swift`)
- `FullContentWindow`: Borderless window with keyboard shortcut handling
- `AppWindowController`: Custom window setup with visual effects and texture overlays
- `DraggableTopBarView`: Custom draggable area for window movement

### Key Features
- Multi-page PDF preview with thumbnail sidebar
- Citation sheet composition with optional cover placement
- Export to PDF, PNG, JPEG, WebP formats
- Batch optimization (downsample >300 PPI, strip metadata)  
- Performance guardrails for large PDFs (>100 pages)
- Memory-efficient thumbnail generation with priority queues

### Design System
- **Fonts**: Inter Variable (UI), Söhne Mono Variable (labels/numeric)
- **Visual Effects**: Metal-based background shaders, noise textures, glass backgrounds
- **Color Scheme**: Dark-first brutalist aesthetic with texture overlays
- **Layout**: Asymmetric rounded rectangles, brutal typography, texture-heavy components

### Settings and Persistence
- Settings stored as JSON in `~/Library/Application Support/AlmostBrutal/settings.json`
- Thumbnail cache managed with LRU eviction and memory limits
- Security-scoped resource access for file operations

### Performance Considerations
- Async thumbnail generation with priority queues
- Memory-efficient PDF processing using autoreleasepool
- Viewport-based thumbnail preloading
- Metal rendering for smooth background effects
- Task-based concurrency with proper memory management

## GitHub Repository Management

**Repository**: https://github.com/Droyyf/pdf-composer-macos (Private)

### Branch Workflow Rules
When working on this PDF project, Claude Code must follow this GitHub workflow:

1. **MANDATORY: All edits go to feature branches** - NEVER commit directly to main
2. **Always push to variant branches** - Every edit must be pushed to a feature branch first
3. **Descriptive branch names** - Use format: `feature/description-of-edit` (e.g., `feature/fix-layout-responsiveness`, `feature/add-export-formats`)
4. **Descriptive commit messages** - Each commit should clearly describe what was changed and why
5. **Required workflow for EVERY edit**:
   ```bash
   # Create descriptive feature branch for each edit
   git checkout -b feature/your-edit-description
   
   # Make changes and commit with clear message
   git add .
   git commit -m "Descriptive commit message explaining the change"
   
   # ALWAYS push to feature branch immediately after each edit
   git push -u origin feature/your-edit-description
   ```
6. **Wait for user approval** - Only merge to main when user explicitly says "everything is okay" or "go ahead"
7. **Revert capability** - If user says "revert", checkout the last known good branch before the problematic changes
8. **Branch cleanup** - Delete feature branches only after successful merge to main and user confirmation

### Current Setup
- Main branch contains the complete, working codebase
- Feature branches are used for all development work
- Repository is private for project security