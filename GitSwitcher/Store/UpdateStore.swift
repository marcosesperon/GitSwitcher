import Foundation
import Observation

/// Todo lo relativo a versiones nuevas: comprobar, avisar e instalar. Va aparte
/// de `AccountsStore` para no mezclar cuentas con actualizaciones.
@MainActor
@Observable
final class UpdateStore {
    enum CheckState: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed(String)
    }

    private(set) var state: CheckState = .idle
    /// `nil` cuando no se está instalando; si no, avance de la descarga (0…1).
    private(set) var installProgress: Double?
    private(set) var installError: String?

    let currentVersion = AppVersion.current
    let installMethod = InstallMethod.detect()

    var checkAutomatically: Bool {
        didSet {
            storage.checkForUpdates = checkAutomatically
            if checkAutomatically { scheduleDailyChecks() } else { dailyTask?.cancel() }
        }
    }

    /// La versión nueva, si la hay. Es lo que mira el menú para el aviso.
    var availableRelease: ReleaseInfo? {
        if case .available(let release) = state { return release }
        return nil
    }

    private let storage: PreferencesStorage
    private var dailyTask: Task<Void, Never>?

    /// Cada cuánto se vuelve a mirar si la app sigue abierta.
    static let checkInterval: Duration = .seconds(24 * 60 * 60)

    init(storage: PreferencesStorage = PreferencesStorage()) {
        self.storage = storage
        self.checkAutomatically = storage.checkForUpdates
    }

    /// Al arrancar: si está activado, comprueba ya y luego una vez al día.
    func start() {
        if checkAutomatically { scheduleDailyChecks() }
    }

    private func scheduleDailyChecks() {
        dailyTask?.cancel()
        dailyTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    /// Pregunta a GitHub por la última versión y actualiza `state`.
    @discardableResult
    func check() async -> CheckState {
        guard state != .checking else { return state }
        // Si ya sabemos que hay versión nueva, no la «perdemos» mientras se
        // vuelve a comprobar (el aviso del menú no parpadea).
        let previous = state
        state = .checking
        do {
            let release = try await ReleaseFeed.fetchLatest()
            state = release.version > currentVersion ? .available(release) : .upToDate
        } catch {
            if case .available = previous {
                state = previous
            } else {
                state = .failed(error.localizedDescription)
            }
        }
        return state
    }

    /// Descarga e instala la versión nueva y vuelve a abrir la app. Solo para
    /// instalaciones manuales; las de Homebrew usan `upgradeWithHomebrew()`.
    func installAndRelaunch() async {
        guard let release = availableRelease, installProgress == nil else { return }
        installError = nil
        installProgress = 0

        let appURL = Bundle.main.bundleURL
        do {
            try await UpdateInstaller().install(release, over: appURL) { [weak self] value in
                Task { @MainActor in
                    // Solo avanzamos: los avisos pueden llegar desordenados.
                    if let current = self?.installProgress, value > current { self?.installProgress = value }
                }
            }
            UpdateInstaller.relaunch(appURL)
        } catch {
            installError = error.localizedDescription
            installProgress = nil
        }
    }

    /// Abre Terminal con `brew update && brew upgrade --cask gitswitcher`.
    ///
    /// El `brew update` hace falta: Homebrew solo refresca los taps una vez al
    /// día, así que sin él `brew upgrade` puede no enterarse todavía de la
    /// versión que acabamos de anunciar. Homebrew cierra la app, instala la
    /// nueva y (en Homebrew 7) la vuelve a abrir.
    func upgradeWithHomebrew() {
        do {
            try TerminalLauncher.run(commands: Self.homebrewUpgradeCommands())
        } catch {
            installError = error.localizedDescription
        }
    }

    /// Los comandos de «Actualizar con Homebrew». Usa la ruta de brew si la
    /// encuentra; si no, confía en el PATH de la terminal.
    nonisolated static func homebrewUpgradeCommands(
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> [[String]] {
        let brew = SetupChecker.brewLocations.first(where: isExecutable).map { [$0] } ?? ["/usr/bin/env", "brew"]
        return [brew + ["update"], brew + ["upgrade", "--cask", "gitswitcher"]]
    }

    func clearInstallError() {
        installError = nil
    }
}

#if DEBUG
extension UpdateStore {
    /// Solo para el test de capturas de la web: simula que hay una versión nueva.
    func loadSampleRelease(_ release: ReleaseInfo) {
        state = .available(release)
    }
}
#endif
