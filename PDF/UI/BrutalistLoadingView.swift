import SwiftUI

struct BrutalistLoadingView: View {
    let progress: Double?
    let totalPages: Int?
    @State private var rotation: Double = 0

    init(progress: Double? = nil, totalPages: Int? = nil) {
        self.progress = progress
        self.totalPages = totalPages
    }

    var body: some View {
        ZStack {
            // Black background for grain to render on
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 25) {
                // Progress-based or spinning loader
                ZStack {
                    if let progress = progress {
                        // Simple progress bar instead of broken circle
                        VStack(spacing: 8) {
                            // Progress bar background
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(DesignTokens.brutalistPrimary).opacity(0.2))
                                .frame(width: 80, height: 6)
                                .overlay(
                                    // Progress bar fill
                                    HStack {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(DesignTokens.brutalistPrimary))
                                            .frame(width: 80 * min(progress, 1.0), height: 6)
                                            .animation(.easeInOut(duration: 0.3), value: progress)
                                        Spacer(minLength: 0)
                                    }
                                )
                        }
                    } else {
                        // Fallback: spinning bars when no progress available
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(DesignTokens.brutalistPrimary))
                                .frame(width: 4, height: 30)
                                .offset(y: -15)
                                .rotationEffect(.degrees(rotation + Double(index * 120)))
                        }
                    }
                }
                .frame(width: 60, height: 60)
                .drawingGroup() // Hardware acceleration for entire group

                // Loading text with progress
                if let progress = progress {
                    BrutalistHeading(
                        text: "LOADING \(Int(progress * 100))%",
                        size: 24,
                        color: Color(DesignTokens.brutalistPrimary),
                        tracking: 3.0,
                        addStroke: false
                    )
                    
                    // Optional page details
                    if let totalPages = totalPages {
                        let currentPage = Int(progress * Double(totalPages))
                        BrutalistTechnicalText(
                            text: "\(currentPage)/\(totalPages) PAGES",
                            color: Color.white.opacity(0.7),
                            size: 11,
                            addDecorators: true,
                            align: .center
                        )
                    }
                } else {
                    BrutalistHeading(
                        text: "LOADING",
                        size: 24,
                        color: Color(DesignTokens.brutalistPrimary),
                        tracking: 3.0,
                        addStroke: false
                    )
                    
                    BrutalistTechnicalText(
                        text: "PDF PROCESSING IN PROGRESS",
                        color: Color.white.opacity(0.7),
                        size: 11,
                        addDecorators: true,
                        align: .center
                    )
                }
            }
            .offset(y: -30)
        }
        .onAppear {
            // Start continuous rotation animation
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onDisappear {
            rotation = 0
        }
        .preferredColorScheme(.dark) // Optimize for dark mode rendering
        .clipped() // Prevent unnecessary overdraw
    }
}

#Preview {
    VStack {
        BrutalistLoadingView(progress: 0.65, totalPages: 42)
        BrutalistLoadingView(progress: 0.25)
        BrutalistLoadingView()
    }
}
