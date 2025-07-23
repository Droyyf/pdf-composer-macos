import SwiftUI

/// Enhanced brutalist cloud storage picker for export operations with multi-account support
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
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0.0
    @State private var uploadRetryCount: Int = 0
    @State private var maxRetries: Int = 3
    @State private var showRetryOption: Bool = false
    
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
                        // Account selection with provider grouping
                        accountSelectionSection
                        
                        // Selected account info
                        if let account = selectedAccount {
                            selectedAccountInfoSection(account: account)
                        }
                        
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
            
            // Upload progress overlay
            if isUploading {
                uploadProgressOverlay
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
        .onReceive(cloudManager.$uploadProgress) { progress in
            if isUploading {
                uploadProgress = progress.progress
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
                    text: "SELECT CLOUD ACCOUNT (\(cloudManager.connectedAccounts.count) CONNECTED)",
                    color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                    size: 12,
                    addDecorators: true
                )
                
                Spacer()
                
                // Provider summary indicators
                HStack(spacing: 4) {
                    ForEach(CloudProvider.allCases, id: \.self) { provider in
                        let accountCount = cloudManager.accounts(for: provider).count
                        if accountCount > 0 {
                            providerIndicator(provider: provider, count: accountCount)
                        }
                    }
                }
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
    
    private func providerIndicator(provider: CloudProvider, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: provider.iconName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.6))
            
            Text("\(count)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 4, .bottomLeading: 2, .bottomTrailing: 4, .topTrailing: 2], style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private func accountCard(account: CloudAccount) -> some View {
        Button {
            selectedAccount = account
            selectedFolder = nil
            currentPath = []
            loadFolders()
        } label: {
            VStack(spacing: 8) {
                // Provider icon with active indicator
                ZStack {
                    UnevenRoundedRectangle(cornerRadii: [.topLeading: 12, .bottomLeading: 4, .bottomTrailing: 12, .topTrailing: 4], style: .continuous)
                        .fill(isSelected(account) ? Color(DesignTokens.brutalistPrimary).opacity(0.2) : Color.black.opacity(0.3))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: account.provider.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isSelected(account) ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.7))
                    
                    // Active status indicator
                    if account.isActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 16, y: -16)
                    }
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
                    
                    // Account email
                    Text(account.email)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(width: 110)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(isSelected(account) ? Color(DesignTokens.brutalistPrimary).opacity(0.6) : .white.opacity(0.2), lineWidth: isSelected(account) ? 2 : 1)
                )
        )
    }
    
    private func isSelected(_ account: CloudAccount) -> Bool {
        selectedAccount?.id == account.id && selectedAccount?.provider == account.provider
    }
    
    // MARK: - Selected Account Info
    
    private func selectedAccountInfoSection(account: CloudAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                BrutalistTechnicalText(
                    text: "SELECTED ACCOUNT",
                    color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                    size: 12,
                    addDecorators: true
                )
                
                Spacer()
                
                Button("SWITCH ACCOUNT") {
                    selectedAccount = nil
                    selectedFolder = nil
                    currentPath = []
                    folders = []
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.8))
                .buttonStyle(PlainButtonStyle())
            }
            
            HStack(spacing: 12) {
                // Provider icon
                ZStack {
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: account.provider.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(account.displayName) • \(account.provider.displayName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(account.email)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if let lastSync = account.lastSync {
                        Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Status indicator
                VStack(spacing: 4) {
                    Circle()
                        .fill(account.isActive ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(account.isActive ? "ACTIVE" : "INACTIVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(account.isActive ? Color.green : Color.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .overlay(
                    Rectangle()
                        .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
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
    
    // MARK: - Upload Progress Overlay
    
    private var uploadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Upload icon
                ZStack {
                    Circle()
                        .stroke(Color(DesignTokens.brutalistPrimary).opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: uploadProgress)
                        .stroke(Color(DesignTokens.brutalistPrimary), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: uploadProgress)
                    
                    Image(systemName: "cloud.arrow.up.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
                
                VStack(spacing: 8) {
                    BrutalistTechnicalText(
                        text: "UPLOADING TO \(selectedAccount?.provider.displayName.uppercased() ?? "CLOUD")...",
                        color: Color(DesignTokens.brutalistPrimary),
                        size: 14,
                        addDecorators: true,
                        align: .center
                    )
                    
                    Text("\(Int(uploadProgress * 100))% COMPLETE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let account = selectedAccount {
                        Text("TO: \(account.displayName)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(40)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.6), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Error Toast
    
    private var errorToast: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                
                // Show retry button if retry is available
                if showRetryOption {
                    HStack {
                        Button("RETRY") {
                            retryUpload()
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: [.topLeading: 4, .bottomLeading: 2, .bottomTrailing: 4, .topTrailing: 2], style: .continuous)
                                .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                                .overlay(
                                    UnevenRoundedRectangle(cornerRadii: [.topLeading: 4, .bottomLeading: 2, .bottomTrailing: 4, .topTrailing: 2], style: .continuous)
                                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.6), lineWidth: 1)
                                )
                        )
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Button("DISMISS") {
                            withAnimation {
                                showError = false
                                showRetryOption = false
                            }
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: [.topLeading: 2, .bottomLeading: 4, .bottomTrailing: 2, .topTrailing: 4], style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                        .buttonStyle(PlainButtonStyle())
                    }
                }
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
                if !showRetryOption {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            showError = false
                        }
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
        
        // Reset retry state for new upload
        showRetryOption = false
        
        Task {
            await performUploadWithRetry(request: request, account: account)
        }
    }
    
    private func performUploadWithRetry(request: CloudUploadRequest, account: CloudAccount) async {
        // Start upload with progress tracking
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }
        
        do {
            // Use the actual CloudStorageManager to upload
            let uploadedFile = try await cloudManager.upload(request: request, to: account)
            
            await MainActor.run {
                isUploading = false
                uploadRetryCount = 0 // Reset retry count on success
                onComplete(request, account)
            }
        } catch {
            await MainActor.run {
                isUploading = false
                handleUploadError(error, request: request, account: account)
            }
        }
    }
    
    private func handleUploadError(_ error: Error, request: CloudUploadRequest, account: CloudAccount) {
        let errorMsg = error.localizedDescription
        
        // Check if this is a retryable error and we haven't exceeded max retries
        if isRetryableError(error) && uploadRetryCount < maxRetries {
            uploadRetryCount += 1
            showRetryOption = true
            showErrorMessage("Upload failed (attempt \(uploadRetryCount)/\(maxRetries)): \(errorMsg)")
        } else {
            // Max retries exceeded or non-retryable error
            uploadRetryCount = 0
            showRetryOption = false
            
            if uploadRetryCount >= maxRetries {
                showErrorMessage("Upload failed after \(maxRetries) attempts: \(errorMsg)")
            } else {
                showErrorMessage("Upload failed: \(errorMsg)")
            }
        }
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Check for retryable errors (network issues, temporary server errors, etc.)
        if let cloudError = error as? CloudStorageError {
            switch cloudError {
            case .networkError(_):
                return true
            case .rateLimitExceeded:
                return true
            case .invalidResponse:
                return true
            case .tokenExpired:
                return true // Can retry after token refresh
            default:
                return false
            }
        }
        
        // Check for NSError network-related errors
        if let nsError = error as? NSError {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func retryUpload() {
        guard let account = selectedAccount, showRetryOption else { return }
        
        let request = CloudUploadRequest(
            localFileURL: localFileURL,
            fileName: fileName.trimmingCharacters(in: .whitespacesAndNewlines),
            parentFolderId: currentPath.last?.id,
            overwrite: false
        )
        
        showRetryOption = false
        
        Task {
            await performUploadWithRetry(request: request, account: account)
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
    CloudStoragePickerView(
        localFileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        onComplete: { _, _ in },
        onCancel: { }
    )
}