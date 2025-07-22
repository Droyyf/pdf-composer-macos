import SwiftUI

struct BrutalistTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                            .fill(Color.secondary.opacity(0.05))
                    )
            )
    }
}