import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    enum ToastType { case success, error, info }
}

class ToastManager: ObservableObject {
    @Published var toasts: [Toast] = []
    func show(_ toast: Toast) {
        toasts.append(toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.toasts.removeAll { $0 == toast }
        }
    }
}

struct ToastStack: View {
    @ObservedObject var manager: ToastManager
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: DesignTokens.grid) {
                    ForEach(manager.toasts) { toast in
                        Text(toast.message)
                            .font(.custom("Inter Variable", size: 14))
                            .padding(.vertical, DesignTokens.grid)
                            .padding(.horizontal, DesignTokens.grid * 2)
                            .background(Color(DesignTokens.bg900).opacity(0.95))
                            .foregroundColor(Color(DesignTokens.fg100))
                            .cornerRadius(DesignTokens.radiusLg)
                            .shadow(radius: 8)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(DesignTokens.grid * 2)
            }
        }
        .animation(.easeOut(duration: 0.2), value: manager.toasts)
        .ignoresSafeArea()
    }
}
