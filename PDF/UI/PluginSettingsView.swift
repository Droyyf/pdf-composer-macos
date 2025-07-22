import SwiftUI

/// Plugin settings configuration view with brutalist design
struct PluginSettingsView: View {
    let plugin: PluginMetadata
    let pluginManager: PluginManager
    
    @State private var configurationValues: [String: Any] = [:]
    @State private var hasUnsavedChanges = false
    @State private var showingResetConfirmation = false
    @State private var isSaving = false
    @State private var saveError: String?
    
    @Environment(\.dismiss) private var dismiss
    
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
                    settingsHeader
                    
                    // Content
                    if let schema = pluginManager.getPluginConfiguration(plugin.identifier) {
                        settingsContent(schema)
                    } else {
                        noSettingsView
                    }
                    
                    // Footer
                    settingsFooter
                }
                .padding(.all, 24)
            }
        }
        .onAppear {
            loadConfiguration()
        }
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset all plugin settings to their default values. This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    
    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                BrutalistText("\(plugin.displayName.uppercased()) SETTINGS", style: .headline)
                    .foregroundColor(.primary)
                
                BrutalistText("CONFIGURE PLUGIN BEHAVIOR", style: .caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Close button
            BrutalistButton(action: {
                if hasUnsavedChanges {
                    // TODO: Show unsaved changes alert
                }
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Settings Content
    
    private func settingsContent(_ schema: PluginSettingsSchema) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(schema.settings, id: \.key) { setting in
                    settingRow(setting)
                }
                
                // Error display
                if let error = saveError {
                    errorView(error)
                }
            }
            .padding(.vertical, 20)
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
    
    private var noSettingsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                BrutalistText("NO SETTINGS AVAILABLE", style: .headline)
                    .foregroundColor(.primary)
                
                BrutalistText("THIS PLUGIN DOES NOT HAVE CONFIGURABLE SETTINGS", style: .caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    // MARK: - Setting Rows
    
    @ViewBuilder
    private func settingRow(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Setting header
            VStack(alignment: .leading, spacing: 4) {
                BrutalistText(setting.title.uppercased(), style: .subheadline)
                    .foregroundColor(.primary)
                
                if let description = setting.description {
                    BrutalistText(description, style: .caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Setting control
            settingControl(setting)
            
            // Validation error
            if let validation = setting.validation,
               let error = validateSetting(setting, value: configurationValues[setting.key]) {
                BrutalistText(error, style: .caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(.quaternary)
                .overlay(
                    Rectangle()
                        .stroke(.tertiary, lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func settingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        switch setting.type {
        case .string:
            stringSettingControl(setting)
        case .integer:
            integerSettingControl(setting)
        case .double:
            doubleSettingControl(setting)
        case .boolean:
            booleanSettingControl(setting)
        case .url:
            urlSettingControl(setting)
        case .color:
            colorSettingControl(setting)
        case .file:
            fileSettingControl(setting)
        case .directory:
            directorySettingControl(setting)
        }
    }
    
    private func stringSettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        TextField("Enter value", text: Binding(
            get: {
                if let value = configurationValues[setting.key] as? String {
                    return value
                } else {
                    return getDefaultStringValue(setting)
                }
            },
            set: { newValue in
                configurationValues[setting.key] = newValue
                hasUnsavedChanges = true
            }
        ))
        .textFieldStyle(BrutalistTextFieldStyle())
    }
    
    private func integerSettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        HStack {
            TextField("0", value: Binding(
                get: {
                    if let value = configurationValues[setting.key] as? Int {
                        return value
                    } else {
                        return getDefaultIntegerValue(setting)
                    }
                },
                set: { newValue in
                    configurationValues[setting.key] = newValue
                    hasUnsavedChanges = true
                }
            ), format: .number)
            .textFieldStyle(BrutalistTextFieldStyle())
            
            // Stepper for integer values
            Stepper("", value: Binding(
                get: {
                    if let value = configurationValues[setting.key] as? Int {
                        return value
                    } else {
                        return getDefaultIntegerValue(setting)
                    }
                },
                set: { newValue in
                    configurationValues[setting.key] = newValue
                    hasUnsavedChanges = true
                }
            ), in: getIntegerRange(setting))
            .labelsHidden()
        }
    }
    
    private func doubleSettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        TextField("0.0", value: Binding(
            get: {
                if let value = configurationValues[setting.key] as? Double {
                    return value
                } else {
                    return getDefaultDoubleValue(setting)
                }
            },
            set: { newValue in
                configurationValues[setting.key] = newValue
                hasUnsavedChanges = true
            }
        ), format: .number)
        .textFieldStyle(BrutalistTextFieldStyle())
    }
    
    private func booleanSettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        Toggle(isOn: Binding(
            get: {
                if let value = configurationValues[setting.key] as? Bool {
                    return value
                } else {
                    return getDefaultBooleanValue(setting)
                }
            },
            set: { newValue in
                configurationValues[setting.key] = newValue
                hasUnsavedChanges = true
            }
        )) {
            EmptyView()
        }
        .toggleStyle(BrutalistToggleStyle())
    }
    
    private func urlSettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        TextField("https://example.com", text: Binding(
            get: {
                if let value = configurationValues[setting.key] as? String {
                    return value
                } else {
                    return getDefaultURLValue(setting)
                }
            },
            set: { newValue in
                configurationValues[setting.key] = newValue
                hasUnsavedChanges = true
            }
        ))
        .textFieldStyle(BrutalistTextFieldStyle())
    }
    
    private func colorSettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        HStack {
            ColorPicker("", selection: Binding(
                get: {
                    if let colorString = configurationValues[setting.key] as? String {
                        return Color(hex: colorString) ?? .blue
                    } else {
                        return Color(hex: getDefaultColorValue(setting)) ?? .blue
                    }
                },
                set: { newColor in
                    configurationValues[setting.key] = newColor.hexString
                    hasUnsavedChanges = true
                }
            ))
            .labelsHidden()
            .frame(width: 44, height: 44)
            
            TextField("Color hex code", text: Binding(
                get: {
                    if let value = configurationValues[setting.key] as? String {
                        return value
                    } else {
                        return getDefaultColorValue(setting)
                    }
                },
                set: { newValue in
                    configurationValues[setting.key] = newValue
                    hasUnsavedChanges = true
                }
            ))
            .textFieldStyle(BrutalistTextFieldStyle())
        }
    }
    
    private func fileSettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        HStack {
            TextField("Select file", text: Binding(
                get: {
                    if let value = configurationValues[setting.key] as? String {
                        return value
                    } else {
                        return getDefaultStringValue(setting)
                    }
                },
                set: { newValue in
                    configurationValues[setting.key] = newValue
                    hasUnsavedChanges = true
                }
            ))
            .textFieldStyle(BrutalistTextFieldStyle())
            .disabled(true)
            
            BrutalistButton(action: {
                selectFile(for: setting)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12, weight: .bold))
                    BrutalistText("BROWSE", style: .caption)
                }
            }
        }
    }
    
    private func directorySettingControl(_ setting: PluginSettingsSchema.PluginSetting) -> some View {
        HStack {
            TextField("Select directory", text: Binding(
                get: {
                    if let value = configurationValues[setting.key] as? String {
                        return value
                    } else {
                        return getDefaultStringValue(setting)
                    }
                },
                set: { newValue in
                    configurationValues[setting.key] = newValue
                    hasUnsavedChanges = true
                }
            ))
            .textFieldStyle(BrutalistTextFieldStyle())
            .disabled(true)
            
            BrutalistButton(action: {
                selectDirectory(for: setting)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12, weight: .bold))
                    BrutalistText("BROWSE", style: .caption)
                }
            }
        }
    }
    
    // MARK: - Footer
    
    private var settingsFooter: some View {
        HStack {
            // Reset button
            BrutalistButton(action: {
                showingResetConfirmation = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                    BrutalistText("RESET", style: .button)
                }
            }
            .disabled(!hasUnsavedChanges)
            
            Spacer()
            
            HStack(spacing: 12) {
                // Cancel button
                BrutalistButton(action: {
                    dismiss()
                }) {
                    BrutalistText("CANCEL", style: .button)
                        .foregroundColor(.secondary)
                }
                
                // Save button
                BrutalistButton(action: {
                    saveConfiguration()
                }) {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                        }
                        
                        BrutalistText("SAVE", style: .button)
                    }
                }
                .disabled(!hasUnsavedChanges || isSaving)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.red)
            
            BrutalistText(error, style: .body)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.red.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadConfiguration() {
        // TODO: Load actual plugin configuration
        configurationValues = [:]
    }
    
    private func saveConfiguration() {
        isSaving = true
        saveError = nil
        
        Task {
            do {
                // TODO: Validate and save configuration to plugin
                try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate save delay
                
                await MainActor.run {
                    hasUnsavedChanges = false
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
    
    private func resetToDefaults() {
        // TODO: Reset to default values from schema
        configurationValues = [:]
        hasUnsavedChanges = true
    }
    
    private func selectFile(for setting: PluginSettingsSchema.PluginSetting) {
        // TODO: Implement file selection
    }
    
    private func selectDirectory(for setting: PluginSettingsSchema.PluginSetting) {
        // TODO: Implement directory selection
    }
    
    // MARK: - Default Value Helpers
    
    private func getDefaultStringValue(_ setting: PluginSettingsSchema.PluginSetting) -> String {
        if case .string(let value) = setting.defaultValue {
            return value
        }
        return ""
    }
    
    private func getDefaultIntegerValue(_ setting: PluginSettingsSchema.PluginSetting) -> Int {
        if case .integer(let value) = setting.defaultValue {
            return value
        }
        return 0
    }
    
    private func getDefaultDoubleValue(_ setting: PluginSettingsSchema.PluginSetting) -> Double {
        if case .double(let value) = setting.defaultValue {
            return value
        }
        return 0.0
    }
    
    private func getDefaultBooleanValue(_ setting: PluginSettingsSchema.PluginSetting) -> Bool {
        if case .boolean(let value) = setting.defaultValue {
            return value
        }
        return false
    }
    
    private func getDefaultURLValue(_ setting: PluginSettingsSchema.PluginSetting) -> String {
        if case .url(let value) = setting.defaultValue {
            return value.absoluteString
        }
        return ""
    }
    
    private func getDefaultColorValue(_ setting: PluginSettingsSchema.PluginSetting) -> String {
        if case .color(let value) = setting.defaultValue {
            return value
        }
        return "#000000"
    }
    
    private func getIntegerRange(_ setting: PluginSettingsSchema.PluginSetting) -> ClosedRange<Int> {
        let min = setting.validation?.minValue.map { Int($0) } ?? Int.min
        let max = setting.validation?.maxValue.map { Int($0) } ?? Int.max
        return min...max
    }
    
    private func validateSetting(_ setting: PluginSettingsSchema.PluginSetting, value: Any?) -> String? {
        guard let validation = setting.validation else { return nil }
        
        // TODO: Implement comprehensive validation
        return nil
    }
}

// MARK: - Custom Styles

private struct PluginTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
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
            .font(.system(size: 14, weight: .medium, design: .monospaced))
    }
}

private struct PluginToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Rectangle()
                .fill(configuration.isOn ? .green : .secondary)
                .frame(width: 44, height: 24)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                )
                .overlay(
                    Rectangle()
                        .stroke(.tertiary, lineWidth: 2)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            
            configuration.label
        }
    }
}

// Color extensions are already defined in ColorExtensions.swift

#Preview {
    PluginSettingsView(
        plugin: PluginMetadata(
            identifier: "com.example.testplugin",
            name: "Test Plugin",
            version: PluginVersion(1, 0, 0),
            author: "Test Author",
            description: "A test plugin for demonstration",
            website: nil,
            supportEmail: nil,
            hostVersionRequirement: PluginVersionRequirement(minimum: PluginVersion(1, 0, 0)),
            swiftVersion: "5.9",
            minimumMacOSVersion: "14.0",
            capabilities: .pdfProcessing,
            requiredEntitlements: [],
            codeSigningIdentity: nil,
            teamIdentifier: nil,
            bundleIdentifier: "com.example.testplugin",
            checksumSHA256: nil,
            displayName: "Test Plugin",
            iconName: nil,
            menuItems: [],
            settingsSchema: nil
        ),
        pluginManager: PluginManager()
    )
    .frame(width: 600, height: 500)
}