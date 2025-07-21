import SwiftUI

/// Contains decorative elements for the brutalist UI styling
struct BrutalistDecorations: View {
    // Pink color from FIGHT poster (#c5879b)
    private let accentColor = Color(hex: "c5879b")
    private let scale: CGFloat
    
    // Cache computed values to avoid recomputation
    private let cachedLayout: DecorationLayout

    init(scale: CGFloat = 1.0) {
        self.scale = scale
        self.cachedLayout = DecorationLayout(scale: scale)
    }
}

// MARK: - Layout Configuration
struct DecorationLayout {
    let scale: CGFloat
    let starSize: CGSize
    let globeSize: CGSize
    let fontSizes: FontSizes
    let spacings: Spacings
    let offsets: Offsets
    
    struct FontSizes {
        let bcr: CGFloat
        let burst: CGFloat
        let starSymbol: CGFloat
        let zSymbol: CGFloat
        let numberSymbol: CGFloat
    }
    
    struct Spacings {
        let topRow: CGFloat
        let rightSide: CGFloat
        let lineSpacing: CGFloat
    }
    
    struct Offsets {
        let topRowY: CGFloat
        let rightSideX: CGFloat
        let crossMarkPositions: [(x: CGFloat, y: CGFloat)]
        let dotPositions: [(x: CGFloat, y: CGFloat)]
    }
    
    init(scale: CGFloat) {
        self.scale = scale
        self.starSize = CGSize(width: 14 * scale, height: 14 * scale)
        self.globeSize = CGSize(width: 20 * scale, height: 16 * scale)
        
        self.fontSizes = FontSizes(
            bcr: 14 * scale,
            burst: 12 * scale,
            starSymbol: 10 * scale,
            zSymbol: 18 * scale,
            numberSymbol: 24 * scale
        )
        
        self.spacings = Spacings(
            topRow: 12 * scale,
            rightSide: 12 * scale,
            lineSpacing: 1 * scale
        )
        
        self.offsets = Offsets(
            topRowY: -40 * scale,
            rightSideX: 120 * scale,
            crossMarkPositions: [
                (x: -80 * scale, y: 30 * scale),
                (x: 100 * scale, y: -20 * scale),
                (x: -60 * scale, y: -50 * scale),
                (x: 70 * scale, y: 50 * scale),
                (x: 85 * scale, y: 0 * scale)
            ],
            dotPositions: [
                (x: -50 * scale, y: 45 * scale),
                (x: 90 * scale, y: -35 * scale),
                (x: -80 * scale, y: 15 * scale)
            ]
        )
    }
}

// MARK: - View Extension
extension BrutalistDecorations {

    var body: some View {
        ZStack {
            // Top row symbols (BCR, globe, etc.)
            topRowSymbols
                .foregroundColor(accentColor)
                .offset(y: cachedLayout.offsets.topRowY)

            // Right side Z33 and globe
            rightSideElements
                .foregroundColor(accentColor)
                .offset(x: cachedLayout.offsets.rightSideX)

            // Cross marks
            crossMarksOverlay

            // Dots for additional texture
            dotsOverlay
        }
    }
    
    // MARK: - Cached Sub-Views
    
    @ViewBuilder
    private var topRowSymbols: some View {
        HStack(spacing: cachedLayout.spacings.topRow) {
            // Sun/star symbol
            StarSymbol()
                .frame(width: cachedLayout.starSize.width, height: cachedLayout.starSize.height)

            // Globe symbol
            GlobeSymbol()
                .frame(width: cachedLayout.globeSize.width, height: cachedLayout.globeSize.height)

            // BCR text
            Text("BCR.")
                .font(.custom("Courier-Bold", size: cachedLayout.fontSizes.bcr))
                .kerning(0.5)

            // Line and circle symbols
            HStack(spacing: 4 * scale) {
                Rectangle()
                    .frame(width: 20 * scale, height: 1 * scale)

                Circle()
                    .frame(width: 8 * scale, height: 8 * scale)

                Image(systemName: "burst")
                    .font(.system(size: cachedLayout.fontSizes.burst))
            }
        }
    }
    
    @ViewBuilder
    private var rightSideElements: some View {
        VStack(spacing: cachedLayout.spacings.rightSide) {
            // *Z* with star symbols
            HStack(spacing: 0) {
                Text("*")
                    .font(.system(size: cachedLayout.fontSizes.starSymbol, weight: .black))
                Text("Z")
                    .font(.custom("Courier-Bold", size: cachedLayout.fontSizes.zSymbol))
                Text("*")
                    .font(.system(size: cachedLayout.fontSizes.starSymbol, weight: .black))
            }

            // 33 number
            Text("33")
                .font(.custom("Courier-Bold", size: cachedLayout.fontSizes.numberSymbol))
                .kerning(-2)

            GlobeSymbol()
                .frame(width: 24 * scale, height: 20 * scale)

            // Machine/typewriter symbol
            typewriterSymbol
        }
    }
    
    @ViewBuilder
    private var typewriterSymbol: some View {
        VStack(spacing: cachedLayout.spacings.lineSpacing) {
            Rectangle()
                .frame(width: 22 * scale, height: 1.5 * scale)

            HStack(spacing: 0) {
                Rectangle()
                    .frame(width: 16 * scale, height: 14 * scale)

                VStack(spacing: 0) {
                    Rectangle()
                        .frame(width: 6 * scale, height: 7 * scale)
                    Rectangle()
                        .frame(width: 6 * scale, height: 7 * scale)
                        .opacity(0.6)
                }
            }

            Rectangle()
                .frame(width: 22 * scale, height: 1.5 * scale)

            Rectangle()
                .frame(width: 26 * scale, height: 14 * scale)
        }
    }
    
    @ViewBuilder
    private var crossMarksOverlay: some View {
        ForEach(0..<cachedLayout.offsets.crossMarkPositions.count, id: \.self) { i in
            CrossMark(size: 6 * scale)
                .offset(
                    x: cachedLayout.offsets.crossMarkPositions[i].x,
                    y: cachedLayout.offsets.crossMarkPositions[i].y
                )
                .foregroundColor(accentColor.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private var dotsOverlay: some View {
        ForEach(0..<cachedLayout.offsets.dotPositions.count, id: \.self) { i in
            Circle()
                .frame(width: 3 * scale, height: 3 * scale)
                .offset(
                    x: cachedLayout.offsets.dotPositions[i].x,
                    y: cachedLayout.offsets.dotPositions[i].y
                )
                .foregroundColor(accentColor.opacity(0.9))
        }
    }
}

// Custom symbols
struct StarSymbol: View {
    var body: some View {
        // Using a custom star shape to better match the image
        ZStack {
            Image(systemName: "sparkle")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

struct GlobeSymbol: View {
    var body: some View {
        // More detailed globe to match the image
        ZStack {
            Circle()
                .stroke(lineWidth: 1)

            // Horizontal lines for latitude
            ForEach(-2...2, id: \.self) { i in
                let offset = CGFloat(i) * 3
                Capsule()
                    .frame(height: 0.5)
                    .offset(y: offset)
            }

            // Vertical line for longitude
            Capsule()
                .frame(width: 0.5)
                .rotationEffect(.degrees(15))

            // Second vertical line
            Capsule()
                .frame(width: 0.5)
                .rotationEffect(.degrees(-15))
        }
    }
}

struct CrossMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: size, height: 1)

            Rectangle()
                .frame(width: 1, height: size)
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        BrutalistDecorations(scale: 1.0)
    }
}
