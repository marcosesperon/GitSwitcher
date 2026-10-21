import AppKit
import SwiftUI
import Testing
@testable import GitSwitcher

/// Genera las capturas de los ajustes para la web (site/img).
///
/// No corre con los tests normales: solo si se lanza con
/// `scripts/screenshots.sh`, que pone las variables de entorno. Usa datos
/// inventados y unas preferencias de usar y tirar, nunca las del usuario.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["GITSWITCHER_SCREENSHOTS_DIR"] != nil))
struct ScreenshotTests {
    /// Cuentas y estado de ejemplo que se ven en las capturas.
    static let sampleAccounts = [
        GhAccount(host: "github.com", login: "octo-personal", isActive: false, isValid: true),
        GhAccount(host: "github.com", login: "octo-work", isActive: true, isValid: true),
    ]
    static let sampleSetup = SetupStatus(
        ghPath: "/opt/homebrew/bin/gh", ghVersion: "2.80.0", gitUsesGh: true, brewPath: "/opt/homebrew/bin/brew"
    )

    @Test func capturarAjustes() async throws {
        let environment = ProcessInfo.processInfo.environment
        let outputDirectory = try #require(environment["GITSWITCHER_SCREENSHOTS_DIR"])
        let language = environment["GITSWITCHER_SCREENSHOTS_LANG"] ?? "en"

        let store = try makeSampleStore()
        let tabs: [(SettingsTab, String)] = [(.general, "general"), (.accounts, "accounts"), (.guide, "guide")]
        let themes: [(NSAppearance.Name, String)] = [(.aqua, "light"), (.darkAqua, "dark")]

        for (tab, tabName) in tabs {
            for (appearance, themeName) in themes {
                store.settingsTab = tab
                let file = "\(outputDirectory)/settings-\(tabName)-\(language)-\(themeName).png"
                try await render(SettingsView(store: store), appearance: appearance, to: file)
            }
        }
    }

    /// Store con preferencias en un dominio temporal y los datos de ejemplo.
    private func makeSampleStore() throws -> AccountsStore {
        let suite = "GitSwitcherScreenshots-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let storage = PreferencesStorage(defaults: defaults)
        storage.changeGitAuthor = true
        storage.accountPreferences = [
            "github.com/octo-work": AccountPreferences(alias: "Work", gitName: "Octo Cat", gitEmail: "octo@work.example"),
            "github.com/octo-personal": AccountPreferences(alias: "Personal", gitName: "Octo Cat", gitEmail: "1234567+octo-personal@users.noreply.github.com"),
        ]

        let store = AccountsStore(storage: storage)
        store.loadSampleData(accounts: Self.sampleAccounts, setup: Self.sampleSetup)
        return store
    }

    /// Pinta la vista en una ventana real (fuera de pantalla) y la guarda en PNG.
    private func render(_ view: some View, appearance: NSAppearance.Name, to path: String) async throws {
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.appearance = NSAppearance(named: appearance)
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFront(nil)
        defer { window.close() }

        // Damos tiempo a SwiftUI a colocar todo (y a la pestaña a cambiar).
        try await Task.sleep(for: .milliseconds(800))

        let content = try #require(window.contentView)
        let bitmap = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        let png = try #require(onWindowBackground(bitmap, appearance: appearance).representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: path))
    }

    /// `cacheDisplay` deja transparente el fondo de la ventana (la zona de las
    /// pestañas); en modo oscuro, el texto claro de las pestañas desaparecería
    /// sobre una web clara. Pintamos debajo el color de fondo de ventana del tema.
    private func onWindowBackground(_ bitmap: NSBitmapImageRep, appearance: NSAppearance.Name) throws -> NSBitmapImageRep {
        let result = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: bitmap.pixelsWide, pixelsHigh: bitmap.pixelsHigh,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let rect = NSRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: result)
        // El color «de sistema» cambia según el tema: lo resolvemos dentro de él.
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            rect.fill()
        }
        bitmap.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        return result
    }
}
