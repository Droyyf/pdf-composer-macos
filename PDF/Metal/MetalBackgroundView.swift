import SwiftUI
import MetalKit

struct MetalBackgroundView: NSViewRepresentable {
    @Binding var blur: Float
    @Binding var noise: Float
    @Binding var grain: Float
    @Binding var textureMix: Float
    @Binding var colorTint: Color
    @Binding var vignette: Float
    var texture: MTLTexture? = MetalBackgroundView.loadNoiseTexture()

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice()!
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        context.coordinator.renderer = MetalBackgroundRenderer(mtkView: mtkView, texture: texture)
        context.coordinator.attachDisplayLink(to: mtkView)
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // No-op: animation handled by timer
    }

    class Coordinator: NSObject {
        var parent: MetalBackgroundView
        var renderer: MetalBackgroundRenderer?
        var displayLink: Any?
        var cvDisplayLink: CVDisplayLink?
        var startTime: CFTimeInterval = CACurrentMediaTime()

        init(_ parent: MetalBackgroundView) {
            self.parent = parent
            super.init()
        }

        func attachDisplayLink(to mtkView: MTKView) {
            if #available(macOS 15.0, *) {
                // Use new API
                displayLink = mtkView.displayLink(target: self, selector: #selector(frameUpdate))
            } else {
                // Fallback to CVDisplayLink
                var link: CVDisplayLink?
                CVDisplayLinkCreateWithActiveCGDisplays(&link)
                cvDisplayLink = link
                if let dl = link {
                    CVDisplayLinkSetOutputCallback(dl, { (_, _, _, _, _, userData) -> CVReturn in
                        let coordinator = Unmanaged<Coordinator>.fromOpaque(userData!).takeUnretainedValue()
                        DispatchQueue.main.async {
                            coordinator.drawFrame()
                        }
                        return kCVReturnSuccess
                    }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
                    CVDisplayLinkStart(dl)
                }
            }
        }

        @objc func frameUpdate() {
            drawFrame()
        }

        func drawFrame() {
            guard let renderer = renderer, let mtkView = renderer.value(forKey: "mtkView") as? MTKView else { return }
            let now = CACurrentMediaTime()
            let time = Float(now - startTime)
            let size = mtkView.drawableSize
            let tint = parent.colorTint.toSIMD4()
            let vignette = parent.vignette
            renderer.updateUniforms(time: time,
                                    resolution: CGSize(width: size.width, height: size.height),
                                    blur: parent.blur,
                                    noise: parent.noise,
                                    grain: parent.grain,
                                    textureMix: parent.textureMix,
                                    colorTint: tint,
                                    vignette: vignette)
            mtkView.setNeedsDisplay(mtkView.bounds)
        }

        deinit {
            if #available(macOS 15.0, *) {
                // NSView.displayLink is automatically cleaned up
            } else {
                if let dl = cvDisplayLink {
                    CVDisplayLinkStop(dl)
                }
            }
        }
    }

    static func loadNoiseTexture() -> MTLTexture? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        guard let url = Bundle.main.url(forResource: "noise", withExtension: "png") else { return nil }
        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(URL: url, options: [MTKTextureLoader.Option.SRGB : false])
    }
}

extension Color {
    func toSIMD4() -> SIMD4<Float> {
        #if os(macOS)
        let nsColor = NSColor(self)
        #else
        let uiColor = UIColor(self)
        #endif
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        #if os(macOS)
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }
}

// Usage Example in SwiftUI:
// MetalBackgroundView(blur: .constant(2.0), noise: .constant(0.2), grain: .constant(0.2), textureMix: .constant(0.5), colorTint: .constant(.white.opacity(0.0)), vignette: .constant(0.2))
