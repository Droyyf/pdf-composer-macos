//
//  AlmostBrutalApp.swift
//  AlmostBrutal
//
//  Created by Droy — on 13/05/2025.
//

import SwiftUI
import AppKit

// Custom NSImageView subclass to make it non-interactive
class NonInteractiveImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // This view should not respond to mouse events
    }
}

// Helper function to enhance texture images for better visibility
func enhanceTextureImage(_ image: NSImage) -> NSImage {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return image
    }
    
    let enhancedImage = NSImage(size: image.size)
    enhancedImage.lockFocus()
    
    guard let context = NSGraphicsContext.current?.cgContext else {
        enhancedImage.unlockFocus()
        return image
    }
    
    // Apply contrast and brightness enhancements
    context.saveGState()
    
    // Set up color filter to enhance contrast
    let colorFilter = CIFilter(name: "CIColorControls")
    colorFilter?.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
    colorFilter?.setValue(1.6, forKey: kCIInputContrastKey) // Increase contrast
    colorFilter?.setValue(0.1, forKey: kCIInputBrightnessKey) // Slight brightness boost
    colorFilter?.setValue(1.3, forKey: kCIInputSaturationKey) // Increase saturation
    
    if let outputImage = colorFilter?.outputImage,
       let enhancedCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) {
        context.draw(enhancedCGImage, in: CGRect(origin: .zero, size: image.size))
    } else {
        // Fallback to original image if filtering fails
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
    }
    
    context.restoreGState()
    enhancedImage.unlockFocus()
    return enhancedImage
}

class FullContentWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func contentRect(forFrameRect frameRect: NSRect) -> NSRect {
        return frameRect // Fill the entire window, including the title bar area
    }

    // Remove corner radius from window and make it truly borderless
    override func awakeFromNib() {
        super.awakeFromNib()
        self.hasShadow = true
        applyBorderlessAppearance()
    }

    // Enable keyboard events to be passed up the responder chain
    override func keyDown(with event: NSEvent) {
        // Pass standard keyboard events to the next responder
        // This ensures system shortcuts work
        self.nextResponder?.keyDown(with: event)
        super.keyDown(with: event)
    }

    // Enable keyboard shortcuts without requiring a text field
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // First try standard handling
        if super.performKeyEquivalent(with: event) {
            return true
        }

        // If it's a standard menu command, try to find and perform it
        if event.modifierFlags.contains(.command) {
            let keyEquivalent = event.charactersIgnoringModifiers?.lowercased() ?? ""

            // Check main menu items for matching key equivalent
            for menuItem in NSApp.mainMenu?.items ?? [] {
                if let submenu = menuItem.submenu {
                    for subMenuItem in submenu.items {
                        if subMenuItem.keyEquivalent.lowercased() == keyEquivalent {
                            if subMenuItem.isEnabled, let action = subMenuItem.action {
                                NSApp.sendAction(action, to: subMenuItem.target, from: self)
                                return true
                            }
                        }
                    }
                }
            }
        }

        return false
    }

    func applyBorderlessAppearance() {
        self.backgroundColor = .clear
        self.isOpaque = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.styleMask.insert(.fullSizeContentView)
        self.styleMask.remove(.titled)
        self.styleMask.remove(.closable)
        self.styleMask.remove(.miniaturizable)
        // self.styleMask.remove(.resizable) // Allow window to be resizable
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        if let contentView = self.contentView, let windowView = contentView.superview?.superview {
            windowView.wantsLayer = true
            windowView.layer?.cornerRadius = 0
            windowView.layer?.masksToBounds = true
            windowView.layer?.borderWidth = 0
        }
    }
}

class AppWindowController: NSWindowController {
    convenience init() {
        // Get main screen dimensions
        guard let mainScreen = NSScreen.main else {
            // Fallback size if main screen is not available
            self.init(window: FullContentWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                                              styleMask: [.borderless, .fullSizeContentView, .resizable],
                                              backing: .buffered, defer: false))
            // Setup content for fallback window
            if let window = self.window as? FullContentWindow {
                _ = AppShellViewModel()
                setupWindowContent(for: window, rootView: AppShell())
            }
            return
        }

        let screenRect = mainScreen.visibleFrame
        // Calculate a square size that fits within the screen bounds
        let squareSize = min(screenRect.width * 0.8, screenRect.height * 0.8, 900)
        let originX = (screenRect.width - squareSize) / 2 + screenRect.origin.x
        let originY = (screenRect.height - squareSize) / 2 + screenRect.origin.y
        let initialWindowRect = NSRect(x: originX, y: originY, width: squareSize, height: squareSize)

        // Create a borderless window with proper style masks for visual effects
        let window = FullContentWindow(
            contentRect: initialWindowRect, // Use calculated initial size and position
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        self.init(window: window)
        setupWindowContent(for: window, rootView: AppShell()) // Call helper with AppShell instead of BrutalistAppShell
    }

    // Helper function to setup window content (blur, noise, grain, SwiftUI view)
    private func setupWindowContent(for window: NSWindow, rootView: AppShell) {
        // Configure window for transparency and visual effects
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false // Ensure window is only draggable from designated areas
        
        // Performance optimizations for smooth animations
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.drawsAsynchronously = true // Enable async drawing
            contentView.layer?.allowsGroupOpacity = false // Optimize blending
        }

        // Create a container view to hold all content
        let containerView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        // Create and configure the base visual effect view for blur/vibrancy
        let baseVisualEffectView = NSVisualEffectView(frame: containerView.bounds)
        baseVisualEffectView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        baseVisualEffectView.blendingMode = .behindWindow
        baseVisualEffectView.material = .hudWindow
        baseVisualEffectView.state = .active
        baseVisualEffectView.wantsLayer = true
        
        // Performance optimizations for visual effect view
        baseVisualEffectView.layer?.drawsAsynchronously = true

        // Configure the hosting view with proper frame and autoresizing
        // Use the AppShell view instead of AppShell
        let contentView = NSHostingView(rootView: rootView)
        contentView.frame = containerView.bounds
        contentView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        
        // Performance optimizations for SwiftUI hosting view
        contentView.wantsLayer = true
        contentView.layer?.drawsAsynchronously = true

        // Build the view hierarchy
        containerView.addSubview(baseVisualEffectView) // Blur/Vibrancy layer

        // Declare baseNoiseImageView as an optional NSImageView here
        var baseNoiseImageView: NSImageView? = nil

        // Create and configure the base noise image view
        baseNoiseImageView = NSImageView(frame: containerView.bounds)
        baseNoiseImageView?.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        baseNoiseImageView?.imageScaling = .scaleAxesIndependently
        let loadedImage = NSImage(named: "AccentTexture3")
        baseNoiseImageView?.image = loadedImage
        print("Loaded AccentTexture3 as Global Background: \(loadedImage != nil ? "Success" : "Failed")") // Debug print
        baseNoiseImageView?.alphaValue = 0.55 // Increased alpha a tiny bit more
        baseNoiseImageView?.wantsLayer = true
        baseNoiseImageView?.layer?.compositingFilter = "overlayBlendMode" // Keeping overlayBlendMode

        // Ensure it's added to the view hierarchy if successfully created
        if let baseNoiseImageView = baseNoiseImageView {
            containerView.addSubview(baseNoiseImageView, positioned: .above, relativeTo: baseVisualEffectView)
        }

        // Ensure SwiftUI content view is on top of all effect layers
        containerView.addSubview(contentView, positioned: .above, relativeTo: nil) // Position on very top

        // Create and configure the TOPMOST global texture overlay using the custom class
        let topOverlayTextureView = NonInteractiveImageView(frame: containerView.bounds) // Use custom class
        topOverlayTextureView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        topOverlayTextureView.imageScaling = .scaleAxesIndependently
        if let topTextureImage = NSImage(named: "AccentTexture5") {
            // Enhance the texture with better contrast and definition
            let enhancedTexture = enhanceTextureImage(topTextureImage)
            topOverlayTextureView.image = enhancedTexture
            print("Loaded and enhanced AccentTexture5 as Topmost Overlay: Success") // Updated success message
        } else {
            print("FAILED to load AccentTexture5 as Topmost Overlay.") // Kept failure message
        }
        topOverlayTextureView.alphaValue = 0.75 // Increased alpha for better visibility
        topOverlayTextureView.wantsLayer = true
        topOverlayTextureView.layer?.compositingFilter = "overlayBlendMode" // Use overlay blending for better texture visibility

        containerView.addSubview(topOverlayTextureView, positioned: .above, relativeTo: contentView)
        // Optionally remove or keep the frame debug print
        // print("DEBUG: Added topOverlayTextureView. Frame: \(topOverlayTextureView.frame)")

        // Set the container as the window's content view
        window.contentView = containerView

        // Apply final window appearance
        if let fullContentWindow = window as? FullContentWindow {
            fullContentWindow.applyBorderlessAppearance()
        }

        // Position and show the window
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.acceptsMouseMovedEvents = true

        // Add draggable area AFTER everything is set up to ensure it's on top
        let topDragAreaHeight: CGFloat = 40
        if let contentView = window.contentView {
            let dragAreaFrame = NSRect(x: 0, y: contentView.bounds.height - topDragAreaHeight,
                                     width: contentView.bounds.width, height: topDragAreaHeight)
            let dragAreaView = DraggableTopBarView(frame: dragAreaFrame)
            dragAreaView.autoresizingMask = [.width, .minYMargin] // Resize with window width, stay at top
            contentView.addSubview(dragAreaView, positioned: .above, relativeTo: nil)
        }

        // Debug - print view hierarchy
        print("Window content view: \(String(describing: window.contentView))")
        print("Subviews count: \(window.contentView?.subviews.count ?? 0)")
        window.contentView?.subviews.forEach { subview in
            print("Subview: \(type(of: subview)), frame: \(subview.frame), hidden: \(subview.isHidden)")
        }
    }
}

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    private init() {
        let contentView = NSHostingView(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = contentView
        window.center()
        super.init(window: window)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func show() {
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Custom NSView subclass for the draggable area at the top of the window
class DraggableTopBarView: NSView {
    private var isHovering = false
    private var trackingArea: NSTrackingArea!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        // Create tracking area after super.init
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Create tracking area
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Create tracking area after super.init
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Create tracking area
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
        NSCursor.arrow.set() // Use standard cursor for draggable area
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        // Start window drag operation when the mouse is pressed in this area
        if let window = self.window {
            window.performDrag(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Optional: add a subtle visual indicator when hovering
        if isHovering {
            NSColor.white.withAlphaComponent(0.1).set()
            let hoverIndicator = NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width, height: 1))
            hoverIndicator.fill()
        }
    }
}

@main
struct PDFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        // WindowGroup removed to prevent empty window, as main window is handled by AppWindowController
        // If you need a settings scene, it would be defined here, but main window is custom.
        // Example: Settings { SettingsView() } would still be valid alongside custom main window.
        // For now, no scenes are defined here to solely rely on AppDelegate for the main window.
        #if false // Effectively removing the WindowGroup
        WindowGroup {
            EmptyView()
        }
        #endif
        // If you need to re-introduce a Settings scene later:
        // Settings { SettingsView() } // Commented out to resolve build error: Trailing closure passed to parameter of type 'any Decoder'
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: AppWindowController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon programmatically to bypass asset catalog issues
        AppIconSetter.setAppIcon()

        windowController = AppWindowController()
        setupSettingsMenuItem()
        ensureStandardKeyboardShortcuts()
    }

    private func setupSettingsMenuItem() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let appMenu = mainMenu.items.first?.submenu
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        // Insert after About (usually at index 1)
        if let appMenu = appMenu, appMenu.items.count > 1 {
            appMenu.insertItem(settingsItem, at: 1)
        } else {
            appMenu?.addItem(settingsItem)
        }
    }

    private func ensureStandardKeyboardShortcuts() {
        // Ensure standard app menu exists
        guard let mainMenu = NSApp.mainMenu else { return }

        // Get or create App menu
        let appMenu: NSMenu
        if let existingAppMenu = mainMenu.items.first?.submenu {
            appMenu = existingAppMenu
        } else {
            let appMenuItem = NSMenuItem()
            appMenu = NSMenu()
            appMenuItem.submenu = appMenu
            mainMenu.insertItem(appMenuItem, at: 0)
        }

        // Ensure Quit menu item exists with Cmd+Q shortcut
        if !appMenu.items.contains(where: { $0.keyEquivalent == "q" }) {
            let quitMenuItem = NSMenuItem(
                title: "Quit \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "PDF")",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
            quitMenuItem.keyEquivalentModifierMask = [.command]
            appMenu.addItem(quitMenuItem)
        }

        // Add other standard shortcuts if needed
        if !appMenu.items.contains(where: { $0.keyEquivalent == "w" }) {
            let closeMenuItem = NSMenuItem(
                title: "Close",
                action: #selector(NSWindow.performClose(_:)),
                keyEquivalent: "w"
            )
            closeMenuItem.keyEquivalentModifierMask = [.command]
            appMenu.addItem(closeMenuItem)
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }
}
