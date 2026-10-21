import AppKit
import Observation

/// El icono de la barra de menú y su menú desplegable.
///
/// Usamos AppKit (NSStatusItem + NSMenu) en lugar de `MenuBarExtra` de SwiftUI
/// porque necesitamos enterarnos de cuándo se abre el menú para refrescar las
/// cuentas, y `NSMenuDelegate` nos lo dice siempre.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let store: AccountsStore
    private let updates: UpdateStore
    private let showUpdateWindow: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let openSettings: (SettingsTab?) -> Void

    init(
        store: AccountsStore,
        updates: UpdateStore,
        openSettings: @escaping (SettingsTab?) -> Void,
        showUpdateWindow: @escaping () -> Void
    ) {
        self.store = store
        self.updates = updates
        self.openSettings = openSettings
        self.showUpdateWindow = showUpdateWindow
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageLeading

        observeStore()
    }

    // MARK: - Mantener la barra al día

    /// Repinta la barra (y el menú, si está abierto) cada vez que cambia algo del
    /// store. `withObservationTracking` solo avisa una vez, así que nos volvemos
    /// a apuntar después de cada aviso.
    private func observeStore() {
        withObservationTracking {
            updateButton()
            rebuildMenu()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeStore() }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }

        let symbol: String
        var title = ""
        switch store.status {
        case .loading:
            symbol = "person.crop.circle"
        case .ghMissing, .failed:
            symbol = "person.crop.circle.badge.exclamationmark"
        case .signedOut:
            symbol = "person.crop.circle.badge.plus"
        case .ready:
            symbol = store.switchingTo == nil ? "person.crop.circle.fill" : "arrow.triangle.2.circlepath.circle"
            if let active = store.activeAccount, !store.iconOnly {
                title = store.displayName(for: active)
            }
        }

        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "GitSwitcher")
        // Si hay versión nueva, el icono lleva un puntito.
        button.image = updates.availableRelease == nil ? image : image.map(withUpdateDot)
        button.image?.isTemplate = true
        // Un espacio delante para que el texto no quede pegado al icono.
        button.title = title.isEmpty ? "" : " " + title
        button.toolTip = store.activeAccount.map {
            String(localized: "GitHub account: \($0.login)")
        } ?? "GitSwitcher"
    }

    /// Dibuja el icono con un puntito arriba a la derecha (aviso de versión
    /// nueva). Sigue siendo «plantilla», así que macOS lo pinta del color de la
    /// barra como el resto de iconos.
    private func withUpdateDot(_ symbol: NSImage) -> NSImage {
        let size = NSSize(width: symbol.size.width + 3, height: symbol.size.height)
        return NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: NSRect(origin: .zero, size: symbol.size))
            let dot = NSRect(x: rect.maxX - 6, y: rect.maxY - 6, width: 6, height: 6)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
    }

    // MARK: - El menú

    /// Al abrir el menú pedimos a gh el estado actual, por si algo cambió fuera
    /// y el vigilante no se enteró. Si cambia, el menú se repinta solo.
    func menuWillOpen(_ menu: NSMenu) {
        store.refresh()
    }

    /// Un error ya visto no hace falta volver a enseñarlo.
    func menuDidClose(_ menu: NSMenu) {
        store.clearError()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        if let release = updates.availableRelease {
            menu.addItem(actionItem(
                String(localized: "Update Available: \(release.version.description)…"),
                action: #selector(openUpdate)
            ))
            menu.addItem(.separator())
        }

        switch store.status {
        case .loading:
            menu.addItem(disabledItem(String(localized: "Loading accounts…")))

        case .ghMissing:
            menu.addItem(disabledItem(String(localized: "GitHub CLI (gh) was not found")))
            menu.addItem(actionItem(String(localized: "Setup Guide…"), action: #selector(showGuide)))

        case .signedOut:
            menu.addItem(disabledItem(String(localized: "No GitHub accounts signed in to gh")))
            menu.addItem(actionItem(String(localized: "Setup Guide…"), action: #selector(showGuide)))

        case .failed(let message):
            menu.addItem(disabledItem(message))

        case .ready:
            menu.addItem(NSMenuItem.sectionHeader(title: defaultGitHubHost))
            for account in store.visibleAccounts {
                menu.addItem(accountItem(for: account))
            }
        }

        if let error = store.lastError, store.status == .ready || store.status == .signedOut {
            menu.addItem(.separator())
            let item = disabledItem("⚠︎ " + error)
            item.toolTip = error
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(String(localized: "Check for Updates…"), action: #selector(checkForUpdates)))
        menu.addItem(actionItem(String(localized: "Settings…"), action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem(String(localized: "Quit GitSwitcher"), action: #selector(quit), key: "q"))
    }

    private func accountItem(for account: GhAccount) -> NSMenuItem {
        let name = store.displayName(for: account)
        var title = name == account.login ? name : "\(name) (\(account.login))"
        if store.switchingTo == account.id {
            title += " — " + String(localized: "switching…")
        } else if !account.isValid {
            title += " — " + String(localized: "sign-in expired")
        }

        let item = actionItem(title, action: #selector(switchAccount(_:)))
        item.state = account.isActive ? .on : .off
        item.representedObject = account
        item.isEnabled = store.switchingTo == nil
        if !account.isValid {
            item.toolTip = String(localized: "Run “gh auth login” again for this account.")
        }
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Acciones del menú

    @objc private func switchAccount(_ sender: NSMenuItem) {
        guard let account = sender.representedObject as? GhAccount else { return }
        Task { await store.switchTo(account) }
    }

    @objc private func showSettings() {
        openSettings(nil)
    }

    @objc private func showGuide() {
        openSettings(.guide)
    }

    @objc private func openUpdate() {
        showUpdateWindow()
    }

    /// Comprobación a mano: a diferencia de la automática, siempre responde algo
    /// (hay versión, ya estás al día, o qué ha fallado).
    @objc private func checkForUpdates() {
        Task {
            switch await updates.check() {
            case .available:
                showUpdateWindow()
            case .upToDate:
                showAlert(
                    String(localized: "You're up to date"),
                    String(localized: "GitSwitcher \(updates.currentVersion.description) is the latest version.")
                )
            case .failed(let message):
                showAlert(String(localized: "Couldn't check for updates"), message)
            case .idle, .checking:
                break
            }
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
