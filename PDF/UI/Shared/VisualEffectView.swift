import SwiftUI
import AppKit

/// A SwiftUI wrapper for NSVisualEffectView to provide system material effects with brutalist styling
public struct BrutalistVisualEffectView: NSViewRepresentable {
    /// The material style to apply
    public enum Material {
        case titlebar
        case selection
        case menu
        case popover
        case sidebar
        case headerView
        case sheet
        case windowBackground
        case hudWindow
        case fullScreenUI
        case toolTip
        case contentBackground
        case underWindowBackground
        case underPageBackground

        /// Convert to NSVisualEffectView.Material
        fileprivate func toNSVisualEffectMaterial() -> NSVisualEffectView.Material {
            switch self {
            case .titlebar:
                return .titlebar
            case .selection:
                return .selection
            case .menu:
                return .menu
            case .popover:
                return .popover
            case .sidebar:
                return .sidebar
            case .headerView:
                return .headerView
            case .sheet:
                return .sheet
            case .windowBackground:
                return .windowBackground
            case .hudWindow:
                return .hudWindow
            case .fullScreenUI:
                return .fullScreenUI
            case .toolTip:
                return .toolTip
            case .contentBackground:
                return .contentBackground
            case .underWindowBackground:
                return .underWindowBackground
            case .underPageBackground:
                return .underPageBackground
            }
        }
    }

    /// The blending mode to use
    public enum BlendingMode {
        case behindWindow
        case withinWindow

        /// Convert to NSVisualEffectView.BlendingMode
        fileprivate func toNSVisualEffectBlendingMode() -> NSVisualEffectView.BlendingMode {
            switch self {
            case .behindWindow:
                return .behindWindow
            case .withinWindow:
                return .withinWindow
            }
        }
    }

    private let material: Material
    private let blendingMode: BlendingMode
    private let isEmphasized: Bool
    private let addNoise: Bool
    private let noiseIntensity: CGFloat
    private let cornerRadius: CGFloat

    /// Initialize a VisualEffectView with the specified material and blending mode
    /// - Parameters:
    ///   - material: The material style to use
    ///   - blendingMode: The blending mode to apply
    ///   - emphasized: Whether the effect should be emphasized
    ///   - addNoise: Whether to add a noise texture overlay
    ///   - noiseIntensity: The intensity of the noise (0.0-1.0)
    ///   - cornerRadius: Corner radius for the view
    public init(
        material: Material,
        blendingMode: BlendingMode = .behindWindow,
        emphasized: Bool = false,
        addNoise: Bool = true,
        noiseIntensity: CGFloat = 0.12,
        cornerRadius: CGFloat = 0
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = emphasized
        self.addNoise = addNoise
        self.noiseIntensity = noiseIntensity
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        if cornerRadius > 0 {
            container.layer?.cornerRadius = cornerRadius
            container.layer?.masksToBounds = true
        }

        // Create the visual effect view
        let visualEffectView = NSVisualEffectView(frame: container.bounds)
        visualEffectView.material = material.toNSVisualEffectMaterial()
        visualEffectView.blendingMode = blendingMode.toNSVisualEffectBlendingMode()
        visualEffectView.state = .active
        visualEffectView.isEmphasized = isEmphasized
        visualEffectView.wantsLayer = true
        visualEffectView.autoresizingMask = [.width, .height]

        if cornerRadius > 0 {
            visualEffectView.layer?.cornerRadius = cornerRadius
            visualEffectView.layer?.masksToBounds = true
        }

        container.addSubview(visualEffectView)

        // Add noise texture if requested
        if addNoise, let noiseImage = NSImage(named: "noise") {
            let noiseView = NSImageView(image: noiseImage)
            noiseView.imageScaling = .scaleAxesIndependently
            noiseView.alphaValue = noiseIntensity
            noiseView.wantsLayer = true
            noiseView.layer?.compositingFilter = "overlayBlendMode"
            noiseView.autoresizingMask = [.width, .height]

            if cornerRadius > 0 {
                noiseView.layer?.cornerRadius = cornerRadius
                noiseView.layer?.masksToBounds = true
            }

            visualEffectView.addSubview(noiseView)
        }

        return container
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        guard let visualEffectView = nsView.subviews.first as? NSVisualEffectView else { return }

        visualEffectView.material = material.toNSVisualEffectMaterial()
        visualEffectView.blendingMode = blendingMode.toNSVisualEffectBlendingMode()
        visualEffectView.isEmphasized = isEmphasized

        // Update noise overlay intensity if it exists
        if addNoise, let noiseView = visualEffectView.subviews.first as? NSImageView {
            noiseView.alphaValue = noiseIntensity
        }
    }
}

#if DEBUG
struct BrutalistVisualEffectView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Window Background")
                .foregroundColor(.white)
                .padding()
                .background(BrutalistVisualEffectView(material: .windowBackground))

            Text("HUD Window with Noise")
                .foregroundColor(.white)
                .padding()
                .background(BrutalistVisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    addNoise: true,
                    noiseIntensity: 0.15,
                    cornerRadius: 8
                ))

            Text("Sidebar with Rounded Corners")
                .foregroundColor(.white)
                .padding()
                .background(BrutalistVisualEffectView(
                    material: .sidebar,
                    cornerRadius: 12
                ))

            Text("Emphasized Content")
                .foregroundColor(.white)
                .padding()
                .background(BrutalistVisualEffectView(
                    material: .contentBackground,
                    emphasized: true,
                    noiseIntensity: 0.2
                ))
        }
        .frame(width: 300, height: 400)
        .padding(40)
        .background(Color.black)
    }
}
#endif
