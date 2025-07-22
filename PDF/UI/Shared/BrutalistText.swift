import SwiftUI

struct BrutalistText: View {
    let text: String
    let style: BrutalistTextStyle
    
    init(_ text: String, style: BrutalistTextStyle = .body) {
        self.text = text
        self.style = style
    }
    
    var body: some View {
        Text(text)
            .font(style.font)
            .foregroundColor(style.color)
            .tracking(style.tracking)
    }
}

enum BrutalistTextStyle {
    case title
    case headline
    case subheadline
    case body
    case caption
    case button
    
    var font: Font {
        switch self {
        case .title:
            return .system(size: 24, weight: .black, design: .monospaced)
        case .headline:
            return .system(size: 18, weight: .bold, design: .monospaced)
        case .subheadline:
            return .system(size: 16, weight: .semibold, design: .monospaced)
        case .body:
            return .system(size: 14, weight: .medium, design: .monospaced)
        case .caption:
            return .system(size: 12, weight: .medium, design: .monospaced)
        case .button:
            return .system(size: 12, weight: .bold, design: .monospaced)
        }
    }
    
    var color: Color {
        switch self {
        case .title:
            return Color(DesignTokens.brutalistPrimary)
        case .headline, .subheadline:
            return .primary
        case .body:
            return .primary.opacity(0.8)
        case .caption:
            return .secondary
        case .button:
            return Color(DesignTokens.brutalistPrimary)
        }
    }
    
    var tracking: CGFloat {
        switch self {
        case .title, .headline:
            return 1.2
        case .subheadline, .button:
            return 0.8
        case .body, .caption:
            return 0.5
        }
    }
}