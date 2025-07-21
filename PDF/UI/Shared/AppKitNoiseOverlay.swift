import SwiftUI
import AppKit

struct AppKitNoiseOverlay: NSViewRepresentable {
    var alpha: CGFloat = 0.12
    var imageName: String = "noise"
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        if let noiseImage = NSImage(named: imageName) {
            let noiseView = NSImageView(image: noiseImage)
            noiseView.imageScaling = .scaleAxesIndependently
            noiseView.alphaValue = alpha
            noiseView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(noiseView)
            NSLayoutConstraint.activate([
                noiseView.topAnchor.constraint(equalTo: view.topAnchor),
                noiseView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                noiseView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                noiseView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
