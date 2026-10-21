import Foundation
import Observation

/// El «cerebro» de la app: sabe qué cuentas hay, cuál está activa y qué ha
/// elegido el usuario en ajustes. El menú y la ventana de ajustes solo leen de
/// aquí y le piden cosas; ninguno habla con gh directamente.
@MainActor
@Observable
final class AccountsStore {
    /// En qué situación estamos, para que el menú sepa qué enseñar.
    enum Status: Equatable {
        case loading
        case ghMissing
        case signedOut
        case ready
        case failed(String)
    }

    private(set) var status: Status = .loading
    /// Todas las cuentas de todos los hosts, tal cual las da gh.
    private(set) var allAccounts: [GhAccount] = []
    /// Cuenta a la que estamos cambiando ahora mismo (para mostrar «cambiando…»).
    private(set) var switchingTo: GhAccount.ID?
    /// Último error que merece la pena enseñar en el menú.
    private(set) var lastError: String?
    /// Cuentas cuyo nombre/correo se está pidiendo a GitHub en este momento.
    private(set) var fetchingProfiles: Set<GhAccount.ID> = []

    private(set) var preferences: [String: AccountPreferences]

    var iconOnly: Bool {
        didSet { storage.iconOnly = iconOnly }
    }

    var changeGitAuthor: Bool {
        didSet {
            storage.changeGitAuthor = changeGitAuthor
            // Al activarlo, rellenamos de una vez lo que falte para que el usuario
            // vea en ajustes qué se va a aplicar.
            if changeGitAuthor && !oldValue {
                Task { await fillMissingGitIdentities() }
            }
        }
    }

    private let storage: PreferencesStorage
    private var client: GhClient?
    private var watcher: HostsWatcher?
    private var refreshTask: Task<Void, Never>?
    private var refreshAgain = false

    init(storage: PreferencesStorage = PreferencesStorage()) {
        self.storage = storage
        self.preferences = storage.accountPreferences
        self.iconOnly = storage.iconOnly
        self.changeGitAuthor = storage.changeGitAuthor
    }

    // MARK: - Lo que se ve

    /// Cuentas que enseñamos: de momento, solo las de github.com.
    var visibleAccounts: [GhAccount] {
        allAccounts.filter { $0.host == defaultGitHubHost }
    }

    var activeAccount: GhAccount? {
        visibleAccounts.first { $0.isActive }
    }

    func preferences(for account: GhAccount) -> AccountPreferences {
        preferences[account.id] ?? AccountPreferences()
    }

    func displayName(for account: GhAccount) -> String {
        preferences(for: account).displayName(for: account)
    }

    // MARK: - Arranque y refresco

    /// Busca gh, carga las cuentas y se queda vigilando cambios externos.
    func start() async {
        let environment = await GhLocator.locate()
        client = GhClient(environment: environment)

        watcher = HostsWatcher(directory: environment.configDirectory) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        watcher?.start()

        await reload()
    }

    /// Pide un refresco. Si ya hay uno en marcha no lanzamos otro en paralelo,
    /// pero apuntamos que hay que repetir: puede que el que está en marcha haya
    /// leído los datos justo antes del cambio que nos acaban de avisar.
    func refresh() {
        guard refreshTask == nil else {
            refreshAgain = true
            return
        }
        refreshTask = Task {
            repeat {
                refreshAgain = false
                await reload()
            } while refreshAgain
            refreshTask = nil
        }
    }

    private func reload() async {
        guard let client else { return }
        guard client.environment.executable != nil else {
            allAccounts = []
            status = .ghMissing
            return
        }
        do {
            allAccounts = try await client.accounts()
            status = visibleAccounts.isEmpty ? .signedOut : .ready
        } catch {
            // Si ya teníamos cuentas, un fallo puntual no debe vaciar el menú.
            if allAccounts.isEmpty { status = .failed(error.localizedDescription) }
            lastError = error.localizedDescription
        }
    }

    // MARK: - Acciones

    /// Cambia a `account`. Si está activado, aplica también su autor de git.
    func switchTo(_ account: GhAccount) async {
        guard let client, switchingTo == nil, !account.isActive else { return }
        switchingTo = account.id
        lastError = nil
        defer { switchingTo = nil }

        do {
            try await client.switchAccount(to: account.login, host: account.host)
        } catch {
            lastError = error.localizedDescription
            await reload()
            return
        }

        if changeGitAuthor {
            await applyGitIdentity(of: account)
        }
        await reload()
    }

    /// Abre Terminal con `gh auth login`.
    func addAccount() {
        do {
            try client?.openLoginInTerminal()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - Preferencias por cuenta

    func updatePreferences(for account: GhAccount, _ change: (inout AccountPreferences) -> Void) {
        var value = preferences(for: account)
        change(&value)
        preferences[account.id] = value
        storage.accountPreferences = preferences
    }

    /// Rellena nombre y correo de git de una cuenta con su perfil de GitHub.
    /// Con `overwrite: false` solo completa los campos que estén vacíos, para no
    /// pisar lo que el usuario haya escrito a mano.
    func fillGitIdentityFromGitHub(for account: GhAccount, overwrite: Bool) async {
        guard let client, !fetchingProfiles.contains(account.id) else { return }
        fetchingProfiles.insert(account.id)
        defer { fetchingProfiles.remove(account.id) }

        do {
            let profile = try await client.profile(of: account.login, host: account.host)
            updatePreferences(for: account) { prefs in
                if overwrite || prefs.gitName.isEmpty { prefs.gitName = profile.suggestedName }
                if overwrite || prefs.gitEmail.isEmpty { prefs.gitEmail = profile.suggestedEmail }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fillMissingGitIdentities() async {
        for account in visibleAccounts where !preferences(for: account).hasGitIdentity {
            await fillGitIdentityFromGitHub(for: account, overwrite: false)
        }
    }

    /// Aplica el autor de git de la cuenta. Si aún no lo tiene, primero lo pide a
    /// GitHub. Un fallo aquí no deshace el cambio de cuenta: gh ya cambió y eso es
    /// lo importante; solo avisamos.
    private func applyGitIdentity(of account: GhAccount) async {
        if !preferences(for: account).hasGitIdentity {
            await fillGitIdentityFromGitHub(for: account, overwrite: false)
        }
        let prefs = preferences(for: account)
        guard prefs.hasGitIdentity else { return }
        do {
            try await GitConfigWriter.setGlobalIdentity(
                name: prefs.gitName.trimmingCharacters(in: .whitespaces),
                email: prefs.gitEmail.trimmingCharacters(in: .whitespaces)
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}
