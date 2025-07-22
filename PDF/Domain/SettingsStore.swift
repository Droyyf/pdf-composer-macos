import Foundation
import SwiftUI

struct Settings: Codable {
    var defaultZoom: Double = 1.0
    var defaultCoverPlacement: String = "center"
    var darkMode: Bool = false
    var recentFileCount: Int = 5
    var autosaveInterval: TimeInterval = 60
    var logLevel: String = "info"
    
    // Cloud storage settings
    var cloudStorageEnabled: Bool = true
    var defaultCloudProvider: String? = nil
    var autoUploadEnabled: Bool = false
    var cloudBackupEnabled: Bool = false
    var syncSettings: Bool = false
}

final class SettingsStore: ObservableObject {
    @Published var settings: Settings
    private let url: URL
    static let shared = SettingsStore()

    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AlmostBrutal", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        url = dir.appendingPathComponent("settings.json")
        if let data = try? Data(contentsOf: url), let loaded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = loaded
        } else {
            settings = Settings()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: url)
        }
    }

    func update(_ block: (inout Settings) -> Void) {
        block(&settings)
        save()
    }
}
