import Foundation
import Testing
@testable import GitSwitcher

// Pruebas de las piezas que no dependen de tener gh instalado: la lectura de
// lo que devuelve gh y las reglas que decidimos nosotros.

@Suite("Lectura de gh auth status")
struct AuthStatusParserTests {
    @Test func leeCuentasDeVariosHosts() throws {
        let json = """
        {"hosts":{
          "github.com":[
            {"state":"success","active":false,"host":"github.com","login":"zoe-personal","tokenSource":"keyring","gitProtocol":"https"},
            {"state":"success","active":true,"host":"github.com","login":"Alice-Work","tokenSource":"keyring","gitProtocol":"https"}
          ],
          "ghe.example.com":[
            {"state":"error","active":true,"host":"ghe.example.com","login":"alice","tokenSource":"keyring"}
          ]
        }}
        """
        let accounts = try AuthStatusParser.parse(Data(json.utf8))

        #expect(accounts.count == 3)
        // Ordenadas por host y luego por login sin distinguir mayúsculas.
        #expect(accounts.map(\.login) == ["alice", "Alice-Work", "zoe-personal"])
        #expect(accounts.first { $0.login == "Alice-Work" }?.isActive == true)
        #expect(accounts.first { $0.host == "ghe.example.com" }?.isValid == false)
        #expect(accounts.first { $0.login == "zoe-personal" }?.id == "github.com/zoe-personal")
    }

    @Test func sinSesionDevuelveListaVacia() throws {
        let accounts = try AuthStatusParser.parse(Data(#"{"hosts":{}}"#.utf8))
        #expect(accounts.isEmpty)
    }

    @Test func jsonInvalidoFalla() {
        #expect(throws: (any Error).self) {
            try AuthStatusParser.parse(Data("not json".utf8))
        }
    }
}

@Suite("Preferencias y perfil")
struct PreferencesTests {
    let account = GhAccount(host: "github.com", login: "octo-cat", isActive: true, isValid: true)

    @Test func aliasVacioUsaElLogin() {
        #expect(AccountPreferences(alias: "  ").displayName(for: account) == "octo-cat")
        #expect(AccountPreferences(alias: "Work").displayName(for: account) == "Work")
    }

    @Test func identidadGitNecesitaNombreYCorreo() {
        #expect(!AccountPreferences(gitName: "Octo").hasGitIdentity)
        #expect(AccountPreferences(gitName: "Octo", gitEmail: "o@example.com").hasGitIdentity)
    }

    @Test func correoPrivadoUsaNoreply() {
        let profile = GitHubProfile(id: 42, login: "octo-cat", name: nil, email: nil)
        #expect(profile.suggestedEmail == "42+octo-cat@users.noreply.github.com")
        #expect(profile.suggestedName == "octo-cat")
    }

    @Test func correoPublicoSeRespeta() {
        let profile = GitHubProfile(id: 42, login: "octo-cat", name: "Octo Cat", email: "octo@example.com")
        #expect(profile.suggestedEmail == "octo@example.com")
        #expect(profile.suggestedName == "Octo Cat")
    }

    @Test func seGuardanYRecuperan() throws {
        let suite = "GitSwitcherTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let storage = PreferencesStorage(defaults: defaults)
        storage.accountPreferences = [account.id: AccountPreferences(alias: "Work", gitName: "Octo", gitEmail: "o@example.com")]
        storage.iconOnly = true

        #expect(storage.accountPreferences[account.id]?.alias == "Work")
        #expect(storage.iconOnly)
        #expect(!storage.changeGitAuthor)
    }
}

@Suite("Búsqueda de gh")
struct GhLocatorTests {
    @Test func leeLaRespuestaDelShellAunqueHayaRuido() {
        let m = GhLocator.marker
        let output = "Bienvenido!\n\(m)\n/opt/homebrew/bin/gh\n\(m)\n/custom/gh\n\(m)\n\n\(m)\n"
        let answer = GhLocator.parseShellAnswer(output)
        #expect(answer == .init(ghPath: "/opt/homebrew/bin/gh", ghConfigDir: "/custom/gh", xdgConfigHome: nil))
    }

    @Test func ignoraAliasYRespuestasIncompletas() {
        let m = GhLocator.marker
        #expect(GhLocator.parseShellAnswer("\(m)\ngh: aliased to hub\n\(m)\n\n\(m)\n\n\(m)\n").ghPath == nil)
        #expect(GhLocator.parseShellAnswer("zsh: command not found") == .init())
    }

    @Test func carpetaDeConfigSigueLasReglasDeGh() {
        #expect(GhLocator.configDirectory(ghConfigDir: "/a/b", xdgConfigHome: "/x").path == "/a/b")
        #expect(GhLocator.configDirectory(ghConfigDir: nil, xdgConfigHome: "/x").path == "/x/gh")
        #expect(GhLocator.configDirectory(ghConfigDir: nil, xdgConfigHome: nil).path.hasSuffix("/.config/gh"))
    }
}

@Suite("Vigilante de la configuración de gh")
struct HostsWatcherTests {
    /// Carpeta temporal que imita la de gh, con un contador de avisos.
    final class Fixture: @unchecked Sendable {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitswitcher-tests-\(UUID().uuidString)", isDirectory: true)
        var hosts: URL { directory.appendingPathComponent("hosts.yml") }
        private let lock = NSLock()
        private var count = 0
        var notifications: Int { lock.withLock { count } }
        func bump() { lock.withLock { count += 1 } }

        deinit { try? FileManager.default.removeItem(at: directory) }
    }

    /// Espera (hasta 3 s) a que llegue al menos un aviso nuevo.
    func waitForNotification(_ fixture: Fixture, after previous: Int) async -> Bool {
        for _ in 0..<60 {
            if fixture.notifications > previous { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    func makeWatcher(_ fixture: Fixture) async -> HostsWatcher {
        let watcher = HostsWatcher(directory: fixture.directory) { fixture.bump() }
        watcher.start()
        // Damos tiempo a que se enganche antes de tocar nada.
        try? await Task.sleep(for: .milliseconds(200))
        return watcher
    }

    @Test func avisaCuandoGhReescribeElFicheroEnSuSitio() async throws {
        let fixture = Fixture()
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try Data("user: a\n".utf8).write(to: fixture.hosts)
        let watcher = await makeWatcher(fixture)
        defer { watcher.stop() }

        // Igual que gh: abrir el fichero existente, vaciarlo y escribir.
        let handle = try FileHandle(forWritingTo: fixture.hosts)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data("user: b\n".utf8))
        try handle.close()

        #expect(await waitForNotification(fixture, after: 0))
    }

    @Test func avisaCuandoElFicheroSeSustituyeYSigueVigilando() async throws {
        let fixture = Fixture()
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try Data("user: a\n".utf8).write(to: fixture.hosts)
        let watcher = await makeWatcher(fixture)
        defer { watcher.stop() }

        // Escritura atómica: fichero nuevo que sustituye al viejo.
        try Data("user: b\n".utf8).write(to: fixture.hosts, options: .atomic)
        #expect(await waitForNotification(fixture, after: 0))

        // Y después, una reescritura en el sitio sobre el fichero nuevo.
        try? await Task.sleep(for: .milliseconds(500))
        let before = fixture.notifications
        let handle = try FileHandle(forWritingTo: fixture.hosts)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data("user: c\n".utf8))
        try handle.close()
        #expect(await waitForNotification(fixture, after: before))
    }

    @Test func avisaCuandoElFicheroSeCreaDespues() async throws {
        let fixture = Fixture()
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        let watcher = await makeWatcher(fixture)
        defer { watcher.stop() }

        try Data("user: a\n".utf8).write(to: fixture.hosts)
        #expect(await waitForNotification(fixture, after: 0))
    }
}
