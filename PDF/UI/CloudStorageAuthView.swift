import SwiftUI

/// Brutalist cloud storage authentication interface
struct CloudStorageAuthView: View {
    @StateObject private var cloudManager = CloudStorageManager.shared
    @State private var selectedProvider: CloudProvider?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Black background with grain
            Color.black
                .ignoresSafeArea()
                .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
            
            VStack(spacing: 0) {
                // Brutalist header
                authHeader
                
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Authentication intro
                        authIntroSection
                        
                        // Provider selection
                        providerSelectionSection
                        
                        // Connected accounts section
                        if !cloudManager.connectedAccounts.isEmpty {
                            connectedAccountsSection
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            
            // Loading overlay
            if cloudManager.isAuthenticating {
                authLoadingOverlay
            }
            
            // Error toast
            if showError {
                errorToast
            }
        }
        .onChange(of: cloudManager.isAuthenticating) { _, isAuthenticating in
            if !isAuthenticating {
                selectedProvider = nil
            }
        }
    }
    
    // MARK: - Header
    
    private var authHeader: some View {
        HStack {
            // Back button
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                    Text("BACK")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(Color(DesignTokens.brutalistPrimary))
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Title
            BrutalistHeading(
                text: "CLOUD STORAGE",
                size: 20,
                color: Color(DesignTokens.brutalistPrimary),
                tracking: 1.2,
                addStroke: true,
                strokeWidth: 0.6
            )
            
            Spacer()
            
            // Spacer for balance
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                Text("BACK")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            .opacity(0) // Invisible for spacing
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
        )
    }
    
    // MARK: - Intro Section
    
    private var authIntroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistTechnicalText(
                text: "CONNECT TO CLOUD PROVIDERS",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.8),
                size: 14,
                addDecorators: true
            )
            
            Text("Securely connect your cloud storage accounts to save and sync PDFs across devices. All authentication tokens are stored encrypted in your system keychain.")
                .font(.system(size: 14, design: .default))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Provider Selection
    
    private var providerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistTechnicalText(
                text: "SELECT PROVIDER",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                size: 12,
                addDecorators: true
            )
            
            VStack(spacing: 12) {
                ForEach(CloudProvider.allCases, id: \.rawValue) { provider in
                    providerCard(for: provider)
                }
            }
        }
    }
    
    private func providerCard(for provider: CloudProvider) -> some View {
        Button {
            authenticateWithProvider(provider)
        } label: {
            HStack(spacing: 16) {
                // Provider icon
                ZStack {
                    UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 8, bottomLeading: 2, bottomTrailing: 8, topTrailing: 2), style: .continuous)
                        .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: provider.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(connectionStatus(for: provider))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(connectionStatusColor(for: provider))
                }
                
                Spacer()
                
                // Connection indicator
                connectionIndicator(for: provider)
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(borderColor(for: provider), lineWidth: 1)
                )
        )
        .disabled(cloudManager.isAuthenticating)
    }
    
    private func connectionStatus(for provider: CloudProvider) -> String {
        let accounts = cloudManager.accounts(for: provider)
        if accounts.isEmpty {
            return "Not connected"
        } else if accounts.count == 1 {
            return "Connected as \(accounts.first!.email)"
        } else {
            return "\(accounts.count) accounts connected"
        }
    }
    
    private func connectionStatusColor(for provider: CloudProvider) -> Color {
        return cloudManager.hasConnectedAccounts(for: provider) 
            ? Color(DesignTokens.brutalistPrimary).opacity(0.8)
            : .white.opacity(0.6)
    }
    
    private func borderColor(for provider: CloudProvider) -> Color {
        if selectedProvider == provider && cloudManager.isAuthenticating {
            return Color(DesignTokens.brutalistPrimary).opacity(0.8)
        } else if cloudManager.hasConnectedAccounts(for: provider) {
            return Color(DesignTokens.brutalistPrimary).opacity(0.4)
        } else {
            return .white.opacity(0.2)
        }
    }
    
    private func connectionIndicator(for provider: CloudProvider) -> some View {
        Group {
            if selectedProvider == provider && cloudManager.isAuthenticating {
                // Loading spinner
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(DesignTokens.brutalistPrimary)))
                    .scaleEffect(0.8)
            } else if cloudManager.hasConnectedAccounts(for: provider) {
                // Connected indicator
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
            } else {
                // Connect button
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Connected Accounts Section
    
    private var connectedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistTechnicalText(
                text: "CONNECTED ACCOUNTS",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                size: 12,
                addDecorators: true
            )
            
            VStack(spacing: 8) {
                ForEach(cloudManager.connectedAccounts) { account in
                    connectedAccountCard(account: account)
                }
            }
        }
    }
    
    private func connectedAccountCard(account: CloudAccount) -> some View {
        HStack(spacing: 12) {
            // Provider icon
            ZStack {
                Circle()
                    .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: account.provider.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(account.email)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(account.isActive ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            // Disconnect button
            Button {
                disconnectAccount(account)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Loading Overlay
    
    private var authLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated icon
                Image(systemName: "cloud")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    .rotationEffect(.degrees(Double.random(in: -5...5)))
                    .animation(.easeInOut(duration: 2).repeatForever(), value: UUID())
                
                BrutalistTechnicalText(
                    text: "AUTHENTICATING...",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 16,
                    addDecorators: true,
                    align: .center
                )
                
                if let provider = selectedProvider {
                    Text("Connecting to \(provider.displayName)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color(DesignTokens.brutalistPrimary))
                            .frame(width: 8, height: 8)
                            .opacity(0.3 + Double(i) * 0.2)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(i) * 0.2),
                                value: UUID()
                            )
                    }
                }
            }
            .padding(40)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                    )
                    .brutalistTexture(style: .grain, intensity: 0.2, color: .white)
            )
        }
    }
    
    // MARK: - Error Toast
    
    private var errorToast: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
                
                Text(errorMessage)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(3)
            }
            .padding()
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(.red.opacity(0.6), lineWidth: 1)
                    )
                    .brutalistTexture(style: .grain, intensity: 0.2, color: .white)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation {
                        showError = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func authenticateWithProvider(_ provider: CloudProvider) {
        selectedProvider = provider
        
        Task {
            do {
                try await cloudManager.authenticate(provider: provider)
            } catch {
                await MainActor.run {
                    showErrorMessage("Failed to connect to \(provider.displayName): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func disconnectAccount(_ account: CloudAccount) {
        Task {
            do {
                try await cloudManager.signOut(account: account)
            } catch {
                await MainActor.run {
                    showErrorMessage("Failed to disconnect account: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showErrorMessage(_ message: String) {
        withAnimation {
            errorMessage = message
            showError = true
        }
    }
}

// MARK: - Preview

#Preview {
    CloudStorageAuthView()
}