import SwiftUI

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    var body: some View {
        Form {
            Section(header: Text("Display")) {
                HStack {
                    Text("Default Zoom")
                    Slider(value: $store.settings.defaultZoom, in: 0.5...4.0, step: 0.01)
                }
                Picker("Cover Placement", selection: $store.settings.defaultCoverPlacement) {
                    ForEach(CoverPlacement.allCases.map { $0.rawValue }, id: \ .self) { placement in
                        Text(placement.capitalized)
                    }
                }
                Toggle("Dark Mode", isOn: $store.settings.darkMode)
            }
            Section(header: Text("General")) {
                Stepper(value: $store.settings.recentFileCount, in: 1...20) {
                    Text("Recent File Count: \(store.settings.recentFileCount)")
                }
                Stepper(value: $store.settings.autosaveInterval, in: 10...600, step: 10) {
                    Text("Autosave Interval: \(Int(store.settings.autosaveInterval))s")
                }
                Picker("Log Level", selection: $store.settings.logLevel) {
                    ForEach(["debug", "info", "warn", "error"], id: \ .self) { level in
                        Text(level.capitalized)
                    }
                }
            }
        }
        .padding(DesignTokens.grid * 2)
        .background(Color(DesignTokens.bg900))
        .onDisappear { store.save() }
    }
}

#Preview {
    SettingsView()
}
