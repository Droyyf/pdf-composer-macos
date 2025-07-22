# Shortcuts Integration for PDF Composer

This directory contains the complete Shortcuts integration implementation for the PDF Composer macOS app, enabling users to automate PDF operations through the Shortcuts app.

## Overview

The integration provides three main intents that can be used in the Shortcuts app:

### 1. ComposePDFIntent
- **Purpose**: Compose multiple PDF files into a single document with optional cover image
- **Parameters**:
  - `pdfFiles`: Array of PDF files to combine
  - `coverImage`: Optional cover image (PNG, JPEG, TIFF, etc.)
  - `coverPlacement`: Position of cover (top, center, bottom, etc.)
  - `outputFileName`: Custom name for the result file
- **Output**: Composed PDF file with page count information

### 2. BatchProcessIntent  
- **Purpose**: Process multiple PDF files with optimization operations
- **Parameters**:
  - `pdfFiles`: Array of PDF files to process
  - `operations`: Array of operations (optimize, downsample, strip metadata, validate security)
  - `maxPPI`: Maximum PPI for downsampling (default: 300)
  - `outputDirectory`: Directory for processed files
- **Output**: Array of processed files with size savings information

### 3. ExportPDFIntent
- **Purpose**: Export PDF to various formats and destinations
- **Parameters**:
  - `pdfFile`: PDF file to export
  - `format`: Export format (PDF, PNG, JPEG, WebP)
  - `destination`: Export destination (Files, Desktop, Documents, Custom)
  - `customDirectory`: Custom directory path (when destination is Custom)
  - `quality`: Export quality (0.1 to 1.0, default: 0.9)
  - `outputFileName`: Custom output file name
- **Output**: Exported file with size information

## File Structure

```
PDF/Domain/Shortcuts/
├── ComposePDFIntent.intentdefinition          # Intent definition for PDF composition
├── BatchProcessIntent.intentdefinition        # Intent definition for batch processing
├── ExportPDFIntent.intentdefinition          # Intent definition for PDF export
├── ComposePDFIntentHandler.swift             # Handler for composition intent
├── BatchProcessIntentHandler.swift           # Handler for batch processing intent
├── ExportPDFIntentHandler.swift              # Handler for export intent
├── ShortcutsIntegration.swift                # Main integration coordinator
├── SharedUtilities.swift                     # Shared utilities for app and extension
└── README.md                                 # This documentation

IntentsExtension/
├── IntentHandler.swift                       # Main extension handler
├── Info.plist                               # Extension configuration
└── IntentsExtension.entitlements            # Extension entitlements
```

## Integration with Existing Services

The Shortcuts integration seamlessly integrates with existing app services:

- **PDFService**: Used for opening PDFs, generating thumbnails, and exporting files
- **Composer**: Used for merging PDFs with cover images and optimization
- **ThumbnailCache**: Provides efficient thumbnail generation and caching
- **SettingsStore**: Accesses user preferences for default settings

## Setup and Configuration

### 1. Xcode Project Configuration

Add the IntentsExtension target to your Xcode project with:
- Product Name: "IntentsExtension"
- Bundle Identifier: "com.yourcompany.pdf.IntentsExtension"
- Language: Swift
- Target iOS/macOS version: 11.0+

### 2. Build Settings

Ensure the following build settings:
- Enable App Sandbox: YES
- File Access: User Selected Files (Read/Write)
- Entitlements: Include Siri capability

### 3. Info.plist Updates

The main app's Info.plist has been updated with:
- `INIntentsSupported`: List of supported intents
- `NSUserActivityTypes`: User activity types for intent discovery
- `NSShortcutsAppName`: Display name in Shortcuts app

## Usage Examples

### Compose PDFs with Cover
```
1. Add "Compose PDF" action from PDF Composer app
2. Select PDF files to combine
3. Optionally add a cover image
4. Choose cover placement
5. Set output filename
```

### Batch Process PDFs
```  
1. Add "Batch Process PDFs" action
2. Select multiple PDF files
3. Choose operations (optimize, downsample, etc.)
4. Set maximum PPI for downsampling
5. Choose output directory
```

### Export PDF
```
1. Add "Export PDF" action
2. Select source PDF file
3. Choose export format (PNG, JPEG, etc.)
4. Select destination
5. Adjust quality settings
```

## Error Handling

All intent handlers include comprehensive error handling:
- File access validation
- Format compatibility checks
- Memory limit enforcement
- Security-scoped resource management
- User-friendly error messages

## Security Considerations

- Security-scoped resource access for file operations
- Sandboxed execution environment
- App group sharing for data exchange
- Restricted background execution for large operations

## Performance Optimizations

- Async/await for non-blocking operations
- Memory-efficient processing with autoreleasepool
- Background queue execution for intensive tasks
- Progress tracking for batch operations
- Proper resource cleanup and memory management

## Testing

To test the Shortcuts integration:

1. Build and run the app with the IntentsExtension
2. Open Shortcuts app
3. Create new shortcut
4. Search for "PDF Composer" actions
5. Configure and test each intent type

## Troubleshooting

### Common Issues

1. **Intents not appearing in Shortcuts app**
   - Verify Info.plist configuration
   - Check that extension is properly built and signed
   - Restart Shortcuts app

2. **File access denied errors**
   - Ensure security-scoped resource access is properly implemented
   - Check app entitlements include file access permissions
   - Verify user has granted necessary permissions

3. **Memory issues with large files**
   - Check memory management in intent handlers
   - Verify autoreleasepool usage for large operations
   - Monitor memory usage during batch processing

### Debug Logging

Enable debug logging in intent handlers by setting appropriate log levels in the IntentHandler.log() method.

## Future Enhancements

Potential improvements for future versions:
- Advanced PDF manipulation operations
- OCR text extraction capabilities  
- Metadata editing and management
- Cloud service integration
- Custom workflow templates
- Batch renaming and organization features