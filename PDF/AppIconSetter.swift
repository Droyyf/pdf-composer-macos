import AppKit

// Workaround for app icon not being correctly set through asset catalog
class AppIconSetter {
    static func setAppIcon() {
        // Try ICNS file first
        if let icnsPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") {
            if let iconImage = NSImage(contentsOfFile: icnsPath) {
                NSApplication.shared.applicationIconImage = iconImage
                print("App icon set programmatically from ICNS file")
                return
            }
        }

        // Fall back to PNG
        if let pngPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") {
            if let iconImage = NSImage(contentsOfFile: pngPath) {
                NSApplication.shared.applicationIconImage = iconImage
                print("App icon set programmatically from PNG file")
                return
            }
        }

        print("Could not find any icon files in the bundle")
    }
}
