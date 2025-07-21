import SwiftUI
import AppKit

/// A class that configures the main window to be frameless and vibrant/blurred
class FramelessWindowManager: NSObject {
    static let shared = FramelessWindowManager()

    func configureWindow(_ window: NSWindow) {
        // Always include .titled for custom drag support
        window.styleMask.insert(.titled)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.remove(.closable)
        window.styleMask.remove(.miniaturizable)
        window.styleMask.insert(.fullSizeContentView)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .normal
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = false // We want only our custom area to be draggable

        // CRITICAL FIX: Make the title bar zero height to completely eliminate it
        // This is the key - rather than trying to style the bar, we'll eliminate it
        // from the window frame completely
        if let titlebarContainerView = findTitlebarContainerView(in: window) {
            titlebarContainerView.frame = .zero
            titlebarContainerView.isHidden = true
        }

        // Zero out all title bar elements
        window.setContentBorderThickness(0, for: .minY)

        // Set the window frame origin to include all content
        if let screen = window.screen {
            let contentRect = window.contentRect(forFrameRect: window.frame)
            let screenRect = screen.frame
            let yOrigin = screenRect.maxY - contentRect.height

            window.setFrame(NSRect(x: window.frame.origin.x,
                                  y: yOrigin,
                                  width: contentRect.width,
                                  height: contentRect.height),
                           display: true)
        }

        // Apply to the true window view
        guard window.contentView != nil else { return }

        // Clear all backgrounds
        clearAllBackgrounds(in: window)

        // Apply vibrancy directly to content view
        let vibrancy = NSVisualEffectView()
        vibrancy.material = .hudWindow
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.translatesAutoresizingMaskIntoConstraints = false

        // Actually remove the existing content view and replace it with a vibrancy view
        let originalContentView = window.contentView
        window.contentView = vibrancy

        // Then add the original content view as a subview of the vibrancy view
        if let originalContentView = originalContentView {
            originalContentView.translatesAutoresizingMaskIntoConstraints = false
            vibrancy.addSubview(originalContentView)
            NSLayoutConstraint.activate([
                originalContentView.topAnchor.constraint(equalTo: vibrancy.topAnchor),
                originalContentView.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor),
                originalContentView.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor),
                originalContentView.bottomAnchor.constraint(equalTo: vibrancy.bottomAnchor)
            ])
        }

        // Add noise overlay as an NSImageView
        if let noiseImage = NSImage(named: "noise") {
            let noiseView = NSImageView(image: noiseImage)
            noiseView.imageScaling = .scaleAxesIndependently
            noiseView.alphaValue = 0.12
            noiseView.wantsLayer = true
            noiseView.translatesAutoresizingMaskIntoConstraints = false
            vibrancy.addSubview(noiseView)
            NSLayoutConstraint.activate([
                noiseView.topAnchor.constraint(equalTo: vibrancy.topAnchor),
                noiseView.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor),
                noiseView.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor),
                noiseView.bottomAnchor.constraint(equalTo: vibrancy.bottomAnchor)
            ])
        }
    }

    // Find the titlebar container view using recursion
    private func findTitlebarContainerView(in window: NSWindow) -> NSView? {
        guard let contentView = window.contentView else { return nil }

        // Look for the main window's "ThemeFrame" which contains the title bar
        let titleBarView = contentView.superview?.superview
        if let titleBar = titleBarView, NSStringFromClass(type(of: titleBar)).contains("ThemeFrame") {
            // Find the actual container within the theme frame that holds the title
            for subview in titleBar.subviews {
                let className = NSStringFromClass(type(of: subview))
                if className.contains("NSTitlebar") || className.contains("TitleBar") {
                    return subview
                }
            }
            return titleBarView // Return the theme frame as fallback
        }

        // Fallback to our original search for specific class names
        return findViewByClassNameRecursively(in: contentView, className: "NSTitlebarContainerView") ??
               findViewByClassNameRecursively(in: contentView, className: "NSTitlebarView")
    }

    // Recursively search for a view with a specific class name
    private func findViewByClassNameRecursively(in view: NSView, className: String) -> NSView? {
        let viewClassName = NSStringFromClass(type(of: view))
        if viewClassName.contains(className) {
            return view
        }

        for subview in view.subviews {
            if let result = findViewByClassNameRecursively(in: subview, className: className) {
                return result
            }
        }

        return nil
    }

    // Clear backgrounds everywhere
    private func clearAllBackgrounds(in window: NSWindow) {
        window.backgroundColor = .clear

        func clearView(_ view: NSView) {
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor

            // If it's not a special view we want to keep, clear its subviews too
            if !(view is NSVisualEffectView) {
                for subview in view.subviews {
                    clearView(subview)
                }
            }
        }

        if let contentView = window.contentView {
            clearView(contentView)

            // Also clear parents if we can access them
            if let superView = contentView.superview {
                clearView(superView)

                if let superSuperView = superView.superview {
                    clearView(superSuperView)
                }
            }
        }
    }

    // Custom NSView for the brutalist title bar
    private class BrutalistTitlebarView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: NSRect(x: 0, y: 0, width: 1000, height: 48))
            wantsLayer = true
            layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.85).cgColor
            // Add noise overlay or gradient if desired
            // Add custom border, logo, or text if desired
        }
        required init?(coder: NSCoder) { super.init(coder: coder) }
    }
}

/// A SwiftUI view modifier that applies the frameless window configuration
struct FramelessWindowModifier: ViewModifier {
    @State private var windowConfigured = false

    func body(content: Content) -> some View {
        content
            .background(WindowAccessor(configureWindow: configureWindow))
    }

    private func configureWindow(_ window: NSWindow?) {
        guard let window = window, !windowConfigured else { return }
        FramelessWindowManager.shared.configureWindow(window)
        windowConfigured = true
    }
}

/// A helper view to get access to the NSWindow
struct WindowAccessor: NSViewRepresentable {
    var configureWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.configureWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update window configuration in case it's needed
        if let window = nsView.window {
            self.configureWindow(window)
        }
    }
}

extension View {
    /// Applies a frameless window style
    func framelessWindow() -> some View {
        self.modifier(FramelessWindowModifier())
    }
}
