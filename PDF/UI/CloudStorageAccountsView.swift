import SwiftUI

/// Brutalist account management interface for cloud storage
struct CloudStorageAccountsView: View {
    @StateObject private var cloudManager = CloudStorageManager.shared
    @State private var showAuthView: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingStorageDetails: CloudAccount? = nil
    @State private var storageInfo: [String: (used: Int64, total: Int64?)] = [:]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Black background with grain
            Color.black
                .ignoresSafeArea()
                .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
            
            VStack(spacing: 0) {
                // Header
                accountsHeader
                
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Summary section
                        accountsSummarySection
                        
                        // Connected accounts
                        if !cloudManager.connectedAccounts.isEmpty {
                            connectedAccountsSection
                        }
                        
                        // Provider management
                        providerManagementSection
                        
                        // Storage usage section
                        if !storageInfo.isEmpty {
                            storageUsageSection
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            
            // Error toast
            if showError {
                errorToast
            }
        }
        .sheet(isPresented: $showAuthView) {
            CloudStorageAuthView()
        }
        .onAppear {
            loadStorageInfo()
        }
    }
    
    // MARK: - Header
    
    private var accountsHeader: some View {
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
                text: "CLOUD ACCOUNTS",
                size: 20,
                color: Color(DesignTokens.brutalistPrimary),
                tracking: 1.2,
                addStroke: true,
                strokeWidth: 0.6
            )
            
            Spacer()
            
            // Add account button
            Button {
                showAuthView = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
        )
    }
    
    // MARK: - Summary Section
    
    private var accountsSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistTechnicalText(
                text: "ACCOUNT OVERVIEW",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.8),
                size: 14,
                addDecorators: true
            )
            
            HStack(spacing: 20) {
                // Connected accounts count
                summaryCard(
                    title: "CONNECTED",
                    value: "\(cloudManager.connectedAccounts.count)",
                    subtitle: "ACCOUNTS",
                    color: Color(DesignTokens.brutalistPrimary)
                )
                
                // Providers count
                summaryCard(
                    title: "PROVIDERS",
                    value: "\(uniqueProvidersCount)",
                    subtitle: "SERVICES",
                    color: .blue
                )
                
                // Active accounts
                summaryCard(
                    title: "ACTIVE",
                    value: "\(activeAccountsCount)",
                    subtitle: "READY",
                    color: .green
                )
            }
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
    
    private func summaryCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(color.opacity(0.1))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var uniqueProvidersCount: Int {
        Set(cloudManager.connectedAccounts.map { $0.provider }).count
    }
    
    private var activeAccountsCount: Int {
        cloudManager.connectedAccounts.filter { $0.isActive }.count
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
            
            VStack(spacing: 12) {
                ForEach(cloudManager.connectedAccounts) { account in
                    expandedAccountCard(account: account)
                }
            }
        }
    }
    
    private func expandedAccountCard(account: CloudAccount) -> some View {
        VStack(spacing: 0) {
            // Main account info
            HStack(spacing: 16) {
                // Provider icon
                ZStack {
                    UnevenRoundedRectangle(cornerRadii: [.topLeading: 12, .bottomLeading: 4, .bottomTrailing: 12, .topTrailing: 4], style: .continuous)
                        .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: account.provider.iconName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Name and provider
                    HStack(spacing: 8) {
                        Text(account.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(account.provider.displayName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                            )
                    }
                    
                    // Email
                    Text(account.email)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Connection info
                    HStack(spacing: 12) {
                        // Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(account.isActive ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            
                            Text(account.isActive ? "ACTIVE" : "INACTIVE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(account.isActive ? .green : .orange)
                        }
                        
                        // Connected date
                        Text("CONNECTED: \(formatDate(account.connectedAt))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 8) {
                    // Toggle active status
                    Button {
                        toggleAccountStatus(account)
                    } label: {
                        Image(systemName: account.isActive ? "pause.circle" : "play.circle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(account.isActive ? .orange : .green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Storage info
                    Button {
                        showingStorageDetails = account
                        loadStorageInfo(for: account)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Remove account
                    Button {
                        removeAccount(account)
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            
            // Storage usage if available
            if let info = storageInfo[accountKey(account)] {
                storageUsageBar(for: account, used: info.used, total: info.total)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(account.isActive ? Color(DesignTokens.brutalistPrimary).opacity(0.4) : .white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func storageUsageBar(for account: CloudAccount, used: Int64, total: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("STORAGE USAGE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                if let total = total {
                    Text("\(formatBytes(used)) / \(formatBytes(total))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text(formatBytes(used))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            if let total = total, total > 0 {
                // Progress bar
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(usageColor(used: used, total: total))
                        .frame(width: CGFloat(Double(used) / Double(total)) * 300, height: 8)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 4, .bottomLeading: 8, .bottomTrailing: 4, .topTrailing: 8], style: .continuous)
                .fill(Color.black.opacity(0.2))
        )
    }
    
    private func usageColor(used: Int64, total: Int64) -> Color {
        let percentage = Double(used) / Double(total)
        if percentage > 0.9 {
            return .red
        } else if percentage > 0.7 {
            return .orange
        } else {
            return Color(DesignTokens.brutalistPrimary)
        }
    }
    
    // MARK: - Provider Management Section
    
    private var providerManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistTechnicalText(
                text: "AVAILABLE PROVIDERS",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                size: 12,
                addDecorators: true
            )
            
            VStack(spacing: 8) {
                ForEach(CloudProvider.allCases, id: \.rawValue) { provider in
                    providerManagementCard(provider: provider)
                }
            }
        }
    }
    
    private func providerManagementCard(provider: CloudProvider) -> some View {
        HStack(spacing: 16) {
            // Provider icon
            ZStack {
                UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                    .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: provider.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                let accounts = cloudManager.accounts(for: provider)
                if accounts.isEmpty {
                    Text("Not connected")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s") connected")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.8))
                }
            }
            
            Spacer()
            
            // Add account button
            Button {
                showAuthView = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.7))
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
    
    // MARK: - Storage Usage Section
    
    private var storageUsageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistTechnicalText(
                text: "STORAGE OVERVIEW",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                size: 12,
                addDecorators: true
            )
            
            VStack(spacing: 8) {
                ForEach(cloudManager.connectedAccounts) { account in
                    if let info = storageInfo[accountKey(account)] {
                        storageOverviewCard(account: account, used: info.used, total: info.total)
                    }
                }
            }
        }
    }
    
    private func storageOverviewCard(account: CloudAccount, used: Int64, total: Int64?) -> some View {
        HStack(spacing: 12) {
            // Account info
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(account.provider.displayName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Usage info
            VStack(alignment: .trailing, spacing: 2) {
                if let total = total {
                    Text("\(Int((Double(used) / Double(total)) * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(usageColor(used: used, total: total))
                } else {
                    Text("N/A")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text(formatBytes(used))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
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
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date).uppercased()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func accountKey(_ account: CloudAccount) -> String {
        return "\(account.provider.rawValue)_\(account.id)"
    }
    
    private func loadStorageInfo() {
        for account in cloudManager.connectedAccounts {
            loadStorageInfo(for: account)
        }
    }
    
    private func loadStorageInfo(for account: CloudAccount) {
        Task {
            do {
                let info = try await cloudManager.getStorageInfo(for: account)
                await MainActor.run {
                    storageInfo[accountKey(account)] = info
                }
            } catch {
                // Silently fail for now - storage info is optional
                print("Failed to load storage info for \(account.displayName): \(error)")
            }
        }
    }
    
    private func toggleAccountStatus(_ account: CloudAccount) {
        do {
            try cloudManager.updateAccount(account, isActive: !account.isActive)
        } catch {
            showErrorMessage("Failed to update account status: \(error.localizedDescription)")
        }
    }
    
    private func removeAccount(_ account: CloudAccount) {
        Task {
            do {
                try await cloudManager.signOut(account: account)
            } catch {
                await MainActor.run {
                    showErrorMessage("Failed to remove account: \(error.localizedDescription)")
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
    CloudStorageAccountsView()
}