import SwiftUI

struct BrutalistLoadingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Black background for grain to render on
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 25) {
                // Simple brutalist rotating bars loader
                ZStack {
                    // Three rotating bars at different angles
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(DesignTokens.brutalistPrimary))
                            .frame(width: 4, height: 30)
                            .offset(y: -15)
                            .rotationEffect(.degrees(rotation + Double(index * 120)))
                    }
                }
                .frame(width: 60, height: 60)
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
    BrutalistLoadingView()
}
