import AppKit

/// Punto de entrada. La app no tiene ventana principal ni icono en el Dock
/// (`LSUIElement` en el Info.plist): vive solo en la barra de menú.
@main
@MainActor
enum GitSwitcherApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AccountsStore()
    private let updates = UpdateStore()
    private var statusMenu: StatusMenuController?
    private var settingsWindow: SettingsWindowController?
    private var updateWindow: UpdateWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsWindowController(store: store, updates: updates)
        let updateWindow = UpdateWindowController(store: updates)
        settingsWindow = settings
        self.updateWindow = updateWindow
        statusMenu = StatusMenuController(
            store: store,
            updates: updates,
            openSettings: { tab in settings.show(tab: tab) },
            showUpdateWindow: { updateWindow.show() }
        )

        Task { await store.start() }
        updates.start()
    }
}
