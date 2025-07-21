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
    }
}

extension Notification.Name {
    static let openDocument = Notification.Name("AlmostBrutalOpenDocument")
    static let exportDocument = Notification.Name("AlmostBrutalExportDocument")
    static let showSettings = Notification.Name("AlmostBrutalShowSettings")
}
