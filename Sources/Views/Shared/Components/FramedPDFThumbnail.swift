import SwiftUI

/// Configuration for different frame styles
struct FrameConfig: Equatable {
    /// Relative size of content area compared to the overall frame
    let contentScale: CGFloat
    /// X-offset (horizontal) of content within the frame as a percentage of frame width
    let contentOffsetX: CGFloat
    /// Y-offset (vertical) of content within the frame as a percentage of frame height
    let contentOffsetY: CGFloat
    /// Aspect ratio of the frame (width / height)
    let aspectRatio: CGFloat

    // Preset configurations
    static let ornateClassicFrame = FrameConfig(
        contentScale: 0.65,    // Content takes up 65% of the frame size
        contentOffsetX: 0.0,   // Centered horizontally
        contentOffsetY: 0.0,   // Centered vertically
        aspectRatio: 0.7       // Slightly taller than wide
    )

    // Configuration specifically for the ornate brown/gold frame shown in the image
    static let ornateGoldFrame = FrameConfig(
        contentScale: 0.42,     // Reduced to fit within the visible window area
        contentOffsetX: 0.0,    // Centered horizontally
        contentOffsetY: -0.01,  // Slight upward adjustment
        aspectRatio: 0.7        // Similar to the classic frame
    )

    // Configuration for the left page of an open book-style frame
    static let ornateGoldFrameLeftPage = FrameConfig(
        contentScale: 0.42,     // Reduced to fit within the visible window area
        contentOffsetX: -0.005, // Slight adjustment toward spine
        contentOffsetY: -0.01,  // Slight upward adjustment
        aspectRatio: 0.7
    )

    // Configuration for the right page of an open book-style frame
    static let ornateGoldFrameRightPage = FrameConfig(
        contentScale: 0.42,     // Reduced to fit within the visible window area
        contentOffsetX: 0.005,  // Slight adjustment toward spine
        contentOffsetY: -0.01,  // Slight upward adjustment
        aspectRatio: 0.7
    )
}

struct FramedPDFThumbnail: View {
    let pdfImage: Image
    let frameImage: Image
    let config: FrameConfig
    let size: CGSize
    let showDebug: Bool

    init(pdfImage: Image,
         frameImage: Image,
         config: FrameConfig = .ornateGoldFrame,
         size: CGSize = CGSize(width: 300, height: 420),
         showDebug: Bool = false) {
        self.pdfImage = pdfImage
        self.frameImage = frameImage
        self.config = config
        self.size = size
        self.showDebug = showDebug
    }

    var body: some View {
        ZStack {
            // Debug background to make it visible
            if showDebug {
                Color.gray.opacity(0.3)
                    .frame(width: size.width, height: size.height)
            }

            // Frame image
            frameImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)

            // PDF content positioned precisely in the frame's content area
            pdfImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: size.width * config.contentScale,
                    height: size.height * config.contentScale
                )
                .offset(
                    x: size.width * config.contentOffsetX,
                    y: size.height * config.contentOffsetY
                )
                .clipShape(Rectangle())
                .border(showDebug ? Color.red : Color.clear, width: 2)
        }
        .frame(width: size.width, height: size.height)
    }
}

// Helper extension
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Example of usage in a side-by-side layout
struct SideBySideFramedView: View {
    let leftImage: Image
    let rightImage: Image
    let frameImage: Image
    let showDebug: Bool

    init(leftImage: Image, rightImage: Image, frameImage: Image, showDebug: Bool = false) {
        self.leftImage = leftImage
        self.rightImage = rightImage
        self.frameImage = frameImage
        self.showDebug = showDebug
    }

    var body: some View {
        HStack(spacing: 0) {
            FramedPDFThumbnail(
                pdfImage: leftImage,
                frameImage: frameImage,
                config: .ornateGoldFrameLeftPage,
                size: CGSize(width: 300, height: 420),
                showDebug: showDebug
            )

            FramedPDFThumbnail(
                pdfImage: rightImage,
                frameImage: frameImage,
                config: .ornateGoldFrameRightPage,
                size: CGSize(width: 300, height: 420),
                showDebug: showDebug
            )
        }
    }
}

#Preview("Normal") {
    SideBySideFramedView(
        leftImage: Image(systemName: "doc.text.fill"),
        rightImage: Image(systemName: "doc.text.fill"),
        frameImage: Image("Frames/GoldOrnateFrame")
    )
}

#Preview("Debug") {
    SideBySideFramedView(
        leftImage: Image(systemName: "doc.text.fill"),
        rightImage: Image(systemName: "doc.text.fill"),
        frameImage: Image("Frames/GoldOrnateFrame"),
        showDebug: true
    )
}
