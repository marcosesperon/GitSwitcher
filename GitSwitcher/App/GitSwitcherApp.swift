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
    private var statusMenu: StatusMenuController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsWindowController(store: store)
        settingsWindow = settings
        statusMenu = StatusMenuController(store: store) { settings.show() }

        Task { await store.start() }
    }
}
