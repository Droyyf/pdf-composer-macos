import SwiftUI

struct BrutalistToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                
                Spacer()
                
                ZStack {
                    UnevenRoundedRectangle(cornerRadii: [.topLeading: 12, .bottomLeading: 4, .bottomTrailing: 12, .topTrailing: 4], style: .continuous)
                        .fill(configuration.isOn ? Color(DesignTokens.brutalistPrimary) : Color.clear)
                        .frame(width: 36, height: 20)
                        .overlay(
                            UnevenRoundedRectangle(cornerRadii: [.topLeading: 12, .bottomLeading: 4, .bottomTrailing: 12, .topTrailing: 4], style: .continuous)
                                .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                        )
                    
                    Circle()
                        .fill(configuration.isOn ? .white : Color(DesignTokens.brutalistPrimary))
                        .frame(width: 14, height: 14)
                        .offset(x: configuration.isOn ? 8 : -8)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension ToggleStyle where Self == BrutalistToggleStyle {
    static var brutalist: BrutalistToggleStyle { BrutalistToggleStyle() }
}