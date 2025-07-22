import SwiftUI

/// Brutalist progress view for cloud operations
struct CloudProgressView: View {
    @ObservedObject var progress: CloudOperationProgress
    let title: String
    let onCancel: (() -> Void)?
    
    init(progress: CloudOperationProgress, title: String, onCancel: (() -> Void)? = nil) {
        self.progress = progress
        self.title = title
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            // Progress card
            VStack(spacing: 20) {
                // Icon and title
                VStack(spacing: 12) {
                    // Animated cloud icon
                    ZStack {
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: progress.isActive ? "icloud.and.arrow.up" : "checkmark.icloud")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                            .rotationEffect(.degrees(progress.isActive ? Double.random(in: -2...2) : 0))
                            .animation(
                                progress.isActive ? .easeInOut(duration: 2).repeatForever() : .none,
                                value: progress.isActive
                            )
                    }
                    
                    BrutalistHeading(
                        text: title,
                        size: 18,
                        color: Color(DesignTokens.brutalistPrimary),
                        tracking: 1.0,
                        addStroke: true,
                        strokeWidth: 0.5
                    )
                }
                
                // Progress content
                VStack(spacing: 16) {
                    // Status text
                    BrutalistTechnicalText(
                        text: progress.status,
                        color: Color(DesignTokens.brutalistPrimary).opacity(0.8),
                        size: 14,
                        addDecorators: true,
                        align: .center
                    )
                    
                    // Progress bar
                    if progress.isActive {
                        progressBar
                    }
                    
                    // Progress details
                    if progress.totalBytes > 0 {
                        Text(progress.formattedProgress)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    } else if progress.isActive {
                        Text("\(Int(progress.progress * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    }
                    
                    // Error display
                    if let error = progress.error {
                        errorSection(error: error)
                    }
                    
                    // Animated dots for active operations
                    if progress.isActive && progress.error == nil {
                        animatedDots
                    }
                }
                
                // Action buttons
                actionButtons
            }
            .padding(32)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                    )
                    .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
            )
            .frame(maxWidth: 400)
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            // Main progress bar
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 16)
                
                Rectangle()
                    .fill(Color(DesignTokens.brutalistPrimary))
                    .frame(width: CGFloat(progress.progress) * 300, height: 16)
                    .animation(.easeInOut(duration: 0.3), value: progress.progress)
            }
            .frame(width: 300)
            .overlay(
                Rectangle()
                    .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
            )
            
            // Segmented progress indicators
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(progress.progress > Double(index) / 10 ? Color(DesignTokens.brutalistPrimary) : Color.white.opacity(0.2))
                        .frame(width: 28, height: 4)
                        .animation(.easeInOut(duration: 0.2).delay(Double(index) * 0.05), value: progress.progress)
                }
            }
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(error: Error) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
                
                BrutalistTechnicalText(
                    text: "OPERATION FAILED",
                    color: .red,
                    size: 12,
                    addDecorators: false
                )
            }
            
            Text(error.localizedDescription)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(12)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(.red.opacity(0.1))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Animated Dots
    
    private var animatedDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(DesignTokens.brutalistPrimary))
                    .frame(width: 8, height: 8)
                    .opacity(0.3 + Double(index) * 0.2)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2 + Double(index)) * 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: UUID()
                    )
            }
        }
        .onAppear {
            // Trigger animation
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Cancel button (only show if operation is active and cancellation is supported)
            if progress.isActive && onCancel != nil {
                Button {
                    onCancel?()
                } label: {
                    Text("CANCEL")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Retry button (only show if there's an error)
            if progress.error != nil {
                Button {
                    progress.reset()
                    // Trigger retry - this would need to be handled by the parent
                } label: {
                    Text("RETRY")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                                .overlay(
                                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Close button (show when operation is complete or has error)
            if !progress.isActive {
                Button {
                    // This should dismiss the progress view
                    progress.reset()
                } label: {
                    Text(progress.error != nil ? "DISMISS" : "CLOSE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                                .overlay(
                                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Compact Progress Indicator

/// Compact version for showing in toolbars or status bars
struct CompactCloudProgressView: View {
    @ObservedObject var progress: CloudOperationProgress
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Group {
                if progress.isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(DesignTokens.brutalistPrimary)))
                        .scaleEffect(0.8)
                } else if progress.error != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                } else if progress.progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "cloud")
                        .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.6))
                }
            }
            .font(.system(size: 14, weight: .bold))
            
            // Status text
            if progress.isActive || progress.error != nil {
                Text(progress.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(progress.error != nil ? .red : Color(DesignTokens.brutalistPrimary))
                    .lineLimit(1)
                
                // Progress percentage
                if progress.isActive && progress.totalBytes == 0 {
                    Text("(\(Int(progress.progress * 100))%)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 8, bottomLeading: 2, bottomTrailing: 8, topTrailing: 2), style: .continuous)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 8, bottomLeading: 2, bottomTrailing: 8, topTrailing: 2), style: .continuous)
                        .strokeBorder(progressBorderColor, lineWidth: 1)
                )
        )
    }
    
    private var progressBorderColor: Color {
        if progress.error != nil {
            return .red.opacity(0.5)
        } else if progress.isActive {
            return Color(DesignTokens.brutalistPrimary).opacity(0.5)
        } else if progress.progress >= 1.0 {
            return .green.opacity(0.5)
        } else {
            return .white.opacity(0.2)
        }
    }
}

// MARK: - Preview

#Preview("Full Progress View") {
    let progress = CloudOperationProgress()
    progress.start(status: "Uploading to Google Drive...", totalBytes: 1024 * 1024)
    progress.update(progress: 0.6, completedBytes: 600 * 1024, status: "Uploading file...")
    
    return CloudProgressView(
        progress: progress,
        title: "CLOUD UPLOAD",
        onCancel: {
            progress.fail(error: CloudStorageError.uploadFailed("User cancelled"))
        }
    )
    .frame(width: 600, height: 400)
}

#Preview("Compact Progress View") {
    let progress = CloudOperationProgress()
    progress.start(status: "Uploading...", totalBytes: 0)
    progress.update(progress: 0.75)
    
    return CompactCloudProgressView(progress: progress)
        .padding()
        .background(Color.black)
}

#Preview("Error State") {
    let progress = CloudOperationProgress()
    progress.fail(error: CloudStorageError.networkError(URLError(.notConnectedToInternet)))
    
    return CloudProgressView(
        progress: progress,
        title: "UPLOAD FAILED",
        onCancel: nil
    )
    .frame(width: 600, height: 400)
}