import AppKit

extension NSImage {
    /// Converts the NSImage to PNG data
    func pngData() -> Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }

        return bitmapImage.representation(using: .png, properties: [:])
    }

    /// Creates a new NSImage from the given data
    convenience init?(data: Data) {
        self.init(dataIgnoringOrientation: data)
    }

    /// Resizes the image to the given size
    func resize(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    /// Applies a color overlay to the image
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()

        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)

        image.unlockFocus()
        return image
    }
}
