import SwiftUI

/// Plugin error display and management interface
struct PluginErrorView: View {
    @StateObject private var errorHandler = PluginErrorHandler(pluginManager: nil)
    @State private var selectedFilter: ErrorFilter = .all
    @State private var showingErrorHistory = false
    @State private var searchText = ""
    
    enum ErrorFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case critical = "Critical"
        case resolved = "Resolved"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .active: return "exclamationmark.circle"
            case .critical: return "exclamationmark.triangle.fill"
            case .resolved: return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .overlay(
                        BrutalistTexture()
                            .opacity(0.2)
                            .blendMode(.overlay)
                    )
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    errorViewHeader
                    
                    // Filters and search
                    filtersAndSearch
                    
                    // Error list
                    errorList
                    
                    // Footer with actions
                    errorViewFooter
                }
                .padding(.all, 24)
            }
        }
        .sheet(isPresented: $showingErrorHistory) {
            PluginErrorHistoryView(errorHandler: errorHandler)
        }
        .sheet(isPresented: $errorHandler.showingErrorDetails) {
            if let error = errorHandler.selectedError {
                PluginErrorDetailView(errorReport: error, errorHandler: errorHandler)
            }
        }
    }
    
    // MARK: - Header
    
    private var errorViewHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                BrutalistText("PLUGIN ERRORS", style: .title)
                    .foregroundColor(.primary)
                
                BrutalistText("\(filteredErrors.count) \(selectedFilter.rawValue.lowercased()) errors", style: .caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Error history button
                BrutalistButton(action: {
                    showingErrorHistory = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .bold))
                        BrutalistText("HISTORY", style: .button)
                    }
                }
                
                // Clear all button
                BrutalistButton(action: {
                    errorHandler.clearAllErrors()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                        BrutalistText("CLEAR ALL", style: .button)
                    }
                }
                .disabled(errorHandler.activeErrors.isEmpty)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Filters and Search
    
    private var filtersAndSearch: some View {
        VStack(spacing: 16) {
            // Filter buttons
            HStack(spacing: 8) {
                ForEach(ErrorFilter.allCases, id: \.self) { filter in
                    filterButton(filter)
                }
                
                Spacer()
                
                // Error count indicators
                errorCountIndicators
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                
                TextField("Search errors...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                
                if !searchText.isEmpty {
                    BrutalistButton(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Rectangle()
                            .stroke(.tertiary, lineWidth: 2)
                    )
            )
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(
                    Rectangle()
                        .stroke(.tertiary, lineWidth: 1)
                )
        )
    }
    
    private func filterButton(_ filter: ErrorFilter) -> some View {
        BrutalistButton(action: {
            selectedFilter = filter
        }) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .bold))
                
                BrutalistText(filter.rawValue.uppercased(), style: .caption)
            }
        }
        .foregroundColor(selectedFilter == filter ? .blue : .secondary)
        .background(
            Rectangle()
                .fill(selectedFilter == filter ? .blue.opacity(0.1) : .clear)
                .overlay(
                    Rectangle()
                        .stroke(selectedFilter == filter ? .blue : .tertiary, lineWidth: 1)
                )
        )
    }
    
    private var errorCountIndicators: some View {
        HStack(spacing: 12) {
            errorCountBadge(count: criticalErrors.count, color: .purple, label: "CRITICAL")
            errorCountBadge(count: errorHandler.activeErrors.filter { $0.severity == .error }.count, color: .red, label: "ERROR")
            errorCountBadge(count: errorHandler.activeErrors.filter { $0.severity == .warning }.count, color: .orange, label: "WARNING")
        }
    }
    
    private func errorCountBadge(count: Int, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            BrutalistText("\(count)", style: .caption)
                .foregroundColor(color)
            
            BrutalistText(label, style: .caption)
                .foregroundColor(.secondary)
        }
        .opacity(count > 0 ? 1.0 : 0.5)
    }
    
    // MARK: - Error List
    
    private var errorList: some View {
        Group {
            if filteredErrors.isEmpty {
                emptyErrorsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredErrors) { error in
                            PluginErrorRowView(
                                errorReport: error,
                                onTap: {
                                    errorHandler.selectedError = error
                                    errorHandler.showingErrorDetails = true
                                },
                                onDismiss: {
                                    errorHandler.markErrorResolved(error.id)
                                },
                                onRetry: {
                                    // TODO: Implement retry functionality
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    private var emptyErrorsView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter == .resolved ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                BrutalistText(emptyStateTitle, style: .headline)
                    .foregroundColor(.primary)
                
                BrutalistText(emptyStateMessage, style: .caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return searchText.isEmpty ? "NO ERRORS" : "NO MATCHING ERRORS"
        case .active:
            return "NO ACTIVE ERRORS"
        case .critical:
            return "NO CRITICAL ERRORS"
        case .resolved:
            return "NO RESOLVED ERRORS"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return searchText.isEmpty ? "ALL PLUGINS ARE RUNNING SMOOTHLY" : "TRY ADJUSTING YOUR SEARCH TERMS"
        case .active:
            return "ALL ERRORS HAVE BEEN RESOLVED"
        case .critical:
            return "NO CRITICAL PLUGIN ISSUES DETECTED"
        case .resolved:
            return "NO ERRORS HAVE BEEN RESOLVED YET"
        }
    }
    
    // MARK: - Footer
    
    private var errorViewFooter: some View {
        HStack {
            // Error summary
            if !errorHandler.activeErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    BrutalistText("ACTIVE ISSUES: \(errorHandler.activeErrors.count)", style: .caption)
                        .foregroundColor(.secondary)
                    
                    if criticalErrors.count > 0 {
                        BrutalistText("CRITICAL: \(criticalErrors.count)", style: .caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                if !criticalErrors.isEmpty {
                    BrutalistButton(action: {
                        // Show critical errors first
                        selectedFilter = .critical
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                            
                            BrutalistText("VIEW CRITICAL", style: .button)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Auto-resolve button
                BrutalistButton(action: {
                    autoResolveErrors()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .bold))
                        
                        BrutalistText("AUTO RESOLVE", style: .button)
                    }
                }
                .disabled(errorHandler.activeErrors.isEmpty)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Computed Properties
    
    private var filteredErrors: [PluginErrorReport] {
        var errors = errorHandler.activeErrors
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break // Show all
        case .active:
            errors = errors.filter { !$0.resolved }
        case .critical:
            errors = errors.filter { $0.severity == .critical }
        case .resolved:
            errors = errors.filter { $0.resolved }
        }
        
        // Apply search
        if !searchText.isEmpty {
            errors = errors.filter { error in
                error.pluginId.localizedCaseInsensitiveContains(searchText) ||
                error.error.localizedDescription.localizedCaseInsensitiveContains(searchText) ||
                error.context.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by severity and timestamp
        return errors.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity // Critical first
            }
            return lhs.timestamp > rhs.timestamp // Recent first
        }
    }
    
    private var criticalErrors: [PluginErrorReport] {
        return errorHandler.activeErrors.filter { $0.severity == .critical && !$0.resolved }
    }
    
    // MARK: - Helper Methods
    
    private func autoResolveErrors() {
        for error in errorHandler.activeErrors {
            if error.severity == .warning || error.severity == .info {
                errorHandler.markErrorResolved(error.id)
            }
        }
    }
}

// MARK: - Error Row View

struct PluginErrorRowView: View {
    let errorReport: PluginErrorReport
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            severityIndicator
            
            // Error content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    BrutalistText(errorReport.pluginId.uppercased(), style: .subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    BrutalistText(timeAgoString(from: errorReport.timestamp), style: .caption)
                        .foregroundColor(.secondary)
                }
                
                BrutalistText(errorReport.error.localizedDescription, style: .body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    contextBadge
                    
                    Spacer()
                    
                    if !errorReport.recoveryAttempts.isEmpty {
                        recoveryBadge
                    }
                }
            }
            
            // Action buttons
            VStack(spacing: 8) {
                if !errorReport.resolved {
                    BrutalistButton(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    BrutalistButton(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(errorReport.resolved ? .green.opacity(0.05) : errorReport.severity.color.opacity(0.05))
                .overlay(
                    Rectangle()
                        .stroke(errorReport.resolved ? .green.opacity(0.2) : errorReport.severity.color.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
        .opacity(errorReport.resolved ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: errorReport.resolved)
    }
    
    private var severityIndicator: some View {
        VStack {
            Circle()
                .fill(errorReport.severity.color)
                .frame(width: 12, height: 12)
            
            if errorReport.severity == .critical {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: -12)
            }
        }
    }
    
    private var contextBadge: some View {
        BrutalistText(errorReport.context.rawValue.uppercased(), style: .caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Rectangle()
                            .stroke(.tertiary, lineWidth: 1)
                    )
            )
            .foregroundColor(.secondary)
    }
    
    private var recoveryBadge: some View {
        let lastAttempt = errorReport.recoveryAttempts.last
        let success = lastAttempt?.success ?? false
        
        return BrutalistText(success ? "RECOVERED" : "RETRY FAILED", style: .caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Rectangle()
                    .fill(success ? .green.opacity(0.2) : .red.opacity(0.2))
                    .overlay(
                        Rectangle()
                            .stroke(success ? .green : .red, lineWidth: 1)
                    )
            )
            .foregroundColor(success ? .green : .red)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    PluginErrorView()
        .frame(width: 800, height: 600)
}