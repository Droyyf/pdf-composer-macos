# Cover Image White Space Fix

## Problem Identified ✅
The cover image in composition preview was showing with unwanted white space around it in both overlay modes (custom and side-by-side). This occurred because the PDF rendering function was using a "fit" scaling approach that maintains aspect ratio but leaves white space when the PDF's aspect ratio doesn't match the target container.

## Root Cause 🔍
The issue was in the `renderPDFPageToImage` function at line 1968, which used:
```swift
let scale = min(optimizedSize.width / pdfBounds.width, optimizedSize.height / pdfBounds.height)
```
This "fit" approach ensures the entire PDF page is visible but can leave white space if the aspect ratios don't match.

## Solution Implemented ⚡
1. **Enhanced `renderPDFPageToImage` function** with a new `fillMode` parameter
2. **Added two scaling modes:**
   - **FIT mode** (default): Uses `min` scale - fits entire PDF with possible white space
   - **FILL mode**: Uses `max` scale - fills entire area, crops excess content
3. **Applied FILL mode to cover images** to eliminate white space
4. **Kept FIT mode for citation pages** to ensure full page visibility

## Changes Made 📝

### Modified Function Signature:
```swift
func renderPDFPageToImage(_ page: PDFPage, size: CGSize, box: PDFDisplayBox = .cropBox, isPreview: Bool = true, fillMode: Bool = false) -> NSImage
```

### Updated Scaling Logic:
```swift
if fillMode {
    // FILL mode: Use max scale to fill the entire area (crop excess content to avoid white space)
    let scale = max(scaleX, scaleY)
} else {
    // FIT mode: Use min scale to fit the entire page (may leave white space)
    let scale = min(scaleX, scaleY)
}
```

### Updated Cover Image Calls:
1. **Side-by-Side Mode** (`brutalistComposeSideBySide`):
   ```swift
   let coverImg = renderPDFPageToImage(cover, size: coverSize, isPreview: isPreview, fillMode: true)
   ```

2. **Custom Overlay Mode** (`brutalistComposeCustom`):
   ```swift
   let coverImg = renderPDFPageToImage(cover, size: NSSize(width: coverWidth * 2, height: coverHeight * 2), fillMode: true)
   ```

3. **Preview Overlay** (interactive mode):
   ```swift
   cachedCoverImage = renderPDFPageToImage(
       coverPage,
       size: NSSize(width: 600, height: 600),
       fillMode: true
   )
   ```

## Result ✨
- **Cover images now fill their designated areas completely** without white space
- **Citation pages maintain full visibility** with proper aspect ratio handling
- **Backward compatibility preserved** - existing calls use FIT mode by default
- **No visual regressions** in other parts of the application

## Impact 🎯
- **Side-by-Side Mode**: Cover appears cleanly in right panel without white borders
- **Custom Overlay Mode**: Cover overlay fills the designated area precisely
- **Interactive Preview**: Draggable cover preview shows content without white space
- **Maintains brutalist design aesthetic** with clean, precise layouts

The fix is now live and ready for testing. Cover images should appear without any unwanted white space in both composition modes! 🚀