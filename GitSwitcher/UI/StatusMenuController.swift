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
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let openSettings: () -> Void

    init(store: AccountsStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.openSettings = openSettings
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
        image?.isTemplate = true
        button.image = image
        // Un espacio delante para que el texto no quede pegado al icono.
        button.title = title.isEmpty ? "" : " " + title
        button.toolTip = store.activeAccount.map {
            String(localized: "GitHub account: \($0.login)")
        } ?? "GitSwitcher"
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

        switch store.status {
        case .loading:
            menu.addItem(disabledItem(String(localized: "Loading accounts…")))

        case .ghMissing:
            menu.addItem(disabledItem(String(localized: "GitHub CLI (gh) was not found")))
            menu.addItem(actionItem(String(localized: "How to Install gh…"), action: #selector(openInstallGuide)))

        case .signedOut:
            menu.addItem(disabledItem(String(localized: "No GitHub accounts signed in to gh")))

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
        if store.status != .ghMissing {
            menu.addItem(actionItem(String(localized: "Add Account…"), action: #selector(addAccount)))
        }
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

    @objc private func addAccount() {
        store.addAccount()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func openInstallGuide() {
        if let url = URL(string: "https://cli.github.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
