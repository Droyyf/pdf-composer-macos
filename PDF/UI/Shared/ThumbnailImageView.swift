import SwiftUI
import PDFKit
import AppKit

// MARK: - Thumbnail Image View with Centralized Service

struct ThumbnailImageView: View {
    let document: PDFDocument
    let pageIndex: Int
    let size: CGSize
    let thumbnailService: ThumbnailService
    
    @State private var image: NSImage?
    @State private var isLoading: Bool = false
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                // Loading placeholder
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Empty placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Text("No Image")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            // Cancel loading task when view disappears to save resources
            loadingTask?.cancel()
            loadingTask = nil
        }
        .onChange(of: pageIndex) { _, _ in
            // Reload when page index changes
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        loadingTask = Task { @MainActor in
            // Check for cached thumbnail first
            if let cachedImage = await thumbnailService.getCachedThumbnail(for: pageIndex) {
                self.image = cachedImage
                return
            }
            
            // Check for placeholder
            if let placeholder = await thumbnailService.getPlaceholderThumbnail(for: pageIndex) {
                self.image = placeholder
            }
            
            // Set loading state
            self.isLoading = true
            
            // Load full thumbnail
            let options = ThumbnailOptions(
                size: size,
                quality: 0.8,
                useCache: true,
                priority: .userInitiated
            )
            
            let result = await thumbnailService.loadThumbnail(
                from: document,
                pageIndex: pageIndex,
                options: options
            )
            
            // Update UI with result
            if let result = result {
                self.image = result.image
            } else {
                // Fallback to direct generation if service fails
                if let page = document.page(at: pageIndex) {
                    let fallbackImage = await thumbnailService.generateDirectThumbnail(
                        from: page,
                        size: size
                    )
                    self.image = fallbackImage
                }
            }
            
            self.isLoading = false
        }
    }
}

// MARK: - Thumbnail Image View with Options

struct ThumbnailImageViewWithOptions: View {
    let document: PDFDocument
    let pageIndex: Int
    let options: ThumbnailOptions
    let thumbnailService: ThumbnailService
    
    @State private var image: NSImage?
    @State private var isLoading: Bool = false
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                LoadingThumbnailPlaceholder()
            } else {
                EmptyThumbnailPlaceholder()
            }
        }
        .onAppear {
            loadThumbnailWithOptions()
        }
        .onDisappear {
            loadingTask?.cancel()
            loadingTask = nil
        }
        .onChange(of: pageIndex) { _, _ in
            loadThumbnailWithOptions()
        }
        .onChange(of: options.size) { _, _ in
            loadThumbnailWithOptions()
        }
    }
    
    private func loadThumbnailWithOptions() {
        loadingTask?.cancel()
        
        loadingTask = Task { @MainActor in
            // Quick cache check
            if let cachedImage = await thumbnailService.getCachedThumbnail(for: pageIndex) {
                self.image = cachedImage
                return
            }
            
            self.isLoading = true
            
            let result = await thumbnailService.loadThumbnail(
                from: document,
                pageIndex: pageIndex,
                options: options
            )
            
            self.image = result?.image
            self.isLoading = false
        }
    }
}

// MARK: - Supporting Views

private struct LoadingThumbnailPlaceholder: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
            
            VStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.secondary)
                
                Text("Loading...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: true)
    }
}

private struct EmptyThumbnailPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    
                    Text("No Image")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            )
    }
}

// MARK: - Convenience Initializers

extension ThumbnailImageView {
    /// Creates a standard thumbnail view with common settings
    static func standard(
        document: PDFDocument,
        pageIndex: Int,
        thumbnailService: ThumbnailService
    ) -> ThumbnailImageView {
        return ThumbnailImageView(
            document: document,
            pageIndex: pageIndex,
            size: CGSize(width: 160, height: 200),
            thumbnailService: thumbnailService
        )
    }
    
    /// Creates a placeholder-quality thumbnail view for quick loading
    static func placeholder(
        document: PDFDocument,
        pageIndex: Int,
        thumbnailService: ThumbnailService
    ) -> ThumbnailImageViewWithOptions {
        return ThumbnailImageViewWithOptions(
            document: document,
            pageIndex: pageIndex,
            options: .placeholder,
            thumbnailService: thumbnailService
        )
    }
    
    /// Creates a high-quality thumbnail view
    static func highQuality(
        document: PDFDocument,
        pageIndex: Int,
        thumbnailService: ThumbnailService
    ) -> ThumbnailImageViewWithOptions {
        return ThumbnailImageViewWithOptions(
            document: document,
            pageIndex: pageIndex,
            options: .highQuality,
            thumbnailService: thumbnailService
        )
    }
}

// MARK: - Performance Optimized Thumbnail View for Lists

struct OptimizedThumbnailImageView: View {
    let document: PDFDocument
    let pageIndex: Int
    let size: CGSize
    let thumbnailService: ThumbnailService
    
    @State private var image: NSImage?
    @State private var isVisible: Bool = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .onAppear {
            isVisible = true
            loadThumbnailIfVisible()
        }
        .onDisappear {
            isVisible = false
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                loadThumbnailIfVisible()
            }
        }
    }
    
    private func loadThumbnailIfVisible() {
        guard isVisible else { return }
        
        Task { @MainActor in
            // Quick cache check
            if let cachedImage = await thumbnailService.getCachedThumbnail(for: pageIndex) {
                self.image = cachedImage
                return
            }
            
            // Only load if still visible
            guard isVisible else { return }
            
            let options = ThumbnailOptions(
                size: size,
                quality: 0.7, // Lower quality for performance
                useCache: true,
                priority: .utility // Lower priority for list items
            )
            
            let result = await thumbnailService.loadThumbnail(
                from: document,
                pageIndex: pageIndex,
                options: options
            )
            
            // Only update if still visible
            if isVisible {
                self.image = result?.image
            }
        }
    }
}