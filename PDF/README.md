# AlmostBrutal

A macOS-native, Swiss-Brutalist PDF composer built with Swift 5.9, SwiftUI, PDFKit, Combine, and Swift Concurrency.

## Requirements
- macOS 12+
- Xcode 15+

## Build & Run
1. Clone the repo.
2. Open `AlmostBrutal.xcodeproj` in Xcode.
3. Build and run (⌘R).

## Features
- Open and preview multi-page PDFs
- Thumbnail grid sidebar with multi-select
- Compose citation sheets with optional cover
- Export to PDF, PNG, JPEG, WebP
- Batch optimisation (down-sample >300 PPI, strip metadata)
- Toast notifications
- JSON-backed settings
- LRU thumbnail cache (100 pages, <25MB RAM)
- Performance guardrails for large PDFs

## Testing
Run all tests:
```
xcodebuild test -scheme AlmostBrutal -destination 'platform=macOS'
```

## Notarisation (CI/CD)
Automate build, codesign, notarise, and staple:

```
fastlane run mac_notarize \
  app_path:"/path/to/AlmostBrutal.app" \
  apple_id:"your@appleid.com" \
  team_id:"YOUR_TEAM_ID" \
  api_key_path:"/path/to/AuthKey.p8"
```

## Fonts & Assets
- Inter Variable (UI body)
- Söhne Mono Variable (labels, numeric UI)
- noise.png (512x512 seamless)

## Folder Structure
```
AlmostBrutal/
 ├─ AlmostBrutalApp.swift
 ├─ Domain/
 │   ├─ PDFService.swift
 │   ├─ Composer.swift
 │   ├─ ThumbnailCache.swift
 │   └─ SettingsStore.swift
 ├─ UI/
 │   ├─ AppShell.swift
 │   ├─ Sidebar/ThumbnailSidebar.swift
 │   ├─ Editor/PDFEditorView.swift
 │   ├─ Preview/PreviewSheet.swift
 │   └─ Shared/
 │       ├─ GlassBackground.swift
 │       ├─ NoisyOverlay.swift
 │       └─ ToastStack.swift
 ├─ Resources/
 │   ├─ noise.png
 │   ├─ Inter-Variable.ttf
 │   └─ SohneMono-Variable.ttf
 └─ Tests/ComposerTests.swift
```

## License
Copyright (c) 2024. All rights reserved.
