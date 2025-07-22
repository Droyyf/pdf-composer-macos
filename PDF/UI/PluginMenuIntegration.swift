import SwiftUI
import AppKit

/// Plugin menu integration system that dynamically adds plugin menu items to the application
@MainActor
class PluginMenuIntegration: ObservableObject {
    
    private let pluginManager: PluginManager
    private var pluginMenus: [String: NSMenu] = [:]
    private var pluginMenuItems: [String: [NSMenuItem]] = [:]
    
    // Main menu references
    private weak var mainMenu: NSMenu?
    private weak var pluginSubmenu: NSMenu?
    
    init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
        setupMenuObservation()
    }
    
    // MARK: - Menu Setup
    
    /// Initialize plugin menus in the main menu bar
    func setupPluginMenus(in mainMenu: NSMenu) {
        self.mainMenu = mainMenu
        
        // Create main plugins menu if it doesn't exist
        if pluginSubmenu == nil {
            createPluginSubmenu(in: mainMenu)
        }
        
        // Load menus for currently loaded plugins
        for plugin in pluginManager.loadedPlugins.values {
            addPluginMenuItems(for: plugin.metadata)
        }
    }
    
    private func createPluginSubmenu(in mainMenu: NSMenu) {
        // Create Plugins menu
        let pluginsMenuItem = NSMenuItem(title: "Plugins", action: nil, keyEquivalent: "")
        let pluginsMenu = NSMenu(title: "Plugins")
        pluginsMenuItem.submenu = pluginsMenu
        
        // Add standard plugin menu items
        let managePluginsItem = NSMenuItem(
            title: "Manage Plugins...",
            action: #selector(showPluginManager),
            keyEquivalent: ""
        )
        managePluginsItem.target = self
        pluginsMenu.addItem(managePluginsItem)
        
        let installPluginItem = NSMenuItem(
            title: "Install Plugin...",
            action: #selector(showPluginInstaller),
            keyEquivalent: ""
        )
        installPluginItem.target = self
        pluginsMenu.addItem(installPluginItem)
        
        pluginsMenu.addItem(.separator())
        
        // Add plugins menu to main menu (before Window menu)
        if let windowMenuIndex = mainMenu.indexOfItem(withTitle: "Window") {
            mainMenu.insertItem(pluginsMenuItem, at: windowMenuIndex)
        } else {
            mainMenu.addItem(pluginsMenuItem)
        }
        
        self.pluginSubmenu = pluginsMenu
    }
    
    // MARK: - Plugin Menu Management
    
    /// Add menu items for a specific plugin
    func addPluginMenuItems(for plugin: PluginMetadata) {
        guard let pluginSubmenu = pluginSubmenu else { return }
        
        // Remove existing items for this plugin
        removePluginMenuItems(for: plugin.identifier)
        
        // Don't add menus for plugins that aren't loaded
        guard pluginManager.isPluginLoaded(plugin.identifier) else { return }
        
        var menuItems: [NSMenuItem] = []
        
        if !plugin.menuItems.isEmpty {
            // Add separator before plugin items if this is not the first plugin
            if pluginSubmenu.numberOfItems > 3 { // Account for standard items + separator
                let separator = NSMenuItem.separator()
                pluginSubmenu.addItem(separator)
                menuItems.append(separator)
            }
            
            // Add plugin name as a disabled header
            let headerItem = NSMenuItem(title: plugin.displayName, action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            headerItem.attributedTitle = NSAttributedString(
                string: plugin.displayName,
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            pluginSubmenu.addItem(headerItem)
            menuItems.append(headerItem)
            
            // Add plugin menu items
            for menuItemDefinition in plugin.menuItems {
                let menuItem = createMenuItem(from: menuItemDefinition, for: plugin)
                pluginSubmenu.addItem(menuItem)
                menuItems.append(menuItem)
            }
        }
        
        // Store menu items for later removal
        pluginMenuItems[plugin.identifier] = menuItems
    }
    
    /// Remove menu items for a specific plugin
    func removePluginMenuItems(for pluginId: String) {
        guard let menuItems = pluginMenuItems[pluginId] else { return }
        
        for item in menuItems {
            item.menu?.removeItem(item)
        }
        
        pluginMenuItems.removeValue(forKey: pluginId)
    }
    
    /// Update all plugin menus
    func updateAllPluginMenus() {
        // Remove all plugin menu items
        for pluginId in pluginMenuItems.keys {
            removePluginMenuItems(for: pluginId)
        }
        
        // Re-add menu items for loaded plugins
        for plugin in pluginManager.loadedPlugins.values {
            addPluginMenuItems(for: plugin.metadata)
        }
    }
    
    // MARK: - Menu Item Creation
    
    private func createMenuItem(from definition: PluginMenuItem, for plugin: PluginMetadata) -> NSMenuItem {
        if definition.separator {
            return NSMenuItem.separator()
        }
        
        let menuItem = NSMenuItem(
            title: definition.title,
            action: #selector(handlePluginAction(_:)),
            keyEquivalent: definition.keyEquivalent ?? ""
        )
        
        menuItem.target = self
        menuItem.representedObject = PluginActionInfo(
            pluginId: plugin.identifier,
            action: definition.action
        )
        
        // Set modifier mask if specified
        if let modifierMask = definition.modifierMask {
            menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(modifierMask))
        }
        
        // Handle submenu
        if let submenuItems = definition.submenu, !submenuItems.isEmpty {
            let submenu = NSMenu(title: definition.title)
            
            for submenuItemDefinition in submenuItems {
                let submenuItem = createMenuItem(from: submenuItemDefinition, for: plugin)
                submenu.addItem(submenuItem)
            }
            
            menuItem.submenu = submenu
        }
        
        return menuItem
    }
    
    // MARK: - Menu Actions
    
    @objc private func showPluginManager() {
        // Send notification to show plugin manager
        NotificationCenter.default.post(name: .showPluginManager, object: nil)
    }
    
    @objc private func showPluginInstaller() {
        // Send notification to show plugin installer
        NotificationCenter.default.post(name: .showPluginInstaller, object: nil)
    }
    
    @objc private func handlePluginAction(_ sender: NSMenuItem) {
        guard let actionInfo = sender.representedObject as? PluginActionInfo else {
            return
        }
        
        // Execute plugin action
        Task {
            do {
                _ = try await pluginManager.executePluginAction(
                    actionInfo.pluginId,
                    action: actionInfo.action,
                    parameters: [:]
                )
            } catch {
                await MainActor.run {
                    showPluginError(error: error, pluginId: actionInfo.pluginId)
                }
            }
        }
    }
    
    private func showPluginError(error: Error, pluginId: String) {
        let alert = NSAlert()
        alert.messageText = "Plugin Action Failed"
        alert.informativeText = "The plugin '\(pluginId)' failed to execute the requested action:\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    // MARK: - Observation Setup
    
    private func setupMenuObservation() {
        // Observe plugin loading/unloading events
        NotificationCenter.default.addObserver(
            forName: .pluginDidLoad,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let pluginId = notification.userInfo?["pluginId"] as? String,
               let plugin = self?.pluginManager.loadedPlugins[pluginId]?.metadata {
                self?.addPluginMenuItems(for: plugin)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .pluginDidUnload,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let pluginId = notification.userInfo?["pluginId"] as? String {
                self?.removePluginMenuItems(for: pluginId)
            }
        }
    }
}

// MARK: - Supporting Types

private struct PluginActionInfo {
    let pluginId: String
    let action: String
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let showPluginManager = Notification.Name("showPluginManager")
    static let showPluginInstaller = Notification.Name("showPluginInstaller")
    static let pluginDidLoad = Notification.Name("pluginDidLoad")
    static let pluginDidUnload = Notification.Name("pluginDidUnload")
}

// MARK: - SwiftUI Integration

/// SwiftUI view that handles plugin menu integration
struct PluginMenuIntegratedView<Content: View>: View {
    let content: Content
    @StateObject private var pluginManager = PluginManager()
    @StateObject private var menuIntegration: PluginMenuIntegration
    @State private var showingPluginManager = false
    @State private var showingPluginInstaller = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self._menuIntegration = StateObject(wrappedValue: PluginMenuIntegration(pluginManager: PluginManager()))
    }
    
    var body: some View {
        content
            .onAppear {
                setupMenuIntegration()
                setupNotificationObservers()
            }
            .sheet(isPresented: $showingPluginManager) {
                PluginManagerView()
            }
            .sheet(isPresented: $showingPluginInstaller) {
                PluginInstallerView(pluginManager: pluginManager)
            }
    }
    
    private func setupMenuIntegration() {
        if let mainMenu = NSApp.mainMenu {
            menuIntegration.setupPluginMenus(in: mainMenu)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .showPluginManager,
            object: nil,
            queue: .main
        ) { _ in
            showingPluginManager = true
        }
        
        NotificationCenter.default.addObserver(
            forName: .showPluginInstaller,
            object: nil,
            queue: .main
        ) { _ in
            showingPluginInstaller = true
        }
    }
}

// MARK: - Context Menu Integration

/// Plugin context menu provider for integrating plugin actions into context menus
@MainActor
class PluginContextMenuProvider: ObservableObject {
    
    private let pluginManager: PluginManager
    
    init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
    }
    
    /// Get context menu items for PDF processing plugins
    func getPDFContextMenuItems(for document: Any?) -> [NSMenuItem] {
        let pdfPlugins = pluginManager.getPDFProcessingPlugins()
        var menuItems: [NSMenuItem] = []
        
        for plugin in pdfPlugins {
            guard pluginManager.isPluginLoaded(plugin.identifier) else { continue }
            
            // Add plugin-specific menu items
            for menuItemDefinition in plugin.menuItems {
                let menuItem = createContextMenuItem(from: menuItemDefinition, for: plugin, with: document)
                menuItems.append(menuItem)
            }
        }
        
        return menuItems
    }
    
    /// Get context menu items for export plugins
    func getExportContextMenuItems(for document: Any?) -> [NSMenuItem] {
        let exportPlugins = pluginManager.getExportFormatPlugins()
        var menuItems: [NSMenuItem] = []
        
        for plugin in exportPlugins {
            guard pluginManager.isPluginLoaded(plugin.identifier) else { continue }
            
            // Add export-specific menu items
            for menuItemDefinition in plugin.menuItems {
                let menuItem = createContextMenuItem(from: menuItemDefinition, for: plugin, with: document)
                menuItems.append(menuItem)
            }
        }
        
        return menuItems
    }
    
    private func createContextMenuItem(from definition: PluginMenuItem, for plugin: PluginMetadata, with context: Any?) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: definition.title,
            action: #selector(handleContextAction(_:)),
            keyEquivalent: ""
        )
        
        menuItem.target = self
        menuItem.representedObject = PluginContextActionInfo(
            pluginId: plugin.identifier,
            action: definition.action,
            context: context
        )
        
        return menuItem
    }
    
    @objc private func handleContextAction(_ sender: NSMenuItem) {
        guard let actionInfo = sender.representedObject as? PluginContextActionInfo else {
            return
        }
        
        // Execute plugin action with context
        Task {
            do {
                var parameters: [String: Any] = [:]
                if let context = actionInfo.context {
                    parameters["context"] = context
                }
                
                _ = try await pluginManager.executePluginAction(
                    actionInfo.pluginId,
                    action: actionInfo.action,
                    parameters: parameters
                )
            } catch {
                // Handle error
                print("Plugin context action failed: \(error)")
            }
        }
    }
}

private struct PluginContextActionInfo {
    let pluginId: String
    let action: String
    let context: Any?
}

// MARK: - Toolbar Integration

/// Plugin toolbar provider for adding plugin buttons to toolbars
@MainActor
class PluginToolbarProvider: ObservableObject {
    
    private let pluginManager: PluginManager
    
    init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
    }
    
    /// Get toolbar items for loaded plugins
    func getPluginToolbarItems() -> [NSToolbarItem] {
        var toolbarItems: [NSToolbarItem] = []
        
        for plugin in pluginManager.loadedPlugins.values {
            // Create toolbar items from plugin menu items
            for menuItemDefinition in plugin.metadata.menuItems {
                if !menuItemDefinition.separator && menuItemDefinition.submenu == nil {
                    let toolbarItem = createPluginToolbarItem(from: menuItemDefinition, for: plugin.metadata)
                    toolbarItems.append(toolbarItem)
                }
            }
        }
        
        return toolbarItems
    }
    
    private func createPluginToolbarItem(from definition: PluginMenuItem, for plugin: PluginMetadata) -> NSToolbarItem {
        let identifier = NSToolbarItem.Identifier("plugin.\(plugin.identifier).\(definition.action)")
        let toolbarItem = NSToolbarItem(itemIdentifier: identifier)
        
        toolbarItem.label = definition.title
        toolbarItem.toolTip = "\(definition.title) (\(plugin.displayName))"
        
        let button = NSButton()
        button.title = definition.title
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = #selector(handleToolbarAction(_:))
        button.tag = plugin.identifier.hashValue ^ definition.action.hashValue
        
        toolbarItem.view = button
        
        return toolbarItem
    }
    
    @objc private func handleToolbarAction(_ sender: NSButton) {
        // TODO: Implement toolbar action handling
        // This would need to map the button tag back to plugin and action
    }
}

#Preview {
    PluginMenuIntegratedView {
        Text("App with Plugin Menu Integration")
    }
}