import SwiftUI

struct BrutalistLoadingView: View {
    @State private var rotation: Double = 0
    @State private var innerRotation: Double = 0

    var body: some View {
        ZStack {
            // Black background for grain to render on
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 25) {
                // High-performance smooth spinning loader
                ZStack {
                    // Main rotating ring with hardware-accelerated animation
                    Circle()
                        .stroke(Color(DesignTokens.brutalistPrimary), lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .overlay(
                            // Spinning indicator dot - fixed positioning
                            Circle()
                                .fill(Color(DesignTokens.brutalistPrimary))
                                .frame(width: 8, height: 8)
                                .offset(y: -40) // Properly positioned for 80pt circle
                        )
                        .rotationEffect(.degrees(rotation))
                        .drawingGroup() // Hardware acceleration
                    
                    // Inner ring for dual rotation effect
                    Circle()
                        .stroke(Color(DesignTokens.brutalistPrimary).opacity(0.3), lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(innerRotation))
                        .drawingGroup() // Hardware acceleration
                }
                .drawingGroup() // Hardware acceleration for entire group

                // Loading text
                BrutalistHeading(
                    text: "LOADING",
                    size: 24,
                    color: Color(DesignTokens.brutalistPrimary),
                    tracking: 3.0,
                    addStroke: false
                )

                // Technical details
                BrutalistTechnicalText(
                    text: "PDF PROCESSING IN PROGRESS",
                    color: Color.white.opacity(0.7),
                    size: 11,
                    addDecorators: true,
                    align: .center
                )
            }
            .offset(y: -30)
        }
        .onAppear {
            // Start continuous rotation animations
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                innerRotation = -360
            }
        }
        .onDisappear {
            rotation = 0
            innerRotation = 0
        }
        .preferredColorScheme(.dark) // Optimize for dark mode rendering
        .clipped() // Prevent unnecessary overdraw
    }
}

#Preview {
    BrutalistLoadingView()
}
