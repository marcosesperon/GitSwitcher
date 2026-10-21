import Foundation

/// Foto del estado del equipo para la pestaña Guía. Cada campo responde a uno
/// de los pasos; `nil` significa «no se ha podido comprobar».
struct SetupStatus: Equatable, Sendable {
    var ghPath: String?
    var ghVersion: String?
    /// ¿git pide las credenciales de github.com a gh? (`gh auth setup-git`)
    var gitUsesGh: Bool
    /// Ruta a Homebrew, si está. Solo sirve para ofrecer «Abrir en Terminal»
    /// con `brew install gh`.
    var brewPath: String?
}

/// Comprueba lo que la guía necesita saber. No cambia nada: solo mira.
enum SetupChecker {
    /// Donde suele estar Homebrew (Apple Silicon e Intel).
    static let brewLocations = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    static func check(client: GhClient) async -> SetupStatus {
        async let version = client.version()
        async let gitUsesGh = gitUsesGhForGitHub()
        return SetupStatus(
            ghPath: client.environment.executable?.path,
            ghVersion: await version,
            gitUsesGh: await gitUsesGh,
            brewPath: brewLocations.first { FileManager.default.isExecutableFile(atPath: $0) }
        )
    }

    /// Mira qué credential helpers tiene git para github.com. `gh auth setup-git`
    /// añade uno que llama a `gh auth git-credential`; si está, git usa la cuenta
    /// activa de gh para `push`/`pull`.
    private static func gitUsesGhForGitHub() async -> Bool {
        let git = GitConfigWriter.gitExecutable
        guard let result = try? await CommandRunner.run(
            git, ["config", "--get-all", "credential.https://github.com.helper"], timeout: 5
        ) else { return false }
        // Si la clave no existe, git sale con código 1 y sin salida: es un «no».
        return helpersUseGh(result.stdoutString)
    }

    // MARK: - Lectura de salidas (separado para poder probarlo)

    /// De «gh version 2.102.0 (2026-09-30)» saca «2.102.0».
    static func parseGhVersion(_ output: String) -> String? {
        guard let firstLine = output.split(separator: "\n").first else { return nil }
        let words = firstLine.split(separator: " ")
        guard let index = words.firstIndex(of: "version"), index + 1 < words.count else { return nil }
        return String(words[index + 1])
    }

    /// ¿Alguno de los helpers (uno por línea) es gh? Puede venir como
    /// `!/opt/homebrew/bin/gh auth git-credential`, entre comillas si la ruta
    /// tiene espacios, o sin ruta (`!gh auth git-credential`).
    static func helpersUseGh(_ output: String) -> Bool {
        output.split(separator: "\n").contains { line in
            line.contains("gh auth git-credential") || line.contains("gh\" auth git-credential")
        }
    }
}
