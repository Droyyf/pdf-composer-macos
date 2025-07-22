import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") {
                NotificationCenter.default.post(name: .openDocument, object: nil)
            }
            .keyboardShortcut("O", modifiers: .command)
        }
        CommandGroup(after: .saveItem) {
            Button("Export…") {
                NotificationCenter.default.post(name: .exportDocument, object: nil)
            }
            .keyboardShortcut("S", modifiers: .command)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        
        // Plugin Commands
        CommandMenu("Plugins") {
            Button("Manage Plugins…") {
                NotificationCenter.default.post(name: .showPluginManager, object: nil)
            }
            .keyboardShortcut("P", modifiers: [.command, .shift])
            
            Button("Install Plugin…") {
                NotificationCenter.default.post(name: .showPluginInstaller, object: nil)
            }
            
            Divider()
            
            Button("Plugin Errors…") {
                NotificationCenter.default.post(name: .showPluginErrors, object: nil)
            }
            
            Button("Reload All Plugins") {
                NotificationCenter.default.post(name: .reloadPlugins, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let openDocument = Notification.Name("AlmostBrutalOpenDocument")
    static let exportDocument = Notification.Name("AlmostBrutalExportDocument")
    static let showSettings = Notification.Name("AlmostBrutalShowSettings")
    
    // Plugin notifications
    static let showPluginManager = Notification.Name("AlmostBrutalShowPluginManager")
    static let showPluginInstaller = Notification.Name("AlmostBrutalShowPluginInstaller")
    static let showPluginErrors = Notification.Name("AlmostBrutalShowPluginErrors")
    static let reloadPlugins = Notification.Name("AlmostBrutalReloadPlugins")
}
