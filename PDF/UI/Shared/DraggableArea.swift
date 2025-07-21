import SwiftUI
import AppKit

struct DraggableArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class DraggableNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
