import SwiftUI

/// Brutalist cloud storage picker for export operations
struct CloudStoragePickerView: View {
    @StateObject private var cloudManager = CloudStorageManager.shared
    @State private var selectedAccount: CloudAccount?
    @State private var selectedFolder: CloudFolder?
    @State private var currentPath: [CloudFolder] = []
    @State private var folders: [CloudFolder] = []
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var fileName: String = ""
    
    let localFileURL: URL
    let onComplete: (CloudUploadRequest, CloudAccount) -> Void
    let onCancel: () -> Void
    
    init(localFileURL: URL, onComplete: @escaping (CloudUploadRequest, CloudAccount) -> Void, onCancel: @escaping () -> Void) {
        self.localFileURL = localFileURL
        self.onComplete = onComplete
        self.onCancel = onCancel
        self._fileName = State(initialValue: localFileURL.lastPathComponent)
    }
    
    var body: some View {
        ZStack {
            // Black background with grain
            Color.black
                .ignoresSafeArea()
                .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
            
            VStack(spacing: 0) {
                // Header
                pickerHeader
                
                // Main content
                if cloudManager.connectedAccounts.isEmpty {
                    noAccountsState
                } else {
                    VStack(spacing: 0) {
                        // Account selection
                        accountSelectionSection
                        
                        // Folder navigation
                        if selectedAccount != nil {
                            folderNavigationSection
                        }
                        
                        // File name input
                        fileNameSection
                        
                        Spacer()
                        
                        // Action buttons
                        actionButtons
                    }
                }
            }
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
            
            // Error toast
            if showError {
                errorToast
            }
        }
        .onAppear {
            if let firstAccount = cloudManager.connectedAccounts.first {
                selectedAccount = firstAccount
                loadFolders()
            }
        }
    }
    
    // MARK: - Header
    
    private var pickerHeader: some View {
        HStack {
            // Cancel button
            Button("CANCEL") {
                onCancel()
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Title
            BrutalistHeading(
                text: "CLOUD EXPORT",
                size: 18,
                color: Color(DesignTokens.brutalistPrimary),
                tracking: 1.0,
                addStroke: true,
                strokeWidth: 0.5
            )
            
            Spacer()
            
            // Save button
            Button("UPLOAD") {
                performUpload()
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(canUpload ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.4))
            .buttonStyle(PlainButtonStyle())
            .disabled(!canUpload)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
        )
    }
    
    // MARK: - No Accounts State
    
    private var noAccountsState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "cloud.slash")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.7))
            }
            
            VStack(spacing: 12) {
                BrutalistTechnicalText(
                    text: "NO CLOUD ACCOUNTS",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 16,
                    addDecorators: true,
                    align: .center
                )
                
                Text("Connect to a cloud storage provider first to upload PDFs.")
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Connect button
            Button {
                // This would open the auth view
                // For now, just show a message
                showErrorMessage("Cloud authentication not fully implemented yet")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14, weight: .bold))
                    
                    Text("CONNECT ACCOUNT")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(Color(DesignTokens.brutalistPrimary))
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Account Selection
    
    private var accountSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BrutalistTechnicalText(
                    text: "SELECT ACCOUNT",
                    color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                    size: 12,
                    addDecorators: true
                )
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cloudManager.connectedAccounts) { account in
                        accountCard(account: account)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
    }
    
    private func accountCard(account: CloudAccount) -> some View {
        Button {
            selectedAccount = account
            selectedFolder = nil
            currentPath = []
            loadFolders()
        } label: {
            VStack(spacing: 8) {
                // Provider icon
                ZStack {
                    UnevenRoundedRectangle(cornerRadii: [.topLeading: 12, .bottomLeading: 4, .bottomTrailing: 12, .topTrailing: 4], style: .continuous)
                        .fill(isSelected(account) ? Color(DesignTokens.brutalistPrimary).opacity(0.2) : Color.black.opacity(0.3))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: account.provider.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isSelected(account) ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.7))
                }
                
                VStack(spacing: 2) {
                    Text(account.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected(account) ? .white : .white.opacity(0.8))
                        .lineLimit(1)
                    
                    Text(account.provider.displayName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isSelected(account) ? Color(DesignTokens.brutalistPrimary).opacity(0.8) : .white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .frame(width: 100)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(isSelected(account) ? Color(DesignTokens.brutalistPrimary).opacity(0.6) : .white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func isSelected(_ account: CloudAccount) -> Bool {
        selectedAccount?.id == account.id && selectedAccount?.provider == account.provider
    }
    
    // MARK: - Folder Navigation
    
    private var folderNavigationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Breadcrumb
            breadcrumbView
            
            // Folder list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(folders) { folder in
                        folderCard(folder: folder)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 300)
        }
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
    
    private var breadcrumbView: some View {
        HStack {
            BrutalistTechnicalText(
                text: "DESTINATION FOLDER",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                size: 12,
                addDecorators: true
            )
            
            Spacer()
            
            // Breadcrumb path
            HStack(spacing: 8) {
                Button("ROOT") {
                    navigateToRoot()
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(currentPath.isEmpty ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.6))
                .buttonStyle(PlainButtonStyle())
                
                ForEach(Array(currentPath.enumerated()), id: \.offset) { index, folder in
                    Text("/")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Button(folder.name) {
                        navigateTo(index: index)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(index == currentPath.count - 1 ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.6))
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func folderCard(folder: CloudFolder) -> some View {
        Button {
            navigateInto(folder: folder)
        } label: {
            HStack(spacing: 12) {
                // Folder icon
                Image(systemName: "folder.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.7))
                
                Text(folder.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.1))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - File Name Section
    
    private var fileNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BrutalistTechnicalText(
                    text: "FILE NAME",
                    color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                    size: 12,
                    addDecorators: true
                )
                
                Spacer()
            }
            
            TextField("Enter file name", text: $fileName)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("CANCEL") {
                onCancel()
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button("UPLOAD") {
                performUpload()
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(canUpload ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.4))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(canUpload ? Color(DesignTokens.brutalistPrimary).opacity(0.1) : Color.clear)
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(canUpload ? Color(DesignTokens.brutalistPrimary).opacity(0.6) : .white.opacity(0.2), lineWidth: 1)
                    )
            )
            .buttonStyle(PlainButtonStyle())
            .disabled(!canUpload)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    private var canUpload: Bool {
        selectedAccount != nil && !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(DesignTokens.brutalistPrimary)))
                    .scaleEffect(1.2)
                
                BrutalistTechnicalText(
                    text: "LOADING FOLDERS...",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 14,
                    addDecorators: true,
                    align: .center
                )
            }
            .padding(40)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                    )
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
    
    // MARK: - Navigation Actions
    
    private func loadFolders() {
        guard let account = selectedAccount else { return }
        
        isLoading = true
        
        Task {
            do {
                let loadedFolders = try await cloudManager.listFolders(
                    in: account,
                    parentId: currentPath.last?.id
                )
                
                await MainActor.run {
                    self.folders = loadedFolders
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    showErrorMessage("Failed to load folders: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func navigateInto(folder: CloudFolder) {
        currentPath.append(folder)
        loadFolders()
    }
    
    private func navigateToRoot() {
        currentPath = []
        loadFolders()
    }
    
    private func navigateTo(index: Int) {
        currentPath = Array(currentPath.prefix(index + 1))
        loadFolders()
    }
    
    private func performUpload() {
        guard let account = selectedAccount else { return }
        
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFileName.isEmpty else { return }
        
        let request = CloudUploadRequest(
            localFileURL: localFileURL,
            fileName: trimmedFileName,
            parentFolderId: currentPath.last?.id,
            overwrite: false
        )
        
        onComplete(request, account)
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
    CloudStoragePickerView(
        localFileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        onComplete: { _, _ in },
        onCancel: { }
    )
}