import SwiftUI

struct DebugFramedPDFView: View {
    @State private var selectedConfig: FrameConfig = .ornateGoldFrame
    @State private var contentScale: CGFloat = 0.42
    @State private var contentOffsetX: CGFloat = 0.0
    @State private var contentOffsetY: CGFloat = -0.01

    var customConfig: FrameConfig {
        FrameConfig(
            contentScale: contentScale,
            contentOffsetX: contentOffsetX,
            contentOffsetY: contentOffsetY,
            aspectRatio: 0.7
        )
    }

    var body: some View {
        VStack {
            // Preview area
            ScrollView {
                VStack(spacing: 20) {
                    // Standard configuration
                    Text("Standard Configuration")
                        .font(.headline)

                    FramedPDFThumbnail(
                        pdfImage: Image(systemName: "doc.text.fill"),
                        frameImage: Image("Frames/GoldOrnateFrame"),
                        config: selectedConfig,
                        showDebug: true
                    )

                    Divider()

                    // Custom configuration
                    Text("Custom Configuration")
                        .font(.headline)

                    FramedPDFThumbnail(
                        pdfImage: Image(systemName: "doc.text.fill"),
                        frameImage: Image("Frames/GoldOrnateFrame"),
                        config: customConfig,
                        showDebug: true
                    )

                    Divider()

                    // Side by side
                    Text("Side by Side View")
                        .font(.headline)

                    SideBySideFramedView(
                        leftImage: Image(systemName: "doc.text.fill"),
                        rightImage: Image(systemName: "doc.text.fill"),
                        frameImage: Image("Frames/GoldOrnateFrame"),
                        showDebug: true
                    )
                }
                .padding()
            }

            // Controls
            VStack {
                // Configuration selector
                Picker("Configuration", selection: $selectedConfig) {
                    Text("Gold Frame").tag(FrameConfig.ornateGoldFrame)
                    Text("Left Page").tag(FrameConfig.ornateGoldFrameLeftPage)
                    Text("Right Page").tag(FrameConfig.ornateGoldFrameRightPage)
                }
                .pickerStyle(.segmented)

                // Custom sliders
                VStack(alignment: .leading, spacing: 10) {
                    Text("Custom Settings").font(.headline)

                    HStack {
                        Text("Scale:")
                        Slider(value: $contentScale, in: 0.3...0.7, step: 0.01)
                        Text(String(format: "%.2f", contentScale))
                    }

                    HStack {
                        Text("X Offset:")
                        Slider(value: $contentOffsetX, in: -0.1...0.1, step: 0.005)
                        Text(String(format: "%.3f", contentOffsetX))
                    }

                    HStack {
                        Text("Y Offset:")
                        Slider(value: $contentOffsetY, in: -0.1...0.1, step: 0.005)
                        Text(String(format: "%.3f", contentOffsetY))
                    }
                }
                .padding()
            }
            .padding(.bottom)
        }
    }
}

#Preview {
    DebugFramedPDFView()
}
