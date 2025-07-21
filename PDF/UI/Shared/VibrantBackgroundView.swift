import SwiftUI
import AppKit

struct VibrantBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var noiseAlpha: CGFloat = 0.12
    var noiseImageName: String = "noise"

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let vibrancy = NSVisualEffectView()
        vibrancy.material = material
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vibrancy)
        NSLayoutConstraint.activate([
            vibrancy.topAnchor.constraint(equalTo: container.topAnchor),
            vibrancy.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            vibrancy.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vibrancy.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        // Add a noise overlay as an NSImageView (optional)
        if let noiseImage = NSImage(named: noiseImageName) {
            let noiseView = NSImageView(image: noiseImage)
            noiseView.imageScaling = .scaleAxesIndependently
            noiseView.alphaValue = noiseAlpha
            noiseView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(noiseView)
            NSLayoutConstraint.activate([
                noiseView.topAnchor.constraint(equalTo: container.topAnchor),
                noiseView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                noiseView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                noiseView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
