import SwiftUI
import AppKit

/// A SwiftUI wrapper for an AppKit-based noisy overlay with better performance
struct NoisyOverlay: NSViewRepresentable {
    var intensity: CGFloat = 1.0
    var asymmetric: Bool = true
    var blendingMode: String = "overlayBlendMode"

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

                // Base noise layer
        if let noiseImage = NSImage(named: "noise") {
            let baseNoiseView = NSImageView(image: noiseImage)
            baseNoiseView.imageScaling = .scaleAxesIndependently
            baseNoiseView.alphaValue = 0.25 * intensity
            baseNoiseView.wantsLayer = true
            baseNoiseView.layer?.compositingFilter = blendingMode
            baseNoiseView.autoresizingMask = [.width, .height]
            container.addSubview(baseNoiseView)

            // Apply contrast adjustment
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(1.6, forKey: "inputContrast")
                baseNoiseView.contentFilters = [contrastFilter]
            }
        }

        // Create grain effect layer
        let grainLayer = CALayer()
        grainLayer.backgroundColor = NSColor.clear.cgColor
        grainLayer.frame = container.bounds
        grainLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        container.layer?.addSublayer(grainLayer)

        // Add grain dots programmatically
        addGrainDots(to: grainLayer, intensity: intensity)

        // Add asymmetric elements if requested
                if asymmetric {
                    // Stronger grain in top left
            let topLeftView = NSView(frame: NSRect(
                x: 0,
                y: container.bounds.height * 0.6,
                width: container.bounds.width * 0.5,
                height: container.bounds.height * 0.4
            ))
            topLeftView.wantsLayer = true
            topLeftView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04 * intensity).cgColor
            topLeftView.layer?.compositingFilter = "overlayBlendMode"
            topLeftView.autoresizingMask = [.width, .height]
            container.addSubview(topLeftView)

                    // Darker grain in bottom right
            let bottomRightView = NSView(frame: NSRect(
                x: container.bounds.width * 0.4,
                y: 0,
                width: container.bounds.width * 0.6,
                height: container.bounds.height * 0.3
            ))
            bottomRightView.wantsLayer = true
            bottomRightView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05 * intensity).cgColor
            bottomRightView.layer?.compositingFilter = "multiplyBlendMode"
            bottomRightView.autoresizingMask = [.width, .height]
            container.addSubview(bottomRightView)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update intensity if needed
        for subview in nsView.subviews {
            if let imageView = subview as? NSImageView {
                imageView.alphaValue = 0.2 * intensity
            }
        }
    }

    private func addGrainDots(to layer: CALayer, intensity: CGFloat) {
        // Calculate number of dots based on layer size
        let width = layer.bounds.width
        let height = layer.bounds.height
        let dotCount = Int(width * height / 100)

        for _ in 0..<dotCount {
            let dotLayer = CALayer()
            let size = CGFloat.random(in: 0.7...1.5)
            let x = CGFloat.random(in: 0..<width)
            let y = CGFloat.random(in: 0..<height)
            let opacity = CGFloat.random(in: 0.15...0.3) * intensity

            dotLayer.frame = CGRect(x: x, y: y, width: size, height: size)
            dotLayer.cornerRadius = size / 2
            dotLayer.backgroundColor = NSColor.white.withAlphaComponent(opacity).cgColor

            layer.addSublayer(dotLayer)
        }
    }
}

/// Terminal-style animated noise background using AppKit
struct TerminalNoiseBackground: NSViewRepresentable {
    var opacity: CGFloat = 0.8
    var intensity: CGFloat = 1.0

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

                // Terminal background color
        container.layer?.backgroundColor = NSColor(DesignTokens.brutalistBlack).withAlphaComponent(opacity).cgColor

                // Primary noise layer
        if let noiseImage = NSImage(named: "noise") {
            let baseNoiseView = NSImageView(image: noiseImage)
            baseNoiseView.imageScaling = .scaleAxesIndependently
            baseNoiseView.alphaValue = 0.25 * intensity
            baseNoiseView.wantsLayer = true
            baseNoiseView.layer?.compositingFilter = "overlayBlendMode"
            baseNoiseView.autoresizingMask = [.width, .height]
            container.addSubview(baseNoiseView)

            // Apply contrast adjustment
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(1.7, forKey: "inputContrast")
                baseNoiseView.contentFilters = [contrastFilter]
            }
        }

        // Animated noise layer
        if let noiseImage = NSImage(named: "noise") {
            let animatedNoiseView = NSImageView(image: noiseImage)
            animatedNoiseView.imageScaling = .scaleAxesIndependently
            animatedNoiseView.alphaValue = 0.15 * intensity
            animatedNoiseView.wantsLayer = true
            animatedNoiseView.layer?.compositingFilter = "overlayBlendMode"
            animatedNoiseView.autoresizingMask = [.width, .height]
            container.addSubview(animatedNoiseView)

            // Add animation
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = NSValue(point: NSPoint(x: -10, y: -10))
            animation.toValue = NSValue(point: NSPoint(x: 10, y: 10))
            animation.duration = 8.0
            animation.autoreverses = true
            animation.repeatCount = Float.infinity
            animatedNoiseView.layer?.add(animation, forKey: "noiseMovement")
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update opacity and intensity if needed
        nsView.layer?.backgroundColor = NSColor(DesignTokens.brutalistBlack).withAlphaComponent(opacity).cgColor

        if let baseNoiseView = nsView.subviews.first as? NSImageView {
            baseNoiseView.alphaValue = 0.25 * intensity
        }

        if nsView.subviews.count > 1, let animatedNoiseView = nsView.subviews[1] as? NSImageView {
            animatedNoiseView.alphaValue = 0.15 * intensity
        }
    }
}

// Additional brutalist texture component
struct BrutalistTextureView: NSViewRepresentable {
    var intensity: CGFloat = 1.0

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // Base visual effect
        let visualEffectView = NSVisualEffectView(frame: container.bounds)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        container.addSubview(visualEffectView)

        // Add multiple noise layers for depth
        if let noiseImage = NSImage(named: "noise") {
            // First noise layer
            let noiseView1 = NSImageView(image: noiseImage)
            noiseView1.imageScaling = .scaleAxesIndependently
            // Significantly increased alpha for more visible internal panel texture
            noiseView1.alphaValue = 0.45 * intensity
            noiseView1.wantsLayer = true
            noiseView1.layer?.compositingFilter = "softLightBlendMode"
            noiseView1.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(noiseView1)

            // Second noise layer with different blending
            let noiseView2 = NSImageView(image: noiseImage)
            noiseView2.imageScaling = .scaleAxesIndependently
            // Significantly increased alpha for more visible internal panel texture
            noiseView2.alphaValue = 0.35 * intensity
            noiseView2.wantsLayer = true
            noiseView2.layer?.compositingFilter = "overlayBlendMode"
            noiseView2.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(noiseView2)

            // Apply contrast to second layer
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(1.8, forKey: "inputContrast")
                noiseView2.contentFilters = [contrastFilter]
            }
        }

        // Add AccentTexture5 as an additional overlay layer for better grain visibility
        if let accentTexture = NSImage(named: "AccentTexture5") {
            let accentView = NSImageView(image: accentTexture)
            accentView.imageScaling = .scaleAxesIndependently
            accentView.alphaValue = 0.4 * intensity
            accentView.wantsLayer = true
            accentView.layer?.compositingFilter = "overlayBlendMode"
            accentView.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(accentView)
            
            // Apply contrast filter for better texture definition
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(1.5, forKey: "inputContrast")
                contrastFilter.setValue(1.2, forKey: "inputSaturation")
                accentView.contentFilters = [contrastFilter]
            }
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update intensity if needed
        nsView.subviews.forEach { subview in
            if let visualEffectView = subview as? NSVisualEffectView {
                visualEffectView.subviews.enumerated().forEach { index, noiseView in
                    if let imageView = noiseView as? NSImageView {
                        // Ensure updateNSView matches the new alpha values
                        switch index {
                        case 0: imageView.alphaValue = 0.45 * intensity // First noise layer
                        case 1: imageView.alphaValue = 0.35 * intensity // Second noise layer
                        case 2: imageView.alphaValue = 0.4 * intensity  // AccentTexture5 layer
                        default: imageView.alphaValue = 0.3 * intensity
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black

        VStack(spacing: 20) {
            Text("Standard Noisy Overlay")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(NoisyOverlay())
                )

            Text("Intense Brutalist Overlay")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(NoisyOverlay(intensity: 2.0))
                )

            Text("Terminal Background")
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(TerminalNoiseBackground())

            Text("Brutalist Texture")
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(BrutalistTextureView(intensity: 1.2))
        }
        .padding(40)
    }
    .ignoresSafeArea()
}
