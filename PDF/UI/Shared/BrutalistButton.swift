import SwiftUI

struct BrutalistButton: View {
    let action: () -> Void
    let content: () -> any View
    
    init(action: @escaping () -> Void, @ViewBuilder content: @escaping () -> any View) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        Button(action: action) {
            AnyView(content())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(DesignTokens.brutalistPrimary))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                                .fill(Color.black.opacity(0.1))
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Convenience init for simple text buttons
extension BrutalistButton {
    init(action: @escaping () -> Void, text: String) {
        self.init(action: action) {
            Text(text.uppercased())
        }
    }
}