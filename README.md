# PDF Composer

A brutalist-designed macOS PDF composition and editing application built with SwiftUI, PDFKit, and Metal rendering.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue.svg)
![License](https://img.shields.io/badge/License-Private-red.svg)

## 🎯 Overview

PDF Composer is a modern macOS application that reimagines PDF editing with a brutalist design aesthetic. Built for power users who need efficient PDF manipulation with a distinctive visual experience.

### ✨ Key Features

- **🔄 PDF Composition** - Merge multiple PDFs with intelligent page selection
- **📄 Citation Management** - Compose citation sheets with optional cover placement
- **🖼️ Multi-Format Export** - Export to PDF, PNG, JPEG, and WebP formats
- **⚡ Performance Optimized** - Memory-efficient processing with thumbnail caching
- **🎨 Brutalist Design** - Custom Metal-rendered backgrounds with heavy grain textures
- **🪟 Custom Window Management** - Borderless windows with draggable areas

## 🏗️ Architecture

### Tech Stack
- **Frontend**: SwiftUI with custom AppKit integration
- **PDF Processing**: PDFKit with actor-based concurrency
- **Rendering**: Metal shaders for background effects
- **Persistence**: JSON-backed settings with security-scoped resources
- **Design**: Custom brutalist design system with noise textures

### Core Components
- **Domain Layer**: Actor-based PDF operations with memory management
- **UI Layer**: Feature-organized SwiftUI views with shared components
- **Metal Pipeline**: Custom background shaders and visual effects
- **Window System**: Borderless window management with visual effects

## 🚀 Getting Started

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9

### Building from Source

```bash
# Clone the repository
git clone https://github.com/Droyyf/pdf-composer-macos.git
cd pdf-composer-macos

# Open in Xcode
open PDF.xcodeproj

# Or build from command line
xcodebuild -project PDF.xcodeproj -scheme PDF -configuration Release clean build
```

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme PDF -destination 'platform=macOS'
```

## 🎨 Design System

### Visual Identity
- **Typography**: Inter Variable (UI), Söhne Mono Variable (labels/numeric)
- **Color Scheme**: Dark-first brutalist aesthetic with texture overlays
- **Effects**: Heavy grain textures, glass backgrounds, Metal-rendered noise
- **Layout**: Asymmetric rounded rectangles with brutal typography

### UI Components
- Custom brutalist cards with hover effects
- Draggable window areas with visual feedback
- Toast notification system
- Multi-select page interfaces
- Glass background effects with noise overlays

## ⚙️ Configuration

Settings are automatically stored in:
```
~/Library/Application Support/AlmostBrutal/settings.json
```

### Performance Settings
- **Thumbnail Cache**: 100MB memory limit with LRU eviction
- **Large PDF Handling**: Performance guardrails for >100 pages
- **Export Quality**: Configurable downsampling for >300 PPI images

## 🔧 Development

### Project Structure
```
PDF/
├── Domain/                 # Business logic and services
│   ├── PDFService.swift   # Actor-based PDF operations
│   ├── Composer.swift     # PDF composition logic
│   └── ThumbnailCache.swift # Memory-efficient caching
├── UI/                    # SwiftUI interface
│   ├── AppShell.swift     # Main coordinator
│   ├── BrutalistAppShell.swift # PDF editing interface
│   └── Shared/            # Reusable components
└── Resources/             # Assets and textures
```

### Key Design Patterns
- **Actor-based Concurrency**: Safe PDF processing with memory management
- **Observable Pattern**: Reactive state management with SwiftUI
- **Security-scoped Resources**: Proper file access handling
- **Memory Management**: Autoreleasepool for efficient PDF processing

## 🚦 Performance

### Optimizations
- Async thumbnail generation with priority queues
- Viewport-based preloading for smooth scrolling
- Memory-efficient PDF processing with autoreleasepool
- Metal rendering for 60fps background effects
- LRU cache with automatic memory management

### Benchmarks
- **Thumbnail Generation**: ~50ms per page (average)
- **Memory Usage**: <100MB cache limit maintained
- **Export Speed**: ~2s for 50-page composition
- **UI Responsiveness**: 60fps with Metal backgrounds

## 🔒 Security

- Security-scoped resource access for file operations
- Metadata stripping during export
- No telemetry or external network requests
- Sandboxed application architecture

## 📋 Requirements

### System Requirements
- macOS 13.0 (Ventura) or later
- 8GB RAM minimum (16GB recommended for large PDFs)
- Metal-compatible GPU for visual effects
- 500MB free disk space

### Supported Formats
- **Import**: PDF
- **Export**: PDF, PNG, JPEG, WebP
- **Optimization**: Automatic downsampling and metadata removal

## 🤝 Contributing

This is a private repository. For internal development:

1. Create feature branches for all changes
2. Follow the established brutalist design patterns
3. Ensure all tests pass before merging
4. Update documentation for new features

### Branch Workflow
```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and commit
git commit -m "Descriptive commit message"

# Push to feature branch
git push -u origin feature/your-feature-name
```

## 📄 License

This project is proprietary software. All rights reserved.

## 🔗 Links

- **Repository**: [pdf-composer-macos](https://github.com/Droyyf/pdf-composer-macos) (Private)
- **Documentation**: See `CLAUDE.md` for development guidelines
- **Design System**: Built-in brutalist components with Metal rendering

---

<p align="center">
  <strong>Built with ❤️ and brutalist design principles</strong>
</p>