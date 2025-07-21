import SwiftUI

struct BrutalistLoadingView: View {
    @State private var isAnimating = false

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
                            // Spinning indicator dot
                            Circle()
                                .fill(Color(DesignTokens.brutalistPrimary))
                                .frame(width: 6, height: 6)
                                .offset(y: -37)
                        )
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)
                        .drawingGroup() // Hardware acceleration
                    
                    // Inner ring for dual rotation effect
                    Circle()
                        .stroke(Color(DesignTokens.brutalistPrimary).opacity(0.4), lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .rotationEffect(Angle(degrees: isAnimating ? -360 : 0))
                        .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: isAnimating)
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
            // Ensure smooth 60fps animation
            DispatchQueue.main.async {
                isAnimating = true
            }
        }
        .preferredColorScheme(.dark) // Optimize for dark mode rendering
        .clipped() // Prevent unnecessary overdraw
    }
}

#Preview {
    BrutalistLoadingView()
}
