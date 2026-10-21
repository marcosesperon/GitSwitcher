import Foundation

enum GhError: LocalizedError {
    case notInstalled
    case commandFailed(String)
    case unexpectedOutput

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return String(localized: "GitHub CLI (gh) is not installed.")
        case .commandFailed(let message):
            return message
        case .unexpectedOutput:
            return String(localized: "gh returned something GitSwitcher didn't understand. Is gh up to date?")
        }
    }
}

/// Todo lo que la app le pide a gh. Es la única pieza que sabe qué comandos
/// existen y cómo se llaman.
struct GhClient: Sendable {
    let environment: GhEnvironment

    /// Cuentas con sesión iniciada en todos los hosts.
    func accounts() async throws -> [GhAccount] {
        // Con `--json` gh devuelve código 0 aunque no haya ninguna sesión (lista
        // vacía), y 1 si algún token no es válido; en ambos casos el JSON viene
        // bien, así que lo leemos antes de mirar el código de salida.
        let result = try await run(["auth", "status", "--json", "hosts"])
        if let accounts = try? AuthStatusParser.parse(result.stdout) {
            return accounts
        }
        if !result.succeeded { throw GhError.commandFailed(cleanMessage(result.stderr)) }
        throw GhError.unexpectedOutput
    }

    /// Hace activa la cuenta `login` en `host`. Es lo mismo que hacían los
    /// scripts de terminal, y como gh es el que da las credenciales a git, también
    /// cambia con qué cuenta se hace `git push`.
    func switchAccount(to login: String, host: String) async throws {
        let result = try await run(["auth", "switch", "--hostname", host, "--user", login])
        guard result.succeeded else { throw GhError.commandFailed(cleanMessage(result.stderr)) }
    }

    /// Perfil público de una cuenta **sin cambiar la activa**: le pedimos a gh el
    /// token de esa cuenta y se lo pasamos solo a esta llamada. El token vive lo
    /// que dura la llamada; no se guarda en ningún sitio.
    func profile(of login: String, host: String) async throws -> GitHubProfile {
        let tokenResult = try await run(["auth", "token", "--hostname", host, "--user", login])
        let token = tokenResult.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tokenResult.succeeded, !token.isEmpty else {
            throw GhError.commandFailed(cleanMessage(tokenResult.stderr))
        }

        // GH_TOKEN vale para github.com; para Enterprise gh usa GH_ENTERPRISE_TOKEN.
        let tokenVariable = host == defaultGitHubHost ? "GH_TOKEN" : "GH_ENTERPRISE_TOKEN"
        let result = try await run(["api", "--hostname", host, "user"], extra: [tokenVariable: token])
        guard result.succeeded else { throw GhError.commandFailed(cleanMessage(result.stderr)) }
        do {
            return try JSONDecoder().decode(GitHubProfile.self, from: result.stdout)
        } catch {
            throw GhError.unexpectedOutput
        }
    }

    /// Versión de gh («2.102.0»), o `nil` si no se puede saber.
    func version() async -> String? {
        guard let result = try? await run(["--version"]), result.succeeded else { return nil }
        return SetupChecker.parseGhVersion(result.stdoutString)
    }

    /// Abre Terminal y ejecuta gh con `arguments`, a la vista del usuario. Se usa
    /// para lo que necesita interacción (`gh auth login`) o que el usuario vea
    /// qué pasa (`gh auth setup-git`). La app nunca ve credenciales: todo lo
    /// hace gh en la terminal.
    func openInTerminal(_ arguments: [String]) throws {
        guard let gh = environment.executable else { throw GhError.notInstalled }
        try TerminalLauncher.run([gh.path] + arguments, environment: environment.variables)
    }

    // MARK: - Ayudas

    private func run(_ arguments: [String], extra: [String: String] = [:]) async throws -> CommandResult {
        guard let gh = environment.executable else { throw GhError.notInstalled }
        // GH_PROMPT_DISABLED evita que gh se quede esperando una respuesta por
        // teclado que nunca llegará. NO_COLOR quita los códigos de color.
        let variables = environment.variables
            .merging(["GH_PROMPT_DISABLED": "1", "NO_COLOR": "1"]) { _, new in new }
            .merging(extra) { _, new in new }
        return try await CommandRunner.run(gh, arguments, environment: variables)
    }

    /// gh a veces deja varias líneas o espacios; nos quedamos con algo legible.
    private func cleanMessage(_ stderr: String) -> String {
        let text = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? String(localized: "gh failed without saying why.") : text
    }
}
