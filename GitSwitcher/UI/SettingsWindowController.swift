import AppKit
import SwiftUI

/// Ventana de ajustes propia. La creamos nosotros en vez de usar la escena
/// `Settings` de SwiftUI porque desde AppKit no hay una forma pública y estable
/// de abrir esa escena.
@MainActor
final class SettingsWindowController {
    private let store: AccountsStore
    private var window: NSWindow?

    init(store: AccountsStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: store))
            // La ventana se ajusta sola al contenido (p. ej. al activar el autor de git).
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.title = String(localized: "GitSwitcher Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // Somos una app sin Dock: hay que traerla al frente a mano para que la
        // ventana no se abra detrás de las demás.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
